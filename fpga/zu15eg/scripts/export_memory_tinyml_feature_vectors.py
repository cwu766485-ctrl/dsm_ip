#!/usr/bin/env python3
"""Export raw-monitor to Q12.20 feature and tree-decision golden vectors."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_memory_tinyml_loso import read_conditions  # noqa: E402
from export_memory_tinyml_tree import infer, quantize  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    with args.model.open(encoding="ascii") as handle:
        model = json.load(handle)["model"]
    conditions = read_conditions(args.input)
    with args.input.open(newline="", encoding="utf-8-sig") as handle:
        first_rows = {}
        for row in csv.DictReader(handle):
            first_rows.setdefault(row["condition_id"], row)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# name valid raw[18] expected_q20[13] package direct path path_len ood\n")
        for condition in conditions:
            row = first_rows[str(condition["condition_id"])]
            sample_count = round(float(row["monitor_sample_count"]))
            raw = (
                round(float(row["qam"])),
                round(float(row["bandwidth_mhz"]) * 1000),
                round(float(row["backoff"]) * 1000000),
                round(float(row["temperature_q8_8"])),
                int(float(row["input_power"])), int(float(row["output_power"])),
                int(float(row["peak"])), int(float(row["avg_mag"])),
                int(float(row["evm_proxy"])), int(float(row["acpr_proxy"])),
                int(float(row["spec_bin0"])), int(float(row["spec_bin1"])),
                int(float(row["spec_bin2"])), int(float(row["spec_adj"])),
                int(float(row["clip"])), int(float(row["saturation"])),
                sample_count, int(float(row["observation_error_l1"])),
            )
            expected = tuple(quantize(float(value)) for value in condition["feature"])
            result = infer(model, expected)
            words = [str(condition["condition_id"]), "1", *(str(value) for value in raw),
                     *(str(value) for value in expected), str(result["package"]),
                     str(result["direct"]), str(result["path"]),
                     str(result["path_len"]), str(result["ood"])]
            handle.write(" ".join(words) + "\n")
    print(f"Exported {len(conditions)} raw feature vectors")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
