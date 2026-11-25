#!/usr/bin/env python3
"""Generate directed MASH 1-1 transactions and independent golden outputs."""

import argparse
import hashlib
import json
import random
from collections import Counter
from pathlib import Path

from dsm_refmodel.mash11 import Mash11Fixed


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_vectors(seed, external_samples=None):
    rng = random.Random(seed)
    cycles = []
    coverage = {}

    def append_case(name, samples, valid_pattern=None, insert_reset=False):
        start = len(cycles)
        if insert_reset:
            cycles.append((1, 0, 0))
        if valid_pattern is None:
            valid_pattern = [1] * len(samples)
        if len(valid_pattern) != len(samples):
            raise ValueError(f"valid pattern length mismatch for {name}")
        for sample, valid in zip(samples, valid_pattern):
            cycles.append((0, int(bool(valid)), int(sample)))
        coverage[name] = {"cycle_start": start, "cycle_end_exclusive": len(cycles),
                          "transactions": sum(int(bool(v)) for v in valid_pattern)}

    cycles.append((1, 0, 0))
    if external_samples is not None:
        append_case("uniform_input_replay", external_samples, insert_reset=False)
        return cycles, coverage
    append_case("zero", [0] * 32)
    append_case("positive_constant", [0x2000] * 96)
    append_case("negative_constant", [-0x2000] * 96)
    append_case("maximum_minimum_alternating",
                [value for _ in range(64) for value in (32767, -32768)])
    append_case("impulse", [0] * 12 + [16384] + [0] * 51, insert_reset=True)
    append_case("step", [-16384] * 32 + [16384] * 64)
    append_case("quantizer_boundary",
                [32767, 32766, 1, 0, -1, -32766, -32767, -32768] * 12)
    random_samples = [rng.randint(-32768, 32767) for _ in range(1024)]
    random_valid = [int(rng.random() >= 0.22) for _ in random_samples]
    append_case("random_with_bubbles", random_samples, random_valid, insert_reset=True)
    append_case("reset_restart", [rng.randint(-32768, 32767) for _ in range(256)],
                [1] * 256, insert_reset=True)
    append_case("long_state_evolution", [rng.randint(-24000, 24000) for _ in range(2048)],
                [int(rng.random() >= 0.08) for _ in range(2048)])
    return cycles, coverage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=130011)
    parser.add_argument("--input-width", type=int, default=16)
    parser.add_argument("--accumulator-width", type=int, default=18)
    parser.add_argument("--samples-file", type=Path,
                        help="replay one signed 16-bit sample per hex line from a shared SKU vector")
    args = parser.parse_args()

    external_samples = None
    if args.samples_file:
        external_samples = []
        for line in args.samples_file.read_text(encoding="ascii").splitlines():
            value = int(line.strip(), 16) & 0xffff
            external_samples.append(value - 0x10000 if value & 0x8000 else value)
    cycles, coverage = build_vectors(args.seed, external_samples)
    model = Mash11Fixed(input_width=args.input_width,
                       accumulator_width=args.accumulator_width,
                       saturate=True)
    expected = []
    levels = Counter()
    resets = bubbles = accepted = 0
    for reset_before, valid, sample in cycles:
        if reset_before:
            model.reset()
            resets += 1
        observation = model.step(bool(valid), sample)
        if valid:
            accepted += 1
            expected.append((observation.stage1_bit, observation.stage2_bit,
                             observation.combined_level, observation.sign_bit))
            levels[str(observation.combined_level)] += 1
        else:
            bubbles += 1

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stimulus_path = args.output_dir / "stimulus.csv"
    with stimulus_path.open("w", encoding="ascii") as stream:
        for reset_before, valid, sample in cycles:
            stream.write(f"{reset_before} {valid} {sample & 0xffff:04X}\n")
    expected_path = args.output_dir / "expected.csv"
    with expected_path.open("w", encoding="ascii") as stream:
        for stage1, stage2, level, sign in expected:
            stream.write(f"{stage1} {stage2} {level} {sign}\n")

    manifest = {
        "seed": args.seed,
        "sku": "MASH 1-1 block-level legacy wrapper",
        "input_width": args.input_width,
        "accumulator_width": args.accumulator_width,
        "saturate": True,
        "cycles": len(cycles),
        "accepted_transactions": accepted,
        "invalid_cycles": bubbles,
        "reset_events": resets,
        "expected_output_transactions": len(expected),
        "combined_level_histogram": dict(sorted(levels.items())),
        "directed_coverage": coverage,
        "shared_input_samples_file": (str(args.samples_file.resolve())
                                       if args.samples_file else None),
        "shared_input_samples_sha256": (sha256(args.samples_file)
                                        if args.samples_file else None),
        "input_contract": "always-accept enable; no ready/backpressure port exists",
        "sha256": {"stimulus.csv": sha256(stimulus_path),
                   "expected.csv": sha256(expected_path)},
    }
    manifest_path = args.output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
    print("MASH11_REFERENCE_VECTORS=PASS")
    print(f"cycles={len(cycles)} accepted={accepted} bubbles={bubbles} resets={resets}")
    print(f"expected_outputs={len(expected)} level_histogram={dict(levels)}")
    print(f"output_dir={args.output_dir.resolve()}")


if __name__ == "__main__":
    main()
