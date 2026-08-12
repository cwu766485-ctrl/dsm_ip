#!/usr/bin/env python3
"""Generate deterministic Fs/4 mixer plus BP-EF2 cross-check vectors."""

import argparse
import csv
import random
from pathlib import Path

from dsm_refmodel import TxBpEf2Model, wrap_signed


def parse_args():
    default_output = Path(__file__).resolve().parent / "out" / "bp_ef2_equivalence.csv"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=1024)
    parser.add_argument("--output", type=Path, default=default_output)
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Use a reproducible pseudo-random I/Q stimulus sequence."
    )
    return parser.parse_args()


def sample_pair(index, rng=None):
    if rng is not None:
        i_value = rng.randrange(-(1 << 15), 1 << 15)
        q_value = rng.randrange(-(1 << 15), 1 << 15)
        # Force signed extrema independently of the random distribution.
        if index % 127 == 0:
            i_value = -32768
        if index % 131 == 0:
            q_value = 32767
        return i_value, q_value
    i_value = wrap_signed(1103 * index + 173, 16)
    q_value = wrap_signed(-2053 * index + 911, 16)
    if index % 127 == 0:
        i_value = -32768
    if index % 131 == 0:
        q_value = 32767
    return i_value, q_value


def main():
    args = parse_args()
    if args.samples <= 0:
        raise ValueError("samples must be positive")
    model = TxBpEf2Model()
    rng = random.Random(args.seed) if args.seed is not None else None
    rows = []
    for index in range(args.samples):
        i_value, q_value = sample_pair(index, rng)
        result = model.step(i_value, q_value)
        rows.append(
            {
                "sample": index,
                "i_q15": i_value,
                "q_q15": q_value,
                "phase": result.phase,
                "if_q15": result.if_sample,
                "python_registered_bit": result.registered_bit,
                "python_core_bit": result.rf_bit,
                "python_rf_signed": result.rf_signed,
                "python_quantizer_input": result.quantizer_input,
            }
        )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Generated {len(rows)} samples: {args.output}")


if __name__ == "__main__":
    main()
