#!/usr/bin/env python3
"""Audit Raw and adjusted URG coverage for the frozen Thermo5 TX product."""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import sys
from pathlib import Path


WAIVER_FIELDS = (
    "waiver_id",
    "configuration",
    "instance",
    "source_file",
    "source_line",
    "metric",
    "bin",
    "reason",
    "candidate_audit",
    "candidate_audit_sha256",
    "source_sha256",
    "review_status",
    "reviewer",
    "approval_reference",
    "el_directive",
)
CODE_METRICS = ("line", "cond", "branch", "toggle")


class AuditError(Exception):
    """Input evidence is incomplete, malformed, or would hide raw coverage."""


def _non_comment_el_lines(path: Path) -> list[str]:
    active: list[str] = []
    in_block_comment = False
    for line_number, original in enumerate(path.read_text().splitlines(), 1):
        line = original
        if in_block_comment:
            if "*/" in line:
                line = line.split("*/", 1)[1]
                in_block_comment = False
            else:
                continue
        while "/*" in line:
            before, after = line.split("/*", 1)
            if "*/" in after:
                line = before + after.split("*/", 1)[1]
            else:
                line = before
                in_block_comment = True
                break
        line = re.split(r"//|#", line, maxsplit=1)[0].strip()
        if line:
            active.append(f"{line_number}:{line}")
    return active


def _read_waivers(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != WAIVER_FIELDS:
            raise AuditError(
                "waiver CSV header mismatch; expected exact audit fields: "
                + ",".join(WAIVER_FIELDS)
            )
        return list(reader)


def _functional_groups(path: Path) -> dict[str, float]:
    """Extract group score rows from URG's groups.html table."""
    source = path.read_text(encoding="utf-8", errors="replace")
    groups: dict[str, float] = {}
    for row in re.findall(r"<tr\b[^>]*>(.*?)</tr>", source, flags=re.I | re.S):
        link = re.search(
            r'<a\s+href="grp\d+\.html"[^>]*>(.*?)</a>', row, flags=re.I | re.S
        )
        if not link:
            continue
        cells = re.findall(r"<td\b[^>]*>(.*?)</td>", row, flags=re.I | re.S)
        if len(cells) < 2:
            continue
        group_name = html.unescape(re.sub(r"<[^>]+>", "", link.group(1))).strip()
        score_text = html.unescape(re.sub(r"<[^>]+>", "", cells[1])).strip()
        try:
            groups[group_name] = float(score_text)
        except ValueError as exc:
            raise AuditError(f"cannot parse URG score for functional group {group_name}") from exc
    if not groups:
        raise AuditError(f"no URG functional groups found in {path}")
    return groups


def _applicable_functional_bins(path: Path) -> tuple[dict[str, float], dict[str, int], str]:
    """Score only explicitly applicable product bins from the source-linked bin audit."""
    by_group: dict[str, list[dict[str, str]]] = {}
    product_shas: set[str] = set()
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        required = {"product_source_sha", "group", "raw_status",
                    "raw_denominator_applicable", "legal_applicability"}
        if not required.issubset(reader.fieldnames or ()):
            raise AuditError("functional-bin detail CSV lacks required applicability fields")
        for row in reader:
            product_shas.add(row["product_source_sha"])
            if row["raw_denominator_applicable"] == "true" and row["legal_applicability"] == "LEGAL_PRODUCT":
                by_group.setdefault(row["group"], []).append(row)
    if len(product_shas) != 1 or not next(iter(product_shas), ""):
        raise AuditError("functional-bin detail must bind every row to one product source SHA")
    if not by_group:
        raise AuditError("functional-bin detail contains no legally applicable product bins")
    scores: dict[str, float] = {}
    counts = {"covered": 0, "total": 0, "uncovered": 0}
    for group, rows in sorted(by_group.items()):
        covered = sum(row["raw_status"] == "COVERED" for row in rows)
        uncovered = sum(row["raw_status"] == "UNCOVERED" for row in rows)
        if covered + uncovered != len(rows):
            raise AuditError(f"unexpected legal functional status in group {group}")
        scores[group] = round(100.0 * covered / len(rows), 4)
        counts["covered"] += covered
        counts["total"] += len(rows)
        counts["uncovered"] += uncovered
    counts["percent"] = round(100.0 * counts["covered"] / counts["total"], 4)
    return scores, counts, next(iter(product_shas))


def _coverage_fingerprint(summary: dict) -> dict:
    return {
        "metrics": {r["metric"]: {"covered": int(r["covered"]), "total": int(r["total"]),
                                  "missing": int(r["missing"])}
                    for r in summary.get("metrics", []) if r.get("ownership") == "PROJECT_RTL"},
        "fsm": [{"metric": r.get("metric"), "covered": int(r.get("covered", 0)),
                 "total": int(r.get("total", 0))}
                for r in summary.get("fsm_denominators", []) if r.get("ownership") == "PROJECT_RTL"],
        "dut_assertions": summary.get("dut_assertion_status_counts", {}),
    }


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _vdb_tree_fingerprint(path: Path) -> dict:
    if not path.is_dir():
        raise AuditError(f"manifest VDB is missing: {path}")
    files = []
    total_bytes = 0
    digest = hashlib.sha256()
    for child in sorted(item for item in path.rglob("*") if item.is_file()):
        relative = child.relative_to(path).as_posix()
        size = child.stat().st_size
        sha = _sha256_file(child)
        files.append({"path": relative, "size_bytes": size, "sha256": sha})
        total_bytes += size
        digest.update(relative.encode() + b"\0" + str(size).encode() + b"\0" + sha.encode() + b"\n")
    return {"path": str(path.resolve()), "file_count": len(files),
            "total_bytes": total_bytes, "tree_sha256": digest.hexdigest(), "files": files}


def _verify_dual_report_manifest(report_manifest: dict, raw_summary: dict,
                                 adjusted_summary: dict, waiver_audit: dict,
                                 waiver_audit_path: Path) -> None:
    if report_manifest.get("raw_summary") != _coverage_fingerprint(raw_summary):
        raise AuditError("Raw summary does not match the dual-report VDB manifest")
    if report_manifest.get("adjusted_summary") != _coverage_fingerprint(adjusted_summary):
        raise AuditError("Adjusted summary does not match the dual-report VDB manifest")
    if report_manifest.get("waiver_audit_sha256") != hashlib.sha256(waiver_audit_path.read_bytes()).hexdigest():
        raise AuditError("dual-report manifest is bound to a different waiver audit")
    if report_manifest.get("product_configuration_fingerprint") != waiver_audit.get("product_configuration_fingerprint"):
        raise AuditError("dual-report manifest product configuration mismatch")
    vdb_manifest = report_manifest.get("vdb_manifest")
    if not isinstance(vdb_manifest, dict) or not vdb_manifest.get("design") or not vdb_manifest.get("tests"):
        raise AuditError("dual-report manifest lacks its complete VDB file inventory")
    digest = hashlib.sha256(json.dumps(vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if digest != report_manifest.get("vdb_manifest_sha256"):
        raise AuditError("dual-report VDB inventory hash mismatch")
    if report_manifest.get("post_vdb_manifest_sha256") != digest:
        raise AuditError("VDB inputs changed while Raw/Adjusted URG reports were generated")
    current_design = _vdb_tree_fingerprint(Path(vdb_manifest["design"]["path"]))
    if current_design != vdb_manifest["design"]:
        raise AuditError("design VDB tree does not match the Raw/Adjusted report manifest")
    current_tests = [_vdb_tree_fingerprint(Path(item["path"]))
                     for item in vdb_manifest["tests"]]
    if current_tests != vdb_manifest["tests"]:
        raise AuditError("test VDB trees do not match the Raw/Adjusted report manifest")
    common = report_manifest.get("common_inputs", {})
    if common.get("design_vdb") != vdb_manifest["design"].get("path"):
        raise AuditError("dual-report design VDB path does not match the hashed inventory")
    if common.get("test_vdbs") != [item.get("path") for item in vdb_manifest["tests"]]:
        raise AuditError("dual-report test VDB list does not match the hashed inventory")


def _project_metrics(summary: dict) -> dict[str, dict[str, int | float]]:
    found = {
        row["metric"]: row
        for row in summary.get("metrics", [])
        if row.get("ownership") == "PROJECT_RTL"
    }
    missing = sorted(set(CODE_METRICS) - set(found))
    if missing:
        raise AuditError(f"raw URG summary lacks PROJECT_RTL metrics: {missing}")
    result: dict[str, dict[str, int | float]] = {}
    for metric in CODE_METRICS:
        row = found[metric]
        total, covered, missing_bins = int(row["total"]), int(row["covered"]), int(row["missing"])
        if total <= 0 or covered + missing_bins != total:
            raise AuditError(f"invalid {metric} denominator or counts: {row}")
        result[metric] = {
            "covered": covered,
            "total": total,
            "missing": missing_bins,
            "percent": round(100.0 * covered / total, 4),
        }
    return result


def _verify_source_manifest(path: Path, repo_root: Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    hashes = manifest.get("source_file_sha256")
    if not isinstance(hashes, dict) or not hashes:
        raise AuditError("source evidence manifest has no source_file_sha256 map")
    audit_tools = manifest.get("audit_tool_sha256")
    if not isinstance(audit_tools, dict) or not audit_tools:
        raise AuditError("source evidence manifest has no audit_tool_sha256 map")

    def verify_map(file_map: dict, label: str) -> int:
        checked = 0
        for relative, expected in file_map.items():
            if not isinstance(expected, str) or not re.fullmatch(r"[0-9a-f]{64}", expected):
                raise AuditError(f"invalid SHA-256 for {label} entry {relative}")
            source = (repo_root / relative).resolve()
            if not source.is_relative_to(repo_root.resolve()):
                raise AuditError(f"{label} path escapes repository: {relative}")
            if not source.is_file():
                raise AuditError(f"{label} file is missing: {relative}")
            observed = hashlib.sha256(source.read_bytes()).hexdigest()
            if observed != expected:
                raise AuditError(
                    f"{label} SHA mismatch for {relative}: expected {expected}, observed {observed}"
                )
            checked += 1
        return checked

    checked = verify_map(hashes, "source")
    audit_tool_count = verify_map(audit_tools, "audit tool")
    return {
        "path": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "source_file_count": checked,
        "audit_tool_count": audit_tool_count,
        "base_commit": manifest.get("base_commit"),
        "product_source_sha": manifest.get("product_source_sha"),
    }


def _fsm_metrics(summary: dict) -> dict[str, dict[str, int | float]]:
    totals = {"states": [0, 0], "transitions": [0, 0]}
    for row in summary.get("fsm_denominators", []):
        if row.get("ownership") != "PROJECT_RTL" or row.get("metric") not in totals:
            continue
        totals[row["metric"]][0] += int(row["covered"])
        totals[row["metric"]][1] += int(row["total"])
    result = {}
    for kind, (covered, total) in totals.items():
        if total:
            result[kind] = {
                "covered": covered,
                "total": total,
                "missing": total - covered,
                "percent": round(100.0 * covered / total, 4),
            }
    if set(result) != {"states", "transitions"}:
        raise AuditError("raw URG summary lacks PROJECT_RTL FSM states or transitions")
    return result


def audit(args: argparse.Namespace) -> dict:
    source_manifest = _verify_source_manifest(args.source_manifest, args.repo_root)
    summary = json.loads(args.raw_summary.read_text(encoding="utf-8"))
    if summary.get("exclusions_applied") is not False:
        raise AuditError("URG summary must explicitly record exclusions_applied=false")

    waivers = _read_waivers(args.waivers_csv)
    active_exclusions = _non_comment_el_lines(args.el_file)
    waiver_audit = None
    approved_waivers: list[dict] = []
    if args.waiver_audit:
        waiver_audit = json.loads(args.waiver_audit.read_text(encoding="utf-8"))
        approved_waivers = waiver_audit.get("approved", [])
        if int(waiver_audit.get("approved_count", -1)) != len(approved_waivers):
            raise AuditError("waiver audit manifest has an inconsistent approved count")
        if waiver_audit.get("waiver_csv_sha256") != hashlib.sha256(args.waivers_csv.read_bytes()).hexdigest():
            raise AuditError("waiver audit manifest is bound to a different CSV")
        if waiver_audit.get("compile_manifest_sha256") != hashlib.sha256(args.source_manifest.read_bytes()).hexdigest():
            raise AuditError("waiver audit manifest is bound to a different product source manifest")
        if waiver_audit.get("generated_el_sha256") != hashlib.sha256(args.el_file.read_bytes()).hexdigest():
            raise AuditError("generated .el SHA does not match the waiver audit manifest")
    elif waivers or active_exclusions:
        raise AuditError("waiver rows or active .el require a validated --waiver-audit manifest")
    elif active_exclusions:
        raise AuditError("active URG exclusions are forbidden without an approved waiver manifest")

    code = _project_metrics(summary)
    fsm = _fsm_metrics(summary)
    raw_groups = _functional_groups(args.groups_html)
    functional_bins = None
    functional_product_sha = None
    if args.functional_bin_detail:
        groups, functional_bins, functional_product_sha = _applicable_functional_bins(
            args.functional_bin_detail
        )
        expected_product_sha = (summary.get("product_source_sha")
                                or source_manifest.get("product_source_sha")
                                or source_manifest.get("base_commit"))
        if expected_product_sha and functional_product_sha != expected_product_sha:
            raise AuditError(
                "functional bin detail product SHA does not match the Raw source manifest"
            )
    else:
        groups = raw_groups
    assertion_summary_path = args.assertion_summary or args.raw_summary
    assertion_summary = json.loads(assertion_summary_path.read_text(encoding="utf-8"))
    assertion = assertion_summary.get("dut_assertion_status_counts")
    if not isinstance(assertion, dict):
        raise AuditError("raw URG summary lacks DUT assertion status counts")
    assertion_counts = {key: int(value) for key, value in assertion.items()}
    attempted = assertion_counts.get("SUCCESS", 0) + assertion_counts.get("UNCOVERED", 0)
    assertion_result = {
        "success": assertion_counts.get("SUCCESS", 0),
        "uncovered": assertion_counts.get("UNCOVERED", 0),
        "without_attempts": assertion_counts.get("WITHOUT_ATTEMPTS", 0),
        "failures": assertion_counts.get("FAILURE", 0),
        "attempted_denominator": attempted,
        "percent_of_attempted": round(
            100.0 * assertion_counts.get("SUCCESS", 0) / attempted, 4
        ) if attempted else None,
    }

    adjusted_code = code
    adjusted_fsm = fsm
    adjusted_exclusions_applied = False
    if args.adjusted_summary:
        adjusted_summary = json.loads(args.adjusted_summary.read_text(encoding="utf-8"))
        expected_exclusions = bool(approved_waivers)
        if adjusted_summary.get("exclusions_applied") is not expected_exclusions:
            raise AuditError("adjusted URG summary exclusion marker does not match approved waiver count")
        adjusted_code = _project_metrics(adjusted_summary)
        adjusted_fsm = _fsm_metrics(adjusted_summary)
        approved_per_metric: dict[str, int] = {}
        for row in approved_waivers:
            metric = "cond" if row["metric"] in {"cond", "condition"} else row["metric"]
            approved_per_metric[metric] = approved_per_metric.get(metric, 0) + 1
        for metric, raw_metric in code.items():
            adjusted_metric = adjusted_code[metric]
            denominator_delta = raw_metric["total"] - adjusted_metric["total"]
            if denominator_delta != approved_per_metric.get(metric, 0):
                raise AuditError(
                    f"adjusted {metric} denominator changed by {denominator_delta}; "
                    f"approved exact bins={approved_per_metric.get(metric, 0)}"
                )
        adjusted_exclusions_applied = expected_exclusions
    elif approved_waivers:
        raise AuditError("approved waivers require an adjusted URG summary generated from the same VDB")
    if args.adjusted_report_manifest:
        report_manifest = json.loads(args.adjusted_report_manifest.read_text(encoding="utf-8"))
        if report_manifest.get("approved_waiver_count") != len(approved_waivers):
            raise AuditError("dual-report manifest waiver count mismatch")
        if report_manifest.get("adjusted_exclusions_applied") is not adjusted_exclusions_applied:
            raise AuditError("dual-report manifest exclusion status mismatch")
        if waiver_audit is None:
            raise AuditError("dual-report manifest requires a validated waiver audit")
        _verify_dual_report_manifest(report_manifest, summary, adjusted_summary, waiver_audit,
                                     args.waiver_audit)

    raw_closed = (
        all(row["missing"] == 0 for row in code.values())
        and all(row["missing"] == 0 for row in fsm.values())
        and all(score == 100.0 for score in groups.values())
        and assertion_result["uncovered"] == 0
        and assertion_result["without_attempts"] == 0
        and assertion_result["failures"] == 0
    )
    return {
        "schema_version": 1,
        "status": "RAW_CLOSED" if raw_closed else "RAW_100_OPEN",
        "exclusions_applied": False,
        "raw_exclusions_applied": False,
        "adjusted_exclusions_applied": adjusted_exclusions_applied,
        "waiver_count": len(approved_waivers),
        "pending_waiver_count": int(waiver_audit.get("pending_count", 0)) if waiver_audit else 0,
        "rejected_waiver_count": int(waiver_audit.get("rejected_count", 0)) if waiver_audit else 0,
        "adjusted_coverage": "SEPARATE_URG_FROM_SAME_RAW_VDB_LIST",
        "source_manifest": source_manifest,
        "raw_project_rtl": code,
        "raw_fsm": fsm,
        "raw_dut_assertions": assertion_result,
        "raw_functional_groups": raw_groups,
        "functional_groups": groups,
        "legally_applicable_functional_bins": functional_bins,
        "functional_product_source_sha": functional_product_sha,
        "adjusted_project_rtl": adjusted_code,
        "adjusted_fsm": adjusted_fsm,
        "adjusted_dut_assertions": assertion_result,
        "adjusted_functional_groups": groups,
        "functional_group_count": len(groups),
        "inputs": {
            "raw_summary": str(args.raw_summary),
            "assertion_summary": str(assertion_summary_path),
            "groups_html": str(args.groups_html),
            "functional_bin_detail": str(args.functional_bin_detail) if args.functional_bin_detail else None,
            "waivers_csv": str(args.waivers_csv),
            "el_file": str(args.el_file),
            "waiver_audit": str(args.waiver_audit) if args.waiver_audit else None,
            "adjusted_summary": str(args.adjusted_summary) if args.adjusted_summary else None,
            "adjusted_report_manifest": str(args.adjusted_report_manifest) if args.adjusted_report_manifest else None,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-summary", required=True, type=Path)
    parser.add_argument("--assertion-summary", type=Path,
                        help="separate assertion inventory, such as the legal-only test report")
    parser.add_argument("--groups-html", required=True, type=Path)
    parser.add_argument("--functional-bin-detail", type=Path,
                        help="source-linked bin audit; only LEGAL_PRODUCT rows are gated")
    parser.add_argument("--waivers-csv", required=True, type=Path)
    parser.add_argument("--el-file", required=True, type=Path)
    parser.add_argument("--waiver-audit", type=Path,
                        help="source-bound output of thermo5_tx_waiver_pipeline.py")
    parser.add_argument("--adjusted-summary", type=Path,
                        help="URG summary from the same Raw VDB list with approved exclusions")
    parser.add_argument("--adjusted-report-manifest", type=Path,
                        help="VDB/command manifest from run_thermo5_tx_urg_dual_report.py")
    parser.add_argument("--source-manifest", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path)
    parser.add_argument(
        "--require-closed",
        action="store_true",
        help="return exit 2 unless every applicable raw code/FSM/assertion/functional bin is closed",
    )
    args = parser.parse_args()
    try:
        result = audit(args)
    except (AuditError, OSError, json.JSONDecodeError, KeyError, TypeError, ValueError) as exc:
        print(f"COVERAGE_AUDIT_ERROR: {exc}", file=sys.stderr)
        return 3

    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")
    if args.require_closed and result["status"] != "RAW_CLOSED":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
