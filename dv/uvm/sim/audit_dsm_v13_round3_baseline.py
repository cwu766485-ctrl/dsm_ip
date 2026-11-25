#!/usr/bin/env python3
"""Freeze and cluster every Round 2 OPEN record without changing its status."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path
import re
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_INPUT = ROOT / "docs" / "verification" / "data" / "dsm-v13-round2"
DEFAULT_OUTPUT = ROOT / "docs" / "verification" / "data" / "dsm-v13-round3"
INPUT_TABLE = "coverage_hole_matrix.csv"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def module_from_location(location: str) -> str:
    if not location:
        return ""
    return re.sub(r":(?:\d+|signal)(?:\D.*)?$", "", location)


def row_signature(row: dict[str, str]) -> tuple[str, ...]:
    return tuple(row.get(name, "").strip() for name in
                 ("coverage_type", "source_location", "rtl_expression", "uncovered_bin"))


def load(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    source = args.input_dir.resolve() / INPUT_TABLE
    output = args.output_dir.resolve()
    rows = load(source)
    opened = [row for row in rows if row.get("round2_disposition") == "OPEN"]
    if len(opened) != 2887:
        print("ROUND3_BASELINE_AUDIT_INVALID=open record count %d, expected 2887" % len(opened))
        return 2

    by_signature: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in opened:
        by_signature[row_signature(row)].append(row)

    clusters: list[dict[str, str]] = []
    records: list[dict[str, str]] = []
    type_counts = Counter(row.get("coverage_type", "") for row in opened)
    module_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    sku_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    for ordinal, (signature, members) in enumerate(sorted(by_signature.items()), 1):
        cluster_id = "R2C%04d" % ordinal
        sample = members[0]
        module = module_from_location(sample.get("source_location", ""))
        configs = sorted({member.get("configuration", "") for member in members})
        skus = sorted({member.get("sku", "") for member in members})
        candidate = ("PENDING_INDEPENDENT_REVIEW" if
                     sample.get("coverage_id") == "transaction_event_cg" and
                     sample.get("coverage_type") == "FUNCTIONAL_GROUP_BINS" and
                     "axil_" in sample.get("uncovered_bin", "") else "UNASSESSED")
        clusters.append({
            "cluster_id": cluster_id,
            "coverage_type": signature[0],
            "module": module,
            "source_location": signature[1],
            "rtl_expression": signature[2],
            "uncovered_bin": signature[3],
            "record_count": str(len(members)),
            "configuration_count": str(len(configs)),
            "configurations": "|".join(configs),
            "skus": "|".join(skus),
            "applicability_review": candidate,
            "disposition": "OPEN",
        })
        module_rows[module or "NON_RTL"] += members
        for member in members:
            sku_rows[member.get("configuration", "")].append(member)
            records.append({**member, "module": module, "cluster_id": cluster_id,
                "cluster_record_count": str(len(members)),
                "duplicate_configuration_record": str(len(members) > 1).lower(),
                "applicability_review": candidate,
                "round3_status": "OPEN_BASELINE_PRESERVED"})

    code_rows = [r for r in opened if r.get("coverage_type") in
                 {"Line", "Branch", "Condition", "Toggle", "FSM_Transitions"}]
    code_signatures = {row_signature(row) for row in code_rows}
    output.mkdir(parents=True, exist_ok=True)
    with (output / "round2_open_record_audit.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(records[0].keys()))
        writer.writeheader()
        writer.writerows(records)
    with (output / "round2_open_clusters.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(clusters[0].keys()))
        writer.writeheader()
        writer.writerows(clusters)

    module_summary = [{"module": name, "open_record_count": len(items),
                       "unique_signature_count": len({row_signature(x) for x in items}),
                       "record_types": dict(Counter(x.get("coverage_type", "") for x in items))}
                      for name, items in sorted(module_rows.items())]
    sku_summary = [{"configuration": name, "open_record_count": len(items),
                    "type_counts": dict(Counter(x.get("coverage_type", "") for x in items))}
                   for name, items in sorted(sku_rows.items())]
    summary = {
        "schema": "dsm_v13_round3_round2_baseline_audit_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_file": str(source.relative_to(ROOT)),
        "source_sha256": digest(source),
        "open_record_count": len(opened),
        "unique_exact_signatures": len(by_signature),
        "code_record_count": len(code_rows),
        "unique_code_signatures": len(code_signatures),
        "repeated_signature_rows": len(opened) - len(by_signature),
        "type_counts": dict(type_counts),
        "module_summary": module_summary,
        "configuration_summary": sku_summary,
        "applicability_policy": "Raw Round 2 denominators and all 2,887 OPEN dispositions are preserved. Product-only AXI-Lite transaction-bin exclusions are proposals only; no denominator adjustment or waiver is approved.",
        "generated_files": {
            "round2_open_record_audit.csv": digest(output / "round2_open_record_audit.csv"),
            "round2_open_clusters.csv": digest(output / "round2_open_clusters.csv"),
        },
    }
    (output / "round2_baseline_audit.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("ROUND3_BASELINE_AUDIT_PASS open=%d code=%d code_signatures=%d all_signatures=%d" %
          (len(opened), len(code_rows), len(code_signatures), len(by_signature)))
    print("ROUND3_BASELINE_AUDIT_OUTPUT=%s" % output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
