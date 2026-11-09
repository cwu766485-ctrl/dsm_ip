#!/usr/bin/env python3.12
"""Run strict Round 17 URG with supplemental directed coverage VDBs.

This adds explicitly named same-product directed Test VDBs to the frozen
Round 17 Design + 551-Test set. It emits separate Raw and Analysis-only
What-if reports; it never modifies the frozen baseline or official waivers.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import html
import importlib.util
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DATA = ROOT / "docs/verification/data/thermo5-r17/analysis_only"
DEFAULT_RUNS = ROOT / "runs/thermo5_r17_residual_whatif_20261109_run2"
DEFAULT_BASE = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_raw_retry2"
DEFAULT_COMPILE = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
DEFAULT_EXTRA = ROOT / "runs/thermo5_r17_counter_highbit_20261109/supplemental_vcs"
METRICS = ("branch", "cond", "line", "toggle")


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load helper: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


residual = load_module("thermo5_tx_r17_residual_whatif", ROOT / "tools/hw/thermo5_tx_r17_residual_whatif.py")
frozen = load_module("thermo5_tx_frozen_vcs", ROOT / "dv/uvm/sim/run_thermo5_frozen_regression.py")
audit = load_module("thermo5_tx_audit_reports", ROOT / "tools/hw/thermo5_audit_reports.py")


def sha256_file(path: Path) -> str:
    return residual.sha256_file(path)


def load_gzip_csv(path: Path) -> list[dict[str, str]]:
    return residual.load_gzip_csv(path)


def toggle_rows(report: Path) -> dict[tuple[str, str], dict[str, bool]]:
    """Read exact URG signal/bit transition status from native module pages."""
    result: dict[tuple[str, str], dict[str, bool]] = {}
    for path in sorted(report.glob("mod*.html")):
        page = path.read_text(encoding="utf-8", errors="replace")
        for tag, block, single in audit.instance_blocks(page):
            name_match = re.search(
                r'(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>',
                block, re.S)
            if not name_match:
                continue
            instance = html.unescape(re.sub(r"<[^>]+>", "", name_match[1])).strip()
            if not instance.startswith("thermo5_sku_uvm_tb.dut"):
                continue
            prefix = "" if single else tag + "_"
            anchor = re.search(r'<a name="' + re.escape(prefix) + r'Toggle"></a>', block)
            if not anchor:
                continue
            section = block[anchor.end():]
            end = re.search(
                r'<a name="' + re.escape(prefix) + r'(?:Line|Cond|Branch|FSM|Assert)"></a>',
                section)
            if end:
                section = section[:end.start()]
            parser = frozen.TableRows()
            parser.feed(section)
            for row in parser.rows:
                if len(row) < 4 or not row[0]:
                    continue
                # URG columns are Name, Toggle, Toggle 1->0, Toggle 0->1.
                if row[1] not in ("Yes", "No") or row[2] not in ("Yes", "No") or row[3] not in ("Yes", "No"):
                    continue
                status = {"1_to_0": row[2] == "Yes", "0_to_1": row[3] == "Yes"}
                vector = re.fullmatch(r"(.+)\[(\d+):(\d+)\]", row[0])
                if vector:
                    signal, left, right = vector.groups()
                    lo, hi = sorted((int(left), int(right)))
                    for bit in range(lo, hi + 1):
                        result[(instance, f"{signal}[{bit}]")] = status
                else:
                    result[(instance, row[0])] = status
    return result


def target_native(row: dict[str, str]) -> tuple[str, str] | None:
    match = re.fullmatch(r"(?:Signal|Port) Details:([^:]+):(0_to_1|1_to_0)", row["exact_urg_bin"])
    if not match:
        return None
    signal, direction = match.groups()
    return signal, {"0_to_1": "0_to_1", "1_to_0": "1_to_0"}[direction]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extra-test-vdb", type=Path, action="append", required=True,
                        help="supplemental directed Test VDB; repeat for each Test VDB")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--base-dir", type=Path, default=DEFAULT_BASE)
    parser.add_argument("--raw-whatif-run-dir", type=Path, default=DEFAULT_RUNS)
    parser.add_argument("--compile-manifest", type=Path, default=DEFAULT_COMPILE)
    parser.add_argument("--extra-run-dir", type=Path, default=DEFAULT_EXTRA)
    args = parser.parse_args()

    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    data_dir = args.data_dir.resolve()
    base_manifest_path = args.base_dir / "input_vdb_manifest.json"
    base_run_path = args.base_dir / "run_manifest.json"
    base_manifest = json.loads(base_manifest_path.read_text(encoding="utf-8"))
    base_run = json.loads(base_run_path.read_text(encoding="utf-8"))
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    if len(base_manifest.get("tests", [])) != 551 or not base_manifest.get("design"):
        raise RuntimeError("Expected the frozen one-Design plus 551-Test VDB baseline")
    if len(args.extra_test_vdb) != 2:
        raise RuntimeError("This directed closure package requires exactly the long-stream and AXI-Lite register VDBs")

    test_log_dir = args.extra_run_dir.resolve()
    run_logs = {
        "long_stream": test_log_dir / "thermo5_sku_axil_config_test_seed271030.log",
        "axil_register": test_log_dir / "thermo5_sku_axil_register_access_test_seed271032.log",
    }
    pass_markers = {
        "long_stream": "THERMO5_AXIL_CONFIG_UVM_PASS",
        "axil_register": "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS",
    }
    for key, log in run_logs.items():
        if not log.is_file():
            raise RuntimeError(f"Missing directed-test log: {log}")
        text = log.read_text(encoding="utf-8", errors="replace")
        if (pass_markers[key] not in text or
                not re.search(r"UVM_WARNING\s*:\s*0", text) or
                not re.search(r"UVM_ERROR\s*:\s*0", text) or
                not re.search(r"UVM_FATAL\s*:\s*0", text)):
            raise RuntimeError(f"Directed test did not meet its UVM PASS contract: {log}")
        if "Warning-[STASKW_OOBIA]" in text:
            raise RuntimeError(f"Directed test used an out-of-bounds vector initialization: {log}")
    if "mismatches=0" not in run_logs["long_stream"].read_text(encoding="utf-8", errors="replace"):
        raise RuntimeError("Long-stream AXI-Lite register predictor reported a mismatch")
    long_log = run_logs["long_stream"].read_text(encoding="utf-8", errors="replace")
    for marker in ("source=4704 cdc=8232 dsp=8243 ef2=8232", "pa=8232", "early_underflow=0"):
        if marker not in long_log:
            raise RuntimeError(f"Long-stream run is missing expected DUT event evidence: {marker}")

    base_command = base_run.get("command", [])
    if "-format" not in base_command:
        raise RuntimeError("Frozen baseline URG command is incomplete")
    prefix = base_command[:base_command.index("-format")]
    base_vdbs = [str(x) for x in (base_manifest["design"], *base_manifest["tests"])]
    if len([arg for arg in prefix if arg.endswith(".vdb")]) != 552 or [arg for arg in prefix if arg.endswith(".vdb")] != [x["path"] for x in (base_manifest["design"], *base_manifest["tests"])] :
        raise RuntimeError("Frozen URG command and VDB manifest path order differ")

    # Re-hash the existing set and bind each supplemental VDB by full tree hash.
    all_base_items = [base_manifest["design"], *base_manifest["tests"]]
    vdb_fingerprints_before = []
    for item in all_base_items:
        path = Path(item["path"])
        actual = residual.tree_fingerprint(path)
        if any(actual[k] != item[k] for k in ("file_count", "total_bytes", "tree_sha256")):
            raise RuntimeError(f"Frozen Round 17 VDB fingerprint mismatch: {path}")
        vdb_fingerprints_before.append({"path": str(path), **actual})
    extras = []
    for path in args.extra_test_vdb:
        path = path.resolve()
        if not path.is_dir() or not path.name.endswith(".vdb"):
            raise RuntimeError(f"Supplemental input is not a VDB directory: {path}")
        fp = residual.tree_fingerprint(path)
        extras.append({"path": str(path), **fp})
    extra_names = {Path(item["path"]).name for item in extras}
    if not any("cov_thermo5_sku_axil_config_test_seed271030.vdb" in n for n in extra_names):
        raise RuntimeError("Long-stream UVM Test VDB is not present")
    if not any("cov_thermo5_sku_axil_register_access_test_seed271032.vdb" in n for n in extra_names):
        raise RuntimeError("AXI-Lite register UVM Test VDB is not present")

    urgent = Path(base_command[0]).resolve()
    old_whatif_filelist = data_dir / "round17_old_plus_all_analysis_only.elfilelist"
    if not urgent.is_file() or not old_whatif_filelist.is_file():
        raise RuntimeError("URG binary or qualified Round 17 Analysis-only exclusion list is missing")
    vdb_paths = [item["path"] for item in extras]
    env = __import__("os").environ.copy()
    vcs_home = Path("/opt/Synopsys/vcs/V-2023.12-SP1")
    env["LD_LIBRARY_PATH"] = ":".join(
        [str(vcs_home / "lib"), str(vcs_home / "linux64/lib"), env.get("LD_LIBRARY_PATH", "")]).rstrip(":")

    run_specs = (
        ("raw", None),
        ("legacy_8957", data_dir / "round17_all_candidate_batches.elfilelist"),
        ("legacy_plus_ef2", data_dir / "round17_old_plus_ef2_analysis_only.elfilelist"),
        ("legacy_plus_active", data_dir / "round17_old_plus_active_analysis_only.elfilelist"),
        ("legacy_plus_all", old_whatif_filelist),
    )
    run_results = {}
    for label, filelist in run_specs:
        exclusion = [] if filelist is None else ["-elfilelist", str(filelist), "-excl_strict"]
        report_dir = out / label / "report"
        log = out / label / "urg.log"
        command = [str(urgent), *prefix[1:], *vdb_paths, *exclusion,
                   "-format", "both", "-report", str(report_dir),
                   "-dbname", f"thermo5_r17_supplemental_{label}", "-log", str(log)]
        residual.run_command(command, env, out, log)
        summary = residual.coverage_summary(report_dir, out / label / "inventory")
        run_results[label] = {
            "command": command,
            "log_sha256": sha256_file(log),
            "metrics": residual.product_metrics(summary),
            "fsm": residual.fsm_assertions(summary)[0],
            "assertions": residual.fsm_assertions(summary)[1],
            "report_path": str(report_dir),
        }

    old_raw_summary = json.loads((args.raw_whatif_run_dir / "raw/inventory/summary.json").read_text(encoding="utf-8"))
    old_adj_summary = json.loads((args.raw_whatif_run_dir / "legacy_plus_all/inventory/summary.json").read_text(encoding="utf-8"))
    old_raw_metrics = residual.product_metrics(old_raw_summary)
    old_adj_metrics = residual.product_metrics(old_adj_summary)
    raw_metrics = run_results["raw"]["metrics"]
    adj_metrics = run_results["legacy_plus_all"]["metrics"]
    if any(raw_metrics[m]["total"] != old_raw_metrics[m]["total"] for m in METRICS):
        raise RuntimeError("Raw DUT denominator changed after supplemental VDBs")
    if any(adj_metrics[m]["total"] != old_adj_metrics[m]["total"] for m in METRICS):
        raise RuntimeError("Analysis-only denominator changed after supplemental VDBs")
    for label, _ in run_specs[1:]:
        if any(raw_metrics[m]["covered"] != run_results[label]["metrics"][m]["covered"] for m in METRICS):
            raise RuntimeError(f"Analysis-only exclusions unexpectedly changed covered numerators: {label}")
        if run_results["raw"]["fsm"] != run_results[label]["fsm"] or run_results["raw"]["assertions"] != run_results[label]["assertions"]:
            raise RuntimeError(f"Analysis-only exclusions changed FSM or assertion coverage: {label}")
    if any(raw_metrics[m]["covered"] < old_raw_metrics[m]["covered"] for m in METRICS):
        raise RuntimeError("Supplemental VDB unexpectedly reduced a Raw covered numerator")

    # Existing candidate `.el` files are expected to stay disjoint from the
    # newly tested shadow/counter bins. Keep exact native target reporting.
    base_raw_report = args.raw_whatif_run_dir / "raw/report"
    new_raw_report = out / "raw/report"
    base_toggles = toggle_rows(base_raw_report)
    new_toggles = toggle_rows(new_raw_report)
    old_ledger = load_gzip_csv(data_dir / "round17_residual_exact_whatif_remaining_bins.csv.gz")
    target_rows = []
    for row in old_ledger:
        if row["metric"] != "toggle":
            continue
        native = target_native(row)
        if native is None:
            continue
        signal, direction = native
        if signal != "sample_count[12]" and not (
            signal == "shadow_taps[1]" and row["instance"].endswith(".u_cfg")
        ):
            continue
        states = new_toggles.get((row["instance"], signal))
        hit = bool(states and states[direction])
        target_rows.append({**row, "supplemental_test_status": "HIT" if hit else "OPEN",
                            "supplemental_urg_log_sha256": run_results["raw"]["log_sha256"]})
    hit_rows = [row for row in target_rows if row["supplemental_test_status"] == "HIT"]
    if len(target_rows) != 34 or len({row["semantic_bin_id"] for row in target_rows}) != 34:
        raise RuntimeError(f"Expected 34 exact sample_count[12]/shadow_taps[1] targets, found {len(target_rows)}")
    if len(hit_rows) != 34:
        misses = [(r["instance"], r["exact_urg_bin"]) for r in target_rows if r["supplemental_test_status"] != "HIT"]
        raise RuntimeError(f"Directed tests did not hit all 34 designated Exact Toggle bins: {misses[:8]}")
    ledger_by_native = {(row["instance"], row["exact_urg_bin"]): row for row in old_ledger if row["metric"] == "toggle"}
    observed_raw_hits = []
    allowed_delta = set()
    for lane in range(16):
        instance = f"thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[{lane}].u_dpd"
        for bit in (12, 13):
            for direction in ("1_to_0", "0_to_1"):
                allowed_delta.add((instance, f"Port Details:sample_count[{bit}]:{direction}"))
    for direction in ("1_to_0", "0_to_1"):
        allowed_delta.add(("thermo5_sku_uvm_tb.dut.u_cfg", f"Signal Details:shadow_taps[1]:{direction}"))
    actual_delta = set()
    for (instance, signal), states in new_toggles.items():
        previous = base_toggles.get((instance, signal), {"1_to_0": False, "0_to_1": False})
        for direction in ("1_to_0", "0_to_1"):
            if states[direction] and not previous[direction]:
                native = "Port Details" if signal.startswith(("sample_count", "saturation_count")) else "Signal Details"
                key = (instance, f"{native}:{signal}:{direction}")
                actual_delta.add(key)
                ledger_row = ledger_by_native.get(key)
                if ledger_row is None:
                    raise RuntimeError(f"A new Raw hit has no exact residual-bin ledger mapping: {key}")
                role = "DIRECTED_TARGET" if (signal == "sample_count[12]" or signal == "shadow_taps[1]") else "ADDITIONAL_HIGHER_COUNTER_BIT"
                observed_raw_hits.append({**ledger_row,
                    "supplemental_test_status": "HIT",
                    "coverage_delta_role": role,
                    "supplemental_urg_log_sha256": run_results["raw"]["log_sha256"]})
    if actual_delta != allowed_delta:
        unexpected = sorted(actual_delta - allowed_delta)
        missing = sorted(allowed_delta - actual_delta)
        raise RuntimeError(f"Exact Raw hit delta mismatch; unexpected={unexpected[:4]} missing={missing[:4]}")
    if len(observed_raw_hits) != 66 or raw_metrics["toggle"]["covered"] - old_raw_metrics["toggle"]["covered"] != 66:
        raise RuntimeError("Raw Toggle numerator delta is not the expected 66 exact transition hits")
    for metric in ("branch", "cond", "line"):
        if raw_metrics[metric]["covered"] != old_raw_metrics[metric]["covered"]:
            raise RuntimeError(f"Unexpected un-ledgered {metric} numerator delta; exact mapping review required")

    expected_excluded = {
        "legacy_8957": {"branch": 98, "cond": 108, "line": 429, "toggle": 8322},
        "legacy_plus_ef2": {"branch": 98, "cond": 108, "line": 429, "toggle": 10650},
        "legacy_plus_active": {"branch": 98, "cond": 108, "line": 429, "toggle": 8442},
        "legacy_plus_all": {"branch": 98, "cond": 108, "line": 429, "toggle": 10770},
    }
    for label, expected in expected_excluded.items():
        metrics = run_results[label]["metrics"]
        actual = {metric: raw_metrics[metric]["total"] - metrics[metric]["total"] for metric in METRICS}
        if actual != expected:
            raise RuntimeError(f"Strict URG excluded-bin count mismatch for {label}: {actual}")
        run_results[label]["excluded_bins_by_metric"] = actual

    hit_ids = {r["semantic_bin_id"] for r in observed_raw_hits}
    remaining = [dict(r) for r in old_ledger if r["semantic_bin_id"] not in hit_ids]
    for row in remaining:
        row["whatif_remaining_status"] = "OPEN_AFTER_R17_FIXED_CONFIG_AND_DIRECTED_COUNTER_TESTS"
        row["official_adjusted_status"] = "UNCHANGED_RAW_OPEN"
    expected_remaining = {"branch": 15, "cond": 84, "line": 29, "toggle": 1572}
    actual_remaining = {m: sum(row["metric"] == m for row in remaining) for m in METRICS}
    if actual_remaining != expected_remaining:
        raise RuntimeError(f"Exact remaining ledger does not reconcile: {actual_remaining}")

    # Every baseline VDB is checked again to prove URG did not mutate inputs.
    vdb_fingerprints_after = []
    for item in all_base_items:
        path = Path(item["path"])
        fp = residual.tree_fingerprint(path)
        if any(fp[k] != item[k] for k in ("file_count", "total_bytes", "tree_sha256")):
            raise RuntimeError(f"Frozen baseline VDB changed during supplemental URG: {path}")
        vdb_fingerprints_after.append({"path": str(path), **fp})
    for item in extras:
        path = Path(item["path"])
        fp = residual.tree_fingerprint(path)
        if any(fp[k] != item[k] for k in ("file_count", "total_bytes", "tree_sha256")):
            raise RuntimeError(f"Supplemental VDB changed during URG: {path}")

    output_data = data_dir
    residual.write_gzip_csv(output_data / "round17_directed_target_exact_bin_results.csv.gz", observed_raw_hits)
    residual.write_gzip_csv(output_data / "round17_post_directed_whatif_remaining_bins.csv.gz", sorted(remaining, key=lambda row: row["semantic_bin_id"]))
    extension_manifest = {
        "schema": "thermo5_tx_r17_supplemental_coverage_v1",
        "analysis_only": True,
        "base_vdb_manifest_file_sha256": sha256_file(base_manifest_path),
        "base_vdb_manifest_canonical_sha256": base_run["vdb_manifest_canonical_sha256"],
        "base_design_vdb_count": 1,
        "base_test_vdb_count": 551,
        "supplemental_test_vdb_count": len(extras),
        "extended_test_vdb_count": 553,
        "extended_total_vdb_count_including_design": 554,
        "product_source_sha": compile_manifest["product_source_sha"],
        "product_rtl_aggregate_sha256": compile_manifest["product_rtl_aggregate_sha256"],
        "compile_fingerprint_sha256": compile_manifest["compile_fingerprint_sha256"],
        "supplemental_uvm_source_sha256": sha256_file(ROOT / "dv/uvm/tests/thermo5/axil/thermo5_sku_axil_config_test.svh"),
        "source_head": __import__("subprocess").check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "supplemental_vdbs": extras,
        "extended_vdb_manifest_canonical_sha256": __import__("hashlib").sha256(
            json.dumps({"base": base_run["vdb_manifest_canonical_sha256"], "supplemental": extras},
                       sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
        "directed_target_bin_hits": {"count": len(hit_rows), "bins": [r["semantic_bin_id"] for r in hit_rows]},
        "all_exact_raw_delta_hits": {"count": len(observed_raw_hits), "bins": [r["semantic_bin_id"] for r in observed_raw_hits]},
        "raw_metrics": raw_metrics,
        "analysis_only_whatif_metrics": adj_metrics,
        "scenario_metrics": {label: result["metrics"] for label, result in run_results.items()},
        "scenario_excluded_bins_by_metric": {label: result.get("excluded_bins_by_metric", {m: 0 for m in METRICS}) for label, result in run_results.items()},
        "remaining_bins_by_metric": actual_remaining,
        "official_waiver_approval_count": 0,
        "official_exclusion_count": 0,
        "fsm_and_assertion_unchanged_by_exclusion": True,
        "run_results": run_results,
        "vdb_fingerprints_before": vdb_fingerprints_before,
        "vdb_fingerprints_after": vdb_fingerprints_after,
        "test_logs": {k: {"path": str(p), "sha256": sha256_file(p)} for k, p in run_logs.items()},
        "long_stream_underflow_observation": {
            "sampled_cycles": 70,
            "before_last_source_beat": 0,
            "interpretation": "The frozen SKU has no end-of-stream flag; a sticky underflow observation after the final source beat is allowed by the documented test contract. The independent bit-true, count, frame, and final drain checks passed.",
        },
        "report_status": "ANALYSIS_ONLY_NOT_OFFICIAL_SIGNOFF",
    }
    manifest_path = out / "supplemental_manifest.json"
    manifest_path.write_text(json.dumps(extension_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    candidate_rows = load_gzip_csv(data_dir / "round17_residual_fixed_config_candidates.csv.gz")
    if len(candidate_rows) != 2448 or len({r["semantic_bin_id"] for r in candidate_rows}) != 2448:
        raise RuntimeError("Fixed-configuration candidate ledger must contain 2,448 unique exact semantic bins")
    extended_candidates = []
    for row in candidate_rows:
        batch = row["candidate_batch"]
        batch_run = "legacy_plus_ef2" if batch == "EF2_PAIR_LOOKAHEAD_ZERO" else "legacy_plus_active"
        extended_candidates.append({**row,
            "strict_urg_log_sha256_extended_553": run_results[batch_run]["log_sha256"],
            "strict_urg_log_sha256_combined_553": run_results["legacy_plus_all"]["log_sha256"],
            "raw_urg_log_sha256_extended_553": run_results["raw"]["log_sha256"],
            "extended_vdb_manifest_canonical_sha256": extension_manifest["extended_vdb_manifest_canonical_sha256"],
            "extended_candidate_review_status": "PENDING_INDEPENDENT_REVIEW_NOT_OFFICIAL"})
    candidate_path = output_data / "round17_fixed_config_candidates_extended_553_vdb.csv.gz"
    residual.write_gzip_csv(candidate_path, extended_candidates)
    extension_manifest["extended_candidate_ledger"] = {
        "path": str(candidate_path.relative_to(ROOT)),
        "row_count": len(extended_candidates),
        "sha256": sha256_file(candidate_path),
        "official_waiver_status": "UNCHANGED_PENDING_NO_APPROVAL",
    }
    manifest_path.write_text(json.dumps(extension_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"raw": raw_metrics, "analysis_only": adj_metrics,
                      "target_hits": len(hit_rows), "all_exact_raw_delta_hits": len(observed_raw_hits), "remaining": actual_remaining,
                      "manifest": str(manifest_path)}, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
