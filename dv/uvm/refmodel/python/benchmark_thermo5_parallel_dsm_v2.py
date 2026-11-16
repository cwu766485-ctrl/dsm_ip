#!/usr/bin/env python3
"""Communication screen for non-Bit-True parallel second-order DSM candidates."""

import argparse
import copy
import csv
import json
import math
import statistics
from pathlib import Path

from benchmark_thermo5_arch_ablation import _spectrum
from benchmark_thermo5_tid_receiver import (
    NCP,
    NFFT,
    RAW_FS_HZ,
    RX_FIR_TAPS,
    SOURCE_FS_HZ,
    _blackman_lowpass,
    _linear_fir_decimate,
    demodulate_metrics,
    make_256qam_ofdm,
    receive_filter_decimate,
    reconstruct_baseband_7g,
)
from dsm_refmodel.thermo5_experiments import (
    generate_thermo5_tidsm_planes,
    pack_fs4_branch_streams,
)
from dsm_refmodel.thermo5_receiver import interpolate_x4


Q = 1 << 15
STATE_W = 20
STATE_MIN = -(1 << (STATE_W - 1))
STATE_MAX = (1 << (STATE_W - 1)) - 1
BRANCH_OFFSETS = (3 * 5120, 5120, -5120, -3 * 5120)


def _clip(value, low, high):
    return min(max(value, low), high)


def _mash11_component(samples, return_stages=False):
    """MASH 1-1 using e1 as stage-2 input and q1 + (1-z^-1)q2."""
    e1 = e2 = q2_delay = 0
    result = []
    stage1 = []
    stage2 = []
    stage1_error = []
    stage2_error = []
    clips = 0
    max_state = 0
    for sample in samples:
        x = _clip(int(sample), -Q, Q - 1)
        u1 = x + e1
        q1 = Q if u1 > 0 else -Q
        e1_raw = u1 - q1
        e1_next = _clip(e1_raw, STATE_MIN, STATE_MAX)
        u2 = e1_next + e2
        q2 = Q if u2 > 0 else -Q
        e2_raw = u2 - q2
        e2_next = _clip(e2_raw, STATE_MIN, STATE_MAX)
        result.append(q1 + q2 - q2_delay)
        stage1.append(q1)
        stage2.append(q2)
        stage1_error.append(e1_next)
        stage2_error.append(e2_next)
        clips += int(e1_next != e1_raw) + int(e2_next != e2_raw)
        max_state = max(max_state, abs(e1_next), abs(e2_next))
        e1, e2, q2_delay = e1_next, e2_next, q2
    stats = {"state_saturations": clips, "max_abs_state_lsb": max_state,
             "final_state_lsb": [e1, e2, q2_delay]}
    if return_stages:
        return result, stats, stage1, stage2, stage1_error, stage2_error
    return result, stats


def _receive_weighted_mash(samples_i, samples_q, stimulus, fir_taps):
    raw = []
    for index, (value_i, value_q) in enumerate(zip(samples_i, samples_q)):
        if index & 1:
            raw.extend((-value_i / Q, value_q / Q))
        else:
            raw.extend((value_i / Q, -value_q / Q))
    phase = (1.0 + 0.0j, -1.0j, -1.0 + 0.0j, 1.0j)
    ddc = [2.0 * value * phase[index & 3] for index, value in enumerate(raw)]
    cutoff = 0.75 * stimulus["actual_bandwidth_hz"]
    baseband_7g = _linear_fir_decimate(
        ddc, _blackman_lowpass(cutoff, RAW_FS_HZ, fir_taps), 2, phase=0)
    baseband, _ = receive_filter_decimate(
        baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    return baseband_7g, baseband


def _encode_three_equal_mash(samples_i, samples_q):
    """Encode exact {-3,-1,+1,+3} MASH levels on three bipolar PA planes.

    Plane bits are thermometer coded. The fourth product plane is physically
    absent in this model; a zero data word on a live fourth PA is not modeled
    as an equivalent substitute.
    """
    if len(samples_i) != len(samples_q) or len(samples_i) % 32:
        raise ValueError("three-plane I/Q streams must have equal 32-sample frames")
    words = []
    reconstructed_i = []
    reconstructed_q = []
    mute_mask = []
    for first in range(0, len(samples_i), 32):
        plane_words = [0, 0, 0]
        for lane in range(32):
            index = first + lane
            for component, sample in ((0, samples_i[index]),
                                      (1, samples_q[index])):
                if sample not in (-3 * Q, -2 * Q, -Q, 0, Q, 2 * Q, 3 * Q):
                    raise ValueError("MASH output is outside the supported three-PA range")
                muted = sample == 0
                if sample in (-2 * Q, 2 * Q):
                    raise ValueError("even nonzero MASH levels need a different PA contract")
                positive_count = (sample // Q + 3) // 2 if not muted else 0
                reconstructed = 0
                for plane in range(3):
                    positive = plane < positive_count
                    bipolar = 1 if positive else -1
                    reconstructed += bipolar
                    if component == 0:
                        raw_bit = positive if lane % 2 == 0 else not positive
                        bit_index = 2 * lane
                    else:
                        raw_bit = not positive if lane % 2 == 0 else positive
                        bit_index = 2 * lane + 1
                    if raw_bit:
                        plane_words[plane] |= 1 << bit_index
                decoded = 0 if muted else reconstructed
                if decoded != sample // Q:
                    raise AssertionError("three-plane thermometer decode mismatch")
                (reconstructed_i if component == 0 else reconstructed_q).append(
                    decoded * Q)
                if muted:
                    mute_mask.append((index, component))
        words.append(tuple(plane_words))
    return words, reconstructed_i, reconstructed_q, mute_mask


def _receive_three_equal_mash(samples_i, samples_q, stimulus, fir_taps):
    """Run the exact three-active-plane Fs/4 stream through the common RX."""
    words, decoded_i, decoded_q, mute_mask = _encode_three_equal_mash(
        samples_i, samples_q)
    raw = []
    for index, (value_i, value_q) in enumerate(zip(decoded_i, decoded_q)):
        if index & 1:
            raw.extend((-value_i / Q, value_q / Q))
        else:
            raw.extend((value_i / Q, -value_q / Q))
    cutoff = 0.75 * stimulus["actual_bandwidth_hz"]
    baseband_7g = _linear_fir_decimate(
        [2.0 * value * (1.0 + 0.0j, -1.0j, -1.0 + 0.0j, 1.0j)[i & 3]
         for i, value in enumerate(raw)],
        _blackman_lowpass(cutoff, RAW_FS_HZ, fir_taps), 2, phase=0)
    baseband, _ = receive_filter_decimate(
        baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    return words, decoded_i, decoded_q, mute_mask, baseband_7g, baseband


def _encode_five_level_words(level_i, level_q):
    """Encode {-2,-1,+1,+2} as five-level four-plane thermometer data."""
    if len(level_i) != len(level_q) or not level_i or len(level_i) % 32:
        raise ValueError("level streams must be equal, nonempty, and 32-sample aligned")
    words = []
    for first in range(0, len(level_i), 32):
        planes = [0, 0, 0, 0]
        for lane in range(32):
            index = first + lane
            positives_i = (0 if level_i[index] < 0 else 4) if abs(level_i[index]) == 2 \
                else (1 if level_i[index] < 0 else 3)
            positives_q = (0 if level_q[index] < 0 else 4) if abs(level_q[index]) == 2 \
                else (1 if level_q[index] < 0 else 3)
            for plane in range(4):
                bit_i = plane < positives_i
                bit_q = plane < positives_q
                raw_i = bit_i if lane % 2 == 0 else not bit_i
                raw_q = not bit_q if lane % 2 == 0 else bit_q
                if raw_i:
                    planes[plane] |= 1 << (2 * lane)
                if raw_q:
                    planes[plane] |= 1 << (2 * lane + 1)
        words.append(tuple(planes))
    return words


def _mash11_planes(samples_i, samples_q):
    mash_i, stats_i = _mash11_component(samples_i)
    mash_q, stats_q = _mash11_component(samples_q)
    # Bit reduction maps MASH levels +/-Q to +/-0.5 and +/-3Q to +/-1.0.
    # This nonlinear mapping is part of the candidate and changes the NTF.
    level_i = [(-2 if value < 0 else 2) if abs(value) >= 2 * Q else
               (-1 if value < 0 else 1) for value in mash_i]
    level_q = [(-2 if value < 0 else 2) if abs(value) >= 2 * Q else
               (-1 if value < 0 else 1) for value in mash_q]
    stats = {
        "i_state_saturations": stats_i["state_saturations"],
        "q_state_saturations": stats_q["state_saturations"],
        "max_abs_state_lsb": max(stats_i["max_abs_state_lsb"],
                                  stats_q["max_abs_state_lsb"]),
        "bit_reduction": "MASH +/-1 -> five-level +/-0.5; +/-3 -> +/-1",
        "ntf_before_bit_reduction": "(1-z^-1)^2",
        "step_applicability": "same input drive; STEP=5120 is not used by the 1-bit MASH quantizers",
    }
    return _encode_five_level_words(level_i, level_q), stats


def _polyphase_ef2_component(samples, offset, phases=32):
    """32-phase block DSM: each phase has NTF (1-z_block^-1)^2."""
    output = [0] * len(samples)
    clips = 0
    max_state = 0
    final_states = []
    for phase in range(phases):
        e1 = e2 = 0
        for index in range(phase, len(samples), phases):
            raw = int(samples[index]) + int(offset)
            x = _clip(raw, -Q, Q - 1)
            u = x + 2 * e1 - e2
            y = Q if u > 0 else -Q
            error_raw = u - y
            e1_next = _clip(error_raw, STATE_MIN, STATE_MAX)
            clips += int(x != raw) + int(e1_next != error_raw)
            output[index] = 1 if y > 0 else -1
            e2, e1 = e1, e1_next
            max_state = max(max_state, abs(e1), abs(e2))
        final_states.append([e1, e2])
    return output, {"input_and_state_saturations": clips,
                    "max_abs_state_lsb": max_state,
                    "final_phase_states_lsb": final_states}


def _polyphase_ef2_planes(samples_i, samples_q):
    branches_i = []
    branches_q = []
    branch_stats = []
    for offset in BRANCH_OFFSETS:
        i_bits, si = _polyphase_ef2_component(samples_i, offset)
        q_bits, sq = _polyphase_ef2_component(samples_q, offset)
        branches_i.append(i_bits)
        branches_q.append(q_bits)
        branch_stats.append({"offset": offset, "i": si, "q": sq})
    return pack_fs4_branch_streams(branches_i, branches_q), {
        "phases": 32,
        "ntf_per_phase_in_vector_time": "(1-z_block^-1)^2",
        "scalar_stream_ntf": "(1-z^-32)^2; differs from Legacy EF2 (1-z^-1)^2",
        "branch_stats": branch_stats,
        "max_abs_state_lsb": max(
            max(item["i"]["max_abs_state_lsb"], item["q"]["max_abs_state_lsb"])
            for item in branch_stats),
        "final_phase_states_lsb": [
            {"offset": item["offset"], "i": item["i"]["final_phase_states_lsb"],
             "q": item["q"]["final_phase_states_lsb"]} for item in branch_stats],
        "state_saturations": sum(
            item["i"]["input_and_state_saturations"] +
            item["q"]["input_and_state_saturations"] for item in branch_stats),
        "step": 5120,
    }


def _case(seed, symbols, fir_taps, candidate, qam_order):
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=0.09,
                                qam_order=qam_order)
    interpolated = interpolate_x4(stimulus["source_iq"], method="centered_cubic")
    samples_i = [pair[0] for pair in interpolated]
    samples_q = [pair[1] for pair in interpolated]
    if candidate == "cubic_ef1":
        planes, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 5120, mode="rtl_first_order",
            rtl_latency_samples=0)
    elif candidate == "cubic_ef2":
        planes, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 5120, mode="ef_order2_fixed", state_width=20)
    elif candidate in ("cubic_mash11_weighted_dualpa",
                       "cubic_mash11_three_equal_pa",
                       "cubic_mash11_bit_reduced"):
        if candidate == "cubic_mash11_weighted_dualpa":
            mash_i, stats_i, stage1_i, stage2_i, _, _ = _mash11_component(
                samples_i, return_stages=True)
            mash_q, stats_q, stage1_q, stage2_q, _, _ = _mash11_component(
                samples_q, return_stages=True)
            _, three_i, three_q, mute_i = _encode_three_equal_mash(mash_i, mash_q)
            if three_i != mash_i or three_q != mash_q:
                raise AssertionError("three-active-plane mapping changed MASH samples")
            stats = {"i_state_saturations": stats_i["state_saturations"],
                     "q_state_saturations": stats_q["state_saturations"],
                     "max_abs_state_lsb": max(stats_i["max_abs_state_lsb"],
                                               stats_q["max_abs_state_lsb"]),
                     "digital_samples_compared": 2 * len(mash_i),
                     "digital_mismatches": 0,
                     "sample_rate_pa_mutes": len(mute_i),
                     "zero_reset_output_samples": sum(value == 0 for value in mash_i) +
                         sum(value == 0 for value in mash_q),
                     "output_levels": [-3, -1, 1, 3],
                     "output_interface": "historical two-PA weights 1:2"}
            baseband_7g, baseband = _receive_weighted_mash(
                mash_i, mash_q, stimulus, fir_taps)
            metrics = demodulate_metrics(baseband, stimulus)
            spectrum = _spectrum(
                baseband_7g, SOURCE_FS_HZ * 4.0,
                stimulus["actual_bandwidth_hz"], image_centers_hz=(SOURCE_FS_HZ,))
            stage_signals = {
                "stage1_q1": [complex(i, q) / Q for i, q in zip(stage1_i, stage1_q)],
                "stage2_q2": [complex(i, q) / Q for i, q in zip(stage2_i, stage2_q)],
                "uncancelled_q1_plus_q2": [complex(i1 + i2, q1 + q2) / Q
                                             for i1, q1, i2, q2 in zip(
                                                 stage1_i, stage1_q, stage2_i, stage2_q)],
                "cancelled_q1_plus_diff_q2": [complex(i, q) / Q
                                               for i, q in zip(mash_i, mash_q)],
            }
            stage_psd = {
                name: _spectrum(signal, SOURCE_FS_HZ * 4.0,
                               stimulus["actual_bandwidth_hz"])["relative_psd_db"]
                for name, signal in stage_signals.items()
            }
            return {
                "candidate": candidate, "seed": seed, "symbols": symbols,
                "qam_order": qam_order, "rms_drive": 0.09, "step": 5120,
                "interpolation": "centered cubic x4 Q14 bit-true model",
                "rx_fir_taps": fir_taps,
                "pa_model": "disabled; historical dual-PA weights 1:2",
                "metrics": metrics,
                "adjacent_band_proxy_dbc": spectrum["adjacent_band_proxy_dbc"],
                "relative_psd_db": spectrum["relative_psd_db"],
                "stage_psd_db": stage_psd,
                "model_diagnostics": stats, "model_only": True,
                "bittrue_to_legacy_ef2": False,
            }
        if candidate == "cubic_mash11_three_equal_pa":
            mash_i, stats_i, stage1_i, stage2_i, _, _ = _mash11_component(
                samples_i, return_stages=True)
            mash_q, stats_q, stage1_q, stage2_q, _, _ = _mash11_component(
                samples_q, return_stages=True)
            _, decoded_i, decoded_q, mute_mask, baseband_7g, baseband = \
                _receive_three_equal_mash(mash_i, mash_q, stimulus, fir_taps)
            if decoded_i != mash_i or decoded_q != mash_q:
                raise AssertionError("three-plane digital reconstruction differs from MASH")
            stats = {"i_state_saturations": stats_i["state_saturations"],
                     "q_state_saturations": stats_q["state_saturations"],
                     "max_abs_state_lsb": max(stats_i["max_abs_state_lsb"],
                                               stats_q["max_abs_state_lsb"]),
                     "output_levels": [-3, -1, 1, 3],
                     "digital_samples_compared": len(mash_i) + len(mash_q),
                     "digital_mismatches": 0,
                     "sample_mute_count": len(mute_mask),
                     "sample_mute_contract": "requires raw-sample-slot common all-PA blanking for exact zero reset level",
                     "active_pa_planes": 3,
                     "fourth_pa_contract": "physically disabled; not represented by zero data"}
            metrics = demodulate_metrics(baseband, stimulus)
            spectrum = _spectrum(
                baseband_7g, SOURCE_FS_HZ * 4.0,
                stimulus["actual_bandwidth_hz"], image_centers_hz=(SOURCE_FS_HZ,))
            stage_signals = {
                "stage1_q1": [complex(i, q) / Q for i, q in zip(stage1_i, stage1_q)],
                "stage2_q2": [complex(i, q) / Q for i, q in zip(stage2_i, stage2_q)],
                "cancelled_q1_plus_diff_q2": [complex(i, q) / Q
                                               for i, q in zip(mash_i, mash_q)],
            }
            stage_psd = {
                name: _spectrum(signal, SOURCE_FS_HZ * 4.0,
                               stimulus["actual_bandwidth_hz"])["relative_psd_db"]
                for name, signal in stage_signals.items()
            }
            return {
                "candidate": candidate, "seed": seed, "symbols": symbols,
                "qam_order": qam_order, "rms_drive": 0.09, "step": 5120,
                "interpolation": "centered cubic x4 Q14 bit-true model",
                "rx_fir_taps": fir_taps,
                "pa_model": "three equal bipolar PA planes; fourth physically disabled",
                "metrics": metrics,
                "adjacent_band_proxy_dbc": spectrum["adjacent_band_proxy_dbc"],
                "relative_psd_db": spectrum["relative_psd_db"],
                "stage_psd_db": stage_psd,
                "model_diagnostics": stats, "model_only": True,
                "bittrue_to_legacy_ef2": False,
            }
        planes, stats = _mash11_planes(samples_i, samples_q)
    elif candidate == "cubic_polyphase_ef2_32":
        planes, stats = _polyphase_ef2_planes(samples_i, samples_q)
    else:
        raise ValueError(candidate)
    baseband_7g, _ = reconstruct_baseband_7g(
        planes, stimulus["actual_bandwidth_hz"], latency_samples=0,
        fir_taps=fir_taps)
    baseband, _ = receive_filter_decimate(
        baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    metrics = demodulate_metrics(baseband, stimulus)
    spectrum = _spectrum(
        baseband_7g, SOURCE_FS_HZ * 4.0,
        stimulus["actual_bandwidth_hz"], image_centers_hz=(SOURCE_FS_HZ,))
    return {
        "candidate": candidate,
        "seed": seed,
        "symbols": symbols,
        "qam_order": qam_order,
        "rms_drive": 0.09,
        "step": 5120,
        "interpolation": "centered cubic x4 Q14 bit-true model",
        "rx_fir_taps": fir_taps,
        "pa_model": "disabled; digital-only common receiver",
        "metrics": metrics,
        "adjacent_band_proxy_dbc": spectrum["adjacent_band_proxy_dbc"],
        "relative_psd_db": spectrum["relative_psd_db"],
        "model_diagnostics": stats,
        "model_only": True,
        "bittrue_to_legacy_ef2": False if "ef2" in candidate or "mash" in candidate else None,
    }


def run(seeds, symbols=8, fir_taps=RX_FIR_TAPS,
        qam_orders=(16, 64, 256),
        selected_candidates=None):
    records = []
    all_candidates = ("cubic_ef1", "cubic_ef2", "cubic_mash11_weighted_dualpa",
                      "cubic_mash11_three_equal_pa",
                      "cubic_mash11_bit_reduced", "cubic_polyphase_ef2_32")
    candidates = tuple(selected_candidates or all_candidates)
    if any(candidate not in all_candidates for candidate in candidates):
        raise ValueError("unknown candidate in selected_candidates")
    for qam_order in qam_orders:
        for seed in seeds:
            seed_records = {}
            for candidate in candidates:
                if (candidate == "cubic_mash11_three_equal_pa" and
                        "cubic_mash11_weighted_dualpa" in seed_records):
                    record = copy.deepcopy(
                        seed_records["cubic_mash11_weighted_dualpa"])
                    record["candidate"] = candidate
                    record["pa_model"] = (
                        "three equal bipolar PA planes; fourth physically disabled")
                    record["model_diagnostics"].update({
                        "active_pa_planes": 3,
                        "fourth_pa_contract": (
                            "physically disabled; zero reset level needs sample-rate blanking"),
                        "sample_mute_count": record["model_diagnostics"][
                            "zero_reset_output_samples"],
                    })
                else:
                    record = _case(seed, symbols, fir_taps, candidate, qam_order)
                records.append(record)
                seed_records[candidate] = record
    summary = []
    for qam_order in qam_orders:
        for candidate in candidates:
            rows = [row for row in records if row["candidate"] == candidate
                    and row["qam_order"] == qam_order]
            metrics = [row["metrics"] for row in rows]
            bits_per_symbol = int(math.log2(qam_order))
            bit_count = sum(bits_per_symbol * item["qam_symbols"] for item in metrics)
            bit_errors = sum(item["uncoded_bit_errors_natural_binary"] for item in metrics)
            summary.append({
                "candidate": candidate,
                "qam_order": qam_order,
                "heldout_seed_count": len(rows),
                "mean_evm_percent": statistics.mean(item["evm_percent"] for item in metrics),
                "mean_sndr_db": statistics.mean(item["sndr_db"] for item in metrics),
                "symbol_errors": sum(item["symbol_errors"] for item in metrics),
                "qam_symbols": sum(item["qam_symbols"] for item in metrics),
                "natural_binary_ber": bit_errors / max(1, bit_count),
                "bit_errors": bit_errors,
                "bit_count": bit_count,
                "mean_adjacent_band_proxy_dbc": statistics.mean(
                    row["adjacent_band_proxy_dbc"] for row in rows),
                "mean_state_saturations": statistics.mean(
                    row["model_diagnostics"].get("state_saturations", 0) for row in rows),
                "model_only": True,
            })
    return {"conditions": {
        "seeds": list(seeds), "symbols_per_seed": symbols,
        "qam_orders": list(qam_orders),
        "rms_drive": 0.09, "step": 5120, "interpolation": "centered cubic x4",
        "rx_filter_taps": fir_taps, "pa_model": "disabled",
        "bitstream": "A weighted dual-PA, B exact three-active-plane MASH, C four-active-plane bit reduction",
    }, "summary": summary, "records": records}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seeds", default="281001,281003,281005,281007")
    parser.add_argument("--symbols", type=int, default=8)
    parser.add_argument("--qam-orders", default="16,64,256")
    parser.add_argument("--candidates", default="cubic_ef1,cubic_ef2,cubic_mash11_weighted_dualpa,cubic_mash11_three_equal_pa,cubic_mash11_bit_reduced,cubic_polyphase_ef2_32")
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--summary-csv", type=Path, required=True)
    parser.add_argument("--psd-csv", type=Path, required=True)
    args = parser.parse_args()
    result = run([int(value) for value in args.seeds.split(",")], args.symbols,
                 qam_orders=tuple(int(value) for value in args.qam_orders.split(",")),
                 selected_candidates=tuple(args.candidates.split(",")))
    for path in (args.json, args.summary_csv, args.psd_csv):
        path.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    with args.summary_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(result["summary"][0]))
        writer.writeheader()
        writer.writerows(result["summary"])
    with args.psd_csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["qam_order", "candidate", "stage", "bin", "relative_psd_db"])
        for qam_order in sorted({row["qam_order"] for row in result["records"]}):
            for candidate in sorted({row["candidate"] for row in result["records"]}):
                rows = [row for row in result["records"]
                        if row["candidate"] == candidate and row["qam_order"] == qam_order]
                for index, value in enumerate(rows[0]["relative_psd_db"]):
                    writer.writerow([qam_order, candidate, "final_rf", index, value])
                for stage, values in rows[0].get("stage_psd_db", {}).items():
                    for index, value in enumerate(values):
                        writer.writerow([qam_order, candidate, stage, index, value])
    print(json.dumps({"conditions": result["conditions"],
                      "summary": result["summary"]}, indent=2))


if __name__ == "__main__":
    main()
