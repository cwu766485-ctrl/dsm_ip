#!/usr/bin/env python3.12
"""Build a source-bound Round 13 TX coverage closure audit package.

This utility only annotates the immutable Round 12 Raw/What-if inventories.
It never writes an URG exclusion file, changes the official waiver ledger, or
claims a Formal result.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import platform
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
R12 = ROOT / "docs/verification/data/thermo5-r12"
WHATIF = ROOT / "docs/verification/data/thermo5-r12-whatif-20261106"
ROUND12_REPORT = ROOT / "docs/verification/thermo5-tx-linux-final-closure-round12-20261106.md"
WHATIF_REPORT = ROOT / "docs/verification/thermo5-tx-round12-waiver-what-if-20261106.md"
FORMAL_ATTEMPT = ROOT / "runs/thermo5_r13_axil_cfg_reproof/formal_manifest.json"
FINAL_SIGNOFF = ROOT / "docs/verification/data/thermo5-r13/thermo5_tx_r13_final_coverage_manifest.json"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], check=True, capture_output=True,
        text=True,
    ).stdout.strip()


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as stream:
        return json.load(stream)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream))


def verify_source_manifest(manifest: dict[str, Any]) -> tuple[int, list[str]]:
    bad: list[str] = []
    entries = manifest["source_file_sha256"]
    for rel, expected in entries.items():
        path = ROOT / rel
        if not path.is_file() or sha256(path) != expected:
            bad.append(rel)
    return len(entries), bad


def verify_vdb_manifest(manifest: dict[str, Any]) -> dict[str, int]:
    entries = [manifest["design"], *manifest["tests"]]
    missing: list[str] = []
    mismatch: list[str] = []
    files_seen = 0
    bytes_seen = 0
    for entry in entries:
        base = Path(entry["path"])
        if not base.is_absolute():
            base = ROOT / base
        if not base.is_dir():
            missing.append(str(base))
            continue
        for item in entry["files"]:
            path = base / item["path"]
            files_seen += 1
            if not path.is_file():
                missing.append(str(path))
                continue
            size = path.stat().st_size
            bytes_seen += size
            if size != item["size_bytes"] or sha256(path) != item["sha256"]:
                mismatch.append(str(path))
    if missing or mismatch:
        raise ValueError(
            f"VDB manifest verification failed: missing={len(missing)}, "
            f"mismatch={len(mismatch)}; first_missing={missing[:2]}, "
            f"first_mismatch={mismatch[:2]}"
        )
    return {
        "vdb_count_including_design": len(entries),
        "test_vdb_count": len(manifest["tests"]),
        "file_count": files_seen,
        "verified_bytes": bytes_seen,
        "missing_file_count": 0,
        "mismatched_file_count": 0,
    }


def summarize_final_tool_status(signoff: dict[str, Any]) -> dict[str, str]:
    """Summarize the later Round 13 evidence without reviving the initial failure."""
    environment = signoff.get("environment", {})
    regression = signoff.get("regression", {})
    coverage = signoff.get("raw_adjusted", {})
    formal_reproofs = signoff.get("current_source_formal_reproofs", [])
    formal_open = signoff.get("formal_open", {})

    vcs_pass = bool(environment.get("vcs")) and all(
        regression.get(key) == "PASS"
        for key in ("generic_centered_ef2", "axil_product")
    )
    urg_pass = (
        bool(environment.get("urg"))
        and coverage.get("same_vdb_manifest") is True
        and bool(coverage.get("raw_urg_log_sha256"))
        and bool(coverage.get("adjusted_urg_log_sha256"))
    )
    proven_reproofs = sum(
        "PROVEN" in str(item.get("result", "")).upper()
        for item in formal_reproofs
    )
    if proven_reproofs and formal_open:
        formal_status = (
            f"PARTIAL_{proven_reproofs}_CURRENT_SOURCE_REPROOFS;"
            f" {len(formal_open)}_REQUIRED_OBLIGATIONS_OPEN"
        )
    elif proven_reproofs:
        formal_status = f"PARTIAL_{proven_reproofs}_CURRENT_SOURCE_REPROOFS"
    else:
        formal_status = "OPEN_NO_CURRENT_SOURCE_REPROOF_RECORDED"

    return {
        "vcs_r13": "PASS_TARGETED_PRODUCT_REGRESSIONS" if vcs_pass else "OPEN_OR_INCOMPLETE",
        "urg_r13": "PASS_SAME_MANIFEST_RAW_AND_ADJUSTED" if urg_pass else "OPEN_OR_INCOMPLETE",
        "formal_r13": formal_status,
    }


def write_csv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_gzip_csv(path: Path, rows: list[dict[str, Any]], fields: list[str]) -> None:
    # Fix gzip metadata so identical input manifests produce reproducible bytes.
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as zipped:
            import io
            text = io.TextIOWrapper(zipped, encoding="utf-8", newline="")
            writer = csv.DictWriter(text, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            text.flush()
            text.detach()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path,
        default=ROOT / "docs/verification/data/thermo5-r13",
    )
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to((ROOT / "docs/verification/data").resolve()):
        parser.error("--output-dir must be under docs/verification/data/")
    output.mkdir(parents=True, exist_ok=True)

    source_manifest_path = R12 / "thermo5-tx-product-source-manifest.json"
    compile_manifest_path = R12 / "thermo5-tx-product-compile-manifest.json"
    vdb_manifest_path = R12 / "thermo5-tx-vdb-manifest.json"
    candidate_path = WHATIF / "thermo5_tx_round12_candidate_audit.csv"
    exact_path = WHATIF / "thermo5_tx_round12_remaining_exact_uncovered_bins.csv.gz"
    metrics_path = WHATIF / "thermo5_tx_round12_raw_vs_whatif_metrics.csv"
    waivers_path = ROOT / "docs/verification/thermo5_tx_waivers.csv"
    resolved_path = R12 / "thermo5-tx-waivers-resolved-by-raw-hit.csv"

    source_manifest = read_json(source_manifest_path)
    compile_manifest = read_json(compile_manifest_path)
    vdb_manifest = read_json(vdb_manifest_path)
    final_signoff = read_json(FINAL_SIGNOFF) if FINAL_SIGNOFF.is_file() else None
    candidate_rows = read_csv(candidate_path)
    metrics_rows = read_csv(metrics_path)
    waiver_rows = read_csv(waivers_path)
    resolved_rows = read_csv(resolved_path)
    with gzip.open(exact_path, "rt", encoding="utf-8", newline="") as stream:
        exact_rows = list(csv.DictReader(stream))

    product_sha = source_manifest["product_source_sha"]
    if compile_manifest["product_source_sha"] != product_sha:
        raise ValueError("Product source SHA differs between source and compile manifests")
    source_count, source_mismatches = verify_source_manifest(source_manifest)
    compile_count, compile_mismatches = verify_source_manifest(compile_manifest)
    if source_mismatches or compile_mismatches:
        raise ValueError(
            f"Source hashes mismatch: source={source_mismatches[:3]}, "
            f"compile={compile_mismatches[:3]}"
        )
    if final_signoff and final_signoff.get("product_source_compile_fingerprint") != (
        "9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a"
    ):
        raise ValueError("Final Round 13 signoff manifest has a different product compile fingerprint")
    vdb_verification = verify_vdb_manifest(vdb_manifest)

    candidate_classes = Counter(row["classification"] for row in candidate_rows)
    if len(candidate_rows) != 369 or candidate_classes != {
        "ELIGIBLE": 361, "NEEDS_REPROOF": 4, "UNRESOLVED": 4
    }:
        raise ValueError(f"Unexpected candidate inventory: {dict(candidate_classes)}")
    candidate_ids = [row["waiver_id"] for row in candidate_rows]
    if len(set(candidate_ids)) != len(candidate_ids):
        raise ValueError("Duplicate candidate waiver ID")
    source_hashes = source_manifest["source_file_sha256"]
    for row in candidate_rows:
        if row["product_source_sha"] != product_sha:
            raise ValueError(f"Candidate product SHA mismatch: {row['waiver_id']}")
        if row["source_context_current"] != "true" or row["native_match_count"] != "1":
            raise ValueError(f"Candidate source/mapping audit mismatch: {row['waiver_id']}")
        if source_hashes.get(row["source_file"]) != row["source_sha256"]:
            raise ValueError(f"Candidate file hash mismatch: {row['waiver_id']}")

    exact_by_metric = Counter(row["metric"] for row in exact_rows)
    if len(exact_rows) != 13594 or exact_by_metric != {
        "branch": 12, "cond": 84, "line": 306, "toggle": 13192
    }:
        raise ValueError(f"Unexpected exact OPEN inventory: {dict(exact_by_metric)}")
    if any(row["product_source_sha"] != product_sha for row in exact_rows):
        raise ValueError("Exact-bin ledger product source SHA mismatch")

    official_ids = {row.get("waiver_id", "") for row in waiver_rows}
    candidate_id_set = set(candidate_ids)
    if len(waiver_rows) != 371 or len(official_ids) != 371:
        raise ValueError(f"Unexpected official waiver rows: {len(waiver_rows)}")
    official_only = official_ids - candidate_id_set
    local_only = candidate_id_set - official_ids
    resolved_ids = {row.get("waiver_id", "") for row in resolved_rows}
    if official_only != resolved_ids or local_only:
        raise ValueError(
            f"Waiver inventory mismatch: official_only={sorted(official_only)}, "
            f"local_only={sorted(local_only)}, resolved={sorted(resolved_ids)}"
        )

    pair1_rows: list[dict[str, Any]] = []
    active_tap_rows: list[dict[str, Any]] = []
    annotated_exact: list[dict[str, Any]] = []
    for row in exact_rows:
        signal_text = f"{row['bin']} {row['source_location']}".lower()
        if row["metric"] == "toggle" and "pair1_" in signal_text:
            bucket = "DPD_PAIR1_STRUCTURAL_ZERO"
            static_argument = (
                "Product DPD_MAX_TAPS=1; comb_tap iterates only tap 0, which is "
                "added to pair0; pair1 combinational sums initialize to zero and "
                "their registers reset to zero and capture that zero when pipe_ce."
            )
            row["r13_status"] = "WAIVER_CANDIDATE"
            row["r13_reachability"] = "STATIC_PARAMETER_INVARIANT_REVIEW_CANDIDATE"
            row["r13_root_cause"] = bucket
            row["r13_evidence"] = static_argument
            row["r13_required_action"] = (
                "Independently review exact source/instance/transition mapping; "
                "obtain a current-source Formal invariant or approve a documented "
                "static proof; do not apply Exclusion before approval."
            )
            pair1_rows.append(dict(row))
        elif row["metric"] == "toggle" and "active_taps[" in signal_text:
            bucket = "DPD_ACTIVE_TAPS_FIXED_TO_ONE"
            static_argument = (
                "Product MAX_TAPS=1; AXI-Lite reset sets shadow/active configuration "
                "to one, and tap_count_legal accepts only 1..MAX_TAPS. Invalid tap "
                "values do not commit. Trace through cfg_pending_core/cfg_active_core "
                "to dpd_active_taps and the 16-lane DPD wrapper."
            )
            row["r13_status"] = "WAIVER_CANDIDATE"
            row["r13_reachability"] = "STATIC_PARAMETER_INVARIANT_REVIEW_CANDIDATE"
            row["r13_root_cause"] = bucket
            row["r13_evidence"] = static_argument
            row["r13_required_action"] = (
                "Independently review reset and legal/invalid COMMIT behavior; "
                "obtain current-source Formal evidence or approve a documented "
                "static proof; do not apply Exclusion before approval."
            )
            active_tap_rows.append(dict(row))
        elif row["metric"] == "toggle" and "sample_count[" in signal_text:
            row["r13_status"] = "OPEN"
            row["r13_reachability"] = "REACHABLE_BY_ACCEPTED_SAMPLE_COUNTER"
            row["r13_root_cause"] = "DPD_SAMPLE_COUNT_HIGH_BITS"
            row["r13_evidence"] = (
                "RTL increments sample_count on each in_valid sample while pipe_ce; "
                "the exact transition requires a very long accepted-sample run."
            )
            row["r13_required_action"] = (
                "State the product lifetime/overflow contract, then use a feasible "
                "accelerated or formal counter proof; do not waive solely for duration."
            )
        else:
            row["r13_status"] = "OPEN"
            row["r13_reachability"] = "UNRESOLVED"
            row["r13_root_cause"] = row["root_cause_class"]
            row["r13_evidence"] = (
                "No new Round 13 DUT hit or current-source non-vacuous reachability "
                "proof was produced. Historical Raw miss is retained."
            )
            row["r13_required_action"] = row["next_action"]
        row["r13_official_waiver_status"] = "NOT_APPROVED_NO_EXCLUSION"
        row["r13_proof_status"] = "NOT_RUN_VCS_READER_UNSUPPORTED_ON_WSL2"
        annotated_exact.append(row)

    if len(pair1_rows) != 8192 or len(active_tap_rows) != 120:
        raise ValueError(
            "Unexpected fixed-configuration toggle groups: "
            f"pair1={len(pair1_rows)}, active_taps={len(active_tap_rows)}"
        )

    candidate_overlay: list[dict[str, Any]] = []
    for row in candidate_rows:
        status = {
            "ELIGIBLE": "WAIVER_CANDIDATE_PENDING_INDEPENDENT_REVIEW",
            "NEEDS_REPROOF": "OPEN_CURRENT_SOURCE_REPROOF_REQUIRED",
            "UNRESOLVED": "OPEN_REACHABILITY_OR_CONFIGURATION_UNRESOLVED",
        }[row["classification"]]
        updated = dict(row)
        updated.update({
            "round13_status": status,
            "round13_formal_reproof": "NOT_RUN_VCS_READER_UNSUPPORTED_ON_WSL2",
            "independent_reviewer": "",
            "approval_reference": "",
            "official_exclusion": "NO",
        })
        candidate_overlay.append(updated)

    data_fields = list(exact_rows[0]) + [
        "r13_status", "r13_reachability", "r13_root_cause", "r13_evidence",
        "r13_required_action", "r13_proof_status", "r13_official_waiver_status",
    ]
    exact_out = output / "thermo5_tx_r13_exact_bin_disposition.csv.gz"
    write_gzip_csv(exact_out, annotated_exact, data_fields)
    candidate_out = output / "thermo5_tx_r13_waiver_candidate_review.csv"
    candidate_fields = list(candidate_rows[0]) + [
        "round13_status", "round13_formal_reproof", "independent_reviewer",
        "approval_reference", "official_exclusion",
    ]
    write_csv(candidate_out, candidate_overlay, candidate_fields)
    toggle_fields = data_fields
    pair1_out = output / "thermo5_tx_r13_pair1_exact_bins.csv.gz"
    active_out = output / "thermo5_tx_r13_active_taps_exact_bins.csv.gz"
    write_gzip_csv(pair1_out, pair1_rows, toggle_fields)
    write_gzip_csv(active_out, active_tap_rows, toggle_fields)

    git_status = git("status", "--porcelain")
    formal_attempt = read_json(FORMAL_ATTEMPT) if FORMAL_ATTEMPT.is_file() else None
    formal_attempt_sha = sha256(FORMAL_ATTEMPT) if FORMAL_ATTEMPT.is_file() else None
    metrics = {
        row["metric"]: {
            "raw_covered": int(row["raw_covered"]),
            "raw_total": int(row["raw_total"]),
            "raw_missing": int(row["raw_missing"]),
            "raw_percent": float(row["raw_percent"]),
            "whatif_covered": int(row["whatif_covered"]),
            "whatif_total": int(row["whatif_total"]),
            "whatif_missing": int(row["whatif_missing"]),
            "whatif_percent": float(row["whatif_percent"]),
            "whatif_exact_bins_excluded": int(row["excluded_exact_bins"]),
        }
        for row in metrics_rows
    }
    pair_inputs = {
        "source_manifest": source_manifest_path,
        "compile_manifest": compile_manifest_path,
        "vdb_manifest": vdb_manifest_path,
        "candidate_audit": candidate_path,
        "exact_whatif_open_bins": exact_path,
        "raw_vs_whatif_metrics": metrics_path,
        "official_waivers": waivers_path,
        "resolved_raw_hits": resolved_path,
        "round12_signoff_report": ROUND12_REPORT,
        "round12_whatif_report": WHATIF_REPORT,
    }
    if formal_attempt:
        pair_inputs["round13_formal_attempt_manifest"] = FORMAL_ATTEMPT
    if final_signoff:
        pair_inputs["round13_final_signoff_manifest"] = FINAL_SIGNOFF

    baseline = {
        "schema_version": 1,
        "round": 13,
        "created_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "github": {
            "repository": "cwu766485-ctrl/dsm_ip",
            "starting_pr": 42,
            "pr_url": "https://github.com/cwu766485-ctrl/dsm_ip/pull/42",
            "pr_state": "OPEN_DRAFT_NOT_MERGED",
            "pr_head_sha": "644458deaf7481673c80177f1621efbff9252419",
            "pr_base": "thermo5",
            "pr_review_count": 0,
            "pr_status_checks": [],
        },
        "repository": {
            "branch": git("branch", "--show-current"),
            "commit_sha": git("rev-parse", "HEAD"),
            "tree_sha": git("rev-parse", "HEAD^{tree}"),
            "worktree_dirty": bool(git_status),
            "worktree_status": git_status.splitlines(),
            "integrated_thermo5_base": "73577475230a9c4e51273ac7071437f0a7373d48",
        },
        "product": {
            **source_manifest["product_configuration"],
            "product_source_sha": product_sha,
            "compile_fingerprint": "9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a",
            "compile_defines": source_manifest["compile_defines"],
            "compile_top": compile_manifest["compile_provenance"]["top"],
        },
        "integrity": {
            "source_manifest_inputs": source_count,
            "source_manifest_hash_mismatches": len(source_mismatches),
            "compile_manifest_inputs": compile_count,
            "compile_manifest_hash_mismatches": len(compile_mismatches),
            "vdbs": vdb_verification,
            "round12_vdb_set_reused_without_modification": True,
            "round13_vcs_vdb_created": False,
            "round13_urg_report_created": False,
        },
        "tools": {
            "python": platform.python_version(),
            "historical_vcs": "V-2023.12-SP1_Full64 (Round 12 recorded)",
            "historical_urg": "V-2023.12-SP1 (Round 12 recorded)",
            "vc_formal_installed": "V-2023.12-SP2_Full64",
            "host_kernel": platform.release(),
            **summarize_final_tool_status(final_signoff or {}),
            "status_evidence_manifest": (
                str(FINAL_SIGNOFF.relative_to(ROOT)) if final_signoff else None
            ),
            "status_evidence_manifest_sha256": (
                sha256(FINAL_SIGNOFF) if final_signoff else None
            ),
            "initial_formal_attempt_exit_code": formal_attempt.get("exit_code") if formal_attempt else None,
            "initial_formal_attempt_errors": formal_attempt.get("errors", []) if formal_attempt else [],
            "initial_formal_attempt_manifest": str(FORMAL_ATTEMPT.relative_to(ROOT)) if formal_attempt else None,
            "initial_formal_attempt_manifest_sha256": formal_attempt_sha,
        },
        "coverage": {
            "baseline_round": 12,
            "raw_and_adjusted_round12": metrics,
            "round13_raw_recomputed": False,
            "round13_adjusted_recomputed": False,
            "approved_waivers": 0,
            "active_exclusions": 0,
            "official_adjusted_is_raw": True,
            "whatif_is_not_signoff": True,
            "exact_open_bins": len(exact_rows),
            "open_bins_by_metric": dict(exact_by_metric),
        },
        "waivers": {
            "official_rows": len(waiver_rows),
            "local_round12_candidates": len(candidate_rows),
            "candidate_classification": dict(candidate_classes),
            "official_only_raw_hit_rows": sorted(official_only),
            "local_only_rows": sorted(local_only),
            "independent_approval_count": 0,
            "active_exclusion_count": 0,
        },
        "round13_disposition": {
            "pair1_toggle_bins": len(pair1_rows),
            "active_tap_toggle_bins": len(active_tap_rows),
            "fixed_config_total": len(pair1_rows) + len(active_tap_rows),
            "fixed_config_status": "WAIVER_CANDIDATE_PENDING_INDEPENDENT_REVIEW",
            "other_exact_bin_status": "OPEN",
            "formal_status": "OPEN_VCS_READER_UNSUPPORTED_ON_CURRENT_WSL2_KERNEL",
            "signoff": "OPEN_NOT_SIGNED_OFF",
        },
        "input_artifacts": {
            name: {"path": str(path.relative_to(ROOT)), "sha256": sha256(path)}
            for name, path in pair_inputs.items()
        },
        "generated_artifacts": {},
    }

    for path in [exact_out, candidate_out, pair1_out, active_out]:
        baseline["generated_artifacts"][path.name] = {
            "path": str(path.relative_to(ROOT)), "sha256": sha256(path),
            "size_bytes": path.stat().st_size,
        }
    baseline_path = output / "thermo5_tx_r13_baseline_manifest.json"
    baseline_path.write_text(json.dumps(baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": "PASS_AUDIT_GENERATED_NOT_SIGNOFF",
        "source_inputs": source_count,
        "vdbs": vdb_verification,
        "candidate_classes": dict(candidate_classes),
        "exact_open_bins": dict(exact_by_metric),
        "pair1_candidate_bins": len(pair1_rows),
        "active_tap_candidate_bins": len(active_tap_rows),
        "approved_waivers": 0,
        "active_exclusions": 0,
        "manifest": str(baseline_path.relative_to(ROOT)),
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
