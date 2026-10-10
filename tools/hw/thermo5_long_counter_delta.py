#!/usr/bin/env python3
"""Compare same-source thermo5 URG reports and require one natural counter bit."""

import argparse
import csv
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "dv/uvm/sim"))
import run_thermo5_gap_closure as gap


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--fifo", choices=("generic", "xpm"), required=True)
    parser.add_argument("--bit", type=int, default=22)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    delta = gap.toggle_delta(args.before, args.after)
    counter_rows = [row for row in delta
                    if ".u_dpd" in row["instance"]
                    and row["signal"] == f"sample_count[{args.bit}]"]
    instances = {row["instance"] for row in counter_rows}
    if len(counter_rows) != 16 or len(instances) != 16:
        raise SystemExit(f"Expected 16 distinct lane counters for bit{args.bit}; got {len(counter_rows)}")
    missed = [row for row in counter_rows if row["status"] != "HIT_BOTH_DIRECTIONS"]
    if missed:
        raise SystemExit(f"bit{args.bit}: {len(missed)} lane counters did not hit both directions")

    after_bits = gap.toggle_bits(args.after)
    bit_status = {}
    for bit in range(args.bit, 32):
        rows = [row for row in after_bits.values()
                if ".u_dpd" in row["instance"] and row["signal"] == f"sample_count[{bit}]"]
        if len(rows) != 16 or len({row["instance"] for row in rows}) != 16:
            raise SystemExit(f"Expected 16 post-merge lane rows for sample_count[{bit}]; got {len(rows)}")
        both = sum(row["one_to_zero"] == "Yes" and row["zero_to_one"] == "Yes" for row in rows)
        neither = sum(row["one_to_zero"] == "No" and row["zero_to_one"] == "No" for row in rows)
        bit_status[str(bit)] = {
            "instances": len(rows),
            "both_directions": both,
            "neither_direction": neither,
            "unhit_directions": sum(row["one_to_zero"] == "No" for row in rows)
                                 + sum(row["zero_to_one"] == "No" for row in rows),
        }

    args.out.mkdir(parents=True, exist_ok=False)
    with (args.out / "toggle_bit_delta.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(delta[0]))
        writer.writeheader()
        writer.writerows(delta)
    coverage = gap.frozen.parse_dut_code_coverage(args.after / "hierarchy.html")
    summary = {
        "status": "PASS",
        "fifo": args.fifo,
        "counter_bit": args.bit,
        "counter_instances": len(instances),
        "counter_directions": "both directions observed by natural full stream plus public reset",
        "sample_count_bit_status": bit_status,
        "remaining_unhit_sample_count_directions_bits_22_to_31": sum(
            row["unhit_directions"] for row in bit_status.values()),
        "raw_dut_hierarchy_coverage": coverage,
        "total_dpd_toggle_delta_rows": sum(".u_dpd" in row["instance"] for row in delta),
        "remaining_dpd_toggle_delta_rows": sum(".u_dpd" in row["instance"] and row["status"] != "HIT_BOTH_DIRECTIONS" for row in delta),
        "before_report": str(args.before),
        "after_report": str(args.after),
        "delta_csv": str(args.out / "toggle_bit_delta.csv"),
    }
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
