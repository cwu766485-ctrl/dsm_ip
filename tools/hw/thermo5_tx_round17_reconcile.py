#!/usr/bin/env python3.12
"""Reconcile Round 17 waiver IDs and priority exact-bin ledgers.

This is a read-only audit over the official waiver CSV and the preserved
Round 15/16 evidence.  It never approves a waiver, edits the official CSV, or
generates an URG exclusion.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
from collections import Counter
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.hw.thermo5_tx_waiver_pipeline import _configuration_fingerprint


OFFICIAL = "docs/verification/thermo5_tx_waivers.csv"
R15_AUDIT = "docs/verification/data/thermo5-r15/thermo5_tx_r15_waiver_review.csv"
R16_REVIEW = "docs/verification/data/thermo5-r16/thermo5_tx_r16_waiver_review.csv"
R16_GAPS = "docs/verification/data/thermo5-r16/thermo5_tx_r16_exact_remaining_bins.csv.gz"
R16_BRANCHES = "docs/verification/data/thermo5-r16/thermo5_tx_r16_branch_rootcause_review.csv"
RAW_HITS = "docs/verification/data/thermo5-r12/thermo5-tx-waivers-resolved-by-raw-hit.csv"
R16_SOURCE = "docs/verification/data/thermo5-r16/thermo5_tx_r16_source_manifest.json"
R16_SUMMARY = "docs/verification/data/thermo5-r16/thermo5_tx_r16_coverage_summary.json"
R16_FORMAL = "docs/verification/data/thermo5-r16/thermo5_tx_r16_formal_matrix.json"
R17_COMPILE = "docs/verification/data/thermo5-r17/thermo5_tx_r17_historical_compile_manifest.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def rows(path: Path) -> list[dict[str, str]]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def line_of_gap(row: dict[str, str]) -> str:
    position = row.get("source_position", "")
    if ":" in position:
        tail = position.rsplit(":", 1)[1]
        if tail.isdigit():
            return tail
    return row.get("branch_target_line", "")


def source_hashes(value: str) -> dict[str, str]:
    result = {}
    for item in value.split(";"):
        if "=" in item:
            name, digest = item.rsplit("=", 1)
            result[name] = digest
    return result


def audit(out_dir: Path) -> dict:
    inputs = {name: ROOT / name for name in (
        OFFICIAL, R15_AUDIT, R16_REVIEW, R16_GAPS, R16_BRANCHES,
        RAW_HITS, R16_SOURCE, R16_SUMMARY, R16_FORMAL, R17_COMPILE,
    )}
    for path in inputs.values():
        if not path.is_file():
            raise ValueError(f"required evidence is missing: {path.relative_to(ROOT)}")

    official = rows(inputs[OFFICIAL])
    r15 = rows(inputs[R15_AUDIT])
    review = rows(inputs[R16_REVIEW])
    gaps = rows(inputs[R16_GAPS])
    branches = rows(inputs[R16_BRANCHES])
    hit_archive = rows(inputs[RAW_HITS])
    source = json.loads(inputs[R16_SOURCE].read_text(encoding="utf-8"))
    summary = json.loads(inputs[R16_SUMMARY].read_text(encoding="utf-8"))
    formal = json.loads(inputs[R16_FORMAL].read_text(encoding="utf-8"))
    compile_manifest = json.loads(inputs[R17_COMPILE].read_text(encoding="utf-8"))

    official_by_id = {row["waiver_id"]: row for row in official}
    review_by_id = {row["waiver_id"]: row for row in review}
    hit_by_id = {row["waiver_id"]: row for row in hit_archive}
    if len(official_by_id) != len(official):
        raise ValueError("official waiver CSV contains duplicate IDs")
    if len(review_by_id) != len(review):
        raise ValueError("Round 16 clean candidate review contains duplicate IDs")
    if len(hit_by_id) != len(hit_archive):
        raise ValueError("Raw-hit archive contains duplicate IDs")

    audit_rows: list[dict[str, str]] = []
    for original in official:
        waiver_id = original["waiver_id"]
        candidate = review_by_id.get(waiver_id)
        prior_hit = hit_by_id.get(waiver_id)
        gap_matches = [gap for gap in gaps
                       if gap["configuration"] == original["configuration"]
                       and gap["instance"] == original["instance"]
                       and original["source_file"] in gap["source_files"].split(";")
                       and line_of_gap(gap) == original["source_line"]
                       and gap["metric"] == {"condition": "cond"}.get(
                           original["metric"].lower(), original["metric"].lower())
                       and gap["bin_id"] == original["bin"]]

        record = dict(original)
        record.update({
            "r17_disposition": "",
            "round16_candidate_classification": "",
            "round16_candidate_disposition": "",
            "round16_raw_bin_status": "",
            "round16_gap_match_count": str(len(gap_matches)),
            "round16_source_sha_match": "NO",
            "historical_raw_hit_status": "NONE",
            "r15_refresh_row_count": str(sum(x["waiver_id"] == waiver_id for x in r15)),
            "note": "",
        })

        if candidate is not None:
            if len(gap_matches) != 1:
                raise ValueError(f"{waiver_id} candidate maps to {len(gap_matches)} Round 16 Raw gaps")
            gap = gap_matches[0]
            expected_sha = source_hashes(gap["source_file_sha256"]).get(original["source_file"])
            if (candidate["configuration"] != original["configuration"]
                    or candidate["instance"] != original["instance"]
                    or candidate["source_file"] != original["source_file"]
                    or candidate["source_line"] != original["source_line"]
                    or candidate["metric"].lower() != original["metric"].lower()
                    or candidate["raw_bin_id"] != original["bin"]):
                raise ValueError(f"{waiver_id} candidate metadata differs from official CSV")
            source_match = bool(expected_sha and expected_sha == original["source_sha256"]
                                and candidate["source_sha256"] == expected_sha)
            if not source_match:
                raise ValueError(f"{waiver_id} source SHA differs from the Round 16 gap ledger")
            record["r17_disposition"] = "PENDING_CANDIDATE"
            record["round16_candidate_classification"] = candidate["classification"]
            record["round16_candidate_disposition"] = candidate["candidate_disposition"]
            record["round16_raw_bin_status"] = candidate["raw_bin_status"]
            record["round16_source_sha_match"] = "YES"
            record["note"] = "Exact Raw gap and source SHA match; no reviewer approval and no exclusion."
            if original["review_status"] != "PENDING":
                raise ValueError(f"{waiver_id} official review state is not PENDING")
        else:
            if len(gap_matches) != 0 or prior_hit is None:
                raise ValueError(f"{waiver_id} is neither a current gap candidate nor an archived Raw HIT")
            hit_matches = all(prior_hit.get(field) == original.get(field) for field in (
                "configuration", "instance", "source_file", "source_line", "metric", "bin",
                "source_sha256"))
            if (not hit_matches or prior_hit.get("current_raw_status") != "HIT"
                    or int(prior_hit.get("missing", "-1")) != 0):
                raise ValueError(f"{waiver_id} Raw-hit archive does not exactly match the official row")
            record["r17_disposition"] = "RESOLVED_BY_RAW_HIT"
            record["round16_source_sha_match"] = "YES"
            record["historical_raw_hit_status"] = (
                f"HIT {prior_hit.get('covered')}/{prior_hit.get('total')}; "
                f"missing={prior_hit.get('missing')}"
            )
            record["note"] = (
                "Raw HIT recorded in the Round 12 Raw URG archive; exact bin is absent "
                "from the Round 16 open ledger. Remove from active waiver scope; no exclusion."
            )
            if original["review_status"] != "PENDING":
                raise ValueError(f"{waiver_id} official Raw-hit row is not pending before reconciliation")
        audit_rows.append(record)

    official_ids = set(official_by_id)
    review_ids = set(review_by_id)
    if official_ids - review_ids != set(hit_by_id):
        raise ValueError("official vs clean candidate/Raw-hit ID difference is not exactly the archived HIT set")
    if review_ids - official_ids:
        raise ValueError("Round 16 candidate review contains IDs absent from official waiver CSV")
    if len(official) != 371 or len(review) != 369 or len(hit_archive) != 2:
        raise ValueError("unexpected Round 17 reconciliation cardinality")

    old_counts = Counter(row["waiver_id"] for row in r15)
    old_unique = set(old_counts)
    duplicate_ids = sorted(item for item, count in old_counts.items() if count > 1)
    missing_old_ids = sorted(official_ids - old_unique)

    # Keep the full exact-bin identifiers for all remaining Branch/Condition
    # records while joining current candidate disposition where one exists.
    branch_review_by_id = {row["bin_id"]: row for row in branches}
    candidate_by_bin = {row["raw_bin_id"]: row for row in review}
    priority_rows: list[dict[str, str]] = []
    for gap in gaps:
        if gap["metric"] not in {"branch", "cond"}:
            continue
        candidate = candidate_by_bin.get(gap["bin_id"])
        branch = branch_review_by_id.get(gap["bin_id"], {}) if gap["metric"] == "branch" else {}
        source_line = line_of_gap(gap)
        if gap["metric"] == "branch":
            if (gap["source_files"] == "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
                    and source_line.isdigit() and 135 <= int(source_line) <= 191):
                branch_bucket = "PAIR_LOOKAHEAD_HELPER_CANDIDATE"
            elif (gap["source_files"] == "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
                    and source_line in {"96", "231"}):
                branch_bucket = "FIXED_PARAMETER_CANDIDATE"
            else:
                branch_bucket = "OPEN_EXACT_BRANCH"
        else:
            branch_bucket = "CONDITION_ROOT_CAUSE_REVIEW"
        record = {
            "record_id": gap.get("record_id", ""),
            "semantic_bin_id": gap.get("semantic_bin_id", ""),
            "bin_id": gap["bin_id"],
            "configuration": gap["configuration"],
            "instance": gap["instance"],
            "source_files": gap["source_files"],
            "source_position": gap.get("source_position", ""),
            "metric": gap["metric"],
            "branch_closure_bucket": branch_bucket,
            "branch_decision_path": gap.get("branch_decision_path", ""),
            "branch_predicate_path": gap.get("branch_predicate_path", ""),
            "condition_class": gap.get("condition_class", ""),
            "condition_operands": gap.get("condition_operands", ""),
            "root_cause_class": gap.get("root_cause_class", ""),
            "r16_exact_status": gap.get("current_status", gap.get("status", "OPEN")),
            "candidate_classification": candidate.get("classification", "") if candidate else "",
            "candidate_disposition": candidate.get("candidate_disposition", "") if candidate else "",
            "round16_review_state": branch.get("review_status", "") if branch else "",
            "round16_coverage_delta": branch.get("coverage_delta", "") if branch else "",
            "next_action": branch.get("next_action", gap.get("next_action", "")) if branch else gap.get("next_action", ""),
            "r17_test_or_proof_result": "NOT_RUN_IN_ROUND17",
            "r17_disposition": "OPEN",
        }
        priority_rows.append(record)

    out_dir.mkdir(parents=True, exist_ok=True)
    reconciliation_path = out_dir / "thermo5_tx_r17_waiver_reconciliation.csv"
    with reconciliation_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(audit_rows[0]))
        writer.writeheader()
        writer.writerows(audit_rows)
    priority_path = out_dir / "thermo5_tx_r17_branch_condition_ledger.csv"
    with priority_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(priority_rows[0]))
        writer.writeheader()
        writer.writerows(priority_rows)

    unresolved = Counter(row["metric"] for row in gaps)
    priority_counts = Counter((row["metric"], row["root_cause_class"]) for row in priority_rows)
    priority_buckets = Counter(row["branch_closure_bucket"] for row in priority_rows)
    old_candidate_audit_refs = Counter(row.get("candidate_audit", "") for row in official)
    old_candidate_audit_shas = Counter(row.get("candidate_audit_sha256", "") for row in official)
    raw_hits = [row for row in audit_rows if row["r17_disposition"] == "RESOLVED_BY_RAW_HIT"]
    candidates = [row for row in audit_rows if row["r17_disposition"] == "PENDING_CANDIDATE"]
    evidence = {
        "schema": "thermo5_tx_round17_waiver_reconciliation",
        "status": "RECONCILED_DATA_ONLY_PIPELINE_NOT_REGENERATED",
        "source_head": source.get("base_commit"),
        "product_rtl_sha256": source.get("product_rtl_aggregate_sha256"),
        "legacy_compile_fingerprint_sha256": source.get("compile_fingerprint_sha256"),
        "round16_coverage": summary["coverage"],
        "round16_formal": {
            "pair1": formal["pair1"],
            "ef2_product_parameters": formal["ef2_product_parameters"],
            "axi_outstanding_counter": formal["axi_outstanding_counter"],
            "dpd_identity_full_chain": formal["dpd_identity_full_chain"],
            "commit_lifecycle": formal["commit_lifecycle"],
            "q1_tail": formal["q1_tail"],
        },
        "waiver_counts": {
            "official_rows": len(official),
            "official_unique_ids": len(official_by_id),
            "clean_round16_candidates": len(review),
            "candidate_classes": dict(Counter(row["classification"] for row in review)),
            "resolved_by_raw_hit": len(raw_hits),
            "pending_candidate_rows": len(candidates),
            "pending_approved": sum(row["review_status"] == "APPROVED" for row in candidates),
            "active_exclusions": 0,
        },
        "raw_hit_bins": [{
            "waiver_id": row["waiver_id"], "bin": row["bin"], "metric": row["metric"],
            "source_file": row["source_file"], "source_line": row["source_line"],
            "instance": row["instance"], "source_sha256": row["source_sha256"],
            "raw_hit": row["historical_raw_hit_status"],
        } for row in raw_hits],
        "r15_refresh_defects": {
            "rows": len(r15), "unique_ids": len(old_unique),
            "duplicate_ids": duplicate_ids,
            "missing_official_ids": missing_old_ids,
            "candidate_audit_refs_in_official_csv": dict(old_candidate_audit_refs),
            "candidate_audit_shas_in_official_csv": dict(old_candidate_audit_shas),
            "interpretation": "Historical refresh CSV is preserved; Round 17 emits a normalized reconciliation artifact rather than rewriting historical evidence.",
        },
        "code_coverage_open": {
            "total_exact_bins": len(gaps),
            "by_metric": dict(unresolved),
            "branch_condition_root_causes": {
                f"{metric}:{cause}": count
                for (metric, cause), count in sorted(priority_counts.items())
            },
            "branch_condition_buckets": dict(priority_buckets),
        },
        "pipeline_binding": {
            "official_csv_sha256": sha256(inputs[OFFICIAL]),
            "r15_refresh_csv_sha256": sha256(inputs[R15_AUDIT]),
            "round16_clean_review_sha256": sha256(inputs[R16_REVIEW]),
            "round16_gap_ledger_sha256": sha256(inputs[R16_GAPS]),
            "round16_branch_review_sha256": sha256(inputs[R16_BRANCHES]),
            "raw_hit_archive_sha256": sha256(inputs[RAW_HITS]),
            "round16_source_manifest_sha256": sha256(inputs[R16_SOURCE]),
            "round16_coverage_summary_sha256": sha256(inputs[R16_SUMMARY]),
            "round16_formal_matrix_sha256": sha256(inputs[R16_FORMAL]),
            "round16_report_fingerprint": source.get("compile_fingerprint_sha256"),
            "round17_compile_manifest_fingerprint": _configuration_fingerprint(compile_manifest),
            "historical_compile_manifest_sha256": sha256(inputs[R17_COMPILE]),
            "fingerprint_match": source.get("compile_fingerprint_sha256") == _configuration_fingerprint(compile_manifest),
            "urg_rerun": "BLOCKED: installed VCS/URG reports unsupported WSL2 kernel; no Round 17 Raw/Adjusted report generated",
            "official_candidate_audit_generated": False,
            "approved_exclusions": 0,
        },
        "outputs": {
            "waiver_reconciliation_csv": reconciliation_path.relative_to(ROOT).as_posix(),
            "waiver_reconciliation_csv_sha256": sha256(reconciliation_path),
            "branch_condition_ledger_csv": priority_path.relative_to(ROOT).as_posix(),
            "branch_condition_ledger_csv_sha256": sha256(priority_path),
        },
        "input_sha256": {name: sha256(path) for name, path in inputs.items()},
    }
    json_path = out_dir / "thermo5_tx_r17_waiver_reconciliation.json"
    json_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return evidence


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = audit(args.out_dir.resolve())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        parser.exit(2, f"ROUND17_RECONCILIATION_ERROR: {exc}\n")
    print(json.dumps({
        "status": result["status"],
        "waivers": result["waiver_counts"],
        "open_code_bins": result["code_coverage_open"],
        "outputs": result["outputs"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
