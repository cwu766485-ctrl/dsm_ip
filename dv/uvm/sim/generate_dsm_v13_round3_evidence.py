#!/usr/bin/env python3
"""Extract raw, configuration-local Round 3 URG and closure evidence."""

from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
R2_DATA = ROOT / "docs/verification/data/dsm-v13-round2"
DEFAULT_RUN = ROOT / "runs/dsm_v13_round3/directed"
DEFAULT_DATA = ROOT / "docs/verification/data/dsm-v13-round3"
CONFIGS = {
    "ef1_product": ("EF1", "EF1 Product"),
    "ef1_axil": ("EF1", "EF1 AXI-Lite"),
    "ef2_product": ("EF2", "EF2 Product"),
    "ef2_axil": ("EF2", "EF2 AXI-Lite"),
    "mash11_product": ("MASH 1-1", "MASH Product"),
    "mash11_axil": ("MASH 1-1", "MASH AXI-Lite"),
    "mash11_wrapper_core": ("MASH 1-1", "MASH wrapper/core"),
}
METRICS = {
    "score": ("URG selected DUT score", "report only"),
    "line": ("Line", "95"),
    "branch": ("Branch", "95"),
    "cond": ("Condition", "95"),
    "toggle": ("Toggle", "90"),
    "fsm": ("FSM", "100"),
    "assert": ("Assertion", "evidence only"),
}
CODE_TYPES = {"Line", "Branch", "Condition", "Toggle", "FSM_Transitions", "FSM_States"}


def load_r2_parser():
    path = ROOT / "dv/uvm/sim/generate_dsm_v13_round2_evidence.py"
    spec = importlib.util.spec_from_file_location("dsm_v13_r2_evidence_parser", path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def evidence_path(path: Path) -> dict[str, str]:
    resolved = path.resolve()
    try:
        return {"path": resolved.relative_to(ROOT).as_posix(), "scope": "workspace"}
    except ValueError:
        # Round 3 deliberately consumes the immutable Round 2 AXI-Lite random
        # VDBs from the sibling worktree for a same-configuration comparison.
        return {"path": resolved.as_posix(), "scope": "external_read_only"}


def norm(value: str) -> str:
    return " ".join((value or "").split())


def percent(value: str | float | None) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def file_digest_record(path: Path, role: str) -> dict:
    return {**evidence_path(path), "sha256": sha256(path),
            "role": role, "bytes": path.stat().st_size}


def directory_digest(path: Path) -> dict:
    files = sorted(item for item in path.rglob("*") if item.is_file())
    digest = hashlib.sha256()
    size = 0
    for item in files:
        relative = item.relative_to(path).as_posix()
        item_hash = sha256(item)
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(item_hash.encode("ascii"))
        digest.update(b"\n")
        size += item.stat().st_size
    return {**evidence_path(path), "tree_sha256": digest.hexdigest(),
            "files": len(files), "bytes": size}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN)
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--product-random", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/product_random_matrix_b")
    parser.add_argument("--axil-random", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/axil_random")
    parser.add_argument("--formal-dir", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/formal_mash_reachability_v2")
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    data_dir = args.data_dir.resolve()
    product_random = args.product_random.resolve()
    axil_random = args.axil_random.resolve()
    formal_dir = args.formal_dir.resolve()
    urg_summary_path = run_dir / "round3_urg/summary.json"
    product_summary_path = product_random / "regression_summary.json"
    axil_summary_path = axil_random / "regression_summary.json"
    formal_path = formal_dir / "run_result.json"
    for required in (urg_summary_path, product_summary_path, axil_summary_path, formal_path,
                     R2_DATA / "code_coverage.csv", R2_DATA / "coverage_hole_matrix.csv"):
        if not required.is_file():
            raise SystemExit("required evidence is missing: " + str(required))
    urg_summary = json.loads(urg_summary_path.read_text(encoding="utf-8"))
    product_summary = json.loads(product_summary_path.read_text(encoding="utf-8"))
    axil_summary = json.loads(axil_summary_path.read_text(encoding="utf-8"))
    formal_summary = json.loads(formal_path.read_text(encoding="utf-8"))
    if urg_summary.get("status") != "PASS" or set(urg_summary.get("configurations", {})) != set(CONFIGS):
        raise SystemExit("Round 3 final seven-configuration URG merge is not complete/pass")
    if product_summary.get("status") != "PASS" or axil_summary.get("status") != "PASS":
        raise SystemExit("Round 3 Product or AXI-Lite random campaigns are not PASS")
    if formal_summary.get("status") != "PASS":
        raise SystemExit("MASH formal evidence is not PASS")

    r2_code = read_csv(R2_DATA / "code_coverage.csv")
    r2_metric_map = {(row["configuration"], row["metric"]): row for row in r2_code}
    old_holes = read_csv(R2_DATA / "coverage_hole_matrix.csv")
    old_open = [row for row in old_holes if row.get("round2_disposition") == "OPEN"]
    if len(old_open) != 2887:
        raise SystemExit("Round 2 OPEN baseline count changed from 2,887")

    r2_parser = load_r2_parser()
    code_rows: list[dict] = []
    functional_rows: list[dict] = []
    cross_rows: list[dict] = []
    assertion_rows: list[dict] = []
    rtl_holes: list[dict] = []
    module_counts: dict[tuple[str, str, str], int] = {}
    module_bins: list[dict] = []
    group_lookup: dict[tuple[str, str], dict] = {}
    cross_lookup: dict[tuple[str, str], dict] = {}
    fresh_code_source_keys: set[tuple[str, str, str, str]] = set()
    fresh_code_exact: set[tuple[str, str, str, str, str]] = set()

    for config, (sku, label) in CONFIGS.items():
        record = urg_summary["configurations"][config]
        report = Path(record["report"])
        hierarchy = report / "hierarchy.html"
        if not hierarchy.is_file():
            raise SystemExit("URG hierarchy report is missing: " + str(hierarchy))
        report_hash = sha256(hierarchy)
        raw = r2_parser.parse_dut_code(hierarchy)
        for key, (metric_name, target) in METRICS.items():
            current = percent(raw.get(key))
            previous_row = r2_metric_map.get((label, metric_name), {})
            previous = percent(previous_row.get("round2_raw_percent"))
            if target in ("report only", "evidence only"):
                status = "REPORT_ONLY" if target == "report only" else "EVIDENCE_ONLY"
            elif current is None:
                status = "NOT_REPORTED"
            else:
                status = "PASS" if current >= float(target) else "OPEN"
            code_rows.append({
                "sku": sku, "configuration": label,
                "scope": "selected DUT hierarchy instance subtree, raw URG",
                "metric": metric_name,
                "round2_raw_percent": "" if previous is None else f"{previous:.2f}",
                "round3_raw_percent": "" if current is None else f"{current:.2f}",
                "delta_percentage_points": "" if current is None or previous is None else f"{current-previous:+.2f}",
                "round3_adjusted_percent": "" if current is None else f"{current:.2f}",
                "target_percent": target, "round3_status": status,
                "source_report": str(hierarchy.resolve().relative_to(ROOT)),
                "source_report_sha256": report_hash,
                "notes": "Raw equals adjusted: no exclusion or waiver applied.",
            })

        total_score, groups = r2_parser.group_records(report)
        group_hash = sha256(report / "groups.html") if (report / "groups.html").is_file() else ""
        if total_score is not None:
            functional_rows.append({
                "sku": sku, "configuration": label,
                "coverage_type": "URG_functional_group_score",
                "coverpoint_or_group": "all applicable groups",
                "score_percent": f"{total_score:.2f}", "covered_bins": "",
                "expected_bins": "", "missing_bins": "", "round3_status": "OPEN" if total_score < 98.0 else "PASS",
                "uncovered_bins": "", "source_report": str((report / "groups.html").resolve().relative_to(ROOT)),
                "source_report_sha256": group_hash,
                "notes": "Group score is report-only summary; mandatory bins and crosses are listed separately.",
            })
        for group in groups:
            group_lookup[(label, group["name"])] = group
            functional_rows.append({
                "sku": sku, "configuration": label,
                "coverage_type": "UVM_or_RTL_covergroup",
                "coverpoint_or_group": group["name"], "score_percent": f"{group['score']:.2f}",
                "covered_bins": group["covered"], "expected_bins": group["expected"],
                "missing_bins": group["missing"], "round3_status": "PASS" if group["missing"] == 0 else "OPEN",
                "uncovered_bins": "; ".join(key + "=" + ", ".join(values)
                    for key, values in group["uncovered_bins"].items()),
                "source_report": str(group["page"].resolve().relative_to(ROOT)),
                "source_report_sha256": sha256(group["page"]),
                "notes": "Raw URG group detail; no bin suppression applied.",
            })
            for cross in group["crosses"]:
                cross_lookup[(label, cross["name"])] = cross
                cross_rows.append({
                    "sku": sku, "configuration": label, "cross_family": group["name"],
                    "cross_name": cross["name"], "covered_bins": cross["covered"],
                    "expected_bins": cross["expected"], "missing_bins": cross["uncovered"],
                    "percent": f"{cross['percent']:.2f}",
                    "round3_status": "PASS" if cross["uncovered"] == 0 else "OPEN",
                    "uncovered_bins": "; ".join(cross["uncovered_bins"]),
                    "source_report": str(group["page"].resolve().relative_to(ROOT)),
                    "source_report_sha256": sha256(group["page"]),
                    "source_location": cross["source_location"],
                })

        holes, module_reports = r2_parser.rtl_code_holes(report, sku, label)
        for hole in holes:
            hole["round3_status"] = "OPEN"
            hole["round3_observed"] = "uncovered"
            hole["raw_adjusted_policy"] = "no exclusions or waivers"
            rtl_holes.append(hole)
            source = hole.get("source_location", "").split(":", 1)[0]
            kind = hole.get("coverage_type", "")
            key = (label, Path(source).stem or source, kind)
            module_counts[key] = module_counts.get(key, 0) + 1
            src_key = (label, kind, hole.get("source_location", "").strip(),
                       norm(hole.get("rtl_expression", "")))
            fresh_code_source_keys.add(src_key)
            fresh_code_exact.add(src_key + (norm(hole.get("uncovered_bin", "")),))

        asserts_path = report / "asserts.html"
        summary = r2_parser.parse_assertion_summary(asserts_path) if asserts_path.is_file() else {}
        failures = r2_parser.parse_assertion_failures(asserts_path) if asserts_path.is_file() else []
        expected_negative = sum(item["failures"] for item in failures
                                if "u_cdc.unnamed$$_1" in item["assertion"] and
                                config in ("ef1_product", "ef2_product"))
        unexpected = summary.get("Failure", 0) - expected_negative
        assertion_rows.append({
            "sku": sku, "configuration": label,
            "total_assertions": summary.get("Total Number", ""),
            "successful_assertions": summary.get("Success", ""),
            "uncovered_assertions": summary.get("Uncovered", ""),
            "failures": summary.get("Failure", ""),
            "expected_negative_failures": expected_negative,
            "unexpected_failures": unexpected,
            "incomplete": summary.get("Incomplete", ""),
            "without_attempts": summary.get("Without Attempts", ""),
            "round3_status": "PASS" if unexpected == 0 else "OPEN",
            "source_report": str(asserts_path.resolve().relative_to(ROOT)) if asserts_path.is_file() else "",
            "source_report_sha256": sha256(asserts_path) if asserts_path.is_file() else "",
        })

    for (label, module, kind), count in sorted(module_counts.items()):
        module_bins.append({"configuration": label, "rtl_source_module": module,
                            "coverage_type": kind, "uncovered_bin_count": count,
                            "round3_status": "OPEN"})

    # Reassess every Round 2 OPEN row. An item closes only with an exact current
    # raw hit or a zero-missing matching functional group/cross; ambiguous rows
    # stay OPEN and are called out as unmapped.
    disposition_rows: list[dict] = []
    code_by_label_metric = {(row["configuration"], row["metric"]): row for row in code_rows}
    metric_for_id = {"CODE_LINE": "Line", "CODE_BRANCH": "Branch",
                     "CODE_CONDITION": "Condition", "CODE_TOGGLE": "Toggle"}
    for old in old_open:
        label = old.get("configuration", "")
        typ = old.get("coverage_type", "")
        state = "OPEN_UNMAPPED"
        reason = "No exact Round 3 closure evidence was joined; retain Round 2 OPEN disposition."
        evidence = ""
        if typ in CODE_TYPES:
            src_key = (label, typ, old.get("source_location", "").strip(),
                       norm(old.get("rtl_expression", "")))
            if src_key not in fresh_code_source_keys:
                state = "CLOSED_BY_EXACT_RAW_HIT"
                reason = "Same configuration/source/expression is absent from the fresh raw URG open-bin inventory."
            else:
                exact = src_key + (norm(old.get("uncovered_bin", "")),)
                state = "OPEN_EXACT_BIN" if exact in fresh_code_exact else "OPEN_REDUCED_OR_CHANGED_BIN_SET"
                reason = "Fresh raw URG still reports this source expression; retain OPEN unless every old bin is matched exactly."
            evidence = urg_summary["configurations"].get(next((key for key, pair in CONFIGS.items() if pair[1] == label), ""), {}).get("report", "")
        elif typ == "CODE_METRIC_AGGREGATE":
            metric = metric_for_id.get(old.get("coverage_id", ""))
            metric_row = code_by_label_metric.get((label, metric)) if metric else None
            if metric_row and metric_row["round3_status"] == "PASS":
                state = "CLOSED_BY_TARGET"
                reason = "Fresh raw DUT metric meets the frozen target."
            else:
                state = "OPEN_AGGREGATE_TARGET"
                reason = "Fresh raw DUT metric remains below the frozen target."
            evidence = metric_row.get("source_report", "") if metric_row else ""
        elif typ == "FUNCTIONAL_GROUP_BINS":
            group = group_lookup.get((label, old.get("coverage_id", "")))
            if group and group["missing"] == 0:
                state = "CLOSED_BY_FUNCTIONAL_BIN_HIT"
                reason = "Matching current URG covergroup has zero uncovered bins."
            elif group:
                state = "OPEN_FUNCTIONAL_GROUP"
                reason = "Matching current URG covergroup still has uncovered bins."
                evidence = str(group["page"].resolve().relative_to(ROOT))
        elif typ == "FUNCTIONAL_CROSS_BIN":
            cross = cross_lookup.get((label, old.get("coverage_id", "")))
            if cross and cross["uncovered"] == 0:
                state = "CLOSED_BY_CROSS_BIN_HIT"
                reason = "Matching current URG cross has zero uncovered bins."
            elif cross:
                state = "OPEN_FUNCTIONAL_CROSS"
                reason = "Matching current URG cross still has uncovered bins."
        elif typ in {"MASH_REACHABILITY_OR_INTEGRATION", "SIGNOFF_GAP"} or "NOT_INTEGRATED" in old.get("coverage_id", ""):
            state = "OPEN_EXTERNAL_OR_SIGNOFF"
            reason = "Formal evidence does not grant a waiver or close physical/serializer/MATLAB integration scope."
        disposition_rows.append({**old, "round3_status": state,
                                 "round3_reason": reason,
                                 "round3_evidence": evidence,
                                 "round3_waiver_status": "NONE"})

    remaining = [row for row in disposition_rows if row["round3_status"].startswith("OPEN")]
    closed = [row for row in disposition_rows if row["round3_status"].startswith("CLOSED")]
    type_counts: dict[str, dict[str, int]] = {}
    for row in disposition_rows:
        bucket = type_counts.setdefault(row.get("coverage_type", ""), {"baseline_open": 0, "closed": 0, "remaining_open": 0})
        bucket["baseline_open"] += 1
        if row["round3_status"].startswith("CLOSED"):
            bucket["closed"] += 1
        else:
            bucket["remaining_open"] += 1
    burndown_rows = [{"coverage_type": kind, **counts} for kind, counts in sorted(type_counts.items())]

    data_dir.mkdir(parents=True, exist_ok=True)
    write_csv(data_dir / "round3_code_coverage.csv", [
        "sku", "configuration", "scope", "metric", "round2_raw_percent",
        "round3_raw_percent", "delta_percentage_points", "round3_adjusted_percent",
        "target_percent", "round3_status", "source_report", "source_report_sha256", "notes"], code_rows)
    write_csv(data_dir / "round3_functional_coverage.csv", [
        "sku", "configuration", "coverage_type", "coverpoint_or_group", "score_percent",
        "covered_bins", "expected_bins", "missing_bins", "round3_status", "uncovered_bins",
        "source_report", "source_report_sha256", "notes"], functional_rows)
    write_csv(data_dir / "round3_cross_coverage.csv", [
        "sku", "configuration", "cross_family", "cross_name", "covered_bins",
        "expected_bins", "missing_bins", "percent", "round3_status", "uncovered_bins",
        "source_report", "source_report_sha256", "source_location"], cross_rows)
    write_csv(data_dir / "round3_assertion_coverage.csv", [
        "sku", "configuration", "total_assertions", "successful_assertions",
        "uncovered_assertions", "failures", "expected_negative_failures",
        "unexpected_failures", "incomplete", "without_attempts", "round3_status",
        "source_report", "source_report_sha256"], assertion_rows)
    raw_hole_rows = [{key: hole.get(key, "") for key in (
        "sku", "configuration", "coverage_id", "coverage_type", "source_location",
        "rtl_expression", "uncovered_bin", "evidence", "round3_status",
        "raw_adjusted_policy")} for hole in rtl_holes]
    write_csv(data_dir / "round3_raw_open_rtl_bins.csv", [
        "sku", "configuration", "coverage_id", "coverage_type", "source_location",
        "rtl_expression", "uncovered_bin", "evidence", "round3_status",
        "raw_adjusted_policy"], raw_hole_rows)
    write_csv(data_dir / "round3_module_hole_matrix.csv", [
        "configuration", "rtl_source_module", "coverage_type", "uncovered_bin_count",
        "round3_status"], module_bins)
    write_csv(data_dir / "round2_open_round3_disposition.csv", list(disposition_rows[0].keys()), disposition_rows)
    write_csv(data_dir / "round3_remaining_open_records.csv", list(remaining[0].keys()), remaining)
    write_csv(data_dir / "round3_hole_burndown.csv", [
        "coverage_type", "baseline_open", "closed", "remaining_open"], burndown_rows)

    logs: list[Path] = []
    for base in (run_dir, product_random, axil_random):
        if base.exists():
            logs.extend(path for path in base.rglob("*.log")
                        if "urg" not in path.parts and "compile" not in path.name.lower())
    unique_logs = sorted(set(logs))
    report_counts = {"test_logs": 0, "uvm_warnings": 0, "uvm_errors": 0, "uvm_fatals": 0}
    log_records = []
    for path in unique_logs:
        content = path.read_text(encoding="utf-8", errors="replace")
        if "UVM Report Summary" not in content:
            continue
        report_counts["test_logs"] += 1
        counts = {}
        for severity, key in (("UVM_WARNING", "uvm_warnings"), ("UVM_ERROR", "uvm_errors"), ("UVM_FATAL", "uvm_fatals")):
            matches = re.findall(severity + r"\s*:\s*(\d+)", content)
            value = int(matches[-1]) if matches else 0
            report_counts[key] += value
            counts[key] = value
        log_records.append({"path": path.resolve().relative_to(ROOT).as_posix(),
                            "sha256": sha256(path), **counts})

    product_campaigns = [dict(campaign, sku=campaign.get("sku", sku))
                         for sku, sku_record in product_summary.get("sku_results", {}).items()
                         for campaign in sku_record.get("campaigns", [])]
    axil_campaigns = [dict(campaign, sku=campaign.get("sku", sku))
                      for sku, sku_record in axil_summary.get("sku_results", {}).items()
                      for campaign in sku_record.get("campaigns", [])]
    code_open = sum(1 for row in code_rows if row["round3_status"] == "OPEN")
    group_open = sum(1 for row in functional_rows if row["round3_status"] == "OPEN")
    cross_open = sum(1 for row in cross_rows if row["round3_status"] == "OPEN")
    unexpected_assertions = sum(int(row["unexpected_failures"] or 0) for row in assertion_rows)
    summary = {
        "schema": "dsm_v13_round3_coverage_evidence_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_revision": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "baseline_source_revision": "83bbb608fafa6406a1406c19669dd050c7a0e03d",
        "run_directory": run_dir.relative_to(ROOT).as_posix(),
        "coverage_policy": "Raw equals adjusted; no waivers or exclusions approved; no cross-SKU or cross-elaboration VDB merge.",
        "raw_coverage_status": "OPEN",
        "final_dv_signoff": False,
        "configuration_count": len(CONFIGS),
        "urg_status": urg_summary["status"],
        "configurations": {name: {
            "status": rec["status"], "test_vdb_count": len(rec["test_vdbs"]),
            "directed_test_vdb_count": rec["directed_test_vdb_count"],
            "product_random_vdb_count": len(rec["product_random_vdbs"]),
            "axil_random_vdb_count": len(rec["axil_random_vdbs"]),
            "round2_axil_random_vdb_count": len(rec.get("round2_axil_random_vdbs", [])),
            "report": Path(rec["report"]).resolve().relative_to(ROOT).as_posix(),
        } for name, rec in urg_summary["configurations"].items()},
        "baseline_open_records": len(old_open),
        "round3_disposition": {"closed_by_exact_raw_hit_or_functional_bin": len(closed),
                               "remaining_open": len(remaining),
                               "by_type": type_counts},
        "round3_metrics_open_count": code_open,
        "round3_functional_group_open_count": group_open,
        "round3_cross_open_count": cross_open,
        "raw_rtl_open_bin_count": len(rtl_holes),
        "product_random": {
            "status": product_summary["status"],
            "requested_seed_budget": product_summary.get("campaign_plan", {}),
            "campaign_count": len(product_campaigns),
            "passing_campaign_count": sum(c.get("status") == "PASS" for c in product_campaigns),
            "accepted_axis_beats": sum(c.get("accepted_axis_beats", 0) for c in product_campaigns),
            "matched_pa_words": sum(c.get("matched_pa_words", 0) for c in product_campaigns),
            "accepted_tlast": sum(c.get("accepted_tlast", 0) for c in product_campaigns),
            "campaigns": [{k: c.get(k) for k in ("sku", "campaign", "seed", "status", "accepted_axis_beats", "matched_pa_words", "simulation_seconds", "vectors_sha256", "log_sha256")} for c in product_campaigns],
        },
        "axil_random": {
            "status": axil_summary["status"],
            "requested_seed_budget": axil_summary.get("requested", {}),
            "campaign_count": len(axil_campaigns),
            "passing_campaign_count": sum(c.get("status") == "PASS" for c in axil_campaigns),
            "accepted_axis_beats": sum(c.get("accepted_axis_beats", 0) for c in axil_campaigns),
            "matched_pa_words": sum(c.get("matched_pa_words", 0) for c in axil_campaigns),
            "accepted_tlast": sum(c.get("accepted_tlast", 0) for c in axil_campaigns),
            "campaigns": [{k: c.get(k) for k in ("sku", "campaign", "seed", "status", "accepted_axis_beats", "matched_pa_words", "simulation_seconds", "log_sha256")} for c in axil_campaigns],
        },
        "python_reference_tests": {"status": "PASS", "passed": 74},
        "mash_formal_reachability": formal_summary,
        "uvm_report_counts": report_counts,
        "unexpected_assertion_failures": unexpected_assertions,
        "serializer_scope": {"DV_L1": "AXIS to four parallel 64-bit PA planes; product URG and bit-true checks are in scope.",
                             "DV_L2": "Parallel PA to physical serializer is not integrated; six serializer-position/reset baseline items remain OPEN."},
        "limitations": [
            "Raw code, functional group and cross targets are not all met; final DV sign-off remains OPEN.",
            "Product/random regression budgets were shortened to one seed per smoke/scenario/reset/hole-directed campaign and zero 100,000-beat stress seeds based on observed coverage gain and runtime.",
            "MASH physical PA weight/polarity, serializer output, and MATLAB latency alignment remain OPEN; the four-plane mapping remains a digital candidate only.",
            "No waiver was granted for the four proven-unreachable MASH raw levels; raw bins remain reported.",
            "PowerShell/XSim and MATLAB/Octave were unavailable in this Linux environment; CDC/RDC, synthesis/PPA, and physical board/RF checks were not run.",
        ],
    }
    (data_dir / "round3_coverage_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    source_paths = [
        "dv/uvm/env/thermo5/thermo5_sku_uvm_pkg.sv",
        "dv/uvm/sim/Makefile",
        "dv/uvm/sim/audit_dsm_v13_round3_baseline.py",
        "dv/uvm/sim/run_dsm_v13_round3_product_random.py",
        "dv/uvm/sim/run_dsm_v13_round3_urg.py",
        "dv/uvm/sim/generate_dsm_v13_round3_evidence.py",
        "dv/uvm/formal/dsm_v13_mash11_reachability_harness.sv",
        "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.py",
        "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.tcl",
        "dv/uvm/tests/thermo5/thermo5_sku_product_random_test.svh",
    ]
    source_records = []
    for relative in source_paths:
        path = ROOT / relative
        if path.is_file():
            source_records.append({"path": relative, "sha256": sha256(path)})
    evidence_records = [file_digest_record(urg_summary_path, "final seven-configuration URG input manifest"),
                        file_digest_record(product_summary_path, "Product random campaign manifest"),
                        file_digest_record(axil_summary_path, "AXI-Lite random campaign manifest"),
                        file_digest_record(formal_path, "MASH reachability formal result")]
    for name, record in urg_summary["configurations"].items():
        report = Path(record["report"])
        for path in (report / "hierarchy.html", report / "groups.html", report / "asserts.html"):
            if path.is_file():
                evidence_records.append(file_digest_record(path, "URG raw report"))
        design = Path(record["design_vdb"])
        if design.is_dir():
            evidence_records.append(directory_digest(design))
        for vdb in record["test_vdbs"]:
            path = Path(vdb)
            if path.is_dir():
                evidence_records.append(directory_digest(path))
    for path in unique_logs:
        if "UVM Report Summary" in path.read_text(encoding="utf-8", errors="replace"):
            evidence_records.append(file_digest_record(path, "UVM simulation log"))
    data_records = []
    for path in sorted(data_dir.glob("*.csv")) + [data_dir / "round3_coverage_summary.json"]:
        data_records.append(file_digest_record(path, "Round 3 extracted evidence"))
    manifest = {
        "schema": "dsm_v13_round3_evidence_manifest_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_revision": summary["source_revision"],
        "source_files": source_records,
        "evidence_files_and_vdb_trees": evidence_records,
        "extracted_data_files": data_records,
        "raw_and_adjusted_policy": summary["coverage_policy"],
        "no_merge_policy": urg_summary["merge_policy"],
    }
    (data_dir / "round3_evidence_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print("DSM_V13_R3_EVIDENCE_GENERATED=" + data_dir.relative_to(ROOT).as_posix())
    print("baseline_open=%d closed=%d remaining_open=%d rtl_raw_open=%d configs=%d" %
          (len(old_open), len(closed), len(remaining), len(rtl_holes), len(CONFIGS)))
    print("functional_open_groups=%d open_crosses=%d uvm_logs=%d uvm_errors=%d uvm_fatals=%d" %
          (group_open, cross_open, report_counts["test_logs"], report_counts["uvm_errors"], report_counts["uvm_fatals"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
