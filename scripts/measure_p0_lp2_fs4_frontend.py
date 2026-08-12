#!/usr/bin/env python3
"""Audit the P0 LPDSM2 native-I/Q and fixed-Fs/4 RF output paths.

This is an independent, NumPy-only measurement script.  It reads the checked
Q1.15 P0 ROM vectors, reproduces the registered-output arithmetic in
``dsm_core_dsm2.sv``, and compares three apertures:

* native complex I/Q DSM output after low-pass reconstruction;
* ``duc_fs4_merge`` RF output after an ideal IF BPF and sparse I/Q recovery;
* the half-rate Fs/4 demultiplexer used by the mature MATLAB reconstruction
  flow, with its phase, Q-sign, Q-shift, and Q half-sample adjustment search.

The report uses OFDM CP removal, FFT, and one complex equalizer per active
subcarrier.  It is a model audit, not a replacement for XSim capture or a
measured RF result.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np


FS_HZ = 100_000_000.0
OSR = 32
NFFT = 64
NCP = 16
ACTIVE_BINS = np.r_[np.arange(-26, 0), np.arange(1, 27)]
USED_FFT_INDICES = np.r_[np.arange(NFFT - 26, NFFT), np.arange(1, 27)]
FS_BB_HZ = FS_HZ / OSR
CHANNEL_BW_HZ = 2.0 * (max(abs(ACTIVE_BINS)) + 1) * FS_BB_HZ / NFFT
LOWPASS_CUTOFF_HZ = CHANNEL_BW_HZ / 2.0
IF_HZ = FS_HZ / 4.0
FILTER_TAPS = 513
EDGE_SYMBOLS = 3


def parse_args() -> argparse.Namespace:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--i-mem",
        type=Path,
        default=repo / "verif" / "vectors" / "p0" / "rom_i.mem",
        help="Q1.15 I input ROM in 16-bit hexadecimal format.",
    )
    parser.add_argument(
        "--q-mem",
        type=Path,
        default=repo / "verif" / "vectors" / "p0" / "rom_q.mem",
        help="Q1.15 Q input ROM in 16-bit hexadecimal format.",
    )
    parser.add_argument(
        "--out-csv",
        type=Path,
        default=repo
        / "docs"
        / "evidence"
        / "frontend"
        / "p0_lp2_fs4_frontend_audit_20260804.csv",
        help="Compact CSV evidence output.",
    )
    return parser.parse_args()


def read_mem_i16(path: Path) -> np.ndarray:
    words = [line.strip() for line in path.read_text(encoding="ascii").splitlines()]
    words = [word for word in words if word]
    values = np.asarray([int(word, 16) for word in words], dtype=np.int64)
    values[values >= 2**15] -= 2**16
    return values


def saturate_signed(value: int, width: int) -> int:
    return max(min(value, 2 ** (width - 1) - 1), -2 ** (width - 1))


def lp2_registered_output_bits(x_q15: np.ndarray) -> np.ndarray:
    """Exact registered-output LPDSM2 state/update order from RTL."""

    v1 = 0
    v2 = 0
    y_reg = 1
    result = np.empty(x_q15.size, dtype=np.float64)
    for index, sample in enumerate(x_q15):
        result[index] = y_reg
        y_next = 1 if v2 >= 0 else 0
        q_feedback = 32767 if v2 >= 0 else -32767
        v1_next = saturate_signed(v1 + int(sample) - q_feedback, 20)
        v2_next = saturate_signed(v2 + v1_next - q_feedback, 20)
        v1 = v1_next
        v2 = v2_next
        y_reg = y_next
    return 2.0 * result - 1.0


def lowpass_fir(
    x: np.ndarray, cutoff_hz: float, sample_rate_hz: float = FS_HZ
) -> np.ndarray:
    """Apply the same zero-phase windowed-sinc reconstruction to both paths."""

    n = np.arange(FILTER_TAPS, dtype=np.float64) - (FILTER_TAPS - 1) / 2.0
    h = (2.0 * cutoff_hz / sample_rate_hz) * np.sinc(
        2.0 * cutoff_hz * n / sample_rate_hz
    )
    h *= np.blackman(FILTER_TAPS)
    h /= np.sum(h)
    half = (FILTER_TAPS - 1) // 2
    filtered = np.convolve(x, h, mode="full")
    return filtered[half:-half]


def fs4_bandpass(x: np.ndarray) -> np.ndarray:
    """Ideal real IF BPF centered at Fs/4 for the declared channel width."""

    frequency = np.fft.fftfreq(x.size, d=1.0 / FS_HZ)
    keep = (np.abs(frequency - IF_HZ) <= LOWPASS_CUTOFF_HZ) | (
        np.abs(frequency + IF_HZ) <= LOWPASS_CUTOFF_HZ
    )
    return np.real(np.fft.ifft(np.fft.fft(x) * keep))


def fixed_fs4_merge(i_bits: np.ndarray, q_bits: np.ndarray) -> np.ndarray:
    """Replicate duc_fs4_merge's [+I, +Q, -I, -Q] sample mapping."""

    phase = np.arange(i_bits.size) % 4
    rf = np.where(
        phase == 0,
        i_bits,
        np.where(phase == 1, q_bits, np.where(phase == 2, -i_bits, -q_bits)),
    )
    return rf


def sparse_fs4_recover(rf_bpf: np.ndarray) -> np.ndarray:
    """Recover complex baseband using the established four sparse branches."""

    phase = np.arange(rf_bpf.size) % 4
    i_sparse = np.zeros(rf_bpf.size, dtype=np.float64)
    q_sparse = np.zeros(rf_bpf.size, dtype=np.float64)
    i_sparse[phase == 0] = rf_bpf[phase == 0]
    i_sparse[phase == 2] = -rf_bpf[phase == 2]
    q_sparse[phase == 1] = rf_bpf[phase == 1]
    q_sparse[phase == 3] = -rf_bpf[phase == 3]
    return 4.0 * (lowpass_fir(i_sparse, LOWPASS_CUTOFF_HZ) + 1j * lowpass_fir(q_sparse, LOWPASS_CUTOFF_HZ))


def half_sample_advance(q_half: np.ndarray) -> np.ndarray:
    """Match MATLAB ``fs4_halfsample_advance`` exactly."""

    if q_half.size <= 1:
        return q_half
    return 0.5 * (q_half + np.r_[q_half[0], q_half[:-1]])


def fs4_halfrate_demux_once(
    rf: np.ndarray, phase_offset: int, q_sign: int, q_shift: int
) -> np.ndarray:
    """Port MATLAB ``rtl_fs4_demux_halfrate_once`` to NumPy."""

    phase = (np.arange(rf.size) - phase_offset) % 4
    i0 = rf[phase == 0]
    i2 = -rf[phase == 2]
    q1 = rf[phase == 1]
    q3 = -rf[phase == 3]
    count = min(i0.size, i2.size, q1.size, q3.size)
    if count == 0:
        return np.zeros(0, dtype=np.complex128)

    i_half = np.empty(2 * count, dtype=np.float64)
    q_half = np.empty(2 * count, dtype=np.float64)
    i_half[0::2] = i0[:count]
    i_half[1::2] = i2[:count]
    q_half[0::2] = q1[:count]
    q_half[1::2] = q3[:count]
    q_half = q_sign * np.roll(q_half, q_shift)
    q_half = half_sample_advance(q_half)
    return i_half + 1j * q_half


def half_rate_fs4_recover(rf: np.ndarray, reference: np.ndarray) -> tuple[np.ndarray, dict[str, float | int]]:
    """Match the MATLAB half-rate phase/sign/shift selection rule."""

    reference_half = reference[0 : 2 * (reference.size // 2) : 2]
    best: tuple[float, np.ndarray, int, int, int] | None = None
    for phase_offset in range(4):
        for q_sign in (1, -1):
            for q_shift in (-1, 0, 1):
                candidate = fs4_halfrate_demux_once(rf, phase_offset, q_sign, q_shift)
                length = min(candidate.size, reference_half.size)
                if length == 0:
                    continue
                candidate = candidate[:length]
                ref_now = reference_half[:length]
                score = abs(np.vdot(candidate, ref_now)) / (
                    np.linalg.norm(candidate) * np.linalg.norm(ref_now)
                    + np.finfo(float).eps
                )
                if best is None or score > best[0]:
                    best = (float(score), candidate, phase_offset, q_sign, q_shift)
    if best is None:
        raise RuntimeError("Unable to recover an Fs/4 half-rate sequence.")
    score, recovered, phase_offset, q_sign, q_shift = best
    return recovered, {
        "RecoveryScore": score,
        "RecoveryPhase": phase_offset,
        "RecoveryQSign": q_sign,
        "RecoveryQShift": q_shift,
    }


def align_integer_samples(y: np.ndarray, x: np.ndarray, max_lag: int = 16) -> tuple[np.ndarray, np.ndarray, int]:
    best: tuple[float, np.ndarray, np.ndarray, int] | None = None
    for lag in range(-max_lag, max_lag + 1):
        y_now = y[max(lag, 0) :]
        x_now = x[max(-lag, 0) :]
        length = min(y_now.size, x_now.size)
        y_now = y_now[:length]
        x_now = x_now[:length]
        gain = np.vdot(y_now, x_now) / (np.vdot(y_now, y_now) + np.finfo(float).eps)
        normalized_error = np.mean(np.abs(gain * y_now - x_now) ** 2) / (
            np.mean(np.abs(x_now) ** 2) + np.finfo(float).eps
        )
        if best is None or normalized_error < best[0]:
            best = (normalized_error, y_now, x_now, lag)
    assert best is not None
    return best[1], best[2], best[3]


def ofdm_metrics(
    y_osr: np.ndarray, x_osr: np.ndarray, osr: int = OSR
) -> dict[str, float | int]:
    """Search decimation phase, then calculate equalized active-subcarrier EVM."""

    best: dict[str, float | int] | None = None
    symbol_length = NFFT + NCP
    for phase in range(osr):
        y, x, lag = align_integer_samples(y_osr[phase::osr], x_osr[phase::osr])
        symbol_count = min(y.size, x.size) // symbol_length
        if symbol_count <= 2 * EDGE_SYMBOLS:
            continue
        y = y[: symbol_count * symbol_length].reshape(symbol_count, symbol_length).T
        x = x[: symbol_count * symbol_length].reshape(symbol_count, symbol_length).T
        y_fft = np.fft.fft(y[NCP:, EDGE_SYMBOLS:-EDGE_SYMBOLS], axis=0)[USED_FFT_INDICES]
        x_fft = np.fft.fft(x[NCP:, EDGE_SYMBOLS:-EDGE_SYMBOLS], axis=0)[USED_FFT_INDICES]
        channel = np.sum(y_fft * np.conj(x_fft), axis=1) / (
            np.sum(np.abs(x_fft) ** 2, axis=1) + np.finfo(float).eps
        )
        error = y_fft / (channel[:, None] + np.finfo(float).eps) - x_fft
        signal_power = np.sum(np.abs(x_fft) ** 2)
        error_power = np.sum(np.abs(error) ** 2)
        evm = 100.0 * np.sqrt(error_power / signal_power)
        result: dict[str, float | int] = {
            "EVM_percent": float(evm),
            "SNDR_dB": float(10.0 * np.log10(signal_power / error_power)),
            "DecimationPhase": phase,
            "BasebandLag": lag,
            "Correlation": float(
                abs(np.vdot(y_fft, x_fft)) / (np.linalg.norm(y_fft) * np.linalg.norm(x_fft))
            ),
            "EqualizedSymbols": symbol_count - 2 * EDGE_SYMBOLS,
        }
        if best is None or result["EVM_percent"] < best["EVM_percent"]:
            best = result
    if best is None:
        raise RuntimeError("The input is too short for CP/FFT measurement.")
    return best


def make_row(
    aperture: str,
    metrics: dict[str, float | int],
    sample_count: int,
    sample_rate_hz: float,
    osr: int,
    recovery: str,
    recovery_meta: dict[str, float | int] | None = None,
) -> dict[str, object]:
    recovery_meta = recovery_meta or {}
    return {
        "Aperture": aperture,
        "EVM_percent": f"{metrics['EVM_percent']:.6f}",
        "SNDR_dB": f"{metrics['SNDR_dB']:.6f}",
        "Correlation": f"{metrics['Correlation']:.6f}",
        "DecimationPhase": metrics["DecimationPhase"],
        "BasebandLag": metrics["BasebandLag"],
        "EqualizedSymbols": metrics["EqualizedSymbols"],
        "InputSamples": sample_count,
        "SampleRate_Hz": f"{sample_rate_hz:.0f}",
        "OSR": osr,
        "Recovery": recovery,
        "RecoveryScore": f"{float(recovery_meta.get('RecoveryScore', np.nan)):.6f}",
        "RecoveryPhase": recovery_meta.get("RecoveryPhase", "n/a"),
        "RecoveryQSign": recovery_meta.get("RecoveryQSign", "n/a"),
        "RecoveryQShift": recovery_meta.get("RecoveryQShift", "n/a"),
        "Measurement": "CP-removed 64-point OFDM FFT; one complex equalizer per active subcarrier",
        "ModelBasis": "Python port of dsm_core_dsm2 registered output; no fresh XSim capture",
    }


def main() -> None:
    args = parse_args()
    i_q15 = read_mem_i16(args.i_mem)
    q_q15 = read_mem_i16(args.q_mem)
    if i_q15.size != q_q15.size:
        raise ValueError("I and Q ROM files have different lengths.")

    reference = i_q15 / 32767.0 + 1j * q_q15 / 32767.0
    reference_bandlimited = lowpass_fir(reference, LOWPASS_CUTOFF_HZ)
    i_bits = lp2_registered_output_bits(i_q15)
    q_bits = lp2_registered_output_bits(q_q15)

    native_iq = lowpass_fir(i_bits, LOWPASS_CUTOFF_HZ) + 1j * lowpass_fir(q_bits, LOWPASS_CUTOFF_HZ)
    rf_bits = fixed_fs4_merge(i_bits, q_bits)
    fixed_fs4 = sparse_fs4_recover(fs4_bandpass(rf_bits))
    half_rate, half_meta = half_rate_fs4_recover(rf_bits, reference)
    half_rate_ref = reference[0 : 2 * (reference.size // 2) : 2]
    half_rate_fs_hz = FS_HZ / 2.0
    half_rate_reconstructed = lowpass_fir(
        half_rate, LOWPASS_CUTOFF_HZ, half_rate_fs_hz
    )
    half_rate_reference = lowpass_fir(
        half_rate_ref, LOWPASS_CUTOFF_HZ, half_rate_fs_hz
    )
    rows = [
        make_row(
            "native_lp2_iq",
            ofdm_metrics(native_iq, reference_bandlimited),
            reference.size,
            FS_HZ,
            OSR,
            "full-rate low-pass reconstruction",
        ),
        make_row(
            "fixed_fs4_sparse_fullrate",
            ofdm_metrics(fixed_fs4, reference_bandlimited),
            reference.size,
            FS_HZ,
            OSR,
            "ideal IF BPF plus sparse full-rate recovery",
        ),
        make_row(
            "fixed_fs4_halfrate_demux",
            ofdm_metrics(half_rate_reconstructed, half_rate_reference, OSR // 2),
            reference.size,
            half_rate_fs_hz,
            OSR // 2,
            "MATLAB-compatible half-rate demux and Q half-sample advance",
            half_meta,
        ),
    ]

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

    print(f"Input: {args.i_mem} / {args.q_mem}")
    print(f"Fs={FS_HZ:.0f} Hz, Fs_bb={FS_BB_HZ:.0f} Hz, channel BW={CHANNEL_BW_HZ:.2f} Hz")
    for row in rows:
        print(
            f"{row['Aperture']}: EVM={row['EVM_percent']}%, SNDR={row['SNDR_dB']} dB, "
            f"corr={row['Correlation']}, decim={row['DecimationPhase']}"
        )
    print(f"Saved: {args.out_csv}")


if __name__ == "__main__":
    main()
