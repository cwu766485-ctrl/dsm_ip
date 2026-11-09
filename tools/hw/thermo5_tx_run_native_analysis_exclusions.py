#!/usr/bin/env python3.12
"""Run Round 17 analysis-only native URG exclusions against one frozen VDB set.

This utility never approves a waiver. It runs Raw URG, each candidate group,
and the combined what-if report with ``-excl_strict``. It fails closed if the
VDB tree, source/configuration fingerprints, warnings, metric deltas, or exact
line-bin effects differ from the audited candidate ledger.
"""

from __future__ import annotations

import argparse
import copy
import csv
import gzip
import hashlib
import html
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_VDB_MANIFEST = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_raw_retry2/input_vdb_manifest.json"
DEFAULT_RUN_MANIFEST = DEFAULT_VDB_MANIFEST.parent / "run_manifest.json"
DEFAULT_CANDIDATE_LEDGER = ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_candidate_native_mapping.csv.gz"
DEFAULT_MAPPING_MANIFEST = ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_candidate_native_mapping_manifest.json"
DEFAULT_ANALYSIS_DIR = ROOT / "docs/verification/data/thermo5-r17/analysis_only"
DEFAULT_COMPILE_MANIFEST = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
DEFAULT_REVIEW_LEDGER = ROOT / "docs/verification/data/thermo5-r17/static_reachability_review/coverage_static_reachability_review.csv"
DEFAULT_OFFICIAL_WAIVERS = ROOT / "docs/verification/thermo5_tx_waivers.csv"
DEFAULT_WAIVER_RECONCILIATION = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_waiver_reconciliation.csv"
DEFAULT_URG = Path("/opt/Synopsys/vcs/V-2023.12-SP1/linux64/bin/urg1")
GROUP_FILES = {
    "A_DPD_PAIR1": "a_dpd_pair1_analysis_only.el",
    "B_EF2_FIXED_PARAMETERS": "b_ef2_fixed_parameters_analysis_only.el",
    "C_DPD_TAP_HISTORY": "c_dpd_tap_history_analysis_only.el",
    "D_CDC_RESIDUAL": "d_cdc_residual_analysis_only.el",
    "E_OTHER_PARAMETERS": "e_other_parameters_analysis_only.el",
}
METRICS = ("branch", "cond", "line", "toggle")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_fingerprint(path: Path) -> dict:
    entries = []
    total_bytes = 0
    digest = hashlib.sha256()
    for child in sorted(item for item in path.rglob("*") if item.is_file()):
        rel = child.relative_to(path).as_posix()
        size = child.stat().st_size
        file_hash = sha256_file(child)
        entries.append((rel, size, file_hash))
        total_bytes += size
        digest.update(rel.encode() + b"\0" + str(size).encode() + b"\0" + file_hash.encode() + b"\n")
    return {"file_count": len(entries), "total_bytes": total_bytes,
            "tree_sha256": digest.hexdigest()}


def read_gzip_csv(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_gzip_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise RuntimeError(f"Refusing to write an empty audit ledger: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with io.TextIOWrapper(compressed, encoding="utf-8", newline="") as text:
                writer = csv.DictWriter(text, fieldnames=list(rows[0]), lineterminator="\n")
                writer.writeheader()
                writer.writerows(rows)


def write_gzip_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            compressed.write(payload)


def coverage_summary(report: Path, output: Path) -> dict:
    command = [sys.executable, str(ROOT / "tools/hw/thermo5_coverage_denominator.py"),
               str(report), str(output)]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode:
        raise RuntimeError(f"Coverage inventory failed: {result.stderr[-2000:]}")
    summary_path = output / "summary.json"
    if not summary_path.is_file():
        raise RuntimeError(f"Coverage inventory missing: {summary_path}")
    return json.loads(summary_path.read_text(encoding="utf-8"))


def product_metric_totals(summary: dict) -> dict[str, dict[str, int]]:
    return {row["metric"]: {key: int(row[key]) for key in ("covered", "total", "missing")}
            for row in summary.get("metrics", [])
            if row.get("ownership") == "PROJECT_RTL" and row.get("metric") in METRICS}


def line_excluded_bins(report: Path) -> set[tuple[str, int]]:
    """Read exact DUT source line bins URG marks as excluded in its report."""
    audit_path = ROOT / "tools/hw/thermo5_audit_reports.py"
    spec = importlib.util.spec_from_file_location("thermo5_audit_reports", audit_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot load URG report instance parser")
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    excluded: set[tuple[str, int]] = set()
    for page_path in report.glob("mod*.html"):
        page = page_path.read_text(errors="replace")
        for _tag, block, _single in audit.instance_blocks(page):
            if "Line Coverage for Instance" not in block:
                continue
            name = re.search(
                r"(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>",
                block, re.S)
            pre = re.search(r'<pre class="code">(.*?)</pre>', block, re.S)
            if not name or not pre:
                continue
            instance = html.unescape(re.sub(r"<[^>]+>", "", name.group(1))).strip()
            if not instance.startswith("thermo5_sku_uvm_tb.dut"):
                continue
            for line in pre.group(1).splitlines():
                match = re.match(r'\s*(\d+)\s*<font color = "grey">excluded', line)
                if match:
                    excluded.add((instance, int(match.group(1))))
    return excluded


def run_urg(command: list[str], cwd: Path, env: dict[str, str], log_path: Path) -> list[str]:
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    log_path.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"URG failed ({result.returncode}); see {log_path}")
    diagnostics = [line for line in result.stdout.splitlines()
                   if re.search(r"\b(warning|error|reject|checksum mismatch|ambiguous)\b", line, re.I)]
    if diagnostics:
        raise RuntimeError("URG emitted warning/error diagnostics: " + " | ".join(diagnostics[:8]))
    return diagnostics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--urg", type=Path, default=DEFAULT_URG)
    parser.add_argument("--vdb-manifest", type=Path, default=DEFAULT_VDB_MANIFEST)
    parser.add_argument("--vdb-run-manifest", type=Path, default=DEFAULT_RUN_MANIFEST)
    parser.add_argument("--candidate-ledger", type=Path, default=DEFAULT_CANDIDATE_LEDGER)
    parser.add_argument("--mapping-manifest", type=Path, default=DEFAULT_MAPPING_MANIFEST)
    parser.add_argument("--analysis-dir", type=Path, default=DEFAULT_ANALYSIS_DIR)
    parser.add_argument("--compile-manifest", type=Path, default=DEFAULT_COMPILE_MANIFEST)
    parser.add_argument("--review-ledger", type=Path, default=DEFAULT_REVIEW_LEDGER)
    parser.add_argument("--official-waivers", type=Path, default=DEFAULT_OFFICIAL_WAIVERS)
    parser.add_argument("--waiver-reconciliation", type=Path, default=DEFAULT_WAIVER_RECONCILIATION)
    parser.add_argument("--evidence-dir", type=Path, default=DEFAULT_ANALYSIS_DIR,
                        help="Destination for compact, reviewable evidence artifacts")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    out = args.out_dir.resolve()
    if out.exists():
        parser.error("--out-dir must be new; existing evidence is never overwritten")
    out.mkdir(parents=True)
    vdb_manifest = json.loads(args.vdb_manifest.read_text(encoding="utf-8"))
    vdb_run = json.loads(args.vdb_run_manifest.read_text(encoding="utf-8"))
    mapping_manifest = json.loads(args.mapping_manifest.read_text(encoding="utf-8"))
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    review_rows = []
    with args.review_ledger.open(newline="", encoding="utf-8") as stream:
        review_rows = list(csv.DictReader(stream))
    with args.official_waivers.open(newline="", encoding="utf-8") as stream:
        official_waivers = list(csv.DictReader(stream))
    with args.waiver_reconciliation.open(newline="", encoding="utf-8") as stream:
        waiver_reconciliation = list(csv.DictReader(stream))
    if sha256_file(args.vdb_manifest) != vdb_run.get("vdb_manifest_file_sha256"):
        raise RuntimeError("VDB manifest file SHA does not match its Raw URG run manifest")
    canonical_vdb_sha = hashlib.sha256(json.dumps(
        vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if canonical_vdb_sha != vdb_run.get("vdb_manifest_canonical_sha256"):
        raise RuntimeError("VDB manifest canonical SHA does not match its Raw URG run manifest")
    if (mapping_manifest.get("vdb_manifest_file_sha256") != sha256_file(args.vdb_manifest)
            or mapping_manifest.get("vdb_manifest_canonical_sha256") != canonical_vdb_sha):
        raise RuntimeError("Native mapping evidence is bound to a different VDB manifest")
    if mapping_manifest.get("compile_fingerprint_sha256") != compile_manifest.get("compile_fingerprint_sha256"):
        raise RuntimeError("Native mapping evidence is bound to a different Product compile")
    if mapping_manifest.get("waiver_approval_count") != 0 or mapping_manifest.get("analysis_only") is not True:
        raise RuntimeError("Analysis-only runner refuses approved/official exclusion state")

    candidates = read_gzip_csv(args.candidate_ledger)
    if len(candidates) != 8970 or len({row["semantic_bin_id"] for row in candidates}) != len(candidates):
        raise RuntimeError("Candidate ledger must contain 8,970 unique semantic IDs")
    if len(review_rows) != 13171 or len(official_waivers) != 371 or len(waiver_reconciliation) != 371:
        raise RuntimeError("Raw exact ledger and official Waiver reconciliation counts do not match Round 17")
    if sha256_file(args.candidate_ledger) != mapping_manifest.get("mapping_ledger_sha256"):
        raise RuntimeError("Candidate mapping ledger fingerprint mismatch")
    source_head = vdb_run.get("source_head", "")
    compile_hashes = compile_manifest.get("source_file_sha256", {})
    for row in candidates:
        if row.get("source_file_sha256") != compile_hashes.get(row.get("source_file")):
            raise RuntimeError(f"Candidate source hash mismatch: {row['record_id']}")
        if row.get("product_source_sha") != compile_manifest.get("product_source_sha"):
            raise RuntimeError(f"Candidate Product SHA mismatch: {row['record_id']}")

    design = vdb_manifest["design"]
    tests = vdb_manifest["tests"]
    if len(tests) != 551:
        raise RuntimeError(f"Expected 551 Test VDBs, got {len(tests)}")
    vdb_groups = [design, *tests]
    before = []
    for item in vdb_groups:
        path = Path(item["path"])
        if not path.is_dir():
            raise RuntimeError(f"VDB path is unavailable: {path}")
        actual = tree_fingerprint(path)
        expected = {key: item[key] for key in ("file_count", "total_bytes", "tree_sha256")}
        if actual != expected:
            raise RuntimeError(f"VDB tree hash mismatch: {path}")
        before.append({"path": str(path), **actual})

    raw_command = vdb_run.get("command", [])
    if "-format" not in raw_command:
        raise RuntimeError("Raw URG run manifest has no -format delimiter")
    base = raw_command[:raw_command.index("-format")]
    if len([arg for arg in base if arg.endswith(".vdb")]) != 552:
        raise RuntimeError("Raw URG command does not contain the expected 552 VDB paths")
    manifest_paths = [design["path"], *(item["path"] for item in tests)]
    if [arg for arg in base if arg.endswith(".vdb")] != manifest_paths:
        raise RuntimeError("Raw URG command VDB order differs from the frozen VDB manifest")

    env = os.environ.copy()
    vcs_home = Path("/opt/Synopsys/vcs/V-2023.12-SP1")
    ld_paths = [str(vcs_home / "lib"), str(vcs_home / "linux64/lib")]
    env["LD_LIBRARY_PATH"] = ":".join(ld_paths + ([env["LD_LIBRARY_PATH"]] if env.get("LD_LIBRARY_PATH") else []))
    urg = str(args.urg.resolve())
    if not Path(urg).is_file():
        raise RuntimeError(f"URG binary not found: {urg}")

    def invoke(label: str, extra: list[str]) -> tuple[dict, set[tuple[str, int]], dict]:
        run_dir = out / label
        run_dir.mkdir()
        report = run_dir / "report"
        log = run_dir / "urg.log"
        command = [urg, *base[1:], *extra, "-excl_strict", "-format", "both",
                   "-report", str(report), "-dbname", f"thermo5_r17_{label}", "-log", str(log)]
        # base already starts with the URG binary; use that validated command prefix.
        diagnostics = run_urg(command, out, env, log)
        summary_dir = run_dir / "inventory"
        summary = coverage_summary(report, summary_dir)
        return summary, line_excluded_bins(report), {
            "command": command, "log_path": str(log), "log_sha256": sha256_file(log),
            "report_path": str(report), "diagnostic_count": len(diagnostics),
        }

    raw_label = "raw_urg"
    raw_dir = out / raw_label
    raw_dir.mkdir()
    raw_report = raw_dir / "report"
    raw_log = raw_dir / "urg.log"
    raw_command_clean = [urg, *base[1:], "-format", "both", "-report", str(raw_report),
                         "-dbname", "thermo5_r17_raw", "-log", str(raw_log)]
    run_urg(raw_command_clean, out, env, raw_log)
    raw_summary = coverage_summary(raw_report, raw_dir / "inventory")
    raw_lines = line_excluded_bins(raw_report)
    raw_metrics = product_metric_totals(raw_summary)
    expected_raw = {"branch": (524, 637), "cond": (657, 849),
                    "line": (3338, 3796), "toggle": (92072, 104480)}
    if any((raw_metrics.get(metric, {}).get("covered"), raw_metrics.get(metric, {}).get("total")) != values
           for metric, values in expected_raw.items()):
        raise RuntimeError(f"Fresh Raw URG differs from Round 17 baseline: {raw_metrics}")
    if raw_lines:
        raise RuntimeError("Fresh Raw report unexpectedly contains line Exclusions")

    by_group = {group: [row for row in candidates if row["analysis_group"] == group]
                for group in GROUP_FILES}
    group_results = {}
    expected_all = {metric: 0 for metric in METRICS}
    line_expected_all: set[tuple[str, int]] = set()
    for index, (group, filename) in enumerate(GROUP_FILES.items()):
        rows = by_group[group]
        if not rows:
            raise RuntimeError(f"Candidate group is empty: {group}")
        expected = {metric: 0 for metric in METRICS}
        expected_lines: set[tuple[str, int]] = set()
        direct = {metric: 0 for metric in METRICS}
        for row in rows:
            metric = row["metric"]
            status = row["native_mapping_status"]
            if status == "MAPPED_EXACT_NATIVE_BIN":
                direct[metric] += 1
                expected[metric] += 1
                if metric == "line":
                    expected_lines.add((row["instance"], int(row["source_position"].rsplit(":", 1)[1])))
            elif metric == "line" and status == "NATIVE_OBJECT_NOT_FOUND":
                # URG can mark a source line excluded as an exact associated
                # effect of a mapped native bin. The report must prove the exact
                # instance+line; unmatched or ambiguous lines stay OPEN.
                expected[metric] += 1
                expected_lines.add((row["instance"], int(row["source_position"].rsplit(":", 1)[1])))
        for metric, count in expected.items():
            expected_all[metric] += count
        line_expected_all |= expected_lines
        el_path = args.analysis_dir / filename
        expected_el_sha = mapping_manifest["group_counts"][group]["el_sha256"]
        if not el_path.is_file() or sha256_file(el_path) != expected_el_sha:
            raise RuntimeError(f"Analysis-only .el fingerprint mismatch: {el_path}")
        summary, excluded_lines, run_meta = invoke(f"batch_{index}_{group.lower()}",
                                                   ["-elfile", str(el_path)])
        metrics = product_metric_totals(summary)
        delta = {metric: raw_metrics[metric]["total"] - metrics[metric]["total"]
                 for metric in METRICS}
        if delta != expected:
            raise RuntimeError(f"{group} metric delta mismatch: expected {expected}, got {delta}")
        changed_covered = {metric: (raw_metrics[metric]["covered"], metrics[metric]["covered"])
                           for metric in METRICS
                           if raw_metrics[metric]["covered"] != metrics[metric]["covered"]}
        if changed_covered:
            raise RuntimeError(f"{group} exclusions changed covered-bin counts: {changed_covered}")
        if excluded_lines - raw_lines != expected_lines:
            extra = sorted((excluded_lines - raw_lines) - expected_lines)[:8]
            missing = sorted(expected_lines - (excluded_lines - raw_lines))[:8]
            raise RuntimeError(f"{group} exact line effect mismatch; extra={extra}, missing={missing}")
        group_results[group] = {
            "candidate_count": len(rows), "direct_native_match_count": sum(direct.values()),
            "direct_native_match_by_metric": direct,
            "urg_effective_excluded_by_metric": expected,
            "remaining_candidate_count": len(rows) - sum(expected.values()),
            "line_effect_exact_match_count": len(expected_lines),
            "line_effect_unexpected_count": len((excluded_lines - raw_lines) - expected_lines),
            "coverage": metrics, **run_meta,
        }

    filelist = args.analysis_dir / "round17_all_candidate_batches.elfilelist"
    filelist_contents = "\n".join(GROUP_FILES.values()) + "\n"
    if not filelist.is_file() or filelist.read_text(encoding="utf-8") != filelist_contents:
        raise RuntimeError("Combined .elfilelist is missing or does not use list-relative paths")
    combined_summary, combined_lines, combined_meta = invoke("combined_whatif", ["-elfilelist", str(filelist)])
    combined_metrics = product_metric_totals(combined_summary)
    combined_delta = {metric: raw_metrics[metric]["total"] - combined_metrics[metric]["total"]
                      for metric in METRICS}
    if combined_delta != expected_all:
        raise RuntimeError(f"Combined metric delta mismatch: expected {expected_all}, got {combined_delta}")
    changed_covered = {metric: (raw_metrics[metric]["covered"], combined_metrics[metric]["covered"])
                       for metric in METRICS
                       if raw_metrics[metric]["covered"] != combined_metrics[metric]["covered"]}
    if changed_covered:
        raise RuntimeError(f"Combined exclusions changed covered-bin counts: {changed_covered}")
    if combined_lines - raw_lines != line_expected_all:
        extra = sorted((combined_lines - raw_lines) - line_expected_all)[:8]
        missing = sorted(line_expected_all - (combined_lines - raw_lines))[:8]
        raise RuntimeError(f"Combined exact line effects mismatch; extra={extra}, missing={missing}")
    raw_fsm = [(row.get("instance"), row.get("fsm"), row.get("metric"), row.get("total"), row.get("covered"))
               for row in raw_summary.get("fsm_denominators", []) if row.get("ownership") == "PROJECT_RTL"]
    adjusted_fsm = [(row.get("instance"), row.get("fsm"), row.get("metric"), row.get("total"), row.get("covered"))
                    for row in combined_summary.get("fsm_denominators", []) if row.get("ownership") == "PROJECT_RTL"]
    if raw_fsm != adjusted_fsm or raw_summary.get("dut_assertion_status_counts") != combined_summary.get("dut_assertion_status_counts"):
        raise RuntimeError("Analysis-only Code exclusions changed FSM or Assertion coverage")

    after = []
    for item in vdb_groups:
        path = Path(item["path"])
        actual = tree_fingerprint(path)
        expected = {key: item[key] for key in ("file_count", "total_bytes", "tree_sha256")}
        if actual != expected:
            raise RuntimeError(f"VDB changed during URG execution: {path}")
        after.append({"path": str(path), **actual})

    raw_urg_version = next((line.strip() for line in raw_log.read_text(errors="replace").splitlines()
                            if line.startswith("URG Version")), "UNKNOWN")
    run_manifest = {
        "schema": "thermo5_tx_round17_analysis_only_urg_execution_v1",
        "analysis_only": True,
        "official_approval_count": 0,
        "source_head_for_vdb": source_head,
        "urg_binary": urg,
        "urg_version": raw_urg_version,
        "product_source_sha": compile_manifest.get("product_source_sha"),
        "compile_fingerprint_sha256": compile_manifest.get("compile_fingerprint_sha256"),
        "candidate_ledger_sha256": sha256_file(args.candidate_ledger),
        "native_mapping_manifest_sha256": sha256_file(args.mapping_manifest),
        "vdb_manifest_path": str(args.vdb_manifest),
        "vdb_manifest_file_sha256": sha256_file(args.vdb_manifest),
        "vdb_manifest_canonical_sha256": canonical_vdb_sha,
        "vdb_design_count": 1,
        "vdb_test_count": len(tests),
        "vdb_tree_fingerprint_validation": {
            "before_count": len(before), "after_count": len(after),
            "mismatches": 0,
        },
        "raw": {"metrics": raw_metrics, "command": raw_command_clean,
                "log_path": str(raw_log.relative_to(ROOT)), "log_sha256": sha256_file(raw_log),
                "report_path": str(raw_report)},
        "groups": group_results,
        "combined_whatif": {"candidate_count": len(candidates),
            "direct_native_match_count": mapping_manifest["mapped_exact_native_bin_count"],
            "effective_exact_candidate_excluded_count": sum(expected_all.values()),
            "metric_exclusions": expected_all,
            "metrics": combined_metrics,
            "remaining_code_bins": {metric: combined_metrics[metric]["missing"] for metric in METRICS},
            "command_template": "urg1 -full64 -dir <Design VDB> <551 Test VDBs> -elfilelist <analysis_only/round17_all_candidate_batches.elfilelist> -excl_strict -format both",
            "log_path": str(Path(combined_meta["log_path"]).relative_to(ROOT)),
            "log_sha256": combined_meta["log_sha256"],
            "report_path": combined_meta["report_path"],
            "diagnostic_count": combined_meta["diagnostic_count"],
            "exact_line_bins_excluded": len(combined_lines - raw_lines),
            "exact_line_bin_unexpected_count": len((combined_lines - raw_lines) - line_expected_all)},
        "review_status": "PENDING_INDEPENDENT_REVIEW",
        "signoff_status": "OPEN_NOT_OFFICIAL_SIGNOFF",
        "created_unix_time": int(time.time()),
    }
    if mapping_manifest.get("official_waiver_csv_sha256") != sha256_file(args.official_waivers):
        raise RuntimeError("Official Waiver CSV changed after candidate mapping")
    evidence_dir = args.evidence_dir.resolve()
    evidence_dir.mkdir(parents=True, exist_ok=True)
    artifact_paths = [
        evidence_dir / "round17_candidate_exclusion_execution.csv.gz",
        evidence_dir / "round17_exact_whatif_remaining_bins.csv.gz",
        evidence_dir / "round17_official_waiver_reconciliation.csv",
        evidence_dir / "thermo5_tx_r17_input_vdb_manifest.json.gz",
        evidence_dir / "thermo5_tx_r17_analysis_execution_evidence.json",
    ]
    if any(path.exists() for path in artifact_paths):
        raise RuntimeError("Evidence output already exists; choose a new evidence directory")

    mapped_by_id = {row["semantic_bin_id"]: row for row in candidates}
    execution_rows: list[dict[str, str]] = []
    applied_semantic_ids: set[str] = set()
    execution_by_semantic: dict[str, str] = {}
    for row in sorted(candidates, key=lambda item: item["record_id"]):
        native_status = row["native_mapping_status"]
        group = row["analysis_group"]
        if native_status == "MAPPED_EXACT_NATIVE_BIN":
            status = "EXCLUDED_DIRECT_NATIVE_EXACT"
        elif row["metric"] == "line" and native_status == "NATIVE_OBJECT_NOT_FOUND":
            status = "EXCLUDED_URG_ASSOCIATED_LINE_EXACT"
        else:
            status = "OPEN_NATIVE_MAPPING"
        if status.startswith("EXCLUDED_"):
            applied_semantic_ids.add(row["semantic_bin_id"])
        execution_by_semantic[row["semantic_bin_id"]] = status
        batch = group_results[group]
        execution_rows.append({**row,
            "analysis_execution_status": status,
            "analysis_only_el_file": GROUP_FILES[group],
            "analysis_only_el_sha256": mapping_manifest["group_counts"][group]["el_sha256"],
            "urg_batch_log_sha256": batch["log_sha256"],
            "combined_whatif_log_sha256": combined_meta["log_sha256"],
            "urg_diagnostics": "0",
            "official_exclusion": "NO",
            "independent_reviewer": "PENDING",
            "approval_reference": ""})
    direct_count = sum(row["analysis_execution_status"] == "EXCLUDED_DIRECT_NATIVE_EXACT" for row in execution_rows)
    associated_count = sum(row["analysis_execution_status"] == "EXCLUDED_URG_ASSOCIATED_LINE_EXACT" for row in execution_rows)
    open_candidate_count = sum(row["analysis_execution_status"] == "OPEN_NATIVE_MAPPING" for row in execution_rows)
    if (direct_count, associated_count, open_candidate_count) != (8721, 236, 13):
        raise RuntimeError(f"Unexpected candidate execution counts: direct={direct_count}, associated={associated_count}, open={open_candidate_count}")
    write_gzip_csv(artifact_paths[0], execution_rows)

    remaining_rows = []
    review_semantics = {row["semantic_bin_id"] for row in review_rows}
    if not set(mapped_by_id).issubset(review_semantics):
        raise RuntimeError("One or more candidates are absent from the current Exact Raw Bin Ledger")
    for row in review_rows:
        semantic = row["semantic_bin_id"]
        if semantic in applied_semantic_ids:
            continue
        row = dict(row)
        row["whatif_remaining_status"] = ("OPEN_CANDIDATE_NATIVE_MAPPING" if semantic in execution_by_semantic
                                           else "OPEN_NOT_IN_8970_CANDIDATE_SET")
        row["official_adjusted_status"] = "UNCHANGED_RAW_OPEN"
        remaining_rows.append(row)
    remaining_by_metric = {metric: sum(row["metric"] == metric for row in remaining_rows)
                           for metric in METRICS}
    if (len(remaining_rows), remaining_by_metric) != (4214,
            {"branch": 15, "cond": 84, "line": 29, "toggle": 4086}):
        raise RuntimeError(f"Exact remaining Raw ledger did not reconcile: {len(remaining_rows)} {remaining_by_metric}")
    write_gzip_csv(artifact_paths[1], remaining_rows)

    reconciliation_by_id = {row["waiver_id"]: row for row in waiver_reconciliation}
    candidate_by_waiver: dict[str, list[dict[str, str]]] = {}
    for row in candidates:
        for waiver_id in filter(None, row.get("official_waiver_ids", "").split(";")):
            candidate_by_waiver.setdefault(waiver_id, []).append(row)
    official_rows = []
    for waiver in official_waivers:
        prior = reconciliation_by_id.get(waiver["waiver_id"], {})
        linked = candidate_by_waiver.get(waiver["waiver_id"], [])
        if prior.get("r17_disposition") == "RESOLVED_BY_RAW_HIT":
            status = "RESOLVED_BY_RAW_HIT"
        elif len(linked) == 1:
            status = "PENDING_MATCHED_TO_8970_CANDIDATE_SET"
        elif not linked:
            status = "PENDING_NOT_IN_8970_CANDIDATE_SET"
        else:
            raise RuntimeError(f"Official Waiver {waiver['waiver_id']} maps ambiguously to candidates")
        if status == "PENDING_MATCHED_TO_8970_CANDIDATE_SET":
            candidate = linked[0]
            analysis_status = execution_by_semantic[candidate["semantic_bin_id"]]
            semantic_id = candidate["semantic_bin_id"]
        else:
            analysis_status = "NO_ANALYSIS_EL_APPLIED"
            semantic_id = ""
        official_rows.append({**waiver,
            "round17_reconciliation_status": status,
            "round17_candidate_semantic_id": semantic_id,
            "analysis_only_execution_status": analysis_status,
            "reviewer_approval": "NONE",
            "official_exclusion_active": "NO"})
    waiver_status_counts = {status: sum(row["round17_reconciliation_status"] == status for row in official_rows)
                            for status in ("RESOLVED_BY_RAW_HIT", "PENDING_MATCHED_TO_8970_CANDIDATE_SET",
                                           "PENDING_NOT_IN_8970_CANDIDATE_SET")}
    if waiver_status_counts != {"RESOLVED_BY_RAW_HIT": 2,
                                "PENDING_MATCHED_TO_8970_CANDIDATE_SET": 367,
                                "PENDING_NOT_IN_8970_CANDIDATE_SET": 2}:
        raise RuntimeError(f"Official Waiver reconciliation mismatch: {waiver_status_counts}")
    with artifact_paths[2].open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(official_rows[0]), lineterminator="\n")
        writer.writeheader(); writer.writerows(official_rows)
    write_gzip_json(artifact_paths[3], vdb_manifest)

    run_manifest["candidate_execution"] = {
        "direct_native_exact_count": direct_count,
        "urg_associated_exact_line_count": associated_count,
        "open_native_mapping_count": open_candidate_count,
        "effective_exact_candidate_excluded_count": len(applied_semantic_ids),
        "official_waiver_reconciliation": waiver_status_counts,
        "official_approval_count": 0,
        "official_exclusion_count": 0,
    }
    run_manifest["artifacts"] = {
        str(path.relative_to(ROOT)): sha256_file(path) for path in artifact_paths[:4]
    }
    run_manifest["vdb_manifest_compressed_sha256"] = sha256_file(artifact_paths[3])
    run_manifest["runner_sha256"] = sha256_file(Path(__file__))
    run_manifest["mapping_tool_sha256"] = sha256_file(ROOT / "tools/hw/thermo5_tx_native_exclusion.py")
    # Keep the full command/VDB-path execution detail in ignored runs/ evidence.
    full_execution_manifest = out / "analysis_execution_manifest.json"
    full_execution_manifest.write_text(json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
                                       encoding="utf-8")
    compact_manifest = copy.deepcopy(run_manifest)
    compact_manifest["full_local_execution_manifest_path"] = str(full_execution_manifest.relative_to(ROOT))
    compact_manifest["full_local_execution_manifest_sha256"] = sha256_file(full_execution_manifest)
    compact_manifest["raw"].pop("command", None)
    for group_result in compact_manifest["groups"].values():
        group_result.pop("command", None)
    execution_copy = evidence_dir / artifact_paths[4].name
    execution_copy.write_text(json.dumps(compact_manifest, indent=2, sort_keys=True) + "\n",
                              encoding="utf-8")
    print(json.dumps({"raw": raw_metrics,
                      "whatif": {"metrics": combined_metrics,
                                 "excluded": expected_all,
                                 "remaining": run_manifest["combined_whatif"]["remaining_code_bins"]},
                      "candidate_count": len(candidates),
                      "direct_native_match_count": mapping_manifest["mapped_exact_native_bin_count"],
                      "effective_exact_candidate_excluded_count": run_manifest["combined_whatif"]["effective_exact_candidate_excluded_count"],
                      "remaining_candidate_count": len(candidates)-run_manifest["combined_whatif"]["effective_exact_candidate_excluded_count"],
                      "signoff": run_manifest["signoff_status"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
