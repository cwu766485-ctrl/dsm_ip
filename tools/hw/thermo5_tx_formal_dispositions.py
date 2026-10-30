#!/usr/bin/env python3.12
"""Apply exact, source-bound VC Formal reachability dispositions to TX bins.

This utility changes only the audit ledger's review status. It never edits URG
data, the raw denominator, or an exclusion file.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def read_csv(path: Path, compressed: bool = False) -> tuple[list[str], list[dict[str, str]]]:
    opener = gzip.open if compressed else open
    with opener(path, "rt", newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames:
            fail(f"missing CSV header: {path}")
        return list(reader.fieldnames), list(reader)


def write_gzip_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("wb") as binary:
        with gzip.GzipFile(filename="", mode="wb", fileobj=binary, mtime=0) as compressed:
            import io

            text = io.TextIOWrapper(compressed, encoding="utf-8", newline="")
            writer = csv.DictWriter(text, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            text.flush()
            text.detach()


def verify_review(review: dict) -> list[dict]:
    if review.get("disposition") != "PROVEN_UNREACHABLE":
        fail("only explicit PROVEN_UNREACHABLE dispositions are accepted")
    dispositions = review.get("bins")
    if not isinstance(dispositions, list) or not dispositions:
        fail("review must contain a non-empty bins array")
    seen: set[str] = set()
    for item in dispositions:
        bin_id = item.get("semantic_bin_id", "")
        if not bin_id or bin_id in seen:
            fail(f"missing or duplicate semantic_bin_id: {bin_id}")
        seen.add(bin_id)
        proof_dir = (ROOT / item["formal_run"]).resolve()
        if not proof_dir.is_relative_to(ROOT.resolve()):
            fail(f"formal run escapes repository: {proof_dir}")
        properties_path = proof_dir / item.get("properties_file", "properties.txt")
        setup_path = proof_dir / item.get("setup_file", "setup.txt")
        console_path = proof_dir / item.get("console_file", "console.log")
        for path, key in ((properties_path, "properties_sha256"),
                          (setup_path, "setup_sha256"),
                          (console_path, "console_sha256")):
            if not path.is_file() or sha256(path) != item.get(key):
                fail(f"missing or stale formal evidence: {path}")
        properties = properties_path.read_text(encoding="utf-8", errors="replace")
        escaped_assert = re.escape(item["assertion"])
        escaped_cover = re.escape(item["cover"])
        if not re.search(r"\bproven\b.*" + escaped_assert + r"\s*$", properties, re.M):
            fail(f"assertion is not proven: {item['assertion']}")
        if not re.search(r"\buncoverable\b.*" + escaped_cover + r"\s*$", properties, re.M):
            fail(f"cover is not formally uncoverable: {item['cover']}")
        setup = setup_path.read_text(encoding="utf-8", errors="replace")
        if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
            fail(f"Formal setup violations are present: {setup_path}")
        console = console_path.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
            fail(f"zero-black-box evidence is absent: {console_path}")
        assumptions = item.get("assumptions", [])
        observed_assumptions = re.findall(r"^\s*\[\s*\d+\]\s+constrained\s+\(non_vacuous\).*?-\s+(\S*\.asm_\S+)\s*$", properties, re.M)
        if set(observed_assumptions) != set(assumptions):
            fail(f"{bin_id}: formal assumptions are missing, vacuous, or not reviewed")
        source_hashes = item.get("source_sha256")
        if not isinstance(source_hashes, dict) or not source_hashes:
            fail(f"missing source hashes for {bin_id}")
        for relative, expected in source_hashes.items():
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
                fail(f"formal source path missing or escapes repository: {relative}")
            if sha256(path) != expected:
                fail(f"formal source changed since proof: {relative}")
        item["status"] = "PROVEN_UNREACHABLE"
        item["evidence_sha256"] = {
            "properties": sha256(properties_path),
            "setup": sha256(setup_path),
            "console": sha256(console_path),
        }
    return dispositions


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--tasks", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--closure-report", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    args = parser.parse_args()
    ledger_fields, ledger_rows = read_csv(args.ledger, compressed=True)
    task_fields, tasks = read_csv(args.tasks)
    summary = json.loads(args.summary.read_text(encoding="utf-8"))
    review = json.loads(args.review.read_text(encoding="utf-8"))
    if review.get("product_source_sha") != summary.get("source_product_sha"):
        fail("Formal review and source-ledger product SHAs differ")
    dispositions = verify_review(review)
    by_id = {row["semantic_bin_id"]: row for row in ledger_rows}
    if len(by_id) != len(ledger_rows):
        fail("semantic Bin IDs are not unique in the ledger")
    for item in dispositions:
        bin_id = item["semantic_bin_id"]
        row = by_id.get(bin_id)
        if row is None:
            fail(f"Formal Bin ID is absent from raw ledger: {bin_id}")
        for field in ("configuration", "instance", "metric", "bin", "source_position"):
            if row.get(field) != item.get(field):
                fail(f"{bin_id}: exact {field} mismatch ({row.get(field)!r} != {item.get(field)!r})")
        source_file = item["source_file"]
        expected_sha = item["source_sha256"].get(source_file)
        if not expected_sha:
            fail(f"{bin_id}: Formal evidence does not hash the DUT source file")
        ledger_source_hashes = dict(
            part.split("=", 1) for part in row["source_file_sha256"].split(";") if "=" in part
        )
        if ledger_source_hashes.get(source_file) != expected_sha:
            fail(f"{bin_id}: source file SHA differs from the raw-ledger source")
        row["closure_status"] = "PROVEN_UNREACHABLE"
        row["status"] = "PROVEN_UNREACHABLE"
        row["reason"] = "Exact product-configuration Formal assertion proven and matching Cover reported uncoverable; Raw bin retained."
        row["evidence_hint"] = item["assertion"] + "; " + item["cover"]
        row["root_cause_hypothesis"] = "Formal proves this exact raw bin unreachable under the recorded product parameter ties."
        row["next_action"] = "Retain the bin in Raw; no exclusion is approved by this disposition."

    for task in tasks:
        ids = set(filter(None, task["semantic_bin_ids"].split(";")))
        closed = ids and all(by_id[bin_id]["closure_status"] == "PROVEN_UNREACHABLE" for bin_id in ids)
        task["current_status"] = "PROVEN_UNREACHABLE" if closed else "OPEN"
        if closed:
            task["status_note"] = "Exact source bin proven unreachable under product configuration; Raw denominator retained; no waiver."
    if "current_status" not in task_fields:
        insert_at = task_fields.index("initial_status") + 1
        task_fields.insert(insert_at, "current_status")
    with args.tasks.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=task_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(tasks)
    write_gzip_csv(args.ledger, ledger_fields, ledger_rows)

    import collections

    counts = collections.Counter(row["closure_status"] for row in ledger_rows)
    summary["closure_status_counts"] = dict(sorted(counts.items()))
    summary["all_rows_have_allowed_status"] = all(
        row["closure_status"] in {"HIT", "PROVEN_UNREACHABLE", "WAIVER_CANDIDATE", "OPEN"}
        for row in ledger_rows
    )
    formal_map = summary.setdefault("formal_dispositions", {})
    for item in dispositions:
        formal_map[item["semantic_bin_id"]] = {
            "status": "PROVEN_UNREACHABLE",
            "formal_run": item["formal_run"],
            "assertion": item["assertion"],
            "cover": item["cover"],
            "source_sha256": item["source_sha256"],
            "evidence_sha256": item["evidence_sha256"],
            "assumptions": item.get("assumptions", []),
        }
    summary["approved_waivers"] = 0
    summary["exclusions_applied"] = 0
    summary["interpretation"] = (
        f"{counts.get('PROVEN_UNREACHABLE', 0)} exact bins are Formal-proven unreachable; "
        f"{counts.get('OPEN', 0)} code gaps remain OPEN. Raw URG bins and denominators are unchanged; "
        "no waiver or exclusion is applied."
    )
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    manifest["followup"] = {
        **manifest.get("followup", {}),
        "formal_review_json": str(args.review.resolve().relative_to(ROOT)),
        "formal_review_sha256": sha256(args.review),
        "formal_status": "PASS_FOR_EXACT_REACHABILITY_DISPOSITIONS; DPD_IDENTITY_OPEN",
        "proven_unreachable_bin_count": counts.get("PROVEN_UNREACHABLE", 0),
        "raw_coverage_edited": False,
        "product_urg_refreshed": False,
        "approved_waivers": 0,
        "exclusions_applied": 0,
    }
    output_hashes = manifest.setdefault("output_sha256", {})
    for path in (args.ledger, args.tasks, args.summary, args.closure_report):
        output_hashes[path.name] = sha256(path)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"ledger_rows": len(ledger_rows), "closure_status_counts": dict(counts),
                      "raw_coverage_edited": False, "exclusions_applied": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
