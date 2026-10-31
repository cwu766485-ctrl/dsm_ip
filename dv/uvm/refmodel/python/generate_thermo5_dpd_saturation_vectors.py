#!/usr/bin/env python3.12
"""Generate bit-true frontend vectors for legal one-tap DPD rail coverage."""

import argparse
import hashlib
import json
from pathlib import Path

from dsm_refmodel.thermo5 import (
    _centered_cubic_midpoint,
    _centered_cubic_x2_with_future,
    apply_memory_polynomial,
    apply_q14_gain,
    generate_source_vectors,
    run_centered_cubic_frontend,
    write_vectors,
)


COEFFICIENT = 0x7FFF
DPD_PROFILE = {
    "c1_re": (COEFFICIENT,),
    "c1_im": (0,),
    "c3_re": (0,),
    "c3_im": (0,),
    "c5_re": (0,),
    "c5_im": (0,),
}


def generate(output_dir: Path, seed: int) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    i_words, q_words, frame_starts, frame_gains = generate_source_vectors(
        words=56,
        seed=seed,
        profile="range_stress",
        frame_start_words=(1,),
        frame_gains=(1 << 14,),
    )
    pa_words = run_centered_cubic_frontend(
        i_words,
        q_words,
        frame_starts,
        frame_gains,
        step=5120,
        dpd_coefficients=DPD_PROFILE,
        dpd_active_taps=1,
        tidsm_order=2,
    )
    write_vectors(output_dir, i_words, q_words, frame_starts, frame_gains, pa_words)

    flat_i = [sample for word in i_words for sample in word]
    flat_q = [sample for word in q_words for sample in word]
    gained_i, gained_q = apply_q14_gain(flat_i, flat_q, 1 << 14)
    stage1 = _centered_cubic_x2_with_future(list(zip(gained_i, gained_q)))
    tail = [(0, 0)] * 16
    tail[1] = _centered_cubic_midpoint(
        (gained_i[-1], gained_q[-1]), (0, 0), (0, 0), (0, 0)
    )
    dpd_inputs = stage1 + tail
    _, _, saturation_samples = apply_memory_polynomial(
        dpd_inputs, DPD_PROFILE, active_taps=1
    )

    directional = [
        {"i_positive": 0, "i_negative": 0, "q_positive": 0, "q_negative": 0}
        for _ in range(16)
    ]
    for sample_index, (i_value, q_value) in enumerate(dpd_inputs):
        raw_i = (i_value * COEFFICIENT) >> 14
        raw_q = (q_value * COEFFICIENT) >> 14
        lane = directional[sample_index % 16]
        lane["i_positive"] += int(raw_i > 32767)
        lane["i_negative"] += int(raw_i < -32768)
        lane["q_positive"] += int(raw_q > 32767)
        lane["q_negative"] += int(raw_q < -32768)

    if len(pa_words) != 56 or any(
        not all(counts.values()) for counts in directional
    ):
        raise RuntimeError("oracle vectors do not hit all four clamp directions per lane")

    files = sorted(output_dir.glob("tid32_thermo5_frontend_*.mem"))
    manifest = {
        "schema_version": 1,
        "configuration": {
            "interpolator": "Centered-Cubic x2+x2",
            "dsm": "EF2 ORDER=2 STEP=5120",
            "dpd_max_taps": 1,
            "active_taps": 1,
            "coefficients_q2_14": {name: list(values) for name, values in DPD_PROFILE.items()},
            "fifo": "Generic FIFO",
        },
        "stimulus": {
            "profile": "range_stress",
            "seed": seed,
            "source_words": len(i_words),
            "source_beats": len(i_words) * 4 // 7,
            "frame_starts": 1,
            "frame_gain_q2_14": 1 << 14,
        },
        "oracle": {
            "implementation": "dsm_refmodel.thermo5.run_centered_cubic_frontend",
            "output_words": len(pa_words),
            "dpd_input_vectors_per_lane": len(dpd_inputs) // 16,
            "saturated_iq_samples": saturation_samples,
            "directional_clamp_hits_by_lane": directional,
        },
        "vectors_sha256": {
            path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files
        },
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=620131)
    args = parser.parse_args()
    manifest = generate(args.output_dir, args.seed)
    print(
        "THERMO5_DPD_SATURATION_VECTORS_PASS words=%d dpd_saturated=%d seed=%d"
        % (
            manifest["oracle"]["output_words"],
            manifest["oracle"]["saturated_iq_samples"],
            args.seed,
        )
    )
    print("output_dir=%s" % args.output_dir.resolve())


if __name__ == "__main__":
    main()
