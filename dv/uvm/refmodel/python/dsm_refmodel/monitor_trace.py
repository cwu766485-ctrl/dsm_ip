"""Monitor-event trace decoder and independent Thermo5 TX PA oracle.

The JSONL schema is intentionally transaction based: source records are emitted
only on AXIS handshakes, AXI-Lite writes at the internal write-fire edge, frame
configuration events at the core boundary, and PA records only on four-plane
handshakes. No DUT active coefficient payload or PA output is used to construct
the expected data.
"""

from dataclasses import dataclass
import json
from pathlib import Path

from .thermo5 import Q14_ONE, run_centered_cubic_frontend


DEFAULT_COEFFICIENTS = {
    "c1_re": (Q14_ONE, 0, 0, 0), "c1_im": (0, 0, 0, 0),
    "c3_re": (0, 0, 0, 0), "c3_im": (0, 0, 0, 0),
    "c5_re": (0, 0, 0, 0), "c5_im": (0, 0, 0, 0),
}
COEFF_BASES = {
    0x10: "c1_re", 0x18: "c1_im", 0x20: "c3_re", 0x28: "c3_im",
    0x30: "c5_re", 0x38: "c5_im",
}


class TraceContractError(ValueError):
    """The recorded monitor events do not satisfy the documented contract."""


@dataclass(frozen=True)
class EpochResult:
    epoch: int
    expected_pa: tuple
    actual_pa: tuple
    compared_words: int
    applied_config_frames: tuple
    underflow_events: int
    reset_terminated: bool = False
    discarded_model_words: int = 0
    safe_output_words: int = 0
    status_reads_checked: int = 0
    status_reads_transition_masked: int = 0
    source_gap_events: int = 0
    source_gap_cycles: int = 0
    observed_stop_states: int = 0

    @property
    def passed(self):
        if self.reset_terminated:
            return (len(self.actual_pa) <= self.safe_output_words and
                    self.expected_pa[:len(self.actual_pa)] == self.actual_pa)
        return (len(self.expected_pa) == len(self.actual_pa) and
                self.expected_pa == self.actual_pa)

    @property
    def normal_passed(self):
        """Normal-stream acceptance also requires no underflow event."""
        return self.passed and self.underflow_events == 0


def _number(value):
    if isinstance(value, str):
        return int(value, 0) if value.lower().startswith("0x") else int(value, 16)
    return int(value)


def _signed16(value):
    value = int(value) & 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def _new_shadow():
    return {base: (Q14_ONE if base == 0x10 else 0) for base in COEFF_BASES}


def _decode_coefficients(shadow):
    decoded = {}
    for base, name in COEFF_BASES.items():
        packed = int(shadow[base])
        decoded[name] = tuple(_signed16((packed >> (16 * tap)) & 0xFFFF)
                              for tap in range(4))
    return decoded


def _apply_write(shadow, taps, run, status, event, *, max_taps=4):
    addr = _number(event["addr"])
    data = _number(event["data"]) & 0xFFFFFFFF
    strobe = _number(event.get("strb", 0xF)) & 0xF
    response = 0
    if addr == 0x00:
        if (strobe & 1) and (data & 2) and (
                status["busy"] or taps < 1 or taps > max_taps):
            response = 2
    elif addr not in (0x04, 0x08) and not (
            (addr & 0xF8) in COEFF_BASES and (addr & 0x03) == 0):
        response = 3
    if response != 0:
        if addr == 0x00:
            status["error"] = True
        return taps, run, None, response
    if addr == 0x08:
        if strobe & 1:
            taps = data & 7
    elif addr == 0x00 and strobe & 1:
        run = data & 1
        if data & 2:
            coeffs = _decode_coefficients(shadow)
            return taps, run, {"active_taps": taps, "coefficients": coeffs}, response
    elif addr == 0x04 and strobe & 1:
        if data & 2:
            status["done"] = False
        if data & 4:
            status["error"] = False
    elif addr in COEFF_BASES or addr - 4 in COEFF_BASES:
        base = addr & 0xF8
        if base not in COEFF_BASES:
            return taps, run, None, response
        old = int(shadow[base])
        shift = 32 if addr & 4 else 0
        old_word = (old >> shift) & 0xFFFFFFFF
        merged = old_word
        for lane in range(4):
            if strobe & (1 << lane):
                mask = 0xFF << (lane * 8)
                merged = (merged & ~mask) | (data & mask)
        mask64 = 0xFFFFFFFF << shift
        shadow[base] = (old & ~mask64) | (merged << shift)
    return taps, run, None, response


def _read_events(trace):
    if isinstance(trace, (str, Path)):
        with Path(trace).open(encoding="utf-8") as stream:
            return [json.loads(line) for line in stream if line.strip()]
    return [dict(item) for item in trace]


def _validate_event_sequence(events):
    """Reject duplicate or reordered recorder sequence numbers."""
    has_sequence = ["seq" in event for event in events]
    if any(has_sequence) and not all(has_sequence):
        raise TraceContractError("trace must either sequence every event or none")
    if not any(has_sequence):
        return
    previous = None
    seen = set()
    for event in events:
        sequence = int(event["seq"])
        if sequence in seen:
            raise TraceContractError(f"duplicate trace sequence number {sequence}")
        if previous is not None and sequence <= previous:
            raise TraceContractError(
                f"trace sequence reordered: {sequence} follows {previous}")
        previous = sequence
        seen.add(sequence)


def _model_system_status(epoch, events):
    """Audit STATUS against an independent, transaction-derived model.

    The expected lifecycle comes from accepted AXIS packets, AXI-Lite control
    writes, and accepted PA words. ``stop_state`` events are observations only;
    they never feed the expected value. Four AXI clocks are treated as the
    conservative settling window for the two RUN/STOP CDC stages and the
    two-stage STATUS return synchronizer. Reads in that window still check
    BUSY/DONE/ERROR whenever those bits are stable, but mask RUN_ACTIVE and
    DRAINING.
    """
    run_request = False
    state = "IDLE"
    state_cycle = 0
    prefill_beats = 0
    packet_beats = 0
    shadow_taps = 1
    required_pa_words = 0
    accepted_pa_words = 0
    busy = done = error = False
    pending_seen = False
    commit_applied = False
    commit_acked = False
    expected_write_responses = {}
    expected_status = {}
    reads_checked = 0
    reads_transition_masked = 0
    source_gaps = 0
    source_gap_cycles = 0
    observed_stop_states = 0
    stable_cycles = 4
    axil_cycle = 0

    def event_cycle(event):
        return int(event.get("event_cycle", event.get("axil_cycle", axil_cycle)))

    def status_state_at(cycle):
        if cycle - state_cycle < stable_cycles:
            return None
        if state == "RUN":
            return (1, 0)
        if state == "DRAIN":
            return (1, 1)
        return (0, 0)

    for event in events:
        kind = event.get("type")
        axil_cycle = event_cycle(event)
        if kind in ("axil_write_fire", "axil_write"):
            address = _number(event["addr"])
            data = _number(event["data"])
            strobe = _number(event.get("strb", 0xF))
            txn_id = int(event.get("txn_id", len(expected_write_responses) + 1))
            if address == 0x00:
                response = (2 if strobe & 1 and data & 2 and
                            (busy or shadow_taps < 1 or shadow_taps > 1) else 0)
            elif address in (0x04, 0x08) or (
                    (address & 0xF8) in COEFF_BASES and (address & 0x03) == 0):
                response = 0
            else:
                response = 3
            if txn_id in expected_write_responses:
                raise TraceContractError(
                    f"epoch {epoch}: duplicate AXI-Lite write id {txn_id}")
            expected_write_responses[txn_id] = response
            if response == 0:
                if address == 0x00 and strobe & 1:
                    previous_run = run_request
                    run_request = bool(data & 1)
                    if run_request and not previous_run:
                        state = "RUN"
                        state_cycle = axil_cycle
                    elif not run_request and previous_run:
                        if accepted_pa_words < required_pa_words or packet_beats:
                            state = "DRAIN"
                        else:
                            state = "IDLE"
                        state_cycle = axil_cycle
                    if data & 2:
                        busy, done = True, False
                        commit_applied = False
                        commit_acked = False
                elif address == 0x04 and strobe & 1:
                    if data & 2:
                        done = False
                    if data & 4:
                        error = False
                elif address == 0x08 and strobe & 1:
                    shadow_taps = data & 7
            elif address == 0x00:
                error = True
        elif kind == "axil_write_response":
            txn_id = int(event["txn_id"])
            if txn_id not in expected_write_responses:
                raise TraceContractError(
                    f"epoch {epoch}: write response without write-fire id {txn_id}")
            expected = expected_write_responses.pop(txn_id)
            if _number(event["resp"]) != expected:
                raise TraceContractError(
                    f"epoch {epoch}: write id {txn_id} response mismatch")
        elif kind == "source_beat":
            packet_beats += 1
            if state == "IDLE":
                prefill_beats = min(2, prefill_beats + 1)
            gap = int(event.get("source_gap_cycles", event.get("gap_cycles", 0)))
            if gap > 0:
                source_gaps += 1
                source_gap_cycles += gap
            if bool(event.get("tlast", False)):
                if packet_beats % 32:
                    raise TraceContractError(
                        f"epoch {epoch}: status model saw TLAST after {packet_beats} beats")
                required_pa_words += packet_beats * 14 // 8
                packet_beats = 0
        elif kind == "pa_word":
            accepted_pa_words += 1
            if (state == "DRAIN" and packet_beats == 0 and required_pa_words and
                    accepted_pa_words >= required_pa_words):
                state = "IDLE"
                prefill_beats = 0
                state_cycle = axil_cycle
        elif kind == "config_pending":
            if not busy or pending_seen or commit_applied:
                raise TraceContractError(
                    f"epoch {epoch}: duplicate or unowned CDC pending event")
            pending_seen = True
        elif kind == "frame_boundary":
            if bool(event.get("config_pending", False)):
                if not busy or not pending_seen or commit_applied:
                    raise TraceContractError(
                        f"epoch {epoch}: config apply precedes CDC pending or COMMIT")
                commit_applied = True
                pending_seen = False
        elif kind == "config_ack_core":
            if not commit_applied or not busy:
                raise TraceContractError(
                    f"epoch {epoch}: config ACK precedes frame-boundary apply")
            commit_acked = True
        elif kind == "commit_done":
            if not commit_applied or not commit_acked or not busy:
                raise TraceContractError(
                    f"epoch {epoch}: COMMIT done precedes apply/ACK")
            busy, done = False, True
            commit_applied = commit_acked = False
        elif kind == "source_gap":
            duration = int(event.get("duration_src_cycles",
                                     event.get("duration_cycles", 0)))
            if duration <= 0:
                raise TraceContractError(
                    f"epoch {epoch}: source_gap event has no positive duration")
            source_gaps += 1
            source_gap_cycles += duration
        elif kind == "stop_state":
            observed = (int(bool(event.get("run", False))),
                        int(bool(event.get("active", False))),
                        int(bool(event.get("draining", False))))
            if observed not in ((0, 0, 0), (1, 1, 0), (0, 1, 1)):
                raise TraceContractError(
                    f"epoch {epoch}: illegal observed RUN/ACTIVE/DRAINING tuple {observed}")
            observed_stop_states += 1
            predicted = status_state_at(axil_cycle)
            if predicted is not None and observed[1:] != predicted:
                raise TraceContractError(
                    f"epoch {epoch}: settled core observation {observed[1:]} "
                    f"disagrees with transaction model {state}")
        elif kind == "axil_read":
            if _number(event["addr"]) == 0x04:
                mask = 0x7
                value = int(busy) | (int(done) << 1) | (int(error) << 2)
                predicted = status_state_at(axil_cycle)
                if predicted is not None:
                    active, draining = predicted
                    value |= (active << 3) | (draining << 4)
                    mask |= 0x18
                else:
                    reads_transition_masked += 1
                txn_id = event.get("txn_id")
                expected_status.setdefault(txn_id, []).append((value, mask))
        elif kind == "axil_read_response":
            txn_id = event.get("txn_id")
            if _number(event.get("addr", 0)) == 0x04:
                if txn_id not in expected_status or not expected_status[txn_id]:
                    raise TraceContractError(
                        f"epoch {epoch}: STATUS response without matching AR id={txn_id}")
                if _number(event.get("resp", 0)) != 0:
                    raise TraceContractError(
                        f"epoch {epoch}: STATUS read id={txn_id} returned non-OKAY")
                value, mask = expected_status[txn_id].pop(0)
                actual = _number(event["rdata"])
                if ((actual ^ value) & mask) != 0:
                    raise TraceContractError(
                        f"epoch {epoch}: STATUS mismatch id={txn_id} "
                        f"expected={value:08x} mask={mask:08x} actual={actual:08x}")
                reads_checked += 1
        elif kind == "reset":
            # Resets partition epochs before this function is called.
            continue

    if expected_write_responses:
        raise TraceContractError(
            f"epoch {epoch}: {len(expected_write_responses)} write responses missing")
    if any(queue for queue in expected_status.values()):
        raise TraceContractError(f"epoch {epoch}: STATUS read response missing")
    return (reads_checked, reads_transition_masked, source_gaps,
            source_gap_cycles, observed_stop_states)


def _model_epoch(epoch, events, *, step=5120, tidsm_order=2, max_taps=1,
                 compare=True, reset_terminated=False):
    shadow = _new_shadow()
    taps = 1
    run = 0
    status = {"busy": False, "done": False, "error": False}
    pending_config = None
    active_config = None
    config_by_frame = {}
    applied_frames = []
    core_ack_seen = False
    cdc_pending_seen = False
    source_beats = []
    actual_pa = []
    packet_beats = 0
    packet_id = 0
    expected_beat_index = 0
    observed_frame_id = 0
    source_frame_seen = False
    underflow_events = 0
    expected_write_responses = {}

    for event in events:
        kind = event.get("type")
        if kind in ("axil_write_fire", "axil_write"):
            taps, run, candidate, response = _apply_write(
                shadow, taps, run, status, event, max_taps=max_taps)
            txn_id = int(event.get("txn_id", len(expected_write_responses) + 1))
            if txn_id in expected_write_responses:
                raise TraceContractError(f"duplicate AXI-Lite write transaction id {txn_id}")
            expected_write_responses[txn_id] = response
            if candidate is not None:
                pending_config = candidate
                status["busy"] = True
                status["done"] = False
        elif kind == "axil_write_response":
            txn_id = int(event["txn_id"])
            if txn_id not in expected_write_responses:
                raise TraceContractError(f"write response without write-fire id {txn_id}")
            expected_response = expected_write_responses.pop(txn_id)
            actual_response = _number(event["resp"])
            if actual_response != expected_response:
                raise TraceContractError(
                    f"write id {txn_id}: response expected {expected_response}, "
                    f"observed {actual_response}")
        elif kind == "config_pending":
            if pending_config is None:
                raise TraceContractError("CDC pending event has no legal accepted COMMIT")
            if cdc_pending_seen:
                raise TraceContractError("duplicate CDC pending event before frame apply")
            cdc_pending_seen = True
        elif kind == "frame_boundary":
            frame_id = int(event["frame_id"])
            if frame_id != len(config_by_frame):
                raise TraceContractError(
                    f"epoch {epoch}: non-monotonic core frame id {frame_id}")
            if bool(event.get("config_pending", False)) and pending_config is None:
                raise TraceContractError(
                    "frame boundary reports pending configuration without a modeled COMMIT")
            if pending_config is not None and bool(event.get("config_pending", False)):
                if not cdc_pending_seen:
                    raise TraceContractError(
                        "frame-boundary apply precedes recorded CDC pending")
                active_config = pending_config
                pending_config = None
                cdc_pending_seen = False
                applied_frames.append(frame_id)
            config_by_frame[frame_id] = active_config
        elif kind == "config_ack_core":
            if not applied_frames or not status["busy"]:
                raise TraceContractError(
                    "core configuration ACK occurred before a modeled frame apply")
            core_ack_seen = True
        elif kind == "commit_done":
            if not status["busy"] or not core_ack_seen or pending_config is not None:
                raise TraceContractError(
                    "AXI-Lite COMMIT completed without frame apply, ACK, and active epoch")
            status["busy"] = False
            status["done"] = True
            core_ack_seen = False
        elif kind == "source_beat":
            beat_index = int(event.get("beat_index", expected_beat_index))
            if beat_index != expected_beat_index:
                raise TraceContractError(
                    f"epoch {epoch}: source beat index {beat_index}, "
                    f"expected {expected_beat_index}")
            if bool(event.get("frame_start", False)):
                if source_frame_seen:
                    observed_frame_id += 1
                source_frame_seen = True
            if "source_frame_id" in event and int(event["source_frame_id"]) != observed_frame_id:
                raise TraceContractError(
                    f"epoch {epoch}: source frame id {event['source_frame_id']}, "
                    f"expected {observed_frame_id}")
            if "packet_id" in event and int(event["packet_id"]) != packet_id:
                raise TraceContractError(
                    f"epoch {epoch}: packet id {event['packet_id']}, expected {packet_id}")
            if "packet_beat_index" in event and int(event["packet_beat_index"]) != packet_beats:
                raise TraceContractError(
                    f"epoch {epoch}: packet beat index {event['packet_beat_index']}, "
                    f"expected {packet_beats}")
            source_beats.append(event)
            packet_beats += 1
            expected_beat_index += 1
            if bool(event.get("tlast", False)):
                if packet_beats % 32:
                    raise TraceContractError(
                        f"epoch {epoch}: TLAST after {packet_beats} beats; expected a multiple of 32")
                packet_beats = 0
                packet_id += 1
        elif kind == "pa_word":
            if "word_index" in event and int(event["word_index"]) != len(actual_pa):
                raise TraceContractError(
                    f"epoch {epoch}: PA word index {event['word_index']}, "
                    f"expected {len(actual_pa)}")
            planes = tuple(_number(word) & ((1 << 64) - 1)
                           for word in event["planes"])
            if len(planes) != 4:
                raise TraceContractError("PA transaction must contain four 64-bit planes")
            actual_pa.append(planes)
        elif kind == "underflow":
            underflow_events += 1
        elif kind in ("reset", "source_gap", "pa_stall", "axil_read",
                      "axil_read_response", "axil_write_response", "status_sample",
                      "stop_state"):
            # These events are retained for protocol/status audit. Underflow is
            # reported separately so normal/negative classification remains an
            # explicit caller decision.
            continue
        else:
            raise TraceContractError(f"epoch {epoch}: unknown trace event {kind!r}")

    if expected_write_responses:
        raise TraceContractError(
            f"epoch {epoch}: {len(expected_write_responses)} AXI-Lite B responses missing")
    if (not reset_terminated and
            (pending_config is not None or cdc_pending_seen or
             status["busy"] or core_ack_seen)):
        raise TraceContractError(
            f"epoch {epoch}: trace ended before COMMIT reached STATUS completion")
    if not source_beats and not actual_pa:
        # Reset-only epochs can contain control/status traffic but no payload.
        (status_reads_checked, status_reads_transition_masked, source_gap_events,
         source_gap_cycles, observed_stop_states) = _model_system_status(epoch, events)
        return EpochResult(epoch, (), (), 0, (), underflow_events,
                           reset_terminated, 0, 0, status_reads_checked,
                           status_reads_transition_masked, source_gap_events,
                           source_gap_cycles, observed_stop_states)
    if packet_beats and not reset_terminated:
        raise TraceContractError(
            f"epoch {epoch}: trace ended with {packet_beats} beats after the last TLAST")
    samples_i, samples_q = [], []
    frame_starts, frame_gains = [], []
    for beat_index, beat in enumerate(source_beats):
        i_values, q_values = beat.get("i", ()), beat.get("q", ())
        if len(i_values) != 14 or len(q_values) != 14:
            raise TraceContractError("each accepted AXIS beat must contain 14 I and Q samples")
        if bool(beat.get("frame_start", False)):
            if len(samples_i) % 56:
                raise TraceContractError(
                    f"frame start at beat {beat_index} is not 56-sample aligned")
            word_index = len(samples_i) // 8
            if len(frame_starts) < word_index:
                frame_starts.extend([0] * (word_index - len(frame_starts)))
                frame_gains.extend([Q14_ONE] * (word_index - len(frame_gains)))
            if len(frame_starts) == word_index:
                frame_starts.append(1)
                frame_gains.append(int(beat.get("frame_gain", Q14_ONE)))
            else:
                frame_starts[word_index] = 1
                frame_gains[word_index] = int(beat.get("frame_gain", Q14_ONE))
        samples_i.extend(_signed16(value) for value in i_values)
        samples_q.extend(_signed16(value) for value in q_values)

    if len(samples_i) != len(samples_q):
        raise TraceContractError("accepted source I/Q sample counts differ")
    if len(samples_i) % 8:
        if not reset_terminated:
            raise TraceContractError("accepted source epoch is not aligned to 8-sample core words")
        complete_samples = len(samples_i) - (len(samples_i) % 8)
        del samples_i[complete_samples:]
        del samples_q[complete_samples:]
    available_samples = len(samples_i)
    if len(samples_i) % 8:
        raise TraceContractError("accepted source epoch is not aligned to 8-sample core words")
    if len(samples_i) % 56:
        if not reset_terminated:
            raise TraceContractError(
                "normal trace epoch requires complete 56-sample frames at its end")
        padded_samples = ((len(samples_i) + 55) // 56) * 56
        padding = padded_samples - len(samples_i)
        samples_i.extend([0] * padding)
        samples_q.extend([0] * padding)
    if reset_terminated:
        complete_frames, partial_frame_samples = divmod(available_samples, 56)
        safe_partial_words = min(
            7, max(0, (partial_frame_samples - 11) // 8 + 1))
        safe_output_words = complete_frames * 7 + safe_partial_words
    else:
        safe_output_words = (available_samples // 56) * 7
    words = len(samples_i) // 8
    if len(frame_starts) < words:
        frame_starts.extend([0] * (words - len(frame_starts)))
        frame_gains.extend([Q14_ONE] * (words - len(frame_gains)))
    elif len(frame_starts) > words:
        raise TraceContractError("frame marker lies beyond accepted source data")
    if not words or not frame_starts[0]:
        raise TraceContractError("first accepted source beat must carry FRAME_START")
    if any(frame_starts[index] and index % 7 for index in range(words)):
        raise TraceContractError("DSP frame starts must align to seven 8-sample core words")
    source_frame_count = sum(bool(flag) for flag in frame_starts)
    if (config_by_frame and
            ((not reset_terminated and len(config_by_frame) != source_frame_count) or
             (reset_terminated and len(config_by_frame) > source_frame_count))):
        raise TraceContractError(
            f"epoch {epoch}: observed {len(config_by_frame)} accepted core frame "
            f"boundaries for {source_frame_count} source frame starts")

    i_words = [samples_i[index:index + 8] for index in range(0, len(samples_i), 8)]
    q_words = [samples_q[index:index + 8] for index in range(0, len(samples_q), 8)]
    dpd_configs = []
    frame_id = -1
    for word_index in range(words):
        if frame_starts[word_index]:
            frame_id += 1
            dpd_configs.append(config_by_frame.get(frame_id))
    expected_pa = run_centered_cubic_frontend(
        i_words, q_words, frame_starts, frame_gains, step=step,
        tidsm_order=tidsm_order, dpd_configs_by_frame=dpd_configs)
    expected_pa = tuple(tuple(int(value) for value in word) for word in expected_pa)
    actual_pa_tuple = tuple(actual_pa)
    if reset_terminated:
        if len(actual_pa_tuple) > safe_output_words:
            raise TraceContractError(
                f"epoch {epoch}: reset accepted {len(actual_pa_tuple)} PA words, "
                f"but only {safe_output_words} have sufficient accepted input history")
        matches = (len(actual_pa_tuple) <= len(expected_pa) and
                   expected_pa[:len(actual_pa_tuple)] == actual_pa_tuple)
    else:
        matches = expected_pa == actual_pa_tuple
    if compare and not matches:
        mismatch = next((index for index, pair in enumerate(zip(expected_pa, actual_pa_tuple))
                         if pair[0] != pair[1]), min(len(expected_pa), len(actual_pa_tuple)))
        raise AssertionError(
            f"epoch {epoch}: PA mismatch at word {mismatch}; "
            f"expected_count={len(expected_pa)} actual_count={len(actual_pa_tuple)}")
    compared_words = (len(actual_pa_tuple) if reset_terminated else
                      min(len(expected_pa), len(actual_pa_tuple)))
    discarded_model_words = (max(0, len(expected_pa) - len(actual_pa_tuple))
                             if reset_terminated else 0)
    (status_reads_checked, status_reads_transition_masked, source_gap_events,
     source_gap_cycles, observed_stop_states) = _model_system_status(epoch, events)
    return EpochResult(epoch, expected_pa, actual_pa_tuple, compared_words,
                       tuple(applied_frames), underflow_events, reset_terminated,
                       discarded_model_words, safe_output_words,
                       status_reads_checked, status_reads_transition_masked,
                       source_gap_events, source_gap_cycles, observed_stop_states)


def run_monitor_trace(trace, *, step=5120, tidsm_order=2, max_taps=1,
                      compare=True):
    """Decode monitor JSONL records and compare every accepted PA word.

    Reset records partition the trace into independent epochs. A reset-ended
    epoch may have no TLAST or final FIR drain: incomplete core samples are
    discarded, the reference is zero-padded only to form a model frame, and
    comparison is limited to PA words actually accepted before reset. The
    unaccepted model suffix is reported as reset-discarded work.
    """
    events = _read_events(trace)
    _validate_event_sequence(events)
    epochs = {}
    reset_terminated = set()
    current_epoch = int(events[0].get("epoch", 0)) if events else 0
    for event in events:
        event_epoch = int(event.get("epoch", current_epoch))
        if event.get("type") == "reset":
            epochs.setdefault(event_epoch, [])
            if event_epoch != current_epoch:
                raise TraceContractError(
                    f"reset event belongs to epoch {event_epoch}, expected {current_epoch}")
            reset_terminated.add(event_epoch)
            next_epoch = int(event.get("next_epoch", event_epoch + 1))
            if next_epoch != event_epoch + 1:
                raise TraceContractError(
                    f"reset epoch transition {event_epoch}->{next_epoch} is not consecutive")
            current_epoch = next_epoch
            epochs.setdefault(current_epoch, [])
            continue
        if event_epoch != current_epoch:
            raise TraceContractError(
                f"event epoch {event_epoch} appears while current epoch is {current_epoch}")
        epochs.setdefault(event_epoch, []).append(event)
    if not epochs:
        raise TraceContractError("trace contains no events")
    return tuple(_model_epoch(epoch, epoch_events, step=step,
                              tidsm_order=tidsm_order, max_taps=max_taps,
                              compare=compare,
                              reset_terminated=epoch in reset_terminated)
                 for epoch, epoch_events in sorted(epochs.items()))
