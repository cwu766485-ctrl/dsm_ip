#!/usr/bin/env python3
"""Held-out branch gain/skew/fault screen from the four thermo5 TID planes.

This behavioral experiment starts from the same four encoded planes as the
EF2 benchmark. It decodes each branch independently, applies branch amplitude
and timing offsets, re-serializes the FS/4 waveform, then reuses the existing
reconstruction, DPA, output-network, receiver, and kTB/NF models. It is not a
GT electrical, DAC, PA, or board signoff model.
"""

import argparse
import cmath
import json
import math
import statistics
from multiprocessing import Pool
from pathlib import Path

from benchmark_thermo5_step_ntf import _analog_metrics
from benchmark_thermo5_tid_receiver import (
    PA_OUTPUT_PROFILES,
    RAW_FS_HZ,
    RX_CUTOFF_RATIO_OF_OCCUPIED_BW,
    _blackman_lowpass,
    _expand_iq_x4,
    _linear_fir_decimate,
    make_256qam_ofdm,
    receive_filter_decimate,
    reconstruct_baseband_7g,
    demodulate_metrics,
)
from dsm_refmodel.thermo5_experiments import generate_thermo5_tidsm_planes
from dsm_refmodel.thermo5_receiver import decode_fs4_branch_word


DEFAULT_SEEDS = (281001, 281003, 281005, 281007)
SKEW_PATTERN = (-0.5, -1.0 / 6.0, 1.0 / 6.0, 0.5)
GAIN_PATTERN = SKEW_PATTERN
BRANCH_SAMPLE_RATE_HZ = RAW_FS_HZ / 2.0
RF_CARRIER_HZ = RAW_FS_HZ / 4.0
PHASE4 = (1.0 + 0.0j, -1.0j, -1.0 + 0.0j, 1.0j)


def fractional_delay_lagrange4(samples, delay_samples):
    """Delay a complex stream by a small fractional sample count.

    A four-point Lagrange interpolator evaluates x[n-delay] from samples at
    n-1, n, n+1, n+2. Out-of-frame samples are zero extended. The TX branch
    sweep uses at most 0.07 sample of delay at 7 GHz.
    """
    nodes = (-1, 0, 1, 2)
    target = -float(delay_samples)
    weights = []
    for node in nodes:
        weight = 1.0
        for other in nodes:
            if other != node:
                weight *= (target - other) / (node - other)
        weights.append(weight)
    result = []
    for index in range(len(samples)):
        value = 0.0j
        for node, weight in zip(nodes, weights):
            source = index + node
            if 0 <= source < len(samples):
                value += complex(samples[source]) * weight
        result.append(value)
    return result


def branch_skews_ps(skew_peak_to_peak_ps):
    """Return a centered four-branch skew pattern with the requested span."""
    span = float(skew_peak_to_peak_ps)
    return [factor * span for factor in SKEW_PATTERN]


def branch_gains_db(gain_peak_to_peak_db):
    """Return a centered four-branch gain pattern with the requested span."""
    span = float(gain_peak_to_peak_db)
    return [factor * span for factor in GAIN_PATTERN]


def _extract_branch_streams(plane_words):
    branch_i = [[] for _ in range(4)]
    branch_q = [[] for _ in range(4)]
    for word in plane_words:
        if len(word) != 4:
            raise ValueError("expected exactly four TID planes per word")
        for branch, plane in enumerate(word):
            values_i, values_q = decode_fs4_branch_word(plane, branch)
            branch_i[branch].extend(values_i)
            branch_q[branch].extend(values_q)
    return [
        [complex(i, q) for i, q in zip(branch_i[b], branch_q[b])]
        for b in range(4)
    ]


def reconstruct_branch_output(plane_words, gain_mismatch_db=0.0,
                              skew_peak_to_peak_ps=0.0,
                              dropped_branch=None, bandwidth_hz=250e6,
                              fir_taps=4097):
    """Reconstruct a 7-GHz complex branch sum after gain/skew/fault changes.

    Each branch starts from its decoded production TID output bits. Fractional
    envelope delay and the corresponding RF carrier phase shift are applied
    independently, then the four branch paths are summed and passed through
    the same FS/4 DDC reconstruction FIR used by the existing benchmark.
    """
    if dropped_branch is not None and dropped_branch not in range(4):
        raise ValueError("dropped_branch must be None or 0..3")
    branch_streams = _extract_branch_streams(plane_words)
    lengths = {len(stream) for stream in branch_streams}
    if len(lengths) != 1 or not lengths or not next(iter(lengths)):
        raise ValueError("all four decoded branch streams must be non-empty/equal")
    gain_db = branch_gains_db(gain_mismatch_db)
    skew_ps = branch_skews_ps(skew_peak_to_peak_ps)
    combined = [0.0j] * len(branch_streams[0])
    for branch, stream in enumerate(branch_streams):
        if branch == dropped_branch:
            continue
        delay_seconds = skew_ps[branch] * 1e-12
        delay_samples = delay_seconds * BRANCH_SAMPLE_RATE_HZ
        delayed = fractional_delay_lagrange4(stream, delay_samples)
        voltage_gain = 10.0 ** (gain_db[branch] / 20.0)
        carrier_phase = cmath.exp(-2.0j * math.pi * RF_CARRIER_HZ * delay_seconds)
        scale = voltage_gain * carrier_phase
        combined = [left + right * scale
                    for left, right in zip(combined, delayed)]

    # A complex baseband sample at 7 GHz maps to two real Fs/4 slots at 14 GHz.
    raw = []
    for index, value in enumerate(combined):
        sign_i = 1.0 if index % 2 == 0 else -1.0
        sign_q = -sign_i
        raw.extend((sign_i * value.real, sign_q * value.imag))
    ddc = [2.0 * value * PHASE4[index & 3]
           for index, value in enumerate(raw)]
    cutoff_hz = RX_CUTOFF_RATIO_OF_OCCUPIED_BW * float(bandwidth_hz)
    coefficients = _blackman_lowpass(cutoff_hz, RAW_FS_HZ, fir_taps)
    baseband_7g = _linear_fir_decimate(ddc, coefficients, 2, phase=0)
    return baseband_7g, {
        "branch_count": 4,
        "decoded_complex_sample_rate_hz": BRANCH_SAMPLE_RATE_HZ,
        "rf_carrier_hz": RF_CARRIER_HZ,
        "gain_mismatch_peak_to_peak_db": float(gain_mismatch_db),
        "branch_gain_db": gain_db,
        "skew_peak_to_peak_ps": float(skew_peak_to_peak_ps),
        "branch_skew_ps": skew_ps,
        "branch_skew_samples_at_7ghz": [
            value * 1e-12 * BRANCH_SAMPLE_RATE_HZ for value in skew_ps],
        "carrier_phase_shift_degrees": [
            -360.0 * RF_CARRIER_HZ * value * 1e-12 for value in skew_ps],
        "dropped_branch": dropped_branch,
        "fs4_reconstruction_filter": "Blackman-windowed linear-phase FIR, centered offline",
        "fs4_filter_taps": int(fir_taps),
        "fs4_filter_cutoff_hz": cutoff_hz,
        "sample_boundary": "zero extension; no frame wrap",
    }


def _scenario_grid():
    scenarios = [{"name": "baseline", "class": "reference",
                  "gain_mismatch_db": 0.0, "skew_ps": 0.0,
                  "drop_branch": None}]
    for skew in (2.0, 5.0, 10.0, 20.0):
        scenarios.append({"name": "skew_%gps" % skew, "class": "sensitivity",
                          "gain_mismatch_db": 0.0, "skew_ps": skew,
                          "drop_branch": None})
    for mismatch in (0.2, 0.5, 1.0):
        scenarios.append({"name": "gain_%gdb_pp" % mismatch,
                          "class": "sensitivity",
                          "gain_mismatch_db": mismatch, "skew_ps": 0.0,
                          "drop_branch": None})
    scenarios.append({"name": "gain_1db_skew_20ps", "class": "sensitivity",
                      "gain_mismatch_db": 1.0, "skew_ps": 20.0,
                      "drop_branch": None})
    for branch in range(4):
        scenarios.append({"name": "pa_branch_%d_dropout" % branch,
                          "class": "expected_fault",
                          "gain_mismatch_db": 0.0, "skew_ps": 0.0,
                          "drop_branch": branch})
    return scenarios


def _one_seed(task):
    seed, symbols, rms_drive, step, state_width, fir_taps, scenarios = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    i_samples, q_samples = _expand_iq_x4(stimulus["source_iq"], "centered_cubic")
    plane_words, model_stats = generate_thermo5_tidsm_planes(
        i_samples, q_samples, step, mode="ef_order2_fixed",
        state_width=state_width)
    baseband, reconstruction = reconstruct_branch_output(
        plane_words, bandwidth_hz=stimulus["actual_bandwidth_hz"],
        fir_taps=fir_taps)
    reference, _ = reconstruct_baseband_7g(
        plane_words, stimulus["actual_bandwidth_hz"], latency_samples=0,
        fir_taps=fir_taps)
    max_reconstruction_error = max(
        abs(left - right) for left, right in zip(baseband, reference))
    if max_reconstruction_error > 1e-10:
        raise RuntimeError("zero-impairment plane reconstruction mismatch %.3g" %
                           max_reconstruction_error)

    baseline_analog = _analog_metrics(
        baseband, stimulus, tuple(PA_OUTPUT_PROFILES), fir_taps)
    reference_output_rms = {
        item["profile"]: item["dpa_output_rms_normalized"]
        for item in baseline_analog
    }
    results = []
    for scenario in scenarios:
        case_baseband = baseband
        case_reconstruction = reconstruction
        if scenario["name"] != "baseline":
            case_baseband, case_reconstruction = reconstruct_branch_output(
                plane_words,
                gain_mismatch_db=scenario["gain_mismatch_db"],
                skew_peak_to_peak_ps=scenario["skew_ps"],
                dropped_branch=scenario["drop_branch"],
                bandwidth_hz=stimulus["actual_bandwidth_hz"],
                fir_taps=fir_taps)
        rx, receiver = receive_filter_decimate(
            case_baseband, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        digital = demodulate_metrics(rx, stimulus)
        analog = (baseline_analog if scenario["name"] == "baseline" else
                  _analog_metrics(case_baseband, stimulus,
                                  tuple(PA_OUTPUT_PROFILES), fir_taps,
                                  reference_output_rms=reference_output_rms))
        results.append({
            "seed": int(seed),
            "scenario": dict(scenario),
            "input": {
                "rms_drive_target": float(rms_drive),
                "measured_rms": stimulus["input_rms"],
                "peak": stimulus["input_peak"],
                "actual_bandwidth_hz": stimulus["actual_bandwidth_hz"],
                "symbols": int(symbols),
            },
            "ef2": {
                "step": int(step),
                "state_width_bits": int(state_width),
                "state_saturation_samples": model_stats["state_saturation_samples"],
                "input_saturation_samples": model_stats["input_saturation_samples"],
                "max_abs_error_state": model_stats["max_abs_error_state"],
                "max_abs_quantizer_input": model_stats["max_abs_quantizer_input"],
            },
            "branch_model": case_reconstruction,
            "baseline_reconstruction_max_abs_error": max_reconstruction_error,
            "receiver": receiver,
            "digital_metrics": digital,
            "analog_profiles": analog,
        })
    return results


def _wilson(errors, trials, z=1.959963984540054):
    if trials <= 0:
        return [None, None]
    p = errors / trials
    denominator = 1.0 + z * z / trials
    center = (p + z * z / (2.0 * trials)) / denominator
    radius = (z * math.sqrt(p * (1.0 - p) / trials +
                            z * z / (4.0 * trials * trials)) / denominator)
    return [max(0.0, center - radius), min(1.0, center + radius)]


def _summaries(records, scenarios):
    summaries = []
    for scenario in scenarios:
        rows = [row for row in records
                if row["scenario"]["name"] == scenario["name"]]
        bits = sum(8 * row["digital_metrics"]["qam_symbols"] for row in rows)
        errors = sum(row["digital_metrics"][
            "uncoded_bit_errors_natural_binary"] for row in rows)
        seed_bers = [row["digital_metrics"][
            "uncoded_bit_errors_natural_binary"] /
            max(1, 8 * row["digital_metrics"]["qam_symbols"])
            for row in rows]
        entry = {
            "scenario": dict(scenario),
            "seed_count": len(rows),
            "qam_symbols": sum(row["digital_metrics"]["qam_symbols"]
                               for row in rows),
            "uncoded_bit_count": bits,
            "uncoded_bit_errors_natural_binary": errors,
            "uncoded_ber_natural_binary": errors / max(1, bits),
            "ber_95pct_wilson_ci": _wilson(errors, bits),
            "worst_seed_ber": max(seed_bers, default=0.0),
            "mean_evm_percent": statistics.mean(
                row["digital_metrics"]["evm_percent"] for row in rows),
            "worst_seed_evm_percent": max(
                row["digital_metrics"]["evm_percent"] for row in rows),
            "mean_sndr_db": statistics.mean(
                row["digital_metrics"]["sndr_db"] for row in rows),
            "max_state_saturation_samples": max(
                row["ef2"]["state_saturation_samples"] for row in rows),
            "max_input_saturation_samples": max(
                row["ef2"]["input_saturation_samples"] for row in rows),
            "max_reconstruction_error": max(
                row["baseline_reconstruction_max_abs_error"] for row in rows),
            "analog": {},
        }
        for profile_name in PA_OUTPUT_PROFILES:
            profile_rows = [next(item for item in row["analog_profiles"]
                                 if item["profile"] == profile_name)
                            for row in rows]
            deterministic = [item["metrics_after_dpa_output_network"]
                             for item in profile_rows]
            noisy = [item["metrics_after_thermal_noise"]
                     for item in profile_rows]
            analog_bits = sum(8 * item["qam_symbols"] for item in noisy)
            analog_errors = sum(item[
                "uncoded_bit_errors_natural_binary"] for item in noisy)
            entry["analog"][profile_name] = {
                "uncoded_bit_count": analog_bits,
                "uncoded_bit_errors_natural_binary": analog_errors,
                "uncoded_ber_natural_binary": analog_errors / max(1, analog_bits),
                "ber_95pct_wilson_ci": _wilson(analog_errors, analog_bits),
                "worst_seed_ber": max(
                    item["uncoded_bit_errors_natural_binary"] /
                    max(1, 8 * item["qam_symbols"]) for item in noisy),
                "mean_evm_after_dpa_percent": statistics.mean(
                    item["evm_percent"] for item in deterministic),
                "mean_evm_after_noise_percent": statistics.mean(
                    item["evm_percent"] for item in noisy),
                "worst_seed_evm_after_noise_percent": max(
                    item["evm_percent"] for item in noisy),
                "modeled_output_power_dbm": statistics.mean(
                    item["modeled_signal_power_dbm"] for item in profile_rows),
            }
        summaries.append(entry)
    return summaries


def run(seeds=DEFAULT_SEEDS, symbols=12, rms_drive=0.10, step=5120,
        state_width=20, fir_taps=4097, jobs=1):
    if not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("seeds must be non-empty and unique")
    if symbols < 1 or jobs < 1:
        raise ValueError("symbols and jobs must be positive")
    scenarios = _scenario_grid()
    tasks = [(seed, symbols, rms_drive, step, state_width, fir_taps, scenarios)
             for seed in seeds]
    if jobs == 1:
        batches = [_one_seed(task) for task in tasks]
    else:
        with Pool(processes=jobs) as pool:
            batches = pool.map(_one_seed, tasks)
    records = [record for batch in batches for record in batch]
    return {
        "benchmark": "thermo5_tx_four_branch_gain_skew_fault_sensitivity",
        "scope": "behavioral model from four actual EF2 output planes; not GT/DAC/PA silicon characterization",
        "seed_role": "held-out confirmation seeds, disjoint from Gate 2 development seeds",
        "seeds": [int(seed) for seed in seeds],
        "symbols_per_seed": int(symbols),
        "qam_order": 256,
        "nfft": 4096,
        "cyclic_prefix": 512,
        "active_subcarriers": 584,
        "step": int(step),
        "state_width_bits": int(state_width),
        "rms_drive": float(rms_drive),
        "branch_sample_rate_hz": BRANCH_SAMPLE_RATE_HZ,
        "carrier_hz": RF_CARRIER_HZ,
        "branch_gain_pattern": "[-1/2,-1/6,+1/6,+1/2] times peak-to-peak dB span",
        "branch_skew_pattern": "[-1/2,-1/6,+1/6,+1/2] times peak-to-peak ps span",
        "skew_model": "4-point Lagrange envelope delay plus Fs/4 carrier phase rotation",
        "pa_models": {
            name: {key: value for key, value in profile.items()
                   if key != "output_network_taps"} |
                  {"output_network_taps": [[tap.real, tap.imag]
                                             for tap in profile["output_network_taps"]]}
            for name, profile in PA_OUTPUT_PROFILES.items()
        },
        "scenarios": _scenario_grid(),
        "summaries": _summaries(records, scenarios),
        "records": records,
        "limitations": [
            "skew and gain limits are sensitivity coordinates; no product contract limits are defined",
            "branch dropout is a fault case, not an expected legal operating condition",
            "all branch paths share the current behavioral PA/output model after summation",
            "PA coefficients, noise figure, signal power and output filter are uncalibrated model assumptions",
            "no GT electrical jitter, DAC reconstruction mismatch, package coupling, or measured BER is modeled",
        ],
    }


def _seed_list(text):
    values = tuple(int(item.strip(), 0) for item in text.split(",") if item.strip())
    if not values:
        raise argparse.ArgumentTypeError("seed list cannot be empty")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=_seed_list,
                        default=DEFAULT_SEEDS)
    parser.add_argument("--symbols", type=int, default=12)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--state-width", type=int, default=20)
    parser.add_argument("--fir-taps", type=int, default=4097)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.seeds, args.symbols, args.rms_drive, args.step,
                 args.state_width, args.fir_taps, args.jobs)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2) + "\n")
    for row in result["summaries"]:
        analog = row["analog"]
        print("%-20s BER=%8.3g CI95=[%.3g,%.3g] EVM=%6.3f%% SNDR=%6.2fdB "
              "nomBER=%8.3g stressBER=%8.3g" % (
                  row["scenario"]["name"], row["uncoded_ber_natural_binary"],
                  *row["ber_95pct_wilson_ci"], row["mean_evm_percent"],
                  row["mean_sndr_db"],
                  analog["nominal"]["uncoded_ber_natural_binary"],
                  analog["stress"]["uncoded_ber_natural_binary"]))
    print("wrote %s (%d seed-scenario records)" %
          (args.json, len(result["records"])))


if __name__ == "__main__":
    main()
