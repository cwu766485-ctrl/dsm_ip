#!/usr/bin/env python3
"""Join the Round 1 OPEN condition ledger to an exact current URG report.

This audit is fail-closed: every selected raw/semantic bin must be present as
Not Covered in the supplied Raw URG HTML. It does not edit the source ledger or
apply waivers.
"""

from __future__ import annotations

import argparse
import csv
import gzip
from collections import Counter
from pathlib import Path

from thermo5_audit_reports import condition_rows


FIELDS = [
    "task_id", "record_id", "raw_bin_id", "semantic_bin_id", "root_cause_class",
    "instance", "source_position", "source_location", "condition_class",
    "condition_operands", "urg_expression", "before_status", "after_status",
    "current_urg_status", "coverage_before", "coverage_after", "coverage_delta",
    "directed_test", "checker_evidence", "formal_status", "review_note",
]


def audit(gap_ledger: Path, task_csv: Path, raw_urg: Path) -> list[dict[str, str]]:
    with gzip.open(gap_ledger, "rt", newline="", encoding="utf-8") as stream:
        gaps = list(csv.DictReader(stream))
    with task_csv.open(newline="", encoding="utf-8") as stream:
        tasks = list(csv.DictReader(stream))
    open_tasks = {
        row["task_id"] for row in tasks
        if row["metric"] == "cond" and row["current_status"] == "OPEN"
    }
    target = [row for row in gaps if row["metric"] == "cond" and row["task_id"] in open_tasks]
    rows, _, _, _ = condition_rows(raw_urg)

    def expression_class(value: str) -> str:
        return "subexpression" if value.startswith("SUB-EXPRESSION") else "expression"

    missing_bins = Counter(
        (row["instance"], row["line"], row["operand_bin"], expression_class(row["expression"]))
        for row in rows if row["status"] == "Not Covered"
    )
    output: list[dict[str, str]] = []
    for row in target:
        line = row["bin"].split(":", 1)[0]
        key = (row["instance"], line, row["condition_operands"], row["condition_class"])
        if not missing_bins[key]:
            raise SystemExit(f"OPEN bin is not an exact current URG miss: {row['semantic_bin_id']} {key}")
        missing_bins[key] -= 1
        root = row["root_cause_class"]
        directed = (
            "thermo5_sku_axil_outstanding_bounds_test seed=610902"
            if root == "INTERPOLATOR_EMPTY_OR_BLOCKED"
            else "thermo5_sku_axil_outstanding_bounds_test seed=610902; reset-release/backpressure sequence"
        )
        output.append({
            "task_id": row["task_id"],
            "record_id": row["record_id"],
            "raw_bin_id": row["bin_id"],
            "semantic_bin_id": row["semantic_bin_id"],
            "root_cause_class": root,
            "instance": row["instance"],
            "source_position": row["source_position"],
            "source_location": row["source_location"],
            "condition_class": row["condition_class"],
            "condition_operands": row["condition_operands"],
            "urg_expression": row["urg_expression"],
            "before_status": "OPEN",
            "after_status": "OPEN",
            "current_urg_status": "Not Covered",
            "coverage_before": "610/849",
            "coverage_after": "610/849",
            "coverage_delta": "0",
            "directed_test": directed,
            "checker_evidence": "PASS; bit-true 112-word drain and public-interface stall/recovery checked; no exact condition bin hit",
            "formal_status": "NOT_RUN_FOR_THIS_EXACT_BIN",
            "review_note": "Keep OPEN. Directed legal traffic is evidence of exercised scenario, not a substitute for the exact URG operand bin.",
        })
    if len(open_tasks) != 71 or len(output) != 131:
        raise SystemExit(f"Unexpected Round 1 condition scope: tasks={len(open_tasks)} bins={len(output)}")
    if Counter(row["root_cause_class"] for row in output) != {
        "RESET_RELEASE_OR_STATE_HOLD": 127,
        "INTERPOLATOR_EMPTY_OR_BLOCKED": 4,
    }:
        raise SystemExit("Unexpected condition root-cause distribution")
    return output


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gap-ledger", type=Path, required=True)
    parser.add_argument("--task-csv", type=Path, required=True)
    parser.add_argument("--raw-urg", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = audit(args.gap_ledger, args.task_csv, args.raw_urg)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"condition audit PASS: tasks=71 bins={len(rows)} exact current URG misses")


if __name__ == "__main__":
    main()
