#!/usr/bin/env python3
"""Compare Python integer interpolation/DPD outputs with MATLAB fixed vectors."""

import argparse
import csv
from pathlib import Path

from dsm_refmodel import ComplexCoeff, interp_frontend, memory_poly


def read_iq(path):
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    i_values = [int(row["i_q1_15"]) for row in rows]
    q_values = [int(row["q_q1_15"]) for row in rows]
    saturated = [bool(int(row["saturated"])) for row in rows] if rows and "saturated" in rows[0] else None
    return i_values, q_values, saturated


def mismatch_count(actual_i, actual_q, expected_i, expected_q):
    if len(actual_i) != len(expected_i):
        raise AssertionError(f"sample count {len(actual_i)} expected {len(expected_i)}")
    return sum(ai != ei or aq != eq for ai, aq, ei, eq in zip(actual_i, actual_q, expected_i, expected_q))


def compare_interp(root):
    vector_dir = root / "matlab" / "out" / "interp_frontend" / "bittrue"
    i_values, q_values, _ = read_iq(vector_dir / "interp_input_iq.csv")
    for mode in range(5):
        actual_i = interp_frontend(i_values, mode)
        actual_q = interp_frontend(q_values, mode)
        expected_i, expected_q, _ = read_iq(vector_dir / f"interp_mode{mode}_expected.csv")
        mismatch = mismatch_count(actual_i, actual_q, expected_i, expected_q)
        if mismatch:
            raise AssertionError(f"interp mode {mode}: {mismatch} mismatches")
        print(f"INTERP_MATLAB_PYTHON_PASS mode={mode} samples={len(actual_i)}")


def read_memory_coefficients(path):
    with path.open(newline="", encoding="utf-8") as handle:
        row = next(csv.DictReader(handle))
    taps = int(row["active_taps"])
    groups = []
    for order in (1, 3, 5):
        groups.append([ComplexCoeff(int(row[f"c{order}_re_t{tap}"]), int(row[f"c{order}_im_t{tap}"])) for tap in range(4)])
    return taps, groups[0], groups[1], groups[2]


def compare_dpd(root):
    vector_dir = root / "matlab" / "out" / "dpd" / "bittrue"
    i_values, q_values, _ = read_iq(vector_dir / "dpd_mp_input_iq.csv")
    expected_i, expected_q, expected_sat = read_iq(vector_dir / "dpd_mp_expected_iq.csv")
    taps, c1, c3, c5 = read_memory_coefficients(vector_dir / "dpd_mp_coefficients.csv")
    actual_i, actual_q, actual_sat = memory_poly(i_values, q_values, c1, c3, c5, active_taps=taps)
    mismatch = mismatch_count(actual_i, actual_q, expected_i, expected_q)
    sat_mismatch = sum(a != b for a, b in zip(actual_sat, expected_sat or []))
    if mismatch or sat_mismatch:
        raise AssertionError(f"memory-poly: iq_mismatch={mismatch} saturation_mismatch={sat_mismatch}")
    print(f"DPD_MATLAB_PYTHON_PASS taps={taps} samples={len(actual_i)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--skip-interp", action="store_true")
    parser.add_argument("--skip-dpd", action="store_true")
    args = parser.parse_args()
    if not args.skip_interp:
        compare_interp(args.root)
    if not args.skip_dpd:
        compare_dpd(args.root)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
