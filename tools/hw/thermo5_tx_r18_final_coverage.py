#!/usr/bin/env python3.12
"""Re-run Round 18 Raw, zero-waiver Adjusted, and analysis-only URG.

The script reuses the frozen Round 17 Design + 551-Test set, adds the two
previously-qualified supplemental tests, and optionally adds one new directed
test VDB. It never edits official waiver state. The zero-waiver Adjusted run
is intentionally identical to Raw until an independent reviewer approves an
exclusion.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
URG_DEFAULT = Path("/opt/Synopsys/vcs/V-2023.12-SP1/linux64/bin/urg1")
BASE_DIR_DEFAULT = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_raw_retry2"
PRIOR_DIR_DEFAULT = ROOT / "runs/thermo5_r17_final_residual_20261109_run5"
COMPILE_DEFAULT = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
EXCLUSION_DEFAULT = ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_old_plus_all_analysis_only.elfilelist"
RESIDUAL_DEFAULT = ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_post_directed_whatif_remaining_bins.csv.gz"
METRICS = ("branch", "cond", "line", "toggle")
CANDIDATE_EXECUTION_DEFAULT = ROOT / "docs/verification/data/thermo5-r17/analysis_only/round17_candidate_exclusion_execution.csv.gz"
NATIVE_TEMPLATE_DEFAULT = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_native_template_retry1"


def load_helper():
    path = ROOT / "tools/hw/thermo5_tx_r17_supplemental_coverage.py"
    spec = importlib.util.spec_from_file_location("thermo5_r17_supplemental", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load existing Round 17 coverage helper: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


helper = load_helper()
residual = helper.residual


def map_unmapped_candidates(candidate_path: Path, compile_manifest: dict,
                            template_dir: Path, out: Path,
                            original_elfilelist: Path) -> tuple[Path, Path, list[dict[str, str]]]:
    with gzip.open(candidate_path, "rt", newline="", encoding="utf-8") as stream:
        all_candidates = list(csv.DictReader(stream))
    candidates = [r for r in all_candidates if r["native_mapping_status"] in
                  ("NATIVE_MAPPING_COMPLEX_BRANCH_BIN", "NATIVE_MAPPING_AMBIGUOUS")]
    if len(candidates) != 13 or sum(r["metric"] == "branch" for r in candidates) != 9 or sum(
            r["metric"] == "line" for r in candidates) != 4:
        raise RuntimeError("Expected exactly the 9 Branch + 4 Line native mapping gaps")
    native = residual.load_native_parser()
    scopes_by_metric = {
        "branch": native.parse_native_template(template_dir / "fullexclude.branch"),
        "line": native.parse_native_template(template_dir / "fullexclude.line"),
    }
    source_hashes = compile_manifest["source_file_sha256"]

    def normalize_vector(value: str) -> str:
        return re.sub(r"\s*[,/]\s*", ",", value.strip())

    mapped: list[dict[str, str]] = []
    for row in candidates:
        source = ROOT / row["source_file"]
        if (source_hashes.get(row["source_file"]) != row["source_file_sha256"] or
                not source.is_file() or sha256_file(source) != row["source_file_sha256"] or
                row["product_source_sha"] != compile_manifest["product_source_sha"]):
            raise RuntimeError(f"Candidate source binding is stale: {row['semantic_bin_id']}")
        metric = row["metric"]
        line = int(row["exact_urg_bin"].split(":", 1)[0])
        scopes = [s for s in scopes_by_metric[metric] if s["instance"] == row["instance"]]
        if len(scopes) != 1:
            raise RuntimeError(f"Candidate instance is not unique: {row['semantic_bin_id']}")
        scope = scopes[0]
        objects = [obj for obj in scope["objects"] if obj["kind"] == metric and
                   obj["line"] == line and native.source_matches(obj, row["source_file"])]
        if metric == "branch":
            target = row["exact_urg_bin"].split(":", 1)[1]
            vectors = []
            for obj in objects:
                for vector_id, signature in obj["vectors"]:
                    suffix = signature[len(obj["signature"]):].strip() if signature.startswith(obj["signature"]) else signature.strip()
                    if normalize_vector(suffix) == normalize_vector(target):
                        vectors.append((obj, vector_id, signature))
            if len(objects) != 1 or len(vectors) != 1:
                raise RuntimeError(f"Branch native-vector mapping is not one-to-one: {row['semantic_bin_id']}")
            obj, vector_id, signature = vectors[0]
            directive = f'Branch {obj["id"]} "{obj["checksum"]}" "{obj["signature"]}" ({vector_id}) "{signature}"'
            reason = "Exact URG decision vector matched one native Branch vector by instance, file, source line, and full vector"
        else:
            # Bind only the guarded $error statement, not the same-line
            # parameter-check predicate or an entire source line.
            error_objects = [obj for obj in objects if "$error(" in obj["signature"]]
            if len(error_objects) != 1:
                raise RuntimeError(f"Parameter $error native Block is not unique: {row['semantic_bin_id']}")
            obj = error_objects[0]
            directive = f'Block {obj["id"]} "{obj["checksum"]}" "{obj["signature"]}"'
            reason = "Unique native $error Block matched to the parameter-guarded statement on this source line"
        mapped.append({**row, "native_mapping_status": "MAPPED_EXACT_NATIVE_BIN",
                       "native_directive": directive, "native_signature": obj.get("signature", ""),
                       "mapping_repair_method": reason,
                       "candidate_status": "PENDING_INDEPENDENT_REVIEW",
                       "reviewer_status": "NONE", "approval_reference": "",
                       "official_exclusion": "NO"})

    out.mkdir(parents=True, exist_ok=True)
    el_path = out / "h_r18_unmapped_exact_analysis_only.el"
    grouped: dict[tuple[str, str, str], set[str]] = {}
    for row in mapped:
        scope = next(s for s in scopes_by_metric[row["metric"]] if s["instance"] == row["instance"])
        grouped.setdefault((scope["checksum"], scope["module"], row["instance"]), set()).add(row["native_directive"])
    el_lines = ["// ANALYSIS_ONLY: 13 repaired native mappings; not an approved official exclusion."]
    for (checksum, module, instance), directives in sorted(grouped.items()):
        el_lines.extend([checksum, f"// {module}", f"INSTANCE: {instance}", *sorted(directives), ""])
    el_path.write_text("\n".join(el_lines).rstrip() + "\n", encoding="utf-8")

    entries = []
    for item in original_elfilelist.read_text(encoding="utf-8").splitlines():
        item = item.strip()
        if not item or item.startswith("#"):
            continue
        resolved = (original_elfilelist.parent / item).resolve()
        if not resolved.is_file():
            raise RuntimeError(f"Existing Analysis-only .el is missing: {resolved}")
        entries.append(str(resolved))
    entries.append(str(el_path.resolve()))
    combined = out / "round18_all_candidates_plus_13_analysis_only.elfilelist"
    combined.write_text("\n".join(entries) + "\n", encoding="utf-8")
    helper.residual.write_gzip_csv(out / "unmapped_candidate_repair_13.csv.gz", mapped)
    return el_path, combined, mapped


def sha256_file(path: Path) -> str:
    return residual.sha256_file(path)


def canonical_sha(value: object) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def verify_vdb(path: Path, expected: dict | None = None) -> dict:
    if not path.is_dir() or not path.name.endswith(".vdb"):
        raise RuntimeError(f"Missing/non-VDB coverage input: {path}")
    result = residual.tree_fingerprint(path)
    if expected:
        for key in ("file_count", "total_bytes", "tree_sha256"):
            if result[key] != expected[key]:
                raise RuntimeError(f"VDB fingerprint mismatch for {path}: {key}")
    return {"path": str(path.resolve()), **result}


def run_one(urg: Path, base_prefix: list[str], vdb_paths: list[str],
            out: Path, label: str, elfilelist: Path | None) -> dict:
    case = out / label
    report = case / "report"
    inventory = case / "inventory"
    log = case / "urg.log"
    command = [str(urg), *base_prefix[1:3], *vdb_paths]
    if elfilelist is not None:
        command.extend(["-elfilelist", str(elfilelist), "-excl_strict"])
    command.extend(["-format", "both", "-report", str(report),
                    "-dbname", str(case / "urg.vdb"), "-log", str(log)])
    env = os.environ.copy()
    vcs_home = Path("/opt/Synopsys/vcs/V-2023.12-SP1")
    env["LD_LIBRARY_PATH"] = ":".join(
        x for x in (str(vcs_home / "lib"), str(vcs_home / "linux64/lib"),
                    env.get("LD_LIBRARY_PATH", "")) if x)
    case.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=case,
                            env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"URG {label} exited {result.returncode}; see {log}")
    diagnostics = [line for line in result.stdout.splitlines()
                   if re.search(r"\b(warning|error|reject|checksum mismatch|ambiguous)\b", line, re.I)]
    if diagnostics:
        raise RuntimeError(f"URG {label} emitted diagnostics: " + " | ".join(diagnostics[:8]))
    summary = residual.coverage_summary(report, inventory)
    metrics = residual.product_metrics(summary)
    if set(metrics) != set(METRICS):
        raise RuntimeError(f"Incomplete DUT metric set in {label}: {metrics}")
    fsm, assertions = residual.fsm_assertions(summary)
    return {"command": command, "log_path": str(log), "log_sha256": sha256_file(log),
            "report_path": str(report), "inventory_path": str(inventory),
            "metrics": metrics, "fsm": fsm, "assertions": assertions}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extra-test-vdb", type=Path, required=True,
                        help="new Round 18 directed Test VDB")
    parser.add_argument("--test-log", type=Path, required=True,
                        help="matching VCS/UVM test log")
    parser.add_argument("--vectors-manifest", type=Path, required=True,
                        help="independent vector/oracle manifest used by the test")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--base-dir", type=Path, default=BASE_DIR_DEFAULT)
    parser.add_argument("--prior-dir", type=Path, default=PRIOR_DIR_DEFAULT)
    parser.add_argument("--compile-manifest", type=Path, default=COMPILE_DEFAULT)
    parser.add_argument("--exclusion-list", type=Path, default=EXCLUSION_DEFAULT)
    parser.add_argument("--residual-ledger", type=Path, default=RESIDUAL_DEFAULT)
    parser.add_argument("--candidate-execution", type=Path, default=CANDIDATE_EXECUTION_DEFAULT)
    parser.add_argument("--native-template-dir", type=Path, default=NATIVE_TEMPLATE_DEFAULT)
    parser.add_argument("--urg", type=Path, default=URG_DEFAULT)
    args = parser.parse_args()

    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    base_manifest_path = args.base_dir / "input_vdb_manifest.json"
    base_run_path = args.base_dir / "run_manifest.json"
    prior_manifest_path = args.prior_dir / "supplemental_manifest.json"
    base_manifest = json.loads(base_manifest_path.read_text(encoding="utf-8"))
    base_run = json.loads(base_run_path.read_text(encoding="utf-8"))
    prior = json.loads(prior_manifest_path.read_text(encoding="utf-8"))
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    vectors_manifest = json.loads(args.vectors_manifest.read_text(encoding="utf-8"))
    test_log = args.test_log.resolve()
    log_text = test_log.read_text(encoding="utf-8", errors="replace")
    for marker in ("THERMO5_DPD_SATURATION_COUNTS_MATCH_PYTHON lanes=16",
                   "THERMO5_AXIL_DPD_SATURATION_BITTRUE_UVM_PASS",
                   "THERMO5_DPD_DRAIN_STATUS_CLEAR"):
        if marker not in log_text:
            raise RuntimeError(f"Directed test lacks checker evidence: {marker}")
    for marker in ("UVM_WARNING :    0", "UVM_ERROR :    0", "UVM_FATAL :    0",
                   "mismatches=0", "underflow=0", "early_underflow=0"):
        if marker not in log_text:
            raise RuntimeError(f"Directed test log lacks required clean result: {marker}")
    if prior.get("extended_test_vdb_count") != 553 or prior.get("official_waiver_approval_count") != 0:
        raise RuntimeError("Prior supplemental evidence is not the expected 553-Test/zero-approval baseline")
    if base_manifest.get("design") is None or len(base_manifest.get("tests", [])) != 551:
        raise RuntimeError("Expected the frozen Round 17 Design + 551-Test input set")
    if prior.get("base_vdb_manifest_canonical_sha256") != base_run.get("vdb_manifest_canonical_sha256"):
        raise RuntimeError("Prior supplemental VDBs are bound to a different base manifest")
    if prior.get("product_rtl_aggregate_sha256") != compile_manifest.get("product_rtl_aggregate_sha256"):
        raise RuntimeError("Product RTL aggregate differs from the frozen compile manifest")
    if prior.get("compile_fingerprint_sha256") != compile_manifest.get("compile_fingerprint_sha256"):
        raise RuntimeError("Product compile fingerprint differs from the Round 17 baseline")
    if not args.exclusion_list.is_file():
        raise RuntimeError(f"Missing Analysis-only candidate exclusion list: {args.exclusion_list}")
    if not test_log.is_file() or not args.extra_test_vdb.is_dir():
        raise RuntimeError("New test log or Test VDB is missing")

    base_items = [base_manifest["design"], *base_manifest["tests"]]
    frozen_fingerprints = prior["vdb_fingerprints_before"]
    expected_by_path = {str(Path(x["path"]).resolve()): x for x in frozen_fingerprints}
    base_vdbs = []
    for item in base_items:
        path = Path(item["path"]).resolve()
        expected = expected_by_path.get(str(path))
        if expected is None:
            raise RuntimeError(f"Base VDB absent from frozen fingerprint ledger: {path}")
        base_vdbs.append(verify_vdb(path, expected))
    prior_vdbs = [verify_vdb(Path(x["path"]), x) for x in prior["supplemental_vdbs"]]
    new_vdb = verify_vdb(args.extra_test_vdb.resolve())
    if "cov_thermo5_sku_axil_dpd_saturation_bittrue_test_seed180018.vdb" not in Path(new_vdb["path"]).name:
        raise RuntimeError("New VDB is not the declared seed-180018 saturation test")
    repaired_el, repaired_elfilelist, repaired_candidates = map_unmapped_candidates(
        args.candidate_execution.resolve(), compile_manifest,
        args.native_template_dir.resolve(), out / "analysis_only_mapping_repair",
        args.exclusion_list.resolve())

    vdb_sets = {
        "553": [x["path"] for x in base_vdbs + prior_vdbs],
        "554": [x["path"] for x in base_vdbs + prior_vdbs + [new_vdb]],
    }
    if len(vdb_sets["553"]) != 554 or len(vdb_sets["554"]) != 555:
        raise RuntimeError("Incorrect Design/Test VDB total after assembling frozen manifests")
    for version, paths in vdb_sets.items():
        if len(set(paths)) != len(paths):
            raise RuntimeError(f"Duplicate VDB path in {version}-Test set")

    base_command = base_run.get("command", [])
    if "-format" not in base_command:
        raise RuntimeError("Frozen Raw URG command lacks -format boundary")
    prefix = base_command[:base_command.index("-format")]
    if prefix[0] != str(args.urg.resolve()):
        # The VCS installation path is part of the run evidence; only allow
        # an explicit command-line override when it points to a real binary.
        if not args.urg.is_file():
            raise RuntimeError(f"URG executable is missing: {args.urg}")
        prefix[0] = str(args.urg.resolve())
    if [x for x in prefix if x.endswith(".vdb")] != [x["path"] for x in base_vdbs]:
        raise RuntimeError("Frozen Raw command VDB order differs from the hashed input manifest")
    if prefix[1:3] != ["-full64", "-dir"]:
        raise RuntimeError("Unexpected frozen URG mode; expected Full64")

    results = {}
    for count, paths in vdb_sets.items():
        for label, exclusion in (("raw", None), ("official_adjusted_zero_waiver", None),
                                 ("analysis_whatif_11405", args.exclusion_list.resolve()),
                                 ("analysis_whatif_11418", repaired_elfilelist.resolve())):
            key = f"test_vdbs_{count}/{label}"
            results[key] = run_one(Path(prefix[0]), prefix, paths, out, key, exclusion)
        raw = results[f"test_vdbs_{count}/raw"]
        official = results[f"test_vdbs_{count}/official_adjusted_zero_waiver"]
        whatif = results[f"test_vdbs_{count}/analysis_whatif_11405"]
        repaired_whatif = results[f"test_vdbs_{count}/analysis_whatif_11418"]
        if raw["metrics"] != official["metrics"]:
            raise RuntimeError(f"No-waiver official Adjusted differs from Raw for {count}-Test VDBs")
        if raw["fsm"] != whatif["fsm"] or raw["assertions"] != whatif["assertions"]:
            raise RuntimeError(f"Analysis-only exclusions changed FSM/Assertion result for {count}-Test VDBs")
        if any(raw["metrics"][m]["covered"] != whatif["metrics"][m]["covered"] for m in METRICS):
            raise RuntimeError(f"Analysis-only exclusions changed covered numerator for {count}-Test VDBs")
        if raw["fsm"] != repaired_whatif["fsm"] or raw["assertions"] != repaired_whatif["assertions"]:
            raise RuntimeError(f"Repaired Analysis-only exclusions changed FSM/Assertion result for {count}-Test VDBs")
        if any(raw["metrics"][m]["covered"] != repaired_whatif["metrics"][m]["covered"] for m in METRICS):
            raise RuntimeError(f"Repaired Analysis-only exclusions changed covered numerator for {count}-Test VDBs")
        excluded_11405 = {m: raw["metrics"][m]["total"] - whatif["metrics"][m]["total"] for m in METRICS}
        excluded_11418 = {m: raw["metrics"][m]["total"] - repaired_whatif["metrics"][m]["total"] for m in METRICS}
        if excluded_11405 != {"branch": 98, "cond": 108, "line": 429, "toggle": 10770}:
            raise RuntimeError(f"Base strict exclusion set changed: {excluded_11405}")
        if excluded_11418 != {"branch": 107, "cond": 108, "line": 433, "toggle": 10770}:
            raise RuntimeError(f"13-bin repaired strict exclusion delta mismatch: {excluded_11418}")

    # Exact 553 -> 554 Raw Toggle delta against native instance/signal/bit/direction.
    report_553 = Path(results["test_vdbs_553/raw"]["report_path"])
    report_554 = Path(results["test_vdbs_554/raw"]["report_path"])
    before = helper.toggle_rows(report_553)
    after = helper.toggle_rows(report_554)
    delta_rows = []
    for (instance, signal), state in sorted(after.items()):
        old = before.get((instance, signal), {"0_to_1": False, "1_to_0": False})
        for direction in ("0_to_1", "1_to_0"):
            if state[direction] and not old[direction]:
                metric = "Port Details" if signal.startswith(("sample_count", "saturation_count")) else "Signal Details"
                exact = f"{metric}:{signal}:{direction}"
                delta_rows.append({"instance": instance, "signal_bit": signal,
                                   "direction": direction, "exact_urg_bin": exact,
                                   "metric": "toggle",
                                   "counter_family": ("sample_count" if signal.startswith("sample_count") else
                                                      "saturation_count" if signal.startswith("saturation_count") else "other"),
                                   "semantic_bin_id": ""})
    residual_rows = residual.load_gzip_csv(args.residual_ledger)
    residual_by_key = {(r["instance"], r["exact_urg_bin"]): r for r in residual_rows}
    for row in delta_rows:
        prior_row = residual_by_key.get((row["instance"], row["exact_urg_bin"]))
        if prior_row:
            row["semantic_bin_id"] = prior_row["semantic_bin_id"]
            row["coverage_scope"] = "ANALYSIS_WHATIF_RESIDUAL_CLOSED_BY_NEW_RAW_HIT"
        else:
            row["coverage_scope"] = "RAW_DELTA_OUTSIDE_PRIOR_ANALYSIS_WHATIF_RESIDUAL"
    helper.residual.write_gzip_csv(out / "exact_raw_toggle_delta_553_to_554.csv.gz", delta_rows)

    # Update exact residual only when the independent Raw report proves each
    # affected toggle row is hit; code metrics remain in the URG summaries.
    hit_ids = {r["semantic_bin_id"] for r in delta_rows if r["semantic_bin_id"]}
    remaining_11405 = [dict(r) for r in residual_rows if r["semantic_bin_id"] not in hit_ids]
    repaired_ids = {r["semantic_bin_id"] for r in repaired_candidates}
    remaining_11418 = [r for r in remaining_11405 if r["semantic_bin_id"] not in repaired_ids]
    helper.residual.write_gzip_csv(out / "exact_whatif_residual_11405_after_554.csv.gz", remaining_11405)
    helper.residual.write_gzip_csv(out / "exact_whatif_residual_11418_after_554.csv.gz", remaining_11418)
    whatif_554 = results["test_vdbs_554/analysis_whatif_11405"]["metrics"]
    repaired_whatif_554 = results["test_vdbs_554/analysis_whatif_11418"]["metrics"]
    if len(remaining_11405) != 1270 or len(remaining_11418) != 1257:
        raise RuntimeError(f"Unexpected exact residual totals: 11,405={len(remaining_11405)} 11,418={len(remaining_11418)}")
    if sum(r["metric"] == "toggle" for r in remaining_11405) != whatif_554["toggle"]["missing"]:
        raise RuntimeError("Base 11,405-candidate toggle residual does not reconcile to 554-Test What-if URG")
    if sum(r["metric"] == "toggle" for r in remaining_11418) != repaired_whatif_554["toggle"]["missing"]:
        raise RuntimeError("Repaired 11,418-candidate toggle residual does not reconcile to 554-Test What-if URG")
    for metric in ("branch", "cond", "line"):
        if sum(r["metric"] == metric for r in remaining_11405) != whatif_554[metric]["missing"]:
            raise RuntimeError(f"Base exact {metric} residual does not reconcile to 554-Test What-if URG")
        if sum(r["metric"] == metric for r in remaining_11418) != repaired_whatif_554[metric]["missing"]:
            raise RuntimeError(f"Repaired exact {metric} residual does not reconcile to 554-Test What-if URG")

    all_inputs_before = base_vdbs + prior_vdbs + [new_vdb]
    all_inputs_after = [verify_vdb(Path(x["path"]), x) for x in all_inputs_before]
    output = {
        "schema": "thermo5_tx_r18_same_vdb_urg_v1",
        "status": "ACTUAL_URG_COMPLETE_NOT_OFFICIAL_SIGNOFF",
        "product_configuration": {
            "architecture": "Centered-Cubic x2+x2 / EF2 ORDER=2 STEP=5120 STATE_BITS=20",
            "dpd_max_taps": 1, "generic_fifo": True, "axi_lite": True,
        },
        "product_source_sha": compile_manifest["product_source_sha"],
        "product_rtl_aggregate_sha256": compile_manifest["product_rtl_aggregate_sha256"],
        "compile_fingerprint_sha256": compile_manifest["compile_fingerprint_sha256"],
        "frozen_553_vdb_manifest_sha256": prior["extended_vdb_manifest_canonical_sha256"],
        "analysis_elfilelist_sha256": sha256_file(args.exclusion_list),
        "analysis_elfilelist_with_13_repairs_sha256": sha256_file(repaired_elfilelist),
        "analysis_candidate_excluded_count_before_mapping_repair": 11405,
        "analysis_candidate_excluded_count_after_mapping_repair": 11418,
        "unmapped_candidate_repair": {
            "count": len(repaired_candidates),
            "branch": sum(r["metric"] == "branch" for r in repaired_candidates),
            "line": sum(r["metric"] == "line" for r in repaired_candidates),
            "review_status": "PENDING_INDEPENDENT_REVIEW_NOT_OFFICIAL",
            "ledger": str((out / "analysis_only_mapping_repair/unmapped_candidate_repair_13.csv.gz").resolve()),
            "el": str(repaired_el.resolve()),
            "elfilelist": str(repaired_elfilelist.resolve()),
        },
        "official_approved_waivers": 0,
        "official_approved_exclusions": 0,
        "test_log_sha256": sha256_file(test_log),
        "vector_manifest_sha256": sha256_file(args.vectors_manifest),
        "vector_manifest": json.loads(args.vectors_manifest.read_text(encoding="utf-8")),
        "new_test_vdb": new_vdb,
        "test_vdb_sets": {"553": {"design": 1, "tests": 553, "canonical_sha256": prior["extended_vdb_manifest_canonical_sha256"]},
                          "554": {"design": 1, "tests": 554,
                                  "canonical_sha256": canonical_sha(vdb_sets["554"])}},
        "run_results": results,
        "raw_toggle_delta_553_to_554": {
            "total_exact_bins": len(delta_rows),
            "by_counter_family": {name: sum(x["counter_family"] == name for x in delta_rows)
                                   for name in ("sample_count", "saturation_count", "other")},
            "analysis_residual_closed": len(hit_ids),
            "outside_prior_whatif_residual": len(delta_rows) - len(hit_ids),
            "ledger": str((out / "exact_raw_toggle_delta_553_to_554.csv.gz").resolve()),
        },
        "updated_whatif_residual_before_13_repairs": {
            "exact_bin_count": len(remaining_11405),
            "by_metric": {m: sum(x["metric"] == m for x in remaining_11405) for m in METRICS},
            "ledger": str((out / "exact_whatif_residual_11405_after_554.csv.gz").resolve()),
        },
        "updated_whatif_residual_after_13_repairs": {
            "exact_bin_count": len(remaining_11418),
            "by_metric": {m: sum(x["metric"] == m for x in remaining_11418) for m in METRICS},
            "ledger": str((out / "exact_whatif_residual_11418_after_554.csv.gz").resolve()),
        },
        "vdb_fingerprints_before": all_inputs_before,
        "vdb_fingerprints_after": all_inputs_after,
        "tool": {"urg_binary": str(Path(prefix[0]).resolve()), "urg_version": "V-2023.12-SP1 Full64"},
        "signoff": "OPEN: independent approvals, remaining bins, Formal/Assertion closure not complete",
    }
    manifest = out / "thermo5_tx_r18_coverage_manifest.json"
    manifest.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest),
                      "553_raw": results["test_vdbs_553/raw"]["metrics"],
                      "553_official_adjusted": results["test_vdbs_553/official_adjusted_zero_waiver"]["metrics"],
                      "553_whatif_11405": results["test_vdbs_553/analysis_whatif_11405"]["metrics"],
                      "553_whatif_11418": results["test_vdbs_553/analysis_whatif_11418"]["metrics"],
                      "554_raw": results["test_vdbs_554/raw"]["metrics"],
                      "554_official_adjusted": results["test_vdbs_554/official_adjusted_zero_waiver"]["metrics"],
                      "554_whatif_11405": whatif_554,
                      "554_whatif_11418": repaired_whatif_554,
                      "exact_toggle_delta": output["raw_toggle_delta_553_to_554"],
                      "remaining": output["updated_whatif_residual_after_13_repairs"]}, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
