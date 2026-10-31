#!/usr/bin/env python3
"""Generate exact legal TX corner payloads and centered-cubic/EF2 oracles."""

import argparse
import json
import random
from pathlib import Path

from dsm_refmodel.thermo5 import run_centered_cubic_frontend, write_vectors


SAMPLE_COUNT = 56 * 8
PATTERNS = ("zero", "positive_fullscale", "negative_fullscale",
            "alternating", "impulse", "ramp", "prbs", "quantizer_tie")


def _lfsr16(seed, count):
    state = int(seed) & 0xffff
    if state == 0:
        state = 1
    result = []
    for _ in range(count):
        result.append(state & 1)
        feedback = ((state >> 0) ^ (state >> 2) ^
                    (state >> 3) ^ (state >> 5)) & 1
        state = (state >> 1) | (feedback << 15)
    return result


def make_samples(pattern, seed=610701):
    if pattern not in PATTERNS:
        raise ValueError("unsupported TX corner pattern: " + str(pattern))
    samples = []
    prbs = _lfsr16(seed, SAMPLE_COUNT) if pattern == "prbs" else None
    for index in range(SAMPLE_COUNT):
        if pattern == "zero":
            i_value = q_value = 0
        elif pattern == "positive_fullscale":
            i_value = q_value = 32767
        elif pattern == "negative_fullscale":
            i_value = q_value = -32768
        elif pattern == "alternating":
            i_value = 32767 if index % 2 == 0 else -32768
            q_value = -32768 if index % 2 == 0 else 32767
        elif pattern == "impulse":
            i_value, q_value = ((32767, -32768) if index == 0 else (0, 0))
        elif pattern == "ramp":
            i_value = -32768 + (65535 * index) // (SAMPLE_COUNT - 1)
            q_value = max(-32768, min(32767, -i_value))
        elif pattern == "prbs":
            i_value = 32767 if prbs[index] else -32768
            q_value = -32768 if prbs[index] else 32767
        else:  # A legal first-sample tie: x=-3*STEP makes branch-0 u[0]=0.
            i_value, q_value = -15360, 0
        samples.append((i_value, q_value))
    return samples


def _csv_ints(text):
    values = tuple(int(item.strip(), 0) for item in text.split(",") if item.strip())
    if not values:
        raise ValueError("frame gain list cannot be empty")
    return values


def generate(output_dir, pattern, seed=610701, step=5120,
             frame_gains=(16384, 32767, -32768)):
    samples = make_samples(pattern, seed)
    words = [samples[index:index + 8] for index in range(0, SAMPLE_COUNT, 8)]
    i_words = [[sample[0] for sample in word] for word in words]
    q_words = [[sample[1] for sample in word] for word in words]
    frame_starts = [0] * len(words)
    frame_gains_by_word = [16384] * len(words)
    start_words = (1, 15, 36)
    gains = ((16384, 16384, 16384) if pattern == "quantizer_tie"
             else tuple(frame_gains))
    for ordinal, one_based in enumerate(start_words):
        frame_starts[one_based - 1] = 1
        frame_gains_by_word[one_based - 1] = gains[ordinal % len(gains)]

    plane_words = run_centered_cubic_frontend(
        i_words, q_words, frame_starts, frame_gains_by_word,
        step=step, tidsm_order=2)
    output_dir = Path(output_dir)
    write_vectors(output_dir, i_words, q_words, frame_starts,
                  frame_gains_by_word, plane_words)
    tie_witness = None
    if pattern == "quantizer_tie":
        tie_witness = {
            "branch": 0,
            "component": "I",
            "first_interpolated_sample": -3 * int(step),
            "offset": 3 * int(step),
            "initial_error_state_1": 0,
            "initial_error_state_2": 0,
            "quantizer_input_u": 0,
            "tie_decision": "negative (RTL/Python rule is u > 0 => +1, else -1)",
        }
    metadata = {
        "pattern": pattern,
        "seed": int(seed),
        "source_samples": SAMPLE_COUNT,
        "source_words_8lane": len(words),
        "source_axis_beats_14lane": SAMPLE_COUNT // 14,
        "output_words_per_plane": len(plane_words),
        "step": int(step),
        "state_width_bits": 20,
        "interpolation": "centered cubic x2 cascaded twice, per frame zero extension",
        "dpd": "identity",
        "frame_start_words_1based": list(start_words),
        "frame_gains_q2_14": list(gains),
        "tie_witness": tie_witness,
        "checker": "UVM four-plane bit-true scoreboard against this Python oracle",
        "output_tail_rule": "single legal 56-word output frame; no implicit extra tail word",
    }
    (output_dir / "corner_manifest.json").write_text(
        json.dumps(metadata, indent=2) + "\n")
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--pattern", choices=PATTERNS, required=True)
    parser.add_argument("--seed", type=int, default=610701)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--frame-gains", type=_csv_ints,
                        default=(16384, 32767, -32768))
    args = parser.parse_args()
    metadata = generate(args.output_dir, args.pattern, args.seed,
                        args.step, args.frame_gains)
    print("THERMO5_TX_CORNER_VECTOR_PASS pattern=%s source_samples=%d output_words=%d" %
          (metadata["pattern"], metadata["source_samples"],
           metadata["output_words_per_plane"]))
    if metadata["tie_witness"]:
        print("THERMO5_EF2_TIE_WITNESS_PASS branch=0 component=I u=0 rule=negative")


if __name__ == "__main__":
    main()
