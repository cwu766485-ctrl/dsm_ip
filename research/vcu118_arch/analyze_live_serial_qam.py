#!/usr/bin/env python3
"""Measure QAM metrics from a live multi-frame GTY digital serial capture.

The capture is first checked word-for-word against the independent continuous
PA Golden. The existing runtime QAM receiver then evaluates the first frame
using the repository's fixed source-offset contract.
"""

import argparse
import hashlib
import json
import shutil
import sys
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_words(path):
    return [int(value, 16) for value in path.read_text().split()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", type=Path, required=True,
                        help="directory containing serial_pa0.mem and serial_pa1.mem")
    parser.add_argument("--golden", type=Path, required=True,
                        help="directory containing long_pa0.mem and long_pa1.mem")
    parser.add_argument("--prepared", type=Path, required=True,
                        help="runtime QAM stimulus directory containing stimulus.json")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(repo / "dv/uvm/refmodel/python"))
    from thermo5_runtime_qam import evaluate

    args.out.mkdir(parents=True, exist_ok=False)
    stimulus = json.loads((args.prepared / "stimulus.json").read_text())
    words_per_frame = int(stimulus["words"])
    tx_capture = args.out / "first_frame_from_live_serial"
    tx_capture.mkdir()

    captures = {}
    for lane in range(2):
        serial_path = args.serial / f"serial_pa{lane}.mem"
        golden_path = args.golden / f"long_pa{lane}.mem"
        serial_words = read_words(serial_path)
        golden_words = read_words(golden_path)
        if len(serial_words) != len(golden_words):
            raise SystemExit(f"lane {lane}: capture/Golden word count mismatch")
        mismatch = next((i for i, (a, b) in enumerate(zip(serial_words, golden_words))
                         if a != b), None)
        if mismatch is not None:
            raise SystemExit(f"lane {lane}: first capture/Golden mismatch at word {mismatch}")
        if len(serial_words) % words_per_frame:
            raise SystemExit("serial capture is not an integer number of QAM frames")
        destination = tx_capture / f"phase1_arch2_pa{lane}.mem"
        destination.write_text("".join(f"{word:016x}\n" for word in serial_words[:words_per_frame]))
        captures[f"lane{lane}"] = {
            "serial_path": str(serial_path),
            "serial_sha256": sha256(serial_path),
            "golden_path": str(golden_path),
            "golden_sha256": sha256(golden_path),
            "words": len(serial_words),
            "exact_word_match": True,
            "first_mismatch": None,
        }

    captured_frames = len(serial_words) // words_per_frame

    metrics_path = args.out / "qam_metrics.json"
    evaluate(args.prepared, tx_capture, metrics_path)
    result = json.loads(metrics_path.read_text())
    result.update({
        "source": f"first frame recovered from {captured_frames}-frame dual-lane live GTY TX/RX capture",
        "capture_frames": captured_frames,
        "serialized_bits_per_lane": len(serial_words) * 64,
        "serial_capture_to_continuous_golden": captures,
        "receiver_contract": "existing thermo5_runtime_qam evaluator; fixed source offset, no lag search",
        "board_rf_metrics": "NOT_MEASURED",
    })
    metrics_path.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
