#!/usr/bin/env python3
"""Small, repeatable Python A/B sweep for thermo5 FIR and input-drive choices.

This is a floating-point system-level screening model around the quantized
interpolators, behavioral DPA, output FIR, and kTB/NF noise. The frozen 4x
first-order TIDSM remains the design baseline; STEP/DSM-order changes are not
ranked by this script because raw TID-plane reconstruction is not yet validated.
"""

import argparse
import csv
import json
import math
import random
from pathlib import Path

from benchmark_thermo5_interp import cascade, fft, ideal_4x
from dsm_refmodel.link_models import (
    BehavioralDPA,
    add_thermal_noise,
    apply_complex_fir,
)
from dsm_refmodel.thermo5 import saturate_signed


FFT_SIZE = 256
ACTIVE_EDGE = 32
SAMPLE_RATE_HZ = 1_000_000_000.0
OCCUPIED_BANDWIDTH_HZ = 250_000_000.0
OVERSAMPLE = 4
METHODS = ("rtl2", "rtl3", "rtl4", "forward_linear", "centered_cubic")
NORMALIZATIONS = ("fixed_average_power", "peak_normalized")
PAPR_LIMITS_DB = (None, 7.0, 9.0)
BACKOFFS_DB = (0.0, 6.0, 12.0)
TARGET_RMS = 0.40
TARGET_PEAK = 0.90
DPA_CONFIG = {
    "saturation": 0.82,
    "smoothness": 2.0,
    "ampm_degrees": 5.0,
    "envelope_memory": 0.15,
}
OUTPUT_TAPS = (1.0 + 0.0j, 0.02 - 0.01j, 0.005 + 0.004j)
BASE_OUTPUT_POWER_DBM = -30.0
NOISE_FIGURE_DB = 6.0
TEMPERATURE_K = 290.0


def _make_256qam_ofdm(rng, symbols):
    """Generate 256-QAM OFDM with 64 active carriers in a 256-point IFFT."""
    levels = tuple(range(-15, 16, 2))
    result = []
    for _ in range(symbols):
        spectrum = [0j] * FFT_SIZE
        for carrier in list(range(-ACTIVE_EDGE, 0)) + list(range(1, ACTIVE_EDGE + 1)):
            symbol = complex(rng.choice(levels), rng.choice(levels)) / math.sqrt(170.0)
            spectrum[carrier % FFT_SIZE] = symbol
        result.append(fft(spectrum, inverse=True))
    return result


def _mean_power(samples):
    return sum(abs(value) ** 2 for value in samples) / max(1, len(samples))


def _scale_symbols(symbols, normalization):
    flat = [sample for symbol in symbols for sample in symbol]
    if normalization == "fixed_average_power":
        rms = math.sqrt(_mean_power(flat))
        scale = TARGET_RMS / max(rms, 1e-30)
    elif normalization == "peak_normalized":
        peak = max(abs(value) for value in flat)
        scale = TARGET_PEAK / max(peak, 1e-30)
    else:
        raise ValueError("unknown normalization mode")
    return [[sample * scale for sample in symbol] for symbol in symbols]


def _radial_clip(samples, peak_limit):
    result = []
    for value in samples:
        magnitude = abs(value)
        if magnitude > peak_limit:
            result.append(value * (peak_limit / magnitude))
        else:
            result.append(value)
    return result


def _apply_papr_limit(symbols, normalization, limit_db):
    flat = [sample for symbol in symbols for sample in symbol]
    if limit_db is None:
        return list(flat)

    if normalization == "fixed_average_power":
        # Repeated clip/renormalize approximates a conventional CFR pass while
        # keeping mean input power comparable across clipping configurations.
        for _ in range(12):
            threshold = TARGET_RMS * 10.0 ** (limit_db / 20.0)
            flat = _radial_clip(flat, threshold)
            rms = math.sqrt(_mean_power(flat))
            flat = [value * (TARGET_RMS / max(rms, 1e-30)) for value in flat]
    else:
        rms = math.sqrt(_mean_power(flat))
        threshold = rms * 10.0 ** (limit_db / 20.0)
        flat = _radial_clip(flat, threshold)
    return flat


def _q15_pair(value, saturate=True):
    real = int(round(value.real * 32768.0))
    imag = int(round(value.imag * 32768.0))
    if saturate:
        real = saturate_signed(real, 16)
        imag = saturate_signed(imag, 16)
    return real, imag


def _signed_bin(index, count):
    return index if index <= count // 2 else index - count


def _rotate_symbol(samples, shift):
    if not samples or shift == 0:
        return list(samples)
    shift %= len(samples)
    return list(samples[shift:]) + list(samples[:shift])


def _estimate_timing_shift(output, references, maximum_shift=16):
    """Choose one fixed integer sample shift across all OFDM symbols."""
    symbol_length = FFT_SIZE * OVERSAMPLE
    candidates = list(range(-maximum_shift, maximum_shift + 1, 4))
    scores = {}
    for shift in candidates:
        fit_error = 0.0
        reference_energy = 0.0
        for symbol_index, reference in enumerate(references):
            start = symbol_index * symbol_length
            actual = _rotate_symbol(output[start:start + symbol_length], shift)
            output_energy = sum(abs(value) ** 2 for value in actual)
            cross = sum(expected * value.conjugate()
                        for value, expected in zip(actual, reference))
            gain = cross / max(output_energy, 1e-30)
            fit_error += sum(abs(gain * value - expected) ** 2
                             for value, expected in zip(actual, reference))
            reference_energy += sum(abs(value) ** 2 for value in reference)
        scores[shift] = fit_error / max(reference_energy, 1e-30)

    coarse_best = min(candidates, key=scores.get)
    refine = range(max(-maximum_shift, coarse_best - 3),
                   min(maximum_shift, coarse_best + 3) + 1)
    for shift in refine:
        if shift in scores:
            continue
        fit_error = 0.0
        reference_energy = 0.0
        for symbol_index, reference in enumerate(references):
            start = symbol_index * symbol_length
            actual = _rotate_symbol(output[start:start + symbol_length], shift)
            output_energy = sum(abs(value) ** 2 for value in actual)
            cross = sum(expected * value.conjugate()
                        for value, expected in zip(actual, reference))
            gain = cross / max(output_energy, 1e-30)
            fit_error += sum(abs(gain * value - expected) ** 2
                             for value, expected in zip(actual, reference))
            reference_energy += sum(abs(value) ** 2 for value in reference)
        scores[shift] = fit_error / max(reference_energy, 1e-30)
    return min(scores, key=scores.get)


def _measure(output, references, timing_shift=0):
    raw_error = 0.0
    fitted_error = 0.0
    reference_energy = 0.0
    inband_reference_energy = 0.0
    inband_error_energy = 0.0
    main_power = 0.0
    adjacent_power = 0.0
    psd = [0.0] * (FFT_SIZE * OVERSAMPLE)
    symbol_length = FFT_SIZE * OVERSAMPLE

    for symbol_index, reference in enumerate(references):
        start = symbol_index * symbol_length
        actual = _rotate_symbol(output[start:start + symbol_length], timing_shift)
        if len(actual) != symbol_length:
            raise ValueError("output and reference symbol lengths differ")
        ref_energy = sum(abs(value) ** 2 for value in reference)
        out_energy = sum(abs(value) ** 2 for value in actual)
        cross = sum(expected * value.conjugate()
                    for value, expected in zip(actual, reference))
        gain = cross / max(out_energy, 1e-30)
        raw_error += sum(abs(value - expected) ** 2
                         for value, expected in zip(actual, reference))
        fitted_error += sum(abs(gain * value - expected) ** 2
                            for value, expected in zip(actual, reference))
        reference_energy += ref_energy

        actual_spectrum = fft(actual)
        reference_spectrum = fft(reference)
        for index, value in enumerate(actual_spectrum):
            frequency_bin = abs(_signed_bin(index, len(actual_spectrum)))
            power = abs(value) ** 2
            psd[index] += power
            if 1 <= frequency_bin <= ACTIVE_EDGE:
                main_power += power
            elif ACTIVE_EDGE < frequency_bin <= 3 * ACTIVE_EDGE:
                adjacent_power += power

        for index, ref_value in enumerate(reference_spectrum):
            frequency_bin = abs(_signed_bin(index, len(reference_spectrum)))
            if 1 <= frequency_bin <= ACTIVE_EDGE:
                corrected_error = gain * actual_spectrum[index] - ref_value
                inband_reference_energy += abs(ref_value) ** 2
                inband_error_energy += abs(corrected_error) ** 2

    count = max(1, len(references))
    active_power = max(main_power, 1e-30)
    normalized_psd = [10.0 * math.log10(max(value / count, 1e-30) /
                                         max(active_power / count, 1e-30))
                      for value in psd]
    return {
        "raw_evm_percent": 100.0 * math.sqrt(raw_error / max(reference_energy, 1e-30)),
        "corrected_evm_percent": 100.0 * math.sqrt(
            fitted_error / max(reference_energy, 1e-30)),
        "inband_sndr_db": 10.0 * math.log10(
            max(inband_reference_energy, 1e-30) /
            max(inband_error_energy, 1e-30)),
        "aclr_proxy_dbc": 10.0 * math.log10(
            max(adjacent_power, 1e-30) / active_power),
        "mean_output_power_normalized": _mean_power(output),
        "psd_dbc_per_bin": normalized_psd,
    }


def _papr_db(samples):
    mean_power = _mean_power(samples)
    peak_power = max((abs(value) ** 2 for value in samples), default=0.0)
    return 10.0 * math.log10(max(peak_power, 1e-30) /
                              max(mean_power, 1e-30))


def _prepare_input(symbols, normalization, papr_limit_db, backoff_db):
    normalized = _scale_symbols(symbols, normalization)
    unclipped = [value for symbol in normalized for value in symbol]
    limited = _apply_papr_limit(normalized, normalization, papr_limit_db)
    drive = 10.0 ** (-backoff_db / 20.0)
    desired = [value * drive for value in unclipped]
    driven = [value * drive for value in limited]
    digital_clips = 0
    q15 = []
    reference_q15 = []
    for value, reference_value in zip(driven, desired):
        if abs(value.real) >= 1.0 or abs(value.imag) >= 1.0:
            digital_clips += int(abs(value.real) >= 1.0) + int(abs(value.imag) >= 1.0)
        q15.append(_q15_pair(value, saturate=True))
        # Preserve the desired reference beyond full scale so input clipping is
        # counted as distortion instead of hidden by reference saturation.
        reference_q15.append(_q15_pair(reference_value, saturate=False))
    return {
        "samples": q15,
        "reference_samples": reference_q15,
        "digital_component_clip_count": digital_clips,
        "input_component_count": 2 * len(q15),
        "papr_before_clip_db": _papr_db(unclipped),
        "papr_after_clip_db": _papr_db(driven),
        "mean_input_power_normalized": _mean_power(driven),
        "peak_input_normalized": max((abs(value) for value in driven), default=0.0),
    }


def _interpolate(samples, method):
    return [complex(real, imag) / 32768.0
            for real, imag in cascade(samples, method)]


def _run_seed(seed, symbols_per_seed, emit_psd=False):
    source_symbols = _make_256qam_ofdm(random.Random(seed), symbols_per_seed)
    results = []
    psd_rows = []
    deterministic_outputs = {}
    references_for_case = {}
    input_metadata = {}

    for normalization in NORMALIZATIONS:
        for papr_limit_db in PAPR_LIMITS_DB:
            for backoff_db in BACKOFFS_DB:
                prepared = _prepare_input(
                    source_symbols, normalization, papr_limit_db, backoff_db)
                key = (normalization, papr_limit_db, backoff_db)
                input_metadata[key] = prepared
                references_for_case[key] = [
                    ideal_4x(prepared["reference_samples"][index * FFT_SIZE:
                                                           (index + 1) * FFT_SIZE])
                    for index in range(symbols_per_seed)
                ]
                for method in METHODS:
                    interpolated = []
                    dpa_input_peak = 0.0
                    dpa_overload_count = 0
                    dpa_sample_count = 0
                    for symbol_index in range(symbols_per_seed):
                        current = prepared["samples"][symbol_index * FFT_SIZE:
                                                       (symbol_index + 1) * FFT_SIZE]
                        high_rate = _interpolate(current, method)
                        dpa_input_peak = max(dpa_input_peak,
                                             max(abs(value) for value in high_rate))
                        dpa_overload_count += sum(
                            abs(value) > DPA_CONFIG["saturation"]
                            for value in high_rate)
                        dpa_sample_count += len(high_rate)
                        interpolated.extend(high_rate)
                    dpa = BehavioralDPA(**DPA_CONFIG)
                    deterministic = dpa.process(interpolated)
                    deterministic = apply_complex_fir(deterministic, OUTPUT_TAPS)
                    alignment_shift = _estimate_timing_shift(
                        deterministic, references_for_case[key])
                    case_method = key + (method,)
                    deterministic_outputs[case_method] = deterministic
                    digital_shift = _estimate_timing_shift(
                        interpolated, references_for_case[key])
                    digital_metrics = _measure(
                        interpolated, references_for_case[key], digital_shift)
                    digital_fixed_timing = _measure(
                        interpolated, references_for_case[key], 0)
                    results.append({
                        "normalization": normalization,
                        "papr_limit_db": papr_limit_db,
                        "backoff_db": backoff_db,
                        "method": method,
                        "dpa_input_peak": dpa_input_peak,
                        "dpa_overload_fraction": dpa_overload_count /
                                                  max(1, dpa_sample_count),
                        "timing_alignment_samples": alignment_shift,
                        "digital_metrics": {
                            name: value for name, value in digital_metrics.items()
                            if name != "psd_dbc_per_bin"},
                        "digital_metrics_fixed_timing": {
                            name: value for name, value in digital_fixed_timing.items()
                            if name != "psd_dbc_per_bin"},
                    })

    baseline_key = ("fixed_average_power", None, 0.0, "centered_cubic")
    baseline_power = _mean_power(deterministic_outputs[baseline_key])
    for row in results:
        key = (row["normalization"], row["papr_limit_db"],
               row["backoff_db"], row["method"])
        deterministic = deterministic_outputs[key]
        output_power_dbm = (BASE_OUTPUT_POWER_DBM + 10.0 * math.log10(
            max(_mean_power(deterministic), 1e-30) /
            max(baseline_power, 1e-30)))
        papr_code = (0 if row["papr_limit_db"] is None else
                     int(row["papr_limit_db"] * 100))
        noise_seed = (seed + 100003 +
                      10000 * NORMALIZATIONS.index(row["normalization"]) +
                      10 * papr_code + int(row["backoff_db"] * 10))
        final_signal, noise_stats = add_thermal_noise(
            deterministic,
            random.Random(noise_seed),
            signal_power_dbm=output_power_dbm,
            bandwidth_hz=OCCUPIED_BANDWIDTH_HZ,
            noise_figure_db=NOISE_FIGURE_DB,
            temperature_k=TEMPERATURE_K)
        references = references_for_case[key[:3]]
        fixed_timing_measurements = _measure(final_signal, references, 0)
        measurements = _measure(final_signal, references,
                                row["timing_alignment_samples"])
        metadata = input_metadata[key[:3]]
        row.update({
            "papr_before_clip_db": metadata["papr_before_clip_db"],
            "papr_after_clip_db": metadata["papr_after_clip_db"],
            "mean_input_power_normalized": metadata["mean_input_power_normalized"],
            "peak_input_normalized": metadata["peak_input_normalized"],
            "digital_input_clip_fraction": metadata["digital_component_clip_count"] /
                                           max(1, metadata["input_component_count"]),
            "output_power_dbm_assumed": output_power_dbm,
            "thermal_noise": noise_stats,
            "metrics": {key: value for key, value in measurements.items()
                        if key != "psd_dbc_per_bin"},
            "metrics_fixed_timing": {
                key: value for key, value in fixed_timing_measurements.items()
                if key != "psd_dbc_per_bin"},
        })
        if (emit_psd and row["normalization"] == "fixed_average_power" and
                row["papr_limit_db"] is None and row["backoff_db"] == 0.0):
            for bin_index, psd_dbc in enumerate(measurements["psd_dbc_per_bin"]):
                frequency = _signed_bin(bin_index, FFT_SIZE * OVERSAMPLE) * (
                    SAMPLE_RATE_HZ / FFT_SIZE)
                psd_rows.append({
                    "seed": seed,
                    "method": row["method"],
                    "frequency_hz": frequency,
                    "psd_dbc_per_bin": psd_dbc,
                })

    return results, psd_rows


def run(seeds=(20261024, 20261025, 20261026, 20261027, 20261028),
        symbols_per_seed=8, development_seed_count=2):
    if not 1 <= development_seed_count < len(seeds):
        raise ValueError("development seed count must leave at least one held-out seed")
    if symbols_per_seed < 1:
        raise ValueError("symbols_per_seed must be positive")
    cases = []
    psd_rows = []
    development_seeds = list(seeds[:development_seed_count])
    heldout_seeds = list(seeds[development_seed_count:])
    psd_seed = heldout_seeds[-1]
    for seed in seeds:
        rows, current_psd = _run_seed(seed, symbols_per_seed,
                                      emit_psd=(seed == psd_seed))
        role = "held_out" if seed in heldout_seeds else "development"
        for row in rows:
            row["seed"] = seed
            row["seed_role"] = role
            cases.append(row)
        psd_rows.extend(current_psd)

    rankings = []
    tags = sorted({(row["seed_role"], row["normalization"],
                    row["papr_limit_db"], row["backoff_db"])
                   for row in cases}, key=lambda item: (
                       item[0], item[1], -1.0 if item[2] is None else item[2], item[3]))
    for role, normalization, papr_limit, backoff in tags:
        selected = [row for row in cases if row["seed_role"] == role and
                    row["normalization"] == normalization and
                    row["papr_limit_db"] == papr_limit and
                    row["backoff_db"] == backoff]
        method_means = []
        for method in METHODS:
            rows_for_method = [row for row in selected if row["method"] == method]
            mean_evm = sum(row["metrics"]["corrected_evm_percent"]
                           for row in rows_for_method) / len(rows_for_method)
            method_means.append((mean_evm, method))
        method_means.sort()
        rankings.append({
            "seed_role": role,
            "normalization": normalization,
            "papr_limit_db": papr_limit,
            "backoff_db": backoff,
            "methods_by_mean_corrected_evm": [method for _, method in method_means],
            "mean_corrected_evm_percent_by_method": {
                method: mean for mean, method in method_means},
        })

    return {
        "benchmark": "thermo5_fir_drive_papr_python_ab_sweep",
        "preferred_fir_candidate": "centered_cubic",
        "design_baseline": "rtl2 with four first-order TIDSM branches",
        "qam_order": 256,
        "fft_size": FFT_SIZE,
        "active_subcarriers": 2 * ACTIVE_EDGE,
        "sample_rate_hz": SAMPLE_RATE_HZ,
        "occupied_bandwidth_hz": OCCUPIED_BANDWIDTH_HZ,
        "subcarrier_spacing_hz": SAMPLE_RATE_HZ / FFT_SIZE,
        "symbols_per_seed": symbols_per_seed,
        "development_seeds": development_seeds,
        "held_out_seeds": heldout_seeds,
        "held_out_psd_seed": psd_seed,
        "normalization_modes": list(NORMALIZATIONS),
        "papr_limits_db": list(PAPR_LIMITS_DB),
        "backoff_db": list(BACKOFFS_DB),
        "analog_chain": {
            "dpa": DPA_CONFIG,
            "output_network_taps_re_im": [[tap.real, tap.imag]
                                           for tap in OUTPUT_TAPS],
            "reference_output_power_dbm": BASE_OUTPUT_POWER_DBM,
            "noise_figure_db": NOISE_FIGURE_DB,
            "temperature_k": TEMPERATURE_K,
        },
        "cases": cases,
        "rankings": rankings,
        "model_scope": [
            "This first A/B covers P0 FIR and input-drive/PAPR options around a shared behavioral analog chain.",
            "All candidates use identical 256-QAM symbols, seeds, DPA/output-network/noise parameters, and per-case references.",
            "Each candidate gets one fixed integer sample alignment across the frame, then the same per-symbol scalar complex fit; fixed-timing EVM is also retained.",
            "Average-power and peak-normalized results are separate; PAPR limiting is radial clipping, with iterative renormalization in fixed-average-power mode.",
            "The OFDM setup assumes 1 GHz sample rate, 64 active carriers, and 250 MHz occupied bandwidth; these are explicit bench assumptions.",
            "Centered cubic is batch evaluated with periodic per-symbol edge extension; real-time frame-edge/latency handling is not represented.",
            "The 4x first-order TIDSM remains the RTL design baseline; this script does not decode its serialized planes into calibrated EVM/SNDR.",
            "STEP and DSM NTF/order are intentionally not ranked here until the exact output reconstruction and stability acceptance metrics are validated.",
            "SNDR and ACLR are baseband FFT-band proxies; power, DPA, filter, and thermal-noise settings are illustrative, not measured hardware values.",
        ],
    }, psd_rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols-per-seed", type=int, default=8)
    parser.add_argument("--seeds",
                        default="20261024,20261025,20261026,20261027,20261028",
                        help="comma-separated; first two develop, rest are held out")
    parser.add_argument("--development-seed-count", type=int, default=2,
                        help="number of leading seeds used for development")
    parser.add_argument("--json", type=Path)
    parser.add_argument("--psd-csv", type=Path)
    args = parser.parse_args()
    try:
        seeds = tuple(int(value.strip()) for value in args.seeds.split(",")
                      if value.strip())
        result, psd_rows = run(seeds, args.symbols_per_seed,
                               args.development_seed_count)
    except ValueError as error:
        parser.error(str(error))
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")
    if args.psd_csv:
        args.psd_csv.parent.mkdir(parents=True, exist_ok=True)
        with args.psd_csv.open("w", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=(
                "seed", "method", "frequency_hz", "psd_dbc_per_bin"))
            writer.writeheader()
            writer.writerows(psd_rows)


if __name__ == "__main__":
    main()
