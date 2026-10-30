#!/usr/bin/env python3
"""Fit offline Q2.14 memory-polynomial DPD candidates with ILA.

The fit uses the existing deterministic behavioral DPA model and development
seeds only. It exports candidate coefficients; it never edits product defaults
or RTL. Held-out communication evaluation is performed by
``benchmark_thermo5_tx_dpd_ab.py``.
"""

import argparse
import json
import math
from pathlib import Path

from benchmark_thermo5_tid_receiver import (
    GUARD_SAMPLES,
    PA_OUTPUT_PROFILES,
    make_256qam_ofdm,
)
from dsm_refmodel.link_models import BehavioralDPA
from dsm_refmodel.thermo5 import _interp_x2_centered_pairs


COEFFICIENT_NAMES = ("c1_re", "c1_im", "c3_re", "c3_im", "c5_re", "c5_im")
COEFFICIENT_FRACTION_BITS = 14
COEFFICIENT_MIN = -(1 << 15)
COEFFICIENT_MAX = (1 << 15) - 1


def solve_complex_system(matrix, vector, pivot_floor=1e-18):
    """Solve a small dense complex system using Gaussian elimination."""
    size = len(vector)
    if size == 0 or len(matrix) != size or any(len(row) != size for row in matrix):
        raise ValueError("matrix must be non-empty and square")
    augmented = [list(map(complex, row)) + [complex(vector[index])]
                 for index, row in enumerate(matrix)]
    min_pivot = float("inf")
    max_pivot = 0.0
    for column in range(size):
        pivot = max(range(column, size),
                    key=lambda row: abs(augmented[row][column]))
        pivot_value = abs(augmented[pivot][column])
        if pivot_value <= pivot_floor:
            raise ArithmeticError("singular/ill-conditioned normal matrix")
        augmented[column], augmented[pivot] = augmented[pivot], augmented[column]
        min_pivot = min(min_pivot, pivot_value)
        max_pivot = max(max_pivot, pivot_value)
        scale = augmented[column][column]
        augmented[column] = [value / scale for value in augmented[column]]
        for row in range(size):
            if row == column:
                continue
            factor = augmented[row][column]
            if factor:
                augmented[row] = [left - factor * right
                                  for left, right in zip(
                                      augmented[row], augmented[column])]
    return [augmented[row][-1] for row in range(size)], {
        "min_abs_pivot": min_pivot,
        "max_abs_pivot": max_pivot,
        "pivot_ratio": min_pivot / max(max_pivot, pivot_floor),
    }


def _feature_vector(pa_output, sample_index, taps):
    features = []
    for tap in range(taps):
        index = sample_index - tap
        sample = pa_output[index] if index >= 0 else 0.0j
        power = abs(sample) ** 2
        features.extend((sample, sample * power, sample * power * power))
    return features


def _quantize_coefficients(solution, taps):
    coefficients = {name: [0] * 4 for name in COEFFICIENT_NAMES}
    clipping = 0
    for tap in range(taps):
        for order, real_name, imag_name in (
                (0, "c1_re", "c1_im"),
                (1, "c3_re", "c3_im"),
                (2, "c5_re", "c5_im")):
            value = solution[tap * 3 + order]
            for name, component in ((real_name, value.real),
                                    (imag_name, value.imag)):
                raw = int(round(component * (1 << COEFFICIENT_FRACTION_BITS)))
                limited = min(COEFFICIENT_MAX, max(COEFFICIENT_MIN, raw))
                clipping += int(raw != limited)
                coefficients[name][tap] = limited
    return coefficients, clipping


def _training_samples(seed, symbols, rms_drive, profile):
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    source = list(stimulus["source_iq"])
    # Match the first centered-cubic x2 stage before the vector DPD. The guard
    # zeros keep OFDM edges away from the fit window; the finite stream is
    # zero-extended at its end and cropped to exactly 2x.
    stage1 = _interp_x2_centered_pairs(source + [(0, 0)] * 3)[:2 * len(source)]
    input_signal = [complex(i, q) / 32768.0 for i, q in stage1]
    dpa = BehavioralDPA(
        saturation=profile["dpa_saturation"],
        smoothness=profile["dpa_smoothness"],
        ampm_degrees=profile["dpa_ampm_degrees"],
        envelope_memory=profile["dpa_envelope_memory"],
    )
    output_signal = dpa.process(input_signal)
    begin = max(4, 2 * GUARD_SAMPLES)
    end = max(begin, len(input_signal) - 2 * GUARD_SAMPLES)
    return input_signal, output_signal, begin, end


def fit_ila(seeds, symbols=12, rms_drive=0.10, taps=2,
            profile_name="nominal", ridge_relative=1e-5,
            samples_per_seed=8192):
    """Fit a regularized inverse polynomial and quantize it to signed Q2.14."""
    seeds = tuple(int(seed) for seed in seeds)
    if not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("development seeds must be non-empty and unique")
    if taps not in (2, 4):
        raise ValueError("only two- and four-tap candidates are supported")
    if symbols < 1 or samples_per_seed < 64 or not 0.0 < rms_drive <= 0.35:
        raise ValueError("invalid symbols, sample budget, or RMS drive")
    if ridge_relative < 0.0:
        raise ValueError("ridge_relative must be non-negative")
    if profile_name not in PA_OUTPUT_PROFILES:
        raise ValueError("unknown behavioral DPA profile")

    profile = PA_OUTPUT_PROFILES[profile_name]
    dimension = taps * 3
    gram = [[0.0j for _ in range(dimension)] for _ in range(dimension)]
    cross = [0.0j for _ in range(dimension)]
    selected_samples = 0
    training_peak = 0.0
    training_rms_sum = 0.0
    for seed in seeds:
        desired, pa_output, begin, end = _training_samples(
            seed, symbols, rms_drive, profile)
        if end <= begin:
            raise ValueError("training waveform has no non-guard samples")
        stride = max(1, math.ceil((end - begin) / samples_per_seed))
        indices = range(begin, end, stride)
        for index in indices:
            features = _feature_vector(pa_output, index, taps)
            target = desired[index]
            for left, left_value in enumerate(features):
                cross[left] += left_value.conjugate() * target
                for right, right_value in enumerate(features):
                    gram[left][right] += left_value.conjugate() * right_value
            selected_samples += 1
            training_peak = max(training_peak, abs(target))
            training_rms_sum += abs(target) ** 2

    raw_trace = sum(gram[index][index].real for index in range(dimension))
    ridge = ridge_relative * raw_trace / max(1, dimension)
    for index in range(dimension):
        gram[index][index] += ridge
    solution, solver_stats = solve_complex_system(gram, cross)
    quantized, clipping_count = _quantize_coefficients(solution, taps)
    coefficient_float = []
    for tap in range(taps):
        coefficient_float.append({
            "c1": [solution[tap * 3].real, solution[tap * 3].imag],
            "c3": [solution[tap * 3 + 1].real, solution[tap * 3 + 1].imag],
            "c5": [solution[tap * 3 + 2].real, solution[tap * 3 + 2].imag],
        })
    return {
        "name": "ila_%s_%dtap" % (profile_name, taps),
        "active_taps": taps,
        "coefficients": quantized,
        "fit": {
            "method": "indirect learning architecture: desired x[n] fit from PA-output y[n-k]*|y[n-k]|^(0,2,4)",
            "profile": profile_name,
            "development_seeds": list(seeds),
            "symbols_per_seed": symbols,
            "rms_drive": rms_drive,
            "fit_samples": selected_samples,
            "samples_per_seed_cap": samples_per_seed,
            "training_rms": math.sqrt(training_rms_sum / max(1, selected_samples)),
            "training_peak": training_peak,
            "ridge_relative": ridge_relative,
            "ridge_diagonal_added": ridge,
            "solver": solver_stats,
            "floating_coefficients": coefficient_float,
            "coefficient_format": "signed Q2.14, int16 saturation",
            "coefficient_clip_count": clipping_count,
            "model_note": "Fits the deterministic behavioral DPA at the first centered x2 interpolation stage; output network and noise are evaluated separately on held-out seeds.",
        },
    }


def fit_candidates(seeds, symbols=12, rms_drive=0.10,
                   profile_name="nominal", ridge_relative=1e-5,
                   samples_per_seed=8192):
    return [fit_ila(seeds, symbols, rms_drive, taps, profile_name,
                    ridge_relative, samples_per_seed)
            for taps in (2, 4)]


def _seed_list(value):
    try:
        result = tuple(int(item.strip(), 0) for item in value.split(",")
                       if item.strip())
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc
    if not result:
        raise argparse.ArgumentTypeError("seed list cannot be empty")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=_seed_list,
                        default=(271001, 271003, 271005, 271007))
    parser.add_argument("--symbols", type=int, default=12)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--profile", choices=tuple(PA_OUTPUT_PROFILES),
                        default="nominal")
    parser.add_argument("--ridge-relative", type=float, default=1e-5)
    parser.add_argument("--samples-per-seed", type=int, default=8192)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()
    candidates = fit_candidates(args.seeds, args.symbols, args.rms_drive,
                                args.profile, args.ridge_relative,
                                args.samples_per_seed)
    result = {
        "benchmark": "thermo5_tx_dpd_ila_fit",
        "status": "CANDIDATES_ONLY_REQUIRES_HELDOUT_AND_RTL_CHECK",
        "development_seeds": list(args.seeds),
        "symbols_per_seed": args.symbols,
        "rms_drive": args.rms_drive,
        "pa_profile": args.profile,
        "candidate_count": len(candidates),
        "candidates": candidates,
        "limits": [
            "The fit is valid only for the named deterministic behavioral DPA profile and operating drive.",
            "Held-out Python communications and bit-true RTL tests are required before candidate acceptance.",
            "This file does not alter the product one-tap identity configuration.",
        ],
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    for candidate in candidates:
        print("%s taps=%d fit_samples=%d coeff_clip=%d pivot_ratio=%.3g" % (
            candidate["name"], candidate["active_taps"],
            candidate["fit"]["fit_samples"],
            candidate["fit"]["coefficient_clip_count"],
            candidate["fit"]["solver"]["pivot_ratio"]))
    print("wrote %s" % args.json)


if __name__ == "__main__":
    main()
