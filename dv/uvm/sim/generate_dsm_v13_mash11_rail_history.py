#!/usr/bin/env python3
"""Generate a bit-true MASH Product witness for the maximum-rail/stage-1 cross."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from dsm_refmodel.mash11 import Mash11Fixed
from dsm_refmodel.thermo5 import (
    run_centered_cubic_ef2_inputs,
    run_centered_cubic_frontend,
    write_vectors,
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--negative-words", type=int, default=4144,
                        help="negative-rail frame length; must be a multiple of 56")
    parser.add_argument("--positive-words", type=int, default=56,
                        help="positive-rail frame length; must be a multiple of 56")
    args = parser.parse_args()

    if args.negative_words < 4096 or args.negative_words % 112:
        parser.error("--negative-words must be >=4096 and a multiple of 112")
    if args.positive_words < 56 or args.positive_words % 56:
        parser.error("--positive-words must be a positive multiple of 56")

    words = args.negative_words + args.positive_words
    i_words = ([[-32768] * 8 for _ in range(args.negative_words)] +
               [[32767] * 8 for _ in range(args.positive_words)])
    q_words = [list(word) for word in i_words]
    frame_starts = [0] * words
    frame_starts[0] = 1
    frame_starts[args.negative_words // 2] = 1
    frame_starts[args.negative_words] = 1
    frame_gains = [16384] * words

    ef2_words = run_centered_cubic_ef2_inputs(
        i_words, q_words, frame_starts, frame_gains)
    if len(ef2_words) != words:
        raise RuntimeError(f"reference produced {len(ef2_words)} output words; expected {words}")

    cross_hits = {"maximum_rail_x_negative_stage1": [],
                  "minimum_rail_x_positive_stage1": []}
    level_counts: dict[str, int] = {}
    for component in (0, 1):
        model = Mash11Fixed(input_width=16, accumulator_width=18, saturate=True)
        for word_index, (block_i, block_q) in enumerate(ef2_words):
            block = block_i if component == 0 else block_q
            for lane, sample in enumerate(block):
                observation = model.step(True, sample)
                level = str(observation.combined_level)
                level_counts[level] = level_counts.get(level, 0) + 1
                witness = {"component": "I" if component == 0 else "Q",
                           "word": word_index, "lane": lane,
                           "v1": observation.v1, "e1_next": observation.e1}
                if sample == 32767 and observation.v1 < 0:
                    cross_hits["maximum_rail_x_negative_stage1"].append(witness)
                if sample == -32768 and observation.v1 > 0:
                    cross_hits["minimum_rail_x_positive_stage1"].append(witness)

    if not cross_hits["maximum_rail_x_negative_stage1"]:
        raise RuntimeError("directed frame-boundary witness missed maximum-rail x negative Stage 1")
    if cross_hits["minimum_rail_x_positive_stage1"]:
        raise RuntimeError("minimum-rail x positive Stage 1 was observed; review the reset contract")
    if not set(level_counts).issubset({"-3", "-1", "1", "2", "3"}):
        raise RuntimeError(f"reference produced an unsupported weighted level: {level_counts}")

    pa_words = run_centered_cubic_frontend(
        i_words, q_words, frame_starts, frame_gains, dsm_mode="mash11")
    write_vectors(args.output_dir, i_words, q_words, frame_starts, frame_gains,
                  pa_words, ef2_words=ef2_words)
    output = args.output_dir.resolve()
    files = sorted(path for path in output.iterdir() if path.is_file())
    manifest = {
        "schema": "dsm_v13_round4_mash11_rail_history_v1",
        "sku": "MASH 1-1 Product",
        "input_width": 16,
        "accumulator_width": 18,
        "saturate": True,
        "frame_gain_q14": 16384,
        "negative_rail_frame_words": args.negative_words,
        "positive_rail_frame_words": args.positive_words,
        "core_words": words,
        "axis_beats": words * 4 // 7,
        "frame_starts": [0, args.negative_words // 2, args.negative_words],
        "frame_contract": "two 56-word-aligned negative-rail frames prime the continuous MASH recurrence before a 56-word positive-rail frame; frame boundaries reset the centered interpolator only",
        "reference": "independent dsm_refmodel.mash11.Mash11Fixed and dsm_refmodel.thermo5 frontend model",
        "cross_witnesses": cross_hits,
        "weighted_level_histogram": dict(sorted(level_counts.items(), key=lambda item: int(item[0]))),
        "vector_sha256": {path.name: sha256(path) for path in files},
    }
    manifest_path = output / "mash11_rail_history_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
    print("DSM_V13_MASH11_RAIL_HISTORY_VECTORS=PASS")
    print(f"core_words={words} axis_beats={words * 4 // 7} frame_starts=3")
    for name, witnesses in cross_hits.items():
        print(f"{name}={len(witnesses)}")
    print(f"output_dir={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
