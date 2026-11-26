#!/usr/bin/env python3
"""Build bounded one-packet vectors and per-lane DPD counts for a V1.4 soak."""
from argparse import ArgumentParser
from pathlib import Path

from dsm_refmodel.thermo5 import (
    _centered_cubic_midpoint,
    _centered_cubic_x2_with_future,
    apply_memory_polynomial,
    apply_q14_gain,
    one_tap_complex_coefficients,
    run_centered_cubic_ef2_inputs,
    run_centered_cubic_frontend,
    write_vectors,
)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--sku", choices=("ef1", "mash11"), required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--saturation", action="store_true")
    args = parser.parse_args()
    gain = 32767 if args.saturation else 16384
    coeffs = one_tap_complex_coefficients(
        *((32767,) * 6 if args.saturation else (16384, 0, 0, 0, 0, 0))
    )
    # A constant complex rail maximizes qualifying increments in the
    # slowest lane. Identity/zero input minimizes unrelated data switching.
    level = 32767 if args.saturation else 0
    i = [(level,) * 8] * 56
    q = i
    starts = [1] + [0] * 55
    gains = [gain] * 56
    mode = "tidsm" if args.sku == "ef1" else "mash11"
    order, step = (1, 7168) if args.sku == "ef1" else (2, 5120)

    expected = run_centered_cubic_frontend(
        i, q, starts, gains, step=step, dpd_coefficients=coeffs,
        dpd_active_taps=1, tidsm_order=order, dsm_mode=mode
    )
    backend = run_centered_cubic_ef2_inputs(
        i, q, starts, gains, dpd_coefficients=coeffs, dpd_active_taps=1
    )
    if run_centered_cubic_ef2_inputs(
        i * 2, q * 2, starts * 2, gains * 2, dpd_coefficients=coeffs, dpd_active_taps=1
    ) != backend * 2:
        raise ValueError("Repeated source packets do not have periodic backend input")
    gained = zip(*apply_q14_gain([x for word in i for x in word],
                                 [x for word in q for x in word], gain))
    samples = list(gained)
    stage1 = _centered_cubic_x2_with_future(samples)
    tail = [(0, 0)] * 16
    tail[1] = _centered_cubic_midpoint(samples[-1], (0, 0), (0, 0), (0, 0))
    dpd = stage1 + tail
    counts = [apply_memory_polynomial(dpd[lane::16], coeffs, active_taps=1)[2]
              for lane in range(16)]
    if any((count > 0) != args.saturation for count in counts):
        raise ValueError("Each lane must match the requested saturation profile")
    args.out.mkdir(parents=True)
    write_vectors(args.out, i, q, starts, gains, expected)
    for component, name in enumerate(("i", "q")):
        (args.out / f"backend_{name}.mem").write_text(
            "".join("".join(f"{value & 0xffff:04x}" for value in reversed(word[component]))
                    + "\n" for word in backend), encoding="ascii"
        )
    (args.out / "pa_prefix.mem").write_text(
        "".join("".join(f"{plane:016x}" for plane in reversed(word)) + "\n"
                for word in expected[:-1]), encoding="ascii"
    )
    (args.out / "dpd_saturation_per_frame.mem").write_text(
        "".join(f"{count:08x}\n" for count in counts), encoding="ascii"
    )
    print(f"DPD saturation counts per packet: {counts}", flush=True)


if __name__ == "__main__":
    main()
