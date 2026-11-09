#!/usr/bin/env python3.12
"""Audit Round 17 EF2/Active-Tap residual toggles and run same-VDB URG what-if.

This is an analysis-only flow. It does not approve or alter official waivers.
It binds the candidate bins to the frozen Round 17 compile and VDB manifests,
maps each transition to a native URG toggle object, and checks exact coverage
denominator deltas for Raw, existing exclusions, each new batch, and combined
exclusions. Existing VDBs are hashed before and after the URG campaign.
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
import time


ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "docs/verification/data/thermo5-r17/analysis_only"
DEFAULT_VDB = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_raw_retry2/input_vdb_manifest.json"
DEFAULT_RUN = DEFAULT_VDB.parent / "run_manifest.json"
DEFAULT_TEMPLATE = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_native_template_retry1"
DEFAULT_RAW_LEDGER = DATA / "round17_exact_whatif_remaining_bins.csv.gz"
DEFAULT_COMPILE = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
DEFAULT_OLD_EL = DATA / "round17_all_candidate_batches.elfilelist"
DEFAULT_URG = Path("/opt/Synopsys/vcs/V-2023.12-SP1/linux64/bin/urg1")
OLD_EL_FILES = (
    "a_dpd_pair1_analysis_only.el",
    "b_ef2_fixed_parameters_analysis_only.el",
    "c_dpd_tap_history_analysis_only.el",
    "d_cdc_residual_analysis_only.el",
    "e_other_parameters_analysis_only.el",
)
PRODUCT_METRICS = ("branch", "cond", "line", "toggle")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_fingerprint(path: Path) -> dict:
    digest = hashlib.sha256()
    count = total = 0
    for child in sorted(item for item in path.rglob("*") if item.is_file()):
        rel = child.relative_to(path).as_posix()
        size = child.stat().st_size
        file_hash = sha256_file(child)
        digest.update(rel.encode() + b"\0" + str(size).encode() + b"\0" + file_hash.encode() + b"\n")
        count += 1
        total += size
    return {"file_count": count, "total_bytes": total, "tree_sha256": digest.hexdigest()}


def load_gzip_csv(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_gzip_csv(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=0) as compressed:
            with __import__("io").TextIOWrapper(compressed, encoding="utf-8", newline="") as text:
                writer = csv.DictWriter(text, fieldnames=list(rows[0]), lineterminator="\n")
                writer.writeheader()
                writer.writerows(rows)


def load_native_parser():
    path = ROOT / "tools/hw/thermo5_tx_native_exclusion.py"
    spec = importlib.util.spec_from_file_location("thermo5_tx_native_exclusion", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load the existing native URG template parser")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def map_toggle(row: dict[str, str], scopes: list[dict], source_hashes: dict[str, str], compile_manifest: dict) -> tuple[str, str, str, int | None, str]:
    rel = row["source_file"]
    source_path = ROOT / rel
    if (source_hashes.get(rel) != row.get("source_file_sha256") or not source_path.is_file()
            or sha256_file(source_path) != row.get("source_file_sha256")):
        return "SOURCE_HASH_MISMATCH", "", "", None, "Compile manifest and exact-bin row SHA differ"
    if row.get("product_source_sha") != compile_manifest.get("product_source_sha"):
        return "PRODUCT_SHA_MISMATCH", "", "", None, "Candidate is not bound to the frozen product source SHA"
    match = re.fullmatch(r"(?:Signal|Port) Details:([^:]+):(0_to_1|1_to_0)", row["exact_urg_bin"])
    if not match:
        return "TOGGLE_BIN_PARSE_ERROR", "", "", None, "Native toggle identity could not be parsed"
    token, direction = match.groups()
    bit_match = re.fullmatch(r"(.+)\[(\d+)\]", token)
    if bit_match:
        name, bit_text = bit_match.groups()
        bit = int(bit_text)
    else:
        name, bit = token, None
    scope = [item for item in scopes if item.get("instance") == row["instance"]]
    if len(scope) != 1:
        return ("ELABORATED_INSTANCE_NOT_FOUND" if not scope else "INSTANCE_MAPPING_AMBIGUOUS"), "", "", None, "Native template instance was not unique"
    objects = [obj for obj in scope[0]["objects"] if obj["kind"] == "toggle" and obj["name"] == name]
    if len(objects) != 1:
        return ("NATIVE_OBJECT_NOT_FOUND" if not objects else "NATIVE_MAPPING_AMBIGUOUS"), "", "", None, "Native signal object was not unique"
    obj = objects[0]
    if not obj.get("source", "").endswith("/" + rel):
        return "NATIVE_SOURCE_MISMATCH", "", "", obj.get("line"), "Native object source path does not match the ledger"
    decl = obj["decl"]
    if bit is None:
        if re.search(r"\[\d+:\d+\]$", decl):
            return "VECTOR_REQUIRES_BIT_ID", "", decl, obj.get("line"), "Ledger omits a bit select for a vector object"
        select = name
    else:
        width = re.search(r"\[(\d+):(\d+)\]$", decl)
        if not width or not (min(map(int, width.groups())) <= bit <= max(map(int, width.groups()))):
            return "TOGGLE_BIT_OUT_OF_RANGE", "", decl, obj.get("line"), "Exact bit is outside native declaration width"
        select = f"{name} [{bit}]"
    transition = {"0_to_1": "0to1", "1_to_0": "1to0"}[direction]
    directive = f'Toggle {transition} {select} "{decl}"'
    return "MAPPED_EXACT_NATIVE_BIN", directive, decl, obj.get("line"), "Unique exact native signal/bit/direction match"


def write_el(path: Path, mapped_rows: list[dict[str, str]], scopes_by_metric: dict[str, list[dict]]) -> None:
    lines = ["// ANALYSIS_ONLY: not an official approved exclusion."]
    grouped: dict[tuple[str, str, str], set[str]] = {}
    for row in mapped_rows:
        metric = "tgl"
        matches = [s for s in scopes_by_metric[metric] if s.get("instance") == row["instance"]]
        if len(matches) != 1:
            raise RuntimeError(f"Mapped candidate instance lost unique native scope: {row['semantic_bin_id']}")
        key = (matches[0]["checksum"], matches[0]["module"], row["instance"])
        grouped.setdefault(key, set()).add(row["native_directive"])
    for (checksum, module, instance), directives in sorted(grouped.items()):
        lines.extend([checksum, f"// {module.removeprefix('ANNOTATION: ').strip().strip(chr(34))}", f"INSTANCE: {instance}"])
        lines.extend(sorted(directives))
        lines.append("")
    while lines and not lines[-1]:
        lines.pop()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def run_command(command: list[str], env: dict[str, str], cwd: Path, log: Path) -> None:
    log.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(command, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"URG exited {result.returncode}; see {log}")
    diagnostics = [line for line in result.stdout.splitlines()
                   if re.search(r"\b(warning|error|reject|checksum mismatch|ambiguous)\b", line, re.I)]
    if diagnostics:
        raise RuntimeError("URG diagnostic in strict run: " + " | ".join(diagnostics[:10]))


def coverage_summary(report: Path, output: Path) -> dict:
    command = [sys.executable, str(ROOT / "tools/hw/thermo5_coverage_denominator.py"), str(report), str(output)]
    result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    if result.returncode:
        raise RuntimeError("Coverage inventory failed: " + result.stdout[-3000:])
    path = output / "summary.json"
    if not path.is_file():
        raise RuntimeError(f"Coverage summary missing: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def product_metrics(summary: dict) -> dict[str, dict[str, int]]:
    return {r["metric"]: {k: int(r[k]) for k in ("covered", "total", "missing")}
            for r in summary.get("metrics", [])
            if r.get("ownership") == "PROJECT_RTL" and r.get("metric") in PRODUCT_METRICS}


def fsm_assertions(summary: dict) -> tuple[list, object]:
    fsm = [(r.get("instance"), r.get("fsm"), r.get("metric"), r.get("total"), r.get("covered"))
           for r in summary.get("fsm_denominators", []) if r.get("ownership") == "PROJECT_RTL"]
    return fsm, summary.get("dut_assertion_status_counts")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--urg", type=Path, default=DEFAULT_URG)
    ap.add_argument("--vdb-manifest", type=Path, default=DEFAULT_VDB)
    ap.add_argument("--vdb-run-manifest", type=Path, default=DEFAULT_RUN)
    ap.add_argument("--compile-manifest", type=Path, default=DEFAULT_COMPILE)
    ap.add_argument("--raw-ledger", type=Path, default=DEFAULT_RAW_LEDGER)
    ap.add_argument("--template-dir", type=Path, default=DEFAULT_TEMPLATE)
    ap.add_argument("--old-exclusion-list", type=Path, default=DEFAULT_OLD_EL)
    ap.add_argument("--data-dir", type=Path, default=DATA)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--prepare-only", action="store_true",
                     help="validate and emit exact candidate/native mapping without hashing or running VDBs")
    args = ap.parse_args()

    data_dir = args.data_dir.resolve()
    out = args.out_dir.resolve()
    out.mkdir(parents=True, exist_ok=False)
    vdb_manifest = json.loads(args.vdb_manifest.read_text(encoding="utf-8"))
    vdb_run = json.loads(args.vdb_run_manifest.read_text(encoding="utf-8"))
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    raw_rows = load_gzip_csv(args.raw_ledger)
    if len(raw_rows) != 4214 or len({r["semantic_bin_id"] for r in raw_rows}) != 4214:
        raise RuntimeError("Expected the 4,214 unique Round 17 exact What-if residual bins")
    if len(vdb_manifest.get("tests", [])) != 551:
        raise RuntimeError("Frozen manifest must contain one Design VDB and 551 Test VDBs")
    if (sha256_file(args.vdb_manifest) != vdb_run.get("vdb_manifest_file_sha256")
            or hashlib.sha256(json.dumps(vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
            != vdb_run.get("vdb_manifest_canonical_sha256")):
        raise RuntimeError("VDB input manifest does not match the prior Raw URG run fingerprint")
    template_run_path = args.template_dir / "run_manifest.json"
    template_run = json.loads(template_run_path.read_text(encoding="utf-8"))
    if template_run.get("vdb_manifest_canonical_sha256") != vdb_run.get("vdb_manifest_canonical_sha256"):
        raise RuntimeError("Native URG templates were not dumped from the same VDB manifest")
    if not args.old_exclusion_list.is_file():
        raise RuntimeError("Existing Round 17 five-batch Analysis-only file list is missing")

    source_hashes = compile_manifest["source_file_sha256"]
    for rel in (
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
        "rtl/dpd/dpd_memory_poly.v",
        "rtl/dpd/dpd_vector16_memory_poly.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
    ):
        if rel not in source_hashes or sha256_file(ROOT / rel) != source_hashes[rel]:
            raise RuntimeError(f"Current product source differs from frozen compile manifest: {rel}")
    native_mod = load_native_parser()
    toggle_scopes = native_mod.parse_native_template(args.template_dir / "fullexclude.tgl")
    candidates: list[dict[str, str]] = []
    for row in raw_rows:
        ef2 = (row["source_file"] == "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
               and (row["exact_urg_bin"].split("Details:", 1)[-1].split(":", 1)[0].startswith(("pair_i.", "pair_q.", "q_one_check["))))
        active = "active_taps" in row["source_position"] and "shadow_taps" not in row["source_position"]
        if not (ef2 or active):
            continue
        row = dict(row)
        row["candidate_batch"] = "EF2_PAIR_LOOKAHEAD_ZERO" if ef2 else "DPD_ACTIVE_TAPS_MAX1"
        status, directive, native_sig, native_line, reason = map_toggle(row, toggle_scopes, source_hashes, compile_manifest)
        row.update({
            "native_mapping_status": status,
            "native_directive": directive,
            "native_declaration": native_sig,
            "native_source_line": "" if native_line is None else str(native_line),
            "mapping_reason": reason,
            "source_parameter_evidence": ("tid32_cartesian_ef2_fs4_gt_tx.sv:parameter PAIR_LOOKAHEAD defaults to 0; pair_i/pair_q zero at always_comb entry and are assigned only under if (PAIR_LOOKAHEAD); product parent omits the override"
                if ef2 and "q_one_check" not in row["source_position"] else
                "tid32_cartesian_ef2_fs4_gt_tx.sv:Q_ONE is derived from W=16 as 1<<15; q_one_check is a sign-extended localparam-derived value and remains used by arithmetic checks"
                if ef2 else
                "MAX_TAPS=1 compile define; thermo5_dpd_axi_lite_cfg.sv legal tap predicate accepts only shadow_taps==1; invalid COMMIT gets SLVERR before mailbox capture; cfg/pending/active reset images all select tap 1; shadow_taps remains software-writable and is excluded from this candidate"),
            "source_hashes_invariant": "852e17a445889491b9ed4f04e94129df82224b68b92322b2edb4534bf7ccd584" if ef2 else "780130a318b4c4e272c4b95d32749ca669ed51585784fa4cb789bf0c1a584ba7;5818119d0b1f5c9fc43574c069319c3e6bd89282f932e4a08842d7a7f2c06156;09d03fa1f1112766604d8045bc031d4fdad4cd61a22d5eff67275d02cdc9b80a;6585ebf3b19f5313e79b4b1a3483b0c4ca923d4c78c67a67876d1ffae4e61f9d;d2621fc061bf225bfa04f357a76410b3c9e589016ff70c7d1019dae8970b77a7",
            "review_status": "PENDING_INDEPENDENT_REVIEW",
            "official_waiver_status": "NOT_APPROVED",
            "analysis_execution_status": "NOT_RUN",
        })
        candidates.append(row)
    expected = {"EF2_PAIR_LOOKAHEAD_ZERO": 2328, "DPD_ACTIVE_TAPS_MAX1": 120}
    actual = {batch: sum(r["candidate_batch"] == batch for r in candidates) for batch in expected}
    if actual != expected:
        raise RuntimeError(f"Exact candidate count mismatch: expected {expected}, got {actual}")
    for batch, count in expected.items():
        rows = [r for r in candidates if r["candidate_batch"] == batch]
        if len({r["semantic_bin_id"] for r in rows}) != count:
            raise RuntimeError(f"Duplicate semantic bin in {batch}")

    # Native templates are indexed per module instance and each candidate must
    # map one-to-one to the same signal, bit and transition direction.
    mapped = [r for r in candidates if r["native_mapping_status"] == "MAPPED_EXACT_NATIVE_BIN"]
    duplicate_targets: dict[tuple, list[dict]] = {}
    for row in mapped:
        key = (row["instance"], row["native_directive"])
        duplicate_targets.setdefault(key, []).append(row)
    for duplicates in duplicate_targets.values():
        if len(duplicates) != 1:
            for row in duplicates:
                row["native_mapping_status"] = "MAPPING_COLLISION_DUPLICATE_NATIVE_TARGET"
                row["native_directive"] = ""
                row["analysis_execution_status"] = "OPEN_MAPPING_COLLISION"
    mapped = [r for r in candidates if r["native_mapping_status"] == "MAPPED_EXACT_NATIVE_BIN"]
    ef2_mapped = [r for r in mapped if r["candidate_batch"] == "EF2_PAIR_LOOKAHEAD_ZERO"]
    active_mapped = [r for r in mapped if r["candidate_batch"] == "DPD_ACTIVE_TAPS_MAX1"]

    ef2_el = data_dir / "f_r17_ef2_pair_and_qone_constants_analysis_only.el"
    active_el = data_dir / "g_r17_dpd_active_taps_max1_analysis_only.el"
    write_el(ef2_el, ef2_mapped, {"tgl": toggle_scopes})
    write_el(active_el, active_mapped, {"tgl": toggle_scopes})
    # Store extension lists next to the native files so URG resolves the same
    # relative file names as the previously qualified Round 17 runner.
    combined_lists = {
        "old_plus_ef2": (*OLD_EL_FILES, ef2_el.name),
        "old_plus_active": (*OLD_EL_FILES, active_el.name),
        "old_plus_all": (*OLD_EL_FILES, ef2_el.name, active_el.name),
    }
    list_paths = {}
    for label, files in combined_lists.items():
        path = data_dir / f"round17_{label}_analysis_only.elfilelist"
        path.write_text("\n".join(files) + "\n", encoding="utf-8")
        list_paths[label] = path

    if args.prepare_only:
        for row in candidates:
            row["analysis_execution_status"] = ("READY_FOR_STRICT_URG_ANALYSIS_ONLY"
                if row["native_mapping_status"] == "MAPPED_EXACT_NATIVE_BIN" else "OPEN_NATIVE_MAPPING")
        write_gzip_csv(data_dir / "round17_residual_fixed_config_candidates.csv.gz",
                       sorted(candidates, key=lambda r: r["semantic_bin_id"]))
        print(json.dumps({
            "candidate_count": actual,
            "native_exact_mapped_count": {
                "EF2_PAIR_LOOKAHEAD_ZERO": sum(r["candidate_batch"] == "EF2_PAIR_LOOKAHEAD_ZERO" for r in mapped),
                "DPD_ACTIVE_TAPS_MAX1": sum(r["candidate_batch"] == "DPD_ACTIVE_TAPS_MAX1" for r in mapped),
                "total": len(mapped),
            },
            "mapping_failures": [{"semantic_bin_id": r["semantic_bin_id"], "status": r["native_mapping_status"]}
                                 for r in candidates if r["native_mapping_status"] != "MAPPED_EXACT_NATIVE_BIN"],
        }, sort_keys=True), flush=True)
        return 0

    # Validate every VDB tree once before URG, then again after all reports.
    vdb_inputs = [vdb_manifest["design"], *vdb_manifest["tests"]]
    before = []
    for item in vdb_inputs:
        path = Path(item["path"])
        if not path.is_dir():
            raise RuntimeError(f"Frozen VDB is absent: {path}")
        fp = tree_fingerprint(path)
        if any(fp[k] != item[k] for k in ("file_count", "total_bytes", "tree_sha256")):
            raise RuntimeError(f"Frozen VDB fingerprint mismatch: {path}")
        before.append({"path": str(path), **fp})

    raw_command = vdb_run["command"]
    if "-format" not in raw_command:
        raise RuntimeError("Frozen Raw URG command missing -format separator")
    base = raw_command[:raw_command.index("-format")]
    if len([a for a in base if a.endswith(".vdb")]) != 552:
        raise RuntimeError("Frozen URG command does not contain 552 VDBs")
    if [a for a in base if a.endswith(".vdb")] != [x["path"] for x in vdb_inputs]:
        raise RuntimeError("Frozen URG command order differs from VDB manifest")
    env = os.environ.copy()
    vcs_home = Path("/opt/Synopsys/vcs/V-2023.12-SP1")
    libpaths = [str(vcs_home / "lib"), str(vcs_home / "linux64/lib")]
    env["LD_LIBRARY_PATH"] = ":".join(libpaths + ([env["LD_LIBRARY_PATH"]] if env.get("LD_LIBRARY_PATH") else []))
    urg = args.urg.resolve()
    if not urg.is_file():
        raise RuntimeError(f"URG binary is missing: {urg}")

    labels = {
        "raw": [],
        "legacy_8957": ["-elfilelist", str(args.old_exclusion_list.resolve())],
        "ef2_pair_qone_only": ["-elfile", str(ef2_el.resolve())],
        "active_taps_only": ["-elfile", str(active_el.resolve())],
        "legacy_plus_ef2": ["-elfilelist", str(list_paths["old_plus_ef2"])],
        "legacy_plus_active": ["-elfilelist", str(list_paths["old_plus_active"])],
        "legacy_plus_all": ["-elfilelist", str(list_paths["old_plus_all"])],
    }
    raw_expected = {"branch": (524, 637), "cond": (657, 849), "line": (3338, 3796), "toggle": (92072, 104480)}
    delta_expected = {
        "raw": {m: 0 for m in PRODUCT_METRICS},
        "legacy_8957": {"branch": 98, "cond": 108, "line": 429, "toggle": 8322},
        "ef2_pair_qone_only": {"branch": 0, "cond": 0, "line": 0, "toggle": len(ef2_mapped)},
        "active_taps_only": {"branch": 0, "cond": 0, "line": 0, "toggle": len(active_mapped)},
        "legacy_plus_ef2": {"branch": 98, "cond": 108, "line": 429, "toggle": 8322 + len(ef2_mapped)},
        "legacy_plus_active": {"branch": 98, "cond": 108, "line": 429, "toggle": 8322 + len(active_mapped)},
        "legacy_plus_all": {"branch": 98, "cond": 108, "line": 429, "toggle": 8322 + len(mapped)},
    }
    results = {}
    reference_fsm = reference_assert = None
    raw_metrics = None
    for label, extra in labels.items():
        report = out / label / "report"
        log = out / label / "urg.log"
        command = [str(urg), *base[1:], *extra]
        if label != "raw":
            command.append("-excl_strict")
        command += ["-format", "both", "-report", str(report), "-dbname", f"thermo5_r17_residual_{label}", "-log", str(log)]
        run_command(command, env, out, log)
        summary = coverage_summary(report, out / label / "inventory")
        metrics = product_metrics(summary)
        if raw_metrics is None:
            raw_metrics = metrics
            if any((metrics.get(m, {}).get("covered"), metrics.get(m, {}).get("total")) != raw_expected[m] for m in PRODUCT_METRICS):
                raise RuntimeError(f"Fresh Raw URG differs from Round 17 baseline: {metrics}")
            reference_fsm, reference_assert = fsm_assertions(summary)
        else:
            if metrics.keys() != raw_metrics.keys():
                raise RuntimeError(f"Metric set changed in {label}")
            changed = {m: (raw_metrics[m]["covered"], metrics[m]["covered"]) for m in PRODUCT_METRICS
                       if raw_metrics[m]["covered"] != metrics[m]["covered"]}
            if changed:
                raise RuntimeError(f"Covered numerators changed in {label}: {changed}")
            if fsm_assertions(summary) != (reference_fsm, reference_assert):
                raise RuntimeError(f"FSM or assertion coverage changed in {label}")
        deltas = {m: raw_metrics[m]["total"] - metrics[m]["total"] for m in PRODUCT_METRICS}
        if deltas != delta_expected[label]:
            raise RuntimeError(f"Exact denominator delta mismatch for {label}: expected {delta_expected[label]}, got {deltas}")
        results[label] = {
            "coverage": metrics,
            "excluded_bins_by_metric": deltas,
            "fsm_and_assertion_unchanged": True,
            "command": command,
            "log_sha256": sha256_file(log),
            "report_path": str(report),
        }
        print(f"{label}: metrics={metrics} excluded={deltas} (strict, no diagnostics)", flush=True)

    for row in candidates:
        row["analysis_execution_status"] = ("EXCLUDED_ANALYSIS_ONLY_STRICT_URG"
            if row["native_mapping_status"] == "MAPPED_EXACT_NATIVE_BIN" else "OPEN_NATIVE_MAPPING")
        batch_key = "ef2_pair_qone_only" if row["candidate_batch"] == "EF2_PAIR_LOOKAHEAD_ZERO" else "active_taps_only"
        row["strict_urg_log_sha256"] = results.get(batch_key, {}).get("log_sha256", "")

    after = []
    for item in vdb_inputs:
        path = Path(item["path"])
        fp = tree_fingerprint(path)
        if any(fp[k] != item[k] for k in ("file_count", "total_bytes", "tree_sha256")):
            raise RuntimeError(f"Frozen VDB changed during URG: {path}")
        after.append({"path": str(path), **fp})

    excluded_new = {r["semantic_bin_id"] for r in mapped}
    prior_remaining = {r["semantic_bin_id"] for r in raw_rows}
    if not excluded_new.issubset(prior_remaining):
        raise RuntimeError("New candidate is not a subset of the prior exact remaining ledger")
    new_remaining = [dict(r) for r in raw_rows if r["semantic_bin_id"] not in excluded_new]
    for row in new_remaining:
        row["whatif_remaining_status"] = "OPEN_AFTER_R17_EXTRA_FIXED_CONFIG_BATCH"
        row["official_adjusted_status"] = "UNCHANGED_RAW_OPEN"
    if (len(new_remaining), {m: sum(r["metric"] == m for r in new_remaining) for m in PRODUCT_METRICS}) != (
        4214 - len(mapped), {"branch": 15, "cond": 84, "line": 29, "toggle": 4086 - len(mapped)}):
        raise RuntimeError("Combined exact semantic remaining ledger did not reconcile with the mapped candidates")
    write_gzip_csv(args.data_dir.resolve() / "round17_residual_fixed_config_candidates.csv.gz", sorted(candidates, key=lambda r: r["semantic_bin_id"]))
    write_gzip_csv(args.data_dir.resolve() / "round17_residual_exact_whatif_remaining_bins.csv.gz", sorted(new_remaining, key=lambda r: r["semantic_bin_id"]))

    summary = {
        "schema": "thermo5_tx_r17_residual_toggle_whatif_v1",
        "analysis_only": True,
        "official_waiver_approval_count": 0,
        "official_exclusion_count": 0,
        "source_head_for_vdb": vdb_run.get("source_head"),
        "product_source_sha": compile_manifest.get("product_source_sha"),
        "product_rtl_aggregate_sha256": compile_manifest.get("product_rtl_aggregate_sha256"),
        "compile_fingerprint_sha256": compile_manifest.get("compile_fingerprint_sha256"),
        "vdb_manifest_sha256": vdb_run.get("vdb_manifest_canonical_sha256"),
        "vdb_manifest_file_sha256": vdb_run.get("vdb_manifest_file_sha256"),
        "design_vdb_count": 1,
        "test_vdb_count": 551,
        "vdb_tree_mismatches": 0,
        "urg_binary": str(urg),
        "urg_version": vdb_run.get("urg_version"),
        "candidate_count": actual,
        "native_exact_mapped_count": {"EF2_PAIR_LOOKAHEAD_ZERO": len(ef2_mapped), "DPD_ACTIVE_TAPS_MAX1": len(active_mapped), "total": len(mapped)},
        "native_mapping_failures": [{"semantic_bin_id": r["semantic_bin_id"], "status": r["native_mapping_status"], "reason": r["mapping_reason"]} for r in candidates if r["native_mapping_status"] != "MAPPED_EXACT_NATIVE_BIN"],
        "analysis_el_sha256": {"ef2": sha256_file(ef2_el), "active_taps": sha256_file(active_el)},
        "run_results": results,
        "raw_whatif_remaining_bin_count": len(raw_rows),
        "new_whatif_remaining_bin_count": len(new_remaining),
        "new_whatif_remaining_by_metric": {m: sum(r["metric"] == m for r in new_remaining) for m in PRODUCT_METRICS},
        "vdb_fingerprints_before": before,
        "vdb_fingerprints_after": after,
        "review_status": "PENDING_INDEPENDENT_REVIEW",
        "signoff_status": "OPEN_NOT_OFFICIAL_SIGNOFF",
        "created_unix_time": int(time.time()),
    }
    (out / "whatif_manifest.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"new_candidates_mapped": summary["native_exact_mapped_count"],
                      "remaining": summary["new_whatif_remaining_by_metric"],
                      "runs": {k: v["excluded_bins_by_metric"] for k, v in results.items()}}, sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
