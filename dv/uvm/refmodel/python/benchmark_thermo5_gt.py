#!/usr/bin/env python3
"""Inject discrete BER into Python-generated four-plane thermo5 TID words.

This screens digital data corruption at the raw GT user-word boundary. It does
not model a GT electrical eye, serializer/CDR behavior, or analog noise.
"""

import argparse
import json
import random
from pathlib import Path

from dsm_refmodel.link_models import inject_gt_plane_bit_errors
from dsm_refmodel.thermo5 import generate_source_vectors, run_frozen_frontend


def run(words=56, seed=20261023, ber=0.0, interp_taps=2):
    i_words, q_words, frame_starts, frame_gains = generate_source_vectors(
        words=words, seed=seed)
    planes = run_frozen_frontend(
        i_words, q_words, frame_starts, frame_gains,
        interp_taps=interp_taps)
    corrupted, stats = inject_gt_plane_bit_errors(
        planes, random.Random(seed + 1709), ber=ber)
    return {
        "benchmark": "thermo5_four_plane_gt_bit_error_screen",
        "seed": seed,
        "source_words": words,
        "output_words": len(planes),
        "interp_taps": interp_taps,
        "requested_ber": ber,
        "bit_error_stats": stats,
        "model_scope": [
            "Bit flips are applied independently to the Python bit-true model's four 64-bit TID output planes.",
            "The result models digital word corruption only; no timing jitter, line coding, CDR, eye, or analog noise is represented.",
            "Use a realistic measured or vendor-specified BER and enough serialized bits for useful rare-error statistics.",
        ],
        "changed_words": sum(a != b for a, b in zip(planes, corrupted)),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--words", type=int, default=56)
    parser.add_argument("--seed", type=int, default=20261023)
    parser.add_argument("--ber", type=float, default=0.0)
    parser.add_argument("--interp-taps", type=int, choices=(2, 3, 4), default=2)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    if args.words < 12:
        parser.error("--words must be at least 12")
    if not 0.0 <= args.ber <= 1.0:
        parser.error("--ber must be between zero and one")
    result = run(args.words, args.seed, args.ber, args.interp_taps)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")


if __name__ == "__main__":
    main()
