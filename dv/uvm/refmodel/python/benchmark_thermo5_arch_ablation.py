#!/usr/bin/env python3
"""Controlled QAM256 ablation of interpolation and TIDSM architecture.

The four primary cells use the same Q1.15 OFDM inputs, receiver, and PA model.
First-order uses a scalar recurrence equivalent to the existing RTL; EF2 uses
the integer fixed-point recurrence and 20-bit state used by the product. The
default includes a common STEP=5120 comparison plus the historical first-order
STEP=7168 operating point. Pipeline latency is removed before receiver
measurement; no hardware II, timing, or resource result is inferred.
"""

import argparse
import csv
import json
import math
import random
import statistics
from multiprocessing import Pool
from pathlib import Path

from benchmark_thermo5_interp import fft
from benchmark_thermo5_step_ntf import _analog_metrics
from benchmark_thermo5_tid_receiver import (
    ACTIVE_CARRIERS,
    GUARD_SAMPLES,
    NCP,
    NFFT,
    OCCUPIED_BW_HZ,
    PA_OUTPUT_PROFILES,
    RX_FIR_TAPS,
    SOURCE_FS_HZ,
    demodulate_metrics,
    make_256qam_ofdm,
    receive_filter_decimate,
    reconstruct_baseband_7g,
)
from dsm_refmodel.thermo5 import INTERP_COEFFS_Q14
from dsm_refmodel.thermo5_experiments import generate_thermo5_tidsm_planes
from dsm_refmodel.thermo5_receiver import (
    centered_cubic_stream_contract,
    interpolate_x4,
)


INTERPOLATORS = ("causal", "centered_cubic")
DEFAULT_DEVELOPMENT_SEEDS = (271001, 271003, 271005, 271007)
DEFAULT_HELDOUT_SEEDS = (281001, 281003, 281005, 281007)
DEFAULT_PROFILES = ("nominal", "stress")
SPECTRUM_FFT_SIZE = 4096
SPECTRUM_OVERLAP = 2048


def _q15_to_complex(samples):
    return [complex(int(i), int(q)) / 32768.0 for i, q in samples]


def _float_interpolate_x2(samples, method):
    result = []
    if method == "causal":
        coeffs = INTERP_COEFFS_Q14[2]
        history = [(0.0, 0.0)]
        for current in samples:
            terms = [current, *history]
            odd = tuple(sum(term[axis] * coeff
                            for term, coeff in zip(terms, coeffs)) / 16384.0
                        for axis in (0, 1))
            result.extend((current, odd))
            history = [current]
        return result
    coeffs = (-1024, 9216, 9216, -1024)
    for index, current in enumerate(samples):
        terms = [samples[position] if 0 <= position < len(samples) else (0.0, 0.0)
                 for position in (index - 1, index, index + 1, index + 2)]
        odd = tuple(sum(term[axis] * coeff
                        for term, coeff in zip(terms, coeffs)) / 16384.0
                    for axis in (0, 1))
        result.extend((current, odd))
    return result


def _float_interpolate_x4(samples, method):
    if method == "causal":
        return _float_interpolate_x2(_float_interpolate_x2(samples, method), method)
    padded = list(samples) + [(0.0, 0.0)] * 3
    stage1 = _float_interpolate_x2(padded, method)
    return _float_interpolate_x2(stage1, method)[:4 * len(samples)]


def _fixed_point_error(input_iq, output_iq, method):
    reference = _float_interpolate_x4(
        [(i / 32768.0, q / 32768.0) for i, q in input_iq], method)
    actual = [(i / 32768.0, q / 32768.0) for i, q in output_iq]
    errors = [abs(actual[n][axis] - reference[n][axis]) * 32768.0
              for n in range(len(actual)) for axis in (0, 1)]
    return {
        "rms_component_error_lsb": math.sqrt(
            sum(value * value for value in errors) / max(1, len(errors))),
        "max_component_error_lsb": max(errors, default=0.0),
        "rail_valued_output_components": sum(
            value in (-32768, 32767) for pair in output_iq for value in pair),
        "component_count": len(errors),
        "reference": "high-precision same-coefficient cascade; Q14 rounding/saturation included in measured error",
    }


def _papr_db(samples):
    if not samples:
        return None
    mean_power = sum(abs(value) ** 2 for value in samples) / len(samples)
    peak_power = max(abs(value) ** 2 for value in samples)
    return 10.0 * math.log10(max(peak_power, 1e-30) /
                              max(mean_power, 1e-30))


def _spectrum(samples, sample_rate_hz, occupied_bw_hz,
              image_centers_hz=(), fft_size=SPECTRUM_FFT_SIZE):
    if len(samples) < fft_size:
        raise ValueError("waveform is shorter than the spectrum segment")
    hop = fft_size - SPECTRUM_OVERLAP
    bin_power = [0.0] * fft_size
    segment_count = 0
    window = [0.42 - 0.5 * math.cos(2.0 * math.pi * n / (fft_size - 1)) +
              0.08 * math.cos(4.0 * math.pi * n / (fft_size - 1))
              for n in range(fft_size)]
    for start in range(0, len(samples) - fft_size + 1, hop):
        transformed = fft([complex(samples[start + n]) * window[n]
                           for n in range(fft_size)])
        for index, value in enumerate(transformed):
            bin_power[index] += abs(value) ** 2
        segment_count += 1
    if not segment_count:
        raise ValueError("no complete spectrum segments")
    bin_power = [value / segment_count for value in bin_power]

    def bin_frequency(index):
        signed = index if index <= fft_size // 2 else index - fft_size
        return signed * sample_rate_hz / fft_size

    main = [index for index in range(fft_size)
            if abs(bin_frequency(index)) <= occupied_bw_hz / 2.0]
    adjacent = [index for index in range(fft_size)
                if occupied_bw_hz / 2.0 < abs(bin_frequency(index)) <=
                1.5 * occupied_bw_hz]
    image = [index for index in range(fft_size)
             if any(abs(abs(bin_frequency(index)) - center) <=
                    occupied_bw_hz / 2.0 for center in image_centers_hz)]
    main_power = sum(bin_power[index] for index in main)
    adjacent_power = sum(bin_power[index] for index in adjacent)
    image_power = sum(bin_power[index] for index in image)
    noise_floor = max(main_power, 1e-30)
    psd_db = [10.0 * math.log10(max(value, 1e-30) / noise_floor)
              for value in bin_power]
    return {
        "sample_rate_hz": float(sample_rate_hz),
        "fft_size": fft_size,
        "segments": segment_count,
        "mainband_power": main_power,
        "adjacent_band_proxy_dbc": 10.0 * math.log10(
            max(adjacent_power, 1e-30) / max(main_power, 1e-30)),
        "first_interpolation_image_dbc": (
            10.0 * math.log10(max(image_power, 1e-30) /
                              max(main_power, 1e-30)) if image_centers_hz else None),
        "frequency_hz": [bin_frequency(index) for index in range(fft_size)],
        "relative_psd_db": psd_db,
    }


def _constellation(baseband, stimulus, metrics):
    data = baseband[stimulus["data_start"]:
                    stimulus["data_start"] + stimulus["data_samples"]]
    received, expected = [], []
    frame_size = NFFT + NCP
    for symbol in range(stimulus["symbols"]):
        start = symbol * frame_size + NCP
        spectrum = fft(data[start:start + NFFT])
        for carrier_index, carrier in enumerate(stimulus["active_bins"]):
            received.append(spectrum[carrier % NFFT])
            expected.append(stimulus["qam_rows"][symbol][carrier_index])
    gain = complex(*metrics["global_complex_equalizer"])
    return [(gain * actual, reference)
            for actual, reference in zip(received, expected)]


def _run_seed(seed, partition, symbols, rms_drive, rx_fir_taps,
              profiles, first_order_steps):
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    input_iq = stimulus["source_iq"]
    source = _q15_to_complex(input_iq)
    source_papr = _papr_db(source)
    raw_results = []
    interpolated = {}

    for method in INTERPOLATORS:
        output_pairs = interpolate_x4(input_iq, "rtl2" if method == "causal" else method)
        output_i = [pair[0] for pair in output_pairs]
        output_q = [pair[1] for pair in output_pairs]
        interpolated[method] = {
            "pairs": output_pairs,
            "i": output_i,
            "q": output_q,
            "complex": [complex(i, q) / 32768.0 for i, q in output_pairs],
            "fixed_point_error": _fixed_point_error(input_iq, output_pairs, method),
        }

    # Interpolation spectra are architecture-independent across TID/STEP
    # variants, so compute them once per method and seed.
    interpolation_spectra = {
        method: _spectrum(
            interp["complex"], SOURCE_FS_HZ * 4.0,
            stimulus["actual_bandwidth_hz"], image_centers_hz=(SOURCE_FS_HZ,))
        for method, interp in interpolated.items()
    }

    for method, interp in interpolated.items():
        steps = first_order_steps if method in INTERPOLATORS else ()
        for step in steps:
            planes, model_stats = generate_thermo5_tidsm_planes(
                interp["i"], interp["q"], step, mode="rtl_first_order",
                rtl_latency_samples=0)
            raw_results.append((method, "first_order", step, planes,
                                model_stats, interp))
        planes, model_stats = generate_thermo5_tidsm_planes(
            interp["i"], interp["q"], 5120, mode="ef_order2_fixed",
            state_width=20)
        raw_results.append((method, "ef2", 5120, planes, model_stats, interp))

    # Anchor every modeled PA output-power setting to the frozen product cell.
    product = next(item for item in raw_results
                   if item[0] == "centered_cubic" and item[1] == "ef2")
    product_bb7, _ = reconstruct_baseband_7g(
        product[3], stimulus["actual_bandwidth_hz"], latency_samples=0,
        fir_taps=rx_fir_taps)
    product_analog = _analog_metrics(product_bb7, stimulus, profiles, rx_fir_taps)
    common_output_rms = {
        item["profile"]: item["dpa_output_rms_normalized"]
        for item in product_analog
    }

    records = []
    psd_records = {}
    for method, order, step, planes, model_stats, interp in raw_results:
        baseband_7g, fs4_config = reconstruct_baseband_7g(
            planes, stimulus["actual_bandwidth_hz"], latency_samples=0,
            fir_taps=rx_fir_taps)
        baseband, receiver_config = receive_filter_decimate(
            baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=rx_fir_taps)
        digital = demodulate_metrics(baseband, stimulus)
        profiles_result = _analog_metrics(
            baseband_7g, stimulus, profiles, rx_fir_taps,
            reference_output_rms=common_output_rms)
        key = "%s_%s_step%d" % (order, method, step)
        if key not in psd_records:
            psd_records[key] = _spectrum(
                baseband_7g, SOURCE_FS_HZ * 4.0,
                stimulus["actual_bandwidth_hz"],
                image_centers_hz=(SOURCE_FS_HZ,))
        interp_psd = interpolation_spectra[method]
        branch_diagnostics = model_stats.get("branch_diagnostics", [])
        if order == "ef2":
            state_sats = sum(
                component.get("state_saturation_samples", 0)
                for branch in branch_diagnostics
                for component in (branch.get("i", {}), branch.get("q", {})))
            input_sats = sum(
                component.get("input_saturation_samples", 0)
                for branch in branch_diagnostics
                for component in (branch.get("i", {}), branch.get("q", {})))
        else:
            state_sats = 0
            input_sats = sum(item.get("input_saturation_samples", 0)
                             for item in branch_diagnostics)
        row = {
            "seed": int(seed),
            "partition": partition,
            "architecture": key,
            "interpolator": method,
            "tidsm": order,
            "step": int(step),
            "state_width_bits": model_stats.get("state_width_bits"),
            "symbols": int(symbols),
            "qam_order": 256,
            "input_rms": stimulus["input_rms"],
            "input_peak": stimulus["input_peak"],
            "source_papr_db": source_papr,
            "interpolated_papr_db": _papr_db(interp["complex"]),
            "expanded_samples_per_input_sample": len(interp["i"]) / len(input_iq),
            "logical_throughput_contract": "one 8-sample source vector maps to one 32-sample TID vector; no hardware timing claim",
            "interpolator_lookahead_input_samples": (
                0.0 if method == "causal" else
                centered_cubic_stream_contract(8)[
                    "max_future_dependency_source_samples"]),
            "interpolator_fixed_point_error": interp["fixed_point_error"],
            "input_saturation_count": int(input_sats),
            "state_saturation_count": int(state_sats),
            "quantizer_overrange_count": int(model_stats.get(
                "quantizer_overrange_samples", 0) or 0),
            "tid_model": model_stats,
            "tid_logical_latency_removed_samples": 0,
            "receiver": {"fs4": fs4_config, "channel_filter": receiver_config},
            "digital": digital,
            "spectrum_after_interpolation": {
                key: value for key, value in interp_psd.items()
                if key not in ("frequency_hz", "relative_psd_db")
            },
            "spectrum_after_tid_reconstruction": {
                key: value for key, value in psd_records[key].items()
                if key not in ("frequency_hz", "relative_psd_db")
            },
            "analog_profiles": profiles_result,
        }
        row["_constellation"] = _constellation(baseband, stimulus, digital)
        row["_baseband_7g"] = baseband_7g
        row["_interpolated_complex"] = interp["complex"]
        records.append(row)

    # Store spectrum arrays once per architecture/seed record group.
    spectra = {}
    for row in records:
        key = row["architecture"]
        if key not in spectra:
            spectra[key] = {
                "interpolation": interpolation_spectra[row["interpolator"]],
                "tid_reconstructed": psd_records[key],
            }
    for row in records:
        del row["_baseband_7g"]
        del row["_interpolated_complex"]
    return records, spectra, stimulus


def _summarize(records):
    summaries = []
    groups = sorted({(row["architecture"], row["partition"]) for row in records})
    for key, partition in groups:
        rows = [row for row in records
                if row["architecture"] == key and row["partition"] == partition]
        errors = sum(row["digital"]["uncoded_bit_errors_natural_binary"]
                     for row in rows)
        bits = sum(row["digital"]["qam_symbols"] * 8 for row in rows)
        e_v_m = [row["digital"]["evm_percent"] for row in rows]
        sndr = [row["digital"]["sndr_db"] for row in rows]
        entry = {
            "architecture": key,
            "partition": partition,
            "interpolator": rows[0]["interpolator"],
            "tidsm": rows[0]["tidsm"],
            "step": rows[0]["step"],
            "state_width_bits": rows[0]["state_width_bits"],
            "seed_count": len(rows),
            "partitions": sorted({row["partition"] for row in rows}),
            "uncoded_bit_errors": errors,
            "uncoded_bits": bits,
            "uncoded_ber": errors / max(1, bits),
            "mean_evm_percent": statistics.mean(e_v_m),
            "worst_seed_evm_percent": max(e_v_m),
            "mean_sndr_db": statistics.mean(sndr),
            "worst_seed_sndr_db": min(sndr),
            "source_papr_db": statistics.mean(row["source_papr_db"] for row in rows),
            "mean_interpolated_papr_db": statistics.mean(
                row["interpolated_papr_db"] for row in rows),
            "input_saturation_samples": sum(row["input_saturation_count"] for row in rows),
            "state_saturation_samples": sum(row["state_saturation_count"] for row in rows),
            "quantizer_overrange_samples": sum(row["quantizer_overrange_count"] for row in rows),
            "mean_interpolator_rms_error_lsb": statistics.mean(
                row["interpolator_fixed_point_error"]["rms_component_error_lsb"]
                for row in rows),
            "max_interpolator_error_lsb": max(
                row["interpolator_fixed_point_error"]["max_component_error_lsb"]
                for row in rows),
        }
        entry["analog"] = {}
        profile_names = [item["profile"] for item in rows[0]["analog_profiles"]]
        for profile in profile_names:
            profile_rows = [next(p for p in row["analog_profiles"]
                                 if p["profile"] == profile) for row in rows]
            noisy = [item["metrics_after_thermal_noise"] for item in profile_rows]
            analog_errors = sum(item["uncoded_bit_errors_natural_binary"]
                                for item in noisy)
            analog_bits = sum(item["qam_symbols"] * 8 for item in noisy)
            entry["analog"][profile] = {
                "uncoded_bit_errors": analog_errors,
                "uncoded_bits": analog_bits,
                "uncoded_ber": analog_errors / max(1, analog_bits),
                "mean_evm_after_noise_percent": statistics.mean(
                    item["evm_percent"] for item in noisy),
                "worst_seed_evm_after_noise_percent": max(
                    item["evm_percent"] for item in noisy),
                "mean_modeled_output_power_dbm": statistics.mean(
                    item["modeled_signal_power_dbm"] for item in profile_rows),
                "mean_adjacent_band_proxy_dbc": statistics.mean(
                    row["spectrum_after_tid_reconstruction"][
                        "adjacent_band_proxy_dbc"] for row in rows),
            }
        summaries.append(entry)
    return summaries


def _average_spectra(spectrum_samples):
    averaged = []
    for (partition, architecture), samples in sorted(spectrum_samples.items()):
        stages = {}
        for stage in samples[0]:
            reference = samples[0][stage]
            power_rows = [item[stage]["relative_psd_db"] for item in samples]
            mean_linear = [statistics.mean(
                10.0 ** (row[index] / 10.0) for row in power_rows)
                for index in range(len(reference["relative_psd_db"]))]
            stages[stage] = {
                "sample_rate_hz": reference["sample_rate_hz"],
                "fft_size": reference["fft_size"],
                "segments_per_seed": [item[stage]["segments"] for item in samples],
                "seed_count": len(samples),
                "frequency_hz": reference["frequency_hz"],
                "relative_psd_db": [10.0 * math.log10(max(value, 1e-30))
                                    for value in mean_linear],
            }
        averaged.append({"partition": partition, "architecture": architecture,
                         "stages": stages})
    return averaged


def _write_constellation_svg(path, records):
    heldout = [row for row in records if row["partition"] == "heldout"]
    if not heldout:
        return
    labels = sorted({row["architecture"] for row in heldout})
    width, height, cols, rows = 1200, 820, 3, 2
    panel_w, panel_h = width / cols, (height - 60) / rows
    pad = 44
    scale = min((panel_w - 2 * pad) / 2.5, (panel_h - 2 * pad) / 2.5)
    colors = ("#005f73", "#bb3e03", "#0a9396", "#9b2226", "#6a4c93", "#3a5a40")
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="white"/>',
             f'<text x="{width/2}" y="26" text-anchor="middle" font-family="sans-serif" font-size="18">Held-out QAM256 constellation, shared scale</text>']
    qam_scale = math.sqrt(170.0)
    for arch_index, architecture in enumerate(labels):
        col, row_index = arch_index % cols, arch_index // cols
        left, top = col * panel_w, 45 + row_index * panel_h
        center_x, center_y = left + panel_w / 2, top + panel_h / 2
        color = colors[arch_index % len(colors)]
        parts.append(f'<rect x="{left+8:.1f}" y="{top+4:.1f}" width="{panel_w-16:.1f}" height="{panel_h-8:.1f}" fill="none" stroke="#ddd"/>')
        parts.append(f'<text x="{center_x:.1f}" y="{top+22:.1f}" text-anchor="middle" font-family="sans-serif" font-size="13">{architecture}</text>')
        parts.append(f'<line x1="{center_x-scale*1.25:.1f}" y1="{center_y:.1f}" x2="{center_x+scale*1.25:.1f}" y2="{center_y:.1f}" stroke="#bbb"/>')
        parts.append(f'<line x1="{center_x:.1f}" y1="{center_y-scale*1.25:.1f}" x2="{center_x:.1f}" y2="{center_y+scale*1.25:.1f}" stroke="#bbb"/>')
        for row in heldout:
            if row["architecture"] != architecture:
                continue
            constellation = row["_constellation"]
            stride = max(1, math.ceil(len(constellation) / 1500))
            for actual, _expected in constellation[::stride]:
                x = center_x + actual.real * scale
                y = center_y - actual.imag * scale
                if left + pad <= x <= left + panel_w - pad and top + pad <= y <= top + panel_h - pad:
                    parts.append(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="1.1" fill="{color}" fill-opacity="0.30"/>')
        for i_level in range(16):
            for q_level in range(16):
                x_value = (2 * i_level - 15) / qam_scale
                y_value = (2 * q_level - 15) / qam_scale
                x, y = center_x + x_value * scale, center_y - y_value * scale
                parts.append(f'<path d="M{x-2:.2f},{y:.2f}h4 M{x:.2f},{y-2:.2f}v4" stroke="#777" stroke-width="0.65"/>')
        parts.append(f'<text x="{center_x:.1f}" y="{top+panel_h-8:.1f}" text-anchor="middle" font-family="sans-serif" font-size="10">In-phase</text>')
    parts.append('</svg>')
    path.write_text("\n".join(parts) + "\n")


def run(development_seeds=DEFAULT_DEVELOPMENT_SEEDS,
        heldout_seeds=DEFAULT_HELDOUT_SEEDS, symbols=4, rms_drive=0.10,
        rx_fir_taps=RX_FIR_TAPS, profiles=DEFAULT_PROFILES,
        first_order_steps=(5120, 7168), jobs=1):
    development_seeds = tuple(int(seed) for seed in development_seeds)
    heldout_seeds = tuple(int(seed) for seed in heldout_seeds)
    if not development_seeds or not heldout_seeds:
        raise ValueError("development and held-out seeds must be non-empty")
    if set(development_seeds) & set(heldout_seeds):
        raise ValueError("development and held-out seeds must be disjoint")
    if symbols < 1 or not 0.0 < rms_drive <= 0.35:
        raise ValueError("symbols must be positive and RMS drive must be <= 0.35")
    if jobs < 1:
        raise ValueError("jobs must be positive")
    if rx_fir_taps < 3 or rx_fir_taps % 2 == 0:
        raise ValueError("receiver FIR length must be odd and >= 3")
    if not profiles or any(profile not in PA_OUTPUT_PROFILES for profile in profiles):
        raise ValueError("unknown or empty PA profile set")
    if not first_order_steps or any(int(step) <= 0 for step in first_order_steps):
        raise ValueError("first-order STEP values must be positive")

    records = []
    spectrum_samples = {}
    constellation_seed = None
    tasks = [(seed, partition, symbols, rms_drive, rx_fir_taps,
              tuple(profiles), tuple(int(step) for step in first_order_steps))
             for partition, seeds in (("development", development_seeds),
                                      ("heldout", heldout_seeds))
             for seed in seeds]
    if jobs == 1:
        seed_results = [_run_seed(*task) for task in tasks]
    else:
        with Pool(processes=jobs) as pool:
            seed_results = pool.starmap(_run_seed, tasks)
    for task, (seed_records, seed_spectra, _stimulus) in zip(tasks, seed_results):
        seed, partition = task[:2]
        records.extend(seed_records)
        for architecture, stages in seed_spectra.items():
            spectrum_samples.setdefault((partition, architecture), []).append(stages)
        if partition == "heldout" and constellation_seed is None:
            constellation_seed = seed
    summaries = _summarize(records)
    spectra = _average_spectra(spectrum_samples)
    return {
        "benchmark": "thermo5_tx_four_architecture_ablation",
        "status": "MODEL_ONLY_REQUIRES_TARGET_REVIEW",
        "product": {
            "interpolator": "centered cubic x2+x2",
            "tidsm_order": 2,
            "step": 5120,
            "state_width_bits": 20,
            "dpd": "one-tap identity",
        },
        "waveform": {
            "qam_order": 256, "nfft": NFFT, "cyclic_prefix": NCP,
            "active_subcarriers": ACTIVE_CARRIERS,
            "occupied_bandwidth_hz": OCCUPIED_BW_HZ,
            "source_sample_rate_hz": SOURCE_FS_HZ,
            "rms_drive": rms_drive, "symbols_per_seed": symbols,
            "guard_samples_each_side": GUARD_SAMPLES,
            "development_seeds": list(development_seeds),
            "heldout_seeds": list(heldout_seeds),
        },
        "receiver": {
            "type": "same offline Blackman linear-phase filters for all cells",
            "fir_taps": rx_fir_taps,
            "timing": "Known filter delays compensated; model pipeline latency removed; no candidate-specific timing fit",
            "qam_ber": "uncoded natural-binary bit labels; not Gray-coded BER",
        },
        "candidate_contract": {
            "primary_common_step": 5120,
            "first_order_sensitivity_steps": list(first_order_steps),
            "ef2_step": 5120,
            "ef2_recurrence": "u[n]=x[n]+2e1[n-1]-e2[n-1]; e[n]=sat20(u[n]-sign(u[n]))",
            "causal_interpolator": "two cascaded x2 Q14 RTL FIR stages; [0.5,0.5] at each midpoint",
            "centered_interpolator": "two cascaded x2 Q14 [-1,9,9,-1]/16 stages; block-mode zero extension",
            "pipeline_latency": "removed at the algorithm boundary for communication comparison; streaming latency remains a separate RTL property",
            "throughput": "digital data-rate contract only, no hardware Fmax/II claim",
        },
        "pa_profiles": {
            name: {key: ([[tap.real, tap.imag] for tap in value]
                         if key == "output_network_taps" else value)
                  for key, value in PA_OUTPUT_PROFILES[name].items()}
            for name in profiles
        },
        "summaries": summaries,
        "records": [{key: value for key, value in row.items()
                     if not key.startswith("_")} for row in records],
        "spectra": spectra,
        "constellation_seed": constellation_seed,
        "limits": [
            "Behavioral DPA, output filter, power, and noise settings are sensitivity assumptions, not calibration.",
            "The adjacent-band metric is a proxy, not standards ACLR.",
            "No FPGA resources, timing, routed result, physical BER, or product acceptance threshold is established.",
        ],
    }


def _csv_summary(path, summaries):
    if not summaries:
        return
    fields = ["partition", "architecture", "interpolator", "tidsm", "step", "state_width_bits",
              "seed_count", "uncoded_bit_errors", "uncoded_bits",
              "uncoded_ber", "mean_evm_percent", "worst_seed_evm_percent",
              "mean_sndr_db", "worst_seed_sndr_db", "source_papr_db",
              "mean_interpolated_papr_db", "max_interpolator_error_lsb",
              "mean_interpolator_rms_error_lsb",
              "input_saturation_samples", "state_saturation_samples",
              "quantizer_overrange_samples",
              "nominal_analog_uncoded_ber", "nominal_analog_mean_evm_percent",
              "nominal_modeled_output_power_dbm", "nominal_adjacent_band_proxy_dbc",
              "stress_analog_uncoded_ber", "stress_analog_mean_evm_percent",
              "stress_modeled_output_power_dbm", "stress_adjacent_band_proxy_dbc"]
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for row in summaries:
            flat = {key: row.get(key) for key in fields}
            for profile in ("nominal", "stress"):
                metrics = row.get("analog", {}).get(profile, {})
                flat[profile + "_analog_uncoded_ber"] = metrics.get("uncoded_ber")
                flat[profile + "_analog_mean_evm_percent"] = metrics.get(
                    "mean_evm_after_noise_percent")
                flat[profile + "_modeled_output_power_dbm"] = metrics.get(
                    "mean_modeled_output_power_dbm")
                flat[profile + "_adjacent_band_proxy_dbc"] = metrics.get(
                    "mean_adjacent_band_proxy_dbc")
            writer.writerow(flat)


def _arg_seeds(value):
    try:
        return tuple(int(item.strip(), 0) for item in value.split(",") if item.strip())
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--development-seeds", type=_arg_seeds,
                        default=DEFAULT_DEVELOPMENT_SEEDS)
    parser.add_argument("--heldout-seeds", type=_arg_seeds,
                        default=DEFAULT_HELDOUT_SEEDS)
    parser.add_argument("--symbols", type=int, default=4)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--rx-fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--first-order-steps", type=_arg_seeds,
                        default=(5120, 7168))
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--summary-csv", type=Path, required=True)
    parser.add_argument("--psd-csv", type=Path, required=True)
    parser.add_argument("--constellation-svg", type=Path, required=True)
    args = parser.parse_args()
    result = run(args.development_seeds, args.heldout_seeds, args.symbols,
                 args.rms_drive, args.rx_fir_taps,
                 first_order_steps=args.first_order_steps, jobs=args.jobs)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    _csv_summary(args.summary_csv, result["summaries"])
    # Spectra were averaged across seeds per architecture in run(); emit them
    # directly so the PSD table remains small and reproducible.
    with args.psd_csv.open("w", newline="") as stream:
        fields = ("partition", "architecture", "stage", "bin", "frequency_hz",
                  "relative_psd_db")
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for spectrum_row in result["spectra"]:
            partition = spectrum_row["partition"]
            architecture = spectrum_row["architecture"]
            stages = spectrum_row["stages"]
            for stage, spec in stages.items():
                for index, (frequency, power) in enumerate(zip(
                        spec["frequency_hz"], spec["relative_psd_db"])):
                    writer.writerow({"partition": partition,
                                     "architecture": architecture, "stage": stage,
                                     "bin": index, "frequency_hz": "%.3f" % frequency,
                                     "relative_psd_db": "%.6f" % power})
    # Rebuild one held-out constellation seed for a compact SVG plot.
    heldout_seed = result["constellation_seed"]
    plot_records, _, _ = _run_seed(
        heldout_seed, "heldout", args.symbols, args.rms_drive,
        args.rx_fir_taps, DEFAULT_PROFILES, args.first_order_steps)
    _write_constellation_svg(args.constellation_svg, plot_records)
    for row in result["summaries"]:
        print("%-10s %-38s BER=%8.3g EVM=%6.3f%% SNDR=%6.2fdB state_sat=%d" % (
            row["partition"], row["architecture"], row["uncoded_ber"], row["mean_evm_percent"],
            row["mean_sndr_db"], row["state_saturation_samples"]))
    print("wrote JSON/CSV/PSD/constellation outputs")


if __name__ == "__main__":
    main()
