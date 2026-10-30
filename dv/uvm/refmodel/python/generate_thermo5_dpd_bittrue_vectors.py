#!/usr/bin/env python3
"""Generate scalar Q1.15 vectors for the standalone 16-lane DPD RTL miter."""

import argparse
import hashlib
import json
from pathlib import Path

from benchmark_thermo5_tid_receiver import make_256qam_ofdm
from dsm_refmodel.thermo5 import (
    _interp_x2_centered_pairs,
    apply_memory_polynomial,
)


def _write_hex(path, values, width=16):
    mask = (1 << width) - 1
    payload = "".join("%0*x\n" % (width // 4, int(value) & mask)
                      for value in values)
    path.write_text(payload)
    return hashlib.sha256(payload.encode("ascii")).hexdigest()


def generate(candidate_json, candidate_name, seed, symbols, rms_drive, output_dir):
    fit = json.loads(Path(candidate_json).read_text())
    candidate = next((row for row in fit["candidates"]
                      if row["name"] == candidate_name), None)
    if candidate is None:
        raise ValueError("candidate not found: " + candidate_name)
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    source = list(stimulus["source_iq"])
    stage1 = _interp_x2_centered_pairs(source + [(0, 0)] * 3)[:2 * len(source)]
    expected, final_history, saturation_count = apply_memory_polynomial(
        stage1, candidate["coefficients"], active_taps=candidate["active_taps"])
    if len(stage1) % 16:
        raise ValueError("interpolated DPD stream must contain complete 16-lane words")

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    hashes = {}
    hashes["input_i.mem"] = _write_hex(output_dir / "input_i.mem",
                                      [sample[0] for sample in stage1])
    hashes["input_q.mem"] = _write_hex(output_dir / "input_q.mem",
                                      [sample[1] for sample in stage1])
    hashes["expected_i.mem"] = _write_hex(output_dir / "expected_i.mem",
                                         [sample[0] for sample in expected])
    hashes["expected_q.mem"] = _write_hex(output_dir / "expected_q.mem",
                                         [sample[1] for sample in expected])
    coefficient_words = []
    for name in ("c1_re", "c1_im", "c3_re", "c3_im", "c5_re", "c5_im"):
        coefficient_words.extend(int(value) for value in
                                  candidate["coefficients"][name])
    hashes["coefficients.mem"] = _write_hex(
        output_dir / "coefficients.mem", coefficient_words)
    manifest = {
        "candidate": candidate_name,
        "active_taps": candidate["active_taps"],
        "seed": int(seed),
        "symbols": int(symbols),
        "rms_drive_target": float(rms_drive),
        "source_samples": len(source),
        "dpd_samples": len(stage1),
        "dpd_words_16lane": len(stage1) // 16,
        "q_format": {"input": "signed Q1.15", "coefficient": "signed Q2.14"},
        "python_oracle": "dsm_refmodel.thermo5.apply_memory_polynomial",
        "output_saturation_samples": saturation_count,
        "final_history_iq": [list(sample) for sample in final_history],
        "coefficient_image": candidate["coefficients"],
        "files_sha256": hashes,
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-json", type=Path, required=True)
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--seed", type=int, default=281001)
    parser.add_argument("--symbols", type=int, default=9)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = generate(args.candidate_json, args.candidate, args.seed,
                        args.symbols, args.rms_drive, args.output_dir)
    print("THERMO5_DPD_BITTRUE_VECTORS_PASS samples=%d words=%d saturation=%d" % (
        manifest["dpd_samples"], manifest["dpd_words_16lane"],
        manifest["output_saturation_samples"]))
    print("output_dir=%s" % args.output_dir.resolve())


if __name__ == "__main__":
    main()
