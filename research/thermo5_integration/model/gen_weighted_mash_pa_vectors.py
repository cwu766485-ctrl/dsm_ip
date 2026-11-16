#!/usr/bin/env python3
"""Derive independent weighted-PA golden words from MATLAB MASH vectors."""

import argparse
import hashlib
import json
from pathlib import Path

from mash_weighted_contract import weighted_encode


def read_bits(path):
    return [int(line.strip(), 16) for line in path.read_text().splitlines()]


def write_words(path, values, width):
    digits = (width + 3) // 4
    path.write_text("".join(f"{value:0{digits}X}\n" for value in values))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vector-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    stage1 = read_bits(args.vector_dir / "tidmash_pa1.mem")
    stage2 = read_bits(args.vector_dir / "tidmash_pa2.mem")
    if len(stage1) != len(stage2) or len(stage1) % 64:
        raise SystemExit("MATLAB stage vectors must be matching 64-bit words")
    pa0_words, pa1_words, reconstructed = [], [], []
    previous = (-1, -1)
    for offset in range(0, len(stage1), 64):
        word1 = sum(bit << index for index, bit in enumerate(stage1[offset:offset + 64]))
        word2 = sum(bit << index for index, bit in enumerate(stage2[offset:offset + 64]))
        pa0, pa1, levels, previous = weighted_encode(word1, word2, previous)
        pa0_words.append(pa0)
        pa1_words.append(pa1)
        reconstructed.extend(levels)
    write_words(args.output_dir / "weighted_pa0.mem", pa0_words, 64)
    write_words(args.output_dir / "weighted_pa1.mem", pa1_words, 64)
    manifest = {
        "source": "MATLAB tid_mash11_pipelined_step golden tidmash_pa1/pa2.mem",
        "model": "research/thermo5_integration/model/mash_weighted_contract.py",
        "vectors": len(pa0_words),
        "cartesian_samples": len(reconstructed),
        "previous_q2_reset": [-1, -1],
        "weighted_levels": sorted({v for pair in reconstructed for v in pair}),
        "pa_weights": [1, 2],
        "pa0_sha256": hashlib.sha256((args.output_dir / "weighted_pa0.mem").read_bytes()).hexdigest(),
        "pa1_sha256": hashlib.sha256((args.output_dir / "weighted_pa1.mem").read_bytes()).hexdigest(),
    }
    (args.output_dir / "weighted_pa_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n")
    print(f"THERMO5_WEIGHTED_MASH_GOLDEN_PASS vectors={len(pa0_words)} samples={len(reconstructed)} levels={manifest['weighted_levels']}")


if __name__ == "__main__":
    main()
