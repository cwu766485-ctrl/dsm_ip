#!/usr/bin/env python3
"""Generate deterministic DPD-bypass plus interpolation subsystem vectors."""

import argparse
import csv
from pathlib import Path

from dsm_refmodel import interp_frontend, wrap_signed


def stimulus(index, is_q):
    """Match the signed corner and deterministic stimulus used by the SV test."""
    corners = (-32768, 32767, 0, -1)
    if index < len(corners):
        return corners[index]
    raw = index * (-1597 if is_q else 2011) + (831 if is_q else -593)
    return wrap_signed(raw, 16)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inputs", type=int, default=97)
    parser.add_argument("--mode", type=int, default=1)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.inputs <= 0:
        raise ValueError("--inputs must be positive")

    i_samples = [stimulus(index, False) for index in range(args.inputs)]
    q_samples = [stimulus(index, True) for index in range(args.inputs)]
    i_expected = interp_frontend(i_samples, args.mode)
    q_expected = interp_frontend(q_samples, args.mode)
    args.output.parent.mkdir(parents=True, exist_ok=True)

    with args.output.open("w", newline="", encoding="utf-8") as handle:
        # Whitespace-delimited vectors avoid simulator-specific CSV scanf behavior.
        writer = csv.writer(handle, delimiter=" ", lineterminator="\n")
        writer.writerow(("kind", "index", "i_q1_15", "q_q1_15"))
        for index, (i_value, q_value) in enumerate(zip(i_samples, q_samples)):
            writer.writerow(("IN", index, i_value, q_value))
        for index, (i_value, q_value) in enumerate(zip(i_expected, q_expected)):
            writer.writerow(("OUT", index, i_value, q_value))
    print(f"TX_FRONTEND_VECTORS inputs={len(i_samples)} outputs={len(i_expected)} mode={args.mode}")


if __name__ == "__main__":
    main()
