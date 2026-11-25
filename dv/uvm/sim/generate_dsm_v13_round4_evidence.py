#!/usr/bin/env python3
"""Export Round 4 raw coverage, closure dispositions, and evidence hashes."""

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
DEFAULT_RUN = ROOT / "runs/dsm_v13_round4"
DEFAULT_DATA = ROOT / "docs/verification/data/dsm-v13-round4"
BASELINE_DATA = ROOT / "docs/verification/data/dsm-v13-round3"
BASELINE_REVISION = "9ae4e3fc574c34149930dca055d83528458be553"
CONFIGS = {
    "ef1_product": ("EF1", "EF1 Product"),
    "ef2_product": ("EF2", "EF2 Product"),
    "mash11_product": ("MASH 1-1", "MASH Product"),
    "ef1_axil": ("EF1", "EF1 AXI-Lite"),
    "ef2_axil": ("EF2", "EF2 AXI-Lite"),
    "mash11_axil": ("MASH 1-1", "MASH AXI-Lite"),
    "mash11_wrapper_core": ("MASH 1-1", "MASH wrapper/core"),
}
BLOCK_RUNS = [
    {"test_id": f"dpd_poly_order{order}", "scope": "DPD polynomial closure",
     "run_dir": f"runs/dsm_v13_round4/block_dpd/poly_order{order}",
     "report_dir": f"runs/dsm_v13_round4/block_dpd/poly_order{order}/urg",
     "coverage_vdb": f"runs/dsm_v13_round4/block_dpd/poly_order{order}/coverage.vdb",
     "run_log": f"runs/dsm_v13_round4/block_dpd/poly_order{order}/run.log",
     "pass_marker": f"DPD_POLY_CLOSURE_PASS order={order}",
     "vector_manifest": f"runs/dsm_v13_round4/block_dpd/poly_order{order}/vectors/manifest.json",
     "scope_note": "One independent Python-oracle block elaboration; not merged with Product URG."}
    for order in (3, 5, 7)
] + [
    {"test_id": "dpd_identity_exhaustive", "scope": "DPD identity exhaustive",
     "run_dir": "runs/dpd_identity_exhaustive",
     "report_dir": "runs/dsm_v13_round4/block_dpd/identity_urg",
     "coverage_vdb": "runs/dpd_identity_exhaustive/coverage.vdb",
     "run_log": "runs/dpd_identity_exhaustive/run.log",
     "pass_marker": "DPD_IDENTITY_EXHAUSTIVE_PASS",
     "scope_note": "Exhaustive 16-bit identity-domain check; separate block elaboration."},
    {"test_id": "dpd_memory_poly_random_protocol", "scope": "DPD memory-poly protocol",
     "run_dir": "runs/dpd_memory_poly_random_vcs",
     "report_dir": "runs/dsm_v13_round4/block_dpd/random_urg",
     "coverage_vdb": "runs/dpd_memory_poly_random_vcs/coverage.vdb",
     "run_log": "runs/dpd_memory_poly_random_vcs/sim.log",
     "pass_marker": "DPD_MEMORY_RANDOM_PROTOCOL_PASS",
     "scope_note": "Directed protocol randomization and one-tap identity oracle; separate block elaboration."},
    {"test_id": "dpd_vector16_fitted_4tap", "scope": "16-lane four-tap memory polynomial",
     "run_dir": "runs/dsm_v13_round4/block_dpd/fitted_4tap",
     "report_dir": "runs/dsm_v13_round4/block_dpd/fitted_4tap/urg",
     "coverage_vdb": "runs/dsm_v13_round4/block_dpd/fitted_4tap/coverage.vdb",
     "run_log": "runs/dsm_v13_round4/block_dpd/fitted_4tap/run.log",
     "pass_marker": "THERMO5_FITTED_DPD_RTL_BITTRUE_PASS",
     "vector_manifest": "runs/dsm_v13_round4/block_dpd/fitted_4tap_vectors/manifest.json",
     "scope_note": "Four-tap candidate arithmetic/bit-true test; does not change the frozen one-tap Product configuration."},
    {"test_id": "interp_centered_cubic_sustained", "scope": "Centered-cubic sustained block test",
     "run_dir": "runs/dsm_v13_round4/block_interp/centered",
     "report_dir": "runs/dsm_v13_round4/block_interp/centered/urg",
     "coverage_vdb": "runs/dsm_v13_round4/block_interp/centered/coverage.vdb",
     "run_log": "runs/dsm_v13_round4/block_interp/centered/run.log",
     "pass_marker": "CENTERED_CUBIC_SUSTAINED_PASS",
     "scope_note": "Sustained zero-bubble directed case only; not interpolator coverage closure."},
    {"test_id": "interp_polyphase_reachable", "scope": "Polyphase reachable block test",
     "run_dir": "runs/dsm_v13_round4/block_interp/polyphase",
     "report_dir": "runs/dsm_v13_round4/block_interp/polyphase/urg",
     "coverage_vdb": "runs/dsm_v13_round4/block_interp/polyphase/coverage.vdb",
     "run_log": "runs/dsm_v13_round4/block_interp/polyphase/run.log",
     "pass_marker": "INTERP_X2_REACHABLE_PASS",
     "scope_note": "Focused reachable states, bubble blocking, stalls and reset enable; not interpolator coverage closure."},
]
CODE_TYPES = {"Line", "Branch", "Condition", "Toggle", "FSM_Transitions", "FSM_States"}
CODE_TARGETS = {"Line": 95.0, "Branch": 95.0, "Condition": 95.0, "Toggle": 90.0}


def import_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import evidence parser: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


R2 = import_module("dsm_v13_r2_parser", ROOT / "dv/uvm/sim/generate_dsm_v13_round2_evidence.py")
R3 = import_module("dsm_v13_r3_parser", ROOT / "dv/uvm/sim/generate_dsm_v13_round3_evidence.py")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_digest(path: Path) -> dict:
    entries = sorted(item for item in path.rglob("*") if item.is_file())
    digest = hashlib.sha256()
    byte_count = 0
    for item in entries:
        item_hash = sha256(item)
        digest.update(item.relative_to(path).as_posix().encode("utf-8"))
        digest.update(b"\0")
        digest.update(item_hash.encode("ascii"))
        digest.update(b"\n")
        byte_count += item.stat().st_size
    return {"tree_sha256": digest.hexdigest(), "files": len(entries), "bytes": byte_count}


def block_coverage_records() -> tuple[list[dict], list[dict], list[dict]]:
    run_rows: list[dict] = []
    module_rows: list[dict] = []
    hole_rows: list[dict] = []
    for item in BLOCK_RUNS:
        log = ROOT / item["run_log"]
        report = ROOT / item["report_dir"]
        vdb = ROOT / item["coverage_vdb"]
        if not log.is_file() or not vdb.is_dir() or not (report / "modlist.html").is_file():
            raise SystemExit(f"block-level evidence is missing for {item['test_id']}")
        log_text = log.read_text(encoding="utf-8", errors="replace")
        test_status = "PASS" if item["pass_marker"] in log_text else "OPEN"
        if test_status != "PASS":
            raise SystemExit(f"block-level test lacks PASS marker: {item['test_id']}")
        vector_manifest = ROOT / item.get("vector_manifest", "") if item.get("vector_manifest") else None
        run_rows.append({
            "test_id": item["test_id"], "scope": item["scope"], "test_status": test_status,
            "pass_marker": item["pass_marker"], "scope_note": item["scope_note"],
            "run_log": relative(log), "run_log_sha256": sha256(log),
            "coverage_vdb": relative(vdb), "coverage_vdb_tree_sha256": tree_digest(vdb)["tree_sha256"],
            "urg_report": relative(report), "urg_report_sha256": sha256(report / "hierarchy.html"),
            "vector_manifest": relative(vector_manifest) if vector_manifest else "",
            "vector_manifest_sha256": sha256(vector_manifest) if vector_manifest and vector_manifest.is_file() else "",
        })
        holes, _ = R2.rtl_code_holes(report, "Block", item["test_id"])
        hole_counts: dict[str, int] = {}
        for hole in holes:
            module_page = Path(hole["evidence"].split("#", 1)[0]).name
            hole_counts[module_page] = hole_counts.get(module_page, 0) + 1
            hole_rows.append({**hole, "status": "OPEN",
                              "raw_adjusted_policy": "Block standalone raw equals adjusted; no waivers or exclusions.",
                              "evidence": hole["evidence"]})
        module_list_rows = R2.read_rows(report / "modlist.html")
        module_headers = next((R2.text_cells(row) for row in module_list_rows
                               if "NAME" in R2.text_cells(row) and "SCORE" in R2.text_cells(row)), [])
        for row in module_list_rows:
            cells = R2.text_cells(row)
            if not cells or cells[0] in ("", "NAME", "SCORE"):
                continue
            links = row[0]["links"] if row else []
            page_name = next((link for link in links if re.fullmatch(r"mod\d+\.html", link)), None)
            if not page_name:
                continue
            page = report / page_name
            source_path = module_source(page)
            if not source_path or "/rtl/" not in source_path.replace("\\", "/"):
                continue
            values = dict(zip(module_headers, cells))
            module = values.get("NAME") or Path(source_path).stem
            module_rows.append({
                "test_id": item["test_id"], "scope": item["scope"], "module": module,
                "source_path": source_path, "test_status": test_status,
                "raw_score_percent": values.get("SCORE", ""),
                "raw_line_percent": values.get("LINE", ""),
                "raw_branch_percent": values.get("BRANCH", ""),
                "raw_condition_percent": values.get("COND", ""),
                "raw_toggle_percent": values.get("TOGGLE", ""),
                "raw_fsm_percent": values.get("FSM", ""),
                "raw_assertion_percent": values.get("ASSERT", ""),
                "adjusted_equals_raw": "true", "approved_waivers": 0, "exclusions": 0,
                "open_raw_bins": hole_counts.get(page_name, 0),
                "closure_status": "OPEN" if hole_counts.get(page_name, 0) else "HIT_NO_RAW_HOLES",
                "scope_note": item["scope_note"], "urg_module_report": relative(page),
                "urg_module_report_sha256": sha256(page),
            })
    return run_rows, module_rows, hole_rows


def write_csv(path: Path, fields: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def norm(value: str) -> str:
    return " ".join((value or "").split())


def is_integer(value) -> bool:
    return isinstance(value, int) or (isinstance(value, str) and value.isdigit())


def code_key(row: dict) -> tuple[str, str, str, str, str]:
    return (row.get("configuration", ""), row.get("coverage_type", ""),
            row.get("source_location", ""), norm(row.get("rtl_expression", "")),
            norm(row.get("uncovered_bin", "")))


def code_source_key(row: dict) -> tuple[str, str, str, str]:
    return code_key(row)[:4]


def relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return path.resolve().as_posix()


def module_source(page: Path) -> str:
    source = page.read_text(encoding="utf-8", errors="replace")
    match = re.search(r"openSrcFile\('([^']+)'", source)
    return match.group(1) if match else ""


def parse_assertion_section(path: Path, section_name: str) -> list[dict]:
    source = path.read_text(encoding="utf-8", errors="replace")
    marker = section_name + ":"
    start = source.find(marker)
    if start < 0:
        return []
    end_candidates = [source.find(token + ":", start + len(marker)) for token in
                      ("Assertions Uncovered", "Assertions Success", "Assertions Failure",
                       "Assertions Without Attempts")]
    end_candidates = [item for item in end_candidates if item >= 0]
    end = min(end_candidates) if end_candidates else len(source)
    parser = R2.HtmlRows()
    parser.feed(source[start:end])
    result = []
    for row in parser.rows:
        cells = R2.text_cells(row)
        if (len(cells) < 7 or cells[0] in ("", "ASSERTIONS")
                or not all(re.fullmatch(r"\d+", value) for value in cells[3:7])):
            continue
        result.append({"assertion": cells[0], "attempts": int(cells[3]),
                       "real_successes": int(cells[4]), "failures": int(cells[5]),
                       "incomplete": int(cells[6])})
    return result


def source_manifest() -> list[dict]:
    # Compare with the frozen Round 3 baseline so source hashes remain present
    # after the Round 4 changes are committed.
    tracked = subprocess.check_output(["git", "diff", "--name-only", BASELINE_REVISION], cwd=ROOT, text=True).splitlines()
    untracked = subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    ignored = {
        "docs/verification/data/thermo5-r12/thermo5-tx-waivers-resolved-by-raw-hit.csv",
        *[f"docs/verification/data/thermo5-r12-whatif-20261106/{name}" for name in (
            "thermo5_tx_round12_candidate_audit.csv",
            "thermo5_tx_round12_github_local_waiver_diff.csv",
            "thermo5_tx_round12_raw_vs_whatif_metrics.csv",
            "thermo5_tx_round12_remaining_root_cause_summary.csv",
            "thermo5_tx_round12_toggle_root_cause_audit.csv",
            "thermo5_tx_round12_toggle_signal_groups.csv")],
    }
    evidence_prefix = "docs/verification/data/dsm-v13-round4/"
    files = sorted(name for name in set(tracked + untracked) - ignored
                   if not name.startswith(evidence_prefix))
    return [{"path": name, "sha256": sha256(ROOT / name), "bytes": (ROOT / name).stat().st_size,
             "role": "Round 4 source, test, or documentation change"}
            for name in files if (ROOT / name).is_file()]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--run-dir", type=Path, default=DEFAULT_RUN)
    ap.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    ap.add_argument("--mash-formal-dir", type=Path, default=DEFAULT_RUN / "formal_mash_reachability_v3")
    ap.add_argument("--frame-formal-dir", type=Path, default=DEFAULT_RUN / "formal_frame_tail")
    args = ap.parse_args()
    run_dir, data_dir = args.run_dir.resolve(), args.data_dir.resolve()
    urg_summary_path = run_dir / "round4_urg/summary.json"
    mash_formal_path = args.mash_formal_dir.resolve() / "run_result.json"
    frame_formal_path = args.frame_formal_dir.resolve() / "formal_summary.json"
    for required in (urg_summary_path, mash_formal_path, frame_formal_path,
                     BASELINE_DATA / "round3_raw_open_rtl_bins.csv",
                     BASELINE_DATA / "round3_remaining_open_records.csv",
                     BASELINE_DATA / "round3_code_coverage.csv"):
        if not required.is_file():
            raise SystemExit("required evidence is missing: " + str(required))
    urg = json.loads(urg_summary_path.read_text(encoding="utf-8"))
    mash_formal = json.loads(mash_formal_path.read_text(encoding="utf-8"))
    frame_formal = json.loads(frame_formal_path.read_text(encoding="utf-8"))
    if urg.get("status") != "PASS" or set(urg.get("configurations", {})) != set(CONFIGS):
        raise SystemExit("all seven independent Round 4 URG merges must PASS")
    if mash_formal.get("status") != "PASS" or frame_formal.get("status") != "PASS":
        raise SystemExit("required MASH and legal frame metadata proofs must PASS")

    assertion_isolation_rows: list[dict] = []
    isolated_incomplete: dict[str, dict] = {}
    isolation = urg.get("configurations", {}).get("mash11_axil", {}).get("assertion_isolation", {})
    if isolation.get("status") != "PASS" or not isolation.get("reports"):
        raise SystemExit("MASH AXI-Lite per-test assertion isolation evidence is missing")
    for item in isolation["reports"]:
        report = Path(item["report"])
        if not report.is_absolute():
            report = (ROOT / report).resolve()
        asserts_html = report / "asserts.html"
        if not asserts_html.is_file():
            raise SystemExit("isolated assertion report is missing: " + str(asserts_html))
        found: dict[str, dict] = {}
        for section_name in ("Assertions Uncovered", "Assertions Success", "Assertions Failure",
                             "Assertions Without Attempts"):
            state_name = section_name.replace("Assertions ", "").upper().replace(" ", "_")
            for assertion in parse_assertion_section(asserts_html, section_name):
                found[assertion["assertion"]] = {**assertion, "state": state_name}
        target_name = next((name for name in found if ".u_mash11.unnamed$$_16" in name), "")
        target = found.get(target_name, {})
        incomplete = int(target.get("incomplete", 0))
        failures = int(target.get("failures", 0))
        test_name = item.get("test_name", "")
        test_status = ("RESET_ABORT_EXPECTED" if incomplete > 0 and failures == 0
                       and "reset_sweep" in test_name else
                       "OPEN_INCOMPLETE" if incomplete > 0 else
                       "FAILURE" if failures > 0 else "PASS")
        if incomplete:
            isolated_incomplete[target_name] = {"test_name": test_name, "status": test_status,
                                                "incomplete": incomplete, "failures": failures}
        assertion_isolation_rows.append({
            "configuration": "MASH AXI-Lite", "test_name": test_name,
            "assertion": target_name, "attempts": target.get("attempts", ""),
            "real_successes": target.get("real_successes", ""),
            "failures": failures, "incomplete": incomplete,
            "isolated_disposition": test_status,
            "reason": ("The reset-sweep test performs legal reset epochs while a sampled attempt may be pending; the assertion has disable iff (!rst_n). Incomplete is retained and is not counted as success or failure."
                      if test_status == "RESET_ABORT_EXPECTED" else
                      "No incomplete attempt in this isolated positive test." if test_status == "PASS" else
                      "Unexplained failure or incomplete assertion attempt requires review."),
            "vdb": relative(Path(item["test_vdb"])),
            "urg_assertion_report": relative(asserts_html),
            "urg_assertion_report_sha256": sha256(asserts_html),
        })
    reset_abort_verified = (len(isolated_incomplete) == 1 and
                            next(iter(isolated_incomplete.values())).get("status") == "RESET_ABORT_EXPECTED" and
                            next(iter(isolated_incomplete.values())).get("incomplete") == 1 and
                            next(iter(isolated_incomplete.values())).get("failures") == 0)
    block_run_rows, block_module_rows, block_hole_rows = block_coverage_records()

    baseline_open = read_csv(BASELINE_DATA / "round3_remaining_open_records.csv")
    baseline_raw = read_csv(BASELINE_DATA / "round3_raw_open_rtl_bins.csv")
    baseline_code = read_csv(BASELINE_DATA / "round3_code_coverage.csv")
    baseline_functional = read_csv(BASELINE_DATA / "round3_functional_coverage.csv")
    baseline_cross = read_csv(BASELINE_DATA / "round3_cross_coverage.csv")
    old_raw_keys = {code_key(row) for row in baseline_raw}
    old_raw_sources = {code_source_key(row) for row in baseline_raw}
    r3_metric = {(row["configuration"], row["metric"]): row for row in baseline_code}
    r3_func = {(row["configuration"], row["coverpoint_or_group"]): row
               for row in baseline_functional if row["coverage_type"] == "UVM_or_RTL_covergroup"}
    r3_cross = {(row["configuration"], row["cross_name"]): row for row in baseline_cross}

    module_rows: list[dict] = []
    code_rows: list[dict] = []
    func_rows: list[dict] = []
    cross_rows: list[dict] = []
    assertion_rows: list[dict] = []
    assertion_detail_rows: list[dict] = []
    current_holes: list[dict] = []
    group_index: dict[tuple[str, str], dict] = {}
    cross_index: dict[tuple[str, str], dict] = {}
    config_metrics: dict[tuple[str, str], float | None] = {}
    baseline_missing_func_bins = sum(int(row["missing_bins"]) for row in baseline_functional
                                     if row.get("missing_bins", "").isdigit())
    baseline_missing_cross_bins = sum(int(row["missing_bins"]) for row in baseline_cross
                                      if row.get("missing_bins", "").isdigit())

    for config, (sku, label) in CONFIGS.items():
        record = urg["configurations"][config]
        report = Path(record["report"])
        if not report.is_absolute():
            report = (ROOT / report).resolve()
        hierarchy = report / "hierarchy.html"
        report_hash = sha256(hierarchy)
        raw_metrics = R2.parse_dut_code(hierarchy)
        metric_names = {"line": "Line", "branch": "Branch", "cond": "Condition",
                        "toggle": "Toggle", "fsm": "FSM", "assert": "Assertion"}
        for metric_key, metric_name in metric_names.items():
            value = R2.numeric(raw_metrics.get(metric_key))
            previous = R2.numeric(r3_metric.get((label, metric_name), {}).get("round3_raw_percent"))
            config_metrics[(label, metric_name)] = value
            target = CODE_TARGETS.get(metric_name)
            status = ("NOT_REPORTED" if value is None else
                      "EVIDENCE_ONLY" if target is None else
                      "PASS" if value >= target else "OPEN")
            code_rows.append({
                "sku": sku, "configuration": label, "scope": "selected DUT instance subtree, raw URG",
                "metric": metric_name, "round3_raw_percent": "" if previous is None else f"{previous:.2f}",
                "round4_raw_percent": "" if value is None else f"{value:.2f}",
                "delta_percentage_points": "" if value is None or previous is None else f"{value-previous:+.2f}",
                "round4_adjusted_percent": "" if value is None else f"{value:.2f}",
                "target_percent": "" if target is None else f"{target:.0f}", "status": status,
                "raw_adjusted_policy": "Raw equals adjusted; no waivers or exclusions applied.",
                "source_report": relative(hierarchy), "source_report_sha256": report_hash})

        holes, _ = R2.rtl_code_holes(report, sku, label)
        for hole in holes:
            row = dict(hole)
            row["configuration"] = label
            current_holes.append(row)

        current_by_module: dict[str, int] = {}
        current_by_module_type: dict[tuple[str, str], int] = {}
        for hole in holes:
            source = hole.get("source_location", "").split(":", 1)[0]
            module = Path(source).stem
            current_by_module[module] = current_by_module.get(module, 0) + 1
            key = (module, hole.get("coverage_type", ""))
            current_by_module_type[key] = current_by_module_type.get(key, 0) + 1
        module_list_rows = R2.read_rows(report / "modlist.html")
        module_headers = next((R2.text_cells(row) for row in module_list_rows
                               if "NAME" in R2.text_cells(row) and "SCORE" in R2.text_cells(row)), [])
        for row in module_list_rows:
            cells = R2.text_cells(row)
            if not cells or cells[0] in ("", "NAME", "SCORE"):
                continue
            links = row[0]["links"] if row else []
            page_name = next((link for link in links if re.fullmatch(r"mod\d+\.html", link)), None)
            if not page_name:
                continue
            source_path = module_source(report / page_name)
            if not source_path:
                continue
            module = Path(source_path).stem
            values = dict(zip(module_headers, cells))
            module_rows.append({
                "sku": sku, "configuration": label, "module": module,
                "source_path": source_path,
                "source_scope": "repository RTL" if "/rtl/" in source_path.replace("\\", "/") else "imported or generated source",
                "raw_score_percent": values.get("SCORE", ""), "adjusted_score_percent": values.get("SCORE", ""),
                "raw_line_percent": values.get("LINE", ""), "adjusted_line_percent": values.get("LINE", ""),
                "raw_branch_percent": values.get("BRANCH", ""), "adjusted_branch_percent": values.get("BRANCH", ""),
                "raw_condition_percent": values.get("COND", ""), "adjusted_condition_percent": values.get("COND", ""),
                "raw_toggle_percent": values.get("TOGGLE", ""), "adjusted_toggle_percent": values.get("TOGGLE", ""),
                "raw_fsm_percent": values.get("FSM", ""), "adjusted_fsm_percent": values.get("FSM", ""),
                "round4_open_raw_bins": current_by_module.get(module, 0),
                "round4_open_adjusted_bins": current_by_module.get(module, 0),
                "open_bin_counts_by_type": ";".join(
                    f"{kind}={count}" for (mod, kind), count in sorted(current_by_module_type.items()) if mod == module),
                "raw_adjusted_policy": "Raw equals adjusted; no waivers or exclusions applied.",
                "source_report": relative(report / page_name)})

        total_score, groups = R2.group_records(report)
        groups_path = report / "groups.html"
        group_hash = sha256(groups_path) if groups_path.is_file() else ""
        if total_score is not None:
            func_rows.append({"sku": sku, "configuration": label,
                              "group": "ALL_APPLICABLE_GROUPS", "score_percent": f"{total_score:.2f}",
                              "covered_bins": "", "expected_bins": "", "missing_bins": "",
                              "baseline_round3_score_percent": "", "delta_percentage_points": "",
                              "status": "PASS" if total_score >= 98.0 else "OPEN",
                              "uncovered_bins": "",
                              "raw_denominator_note": "The report score is informational; exact group/cross bins follow." ,
                              "source_report": relative(groups_path), "source_report_sha256": group_hash})
        else:
            func_rows.append({"sku": sku, "configuration": label,
                              "group": "NO_SHARED_PRODUCT_COVERGROUPS", "score_percent": "",
                              "covered_bins": "", "expected_bins": "", "missing_bins": "",
                              "baseline_round3_score_percent": "", "delta_percentage_points": "",
                              "status": "NOT_APPLICABLE",
                              "uncovered_bins": "",
                              "raw_denominator_note": "Legacy wrapper/core is a separate elaboration and uses its block-level scoreboard coverage; it is not merged into Product URG.",
                              "source_report": relative(report), "source_report_sha256": ""})
        for group in groups:
            group_index[(label, group["name"])] = group
            previous = r3_func.get((label, group["name"]), {})
            prev_score = R2.numeric(previous.get("score_percent"))
            func_rows.append({"sku": sku, "configuration": label,
                              "group": group["name"], "score_percent": f"{group['score']:.2f}",
                              "covered_bins": group["covered"], "expected_bins": group["expected"],
                              "missing_bins": group["missing"],
                              "baseline_round3_score_percent": "" if prev_score is None else f"{prev_score:.2f}",
                              "delta_percentage_points": "" if prev_score is None else f"{group['score']-prev_score:+.2f}",
                              "status": "PASS" if group["missing"] == 0 else "APPROVAL_PENDING" if sku == "MASH 1-1" else "OPEN",
                              "uncovered_bins": "; ".join(f"{name}: {', '.join(bins)}" for name, bins in group["uncovered_bins"].items()),
                              "source_report": relative(group["page"]), "source_report_sha256": sha256(group["page"])})
            for cross in group["crosses"]:
                cross_index[(label, cross["name"])] = {**cross, "group": group["name"], "page": group["page"]}
                previous_cross = r3_cross.get((label, cross["name"]), {})
                cross_rows.append({"sku": sku, "configuration": label,
                                   "cross_group": group["name"], "cross": cross["name"],
                                   "covered_bins": cross["covered"], "expected_bins": cross["expected"],
                                   "missing_bins": cross["uncovered"], "score_percent": f"{cross['percent']:.2f}",
                                   "baseline_round3_missing_bins": previous_cross.get("missing_bins", ""),
                                   "status": "HIT" if cross["uncovered"] == 0 else "APPROVAL_PENDING" if sku == "MASH 1-1" and cross["name"] == "x_input_range_stage1" else "OPEN",
                                   "uncovered_bins": "; ".join(cross["uncovered_bins"]),
                                   "source_location": cross["source_location"],
                                   "source_report": relative(group["page"]),
                                   "source_report_sha256": sha256(group["page"])})

        full_asserts = report / "asserts.html"
        positive_asserts = run_dir / "assertions_positive_only" / config / "asserts.html"
        full_summary = R2.parse_assertion_summary(full_asserts)
        positive_summary = R2.parse_assertion_summary(positive_asserts)
        positive_assertion_inventory: dict[str, dict] = {}
        for section_name in ("Assertions Uncovered", "Assertions Success", "Assertions Failure",
                             "Assertions Without Attempts"):
            for item in parse_assertion_section(positive_asserts, section_name):
                positive_assertion_inventory[item["assertion"]] = item
        positive_incomplete = sum(item["incomplete"] for item in positive_assertion_inventory.values())
        config_assertion_status = (
            "PASS_WITH_EXPECTED_RESET_ABORT" if label == "MASH AXI-Lite" and reset_abort_verified
            and positive_summary.get("Failure", 0) == 0 else
            "PASS" if positive_summary.get("Failure", 0) == 0 and positive_incomplete == 0 else "OPEN")
        assertion_rows.append({"sku": sku, "configuration": label,
                               "full_merged_assertions": full_summary.get("Total Number", ""),
                               "full_uncovered": full_summary.get("Uncovered", ""),
                               "full_success": full_summary.get("Success", ""),
                               "full_failures_including_expected_negative": full_summary.get("Failure", ""),
                               "full_without_attempts": full_summary.get("Without Attempts", ""),
                               "legal_positive_failures": positive_summary.get("Failure", ""),
                               "legal_positive_incomplete_attempts": positive_incomplete,
                               "legal_positive_without_attempts": positive_summary.get("Without Attempts", ""),
                               "legal_positive_uncovered": positive_summary.get("Uncovered", ""),
                               "status": config_assertion_status,
                               "full_assertion_report": relative(full_asserts),
                               "positive_assertion_report": relative(positive_asserts)})
        full_by_name: dict[str, dict] = {}
        for section_name in ("Assertions Uncovered", "Assertions Success", "Assertions Failure", "Assertions Without Attempts"):
            section_state = section_name.replace("Assertions ", "").upper().replace(" ", "_")
            for item in parse_assertion_section(full_asserts, section_name):
                full_by_name[item["assertion"]] = {**item, "full_state": section_state}
        positive_by_name: dict[str, dict] = {}
        for section_name in ("Assertions Uncovered", "Assertions Success", "Assertions Failure", "Assertions Without Attempts"):
            section_state = section_name.replace("Assertions ", "").upper().replace(" ", "_")
            for item in parse_assertion_section(positive_asserts, section_name):
                positive_by_name[item["assertion"]] = {**item, "positive_state": section_state}
        for name in sorted(set(full_by_name) | set(positive_by_name)):
            full = full_by_name.get(name, {})
            positive = positive_by_name.get(name, {})
            source = ""
            for item in R2.read_rows(full_asserts):
                cells = R2.text_cells(item)
                if cells and cells[0] == name and item[0]["links"]:
                    break
            full_failure = int(full.get("failures", 0))
            pos_failure = int(positive.get("failures", 0))
            full_incomplete = int(full.get("incomplete", 0))
            pos_incomplete = int(positive.get("incomplete", 0))
            state = full.get("full_state", positive.get("positive_state", "UNKNOWN"))
            negative_delta = max(0, full_failure - pos_failure)
            isolated = isolated_incomplete.get(name, {})
            disposition = "EXPECTED_NEGATIVE" if negative_delta else (
                "PROVEN_UNREACHABLE" if name.endswith("u_interp_1.unnamed$$_1") or name.endswith("u_interp_2.unnamed$$_1")
                else "NOT_APPLICABLE" if "uvm_pkg" in name else
                "FAILURE" if pos_failure else
                "RESET_ABORT_EXPECTED" if pos_incomplete and reset_abort_verified
                and isolated.get("status") == "RESET_ABORT_EXPECTED" else
                "OPEN_INCOMPLETE" if pos_incomplete else state)
            assertion_detail_rows.append({"configuration": label, "assertion": name,
                                          "attempts_full": full.get("attempts", ""),
                                          "successes_full": full.get("real_successes", ""),
                                          "failures_full": full_failure,
                                          "incomplete_full": full_incomplete,
                                          "attempts_legal_positive": positive.get("attempts", ""),
                                          "successes_legal_positive": positive.get("real_successes", ""),
                                          "failures_legal_positive": pos_failure,
                                          "incomplete_legal_positive": pos_incomplete,
                                          "uncovered_status_legal_positive": positive.get("positive_state", ""),
                                          "disposition": disposition,
                                          "negative_failure_count": negative_delta,
                                          "incomplete_test": isolated.get("test_name", ""),
                                          "formal_property": "a_append_legal_frame_end_context / a_plain_legal_frame_end_context" if disposition == "PROVEN_UNREACHABLE" else "",
                                          "formal_scope": "Exact centered-cubic product frame metadata; legal 32-beat AXIS packet contract" if disposition == "PROVEN_UNREACHABLE" else ""})

    raw_hole_rows = []
    for hole in current_holes:
        raw_hole_rows.append({"sku": hole["sku"], "configuration": hole["configuration"],
                              "coverage_id": hole["coverage_id"], "coverage_type": hole["coverage_type"],
                              "source_location": hole["source_location"], "rtl_expression": hole["rtl_expression"],
                              "uncovered_bin": hole["uncovered_bin"], "status": "OPEN",
                              "raw_adjusted_policy": "Raw equals adjusted; no exclusions or waivers.",
                              "evidence": hole["evidence"]})
    current_raw_keys = {code_key(row) for row in raw_hole_rows}
    current_raw_sources = {code_source_key(row) for row in raw_hole_rows}

    # Keep every frozen Round 3 OPEN record and attach only evidence-backed dispositions.
    disposition_rows: list[dict] = []
    metric_id = {"CODE_LINE": "Line", "CODE_BRANCH": "Branch", "CODE_CONDITION": "Condition", "CODE_TOGGLE": "Toggle"}
    for old in baseline_open:
        config = old.get("configuration", "")
        kind = old.get("coverage_type", "")
        status, reason, evidence = "OPEN_UNMAPPED", "No exact Round 4 evidence joined; keep OPEN.", ""
        if kind in CODE_TYPES:
            key = code_key(old)
            exact_in_baseline_inventory = key in old_raw_keys
            if key in current_raw_keys:
                status, reason = "OPEN", "The same raw code bin remains uncovered in Round 4."
            elif exact_in_baseline_inventory:
                status, reason = "HIT", "This exact Round 3 raw code bin is absent from the fresh Round 4 raw inventory."
            elif code_source_key(old) in current_raw_sources:
                status, reason = "OPEN", "The same source expression remains open; the Round 3 matrix row is not an exact raw-bin record."
            else:
                status, reason = "OPEN_UNMAPPED", "Round 3 matrix entry does not map to the raw-bin inventory; do not infer a hit."
            evidence = old.get("evidence", "")
        elif kind == "CODE_METRIC_AGGREGATE":
            metric = metric_id.get(old.get("coverage_id", ""))
            value = config_metrics.get((config, metric or ""))
            target = CODE_TARGETS.get(metric or "")
            status = "HIT" if value is not None and target is not None and value >= target else "OPEN"
            reason = "Current raw metric meets target." if status == "HIT" else "Current raw metric remains below the frozen final target."
            evidence = next((row["source_report"] for row in code_rows if row["configuration"] == config and row["metric"] == metric), "")
        elif kind == "FUNCTIONAL_GROUP_BINS":
            group = group_index.get((config, old.get("coverage_id", "")))
            if group and group["missing"] == 0:
                if old.get("coverage_id") == "transaction_event_cg" and "Product" in config:
                    status, reason = "NOT_APPLICABLE", "AXI-Lite-only event bins are absent from Product-only elaborations; Round 3 raw row retained."
                else:
                    status, reason = "HIT", "The matching current URG covergroup has zero uncovered bins."
                evidence = relative(group["page"])
            elif group and config.startswith("MASH") and old.get("coverage_id") in ("mash11_product_cg", "quantizer_input_range_cg"):
                status, reason = "APPROVAL_PENDING", "Raw bin remains uncovered; Round 4 formal proof supports a waiver proposal, not an applied exclusion."
                evidence = relative(group["page"])
            else:
                status, reason = "OPEN", "Matching Round 4 covergroup still has uncovered bins or was not found."
        elif kind == "FUNCTIONAL_CROSS_BIN":
            cross = cross_index.get((config, old.get("coverage_id", "")))
            if cross and cross["uncovered"] == 0:
                status, reason, evidence = "HIT", "All bins in the matching current cross are hit.", relative(cross["page"])
            elif cross and config.startswith("MASH") and old.get("coverage_id") == "x_input_range_stage1":
                status, reason, evidence = "APPROVAL_PENDING", "Maximum-rail × negative Stage1 hit; minimum-rail × positive Stage1 is formally proven unreachable and awaits review.", relative(cross["page"])
            else:
                status, reason = "OPEN", "The matching Round 4 cross still has uncovered bins or was not found."
        elif kind == "FSM_Transitions":
            key = code_key(old)
            if key in current_raw_keys:
                status, reason = "OPEN", "This exact FSM transition remains a fresh raw hole."
            elif key in old_raw_keys:
                status, reason = "HIT", "The exact Round 3 uncovered FSM transition is no longer in the fresh raw inventory."
            else:
                status, reason = "OPEN_UNMAPPED", "The transition row has no exact Round 3 raw inventory mapping."
            evidence = next((row["source_report"] for row in code_rows if row["configuration"] == config and row["metric"] == "FSM"), "")
        elif kind == "MASH_REACHABILITY_OR_INTEGRATION":
            if old.get("coverage_id") in ("MASH_weighted_levels_minus2_zero", "MASH_weighted_levels_minus4_plus4"):
                status, reason = "APPROVAL_PENDING", "MASH Formal proves the weighted-level set; Raw bins remain and no waiver was applied."
                evidence = relative(mash_formal_path)
            else:
                status, reason = "OPEN", "Physical PA weight/polarity or MATLAB latency alignment remains outside the proved scope."
        elif kind == "SIGNOFF_GAP":
            status, reason = "OPEN", "CDC/RDC, timing/PPA, and board/RF sign-off were not run in this Round 4 DV scope."
        disposition_rows.append({**old, "round4_status": status, "round4_reason": reason,
                                 "round4_evidence": evidence,
                                 "round4_waiver_status": "APPROVAL_PENDING" if status == "APPROVAL_PENDING" else "NONE"})

    remaining_rows = [row for row in disposition_rows if row["round4_status"] not in ("HIT", "NOT_APPLICABLE")]
    status_counts: dict[str, int] = {}
    type_counts: dict[str, dict[str, int]] = {}
    for row in disposition_rows:
        status_counts[row["round4_status"]] = status_counts.get(row["round4_status"], 0) + 1
        bucket = type_counts.setdefault(row["coverage_type"], {"baseline_open": 0})
        bucket["baseline_open"] += 1
        key = row["round4_status"].lower()
        bucket[key] = bucket.get(key, 0) + 1
    all_status_keys = sorted({status.lower() for status in status_counts})
    burndown_rows = [{"coverage_type": kind, "baseline_open": counts["baseline_open"],
                      **{key: counts.get(key, 0) for key in all_status_keys}}
                     for kind, counts in sorted(type_counts.items())]

    fsm_rows = []
    disposition_index = {
        (row.get("configuration", ""), row.get("coverage_id", ""), row.get("uncovered_bin", "")): row
        for row in disposition_rows
    }
    for old in baseline_open:
        if old.get("coverage_type") != "FSM_Transitions":
            continue
        disposition = disposition_index[(old.get("configuration", ""),
                                         old.get("coverage_id", ""),
                                         old.get("uncovered_bin", ""))]
        fsm_rows.append({"configuration": old["configuration"], "source_location": old["source_location"],
                         "transition": old["uncovered_bin"], "round3_status": old.get("round3_status", "OPEN"),
                         "round4_status": disposition["round4_status"],
                         "evidence": disposition["round4_evidence"], "reason": disposition["round4_reason"]})

    waiver_rows = []
    for config in ("MASH Product", "MASH AXI-Lite"):
        for level in ("minus4", "minus2", "zero", "plus4"):
            waiver_rows.append({"configuration": config, "coverage_id": f"mash11_product_cg.cp_raw_weighted_level.{level}",
                                "status": "PROVEN_UNREACHABLE", "approval_status": "APPROVAL_PENDING",
                                "raw_bin_retained": "true", "adjusted_exclusion_applied": "false",
                                "formal_property": "a_no_unreachable_weighted_level",
                                "proof_scope": "W16/ACC18, 4-plane MASH 1-1 reset-constrained DUT contract; sequential formal proof",
                                "evidence": relative(mash_formal_path)})
        waiver_rows.append({"configuration": config, "coverage_id": "quantizer_input_range_cg.x_input_range_stage1.minimum_rail_positive",
                            "status": "PROVEN_UNREACHABLE", "approval_status": "APPROVAL_PENDING",
                            "raw_bin_retained": "true", "adjusted_exclusion_applied": "false",
                            "formal_property": "a_minimum_rail_never_stage1_positive",
                            "proof_scope": "W16/ACC18, 4-plane MASH 1-1 reset-constrained DUT contract; exact input-range sampling",
                            "evidence": relative(mash_formal_path)})
    waiver_rows.append({"configuration": "MASH Product", "coverage_id": "quantizer_input_range_cg.x_input_range_stage1.maximum_rail_negative",
                        "status": "HIT", "approval_status": "NOT_REQUIRED", "raw_bin_retained": "true",
                        "adjusted_exclusion_applied": "false", "formal_property": "",
                        "proof_scope": "Directed product-level rail-history replay; I/Q maximum rail × negative Stage1 observed",
                        "evidence": "runs/dsm_v13_round4/mash11_product/thermo5_sku_bittrue_test_seed440418.log"})
    waiver_rows.append({"configuration": "MASH AXI-Lite", "coverage_id": "quantizer_input_range_cg.x_input_range_stage1.maximum_rail_negative",
                        "status": "HIT", "approval_status": "NOT_REQUIRED", "raw_bin_retained": "true",
                        "adjusted_exclusion_applied": "false", "formal_property": "",
                        "proof_scope": "Directed product-level rail-history replay; maximum rail × negative Stage1 observed",
                        "evidence": "runs/dsm_v13_round4/mash11_axil/thermo5_sku_axil_mash11_rail_history_test_seed440529.log"})

    raw_code_exact_hits = len(old_raw_keys - current_raw_keys)
    current_functional_missing = sum(int(row["missing_bins"]) for row in func_rows
                                     if is_integer(row.get("missing_bins", "")))
    current_cross_missing = sum(int(row["missing_bins"]) for row in cross_rows
                                if is_integer(row.get("missing_bins", "")))
    applicable_fix_bins = sum(1 for row in baseline_functional
                              if row.get("coverage_type") == "UVM_or_RTL_covergroup"
                              and row.get("coverpoint_or_group") == "transaction_event_cg"
                              and "Product" in row.get("configuration", "")
                              and row.get("missing_bins", "").isdigit())
    # Each Product elaboration has the same three AXI-Lite-only raw bins.
    functional_unique_hits = max(0, baseline_missing_func_bins - current_functional_missing - applicable_fix_bins)
    summary = {
        "schema": "dsm_v13_round4_coverage_evidence_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_source_revision": BASELINE_REVISION,
        "source_revision_at_generation": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "run_directory": relative(run_dir), "coverage_policy": "Raw equals adjusted; zero approved waivers/exclusions; no cross-SKU or incompatible-elaboration merge.",
        "status": "OPEN", "final_dv_signoff": False,
        "baseline_round3_open_records": len(baseline_open),
        "round4_open_record_dispositions": status_counts,
        "round3_raw_rtl_open_bins": len(baseline_raw), "round4_raw_rtl_open_bins": len(raw_hole_rows),
        "round3_to_round4_exact_raw_code_hits": raw_code_exact_hits,
        "round3_fsm_transition_records": len(fsm_rows),
        "round4_fsm_transition_hit_records": sum(row["round4_status"] == "HIT" for row in fsm_rows),
        "round3_functional_group_missing_bins": baseline_missing_func_bins,
        "round4_functional_group_missing_bins": current_functional_missing,
        "round3_cross_missing_bins_subset": baseline_missing_cross_bins,
        "round4_cross_missing_bins_subset": current_cross_missing,
        "round3_functional_group_records": sum(row["coverage_type"] == "FUNCTIONAL_GROUP_BINS" for row in baseline_open),
        "round4_functional_group_hit_records": sum(row["coverage_type"] == "FUNCTIONAL_GROUP_BINS" and row["round4_status"] == "HIT" for row in disposition_rows),
        "round4_functional_group_not_applicable_records": sum(row["coverage_type"] == "FUNCTIONAL_GROUP_BINS" and row["round4_status"] == "NOT_APPLICABLE" for row in disposition_rows),
        "round4_functional_cross_hit_records": sum(row["coverage_type"] == "FUNCTIONAL_CROSS_BIN" and row["round4_status"] == "HIT" for row in disposition_rows),
        "round4_formally_proven_unreachable_raw_records": sum(row["round4_status"] == "APPROVAL_PENDING" for row in disposition_rows),
        "round4_assertion_isolated_incomplete_attempts": sum(int(row["incomplete"]) for row in assertion_isolation_rows),
        "round4_assertion_incomplete_disposition": ("RESET_ABORT_EXPECTED; retained in raw assertion data; not a failure or success"
                                                     if reset_abort_verified else "OPEN_REVIEW_REQUIRED"),
        "round4_block_level_test_runs": len(block_run_rows),
        "round4_block_level_module_rows": len(block_module_rows),
        "round4_block_level_raw_open_bins": len(block_hole_rows),
        "unique_functional_bins_hit_estimate": functional_unique_hits,
        "product_only_not_applicable_bins": applicable_fix_bins,
        "current_uncovered_functional_bins_include_crosses": current_functional_missing,
        "mash_proof_status": mash_formal["status"], "frame_metadata_formal_status": frame_formal["status"],
        "unapproved_applied_waivers": 0,
        "limitations": [
            "MASH raw weighted levels -4, -2, 0, +4 and minimum-rail × positive Stage1 remain raw OPEN pending independent approval despite sequential formal proof.",
            "All selected Product/AXI-Lite raw code metrics remain below final targets; current raw RTL hole inventory is preserved.",
            "Round 3 matrix contains non-raw duplicate/aggregate code rows; unmapped rows remain OPEN_UNMAPPED rather than being counted as hits.",
            "Physical serializer, MATLAB bit-true latency, CDC/RDC, STA/PPA, and board/RF sign-off are outside the completed evidence.",
        ],
    }

    data_dir.mkdir(parents=True, exist_ok=True)
    write_csv(data_dir / "round4_code_coverage.csv", list(code_rows[0]), code_rows)
    write_csv(data_dir / "round4_module_code_coverage.csv", list(module_rows[0]), module_rows)
    write_csv(data_dir / "round4_raw_open_rtl_bins.csv", list(raw_hole_rows[0]), raw_hole_rows)
    write_csv(data_dir / "round4_functional_coverage.csv", list(func_rows[0]), func_rows)
    write_csv(data_dir / "round4_cross_coverage.csv", list(cross_rows[0]), cross_rows)
    write_csv(data_dir / "round4_assertion_coverage.csv", list(assertion_rows[0]), assertion_rows)
    write_csv(data_dir / "round4_assertion_disposition.csv", list(assertion_detail_rows[0]), assertion_detail_rows)
    write_csv(data_dir / "round4_assertion_isolation.csv", list(assertion_isolation_rows[0]), assertion_isolation_rows)
    write_csv(data_dir / "round4_block_level_runs.csv", list(block_run_rows[0]), block_run_rows)
    write_csv(data_dir / "round4_block_level_code_coverage.csv", list(block_module_rows[0]), block_module_rows)
    write_csv(data_dir / "round4_block_raw_open_rtl_bins.csv", list(block_hole_rows[0]), block_hole_rows)
    write_csv(data_dir / "round4_fsm_transition_closure.csv", list(fsm_rows[0]), fsm_rows)
    write_csv(data_dir / "round4_waiver_proposal.csv", list(waiver_rows[0]), waiver_rows)
    write_csv(data_dir / "round4_coverage_disposition.csv", list(disposition_rows[0]), disposition_rows)
    write_csv(data_dir / "round4_remaining_open_records.csv", list(remaining_rows[0]), remaining_rows)
    write_csv(data_dir / "round4_hole_burndown.csv", list(burndown_rows[0]), burndown_rows)
    (data_dir / "round4_coverage_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    formal_evidence = {
        "schema": "dsm_v13_round4_formal_evidence_v1",
        "mash_reachability": mash_formal,
        "legal_frame_metadata": frame_formal,
        "assumption_audit": {
            "mash": "The only environment constraint is source payload stability while valid is held without ready; reset is the harness's real reset sequence.",
            "frame_metadata": "Only legal source ready/valid stability is assumed; exact Product centered-cubic geometries and packet/frame marker schedule are instantiated.",
            "nonvacuity": "MASH required Covers are all hit. Frame metadata source stability is non-vacuous; legal packet-end/tail transfer Covers are hit; the two active q1_tail antecedent Covers are proven uncoverable.",
            "waiver": "No URG exclusion has been applied. MASH proposal records remain APPROVAL_PENDING.",
        },
    }
    (data_dir / "round4_formal_evidence.json").write_text(json.dumps(formal_evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    vdb_records = []
    log_records = []
    report_records = []
    for config, rec in urg["configurations"].items():
        design = Path(rec["design_vdb"])
        vdb_records.append({"configuration": config, "role": "design", "path": relative(design), **tree_digest(design)})
        for item in rec["test_vdbs"]:
            path = Path(item)
            vdb_records.append({"configuration": config, "role": "test", "path": relative(path), **tree_digest(path)})
        for name, digest in rec.get("positive_log_sha256", {}).items():
            log_records.append({"configuration": config, "path": relative(Path(run_dir / config / name)), "sha256": digest})
        if rec.get("report"):
            report = Path(rec["report"])
            for name in ("hierarchy.html", "groups.html", "asserts.html", "modlist.html"):
                path = report / name
                if path.is_file():
                    report_records.append({"configuration": config, "path": relative(path), "sha256": sha256(path), "bytes": path.stat().st_size})
    manifest = {"schema": "dsm_v13_round4_regression_manifest_v1",
                "generated_utc": datetime.now(timezone.utc).isoformat(),
                "source_revision": summary["source_revision_at_generation"],
                "baseline_revision": summary["baseline_source_revision"],
                "tools": {"vcs_urg": "V-2023.12-SP1", "vc_formal": "V-2023.12-SP2"},
                "urg_summary": {"path": relative(urg_summary_path), "sha256": sha256(urg_summary_path), "status": urg["status"]},
                "source_changes": source_manifest(), "vdbs": vdb_records, "logs": log_records,
                "urg_reports": report_records, "formal_evidence": [
                    {"path": relative(mash_formal_path), "sha256": sha256(mash_formal_path)},
                    {"path": relative(frame_formal_path), "sha256": sha256(frame_formal_path)}],
                "assertion_isolation_reports": [
                    {"test": row["test_name"], "vdb": row["vdb"],
                     "path": row["urg_assertion_report"], "sha256": row["urg_assertion_report_sha256"]}
                    for row in assertion_isolation_rows],
                "block_level_runs": block_run_rows,
                "diagnostic_runs": ([
                    {"path": relative(data_dir / "round4_early_restart_reproducer.json"),
                     "sha256": sha256(data_dir / "round4_early_restart_reproducer.json"),
                     "classification": "FAIL_REPRODUCED; excluded from passing VDB merges"}
                ] if (data_dir / "round4_early_restart_reproducer.json").is_file() else []),
                "negative_test_policy": "Malformed-frame VDBs are retained in per-config reports; assertion outcomes are separately compared against positive-only URG runs."}
    (data_dir / "round4_regression_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print("DSM_V13_R4_EVIDENCE_GENERATION=PASS")
    print(f"DSM_V13_R4_CURRENT_RAW_CODE_OPEN={len(raw_hole_rows)} baseline_exact_hits={raw_code_exact_hits}")
    print(f"DSM_V13_R4_FUNCTIONAL_GROUP_MISSING={current_functional_missing} baseline={baseline_missing_func_bins} product_not_applicable={applicable_fix_bins}")
    print(f"DSM_V13_R4_FUNCTIONAL_CROSS_MISSING={current_cross_missing} baseline_subset={baseline_missing_cross_bins}")
    print(f"DSM_V13_R4_BASELINE_DISPOSITIONS={status_counts}")
    print("DSM_V13_R4_EVIDENCE_DIR=" + relative(data_dir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
