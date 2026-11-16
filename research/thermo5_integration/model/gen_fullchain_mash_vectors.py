#!/usr/bin/env python3
"""Generate independent centered-cubic frontend and weighted-MASH vectors."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from dsm_refmodel.thermo5 import (
    one_tap_complex_coefficients,
    read_source_vectors,
    run_centered_cubic_ef2_inputs,
)
from mash11_reference import run_mash11
from mash_weighted_contract import weighted_encode


def _read_words(path, width):
    values = [int(line.strip(), 16) for line in path.read_text().splitlines() if line.strip()]
    if len(values) % width:
        raise ValueError("%s does not contain a whole number of words" % path)
    return [sum(bit << index for index, bit in enumerate(values[first:first + width]))
            for first in range(0, len(values), width)]


def _read_samples(path):
    values = [int(line.strip(), 16) for line in path.read_text().splitlines() if line.strip()]
    return [value - 0x10000 if value & 0x8000 else value for value in values]


def _write_mem(path, values, width):
    digits = (width + 3) // 4
    path.write_text("".join("%0*X\n" % (digits, int(value) & ((1 << width) - 1))
                            for value in values))


def _compare_historical(raw_pairs, vector_dir):
    count = len(raw_pairs)
    inputs_i = _read_samples(vector_dir / "tidmash_i.mem")
    inputs_q = _read_samples(vector_dir / "tidmash_q.mem")
    if len(inputs_i) != count * 32 or len(inputs_q) != count * 32:
        raise ValueError("historical vector word count does not match the reference run")
    raw1 = _read_words(vector_dir / "tidmash_pa1.mem", 64)
    raw2 = _read_words(vector_dir / "tidmash_pa2.mem", 64)
    mismatches = [(index, pair, (raw1[index], raw2[index]))
                  for index, pair in enumerate(raw_pairs)
                  if pair != (raw1[index], raw2[index])]
    if len(raw1) != count or len(raw2) != count:
        raise ValueError("historical stage-output count does not match the reference run")
    if mismatches:
        index, actual, expected = mismatches[0]
        raise AssertionError("MATLAB raw-stage mismatch at word %d: got %016x/%016x expected %016x/%016x" %
                             (index, actual[0], actual[1], expected[0], expected[1]))
    return {"words": count, "stage_bits_compared": count * 128, "mismatches": 0}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--frontend-vector-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--historical-mash-dir", type=Path)
    parser.add_argument("--step", type=int, default=5120,
                        help="recorded frontend configuration; the MASH core itself has no STEP")
    parser.add_argument("--dpd-c1-re-q14", type=int, default=16384)
    args = parser.parse_args()

    source = args.frontend_vector_dir.resolve()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    i_words, q_words, starts, gains = read_source_vectors(source)
    coeffs = one_tap_complex_coefficients(args.dpd_c1_re_q14, 0, 0, 0, 0, 0)
    pre_words = run_centered_cubic_ef2_inputs(
        i_words, q_words, starts, gains,
        dpd_coefficients=coeffs, dpd_active_taps=1)
    if len(pre_words) != len(i_words):
        raise ValueError("frontend oracle produced a different transaction count")

    pre_i = [sample for word, _ in pre_words for sample in word]
    pre_q = [sample for _, word in pre_words for sample in word]
    raw_pairs = run_mash11(
        [list(i_word) for i_word, _ in pre_words],
        [list(q_word) for _, q_word in pre_words])
    prev = (-1, -1)
    pa0_words, pa1_words = [], []
    for stage1, stage2 in raw_pairs:
        pa0, pa1, _, prev = weighted_encode(stage1, stage2, prev, channels=32)
        pa0_words.append(pa0)
        pa1_words.append(pa1)

    for name in ("tid32_thermo5_frontend_i.mem", "tid32_thermo5_frontend_q.mem",
                 "tid32_thermo5_frontend_frame_start.mem",
                 "tid32_thermo5_frontend_frame_gain.mem"):
        shutil.copy2(source / name, out / name)
    _write_mem(out / "thermo5_pre_dsm_i.mem", pre_i, 16)
    _write_mem(out / "thermo5_pre_dsm_q.mem", pre_q, 16)
    _write_mem(out / "tid32_thermo5_frontend_pa0.mem", pa0_words, 64)
    _write_mem(out / "tid32_thermo5_frontend_pa1.mem", pa1_words, 64)

    matlab_check = None
    if args.historical_mash_dir:
        matlab_check = _compare_historical(
            run_mash11(
                [list(word) for word in _read_words_by_word(args.historical_mash_dir / "tidmash_i.mem", 32)],
                [list(word) for word in _read_words_by_word(args.historical_mash_dir / "tidmash_q.mem", 32)]),
            args.historical_mash_dir)

    manifest = {
        "source_commit": "6c96c4e1b11bf193240fb8bf5d0e540e5b3c8b3c",
        "source_vector_dir": str(source),
        "source_sha256": {
            name: hashlib.sha256((source / name).read_bytes()).hexdigest()
            for name in ("tid32_thermo5_frontend_i.mem", "tid32_thermo5_frontend_q.mem",
                         "tid32_thermo5_frontend_frame_start.mem",
                         "tid32_thermo5_frontend_frame_gain.mem")
        },
        "frontend": "dsm_refmodel.thermo5.run_centered_cubic_ef2_inputs",
        "dsm": "mash11_reference.run_mash11",
        "pa_contract": "PA0 + 2*PA1; bipolar Fs/4 raw bitstreams",
        "words": len(pre_words),
        "source_step": args.step,
        "dpd_c1_re_q14": args.dpd_c1_re_q14,
        "pre_dsm_samples_per_component": len(pre_i),
        "historical_matlab_crosscheck": matlab_check,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("THERMO5_FULLCHAIN_MASH_VECTORS_PASS words=%d pre_dsm_samples=%d" %
          (len(pre_words), len(pre_i)))
    if matlab_check:
        print("MATLAB_RAW_STAGE_CROSSCHECK_PASS words=%d bits=%d" %
              (matlab_check["words"], matlab_check["stage_bits_compared"]))
    print("output_dir=%s" % out)


def _read_words_by_word(path, width):
    values = _read_samples(path)
    if len(values) % width:
        raise ValueError("%s does not contain whole vectors" % path)
    return [values[first:first + width] for first in range(0, len(values), width)]


if __name__ == "__main__":
    main()
