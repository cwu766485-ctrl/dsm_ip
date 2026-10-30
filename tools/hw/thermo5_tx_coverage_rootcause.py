#!/usr/bin/env python3.12
"""Create a source-linked Thermo5 TX functional/code coverage audit."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import re
import sys
import subprocess
from collections import Counter, defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_METRICS = {"branch": 197, "cond": 263, "line": 606, "toggle": 17527}
ALLOWED_STATUSES = {"HIT", "PROVEN_UNREACHABLE", "WAIVER_CANDIDATE", "OPEN"}
PRODUCT_CONFIG = (
    "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120 STATE_BITS=20; "
    "32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite product; Generic FIFO"
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def stable_id(*parts: str, prefix: str = "") -> str:
    return prefix + hashlib.sha256("\x1f".join(parts).encode()).hexdigest()[:20]


def normalize_instance(value: str) -> str:
    return re.sub(r"\[(\d+)\]", "[*]", value)


def normalize_signal(value: str) -> str:
    return re.sub(r"\[(\d+)\]", "[*]", value)


def root_cause(hint: str, reason: str, metric: str) -> tuple[str, str, str]:
    text = f"{hint} {reason}".lower()
    if "counter" in text or "longer_valid_stream" in text:
        return ("COUNTER_HIGH_BITS",
                "High counter bits or transition states were not observed in the sampled product stream.",
                "For each exact counter bit, derive the legal maximum from transaction rate and reset/stall behavior; run directed stimulus or a non-vacuous inductive proof.")
    if "residual" in text or "cdc" in text or "formal_mapping" in text:
        return ("CDC_OR_RESIDUAL_STATE",
                "The uncovered bin appears related to residual/FIFO state or a CDC-mapped condition.",
                "Map the exact RTL bin and Generic FIFO implementation; provide a legal cover witness or exact proof with reviewed clock/reset assumptions.")
    if "identity" in text or "arithmetic" in text or "saturation" in text:
        return ("IDENTITY_DPD_ARITHMETIC",
                "Identity-DPD arithmetic/saturation reachability is a hypothesis; existing inconclusive proofs do not close it.",
                "Prove the exact fixed-point expression over the product input domain and check non-vacuous cover witnesses; keep inconclusive results OPEN.")
    if "tap/history" in text or "taps1" in text or "max_taps1" in text or "pair1" in text:
        return ("DPD_TAP_HISTORY_CONFIGURATION",
                "Inactive tap/history logic may follow from DPD_MAX_TAPS=1; confirm against actual elaboration and RTL parameter guards.",
                "Trace the elaborated one-tap path and prove each exact alternative path unreachable before creating a waiver candidate.")
    if "fixed" in text or "parameter" in text or "configuration" in text:
        return ("FIXED_PRODUCT_CONFIGURATION",
                "Frozen product parameters may constrain this bin; this is not a reachability conclusion.",
                "Record the actual GT-parent/product parameter chain and close the exact source bin with a legal witness or non-vacuous proof.")
    if "reset" in text or "release" in text or "state_hold" in text:
        return ("RESET_RELEASE_OR_STATE_HOLD",
                "Reset/enable/stall ordering may explain the uncovered condition.",
                "Drive a legal reset-release and enable/stall sequence; check public outputs and state transitions with an independent checker.")
    if "empty_blocked" in text or "empty" in text or "blocking" in text:
        return ("INTERPOLATOR_EMPTY_OR_BLOCKED",
                "Interpolator empty/blocked behavior may be reachable around a stage boundary.",
                "Exercise legal source bubbles and downstream backpressure at the exact stage; compare all four output planes and monitor the DUT event.")
    if metric == "toggle" or "toggle" in text or "input_range" in text or "stress" in text:
        return ("DATA_VALUE_OR_TOGGLE_STIMULUS",
                "The required value/transition is signal-specific and has not been classified for legal reachability.",
                "Identify public stimulus for the exact transition; require monitor-observed activity and an independent data/protocol checker.")
    return ("LEGAL_STIMULUS_OR_CHECKER_REVIEW",
            "The bin is not yet classified as legally reachable, configuration-inapplicable, or a coverage-model issue.",
            "Inspect the exact source expression and elaborated instance; add legal directed stimulus only with an independent checker.")


def location_for(row: dict[str, object]) -> str:
    metric = str(row["metric"])
    if metric == "toggle":
        value = str(row["bin"])
        match = re.match(r"(?:Port|Signal) Details:(.*?):([01]_to_[01])$", value)
        signal = match.group(1) if match else value
        direction = match.group(2) if match else "direction_unknown"
        return f"signal:{normalize_signal(signal)}:{direction}"
    if metric == "cond":
        return (f"line:{str(row['bin']).split(':', 1)[0]}:"
                f"{row.get('condition_class', 'expression_unknown')}:"
                f"{row.get('condition_operands', 'operands_unknown')}")
    if metric == "branch":
        value = str(row["bin"])
        return f"line:{value.split(':', 1)[0]}:decision:{value.split(':', 1)[1] if ':' in value else 'unknown'}"
    return f"line:{str(row['bin']).split(':', 1)[0]}"


def source_position(row: dict[str, object]) -> tuple[str, str]:
    files = str(row["source_files"]).split(";")
    source = next((name for name in files if (ROOT / name).is_file()), files[0])
    metric = str(row["metric"])
    if metric == "toggle":
        value = str(row["bin"])
        match = re.match(r"(?:Port|Signal) Details:(.*?):([01]_to_[01])$", value)
        signal = match.group(1) if match else value
        return f"{source}:symbol {signal}", ""
    line_number = int(str(row["bin"]).split(":", 1)[0])
    try:
        source_line = (ROOT / source).read_text(encoding="utf-8", errors="replace").splitlines()[line_number - 1].strip()
    except (OSError, IndexError):
        source_line = ""
    return f"{source}:{line_number}", source_line


def write_gzip_csv(path: Path, fields: list[str], rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0, compresslevel=9) as zipped:
            with io.TextIOWrapper(zipped, encoding="utf-8", newline="") as output:
                writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n")
                writer.writeheader()
                writer.writerows(rows)


def read_urg_bin(report_dir: Path, group: str, point: str, bin_name: str, view: str) -> tuple[int, Path]:
    if view == "package":
        prefix = f"thermo5_sku_uvm_pkg::thermo5_sku_coverage::{group}.{point}"
    else:
        prefix = f"thermo5_sku_uvm_tb.me.obj.{group}.{point}"
    anchor = f'<a name="inst_tag_{prefix}"></a>'
    row_re = re.compile(
        rf"<tr[^>]*>\s*<td>\s*{re.escape(bin_name)}\s*</td>\s*<td[^>]*>\s*(\d+)\s*</td>",
        flags=re.IGNORECASE,
    )
    for report in sorted(report_dir.glob("grp*.html")):
        content = report.read_text(encoding="utf-8", errors="replace")
        start = content.find(anchor)
        if start < 0:
            continue
        next_anchor = content.find('<a name="inst_tag_', start + len(anchor))
        segment = content[start:next_anchor if next_anchor >= 0 else len(content)]
        found = row_re.search(segment)
        if found:
            return int(found.group(1)), report
    raise ValueError(f"could not find {prefix}.{bin_name} in {report_dir}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ledger", required=True, type=Path)
    ap.add_argument("--raw-report", required=True, type=Path)
    ap.add_argument("--negative-report", required=True, type=Path)
    ap.add_argument("--evidence", required=True, type=Path)
    ap.add_argument("--output-dir", required=True, type=Path)
    args = ap.parse_args()

    sys.path.insert(0, str(ROOT / "tools" / "hw"))
    import thermo5_audit_reports as audit

    evidence = json.loads(args.evidence.read_text(encoding="utf-8"))
    product_sha = evidence["code_coverage"]["gap_ledger"]["generated_source_sha"]
    expected_rows = evidence["code_coverage"]["gap_ledger"]["rows"]
    with args.ledger.open(encoding="utf-8", newline="") as source:
        original_rows = list(csv.DictReader(source))
    if len(original_rows) != expected_rows:
        raise ValueError(f"ledger has {len(original_rows)} records, evidence says {expected_rows}")
    metric_counts = Counter(row["metric"] for row in original_rows)
    if dict(metric_counts) != EXPECTED_METRICS:
        raise ValueError(f"metric counts differ from exact Raw denominator gaps: {metric_counts}")
    if {row["configuration"] for row in original_rows} != {"axil"}:
        raise ValueError("ledger is not the frozen AXI-Lite product hierarchy")

    source_manifest_path = args.ledger.parent / "axil_gap_ledger.json"
    source_manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    if source_manifest.get("source_git_sha") != product_sha:
        raise ValueError("evidence source SHA does not match the gap-ledger manifest")
    mismatches = []
    for relative, expected_hash in source_manifest.get("source_sha256", {}).items():
        path = ROOT / relative
        if not path.is_file() or sha256_file(path) != expected_hash:
            mismatches.append(relative)
    # The latest follow-up added assertions only to an AXI-Lite Formal
    # harness. That file is outside the product VCS/URG compile filelist; keep
    # the Raw simulation evidence usable while flagging Formal as stale.
    product_compile_roots = (
        "rtl/",
        "dv/uvm/agent/",
        "dv/uvm/env/",
        "dv/uvm/sequences/",
        "dv/uvm/tests/",
        "dv/uvm/tb/",
        "dv/uvm/sim/",
    )
    raw_compile_mismatches = [p for p in mismatches if p.startswith(product_compile_roots)]
    if raw_compile_mismatches:
        raise ValueError(f"current VCS/URG product source differs from evidence: {raw_compile_mismatches[:8]}")

    # Restore expression identity from exact Raw URG HTML. The old bin_id
    # omitted expression/subexpression and therefore collided on 17 rows.
    condition_audit = [
        row for row in audit.condition_rows(args.raw_report)[0]
        if row["status"] == "Not Covered" and row["ownership"] == "PROJECT_RTL"
    ]
    queues: dict[tuple[str, str], deque[dict[str, str]]] = defaultdict(deque)
    for row in condition_audit:
        queues[(row["instance"], f"{row['line']}:{row['operand_bin']}")].append(row)
    source_conditions = [row for row in original_rows if row["metric"] == "cond"]
    if Counter((r["instance"], r["bin"]) for r in source_conditions) != Counter(
        (r["instance"], f"{r['line']}:{r['operand_bin']}") for r in condition_audit
    ):
        raise ValueError("Condition rows do not exactly match current Raw URG expression bins")

    collisions = Counter(row["bin_id"] for row in original_rows)
    collision_extra_rows = sum(count - 1 for count in collisions.values() if count > 1)
    classified: list[dict[str, object]] = []
    buckets: dict[tuple[str, ...], list[dict[str, object]]] = defaultdict(list)
    for ordinal, row in enumerate(original_rows, start=1):
        item: dict[str, object] = dict(row)
        if row["metric"] == "cond":
            parsed = queues[(row["instance"], row["bin"])].popleft()
            expression = " ".join(parsed["expression"].split())
            item.update({
                "urg_expression": expression,
                "condition_class": "subexpression" if expression.startswith("SUB-EXPRESSION") else "expression",
                "condition_operands": row["bin"].split(":", 1)[1],
                "urg_module_page": parsed["module_file"],
            })
        else:
            item.update({"urg_expression": "", "condition_class": "", "condition_operands": "", "urg_module_page": ""})
        category, hypothesis, action = root_cause(row["evidence_hint"], row["reason"], row["metric"])
        normalized_inst = normalize_instance(row["instance"])
        location = location_for(item)
        source_pos, source_code = source_position(item)
        source_file_hashes = ";".join(
            f"{path}={source_manifest.get('source_sha256', {}).get(path, 'MISSING')}"
            for path in row["source_files"].split(";")
        )
        semantic_id = stable_id(row["configuration"], row["instance"], row["metric"], row["bin"],
                                str(item["urg_expression"]), prefix="TXB-")
        item.update({
            "record_id": stable_id(str(ordinal), row["bin_id"], row["instance"], row["metric"], row["bin"], prefix="TXR-"),
            "source_bin_id": row["bin_id"],
            "semantic_bin_id": semantic_id,
            "raw_bin_id_collision": "YES" if collisions[row["bin_id"]] > 1 else "NO",
            "closure_status": "OPEN",
            "task_id": "",
            "root_cause_class": category,
            "normalized_instance": normalized_inst,
            "source_location": location,
            "source_position": source_pos,
            "source_code_text": source_code,
            "source_file_sha256": source_file_hashes,
            "product_parameters": PRODUCT_CONFIG,
            "product_source_sha": product_sha,
            "root_cause_hypothesis": hypothesis,
            "next_action": action,
        })
        key = (row["configuration"], row["metric"], row["source_files"], normalized_inst, location, category)
        buckets[key].append(item)
        classified.append(item)
    if any(queues.values()):
        raise ValueError("unconsumed Raw URG Condition expressions remain after ledger mapping")
    semantic_ids = [str(row["semantic_bin_id"]) for row in classified]
    if len(set(semantic_ids)) != len(semantic_ids):
        raise ValueError("expression-aware semantic bin IDs still collide")

    tasks: list[dict[str, object]] = []
    for key, members in sorted(buckets.items()):
        category, hypothesis, action = root_cause(members[0]["evidence_hint"], members[0]["reason"], key[1])
        tid = stable_id(*key, prefix="TXC-")
        for member in members:
            member["task_id"] = tid
        priority = {"branch": "P0_BRANCH", "cond": "P0_CONDITION",
                    "line": "P1_LINE", "toggle": "P2_TOGGLE"}[key[1]]
        tasks.append({
            "task_id": tid,
            "priority": priority,
            "configuration": key[0],
            "metric": key[1],
            "module_source": key[2],
            "normalized_instance": key[3],
            "parameters": PRODUCT_CONFIG,
            "root_cause_class": category,
            "source_location": key[4],
            "source_position": members[0]["source_position"],
            "source_code_text": members[0]["source_code_text"],
            "bin_records": len(members),
            "semantic_bin_ids": ";".join(str(row["semantic_bin_id"]) for row in members),
            "raw_bin_id_examples": ";".join(str(row["source_bin_id"]) for row in members[:12]),
            "initial_status": "OPEN",
            "source_hint": members[0]["evidence_hint"],
            "root_cause_hypothesis": hypothesis,
            "next_action": action,
            "status_note": "Review hypothesis only; no hit, waiver, or reachability disposition is implied.",
            "product_source_sha": product_sha,
        })

    functional_specs = [
        ("source_cg", "cp_packet_quanta", "malformed_early", 1, "Malformed frame ends before the legal packet quantum"),
        ("core_cg", "cp_illegal", "bad_frame", 49, "Illegal frame/protocol-error observation"),
    ]
    functional_rows: list[dict[str, object]] = []
    report_hashes: dict[str, str] = {}
    for report in [args.raw_report, args.negative_report]:
        for candidate in [report / "groups.html", report / "grp6.html", report / "grp7.html"]:
            if candidate.exists():
                report_hashes[str(candidate)] = sha256_file(candidate)
        if report == args.raw_report:
            for candidate in sorted(report.glob("mod*.html")):
                report_hashes[str(candidate)] = sha256_file(candidate)
    for group, point, bin_name, negative_expected, meaning in functional_specs:
        for view in ["package", "instance"]:
            raw_count, raw_page = read_urg_bin(args.raw_report, group, point, bin_name, view)
            negative_count, negative_page = read_urg_bin(args.negative_report, group, point, bin_name, view)
            if raw_count != 0 or negative_count != negative_expected:
                raise ValueError(f"unexpected {group}.{point}.{bin_name} {view} counts: raw={raw_count}, negative={negative_count}")
            scope = (f"thermo5_sku_uvm_pkg::thermo5_sku_coverage::{group}.{point}.{bin_name}"
                     if view == "package" else f"thermo5_sku_uvm_tb.me.obj.{group}.{point}.{bin_name}")
            functional_rows.append({
                "urg_scope": scope,
                "report_view": "covergroup_type" if view == "package" else "monitor_instance",
                "group": group,
                "coverpoint": point,
                "bin": bin_name,
                "meaning": meaning,
                "raw_product_hits": raw_count,
                "negative_report_hits": negative_count,
                "classification": "ILLEGAL_TEST_ONLY",
                "legal_applicability": "NOT_APPLICABLE",
                "raw_denominator_action": "RETAIN; no denominator change or waiver",
                "negative_checker": "thermo5_sku_axil_illegal_frame_test; public protocol_error and reset recovery",
                "raw_urg_page_sha256": sha256_file(raw_page),
                "negative_urg_page_sha256": sha256_file(negative_page),
                "product_source_sha": product_sha,
            })

    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_gzip_csv(args.output_dir / "thermo5-tx-coverage-open-bins.csv.gz",
                   list(classified[0]), classified)
    with (args.output_dir / "thermo5-tx-coverage-root-cause-tasks.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(tasks[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(tasks)
    with (args.output_dir / "thermo5-tx-functional-bin-audit.csv").open("w", encoding="utf-8", newline="") as output:
        writer = csv.DictWriter(output, fieldnames=list(functional_rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(functional_rows)

    functional_detail_path = args.output_dir / "thermo5-tx-functional-bin-detail.csv"
    functional_detail_script = ROOT / "tools" / "hw" / "thermo5_tx_functional_bin_detail.py"
    subprocess.run([
        sys.executable, str(functional_detail_script),
        "--raw-report", str(args.raw_report),
        "--negative-audit", str(args.output_dir / "thermo5-tx-functional-bin-audit.csv"),
        "--out", str(functional_detail_path),
    ], check=True)
    with functional_detail_path.open(encoding="utf-8", newline="") as stream:
        functional_detail_rows = list(csv.DictReader(stream))
    functional_scoreable = [row for row in functional_detail_rows
                            if row["raw_denominator_applicable"] == "true"]
    functional_covered = [row for row in functional_scoreable if row["raw_status"] == "COVERED"]
    functional_uncovered = [row for row in functional_scoreable if row["raw_status"] == "UNCOVERED"]
    functional_excluded = [row for row in functional_detail_rows
                           if row["raw_denominator_applicable"] == "false"]

    status_counts = Counter(row["closure_status"] for row in classified)
    cause_counts = Counter((row["metric"], row["root_cause_class"]) for row in classified)
    task_metric_counts = Counter(task["metric"] for task in tasks)
    raw = evidence["code_coverage"]["raw"]
    metric_key = {"branch": "branch", "cond": "condition", "line": "line", "toggle": "toggle_both_directions"}
    summary = {
        "schema_version": 2,
        "source_product_sha": product_sha,
        "product_configuration": PRODUCT_CONFIG,
        "raw_report": str(args.raw_report),
        "raw_report_sha256": report_hashes,
        "negative_report": str(args.negative_report),
        "source_ledger": str(args.ledger),
        "source_ledger_sha256": sha256_file(args.ledger),
        "source_manifest_sha256": sha256_file(source_manifest_path),
        "source_manifest_sha_matches_current_tree": not mismatches,
        "source_manifest_mismatches": mismatches,
        "raw_simulation_source_mismatches": raw_compile_mismatches,
        "source_ledger_rows": len(original_rows),
        "unique_expression_aware_semantic_bin_ids": len(set(semantic_ids)),
        "raw_bin_id_collision_groups": sum(1 for count in collisions.values() if count > 1),
        "raw_bin_id_collision_extra_rows": collision_extra_rows,
        "collision_resolution": "All source rows retained; Condition expression/subexpression restored from Raw URG; semantic IDs include exact expression text.",
        "source_ledger_metric_counts": dict(sorted(metric_counts.items())),
        "raw_dut_coverage": {metric: raw[metric_key[metric]] for metric in metric_key},
        "closure_status_counts": dict(sorted(status_counts.items())),
        "all_rows_have_allowed_status": all(row["closure_status"] in ALLOWED_STATUSES for row in classified),
        "approved_waivers": 0,
        "exclusions_applied": 0,
        "root_cause_task_count": len(tasks),
        "task_count_by_metric": dict(sorted(task_metric_counts.items())),
        "bin_records_by_metric_and_root_cause": {
            f"{metric}:{cause}": count for (metric, cause), count in sorted(cause_counts.items())
        },
        "functional_raw_bins": {
            "covered": len(functional_covered),
            "expected": len(functional_scoreable),
            "uncovered_records": len(functional_uncovered),
            "detail_rows_including_urg_model_excluded": len(functional_detail_rows),
            "urg_model_excluded_rows": len(functional_excluded),
            "includes_generated_cross_bins": True,
        },
        "functional_bin_detail_report": {
            "file": functional_detail_path.name,
            "sha256": sha256_file(functional_detail_path),
            "groups_html_sha256": sha256_file(args.raw_report / "groups.html"),
            "scoreable_rows": len(functional_scoreable),
            "rows_including_existing_urg_model_exclusions": len(functional_detail_rows),
        },
        "functional_legally_applicable_positive_bins": {
            "covered": sum(row["legal_applicability"] == "LEGAL_PRODUCT" and row["raw_status"] == "COVERED" for row in functional_scoreable),
            "expected": sum(row["legal_applicability"] == "LEGAL_PRODUCT" for row in functional_scoreable),
        },
        "functional_negative_only_semantic_bins": 2,
        "interpretation": "Root-cause groups are planning hypotheses. All code gaps remain OPEN until an exact simulator hit or non-vacuous proof is recorded.",
    }
    (args.output_dir / "thermo5-tx-coverage-root-cause-summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    lines = [
        "# Thermo5 TX Coverage Root-Cause Closure — Step 1/2",
        "",
        f"- Raw VCS/URG product source SHA: {product_sha}; product RTL/UVM compile source hashes match.",
        f"- Source manifest mismatches: {len(mismatches)} ({', '.join(mismatches) if mismatches else 'none'}). Any Formal-harness mismatch is reported separately and is not represented as current Formal evidence.",
        f"- Raw gap ledger: {len(original_rows):,} rows; SHA-256 {sha256_file(args.ledger)}.",
        f"- Expression-aware semantic IDs: {len(set(semantic_ids)):,}; old ID collisions: {summary['raw_bin_id_collision_groups']} groups, {collision_extra_rows} extra rows.",
        "- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.",
        "- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.",
        "- Raw equals Adjusted; approved waivers 0; exclusions 0.",
        "",
        "## Functional Group Report audit",
        "",
        f"The complete product Group Report contains {len(functional_covered)}/{len(functional_scoreable)} denominator-eligible bin records across covergroup-type and monitor-instance views. This includes generated cross bins; the earlier 170/174 tally omitted 40 EF2 cross-bin records and is superseded. Four zero-hit records are two semantic illegal-frame bins repeated in the two report views. Separate negative URG evidence hits them; the Raw records remain in the denominator and are not legal positive-product stimulus.",
        "",
        "| Group | Raw bin hits / denominator | Uncovered |",
        "|---|---:|---:|",
    ]
    functional_by_group: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in functional_scoreable:
        functional_by_group[row["group"]].append(row)
    for group, rows in sorted(functional_by_group.items()):
        group_hits = sum(row["raw_status"] == "COVERED" for row in rows)
        group_misses = len(rows) - group_hits
        lines.append(f"| {group} | {group_hits}/{len(rows)} | {group_misses} |")
    lines += [
        "",
        f"The complete bin CSV has {len(functional_detail_rows)} rows: {len(functional_scoreable)} scoreable Raw records and {len(functional_excluded)} bins already marked Illegal/Excluded by the URG model. These model statuses are listed transparently; no URG exclusion directive or waiver was added. See `thermo5-tx-functional-bin-detail.csv` for every group, coverpoint/cross, bin, count, report view, and source-page SHA.",
        "",
        "| Exact URG scope | Raw product hits | Separate negative hits | Classification |",
        "|---|---:|---:|---|",
    ]
    for row in functional_rows:
        lines.append(f"| {row['urg_scope']} | {row['raw_product_hits']} | {row['negative_report_hits']} | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |")
    lines += [
        "",
        f"Legally applicable positive bins are {summary['functional_legally_applicable_positive_bins']['covered']}/{summary['functional_legally_applicable_positive_bins']['expected']}. The four Raw zero-hit report rows remain visible in the denominator.",
        "",
        "## Code coverage and root-cause task inventory",
        "",
        "| Metric | Raw covered / total | Raw missing | Closure tasks |",
        "|---|---:|---:|---:|",
    ]
    for metric in ["branch", "cond", "line", "toggle"]:
        entry = raw[metric_key[metric]]
        label = "condition" if metric == "cond" else metric
        lines.append(f"| {label} | {entry['covered']:,}/{entry['total']:,} ({entry['percent']:.4f}%) | {entry['missing']:,} | {task_metric_counts[metric]} |")
    lines += [
        "",
        f"The task CSV has {len(tasks):,} source/instance/location-rooted tasks. The compressed bin ledger preserves all {len(original_rows):,} source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. Every row is OPEN at this audit stage.",
        "",
        "| Metric / root-cause hypothesis | Raw gap rows |",
        "|---|---:|",
    ]
    for (metric, cause), count in sorted(cause_counts.items()):
        lines.append(f"| {metric} / {cause} | {count:,} |")
    lines += [
        "",
        "This was a deterministic re-analysis of the fixed-SHA VCS/URG evidence. No simulator was rerun, no new hit was claimed, and no Raw/Adjusted denominator changed.",
        "",
        "## Evidence inputs",
        "",
        f"- Raw Group Report: {args.raw_report}",
        f"- Separate expected-negative Group Report: {args.negative_report}",
        f"- Source-linked gap ledger: {args.ledger}",
        f"- Source manifest: {source_manifest_path}",
        f"- Closure evidence JSON: {args.evidence}",
        "",
    ]
    (args.output_dir / "thermo5-tx-coverage-root-cause-closure.md").write_text("\n".join(lines), encoding="utf-8")
    output_names = [
        "thermo5-tx-coverage-open-bins.csv.gz",
        "thermo5-tx-coverage-root-cause-tasks.csv",
        "thermo5-tx-functional-bin-audit.csv",
        "thermo5-tx-functional-bin-detail.csv",
        "thermo5-tx-coverage-root-cause-summary.json",
        "thermo5-tx-coverage-root-cause-closure.md",
    ]
    command = (
        "python3.12 tools/hw/thermo5_tx_coverage_rootcause.py "
        f"--ledger {args.ledger} --raw-report {args.raw_report} "
        f"--negative-report {args.negative_report} --evidence {args.evidence} "
        f"--output-dir {args.output_dir}"
    )
    manifest = {
        "schema_version": 1,
        "product_source_sha": product_sha,
        "analysis_script_sha256": sha256_file(Path(__file__).resolve()),
        "functional_bin_detail_script_sha256": sha256_file(functional_detail_script),
        "python": sys.version.split()[0],
        "eda_tool_versions_from_source_evidence": evidence.get("tool_versions", {}),
        "command": command,
        "input_sha256": {
            "ledger": sha256_file(args.ledger),
            "raw_groups_html": report_hashes,
            "negative_urg_groups_html": {
                str(path): sha256_file(path)
                for path in sorted(args.negative_report.glob("grp*.html"))
            },
            "source_manifest": sha256_file(source_manifest_path),
            "closure_evidence": sha256_file(args.evidence),
        },
        "output_sha256": {
            name: sha256_file(args.output_dir / name) for name in output_names
        },
        "raw_coverage_reused": True,
        "simulator_rerun": False,
        "waivers": 0,
        "exclusions": 0,
    }
    (args.output_dir / "thermo5-tx-coverage-root-cause-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "source_product_sha": product_sha,
        "source_ledger_rows": len(original_rows),
        "metric_counts": dict(sorted(metric_counts.items())),
        "semantic_id_collision_groups": summary["raw_bin_id_collision_groups"],
        "semantic_id_collision_extra_rows": collision_extra_rows,
        "root_cause_tasks": len(tasks),
        "functional_audit_rows": len(functional_rows),
        "functional_detail_rows": len(functional_detail_rows),
        "functional_raw_bins": f"{len(functional_covered)}/{len(functional_scoreable)}",
        "status_counts": dict(status_counts),
        "output_dir": str(args.output_dir),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
