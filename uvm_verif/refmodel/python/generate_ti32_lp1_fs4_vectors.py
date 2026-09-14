"""Golden vectors for the explicitly non-bit-true ti32_lp1_fs4_dsm baseline."""
from __future__ import annotations

import argparse
import random
from pathlib import Path


def wrap_signed(value: int, width: int) -> int:
    modulus = 1 << width
    return ((value + (1 << (width - 1))) % modulus) - (1 << (width - 1))


def saturate(value: int, width: int) -> int:
    return min(max(value, -(1 << (width - 1))), (1 << (width - 1)) - 1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vectors", type=int, default=128)
    parser.add_argument("--seed", type=int, default=20260908)
    parser.add_argument("--lanes", type=int, default=32)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.vectors <= 0:
        raise ValueError("--vectors must be positive")
    if args.lanes <= 0:
        raise ValueError("--lanes must be positive")

    rng = random.Random(args.seed)
    lanes, w_in, acc_w = args.lanes, 16, 28
    fs = (1 << (w_in - 1)) - 1
    state = [0] * lanes
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as f:
        f.write("x,y\n")
        for _ in range(args.vectors):
            x_word = [rng.randint(-24000, 24000) for _ in range(lanes)]
            y_word = []
            for lane, sample in enumerate(x_word):
                v = saturate(sample + state[lane], acc_w)
                bit = int(v >= 0)
                quantized = fs if bit else -fs
                state[lane] = wrap_signed(v - quantized, acc_w)
                y_word.append(bit ^ int((lane % 4) >= 2))
            for sample, bit in zip(x_word, y_word):
                f.write(f"{sample},{bit}\n")


if __name__ == "__main__":
    main()
