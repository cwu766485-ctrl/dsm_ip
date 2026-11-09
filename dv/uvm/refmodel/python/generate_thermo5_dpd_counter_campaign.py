#!/usr/bin/env python3.12
"""Generate long legal Thermo5 frames for DPD counter/toggle closure."""

import argparse
import hashlib
import json
from pathlib import Path

from dsm_refmodel.thermo5 import (
    centered_cubic_dpd_saturation_by_lane,
    generate_source_vectors,
    one_tap_complex_coefficients,
    run_centered_cubic_frontend,
    write_vectors,
)


def generate(output_dir: Path, core_words: int, seed: int) -> dict:
    if core_words < 56 or core_words % 56:
        raise ValueError("core_words must be a positive multiple of the legal 56-word frame")
    frame_count = core_words // 56
    frame_starts_1based = tuple(range(1, core_words + 1, 56))
    frame_gain = 1 << 14
    coefficients = one_tap_complex_coefficients(c1_re_q14=0x7FFF)

    i_words, q_words, starts, gains = generate_source_vectors(
        words=core_words,
        seed=seed,
        profile="range_stress",
        frame_start_words=frame_starts_1based,
        frame_gains=(frame_gain,),
    )
    pa_words = run_centered_cubic_frontend(
        i_words,
        q_words,
        starts,
        gains,
        step=5120,
        dpd_coefficients=coefficients,
        dpd_active_taps=1,
        tidsm_order=2,
    )
    lane_saturation_counts = centered_cubic_dpd_saturation_by_lane(
        i_words,
        q_words,
        starts,
        gains,
        coefficients,
        dpd_active_taps=1,
        lanes=16,
    )
    expected_samples_per_lane = core_words + frame_count
    write_vectors(output_dir, i_words, q_words, starts, gains, pa_words)
    count_path = output_dir / "thermo5_dpd_saturation_count.mem"
    count_path.write_text("".join("%d\n" % value for value in lane_saturation_counts),
                          encoding="ascii")

    vector_paths = sorted(output_dir.glob("tid32_thermo5_frontend_*.mem"))
    vector_paths.append(count_path)
    manifest = {
        "schema_version": 1,
        "configuration": {
            "product": "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120 STATE_BITS=20",
            "dpd_max_taps": 1,
            "active_taps": 1,
            "coefficients_q2_14": {
                key: list(value) for key, value in coefficients.items()
            },
            "fifo": "Generic FIFO",
            "axil": "legal shadow writes followed by COMMIT at initial frame boundary",
        },
        "stimulus": {
            "profile": "range_stress",
            "seed": seed,
            "core_words": core_words,
            "source_beats": core_words * 4 // 7,
            "frame_count": frame_count,
            "frame_words": 56,
            "frame_gain_q2_14": frame_gain,
            "packet_beats": 32,
        },
        "independent_oracle": {
            "model": "dsm_refmodel.thermo5.centered_cubic_dpd_saturation_by_lane",
            "expected_sample_count_per_lane": expected_samples_per_lane,
            "expected_saturation_count_per_lane": lane_saturation_counts,
            "vector_output_words_per_plane": len(pa_words),
        },
        "files_sha256": {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in vector_paths
        },
    }
    manifest_path = output_dir / "thermo5_dpd_counter_campaign_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
    print("THERMO5_DPD_COUNTER_VECTORS_PASS core_words=%d frames=%d seed=%d" %
          (core_words, frame_count, seed))
    print("expected_sample_count_per_lane=%d" % expected_samples_per_lane)
    print("expected_saturation_count_per_lane=%s" %
          ",".join(str(value) for value in lane_saturation_counts))
    print("output_dir=%s" % output_dir.resolve())
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--core-words", type=int, default=65632)
    parser.add_argument("--seed", type=int, default=180018)
    args = parser.parse_args()
    generate(args.output_dir, args.core_words, args.seed)


if __name__ == "__main__":
    main()
