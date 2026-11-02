# Thermo5 TX Transaction and Verification Contract

## Scope and product configuration

This contract describes the current TX-only Linux verification configuration:
Centered-Cubic interpolation enabled for both x2 stages, EF2 TIDSM order 2,
STEP 5120, one active DPD tap with the reset-loaded identity image, Generic
asynchronous FIFO, and the AXI-Lite TX wrapper where control-plane behavior is
under test. The contract is derived from `tid32_thermo5_axi_lite_axis_frontend_tx`,
`dsm_axis14_to_core8_cdc`, `tid32_thermo5_frontend_tx`, and the UVM interfaces.

## Accepted transactions and identifiers

- **AXIS beat:** one handshake (`TVALID && TREADY`) transfers 14 signed 16-bit
  complex I/Q samples. Lane 0 is earliest. `TUSER_FRAME_START` and gain belong
  to the accepted beat; they are not sampled from an unaccepted presentation.
- **DSP frame:** a frame start is legal only at a 56-complex-sample boundary:
  four AXIS beats or seven 8-sample core words. The source marker must survive
  the gearbox with zero residual samples. The frame gain is selected at the
  accepted frame-start word. The same marker is the DPD configuration boundary
  after it traverses the frontend elastic path.
- **AXIS packet:** in the AXI-Lite wrapper, an accepted `TLAST` is legal when
  the accepted-beat phase is 31 modulo 32. Thus each packet is a positive
  multiple of 32 beats (448 samples, eight DSP frames). An early `TLAST` sets
  sticky protocol-error status but does not repair or shift gearbox alignment.
- **PA word:** the four 64-bit planes form one atomic output transaction. A
  transfer occurs only when all four `PA_VALID` and all four `PA_READY` bits
  are high. Partial `PA_READY` is legal backpressure; partial `PA_VALID` is a
  DUT protocol failure. Accepted PA words are ordered and compared against
  the same epoch's expected word index.
- **Reset epoch:** source and core resets are asserted together by the current
  testbench control BFM; AXI-Lite reset is synchronously derived from core
  reset. A reset discards queued, partial, and in-flight work and clears
  datapath/config state. No pre-reset sample may be matched to a post-reset PA
  word. The scoreboard restarts source/PA sequence indices at the epoch edge.

The existing source monitor supplies an accepted-beat index, the AXI-Lite
monitor supplies transaction IDs and sampled event cycles, and the PA monitor
publishes only accepted four-plane words. The optional JSONL recorder adds a
monotonic trace-event sequence, an epoch-local packet ID/beat index (advanced
only on accepted source beats and `TLAST`), a source frame ID (advanced only
on accepted `FRAME_START`), and an epoch-local accepted PA word index. Core
frame-boundary events have their own frame ID and are checked against the
accepted source frame sequence. The output association key is
`(reset_epoch, pa_word_index)`; expected data is calculated from accepted
source transactions and the configuration image reconstructed from AXI-Lite
write-fire, CDC-pending, and accepted frame-boundary events. The DUT's active
configuration payload and PA data are never inputs to expected-data
generation; PA data is used only as the comparison target.

## Flow control, STOP, drain, and underflow

Source gaps are allowed while the source is not backpressured, but the RTL
specifies no maximum safe gap. Before RUN, the wrapper requires two accepted
source beats to cross the FIFO before starting the gearbox. During an active
stream, if the gearbox has started and becomes empty outside drain, the RTL
sets sticky `core_underflow`. Therefore a legal normal-stream gap is one for
which the accepted-data backlog prevents underflow; a fixed maximum gap must
not be assumed without a measured directed test.

The source monitor counts `TVALID=0` source-clock cycles between accepted
beats. A beat held with `TVALID=1` while `TREADY=0` is backpressure, not a
source gap. The trace stores the measured gap length and the independently
observed underflow event. The checker does not infer a universal safe gap from
the gap length alone: safety depends on FIFO/core backlog and PA backpressure.
Normal regressions require zero underflow. A deliberate starvation test is
classified separately and passes only when its expected underflow is observed
and its accepted output prefix remains bit-true. The existing empty-FIFO test
is the intentional starvation case.

RUN is a request synchronized into the core clock domain. Clearing RUN closes
new ingress only after the already-open packet is accepted through its legal
`TLAST`; the core then drains FIFO/gearbox residuals, datapath pipeline, and
all four-plane output transactions. `core_tx_active` remains asserted through
drain and clears only when the drain predicate is satisfied. A subsequent RUN
waits for two newly accepted beats after the completed drain. STOP without a
packet-closing `TLAST` is not a legal completed-drain scenario.

Reset during a transaction is a separately classified recovery test. The
checker records the pre-reset accepted prefix, permits that epoch's queued
work to be discarded, and requires the first post-reset output to match only
post-reset input. A reset is not a normal-stream flush and is excluded from
the no-loss assertion across epochs. If Reset truncates an incomplete
56-sample DSP frame, the Python model may zero-pad only to construct a
candidate full-frame reference. It compares no padded-dependent output. For a
partial frame with `N` accepted, complete 8-sample core input samples, output
word `k` is safe only if the frame has at least `8*k + 11` known samples; thus
the safe partial-frame count is
`min(7, max(0, floor((N - 11)/8) + 1))`. Each complete earlier frame adds
seven safe words. An observed PA count beyond this bound is a trace-contract
failure, even if the padded model happens to match.

## AXI-Lite configuration epochs

AXI-Lite AW and W are independent channels; a register write takes effect only
after both handshakes and the internal write-fire edge. The register predictor
uses that edge, not the delayed B response, as write acceptance. Shadow writes,
COMMIT acceptance, request crossing into the core domain, pending-bank
observation, and activation on an accepted DPD frame-start transfer are
distinct events. STATUS reads return the value sampled at the AR handshake;
RUN_ACTIVE and DRAINING are synchronized views and must be predicted using
the AXI-Lite sampling edge and the RTL's synchronizer/event priority.

The UVM and Python STATUS models derive RUN/Drain expectations independently
from the DUT `core_tx_active` and `core_draining` status outputs. They use
accepted AXIS packet/TLAST transactions, AXI-Lite RUN/STOP writes, accepted
four-plane PA words, and the specified two-beat startup and packet-drain
contract. A four-AXI-clock settling window covers the RUN/STOP crossing and the
two-stage return synchronizer. In that transition window, only STATUS bits
RUN_ACTIVE and DRAINING are masked; BUSY, DONE, ERROR, read response, and
transaction association remain checked. Stable lifecycle reads compare all
five defined bits. The core `stop_state` trace is corroborating evidence and
does not drive the predicted value. Config COMMIT is checked in the order
write-fire, CDC pending, frame-boundary apply, core ACK, then AXI-Lite
completion/STATUS. The predictor also checks shadow-register readback, WSTRB
merges, write response codes, read response codes, and transaction
association.

## Error classification

Normal regressions require no source protocol violation, no unexpected
underflow, no loss/duplication/reorder, no four-plane mismatch, no wrong
configuration epoch, no deadlock, and no unexpected assertion failure.
Malformed early TLAST, invalid tap count, busy COMMIT, mailbox fault injection,
and reset during pending configuration belong to separate negative tests with
explicit expected response/error/recovery checks. They are not included in the
normal-pass count.

The dynamic Python trace oracle checks global recorder sequence numbers,
consecutive Reset epochs, accepted source and PA indices, packet/frame
alignment, config event order, independent STATUS reads, STOP/Drain/Restart
observations, and four-plane bit-true data. It reports source gap lengths and
underflow separately. The VCS scoreboard continues to compare the same output
against the frozen static vector files, providing a static-Golden cross-check
of the new monitor-derived oracle. Four additional product Reset cases stop
after 1, 2, 3, and 5 accepted source beats, including partial core words and a
partial DSP frame; the oracle confirms that no accepted PA word exceeds the
causal safe-prefix limit. Five residual-state Reset cases and a full
post-reset replay remain in the same directed regression.

## Phase 0–2 implementation status

Phase A dynamic-oracle closure is implemented and exercised on the Linux
Generic FIFO product configuration. Focused VCS evidence includes the existing
two-packet STOP/Drain/Restart sequence, a one-source-clock-cycle gap variant,
and the Reset Sweep with four partial-frame prefixes and five CDC residual
resets. All 112 STOP/Restart PA words and all 56 post-reset replay words match
the frozen static vectors; both traces pass the independent Python oracle with
zero underflow. The one-cycle gap trace records one gap event / one source
cycle and zero underflow. Python negative mutations detect a corrupted PA
word, corrupted STATUS, reordered trace sequence, and Frame Apply before CDC
Pending. Phase B/C Agent coordination and constrained-random seed replay
remain open. No DUT algorithm or RTL changed, and no code-coverage or Formal
signoff is claimed.

The core clean-trace replay command is:

```bash
PYTHONPATH=dv/uvm/refmodel/python python3.12 \
  dv/uvm/refmodel/python/check_thermo5_monitor_trace.py \
  runs/stop_restart_trace.jsonl --step 5120 --tidsm-order 2 --max-taps 1
```
