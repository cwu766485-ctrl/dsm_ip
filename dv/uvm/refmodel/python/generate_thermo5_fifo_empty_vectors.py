#!/usr/bin/env python3
"""Create a bit-true oracle for the deliberately short FIFO-empty frame."""

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from dsm_refmodel.thermo5 import read_source_vectors, run_centered_cubic_frontend, write_vectors


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--step", type=int, required=True)
    parser.add_argument("--tidsm-order", type=int, choices=(1, 2), required=True)
    args = parser.parse_args()

    i_words, q_words, starts, gains = read_source_vectors(args.input_dir)
    if len(i_words) < 7 or not starts[0] or any(starts[1:7]):
        raise SystemExit("input must contain seven words from one frame beginning at word zero")

    short_i, short_q = i_words[:7], q_words[:7]
    short_starts = [1] + [0] * 6
    short_gains = [gains[0]] * 7
    expected = run_centered_cubic_frontend(
        short_i, short_q, short_starts, short_gains,
        step=args.step, tidsm_order=args.tidsm_order)
    if len(expected) != 7:
        raise SystemExit(f"short-frame model produced {len(expected)} PA words, expected 7")
    write_vectors(args.output_dir, short_i, short_q, short_starts,
                  short_gains, expected)

    output_dir = args.output_dir.resolve()
    # Keep all driver/scoreboard memories at the parent file lengths to avoid
    # simulator short-file diagnostics. Only the first seven PA words belong
    # to this test; the remaining PA entries are inert filler from the parent
    # vector set and are never consumed by fifo_empty.
    for name in ("tid32_thermo5_frontend_i.mem",
                 "tid32_thermo5_frontend_q.mem",
                 "tid32_thermo5_frontend_frame_start.mem",
                 "tid32_thermo5_frontend_frame_gain.mem",
                 "tid32_thermo5_frontend_ef2_i.mem",
                 "tid32_thermo5_frontend_ef2_q.mem"):
        source = args.input_dir / name
        if source.exists():
            shutil.copyfile(source, output_dir / name)
    for plane in range(4):
        name = f"tid32_thermo5_frontend_pa{plane}.mem"
        source_lines = (args.input_dir / name).read_text(encoding="ascii").splitlines()
        if len(source_lines) < 7:
            raise SystemExit(f"parent vector {name} has fewer than seven PA words")
        generated_lines = (output_dir / name).read_text(encoding="ascii").splitlines()
        (output_dir / name).write_text(
            "\n".join(generated_lines[:7] + source_lines[7:]) + "\n",
            encoding="ascii")
    manifest = {
        "model": "dsm_refmodel.thermo5.run_centered_cubic_frontend",
        "input_dir": str(args.input_dir.resolve()),
        "input_prefix_words": 7,
        "file_padding": "source/metadata memories copied from parent; PA oracle words 7+ are inert parent-vector filler",
        "frame_contract": "one 7-word centered-cubic frame, TLAST after four 14-sample AXIS beats",
        "tidsm_order": args.tidsm_order,
        "step": args.step,
        "pa_words_per_plane": len(expected),
        "sha256": {
            name: sha256(output_dir / name)
            for name in sorted(path.name for path in output_dir.glob("*.mem"))
        },
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("THERMO5_FIFO_EMPTY_ORACLE=PASS words=7")
    print(f"output_dir={output_dir}")


if __name__ == "__main__":
    main()
