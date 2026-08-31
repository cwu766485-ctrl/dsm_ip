#!/usr/bin/env python3
"""Compare defined Fs/4 bandpass DSM candidates on the checked P0 vector.

Every entry uses the same aperture:

    Q1.15 I/Q -> full-precision Fs/4 IF -> DSM -> 1.2x-channel IF BPF
            -> coherent DDC -> CP-removed OFDM FFT -> equalized EVM/SNDR

Native MASH output is retained as multilevel data. It is intentionally not
hard-limited: a binary limiter changes the MASH output contract and is not a
valid native-MASH comparison. Candidate rows without a checked BP algorithm
are emitted as NOT_IMPLEMENTED rather than being substituted with LP models.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np

from measure_p0_bp_ef2_frontend import (
    bp_ef2_registered_output_bits,
    ideal_if_bandpass,
)
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
        default=repo / "docs/evidence/frontend/p0_bp_dsm_comparison_20260805.csv",
    )
    return parser.parse_args()


def saturate_signed(value: int, width: int = 28) -> int:
    return max(min(value, 2 ** (width - 1) - 1), -2 ** (width - 1))


def bp_single_registered_output_bits(x_q15: np.ndarray) -> np.ndarray:
    """Match the registered resonator loop in ``dsm_core_bp_single``."""

    s1 = 0
    s2 = 0
    y_reg = 1
    result = np.empty(x_q15.size, dtype=np.float64)
    for index, sample in enumerate(x_q15):
        result[index] = y_reg
        q_now = 32767 if y_reg else -32767
        s1_next = saturate_signed(int(sample) - q_now - s2)
        s2_next = s1
        y_reg = 1 if -s2_next >= 0 else 0
        s1 = s1_next
        s2 = s2_next
    return 2.0 * result - 1.0


def bp_mash11_multilevel(x_q15: np.ndarray, interstage_scale: int = 16) -> np.ndarray:
    """Initial BP MASH 1-1 multilevel exploration, not a one-bit DPA output.

    Each section uses NTF ``1 + z^-2``.  The MASH combiner is kept multilevel;
    the interstage scale is explicit because the second section otherwise sees
    a full-scale first-section error. This is an exploration benchmark rather
    than a released BP MASH topology.
    """

    e1 = [0, 0]
    e2 = [0, 0]
    y1_reg = 1
    y2_reg = 1
    y2_delay1 = 1
    y2_delay2 = 1
    result = np.empty(x_q15.size, dtype=np.float64)
    for index, sample in enumerate(x_q15):
        y1_pm = 1 if y1_reg else -1
        y2_pm = 1 if y2_reg else -1
        y2_pm_d2 = 1 if y2_delay2 else -1
        # The 1 + z^-2 combiner preserves the BP notch but needs 2-bit output.
        result[index] = y1_pm - (y2_pm + y2_pm_d2)

        v1 = saturate_signed(int(sample) - e1[1])
        q1 = 32767 if v1 >= 0 else -32767
        e1_next = v1 - q1
        y1_next = 1 if v1 >= 0 else 0

        v2 = saturate_signed((e1[0] // interstage_scale) - e2[1])
        q2 = 32767 if v2 >= 0 else -32767
        e2_next = v2 - q2
        y2_next = 1 if v2 >= 0 else 0

        e1 = [e1_next, e1[0]]
        e2 = [e2_next, e2[0]]
        y2_delay2 = y2_delay1
        y2_delay1 = y2_reg
        y1_reg = y1_next
        y2_reg = y2_next
    return result


def measure_candidate(
    name: str,
    output: np.ndarray,
    reference: np.ndarray,
    output_contract: str,
    dpa_compatible: str,
    notes: str,
) -> dict[str, object]:
    bpf_bandwidth_hz = 1.2 * CHANNEL_BW_HZ
    rf_bpf = ideal_if_bandpass(output, bpf_bandwidth_hz)
    n = np.arange(output.size, dtype=np.float64)
    recovered = lowpass_fir(
        2.0 * rf_bpf * np.exp(1j * 2.0 * np.pi * IF_HZ / FS_HZ * n),
        LOWPASS_CUTOFF_HZ,
    )
    metrics = ofdm_metrics(recovered, reference)
    return {
        "Status": "MEASURED",
        "Candidate": name,
        "OutputContract": output_contract,
        "Current1bitDPACompatible": dpa_compatible,
        "EVM_percent": f"{metrics['EVM_percent']:.6f}",
        "SNDR_dB": f"{metrics['SNDR_dB']:.6f}",
        "Correlation": f"{metrics['Correlation']:.6f}",
        "DecimationPhase": metrics["DecimationPhase"],
        "BasebandLag": metrics["BasebandLag"],
        "EqualizedSymbols": metrics["EqualizedSymbols"],
        "OutputLevels": "/".join(str(int(v)) for v in np.unique(output)),
        "Fs_Hz": f"{FS_HZ:.0f}",
        "IF_Hz": f"{IF_HZ:.0f}",
        "BPF_Bandwidth_Hz": f"{bpf_bandwidth_hz:.3f}",
        "Notes": notes,
        "EvidenceBoundary": "Python algorithm audit; not fresh RTL, ADS, board, DPA, or measured RF",
    }


def unavailable_candidate(name: str, output_contract: str, notes: str) -> dict[str, object]:
    """Keep the matrix explicit when a BP candidate has not been implemented."""

    return {
        "Status": "NOT_IMPLEMENTED",
        "Candidate": name,
        "OutputContract": output_contract,
        "Current1bitDPACompatible": "not assessed",
        "EVM_percent": "",
        "SNDR_dB": "",
        "Correlation": "",
        "DecimationPhase": "",
        "BasebandLag": "",
        "EqualizedSymbols": "",
        "OutputLevels": "",
        "Fs_Hz": f"{FS_HZ:.0f}",
        "IF_Hz": f"{IF_HZ:.0f}",
        "BPF_Bandwidth_Hz": f"{1.2 * CHANNEL_BW_HZ:.3f}",
        "Notes": notes,
        "EvidenceBoundary": "No checked BP state equations, MATLAB reference, or RTL implementation",
    }


def main() -> None:
    args = parse_args()
    i_q15 = read_mem_i16(args.i_mem)
    q_q15 = read_mem_i16(args.q_mem)
    if i_q15.size != q_q15.size:
        raise ValueError("I and Q ROM files have different lengths.")

    reference = lowpass_fir(i_q15 / 32767.0 + 1j * q_q15 / 32767.0, LOWPASS_CUTOFF_HZ)
    if_q15 = fixed_fs4_merge(i_q15, q_q15).astype(np.int64)
    single = bp_single_registered_output_bits(if_q15)
    ef2 = bp_ef2_registered_output_bits(if_q15)
    mash_multi = bp_mash11_multilevel(if_q15)
    rows = [
        measure_candidate(
            "BP DSM single-loop resonator",
            single,
            reference,
            "one-bit {-1,+1}",
            "yes",
            "Initial resonator loop, NTF=1+z^-2.",
        ),
        unavailable_candidate(
            "BP DSM2",
            "not defined",
            "LPDSM2 is a low-pass topology and cannot be relabelled as a BP model.",
        ),
        unavailable_candidate(
            "BP EFDSM",
            "not defined",
            "Only the second-order BP error-feedback state equations are checked in.",
        ),
        measure_candidate(
            "BP EFDSM2 error-feedback second-order",
            ef2,
            reference,
            "one-bit {-1,+1}",
            "yes",
            "dsm_core_bp_ef2, NTF=1+z^-2.",
        ),
        measure_candidate(
            "BP MASH11 exploratory native",
            mash_multi,
            reference,
            "multilevel {-3,-1,+1,+3}",
            "no",
            "Exploratory multilevel MASH combiner; not a released BP MASH topology.",
        ),
        unavailable_candidate(
            "BP MASH111 native",
            "not defined",
            "No BP MASH111 noise-transfer function, fixed-point reference, or RTL is checked in.",
        ),
        unavailable_candidate(
            "BP MASH22 native",
            "not defined",
            "No BP MASH22 noise-transfer function, fixed-point reference, or RTL is checked in.",
        ),
    ]

    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    for row in rows:
        print(
            f"{row['Candidate']}: status={row['Status']}, "
            f"EVM={row['EVM_percent']}%, SNDR={row['SNDR_dB']} dB, "
            f"DPA={row['Current1bitDPACompatible']}"
        )
    print(f"Saved: {args.out_csv}")


if __name__ == "__main__":
    main()
