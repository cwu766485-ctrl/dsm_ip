#!/usr/bin/env python3
"""Measure the initial real-IF BP EFDSM route on the checked P0 vectors.

The audit models the new digital boundary:
full-precision Fs/4 I/Q mixer -> one-bit BP EFDSM -> IF BPF -> DDC.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import numpy as np

# Permit both direct execution and reuse by the BPDSM comparison audit.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from measure_p0_lp2_fs4_frontend import (
    CHANNEL_BW_HZ,
    FS_HZ,
    IF_HZ,
    LOWPASS_CUTOFF_HZ,
    fixed_fs4_merge,
    lowpass_fir,
    ofdm_metrics,
    read_mem_i16,
)


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--i-mem", type=Path, default=repo / "verif/vectors/p0/rom_i.mem")
    parser.add_argument("--q-mem", type=Path, default=repo / "verif/vectors/p0/rom_q.mem")
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=repo / "docs/evidence/frontend/p0_bp_ef2_frontend_audit_20260804.csv",
    )
    return parser.parse_args()


def saturate_signed(value: int, width: int) -> int:
    return max(min(value, 2 ** (width - 1) - 1), -2 ** (width - 1))


def bp_ef2_registered_output_bits(x_q15: np.ndarray) -> np.ndarray:
    """Match dsm_core_bp_ef2 state order through its EF2 implementation."""

    e1 = 0
    e2 = 0
    y_reg = 1
    result = np.empty(x_q15.size, dtype=np.float64)
    for index, sample in enumerate(x_q15):
        result[index] = y_reg
        # B1 = 0 and B2 = -1: v[n] = x[n] - e[n-2].
        v_now = saturate_signed(int(sample) - e2, 28)
        q_now = 32767 if v_now >= 0 else -32767
        e0 = v_now - q_now
        e2 = e1
        e1 = e0
        y_reg = 1 if v_now >= 0 else 0
    return 2.0 * result - 1.0


def ideal_if_bandpass(x: np.ndarray, bandwidth_hz: float) -> np.ndarray:
    frequency = np.fft.fftfreq(x.size, d=1.0 / FS_HZ)
    keep = (np.abs(frequency - IF_HZ) <= bandwidth_hz / 2.0) | (
        np.abs(frequency + IF_HZ) <= bandwidth_hz / 2.0
    )
    return np.real(np.fft.ifft(np.fft.fft(x) * keep))


def main() -> None:
    args = parse_args()
    i_q15 = read_mem_i16(args.i_mem)
    q_q15 = read_mem_i16(args.q_mem)
    if i_q15.size != q_q15.size:
        raise ValueError("I and Q ROM files have different lengths.")

    reference = lowpass_fir(i_q15 / 32767.0 + 1j * q_q15 / 32767.0, LOWPASS_CUTOFF_HZ)
    if_q15 = fixed_fs4_merge(i_q15, q_q15).astype(np.int64)
    rf_bits = bp_ef2_registered_output_bits(if_q15)
    bpf_bandwidth_hz = 1.2 * CHANNEL_BW_HZ
    rf_bpf = ideal_if_bandpass(rf_bits, bpf_bandwidth_hz)
    n = np.arange(rf_bpf.size, dtype=np.float64)
    recovered = lowpass_fir(
        2.0 * rf_bpf * np.exp(1j * 2.0 * np.pi * IF_HZ / FS_HZ * n),
        LOWPASS_CUTOFF_HZ,
    )
    metrics = ofdm_metrics(recovered, reference)
    row = {
        "Aperture": "full_precision_fs4_to_bp_ef2_rf",
        "EVM_percent": f"{metrics['EVM_percent']:.6f}",
        "SNDR_dB": f"{metrics['SNDR_dB']:.6f}",
        "Correlation": f"{metrics['Correlation']:.6f}",
        "DecimationPhase": metrics["DecimationPhase"],
        "BasebandLag": metrics["BasebandLag"],
        "EqualizedSymbols": metrics["EqualizedSymbols"],
        "InputSamples": i_q15.size,
        "Fs_Hz": f"{FS_HZ:.0f}",
        "IF_Hz": f"{IF_HZ:.0f}",
        "BPF_Bandwidth_Hz": f"{bpf_bandwidth_hz:.3f}",
        "Model": "full-precision Fs/4 mixer plus dsm_core_bp_ef2 state order",
        "Measurement": "ideal IF BPF, coherent DDC, CP-removed 64-point OFDM FFT, per-subcarrier equalizer",
        "EvidenceBoundary": "Python algorithm audit; not fresh RTL, ADS, board, or measured RF",
    }
    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(row))
        writer.writeheader()
        writer.writerow(row)
    print(
        f"BP EF2: EVM={row['EVM_percent']}%, SNDR={row['SNDR_dB']} dB, "
        f"corr={row['Correlation']}, BPF={bpf_bandwidth_hz / 1e6:.6f} MHz"
    )
    print(f"Saved: {args.out_csv}")


if __name__ == "__main__":
    main()
