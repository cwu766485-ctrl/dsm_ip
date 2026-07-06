#!/usr/bin/env python3
"""Pack Q1.15 I/Q MEM vectors into 32-bit AXI DMA words.

Output word format matches the RTL contract:

    bits [15:0]  = I sample
    bits [31:16] = Q sample

The binary file is little-endian uint32 words, suitable for loading into a DMA
source buffer from Linux, bare-metal software, or a board-specific test script.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def read_hex16(path: Path) -> list[int]:
    values: list[int] = []
    with path.open("r", encoding="ascii") as handle:
        for line_no, raw in enumerate(handle, start=1):
            text = raw.strip()
            if not text or text.startswith("#"):
                continue
            value = int(text, 16)
            if value < 0 or value > 0xFFFF:
                raise ValueError(f"{path}:{line_no}: value is not 16-bit: {text}")
            values.append(value)
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--i-mem", default="verif/vectors/p0/rom_i.mem")
    parser.add_argument("--q-mem", default="verif/vectors/p0/rom_q.mem")
    parser.add_argument("--out", default="fpga/zu15eg/p0_iq_dma_words.bin")
    parser.add_argument("--limit", type=int, default=0, help="optional sample limit")
    args = parser.parse_args()

    i_path = Path(args.i_mem)
    q_path = Path(args.q_mem)
    out_path = Path(args.out)

    i_values = read_hex16(i_path)
    q_values = read_hex16(q_path)
    if len(i_values) != len(q_values):
        raise ValueError(f"I/Q length mismatch: {len(i_values)} != {len(q_values)}")

    count = len(i_values) if args.limit <= 0 else min(args.limit, len(i_values))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("wb") as handle:
        for i_sample, q_sample in zip(i_values[:count], q_values[:count]):
            word = (q_sample << 16) | i_sample
            handle.write(struct.pack("<I", word))

    print(f"wrote {count} packed I/Q words to {out_path}")


if __name__ == "__main__":
    main()
