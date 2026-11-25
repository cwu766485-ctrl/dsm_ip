#!/usr/bin/env python3
"""Create one coherent complex tone vector for EF1, EF2 and MASH core screens."""

import argparse
import hashlib
import json
import math
from pathlib import Path

from dsm_refmodel.thermo5 import (
    run_centered_cubic_ef2_inputs,
    run_centered_cubic_frontend,
    write_vectors,
)


def write_hex(path, values, width=4):
    path.write_text("".join(f"{int(value) & ((1 << (4*width))-1):0{width}X}\n"
                            for value in values), encoding="ascii")


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--words", type=int, default=56)
    parser.add_argument("--tone-bin", type=int, default=7)
    parser.add_argument("--amplitude-q15", type=int, default=3277)
    args = parser.parse_args()
    if args.words != 56 or args.words % 7:
        raise SystemExit("this comparison target is fixed to the existing 56-word UVM packet")
    samples = args.words * 8
    if not 0 < args.tone_bin < samples // 2:
        raise SystemExit("tone bin must be inside the positive-frequency range")

    i_flat = [round(args.amplitude_q15 * math.cos(2.0 * math.pi * args.tone_bin * n / samples))
              for n in range(samples)]
    q_flat = [round(args.amplitude_q15 * math.sin(2.0 * math.pi * args.tone_bin * n / samples))
              for n in range(samples)]
    i_words = [i_flat[n:n+8] for n in range(0, samples, 8)]
    q_words = [q_flat[n:n+8] for n in range(0, samples, 8)]
    frame_start_words = (1, 15, 36)
    starts = [int(index + 1 in frame_start_words) for index in range(args.words)]
    gains = [16384 if index < 14 else (14336 if index < 35 else 12288)
             for index in range(args.words)]
    zeros = [(0, 0, 0, 0)] * args.words
    base_dir = args.output_dir / "shared_input"
    write_vectors(base_dir, i_words, q_words, starts, gains, zeros)

    results = {}
    for sku, order, step in (("ef1", 1, 7168), ("ef2", 2, 5120)):
        words = run_centered_cubic_frontend(
            i_words, q_words, starts, gains, step=step, tidsm_order=order)
        out_dir = args.output_dir / sku
        core_inputs = run_centered_cubic_ef2_inputs(i_words, q_words, starts, gains)
        write_vectors(out_dir, i_words, q_words, starts, gains,
                      words, ef2_words=core_inputs)
        results[sku] = {"order": order, "step": step,
                        "output_word_count": len(words),
                        "pa_sha256": {f"plane{p}": sha256(out_dir / f"tid32_thermo5_frontend_pa{p}.mem")
                                      for p in range(4)}}

    manifest = {
        "input_sample_count": samples,
        "input_format": "16-bit signed I/Q, coherent complex tone",
        "tone_bin": args.tone_bin,
        "input_amplitude_q15": args.amplitude_q15,
        "input_frame_start_words_one_based": list(frame_start_words),
        "frame_gain_q14_by_start_word": {"1": 16384, "15": 14336, "36": 12288},
        "shared_input_i_sha256": sha256(base_dir / "tid32_thermo5_frontend_i.mem"),
        "shared_input_q_sha256": sha256(base_dir / "tid32_thermo5_frontend_q.mem"),
        "skus": results,
        "mash_input": "same flattened I sample sequence, one scalar transaction per valid cycle",
        "note": "SKU datapaths have different output sample rates and encoding; this is a common stimulus, not equal latency or equal interface semantics.",
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    (args.output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("DSM_V13_COMPARISON_VECTORS=PASS")
    print(f"input_samples={samples} tone_bin={args.tone_bin} amplitude_q15={args.amplitude_q15}")
    print(f"shared_input={base_dir}")


if __name__ == "__main__":
    main()
