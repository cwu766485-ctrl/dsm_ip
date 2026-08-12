#!/usr/bin/env python3
"""Extract a complex baseband feedback trace from a DPA observation.

The ADS switch-core export is a real single-ended waveform.  This utility
performs coherent downconversion at the configured IF, low-pass filters it
with a deterministic moving-average window, and samples it at the DSM rate.
It then aligns the result to the known Fs/4 rf_bit reference and identifies a
forward complex memory-polynomial model.  The model is an identification
artifact; it is not a released DPD coefficient table.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np


def read_csv(path: Path, required: tuple[str, ...]) -> dict[str, np.ndarray]:
    with path.open(newline="", encoding="ascii") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"CSV is empty: {path}")
    missing = [name for name in required if name not in rows[0]]
    if missing:
        raise ValueError(f"{path} is missing columns: {', '.join(missing)}")
    return {name: np.asarray([float(row[name]) for row in rows], dtype=float) for name in required}


def moving_average(values: np.ndarray, width: int) -> np.ndarray:
    if width < 2:
        return values.copy()
    kernel = np.ones(width, dtype=float) / width
    return np.convolve(values, kernel, mode="same")


def sample_feedback(time_s: np.ndarray, vout_v: np.ndarray, if_hz: float,
                    sample_hz: float, lpf_cycles: int) -> tuple[np.ndarray, np.ndarray]:
    dt = float(np.median(np.diff(time_s)))
    native_hz = 1.0 / dt
    width = max(2, int(round(native_hz / if_hz * lpf_cycles)))
    mixed = 2.0 * vout_v * np.exp(-1j * 2.0 * np.pi * if_hz * time_s)
    baseband = moving_average(mixed, width)
    period = 1.0 / sample_hz
    count = int(np.floor((time_s[-1] - time_s[0]) / period))
    centers = time_s[0] + (np.arange(count) + 0.5) * period
    feedback = np.interp(centers, time_s, baseband.real) + 1j * np.interp(
        centers, time_s, baseband.imag
    )
    return centers, feedback


def rf_reference(bits: np.ndarray) -> np.ndarray:
    if not np.all(np.isin(bits, (0.0, 1.0))):
        raise ValueError("rf_bit must contain only 0/1 values")
    signed = 2.0 * bits - 1.0
    phase = np.arange(bits.size) & 3
    return signed * np.exp(-1j * np.pi * phase / 2.0)


def align(reference: np.ndarray, feedback: np.ndarray, max_lag: int) -> tuple[int, complex, np.ndarray, np.ndarray]:
    best: tuple[float, int, complex] | None = None
    for lag in range(-max_lag, max_lag + 1):
        if lag >= 0:
            x = reference[lag:]
            y = feedback[: feedback.size - lag]
        else:
            x = reference[: reference.size + lag]
            y = feedback[-lag:]
        if x.size < 8:
            continue
        gain = np.vdot(x, y) / max(np.vdot(x, x).real, np.finfo(float).eps)
        error = y - gain * x
        score = float(np.vdot(error, error).real / max(np.vdot(y, y).real, np.finfo(float).eps))
        if best is None or score < best[0]:
            best = (score, lag, gain)
    if best is None:
        raise ValueError("Could not align feedback and reference")
    _, lag, gain = best
    if lag >= 0:
        x = reference[lag:]
        y = feedback[: feedback.size - lag]
    else:
        x = reference[: reference.size + lag]
        y = feedback[-lag:]
    return lag, gain, x, y


def fit_memory_polynomial(x: np.ndarray, y: np.ndarray, taps: int, orders: tuple[int, ...]) -> tuple[np.ndarray, float]:
    start = taps - 1
    rows = []
    for n in range(start, x.size):
        rows.append([x[n - tap] * abs(x[n - tap]) ** (order - 1)
                     for tap in range(taps) for order in orders])
    design = np.asarray(rows, dtype=complex)
    target = y[start:]
    coeff, *_ = np.linalg.lstsq(design, target, rcond=None)
    residual = target - design @ coeff
    nmse_db = 10.0 * np.log10(max(np.mean(abs(residual) ** 2), np.finfo(float).tiny) /
                               max(np.mean(abs(target) ** 2), np.finfo(float).tiny))
    return coeff, float(nmse_db)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--observation", type=Path, required=True)
    parser.add_argument("--rf-bits", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--if-hz", type=float, default=25e6)
    parser.add_argument("--sample-hz", type=float, default=100e6)
    parser.add_argument("--lpf-cycles", type=int, default=4)
    parser.add_argument("--max-lag", type=int, default=24)
    parser.add_argument("--taps", type=int, default=4)
    parser.add_argument("--orders", type=int, nargs="+", default=(1, 3, 5))
    parser.add_argument("--classification", default="circuit feedback identification, not released DPD",
                        help="Evidence classification retained in the output summary.")
    args = parser.parse_args()

    obs = read_csv(args.observation, ("time_s", "vout_v"))
    bits = read_csv(args.rf_bits, ("time_s", "rf_bit"))
    if np.any(np.diff(obs["time_s"]) <= 0) or np.any(np.diff(bits["time_s"]) <= 0):
        raise ValueError("time columns must be strictly increasing")
    centers, feedback = sample_feedback(obs["time_s"], obs["vout_v"], args.if_hz,
                                        args.sample_hz, args.lpf_cycles)
    reference = rf_reference(bits["rf_bit"])
    count = min(reference.size, feedback.size)
    lag, gain, x, y = align(reference[:count], feedback[:count], args.max_lag)
    coeff, nmse_db = fit_memory_polynomial(x, y, args.taps, tuple(args.orders))
    inverse_coeff, inverse_nmse_db = fit_memory_polynomial(y, x, args.taps, tuple(args.orders))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    trace_path = args.output_dir / "aligned_complex_feedback.csv"
    with trace_path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(("sample_index", "reference_re", "reference_im", "feedback_re", "feedback_im"))
        writer.writerows((i, a.real, a.imag, b.real, b.imag) for i, (a, b) in enumerate(zip(x, y)))
    coeff_path = args.output_dir / "forward_memory_polynomial_coefficients.csv"
    with coeff_path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(("tap", "order", "real", "imag"))
        for index, value in enumerate(coeff):
            tap, order_index = divmod(index, len(args.orders))
            writer.writerow((tap, args.orders[order_index], value.real, value.imag))
    inverse_path = args.output_dir / "indirect_learning_predistorter_seed.csv"
    with inverse_path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(("tap", "order", "real", "imag"))
        for index, value in enumerate(inverse_coeff):
            tap, order_index = divmod(index, len(args.orders))
            writer.writerow((tap, args.orders[order_index], value.real, value.imag))
    summary = {
        "classification": args.classification,
        "observation": str(args.observation),
        "rf_bits": str(args.rf_bits),
        "input_samples": int(bits["rf_bit"].size),
        "aligned_samples": int(x.size),
        "native_observation_sample_hz": float(1.0 / np.median(np.diff(obs["time_s"]))),
        "if_hz": args.if_hz,
        "feedback_sample_hz": args.sample_hz,
        "lowpass_width_samples": int(round((1.0 / np.median(np.diff(obs["time_s"]))) / args.if_hz * args.lpf_cycles)),
        "alignment_lag_samples": lag,
        "alignment_gain_real": float(gain.real),
        "alignment_gain_imag": float(gain.imag),
        "forward_model_taps": args.taps,
        "forward_model_orders": list(args.orders),
        "forward_model_nmse_db": nmse_db,
        "indirect_learning_inverse_nmse_db": inverse_nmse_db,
        "feedback_rms": float(np.sqrt(np.mean(abs(y) ** 2))),
        "trace_csv": str(trace_path),
        "coefficients_csv": str(coeff_path),
        "inverse_seed_csv": str(inverse_path),
        "next_step": "Use this aligned feedback to identify an indirect-learning predistorter; do not write these forward coefficients to RTL.",
    }
    (args.output_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="ascii")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
