#!/usr/bin/env python3
"""Validate Round 2 evidence structure and enforce a fail-closed closure gate."""

import argparse
import csv
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[3]
DATA = ROOT / "docs" / "verification" / "data" / "dsm-v13-round2"
REQUIRED_CSV = (
    "code_coverage.csv", "functional_coverage.csv", "cross_coverage.csv",
    "coverage_hole_matrix.csv", "assertion_coverage.csv",
)
REQUIRED_CONFIGS = {
    "ef1_product", "ef1_axil", "ef2_product", "ef2_axil",
    "mash11_product", "mash11_axil", "mash11_wrapper_core",
}


def load_csv(path):
    with path.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    if not rows:
        raise ValueError("empty CSV: " + str(path))
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("coverage", "closure"),
                        default="coverage")
    parser.add_argument("--data-dir", type=Path, default=DATA)
    args = parser.parse_args()
    data = args.data_dir.resolve()
    try:
        tables = {name: load_csv(data / name) for name in REQUIRED_CSV}
        summary = json.loads((data / "regression_summary.json").read_text(
            encoding="utf-8"))
        manifest = json.loads((data / "evidence_manifest.json").read_text(
            encoding="utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print("DSM_V13_COVERAGE_AUDIT_INVALID=%s" % error)
        return 2

    for name, rows in tables.items():
        for index, row in enumerate(rows, 2):
            if not row.get("sku") and not row.get("configuration"):
                print("DSM_V13_COVERAGE_AUDIT_INVALID=%s:%d missing SKU/configuration" %
                      (name, index))
                return 2
    config_results = summary.get("configuration_results", {})
    if set(config_results) != REQUIRED_CONFIGS:
        print("DSM_V13_COVERAGE_AUDIT_INVALID=regression summary configuration set mismatch")
        return 2
    if summary.get("fresh_urg_status") != "PASS" or summary.get("urg_merge_status") != "PASS":
        print("DSM_V13_COVERAGE_AUDIT_INVALID=fresh URG merge evidence is not PASS")
        return 2
    if manifest.get("evidence_scope") != "Round 2 working tree and generated reference vectors":
        print("DSM_V13_COVERAGE_AUDIT_INVALID=unexpected evidence manifest scope")
        return 2

    open_configs = [name for name, record in config_results.items()
                    if record.get("status") != "PASS"]
    open_holes = sum(1 for row in tables["coverage_hole_matrix.csv"]
                     if row.get("round2_disposition") == "OPEN")
    no_run_rows = sum(1 for row in tables["code_coverage.csv"] +
                      tables["functional_coverage.csv"] +
                      tables["cross_coverage.csv"]
                      if row.get("round2_status") == "NOT_RUN")
    print("DSM_V13_COVERAGE_AUDIT_VALIDATION_PASS csv=%d configs=%d manifest_files=%d" %
          (len(tables), len(config_results), len(manifest.get("files", []))))
    if args.mode == "coverage":
        print("DSM_V13_COVERAGE_AUDIT_STATUS=DATA_VALIDATION_ONLY")
        return 0

    blockers = []
    if open_configs:
        blockers.append("final regression open: " + ", ".join(sorted(open_configs)))
    if open_holes:
        blockers.append("%d OPEN coverage hole rows" % open_holes)
    if no_run_rows:
        blockers.append("%d Round 2 coverage metrics not run" % no_run_rows)
    if summary.get("coverage_status") != "PASS":
        blockers.append("fresh raw/adjusted URG coverage is not PASS")
    if summary.get("final_dv_signoff") is not True:
        blockers.append("final DV sign-off gate is not satisfied")
    if blockers:
        print("DSM_V13_CLOSURE_OPEN=" + "; ".join(blockers))
        return 2
    print("DSM_V13_CLOSURE_PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
