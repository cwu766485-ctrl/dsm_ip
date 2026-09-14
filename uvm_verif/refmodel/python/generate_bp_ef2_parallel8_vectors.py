#!/usr/bin/env python3
"""Generate eight consecutive scalar BP-EF2 samples per packed vector."""

import argparse
import csv
import random
from pathlib import Path

from dsm_refmodel.bp_ef2 import BpEf2


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vectors", type=int, default=32)
    parser.add_argument("--seed", type=int, default=20260904)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.vectors <= 0:
        raise ValueError("vectors must be positive")

    rng = random.Random(args.seed)
    model = BpEf2()
    rows = []
    for _ in range(args.vectors * 8):
        sample = rng.randrange(-(1 << 15), 1 << 15)
        step = model.step(sample)
        rows.append((sample, step.core_bit, step.signed_output, step.quantizer_input))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(("x_q15", "expected_bit", "expected_signed", "expected_state"))
        writer.writerows(rows)
    print(f"Generated {len(rows)} scalar samples for {args.vectors} parallel vectors: {args.output}")


if __name__ == "__main__":
    main()
