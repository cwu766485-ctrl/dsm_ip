#!/usr/bin/env python3
"""Generate deterministic direct-input vectors for the experimental BP-EF4."""

import argparse
import csv
import random
from pathlib import Path

from dsm_refmodel import BpEf4


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=2048)
    parser.add_argument("--seed", type=int, default=20260915)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.samples <= 0:
        raise ValueError("samples must be positive")
    rng = random.Random(args.seed)
    model = BpEf4()
    rows = []
    for index in range(args.samples):
        sample = rng.randrange(-(1 << 14), 1 << 14)
        if index % 257 == 0:
            sample = -32768
        elif index % 263 == 0:
            sample = 32767
        result = model.step(sample)
        rows.append((index, sample, result.core_bit, result.signed_output,
                     result.quantizer_input))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.writer(handle)
        writer.writerow(["sample", "x_q15", "core_bit", "signed_output", "quantizer_input"])
        writer.writerows(rows)
    print(f"Generated {len(rows)} samples: {args.output}")


if __name__ == "__main__":
    main()
