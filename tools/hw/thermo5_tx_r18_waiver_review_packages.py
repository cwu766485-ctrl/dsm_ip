#!/usr/bin/env python3.12
"""Build review-only Round 18 exact-bin exclusion packets.

This utility preserves official Waiver state. It emits grouped candidate
ledgers and exact residual counter/control inventories from recorded Round 18
URG evidence; every candidate remains pending independent review.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/hw"))
import thermo5_tx_r17_residual_whatif as residual


def read_gzip(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_csv(path: Path, rows: list[dict[str, str]], compressed: bool = True) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if compressed:
        residual.write_gzip_csv(path, rows)
    else:
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)


def sha(path: Path) -> str:
    return residual.sha256_file(path)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--execution-candidates", type=Path, default=ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_candidate_exclusion_execution.csv.gz")
    ap.add_argument("--extended-candidates", type=Path, default=ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_fixed_config_candidates_extended_553_vdb.csv.gz")
    ap.add_argument("--official-reconciliation", type=Path, default=ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_official_waiver_reconciliation.csv")
    ap.add_argument("--compile-manifest", type=Path, default=ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json")
    ap.add_argument("--repair-ledger", type=Path, required=True)
    ap.add_argument("--counter-delta", type=Path, required=True)
    ap.add_argument("--remaining-ledger", type=Path, required=True)
    ap.add_argument("--baseline-ledger", type=Path, default=ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_post_directed_whatif_remaining_bins.csv.gz")
    ap.add_argument("--urg-manifest", type=Path, required=True)
    args = ap.parse_args()

    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    old = read_gzip(args.execution_candidates)
    extended = read_gzip(args.extended_candidates)
    repaired = read_gzip(args.repair_ledger)
    delta = read_gzip(args.counter_delta)
    remaining = read_gzip(args.remaining_ledger)
    official = list(csv.DictReader(args.official_reconciliation.open(encoding="utf-8", newline="")))
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    urg = json.loads(args.urg_manifest.read_text(encoding="utf-8"))

    if len(old) != 8970 or len(extended) != 2448 or len(repaired) != 13 or len(official) != 371:
        raise RuntimeError("Round 17/18 waiver input cardinality mismatch")
    if len({r["semantic_bin_id"] for r in old + extended}) != 11418:
        raise RuntimeError("Candidate semantic IDs overlap or are duplicated")
    if len({r["waiver_id"] for r in official}) != 371:
        raise RuntimeError("Official Waiver IDs are not unique")
    if len(remaining) != 1257:
        raise RuntimeError("Expected the actual 1,257-bin 554-Test/11,418-candidate What-if residual")
    if len(delta) != 430:
        raise RuntimeError("Expected 430 exact Raw Toggle hits from the 553-to-554 VDB comparison")

    official_by_semantic: dict[str, list[str]] = {}
    for waiver in official:
        sem = waiver.get("round17_candidate_semantic_id", "")
        if sem:
            official_by_semantic.setdefault(sem, []).append(waiver["waiver_id"])
    repair_by_semantic = {r["semantic_bin_id"]: r for r in repaired}
    compile_hashes = compile_manifest["source_file_sha256"]
    groups: dict[str, list[dict[str, str]]] = {}
    for raw, origin in [(r, "R17_CORE") for r in old] + [(r, "R17_EF2_ACTIVE_TAP") for r in extended]:
        row = dict(raw)
        group = row.get("analysis_group", "")
        if origin == "R17_EF2_ACTIVE_TAP":
            batch = row.get("candidate_batch", "")
            group = {"EF2_PAIR_LOOKAHEAD_ZERO": "F_R17_EF2_PAIR_QONE",
                     "DPD_ACTIVE_TAPS_MAX1": "G_R17_DPD_ACTIVE_TAPS"}.get(batch, "UNASSIGNED")
        rel = row["source_file"]
        src = ROOT / rel
        expected_sha = compile_hashes.get(rel)
        if (not expected_sha or expected_sha != row.get("source_file_sha256") or
                not src.is_file() or sha(src) != expected_sha or
                row.get("product_source_sha") != compile_manifest.get("product_source_sha")):
            raise RuntimeError(f"Candidate source binding mismatch: {row['semantic_bin_id']}")
        if row.get("semantic_bin_id") in repair_by_semantic:
            fix = repair_by_semantic[row["semantic_bin_id"]]
            row.update({"native_mapping_status": fix["native_mapping_status"],
                        "native_directive": fix["native_directive"],
                        "native_signature": fix["native_signature"],
                        "mapping_repair_method": fix["mapping_repair_method"],
                        "round18_native_mapping_status": "MAPPED_EXACT_NATIVE_BIN"})
        else:
            row["round18_native_mapping_status"] = row.get("native_mapping_status", "")
            row["mapping_repair_method"] = ""
        if origin == "R17_CORE":
            previous = row.get("analysis_execution_status", "")
            row["round18_analysis_application"] = (
                "EXCLUDED_R18_STRICT_URG_REPAIRED_NATIVE_EXACT" if row["semantic_bin_id"] in repair_by_semantic
                else "EXCLUDED_R18_STRICT_URG" if previous.startswith("EXCLUDED_") else "OPEN_MAPPING_NOT_EXCLUDED")
        else:
            row["round18_analysis_application"] = "EXCLUDED_R18_STRICT_URG"
        row["candidate_source_set"] = origin
        row["review_status"] = "PENDING_INDEPENDENT_REVIEW"
        row["reviewer"] = ""
        row["approval_reference"] = ""
        row["official_exclusion_active"] = "NO"
        row["linked_official_waiver_ids"] = ";".join(official_by_semantic.get(row["semantic_bin_id"], []))
        row["official_approval_status"] = "NOT_APPROVED"
        groups.setdefault(group, []).append(row)

    expected_groups = {"A_DPD_PAIR1": 8192, "B_EF2_FIXED_PARAMETERS": 436,
                       "C_DPD_TAP_HISTORY": 176, "D_CDC_RESIDUAL": 137,
                       "E_OTHER_PARAMETERS": 29, "F_R17_EF2_PAIR_QONE": 2328,
                       "G_R17_DPD_ACTIVE_TAPS": 120}
    if {group: len(rows) for group, rows in groups.items()} != expected_groups:
        raise RuntimeError(f"Unexpected root-cause package distribution: { {g:len(r) for g,r in groups.items()} }")

    index = []
    package_dir = out / "waiver_groups"
    for group, rows in sorted(groups.items()):
        filename = f"{group.lower()}_review.csv.gz"
        write_csv(package_dir / filename, rows)
        index.append({"root_cause_group": group, "candidate_count": str(len(rows)),
                      "native_metric_counts": json.dumps({m: sum(r["metric"] == m for r in rows)
                                                          for m in ("branch", "cond", "line", "toggle")}, sort_keys=True),
                      "round18_exact_application_count": str(sum(r["round18_analysis_application"].startswith("EXCLUDED_R18") for r in rows)),
                      "review_status": "PENDING_INDEPENDENT_REVIEW",
                      "approved_count": "0", "approval_reference": "",
                      "package": f"waiver_groups/{filename}"})
    write_csv(out / "waiver_review_package_index.csv", index, compressed=False)
    write_csv(out / "official_waiver_reconciliation_371.csv", official, compressed=False)

    control = []
    for row in remaining:
        if row["metric"] == "toggle":
            continue
        old_class = row.get("review_class", "UNKNOWN")
        classify = {"STATIC_UNREACHABLE": "STRUCTURALLY_UNREACHABLE",
                    "CONFIG_UNREACHABLE": "CONFIG_UNREACHABLE",
                    "DEFENSIVE_NEGATIVE_ONLY": "DEFENSIVE_NEGATIVE",
                    "REACHABLE_UNTESTED": "LEGAL_REACHABLE",
                    "TOOL_OR_MAPPING_ISSUE": "TOOL_MAPPING_ISSUE"}.get(old_class, "UNKNOWN")
        control.append({**row, "round18_reachability_class": classify,
                        "round18_targeted_test_result": "NO_NEW_BRANCH_CONDITION_LINE_HITS",
                        "round18_status": "OPEN"})
    if len(control) != 115:
        raise RuntimeError(f"Expected 115 residual control bins after exact mapping repair, got {len(control)}")
    write_csv(out / "exact_remaining_control_bins_115.csv.gz", control)

    counter_targets = []
    target_rows = [r for r in read_gzip(args.baseline_ledger)
                   if r["metric"] == "toggle" and r["exact_urg_bin"].startswith(("Port Details:sample_count[", "Port Details:saturation_count["))]
    delta_by_id = {r["semantic_bin_id"]: r for r in delta if r.get("semantic_bin_id")}
    for row in target_rows:
        fam = "sample_count" if "sample_count" in row["exact_urg_bin"] else "saturation_count"
        changed = delta_by_id.get(row["semantic_bin_id"])
        counter_targets.append({**row,
                               "counter_family": fam,
                               "round18_result": "HIT" if changed else "OPEN",
                               "round18_direction": changed["direction"] if changed else row["exact_urg_bin"].rsplit(":", 1)[-1],
                               "round18_test_seed": "180018" if changed else "",
                               "review_status": "IN_SCOPE_OPEN_NO_SCOPE_WAIVER"})
    targets_by_family = {fam: [r for r in counter_targets if r["counter_family"] == fam]
                         for fam in ("sample_count", "saturation_count")}
    expected_targets = {"sample_count": (576, 80), "saturation_count": (848, 350)}
    for fam, (expected_total, expected_hits) in expected_targets.items():
        actual_hits = sum(r["round18_result"] == "HIT" for r in targets_by_family[fam])
        if len(targets_by_family[fam]) != expected_total or actual_hits != expected_hits:
            raise RuntimeError(f"{fam} exact-bin target/delta mismatch: {len(targets_by_family[fam])}, {actual_hits}")
    write_csv(out / "counter_high_bit_exact_results_1424.csv.gz", counter_targets)

    other_toggles = [r for r in remaining if r["metric"] == "toggle" and
                     r.get("root_cause_class") == "DATA_VALUE_OR_TOGGLE_STIMULUS"]
    write_csv(out / "other_toggle_remaining_148.csv.gz", other_toggles)
    if len(other_toggles) != 148:
        raise RuntimeError(f"Expected 148 other Toggle bins, got {len(other_toggles)}")

    official_status = {}
    for row in official:
        official_status[row["round17_reconciliation_status"]] = official_status.get(row["round17_reconciliation_status"], 0) + 1
    summary = {
        "schema": "thermo5_tx_r18_review_packages_v1",
        "product_source_sha": compile_manifest["product_source_sha"],
        "product_rtl_aggregate_sha256": compile_manifest["product_rtl_aggregate_sha256"],
        "compile_fingerprint_sha256": compile_manifest["compile_fingerprint_sha256"],
        "candidate_count": 11418,
        "strict_analysis_only_excluded_count": 11418,
        "approved_count": 0,
        "official_waiver_count": 371,
        "official_waiver_status_counts": official_status,
        "official_raw_hit_preserved_count": official_status.get("RESOLVED_BY_RAW_HIT", 0),
        "reviewer_decision": "PENDING_INDEPENDENT_REVIEW",
        "whatif_urg_metrics": urg["run_results"]["test_vdbs_554/analysis_whatif_11418"]["metrics"],
        "remaining_exact_bin_count": len(remaining),
        "remaining_control_count": len(control),
        "remaining_other_toggle_count": len(other_toggles),
        "counter_target_results": {fam: {"target": len(rows), "hit": sum(r["round18_result"] == "HIT" for r in rows),
                                          "remaining": sum(r["round18_result"] == "OPEN" for r in rows)}
                                   for fam, rows in targets_by_family.items()},
        "files": {},
    }
    for path in sorted(p for p in out.rglob("*") if p.is_file()):
        summary["files"][path.relative_to(out).as_posix()] = {"sha256": sha(path), "bytes": path.stat().st_size}
    (out / "review_package_manifest.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"out_dir": str(out), "groups": {g: len(r) for g, r in groups.items()},
                      "official_waivers": official_status,
                      "counter_targets": summary["counter_target_results"],
                      "controls_remaining": len(control), "other_toggles_remaining": len(other_toggles)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
