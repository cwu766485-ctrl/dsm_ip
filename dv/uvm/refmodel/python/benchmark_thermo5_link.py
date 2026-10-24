#!/usr/bin/env python3
"""Compare interpolation candidates through a deterministic DPA/output chain.

Digital interpolation and DPA/output-network distortion are reported before
random analog noise is added. GT bit errors are modeled separately on the
four 64-bit TID planes by ``benchmark_thermo5_gt.py``; they are not noise.
"""

import argparse
import json
import math
import random
from pathlib import Path

from benchmark_thermo5_interp import (
    ACTIVE_EDGE_BIN,
    FFT_SIZE,
    IMAGE_CENTER_BIN,
    IMAGE_HALF_WIDTH,
    cascade,
    fft,
    ideal_4x,
    make_ofdm_symbol,
)
from dsm_refmodel.link_models import (
    BehavioralDPA,
    add_thermal_noise,
    apply_complex_fir,
)


OVERSAMPLE = 4
ADJACENT_LOW_BIN = 64
ADJACENT_HIGH_BIN = 115
METHODS = ("rtl2", "rtl3", "rtl4", "forward_linear", "centered_cubic")


DPA_MILD = {
    "dpa_saturation": 0.82,
    "dpa_smoothness": 2.0,
    "dpa_ampm_degrees": 5.0,
    "dpa_envelope_memory": 0.15,
}
DPA_STRESS = {
    "dpa_saturation": 0.68,
    "dpa_smoothness": 1.7,
    "dpa_ampm_degrees": 10.0,
    "dpa_envelope_memory": 0.10,
}


PROFILES = {
    "ideal": {
        "description": "No DPA, output-network distortion, or analog noise",
        "dpa": False, "output_filter_taps": [[1.0, 0.0]],
        "noise_enabled": False, **DPA_MILD,
    },
    "dpa_only": {
        "description": "Deterministic DPA AM/AM, AM/PM, and envelope-memory distortion",
        "dpa": True, "output_filter_taps": [[1.0, 0.0]],
        "noise_enabled": False, **DPA_MILD,
    },
    "network_only": {
        "description": "Deterministic complex-envelope output-network response",
        "dpa": False,
        "output_filter_taps": [[1.0, 0.0], [0.04, -0.02], [0.01, 0.008]],
        "noise_enabled": False, **DPA_MILD,
    },
    "analog_nominal": {
        "description": "Mild DPA/network plus kTB thermal noise at the observation plane",
        "dpa": True,
        "output_filter_taps": [[1.0, 0.0], [0.02, -0.01], [0.005, 0.004]],
        "noise_enabled": True, "signal_power_dbm": -30.0,
        "noise_bandwidth_hz": 20e6, "noise_figure_db": 6.0,
        "temperature_k": 290.0, **DPA_MILD,
    },
    "analog_stress": {
        "description": "Strong DPA/network plus raised kTB noise from lower output power",
        "dpa": True,
        "output_filter_taps": [[1.0, 0.0], [0.07, -0.035], [0.02, 0.015]],
        "noise_enabled": True, "signal_power_dbm": -50.0,
        "noise_bandwidth_hz": 40e6, "noise_figure_db": 10.0,
        "temperature_k": 290.0, **DPA_STRESS,
    },
    "custom": {
        "description": "User-configured DPA/output-network/thermal-noise profile",
        "dpa": True,
        "output_filter_taps": [[1.0, 0.0], [0.02, -0.01], [0.005, 0.004]],
        "noise_enabled": True, "signal_power_dbm": -30.0,
        "noise_bandwidth_hz": 20e6, "noise_figure_db": 6.0,
        "temperature_k": 290.0, **DPA_MILD,
    },
}


def _symbol_metrics(output, reference):
    error = sum(abs(actual - expected) ** 2
                for actual, expected in zip(output, reference))
    reference_energy = sum(abs(value) ** 2 for value in reference)
    output_energy = sum(abs(value) ** 2 for value in output)
    # Least-squares scalar equalization: choose g so g * output ~= reference.
    cross = sum(expected * actual.conjugate()
                for actual, expected in zip(output, reference))
    gain = cross / max(output_energy, 1e-30)
    fitted_error = sum(abs(gain * actual - expected) ** 2
                       for actual, expected in zip(output, reference))

    spectrum = fft(output)
    main_power = 0.0
    adjacent_power = 0.0
    image_power = 0.0
    for index, value in enumerate(spectrum):
        signed = index if index <= len(spectrum) // 2 else index - len(spectrum)
        absolute_bin = abs(signed)
        power = abs(value) ** 2
        if absolute_bin <= ACTIVE_EDGE_BIN + 2:
            main_power += power
        if ADJACENT_LOW_BIN <= absolute_bin <= ADJACENT_HIGH_BIN:
            adjacent_power += power
        if abs(absolute_bin - IMAGE_CENTER_BIN) <= IMAGE_HALF_WIDTH:
            image_power += power
    return (error, fitted_error, reference_energy, output_energy, main_power,
            adjacent_power, image_power)


def _aggregate_metrics(output, references):
    totals = [0.0] * 7
    symbol_length = FFT_SIZE * OVERSAMPLE
    for symbol_index, reference in enumerate(references):
        start = symbol_index * symbol_length
        values = _symbol_metrics(output[start:start + symbol_length], reference)
        totals = [left + right for left, right in zip(totals, values)]
    error, fitted_error, ref_energy, _, main, adjacent, image = totals
    return {
        "rms_evm_percent": 100.0 * math.sqrt(error / max(ref_energy, 1e-30)),
        "gain_phase_corrected_evm_percent": 100.0 * math.sqrt(
            fitted_error / max(ref_energy, 1e-30)),
        "adjacent_leakage_proxy_dbc": 10.0 * math.log10(
            max(adjacent, 1e-30) / max(main, 1e-30)),
        "first_image_rejection_dbc": -10.0 * math.log10(
            max(image, 1e-30) / max(main, 1e-30)),
    }


def _pa_for_profile(profile):
    if not profile["dpa"]:
        return None
    return BehavioralDPA(
        saturation=profile["dpa_saturation"],
        smoothness=profile["dpa_smoothness"],
        ampm_degrees=profile["dpa_ampm_degrees"],
        envelope_memory=profile["dpa_envelope_memory"])


def _normalized_taps(profile):
    return tuple(complex(real, imag)
                 for real, imag in profile["output_filter_taps"])


def run(symbols=16, seed=20261023, profiles=None, custom_overrides=None):
    if symbols < 1:
        raise ValueError("symbols must be positive")
    selected_profiles = profiles or tuple(
        name for name in PROFILES if name != "custom")
    rng = random.Random(seed)
    source_symbols = [make_ofdm_symbol(rng) for _ in range(symbols)]
    references = [ideal_4x(source) for source in source_symbols]
    candidates = {
        method: [complex(real, imag) / 32768.0
                 for source in source_symbols
                 for real, imag in cascade(source, method)]
        for method in METHODS
    }

    profile_results = []
    for profile_index, name in enumerate(selected_profiles):
        profile = dict(PROFILES[name])
        if name == "custom" and custom_overrides:
            profile.update(custom_overrides)
        per_method = []
        for method in METHODS:
            digital_signal = candidates[method]
            digital_metrics = _aggregate_metrics(digital_signal, references)

            dpa = _pa_for_profile(profile)
            deterministic_signal = (dpa.process(digital_signal)
                                    if dpa is not None else list(digital_signal))
            deterministic_signal = apply_complex_fir(
                deterministic_signal, _normalized_taps(profile))
            deterministic_metrics = _aggregate_metrics(
                deterministic_signal, references)

            noise_stats = None
            final_signal = deterministic_signal
            if profile["noise_enabled"]:
                final_signal, noise_stats = add_thermal_noise(
                    deterministic_signal,
                    random.Random(seed + 1009 * profile_index + 7919),
                    signal_power_dbm=profile["signal_power_dbm"],
                    bandwidth_hz=profile["noise_bandwidth_hz"],
                    noise_figure_db=profile["noise_figure_db"],
                    temperature_k=profile["temperature_k"])
            final_metrics = _aggregate_metrics(final_signal, references)

            noise_energy = sum(abs(a - b) ** 2 for a, b in
                               zip(final_signal, deterministic_signal))
            total_reference_energy = sum(sum(abs(value) ** 2 for value in ref)
                                         for ref in references)
            noise_evm = (100.0 * math.sqrt(noise_energy /
                                         max(total_reference_energy, 1e-30)))
            per_method.append({
                "method": method,
                "digital_interpolation": digital_metrics,
                "after_dpa_and_output_network": deterministic_metrics,
                "after_analog_noise": final_metrics,
                "noise_only_evm_percent": noise_evm,
                "thermal_noise": noise_stats,
                "estimated_real_multiplies_per_source_complex_sample":
                    8 if method in ("rtl2", "forward_linear") else
                    (12 if method == "rtl3" else 16),
            })
        profile_results.append({
            "profile": name,
            "description": profile["description"],
            "assumptions": profile,
            "results": per_method,
        })

    return {
        "benchmark": "thermo5_interpolation_dpa_analog_noise_screen",
        "seed": seed,
        "symbols": symbols,
        "fft_size": FFT_SIZE,
        "oversample": OVERSAMPLE,
        "active_subcarriers": 100,
        "profiles": profile_results,
        "model_scope": [
            "Digital RTL arithmetic is deterministic; quantization and interpolation differences are reported as distortion, not random noise.",
            "GT errors are independent data-bit flips on four 64-bit TID planes in benchmark_thermo5_gt.py; no GT impairment is mixed into this analog EVM screen.",
            "DPA AM/AM, AM/PM, envelope memory, and complex output-network taps are deterministic behavioral approximations.",
            "Thermal noise uses kTB plus noise figure, scaled from normalized samples using declared average signal power at the observation plane.",
            "Noise bandwidth, signal power, and NF are illustrative until replaced with board or circuit measurements.",
            "EVM is sample-domain versus the ideal 4x waveform with one complex scalar fit per OFDM symbol; no demodulator or per-subcarrier equalizer is modeled.",
            "Adjacent leakage is a normalized FFT-bin proxy, not standards-compliant ACLR.",
            "The centered cubic candidate has future-sample lookahead and is not the frozen RTL implementation.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols", type=int, default=16)
    parser.add_argument("--seed", type=int, default=20261023)
    parser.add_argument("--profiles", default=",".join(
        name for name in PROFILES if name != "custom"),
                        help="comma-separated profile names: " + ",".join(PROFILES))
    parser.add_argument("--signal-power-dbm", type=float)
    parser.add_argument("--noise-bandwidth-hz", type=float)
    parser.add_argument("--noise-figure-db", type=float)
    parser.add_argument("--temperature-k", type=float)
    parser.add_argument("--dpa-saturation", type=float)
    parser.add_argument("--dpa-smoothness", type=float)
    parser.add_argument("--dpa-ampm-degrees", type=float)
    parser.add_argument("--dpa-envelope-memory", type=float)
    parser.add_argument("--no-dpa", action="store_true")
    parser.add_argument("--no-noise", action="store_true")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    names = tuple(name.strip() for name in args.profiles.split(",") if name.strip())
    unknown = sorted(set(names) - set(PROFILES))
    if unknown:
        parser.error("unknown profile(s): " + ",".join(unknown))
    if args.symbols < 1 or not names:
        parser.error("symbols must be positive and at least one profile is required")
    overrides = {
        "signal_power_dbm": args.signal_power_dbm,
        "noise_bandwidth_hz": args.noise_bandwidth_hz,
        "noise_figure_db": args.noise_figure_db,
        "temperature_k": args.temperature_k,
        "dpa_saturation": args.dpa_saturation,
        "dpa_smoothness": args.dpa_smoothness,
        "dpa_ampm_degrees": args.dpa_ampm_degrees,
        "dpa_envelope_memory": args.dpa_envelope_memory,
    }
    overrides = {key: value for key, value in overrides.items()
                 if value is not None}
    if args.no_dpa:
        overrides["dpa"] = False
    if args.no_noise:
        overrides["noise_enabled"] = False
    if overrides and "custom" not in names:
        parser.error("model parameter overrides require --profiles custom")
    result = run(args.symbols, args.seed, names, overrides)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")


if __name__ == "__main__":
    main()
