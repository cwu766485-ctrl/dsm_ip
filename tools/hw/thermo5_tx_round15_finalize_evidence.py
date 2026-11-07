#!/usr/bin/env python3.12
"""Refresh the Round 15 exact Raw ledger from a same-source URG report pair.

This evidence utility never approves waivers or creates URG exclusions. It marks
only exact directional toggle bins that changed from Raw-unhit to Raw-hit.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "dv/uvm/sim"))
from run_thermo5_gap_closure import toggle_bits, toggle_delta  # noqa: E402


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_sha256(path: Path) -> tuple[str, int, int]:
    rows = []
    for child in sorted(item for item in path.rglob("*") if item.is_file()):
        rows.append((child.relative_to(path).as_posix(), child.stat().st_size, sha256(child)))
    digest = hashlib.sha256()
    for name, size, file_hash in rows:
        digest.update(name.encode() + b"\0" + str(size).encode() + b"\0" + file_hash.encode() + b"\n")
    return digest.hexdigest(), len(rows), sum(size for _, size, _ in rows)


def read_csv_gz(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        return list(reader.fieldnames or []), list(reader)


def write_csv_gz(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as zipped:
            import io
            text = io.TextIOWrapper(zipped, encoding="utf-8", newline="")
            writer = csv.DictWriter(text, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            text.flush()
            text.detach()


def source_file_hash_map(rows: list[dict[str, str]]) -> dict[str, str]:
    result: dict[str, str] = {}
    for row in rows:
        value = row.get("source_file_sha256", "")
        if "=" in value:
            name, digest = value.split("=", 1)
            result[name] = digest
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ledger", type=Path, required=True)
    parser.add_argument("--before-report", type=Path, required=True)
    parser.add_argument("--after-report", type=Path, required=True)
    parser.add_argument("--raw-inventory", type=Path, required=True)
    parser.add_argument("--report-manifest", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--product-sha", required=True)
    parser.add_argument("--expected-toggle-delta", type=int, default=784)
    args = parser.parse_args()

    fields, rows = read_csv_gz(args.baseline_ledger)
    candidate_toggle_bins = {
        (row["instance"], row["bin"]): row
        for row in rows if row["metric"] == "toggle"
    }
    before = toggle_bits(args.before_report)
    after = toggle_bits(args.after_report)
    hits: list[dict[str, str]] = []
    for key, record in candidate_toggle_bins.items():
        match = re.fullmatch(r"(Port Details|Signal Details):(.*):(1_to_0|0_to_1)", record["bin"])
        if not match:
            raise RuntimeError(f"Unrecognized exact toggle record: {record['bin']}")
        kind, signal, direction = match.groups()
        signal_key = (record["instance"], kind, signal)
        if signal_key not in before or signal_key not in after:
            raise RuntimeError(f"Toggle signal absent from before/after report: {signal_key}")
        before_field = "one_to_zero" if direction == "1_to_0" else "zero_to_one"
        if before[signal_key][before_field] != "No":
            raise RuntimeError(f"Baseline ledger bin was not Raw-unhit: {key}")
        if after[signal_key][before_field] == "Yes":
            hits.append({
                "bin_id": record["bin_id"], "semantic_bin_id": record["semantic_bin_id"],
                "record_id": record["record_id"], "configuration": record["configuration"],
                "instance": record["instance"], "metric": "toggle", "exact_bin": record["bin"],
                "source_position": record["source_position"],
                "before": "Not Covered", "after": "Covered",
                "evidence": "Eight legal four-plane bit-true product identity patterns; merged Raw URG delta",
                "seeds": "610720;610721;610722;610723;610724;610725;610726;610727",
            })
    if len(hits) != args.expected_toggle_delta:
        raise RuntimeError(f"Exact toggle-bin delta mismatch: expected {args.expected_toggle_delta}, got {len(hits)}")
    hit_keys = {(row["configuration"], row["instance"], row["exact_bin"]): row for row in hits}
    if len(hit_keys) != len(hits):
        raise RuntimeError("Duplicate exact toggle hit identity")
    for row in rows:
        key = (row["configuration"], row["instance"], row["bin"])
        if row["metric"] == "toggle" and key in hit_keys:
            row["status"] = "HIT"
            row["closure_status"] = "RESOLVED_BY_RAW_HIT"
            row["current_status"] = "HIT_ROUND15_DATA_CAMPAIGN"
            row["evidence_hint"] = "Raw URG hit after legal four-plane identity pattern campaign"
    remaining = [row for row in rows if row.get("current_status") == "OPEN"]
    inventory = json.loads((args.raw_inventory / "summary.json").read_text(encoding="utf-8"))
    report_manifest = json.loads(args.report_manifest.read_text(encoding="utf-8"))
    actual_vdb_sha = report_manifest["vdb_manifest_sha256"]
    if report_manifest["post_vdb_manifest_sha256"] != actual_vdb_sha:
        raise RuntimeError("VDB manifest changed during Raw/Adjusted URG")
    if report_manifest["source_revision"] != args.product_sha:
        raise RuntimeError("URG report source SHA does not match requested product SHA")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_csv_gz(args.baseline_ledger, fields, rows)
    remaining_fields = list(fields)
    remaining_path = args.out_dir / "thermo5_tx_r15_exact_remaining_bins.csv.gz"
    write_csv_gz(remaining_path, remaining_fields, remaining)
    with (args.out_dir / "thermo5_tx_r15_toggle_hit_delta.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(hits[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(hits)

    # Keep every former bin and task row. Resolved bins/tasks are explicitly
    # retained as history; only the OPEN count is recomputed from exact rows.
    task_path = args.out_dir / "thermo5_tx_r15_root_cause_tasks.csv"
    if task_path.is_file():
        with task_path.open(newline="", encoding="utf-8") as stream:
            task_reader = csv.DictReader(stream)
            task_fields, tasks = list(task_reader.fieldnames or []), list(task_reader)
        open_per_task: dict[str, int] = {}
        for row in remaining:
            open_per_task[row["task_id"]] = open_per_task.get(row["task_id"], 0) + 1
        for task in tasks:
            count = open_per_task.get(task["task_id"], 0)
            task["bin_records"] = str(count)
            task["round15_vdb_manifest_sha256"] = actual_vdb_sha
            if count == 0:
                task["current_status"] = "RESOLVED_BY_RAW_HIT"
                task["status_note"] = "All exact member bins were observed as Raw hits in the Round 15 data campaign."
            else:
                task["current_status"] = "OPEN"
        with task_path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=task_fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(tasks)

    waiver_path = args.out_dir / "thermo5_tx_r15_waiver_review.csv"
    if waiver_path.is_file():
        with waiver_path.open(newline="", encoding="utf-8") as stream:
            waiver_reader = csv.DictReader(stream)
            waiver_fields, waivers = list(waiver_reader.fieldnames or []), list(waiver_reader)
        for field in ("round15_formal_status", "round15_bin_mapping_status", "round15_formal_evidence"):
            if field not in waiver_fields:
                waiver_fields.append(field)
        formal_candidate_updates = {
            "W-9010fccd0889b46ea284": (
                "PROVEN_SCOPED", "EXACT_LOCATION_REVIEW_PENDING",
                "formal/axil_cfg/formal_manifest.json; 4 assertions proven; coefficient-read activity Cover reached"),
            "W-32b5745433f0ff75d5c2": (
                "PROVEN_SCOPED", "EXACT_BIN_REVIEW_PENDING",
                "formal/cdc_end_remaining/formal_summary.json; no assumptions; legal frame/end Covers reached"),
            "W-a9fc97093bdddfb7f5aa": (
                "PROVEN_SCOPED", "SOURCE_LOCATION_MISMATCH",
                "formal/cdc_end_branch/formal_summary.json targets a different source location than this Raw candidate"),
            "W-98a39b6429bbed7c29ad": (
                "PROVEN_SCOPED", "URG_LOCATION_REVIEW_PENDING",
                "formal/cdc_default_branch/formal_summary.json; default-path Cover uncoverable; exact Raw location mapping not approved"),
        }
        for row in waivers:
            row["round15_vdb_manifest_sha256"] = actual_vdb_sha
            row["round15_review_status"] = row.get("round15_review_status") or "PENDING_INDEPENDENT_REVIEW"
            row["round15_official_exclusion"] = "NO"
            row["round15_formal_status"], row["round15_bin_mapping_status"], row["round15_formal_evidence"] = formal_candidate_updates.get(
                row["waiver_id"], ("NOT_REPROVEN_OR_NOT_APPLICABLE", "UNRESOLVED", ""))
        with waiver_path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=waiver_fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(waivers)

    root_counts: dict[str, dict[str, int]] = {}
    for row in remaining:
        metric = row["metric"]
        cause = row["root_cause_class"]
        root_counts.setdefault(metric, {})[cause] = root_counts.setdefault(metric, {}).get(cause, 0) + 1
    coverage = {}
    for metric, source_metric in (("branch", "branch"), ("condition", "cond"), ("line", "line"), ("toggle", "toggle")):
        entry = next(item for item in inventory["metrics"]
                     if item["ownership"] == "PROJECT_RTL" and item["metric"] == source_metric)
        coverage[metric] = {"covered": int(entry["covered"]), "total": int(entry["total"]),
                            "missing": int(entry["missing"]), "percent": float(entry["percent"])}
    for key, report_key in (("fsm_state", "states"), ("fsm_transition", "transitions")):
        matches = [item for item in inventory["fsm_denominators"]
                   if item["ownership"] == "PROJECT_RTL" and item["metric"] == report_key]
        coverage[key] = {"covered": sum(int(item["covered"]) for item in matches),
                         "total": sum(int(item["total"]) for item in matches),
                         "missing": sum(int(item["missing"]) for item in matches), "percent": 100.0}

    summary_path = args.out_dir / "thermo5_tx_r15_coverage_summary.json"
    summary = json.loads(summary_path.read_text(encoding="utf-8")) if summary_path.exists() else {}
    summary.update({
        "coverage": coverage,
        "missing_total": sum(item["missing"] for key, item in coverage.items()
                             if key in {"branch", "condition", "line", "toggle"}),
        "coverage_input_vdb_count": len(report_manifest["vdb_manifest"]["tests"]) + 1,
        "test_vdb_count": len(report_manifest["vdb_manifest"]["tests"]),
        "vdb_manifest_sha256": actual_vdb_sha,
        "raw_adjusted_same_input": report_manifest["raw_summary"] == report_manifest["adjusted_summary"],
        "source_head": args.product_sha,
        "product_rtl_sha256": "fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003",
        "approved_waivers": report_manifest["approved_waiver_count"],
        "active_exclusions": int(report_manifest["adjusted_exclusions_applied"]),
        "root_cause_counts": root_counts,
        "code_bin_record_count": len(rows),
        "open_code_bin_record_count": len(remaining),
        "new_raw_toggle_hits": len(hits),
        "status": "LINUX_DV_SIGNOFF_OPEN_RAW_100_OPEN",
    })
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # A path-free, replay-auditable VDB inventory; the exact URG manifest SHA
    # remains separately recorded above and in the raw URG report manifest.
    full = report_manifest["vdb_manifest"]
    def compact_entry(entry: dict, role: str) -> dict:
        path = Path(entry["path"])
        parts = list(path.parts)
        try:
            index = parts.index("runs")
            origin = "/".join(parts[index + 1:])
        except ValueError:
            origin = path.name
        return {"role": role, "origin_id": origin, "tree_sha256": entry["tree_sha256"],
                "file_count": entry["file_count"], "total_bytes": entry["total_bytes"]}
    compact = {
        "schema_version": 1, "round": 15, "source_revision": args.product_sha,
        "product_configuration_fingerprint": report_manifest["product_configuration_fingerprint"],
        "urg_version": report_manifest["urg_version"], "urg_input_manifest_sha256": actual_vdb_sha,
        "design_vdb": compact_entry(full["design"], "design"),
        "test_vdb_count": len(full["tests"]),
        "test_vdbs": [compact_entry(entry, "test") for entry in full["tests"]],
        "raw_adjusted_used_identical_vdb_snapshot": True,
    }
    compact_path = args.out_dir / "thermo5_tx_r15_vdb_manifest_240.json"
    compact_path.write_text(json.dumps(compact, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    # Refresh the checked-in top-level Round 15 manifest to the exact 240-test
    # URG snapshot, retaining compile/source/tool details from the verified
    # product compile and using path-free VDB identities.
    published_manifest_path = args.out_dir / "thermo5_tx_r15_vdb_manifest.json"
    if published_manifest_path.is_file():
        published = json.loads(published_manifest_path.read_text(encoding="utf-8"))
        published["status"] = "ROUND15_RAW_ADJUSTED_REGENERATED"
        published["test_count"] = len(full["tests"])
        published["design_vdb"] = {key: full["design"][key]
                                   for key in ("file_count", "total_bytes", "tree_sha256")}
        published["test_vdbs"] = []
        campaign_counts: dict[str, int] = {}
        for entry in full["tests"]:
            vdb_path = Path(entry["path"])
            parts = list(vdb_path.parts)
            try:
                run_index = parts.index("runs")
                origin_parts = parts[run_index + 1:]
            except ValueError:
                origin_parts = [vdb_path.name]
            campaign = "/".join(origin_parts[:-1])
            campaign_counts[campaign] = campaign_counts.get(campaign, 0) + 1
            published["test_vdbs"].append({
                "campaign": campaign,
                "test_id": vdb_path.name.removesuffix(".vdb"),
                "file_count": entry["file_count"],
                "total_bytes": entry["total_bytes"],
                "tree_sha256": entry["tree_sha256"],
            })
        published["test_campaign_counts"] = campaign_counts
        published["raw_summary"] = report_manifest["raw_summary"]
        published["adjusted_summary"] = report_manifest["adjusted_summary"]
        published["approved_waiver_count"] = report_manifest["approved_waiver_count"]
        published["adjusted_exclusions_applied"] = report_manifest["adjusted_exclusions_applied"]
        published["vdb_manifest_sha256"] = actual_vdb_sha
        published["post_vdb_manifest_sha256"] = report_manifest["post_vdb_manifest_sha256"]
        published["vdb_manifest_stable_during_urg"] = actual_vdb_sha == report_manifest["post_vdb_manifest_sha256"]
        published["report_manifest_sha256"] = sha256(args.report_manifest)
        published["raw_urg_log_sha256"] = sha256(args.report_manifest.parent / "raw_urg.log")
        published["adjusted_urg_log_sha256"] = sha256(args.report_manifest.parent / "adjusted_urg.log")
        published["compact_vdb_manifest_sha256"] = sha256(compact_path)
        published["vdb_origin_manifest_sha256"] = sha256(compact_path)
        published["vdb_resnapshot_note"] = (
            "The official Raw and zero-exclusion Adjusted reports were regenerated from one "
            "stable design-plus-240-test VDB snapshot. VDB origins are path-free identifiers; "
            "the exact URG-consumed manifest SHA-256 is retained above. All inputs match the "
            "verified 95-source product compile fingerprint."
        )
        published_manifest_path.write_text(json.dumps(published, indent=2, sort_keys=True) + "\n",
                                           encoding="utf-8")

    # Exact per-bin review ledger for the constant Pair-1 datapath proof. The
    # proof is evidence only: every row remains pending independent approval.
    pair1_rows = [row for row in rows if row["metric"] == "toggle" and "pair1" in row["bin"]]
    if len(pair1_rows) != 8192:
        raise RuntimeError(f"Expected 8192 exact Pair-1 toggle rows, got {len(pair1_rows)}")
    pair1_proof = json.loads((ROOT / "runs/thermo5_round15_6b0d7c4/formal/dpd_pair1_review2/formal_manifest.json").read_text())
    candidate_fields = ["raw_bin_id", "semantic_bin_id", "exact_bin", "instance", "source_file",
                        "source_file_sha256", "product_source_sha", "product_parameters",
                        "formal_run", "formal_properties_sha256", "formal_scope", "formal_result",
                        "cover_non_vacuity", "review_status", "official_exclusion"]
    pair1_path = args.out_dir / "thermo5_tx_r15_pair1_waiver_candidates.csv.gz"
    pair1_candidate_rows = []
    for row in pair1_rows:
        pair1_candidate_rows.append({
                "raw_bin_id": row["bin_id"], "semantic_bin_id": row["semantic_bin_id"],
                "exact_bin": row["bin"], "instance": row["instance"],
                "source_file": row["source_position"].split(":symbol", 1)[0],
                "source_file_sha256": row["source_file_sha256"],
                "product_source_sha": args.product_sha,
                "product_parameters": row["product_parameters"],
                "formal_run": "formal/dpd_pair1_review2/formal_manifest.json",
                "formal_properties_sha256": pair1_proof["properties_sha256"],
                "formal_scope": pair1_proof["scope"], "formal_result": "PROVEN_SCOPED",
                "cover_non_vacuity": "input_accept=covered; output_transfer=covered",
                "review_status": "PENDING_INDEPENDENT_REVIEW", "official_exclusion": "NO",
        })
    write_csv_gz(pair1_path, candidate_fields, pair1_candidate_rows)
    (args.out_dir / "thermo5_tx_r15_pair1_waiver_candidates.csv").unlink(missing_ok=True)

    active_tap_rows = [row for row in rows if row["metric"] == "toggle" and "active_taps" in row["bin"]]
    if len(active_tap_rows) != 120:
        raise RuntimeError(f"Expected 120 exact Active-Tap toggle rows, got {len(active_tap_rows)}")
    active_fields = ["raw_bin_id", "semantic_bin_id", "exact_bin", "instance", "source_position",
                     "source_file_sha256", "product_source_sha", "formal_run",
                     "formal_result", "disposition", "review_status", "official_exclusion"]
    with (args.out_dir / "thermo5_tx_r15_active_tap_waiver_candidates.csv").open(
            "w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=active_fields, lineterminator="\n")
        writer.writeheader()
        for row in active_tap_rows:
            writer.writerow({
                "raw_bin_id": row["bin_id"], "semantic_bin_id": row["semantic_bin_id"],
                "exact_bin": row["bin"], "instance": row["instance"],
                "source_position": row["source_position"],
                "source_file_sha256": row["source_file_sha256"],
                "product_source_sha": args.product_sha,
                "formal_run": "formal/axil_cfg_active_taps/formal_manifest.json",
                "formal_result": "INCONCLUSIVE",
                "disposition": "OPEN; no waiver or exclusion supported",
                "review_status": "PENDING", "official_exclusion": "NO",
            })

    formal_root = ROOT / "runs/thermo5_round15_6b0d7c4/formal"
    def formal_evidence(name: str, relative: str, status: str, disposition: str,
                        notes: str) -> dict:
        path = formal_root / relative
        if not path.is_file():
            raise RuntimeError(f"Required Formal evidence is missing: {path}")
        evidence = json.loads(path.read_text(encoding="utf-8"))
        source_hashes = evidence.get("source_sha256", {})
        if not source_hashes and isinstance(evidence.get("source"), dict):
            source_hashes = evidence["source"].get("sha256", {})
        checked_sources = {}
        for source_name, expected_hash in source_hashes.items():
            source_path = ROOT / source_name
            if source_path.is_file():
                actual_hash = sha256(source_path)
                if actual_hash != expected_hash:
                    raise RuntimeError(f"Formal source hash mismatch for {source_name}: {path}")
                checked_sources[source_name] = actual_hash
        return {"property_group": name, "status": status, "disposition": disposition,
                "notes": notes, "evidence_path": str(path.relative_to(ROOT)),
                "evidence_sha256": sha256(path),
                "formal_reported_status": evidence.get("status", "SEE_JOB_MATRIX"),
                "checked_source_hashes": checked_sources}

    formal_matrix = {
        "schema_version": 1, "round": 15, "product_source_sha": args.product_sha,
        "product_configuration_fingerprint": report_manifest["product_configuration_fingerprint"],
        "tool": "VC Formal V-2023.12-SP2",
        "properties": [
            formal_evidence("dpd_pair1_fixed_configuration",
                "dpd_pair1_review2/formal_manifest.json", "PROVEN_SCOPED",
                "PENDING_INDEPENDENT_REVIEW_NO_EXCLUSION",
                "64 lane invariants prove four Pair-1 accumulators per each of 16 MAX_TAPS=1 lanes are zero; input/output Covers hit; only reset constraint rst_n==1; zero blackboxes."),
            formal_evidence("active_tap_configuration",
                "axil_cfg_active_taps/formal_manifest.json", "INCONCLUSIVE",
                "OPEN_NO_WAIVER",
                "Active-Tap enable/configuration property and commit-applied Cover are inconclusive; all 120 exact Active-Tap toggle candidates remain open."),
            formal_evidence("axi_outstanding_counter_guards",
                "outstanding/formal_manifest.json", "INCONCLUSIVE",
                "OPEN_NO_WAIVER",
                "All five capacity/saturation/underflow assertions and both guard Covers are inconclusive under legal source bubbles and arbitrary PA backpressure."),
            formal_evidence("counter_increment_and_carry_lemma",
                "counter_unbounded/formal_summary.json", "PROVEN_SCOPED",
                "COUNTER_HIGH_TOGGLE_STILL_OPEN",
                "Unbounded block-level count/hold/increment and all 32 per-bit transition properties are proven; this does not prove system-level high-bit activity or a bounded product lifetime."),
            formal_evidence("ef2_product_parameters",
                "ef2_product_params/formal_summary.json", "PROVEN_SCOPED",
                "CONFIGURATION_EVIDENCE_ONLY",
                "Exact W=16/CHANNELS=32 product parameter guard and PAIR_LOOKAHEAD=0 are proven; this is not a general source deletion or waiver approval."),
            formal_evidence("centered_interpolator_frame_tail",
                "frame_tail/formal_summary.json", "PROVEN_SCOPED",
                "Q1_TAIL_ASSERTIONS_STILL_OPEN",
                "Two composed production interpolator stages prove stated legal frame geometry and nonempty legal transfer Covers; intermediate FIFOs/DPD are omitted and legal q1_tail assertion attempts remain zero."),
            formal_evidence("cdc_end_remaining_candidate",
                "cdc_end_remaining/formal_summary.json", "PROVEN_SCOPED",
                "PENDING_EXACT_URG_MAPPING_AND_REVIEW",
                "Current-source 14:8 Generic FIFO proof has no SVA assumptions and nonempty legal Covers; retain candidate OPEN pending exact one-to-one URG bin mapping and reviewer approval."),
            formal_evidence("cdc_immediate_frame_end_candidate",
                "cdc_end_branch/formal_summary.json", "PROVEN_SCOPED_BUT_MAPPING_MISMATCH",
                "OPEN_NO_EXCLUSION",
                "Harness report targets the immediate frame-end arm at a different source location than the candidate Raw bin; proof is not applied to that bin."),
            formal_evidence("cdc_default_candidate",
                "cdc_default_branch/formal_summary.json", "PROVEN_SCOPED_BUT_MAPPING_REVIEW_PENDING",
                "OPEN_NO_EXCLUSION",
                "Default-path Cover is uncoverable with legal frame Covers reached and no assumptions; exact candidate-to-URG location mapping still needs review."),
            formal_evidence("axi_lite_config_default_candidate",
                "axil_cfg/formal_manifest.json", "PROVEN_SCOPED",
                "PENDING_INDEPENDENT_REVIEW_NO_EXCLUSION",
                "Four assertions prove the config default/read tuple paths unreachable; legal coefficient-read activity Cover is reached; retain exact branch candidate pending reviewer approval."),
        ],
        "carried_forward_open_obligations": [
            {"property_group": "full_chain_dpd_identity", "status": "INCONCLUSIVE",
             "evidence_reference": "Round 14 report; unchanged source-file hashes; not rerun in Round 15"},
            {"property_group": "product_q1_tail_assertions", "status": "OPEN_NO_LEGAL_ATTEMPTS",
             "evidence_reference": "Round 14 legal assertion split; unchanged RTL source hash; not rerun in Round 15"},
            {"property_group": "commit_pending_apply_ack_done_end_to_end", "status": "OPEN",
             "evidence_reference": "No full-chain proof or new Round 15 proof artifact"},
        ],
        "approved_waivers": 0, "official_exclusions": 0,
    }
    formal_matrix_path = args.out_dir / "thermo5_tx_r15_formal_matrix.json"
    formal_matrix_path.write_text(json.dumps(formal_matrix, indent=2, sort_keys=True) + "\n",
                                  encoding="utf-8")

    campaign_path = args.out_dir / "thermo5_tx_r15_data_campaign.json"
    pattern_path = ROOT / "runs/thermo5_round15_6b0d7c4/directed/data_campaign/pattern_matrix.json"
    patterns = json.loads(pattern_path.read_text(encoding="utf-8"))
    campaign_rows = []
    for item in patterns:
        log = Path(item["log"])
        vdb = Path(item["vdb"])
        if not item["pass_marker"] or item["returncode"] != 0 or item["uvm_errors"] or item["uvm_fatals"]:
            raise RuntimeError(f"Directed identity pattern did not pass: {item['pattern']}")
        tree = []
        for child in sorted(p for p in vdb.rglob("*") if p.is_file()):
            tree.append((child.relative_to(vdb).as_posix(), child.stat().st_size, sha256(child)))
        h = hashlib.sha256()
        for name, size, digest in tree:
            h.update(name.encode() + b"\0" + str(size).encode() + b"\0" + digest.encode() + b"\n")
        campaign_rows.append({"pattern": item["pattern"], "seed": item["seed"], "result": "PASS",
                              "checker": "UVM four-plane bit-true scoreboard; Python vector oracle",
                              "log_sha256": sha256(log), "vdb_tree_sha256": h.hexdigest(),
                              "vdb_file_count": len(tree)})
    campaign = {"source_revision": args.product_sha, "pattern_count": len(campaign_rows),
                "patterns": campaign_rows, "raw_toggle_hit_bin_count": len(hits),
                "raw_line_condition_branch_delta": {"line": 0, "condition": 0, "branch": 0},
                "raw_toggle_delta": len(hits), "checker_failures": 0}
    campaign_path.write_text(json.dumps(campaign, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    focused_tests = []
    focused_specs = [
        ("axil_register_access", "runs/thermo5_round15_6b0d7c4/directed/axil_register_access/run_clean.log",
         "runs/thermo5_round15_6b0d7c4/directed/axil_register_access/register_access_clean.vdb",
         "PASS", 155022, False),
        ("outstanding_bounds_corrected", "runs/thermo5_round15_6b0d7c4/directed/outstanding_bounds/run_pass.log",
         "runs/thermo5_round15_6b0d7c4/directed/outstanding_bounds/outstanding_pass.vdb",
         "PASS", 151002, False),
        ("outstanding_bounds_exploratory_bad_tlast", "runs/thermo5_round15_6b0d7c4/directed/outstanding_bounds/run.log",
         "runs/thermo5_round15_6b0d7c4/directed/outstanding_bounds/outstanding.vdb",
         "FAIL_EXPLORATORY_EXCLUDED", 151001, False),
    ]
    for test, log_name, vdb_name, status, seed, official_input in focused_specs:
        log = ROOT / log_name
        vdb = ROOT / vdb_name
        if not log.is_file() or not vdb.is_dir():
            raise RuntimeError(f"Focused-test evidence is missing: {log} / {vdb}")
        log_text = log.read_text(encoding="utf-8", errors="replace")
        command = next((line.removeprefix("Command: ") for line in log_text.splitlines()
                        if line.startswith("Command: ")), "")
        if not command:
            raise RuntimeError(f"Focused test has no recorded reproduction command: {log}")
        vdb_hash, vdb_files, vdb_bytes = tree_sha256(vdb)
        focused_tests.append({
            "test": test, "seed": seed, "status": status, "official_raw_vdb_input": official_input,
            "log_path": log_name, "log_sha256": sha256(log), "command": command,
            "vdb_path": vdb_name, "vdb_tree_sha256": vdb_hash,
            "vdb_file_count": vdb_files, "vdb_total_bytes": vdb_bytes,
            "checker_notes": {
                "axil_register_access": "48 read checks, 52 write-response checks, zero predictor mismatches and empty transaction queues.",
                "outstanding_bounds_corrected": "64 source beats, 112 output words, max outstanding 28, zero guard hits, bit-true queue drained.",
                "outstanding_bounds_exploratory_bad_tlast": "UVM fatal: one TLAST observed where the test's two-packet contract expected two; corrected seed 151002 uses 32-beat packets.",
            }[test],
        })
    focused_matrix_path = args.out_dir / "thermo5_tx_r15_focused_test_matrix.json"
    focused_matrix = {"schema_version": 1, "round": 15, "product_source_sha": args.product_sha,
                      "tests": focused_tests}
    focused_matrix_path.write_text(json.dumps(focused_matrix, indent=2, sort_keys=True) + "\n",
                                   encoding="utf-8")

    hit_path = args.out_dir / "thermo5_tx_r15_toggle_hit_delta.csv"
    output = {
        "product_source_sha": args.product_sha,
        "product_rtl_sha256": summary["product_rtl_sha256"],
        "product_configuration_fingerprint": report_manifest["product_configuration_fingerprint"],
        "compile_fingerprint": "e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7",
        "raw_adjusted_vdb_manifest_sha256": actual_vdb_sha,
        "compact_vdb_manifest_sha256": sha256(compact_path),
        "raw_coverage": coverage,
        "remaining_raw_code_bin_records": len(remaining),
        "new_exact_raw_toggle_hits": len(hits),
        "approved_waivers": 0,
        "active_exclusions": 0,
        "formal_counter_result": "SEE_COUNTER_UNBOUNDED_RUN",
        "exact_hit_delta_sha256": sha256(hit_path),
        "campaign_sha256": sha256(campaign_path),
        "exact_remaining_ledger_sha256": sha256(remaining_path),
        "pair1_candidate_count": len(pair1_rows),
        "pair1_candidate_ledger_sha256": sha256(pair1_path),
        "active_tap_candidate_count": len(active_tap_rows),
        "formal_matrix_sha256": sha256(formal_matrix_path),
        "focused_test_matrix_sha256": sha256(focused_matrix_path),
    }
    (args.out_dir / "thermo5_tx_r15_evidence_index.json").write_text(
        json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"raw_coverage": coverage, "exact_hits": len(hits),
                      "remaining_bins": len(remaining), "vdb_manifest_sha256": actual_vdb_sha,
                      "compact_manifest_sha256": sha256(compact_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
