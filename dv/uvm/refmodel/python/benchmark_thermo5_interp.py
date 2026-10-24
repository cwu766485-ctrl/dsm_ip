#!/usr/bin/env python3
"""Compare thermo5 x2 interpolation presets on deterministic 64-QAM OFDM.

This is a digital interpolation screen, not a complete TID/PA/RF ACLR test.
It deliberately uses only the Python standard library.
"""

import argparse
import cmath
import json
import math
import random
from pathlib import Path

from dsm_refmodel.thermo5 import (
    INTERP_COEFFS_Q14,
    round_shift_symmetric,
    saturate_signed,
)


FFT_SIZE = 256
OVERSAMPLE = 4
ACTIVE_CARRIERS = 100
ACTIVE_EDGE_BIN = 50
ADJACENT_LOW_BIN = 64
ADJACENT_HIGH_BIN = 115
IMAGE_CENTER_BIN = FFT_SIZE
IMAGE_HALF_WIDTH = 52


def fft(values, inverse=False):
    """In-place radix-2 Cooley-Tukey transform returned as a new list."""
    count = len(values)
    if count == 0 or count & (count - 1):
        raise ValueError("FFT size must be a nonzero power of two")
    out = list(values)
    j = 0
    for i in range(1, count):
        bit = count >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            out[i], out[j] = out[j], out[i]
    length = 2
    sign = 1.0 if inverse else -1.0
    while length <= count:
        angle = sign * 2.0 * math.pi / length
        step = cmath.exp(1j * angle)
        half = length >> 1
        for base in range(0, count, length):
            twiddle = 1.0 + 0.0j
            for offset in range(half):
                even = out[base + offset]
                odd = out[base + offset + half] * twiddle
                out[base + offset] = even + odd
                out[base + offset + half] = even - odd
                twiddle *= step
        length <<= 1
    if inverse:
        out = [value / count for value in out]
    return out


def make_ofdm_symbol(rng):
    spectrum = [0.0j] * FFT_SIZE
    for carrier in list(range(1, ACTIVE_EDGE_BIN + 1)) + list(
            range(FFT_SIZE - ACTIVE_EDGE_BIN, FFT_SIZE)):
        real = rng.choice((-7, -5, -3, -1, 1, 3, 5, 7))
        imag = rng.choice((-7, -5, -3, -1, 1, 3, 5, 7))
        spectrum[carrier] = complex(real, imag) / math.sqrt(42.0)
    time_samples = fft(spectrum, inverse=True)
    peak = max(abs(value) for value in time_samples)
    scale = 0.70 / peak if peak else 1.0
    q15 = []
    for value in time_samples:
        q15.append((saturate_signed(int(round(value.real * scale * 32767.0)), 16),
                    saturate_signed(int(round(value.imag * scale * 32767.0)), 16)))
    return q15


def x2_rtl(samples, taps):
    if taps not in INTERP_COEFFS_Q14:
        raise ValueError("unsupported tap count")
    coeffs = INTERP_COEFFS_Q14[taps]
    history = list(reversed(samples[-(taps - 1):]))
    output = []
    for index, (real, imag) in enumerate(samples):
        acc_real = 0
        acc_imag = 0
        terms = [(real, imag)] + history
        for term, coeff in zip(terms, coeffs):
            acc_real += term[0] * coeff
            acc_imag += term[1] * coeff
        output.append((real, imag))
        output.append((saturate_signed(round_shift_symmetric(acc_real, 14), 16),
                       saturate_signed(round_shift_symmetric(acc_imag, 14), 16)))
        history = [samples[(index - delay) % len(samples)]
                   for delay in range(1, taps)]
    return output


def x2_forward_linear(samples):
    output = []
    for index, current in enumerate(samples):
        following = samples[(index + 1) % len(samples)]
        output.append(current)
        output.append(tuple(saturate_signed(round_shift_symmetric(
            current[axis] * 8192 + following[axis] * 8192, 14), 16)
                            for axis in (0, 1)))
    return output


def x2_centered_cubic(samples):
    coeffs = (-1024, 9216, 9216, -1024)  # [-1, 9, 9, -1] / 16, Q14
    output = []
    count = len(samples)
    for index, current in enumerate(samples):
        neighborhood = [samples[(index + offset) % count]
                        for offset in (-1, 0, 1, 2)]
        accum = []
        for axis in (0, 1):
            value = sum(sample[axis] * coeff
                        for sample, coeff in zip(neighborhood, coeffs))
            accum.append(saturate_signed(round_shift_symmetric(value, 14), 16))
        output.append(current)
        output.append((accum[0], accum[1]))
    return output


def cascade(samples, method):
    if method.startswith("rtl"):
        taps = int(method[-1])
        return x2_rtl(x2_rtl(samples, taps), taps)
    if method == "forward_linear":
        return x2_forward_linear(x2_forward_linear(samples))
    if method == "centered_cubic":
        return x2_centered_cubic(x2_centered_cubic(samples))
    raise ValueError("unknown interpolation method: " + method)


def ideal_4x(samples):
    original = [complex(real, imag) / 32768.0 for real, imag in samples]
    source_spectrum = fft(original)
    high_spectrum = [0.0j] * (FFT_SIZE * OVERSAMPLE)
    for index, value in enumerate(source_spectrum):
        frequency = index if index <= FFT_SIZE // 2 else index - FFT_SIZE
        high_spectrum[frequency % len(high_spectrum)] = value
    # The larger IFFT has four times the normalization denominator.
    return [OVERSAMPLE * value for value in fft(high_spectrum, inverse=True)]


def _power_at_bins(spectrum, indexes):
    return sum(abs(spectrum[index % len(spectrum)]) ** 2 for index in indexes)


def metrics(output, reference):
    output_float = [complex(real, imag) / 32768.0 for real, imag in output]
    error_energy = sum(abs(a - b) ** 2 for a, b in zip(output_float, reference))
    reference_energy = sum(abs(value) ** 2 for value in reference)
    output_energy = sum(abs(value) ** 2 for value in output_float)
    # Least-squares scalar equalization: choose g so g * output ~= reference.
    cross_energy = sum(expected * value.conjugate()
                       for value, expected in zip(output_float, reference))
    fitted_gain = cross_energy / max(output_energy, 1e-30)
    fitted_error_energy = sum(abs(fitted_gain * value - expected) ** 2
                              for value, expected in zip(output_float, reference))
    spectrum = fft(output_float)
    size = len(spectrum)
    main_bins = []
    adjacent_bins = []
    image_bins = []
    for index in range(size):
        signed = index if index <= size // 2 else index - size
        # A length-4N transform at 4Fs has the same integer bin numbers for
        # frequencies expressed in units of the original Fs.
        absolute_bin = abs(signed)
        if absolute_bin <= ACTIVE_EDGE_BIN + 2:
            main_bins.append(index)
        if ADJACENT_LOW_BIN <= absolute_bin <= ADJACENT_HIGH_BIN:
            adjacent_bins.append(index)
        if abs(absolute_bin - IMAGE_CENTER_BIN) <= IMAGE_HALF_WIDTH:
            image_bins.append(index)
    main_power = _power_at_bins(spectrum, main_bins)
    adjacent_power = _power_at_bins(spectrum, adjacent_bins)
    image_power = _power_at_bins(spectrum, image_bins)
    evm_percent = 100.0 * math.sqrt(error_energy / max(reference_energy, 1e-30))
    adjacent_dbc = 10.0 * math.log10(max(adjacent_power, 1e-30) / max(main_power, 1e-30))
    image_dbc = 10.0 * math.log10(max(image_power, 1e-30) / max(main_power, 1e-30))
    return {
        "error_energy": error_energy,
        "fitted_error_energy": fitted_error_energy,
        "reference_energy": reference_energy,
        "main_power": main_power,
        "adjacent_power": adjacent_power,
        "image_power": image_power,
        "evm_percent": evm_percent,
        "adjacent_proxy_dbc": adjacent_dbc,
        "first_image_rejection_dbc": -image_dbc,
    }


def run(symbols, seed):
    methods = ("rtl2", "rtl3", "rtl4", "forward_linear", "centered_cubic")
    rng = random.Random(seed)
    totals = {method: {key: 0.0 for key in (
        "error_energy", "fitted_error_energy", "reference_energy", "main_power",
        "adjacent_power", "image_power")}
              for method in methods}
    for _ in range(symbols):
        source = make_ofdm_symbol(rng)
        reference = ideal_4x(source)
        for method in methods:
            result = metrics(cascade(source, method), reference)
            for key in totals[method]:
                totals[method][key] += result[key]
    rows = []
    for method in methods:
        total = totals[method]
        evm = 100.0 * math.sqrt(total["error_energy"] / total["reference_energy"])
        fitted_evm = 100.0 * math.sqrt(
            total["fitted_error_energy"] / total["reference_energy"])
        adjacent = 10.0 * math.log10(max(total["adjacent_power"], 1e-30) /
                                     max(total["main_power"], 1e-30))
        image = -10.0 * math.log10(max(total["image_power"], 1e-30) /
                                   max(total["main_power"], 1e-30))
        taps = int(method[-1]) if method.startswith("rtl") else (2 if method == "forward_linear" else 4)
        rows.append({
            "method": method,
            "rms_evm_percent": evm,
            "per_symbol_gain_phase_corrected_evm_percent": fitted_evm,
            "adjacent_leakage_proxy_dbc": adjacent,
            "first_image_rejection_dbc": image,
            "estimated_real_multiplies_per_source_complex_sample": 2 * taps * 2,
        })
    return {
        "benchmark": "thermo5_64qam_ofdm_interpolation_screen",
        "seed": seed,
        "symbols": symbols,
        "fft_size": FFT_SIZE,
        "active_subcarriers": ACTIVE_CARRIERS,
        "cascade_stages": 2,
        "metrics_scope": "digital interpolation only; no DPD, TID, PA, RF filter, or standard ACLR mask",
        "results": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols", type=int, default=64)
    parser.add_argument("--seed", type=int, default=20261022)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    if args.symbols < 1:
        parser.error("--symbols must be positive")
    result = run(args.symbols, args.seed)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")


if __name__ == "__main__":
    main()
