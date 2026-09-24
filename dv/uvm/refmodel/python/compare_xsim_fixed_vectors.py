#!/usr/bin/env python3
"""Compare Python fixed-point interpolation references with XSim RTL dumps."""

import argparse
from pathlib import Path

from compare_matlab_fixed_vectors import mismatch_count, read_iq
from dsm_refmodel import ComplexCoeff, interp_frontend, memory_poly
from compare_matlab_fixed_vectors import read_memory_coefficients


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[3])
    args = parser.parse_args()
    vector_dir = args.root / "matlab" / "out" / "interp_frontend" / "bittrue"
    xsim_dir = args.root / "verif" / "out_xsim_interp_frontend"
    i_values, q_values, _ = read_iq(vector_dir / "interp_input_iq.csv")
    for mode in range(5):
        expected_i = interp_frontend(i_values, mode)
        expected_q = interp_frontend(q_values, mode)
        actual_i, actual_q, _ = read_iq(xsim_dir / f"interp_mode{mode}_rtl.csv")
        mismatch = mismatch_count(actual_i, actual_q, expected_i, expected_q)
        if mismatch:
            raise AssertionError(f"interp RTL mode {mode}: {mismatch} mismatches")
        print(f"INTERP_PYTHON_RTL_PASS mode={mode} samples={len(actual_i)}")
    dpd_dir = args.root / "matlab" / "out" / "dpd" / "bittrue"
    i_values, q_values, _ = read_iq(dpd_dir / "dpd_mp_input_iq.csv")
    taps, c1, c3, c5 = read_memory_coefficients(dpd_dir / "dpd_mp_coefficients.csv")
    expected_i, expected_q, _ = memory_poly(i_values, q_values, c1, c3, c5, active_taps=taps)
    actual_i, actual_q, _ = read_iq(args.root / "verif" / "out_xsim_dpd" / "dpd_mp_rtl_iq.csv")
    mismatch = mismatch_count(actual_i, actual_q, expected_i, expected_q)
    if mismatch:
        raise AssertionError(f"memory-poly RTL: {mismatch} mismatches")
    print(f"DPD_PYTHON_RTL_PASS taps={taps} samples={len(actual_i)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
