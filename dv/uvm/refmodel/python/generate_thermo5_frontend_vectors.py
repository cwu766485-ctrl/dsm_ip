#!/usr/bin/env python3
"""Generate the frozen thermo5 UVM vectors without MATLAB."""

import argparse
from pathlib import Path

from dsm_refmodel.thermo5 import (
    generate_source_vectors,
    nonlinear_test_dpd_coefficients,
    nonlinear_test_dpd_coefficients_4tap,
    one_tap_complex_coefficients,
    read_source_vectors,
    run_centered_cubic_frontend,
    run_frozen_frontend,
    write_vectors,
)


def _csv_ints(value):
    if not value:
        return ()
    return tuple(int(item.strip(), 0) for item in value.split(",") if item.strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--input-dir", type=Path,
                        help="reuse I/Q and metadata .mem files from a MATLAB/Python run")
    parser.add_argument("--words", type=int, default=56)
    parser.add_argument("--seed", type=int, default=20260930)
    parser.add_argument("--profile", choices=("random", "extreme", "range_stress", "ef2_saturation"),
                        default="random")
    parser.add_argument("--interp-taps", type=int, choices=(2, 3, 4), default=2)
    parser.add_argument("--interp-mode", choices=("causal", "centered_cubic"),
                        default="centered_cubic")
    parser.add_argument("--dpd-profile", choices=("identity", "nonlinear_test",
                                                    "nonlinear_test_4tap",
                                                    "custom_1tap"),
                        default="identity")
    parser.add_argument("--dpd-c1-re-q14", type=lambda value: int(value, 0))
    parser.add_argument("--dpd-c1-im-q14", type=lambda value: int(value, 0),
                        default=0)
    parser.add_argument("--dpd-c3-re-q14", type=lambda value: int(value, 0),
                        default=0)
    parser.add_argument("--dpd-c3-im-q14", type=lambda value: int(value, 0),
                        default=0)
    parser.add_argument("--dpd-c5-re-q14", type=lambda value: int(value, 0),
                        default=0)
    parser.add_argument("--dpd-c5-im-q14", type=lambda value: int(value, 0),
                        default=0)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--tidsm-order", type=int, choices=(1, 2), default=2,
                        help="use the main-chain EF2 TIDSM (default) or first-order fallback")
    parser.add_argument("--frame-start-words", default="1,15,36")
    parser.add_argument("--frame-gains", default="16384,14336,12288")
    args = parser.parse_args()

    if args.input_dir:
        i_words, q_words, starts, gains = read_source_vectors(args.input_dir)
    else:
        i_words, q_words, starts, gains = generate_source_vectors(
            words=args.words,
            seed=args.seed,
            profile=args.profile,
            frame_start_words=_csv_ints(args.frame_start_words),
            frame_gains=_csv_ints(args.frame_gains),
        )
    if args.interp_mode == "centered_cubic":
        if args.dpd_profile == "nonlinear_test":
            coefficients, active_taps = nonlinear_test_dpd_coefficients(), 2
        elif args.dpd_profile == "nonlinear_test_4tap":
            coefficients, active_taps = nonlinear_test_dpd_coefficients_4tap(), 4
        elif args.dpd_profile == "custom_1tap":
            if args.dpd_c1_re_q14 is None:
                parser.error("--dpd-profile custom_1tap requires --dpd-c1-re-q14")
            custom_coefficients = (
                ("C1 real", args.dpd_c1_re_q14),
                ("C1 imaginary", args.dpd_c1_im_q14),
                ("C3 real", args.dpd_c3_re_q14),
                ("C3 imaginary", args.dpd_c3_im_q14),
                ("C5 real", args.dpd_c5_re_q14),
                ("C5 imaginary", args.dpd_c5_im_q14),
            )
            for name, value in custom_coefficients:
                if not -(1 << 15) <= value < (1 << 15):
                    parser.error("custom one-tap %s coefficient must fit signed Q2.14 storage" % name)
            coefficients = one_tap_complex_coefficients(
                args.dpd_c1_re_q14, args.dpd_c1_im_q14,
                args.dpd_c3_re_q14, args.dpd_c3_im_q14,
                args.dpd_c5_re_q14, args.dpd_c5_im_q14)
            active_taps = 1
        else:
            coefficients, active_taps = None, None
        pa_words = run_centered_cubic_frontend(
            i_words, q_words, starts, gains, step=args.step,
            dpd_coefficients=coefficients,
            dpd_active_taps=active_taps,
            tidsm_order=args.tidsm_order)
    else:
        if args.dpd_profile != "identity":
            parser.error("--dpd-profile nonlinear_test currently requires --interp-mode centered_cubic")
        pa_words = run_frozen_frontend(
            i_words, q_words, starts, gains,
            interp_taps=args.interp_taps,
            step=args.step,
            tidsm_order=args.tidsm_order,
        )
    write_vectors(args.output_dir, i_words, q_words, starts, gains, pa_words)
    print("THERMO5_PYTHON_VECTORS=PASS")
    print("source_words=%d output_words_per_plane=%d" % (len(i_words), len(pa_words)))
    print("interp_mode=%s interp_taps=%d dpd_profile=%s dpd_c1_re_q14=%s dpd_c1_im_q14=%s dpd_c3_re_q14=%s dpd_c3_im_q14=%s dpd_c5_re_q14=%s dpd_c5_im_q14=%s tidsm_order=%d step=%d profile=%s" % (
        args.interp_mode, args.interp_taps, args.dpd_profile,
        args.dpd_c1_re_q14, args.dpd_c1_im_q14,
        args.dpd_c3_re_q14, args.dpd_c3_im_q14,
        args.dpd_c5_re_q14, args.dpd_c5_im_q14,
        args.tidsm_order, args.step,
        "input_mem" if args.input_dir else args.profile))
    print("output_dir=%s" % args.output_dir.resolve())


if __name__ == "__main__":
    main()
