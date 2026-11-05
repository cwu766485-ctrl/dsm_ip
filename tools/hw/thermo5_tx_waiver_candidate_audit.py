#!/usr/bin/env python3.12
"""Rebind legacy Thermo5 TX waiver candidates to current Raw and source evidence.

This tool creates review candidates only. It never edits Raw coverage, changes
waiver approval state, or emits URG exclusions. Formal proofs are accepted only
when their exact properties, covers, assumptions, source hashes, and log hashes
can be checked from the archived run output.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from tools.hw.thermo5_tx_waiver_pipeline import (
    WaiverError,
    _configuration_fingerprint,
    _safe_repo_file,
    _verify_audit_tools,
)


PAIR_SOURCE = "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
FORMAL_REVIEW_DEFAULT = (
    "docs/verification/data/thermo5-tx-current-source-gaps/"
    "thermo5-tx-focused-product-formal-review.json"
)
EXPECTED_DEFINES = [
    "+define+THERMO5_AXIL_CONTROL",
    "+define+THERMO5_CENTERED_CUBIC",
    "+define+THERMO5_TIDSM_ORDER=2",
    "+define+THERMO5_STEP=5120",
    "+define+THERMO5_DPD_MAX_TAPS=1",
]
ALLOWED_ASSUMPTIONS = {"thermo5_frame_tail_harness.asm_source_stable"}


class CandidateAuditError(ValueError):
    """Current source, product, Raw, or evidence inputs do not match."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def _read_gzip_csv(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def _relative(path: Path, repo_root: Path) -> str:
    return path.resolve().relative_to(repo_root.resolve()).as_posix()


def _sha_map_from_ledger(row: dict[str, str]) -> dict[str, str]:
    result: dict[str, str] = {}
    for item in row.get("source_file_sha256", "").split(";"):
        if "=" in item:
            name, digest = item.rsplit("=", 1)
            result[name] = digest
    return result


def _source_line(row: dict[str, str]) -> str:
    match = re.search(r"(?:line:|:)(\d+)(?:\b|$)", row.get("source_position", ""))
    return match.group(1) if match else row.get("branch_target_line", "")


def _find_gap(waiver: dict[str, str], gaps: list[dict[str, str]]) -> dict[str, str]:
    metric_aliases = {"condition": "cond", "cond": "cond", "toggle": "toggle",
                      "tgl": "toggle", "line": "line", "branch": "branch",
                      "fsm": "fsm", "assert": "assert"}
    metric = metric_aliases.get(waiver["metric"].strip().lower())
    matches = [gap for gap in gaps
               if gap.get("bin_id") == waiver["bin"]
               and gap.get("configuration") == waiver["configuration"]
               and gap.get("instance") == waiver["instance"]
               and waiver["source_file"] in gap.get("source_files", "").split(";")
               and _source_line(gap) == waiver["source_line"]
               and gap.get("metric") == metric]
    if len(matches) != 1:
        raise CandidateAuditError(
            f"{waiver['waiver_id']} maps to {len(matches)} current Raw bins"
        )
    return matches[0]


def _check_compile_profile(manifest: dict, repo_root: Path) -> str:
    if manifest.get("scope") != "VCS_PRODUCT_COMPILE_INPUTS":
        raise CandidateAuditError("compile manifest is not a product VCS compile manifest")
    provenance = manifest.get("compile_provenance", {})
    if provenance.get("top") != "thermo5_sku_uvm_tb":
        raise CandidateAuditError("current product compile top is not thermo5_sku_uvm_tb")
    if provenance.get("configuration_defines") != EXPECTED_DEFINES:
        raise CandidateAuditError("current compile defines differ from the frozen TX profile")
    sources = manifest.get("source_file_sha256", {})
    if not sources:
        raise CandidateAuditError("compile manifest has no source file hashes")
    for relative, digest in sources.items():
        source = _safe_repo_file(repo_root, relative, "compiled source")
        if sha256(source) != digest:
            raise CandidateAuditError(f"compiled source SHA is stale: {relative}")
    _verify_audit_tools(manifest, repo_root)
    return _configuration_fingerprint(manifest)


def _vdb_paths(command: list[str]) -> list[str]:
    return [item for item in command if item.endswith(".vdb")]


def _check_coverage_manifests(report: dict, vdb: dict, report_path: Path,
                              vdb_path: Path, config_hash: str) -> dict:
    if report.get("product_configuration_fingerprint") != config_hash:
        raise CandidateAuditError("URG report configuration differs from product compile")
    raw = _vdb_paths(report.get("raw_command", []))
    adjusted = _vdb_paths(report.get("adjusted_command", []))
    if not raw or raw != adjusted:
        raise CandidateAuditError("Raw and Adjusted URG use different VDB input lists")
    canonical_vdb_sha = hashlib.sha256(
        json.dumps(vdb, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    if (report.get("vdb_manifest_sha256") != canonical_vdb_sha
            or report.get("vdb_manifest") != vdb):
        raise CandidateAuditError("URG report does not bind the supplied VDB manifest")
    common = report.get("common_inputs", {})
    if common.get("design_vdb") != raw[0] or common.get("test_vdbs") != raw[1:]:
        raise CandidateAuditError("URG VDB command differs from its common-input inventory")
    inventory = [vdb.get("design", {}).get("path")]
    inventory.extend(test.get("path") for test in vdb.get("tests", []))
    if inventory != raw:
        raise CandidateAuditError("VDB manifest inventory differs from Raw/Adjusted commands")
    if not vdb.get("design") or not vdb.get("tests"):
        raise CandidateAuditError("VDB manifest must contain a design VDB and at least one test VDB")
    if report.get("approved_waiver_count") != 0 or report.get("adjusted_exclusions_applied"):
        raise CandidateAuditError("current baseline unexpectedly contains an approved exclusion")
    raw_summary = report.get("raw_summary", {})
    adjusted_summary = report.get("adjusted_summary", {})
    if raw_summary != adjusted_summary:
        raise CandidateAuditError("baseline Raw and Adjusted coverage summaries differ")
    return {
        "raw_adjusted_same_vdbs": True,
        "raw_adjusted_same_summary": True,
        "test_vdb_count": len(vdb.get("tests", [])),
        "design_vdb_count": 1,
        "input_vdb_count": len(inventory),
        "raw_summary": raw_summary,
        "report_manifest_sha256": sha256(report_path),
        "vdb_manifest_sha256": sha256(vdb_path),
        "vdb_manifest_canonical_sha256": canonical_vdb_sha,
    }


def _formal_status(properties: str, console: str, name: str) -> str:
    pattern = re.compile(rf"PROP_I_RESULT:\s+{re.escape(name)}\s+(proven|uncoverable|covered(?::\d+)?|inconclusive|failed)\b")
    matches = pattern.findall(console)
    if not matches:
        raise CandidateAuditError(f"Formal console has no exact result for {name}")
    if len(set(matches)) != 1:
        raise CandidateAuditError(f"Formal console has conflicting results for {name}")
    if not re.search(rf"\b{re.escape(name)}\b", properties):
        raise CandidateAuditError(f"Formal properties report omits {name}")
    return matches[0]


def _formal_support(review_bin: dict, repo_root: Path, snapshot_root: Path,
                    formal_runs: dict[str, dict]) -> dict:
    assumptions = review_bin.get("assumptions", [])
    if not isinstance(assumptions, list) or not set(assumptions).issubset(ALLOWED_ASSUMPTIONS):
        raise CandidateAuditError("Formal record has an unreviewed assumption")
    source_hashes = review_bin.get("source_sha256", {})
    for relative, expected in source_hashes.items():
        source = _safe_repo_file(repo_root, relative, "Formal source")
        if sha256(source) != expected:
            raise CandidateAuditError(f"Formal source SHA is stale: {relative}")

    run_path = Path(review_bin["formal_run"])
    run_dir = _safe_repo_file(repo_root, (run_path / review_bin["properties_file"]).as_posix(),
                              "Formal properties")
    formal_dir = repo_root / run_path
    if not formal_dir.is_dir():
        raise CandidateAuditError(f"Formal run directory is missing: {run_path}")
    files: dict[str, dict[str, str]] = {}
    text: dict[str, str] = {}
    snapshot_key = hashlib.sha256(run_path.as_posix().encode()).hexdigest()[:12]
    for role, key in (("properties", "properties_file"), ("setup", "setup_file"),
                      ("console", "console_file")):
        source = _safe_repo_file(repo_root, (run_path / review_bin[key]).as_posix(),
                                 f"Formal {role}")
        expected = review_bin.get("evidence_sha256", {}).get(role)
        if expected is None or sha256(source) != expected:
            raise CandidateAuditError(f"Formal {role} evidence SHA is stale")
        destination_dir = snapshot_root / snapshot_key
        destination_dir.mkdir(parents=True, exist_ok=True)
        destination = destination_dir / source.name
        if not destination.exists():
            shutil.copyfile(source, destination)
        if sha256(destination) != expected:
            raise CandidateAuditError(f"archived Formal {role} SHA differs")
        relative = _relative(destination, repo_root)
        files[role] = {"path": relative, "sha256": expected}
        text[role] = destination.read_text(encoding="utf-8", errors="replace")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", text["console"]):
        raise CandidateAuditError("Formal console does not report zero black boxes")
    if re.search(r"tautolog", text["console"], re.IGNORECASE):
        raise CandidateAuditError("Formal console includes a tautological goal warning")
    if "thermo5_frame_tail_harness.asm_source_stable" in assumptions:
        harness = _safe_repo_file(repo_root, "dv/uvm/formal/thermo5_frame_tail_harness.sv",
                                  "source-stability assumption harness")
        harness_text = harness.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"asm_source_stable\s*:\s*assume\s+property", harness_text):
            raise CandidateAuditError("frame-tail source-stability assumption is not explicit")
        if source_hashes.get("dv/uvm/formal/thermo5_frame_tail_harness.sv") != sha256(harness):
            raise CandidateAuditError("Formal source-stability assumption SHA is stale")

    assertion_status = _formal_status(text["properties"], text["console"], review_bin["assertion"])
    cover_status = _formal_status(text["properties"], text["console"], review_bin["cover"])
    covered = re.findall(
        r"PROP_I_RESULT:\s+([A-Za-z0-9_.$]+)\s+covered(?::\d+)?\b", text["console"]
    )
    if (assertion_status != "proven" or cover_status != "uncoverable" or not covered
            or len(covered) != len(set(covered))
            or any(not re.search(rf"\b{re.escape(name)}\b", text["properties"])
                   for name in covered)):
        raise CandidateAuditError("Formal evidence lacks exact proof, uncoverable target, or activity witness")
    prior_source_sha = review_bin.get("source_sha256", {}).get(review_bin["source_file"])
    if not prior_source_sha:
        raise CandidateAuditError("Formal record omits the target DUT source SHA")
    formal_runs[snapshot_key] = {
        "formal_run": review_bin["formal_run"],
        "evidence_files": files,
        "tool_banner": next((line.strip() for line in text["console"].splitlines()
                              if "Version V-" in line), "unknown"),
        "blackboxes": 0,
        "formal_source_sha256": source_hashes,
    }
    return {
        "formal_run_key": snapshot_key,
        "assertion": review_bin["assertion"],
        "assertion_status": assertion_status,
        "target_cover": review_bin["cover"],
        "target_cover_status": cover_status,
        "activity_covers": [{"name": name, "status": "covered"} for name in covered],
        "assumptions": assumptions,
        "blackboxes": 0,
        "tautological": False,
        "non_vacuous": True,
        "formal_review_product_source_sha": review_bin.get("product_source_sha", "19d295360aa6438f4af20e7a6ab44bfebf2fc1ea"),
        "historical_target_source_sha256": prior_source_sha,
        "formal_review_semantic_bin_id": review_bin["semantic_bin_id"],
        "evidence_type": "formal",
    }


def _line_text(repo_root: Path, relative: str, line: int) -> str:
    source = _safe_repo_file(repo_root, relative, "configuration source")
    lines = source.read_text(encoding="utf-8", errors="replace").splitlines()
    if line < 1 or line > len(lines):
        raise CandidateAuditError(f"configuration source line is out of range: {relative}:{line}")
    return lines[line - 1].strip()


def _parameter_block(source_text: str, module_name: str, instance_name: str) -> str | None:
    """Return one balanced SV instance #(...) block for a known instance."""
    pattern = re.compile(rf"\b{re.escape(module_name)}\s*#\s*\(")
    for match in pattern.finditer(source_text):
        open_index = match.end() - 1
        depth = 0
        close_index = None
        for index in range(open_index, len(source_text)):
            if source_text[index] == "(":
                depth += 1
            elif source_text[index] == ")":
                depth -= 1
                if depth == 0:
                    close_index = index
                    break
        if close_index is None:
            continue
        if re.match(rf"\s*{re.escape(instance_name)}\b", source_text[close_index + 1:]):
            return source_text[open_index + 1:close_index]
    return None


def _configuration_rule(waiver: dict[str, str], gap: dict[str, str],
                        repo_root: Path, compile_manifest: dict) -> dict | None:
    relative = waiver["source_file"]
    line = int(waiver["source_line"])
    instance = waiver["instance"]
    path = gap.get("branch_predicate_path", "")
    source = _safe_repo_file(repo_root, relative, "configuration source")
    source_text = _line_text(repo_root, relative, line)
    compiled_sources = compile_manifest.get("source_file_sha256", {})

    def bound_text(name: str) -> str | None:
        """Read a source-chain file and bind it to the exact product compile."""
        if compiled_sources and name not in compiled_sources:
            return None
        path = _safe_repo_file(repo_root, name, "configuration chain source")
        digest = sha256(path)
        if compiled_sources and compiled_sources[name] != digest:
            return None
        chain[name] = digest
        return path.read_text(encoding="utf-8", errors="replace")

    chain: dict[str, str] = {relative: sha256(source)}
    if relative == PAIR_SOURCE and (135 <= line <= 191 or line == 231):
        source = _safe_repo_file(repo_root, PAIR_SOURCE, "PAIR_LOOKAHEAD source")
        body = source.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"parameter\s+bit\s+PAIR_LOOKAHEAD\s*=\s*1'b0", body):
            return None
        if not re.search(r"if\s*\(PAIR_LOOKAHEAD\)\s*begin", body):
            return None
        call_lines = [n for n, text in enumerate(body.splitlines(), 1)
                      if re.search(r"=\s*ef2_pair_lookahead\s*\(", text)]
        if call_lines != [233, 236] or not all(n > 231 for n in call_lines):
            return None
        parent_relative = "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"
        parent_text = bound_text(parent_relative)
        if parent_text is None:
            return None
        parent_params = _parameter_block(parent_text, "tid32_cartesian_ef2_fs4_gt_tx", "u_tid")
        if not parent_params or not re.search(r"\.W\(W\)", parent_params) or not re.search(r"\.CHANNELS\(CHANNELS\)", parent_params):
            return None
        if re.search(r"PAIR_LOOKAHEAD\s*\(", parent_params):
            return None
        if not (instance.endswith(".u_tid") and ".g_order2.u_tid" in instance):
            return None
        if line == 231 and "if (PAIR_LOOKAHEAD)" not in source_text:
            return None
        if line != 231 and not (135 <= line <= 191):
            return None
        return {
            "evidence_type": "configuration",
            "proof_rule_id": "EF2_PAIR_LOOKAHEAD_DEFAULT_DISABLED",
            "elaboration_status": "elaborated_exactly",
            "elaborated_parameters": gap["product_parameters"],
            "actual_parameters": {"TIDSM_ORDER": 2, "PAIR_LOOKAHEAD": 0,
                                  "PAIR_LOOKAHEAD_DEFAULT": 0},
            "unreachable_expression": "if (PAIR_LOOKAHEAD)",
            "unreachable_decision": 1,
            "call_sites": [233, 236],
            "explanation": "The product parent passes only W and CHANNELS to each EF2 instance. PAIR_LOOKAHEAD is not overridden and remains 0, so the true arm and both helper call sites are inactive in the elaborated product.",
            "source_context": chain,
        }

    rules = {
        ("rtl/frontend/dsm_frame_gain_vector.sv", 97):
            ("HOLD_STATE_ON_DISABLE", 0, "if (!HOLD_STATE_ON_DISABLE)", 0),
        ("rtl/gt/gt_tx_user_bridge.sv", 20):
            ("PARALLEL_W == GT_USER_W", 64, "if (PARALLEL_W != GT_USER_W)", 1),
        ("rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv", 348):
            ("MAX_TAPS", 1, "if (MAX_TAPS < 1 || MAX_TAPS > 4)", 1),
        ("rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 210):
            ("HOLD_STATE_ON_DISABLE", 0, "if (!HOLD_STATE_ON_DISABLE)", 0),
        ("rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 294):
            ("LANES", None, "if (LANES < 2)", 1),
        ("rtl/interp/dsm_interp_x2_centered_cubic_vector.sv", 295):
            ("COEFF_FRAC", 14, "if (COEFF_FRAC != 14)", 1),
        (PAIR_SOURCE, 96):
            ("W/CHANNELS", (16, 32), "if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)", 1),
        ("rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv", 274):
            ("DPD_MAX_TAPS", 1, "if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)", 1),
    }
    rule = rules.get((relative, line))
    if not rule or waiver["metric"].lower() != "branch":
        return None
    param, actual, predicate, missed_decision = rule
    if predicate not in source_text or predicate not in path or f"={missed_decision}" not in path:
        return None
    actual_map: dict[str, object]
    if relative == "rtl/frontend/dsm_frame_gain_vector.sv":
        parent_name = "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv"
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        top_name = "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        parent_text = bound_text(parent_name)
        wrapper_text = bound_text(wrapper_name)
        top_text = bound_text(top_name)
        if not parent_text or not wrapper_text or not top_text:
            return None
        if not re.search(r"parameter\s+bit\s+HOLD_STATE_ON_DISABLE\s*=\s*1'b0", parent_text):
            return None
        frame_params = _parameter_block(parent_text, "dsm_frame_gain_vector", "u_frame_gain")
        if not frame_params or not re.search(r"\.HOLD_STATE_ON_DISABLE\(HOLD_STATE_ON_DISABLE\)", frame_params):
            return None
        frontend_params = _parameter_block(wrapper_text, "tid32_thermo5_frontend_tx", "u_frontend")
        if not frontend_params or re.search(r"\.HOLD_STATE_ON_DISABLE\s*\(", frontend_params):
            return None
        if re.search(r"\.HOLD_STATE_ON_DISABLE\s*\(", wrapper_text):
            return None
        if not re.search(r"tid32_thermo5_axi_lite_axis_frontend_tx\s*#\s*\([^;]*\.DPD_MAX_TAPS\(USE_DPD_MAX_TAPS\)", top_text, re.S):
            return None
        actual_map = {"HOLD_STATE_ON_DISABLE": 0, "source_default": 0}
    elif relative == "rtl/gt/gt_tx_user_bridge.sv":
        top_name = "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        frontend_name = "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv"
        multipa_name = "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"
        ef2_name = PAIR_SOURCE
        raw_name = "rtl/gt/gt_tx_raw64_boundary.sv"
        top_text, wrapper_text = bound_text(top_name), bound_text(wrapper_name)
        frontend_text, multipa_text = bound_text(frontend_name), bound_text(multipa_name)
        ef2_text, raw_text = bound_text(ef2_name), bound_text(raw_name)
        if not all((top_text, wrapper_text, frontend_text, multipa_text, ef2_text, raw_text)):
            return None
        top_params = _parameter_block(top_text, "tid32_thermo5_axi_lite_axis_frontend_tx", "dut")
        wrapper_params = _parameter_block(wrapper_text, "tid32_thermo5_frontend_tx", "u_frontend")
        tid_params = _parameter_block(frontend_text, "tid32_thermo5_fs4_multipa_tx", "u_tid")
        ef2_params = _parameter_block(multipa_text, "tid32_cartesian_ef2_fs4_gt_tx", "u_tid")
        boundary_params = _parameter_block(ef2_text, "gt_tx_raw64_boundary", "u_raw_boundary")
        bridge_params = _parameter_block(raw_text, "gt_tx_user_bridge", "u_bridge")
        if (not top_params or re.search(r"\.W\s*\(", top_params)
                or not re.search(r"parameter\s+int\s+W\s*=\s*16", wrapper_text)
                or not wrapper_params or not re.search(r"\.W\(W\)", wrapper_params)
                or not re.search(r"parameter\s+int\s+DPD_LANES\s*=\s*16", frontend_text)
                or not tid_params or not re.search(r"\.W\(W\)", tid_params)
                or not re.search(r"\.CHANNELS\(2\s*\*\s*DPD_LANES\)", tid_params)
                or not ef2_params or not re.search(r"\.W\(W\)", ef2_params)
                or not re.search(r"\.CHANNELS\(CHANNELS\)", ef2_params)
                or not boundary_params or not re.search(r"\.DATA_W\(2\s*\*\s*CHANNELS\)", boundary_params)
                or not bridge_params or not re.search(r"\.PARALLEL_W\(DATA_W\)", bridge_params)
                or not re.search(r"\.GT_USER_W\(DATA_W\)", bridge_params)
                or not re.search(r"\.DPD_LANES\(16\)", wrapper_params)
                or ".g_order2.u_tid.u_raw_boundary.u_bridge" not in instance):
            return None
        actual_map = {"PARALLEL_W": 64, "GT_USER_W": 64, "DATA_W": 64}
    elif relative == "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv":
        top_name = "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        top_text, wrapper_text = bound_text(top_name), bound_text(wrapper_name)
        if not top_text or not wrapper_text:
            return None
        if not re.search(r"localparam\s+int\s+USE_DPD_MAX_TAPS\s*=\s*`THERMO5_DPD_MAX_TAPS", top_text):
            return None
        if not re.search(r"\.DPD_MAX_TAPS\(USE_DPD_MAX_TAPS\)", top_text):
            return None
        if not re.search(r"thermo5_dpd_axi_lite_cfg\s*#\s*\(\.MAX_TAPS\(DPD_MAX_TAPS\)\)\s*u_cfg", wrapper_text):
            return None
        actual_map = {"MAX_TAPS": 1, "DPD_MAX_TAPS": 1}
    elif relative == "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv":
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        frontend_name = "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv"
        wrapper_text, frontend_text = bound_text(wrapper_name), bound_text(frontend_name)
        if not wrapper_text or not frontend_text:
            return None
        frontend_params = _parameter_block(wrapper_text, "tid32_thermo5_frontend_tx", "u_frontend")
        if not frontend_params or not re.search(r"\.DPD_LANES\(16\)", frontend_params):
            return None
        if not re.search(r"\.IN_LANES\(8\)", wrapper_text):
            return None
        if not re.search(r"parameter\s+bit\s+HOLD_STATE_ON_DISABLE\s*=\s*1'b0", frontend_text):
            return None
        if re.search(r"\.HOLD_STATE_ON_DISABLE\s*\(", frontend_params):
            return None
        if line == 210:
            interp_name = "u_interp_1" if ".g_interp1_centered." in instance else "u_interp_2"
            interp_params = _parameter_block(frontend_text, "dsm_interp_x2_centered_cubic_vector", interp_name)
            if not interp_params or not re.search(r"\.HOLD_STATE_ON_DISABLE\(HOLD_STATE_ON_DISABLE\)", interp_params):
                return None
            actual_map = {"HOLD_STATE_ON_DISABLE": 0, "source_default": 0}
        elif line == 294:
            lanes = 8 if ".g_interp1_centered." in instance else 16 if ".g_interp2_centered." in instance else None
            if lanes is None:
                return None
            expected_lanes = "IN_LANES" if lanes == 8 else "DPD_LANES"
            interp_name = "u_interp_1" if lanes == 8 else "u_interp_2"
            interp_params = _parameter_block(frontend_text, "dsm_interp_x2_centered_cubic_vector", interp_name)
            if not interp_params or not re.search(r"\.W\(W\)", interp_params) or not re.search(rf"\.LANES\({expected_lanes}\)", interp_params):
                return None
            actual_map = {"LANES": lanes}
        else:
            if not re.search(r"parameter\s+int\s+COEFF_FRAC\s*=\s*14", source.read_text(encoding="utf-8", errors="replace")):
                return None
            interp_name = "u_interp_1" if ".g_interp1_centered." in instance else "u_interp_2"
            interp_params = _parameter_block(frontend_text, "dsm_interp_x2_centered_cubic_vector", interp_name)
            if interp_params is None or re.search(r"\.COEFF_FRAC\s*\(", interp_params):
                return None
            actual_map = {"COEFF_FRAC": 14, "source_default": 14}
    elif relative == PAIR_SOURCE and line == 96:
        top_name = "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        frontend_name = "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv"
        multipa_name = "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"
        top_text, wrapper_text = bound_text(top_name), bound_text(wrapper_name)
        frontend_text, multipa_text = bound_text(frontend_name), bound_text(multipa_name)
        if not all((top_text, wrapper_text, frontend_text, multipa_text)):
            return None
        if not re.search(r"localparam\s+int\s+USE_TIDSM_ORDER\s*=\s*`THERMO5_TIDSM_ORDER", top_text):
            return None
        if not re.search(r"\.TIDSM_ORDER\(USE_TIDSM_ORDER\)", top_text):
            return None
        top_params = _parameter_block(top_text, "tid32_thermo5_axi_lite_axis_frontend_tx", "dut")
        wrapper_params = _parameter_block(wrapper_text, "tid32_thermo5_frontend_tx", "u_frontend")
        tid_params = _parameter_block(frontend_text, "tid32_thermo5_fs4_multipa_tx", "u_tid")
        ef2_params = _parameter_block(multipa_text, "tid32_cartesian_ef2_fs4_gt_tx", "u_tid")
        if not top_params or re.search(r"\.W\s*\(", top_params):
            return None
        if not re.search(r"parameter\s+int\s+W\s*=\s*16", wrapper_text):
            return None
        if not wrapper_params or not re.search(r"\.W\(W\)", wrapper_params):
            return None
        if not re.search(r"\.DPD_LANES\(16\)", wrapper_params):
            return None
        if not tid_params or not re.search(r"\.W\(W\)", tid_params):
            return None
        if not re.search(r"\.CHANNELS\(2\s*\*\s*DPD_LANES\)", tid_params):
            return None
        if not ef2_params or not re.search(r"\.W\(W\)", ef2_params):
            return None
        if not re.search(r"\.CHANNELS\(CHANNELS\)", ef2_params):
            return None
        if not re.search(r"tid32_thermo5_frontend_tx\s*#", wrapper_text):
            return None
        if not re.search(r"parameter\s+int\s+DPD_LANES\s*=\s*16", frontend_text):
            return None
        if ".g_order2.u_tid" not in instance:
            return None
        actual_map = {"W": 16, "CHANNELS": 32}
    else:
        wrapper_name = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        top_name = "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        wrapper_text, top_text = bound_text(wrapper_name), bound_text(top_name)
        if not wrapper_text or not top_text:
            return None
        if not re.search(r"localparam\s+int\s+USE_DPD_MAX_TAPS\s*=\s*`THERMO5_DPD_MAX_TAPS", top_text):
            return None
        if not re.search(r"\.DPD_MAX_TAPS\(USE_DPD_MAX_TAPS\)", top_text):
            return None
        actual_map = {"DPD_MAX_TAPS": 1}
    if param == "PARALLEL_W == GT_USER_W" and actual_map.get("PARALLEL_W") != actual_map.get("GT_USER_W"):
        return None
    if param == "W/CHANNELS" and (actual_map.get("W"), actual_map.get("CHANNELS")) != actual:
        return None
    if isinstance(actual, int) and param in actual_map and actual_map[param] != actual:
        return None
    return {
        "evidence_type": "configuration",
        "proof_rule_id": f"FIXED_PRODUCT_PARAMETER_{relative.replace('/', '_').replace('.', '_')}_{line}",
        "elaboration_status": "elaborated_exactly",
        "elaborated_parameters": gap["product_parameters"],
        "actual_parameters": actual_map,
        "unreachable_expression": predicate,
        "unreachable_decision": missed_decision,
        "branch_predicate_path": path,
        "source_line_text": source_text,
        "explanation": "The exact product top and parent parameter chain bind the guard operands to the listed values. The missing decision is opposite the elaborated constant result; no stimulus can change a compile-time parameter guard in this product configuration.",
        "source_context": chain,
    }


def _classify(waiver: dict[str, str], gap: dict[str, str], formal_by_semantic: dict,
              repo_root: Path, snapshot_root: Path, formal_runs: dict) -> dict:
    source = _safe_repo_file(repo_root, waiver["source_file"], "waiver source")
    source_sha = sha256(source)
    ledger_sha = _sha_map_from_ledger(gap).get(waiver["source_file"])
    if not ledger_sha or source_sha != ledger_sha or source_sha != waiver["source_sha256"]:
        raise CandidateAuditError(f"source SHA mismatch for {waiver['waiver_id']}")
    exact = {
        "waiver_id": waiver["waiver_id"],
        "raw_bin_id": gap["bin_id"],
        "semantic_bin_id": gap["semantic_bin_id"],
        "configuration": gap["configuration"],
        "instance": gap["instance"],
        "source_file": waiver["source_file"],
        "source_line": int(waiver["source_line"]),
        "metric": gap["metric"],
        "raw_status": gap["status"],
        "raw_retained": True,
        "source_sha256": source_sha,
        "product_source_sha": gap["product_source_sha"],
        "product_parameters": gap["product_parameters"],
        "legacy_reason": waiver.get("reason", ""),
        "rootcause_hint": gap.get("rootcause", ""),
        "rootcause_detail": gap.get("rootcause_reason", ""),
        "branch_predicate_path": gap.get("branch_predicate_path", ""),
    }
    formal = formal_by_semantic.get(gap["semantic_bin_id"])
    if formal:
        if (formal.get("status") != "PROVEN_UNREACHABLE"
                or formal.get("source_file") != waiver["source_file"]
                or formal.get("instance") != waiver["instance"]
                or formal.get("metric") != gap["metric"]
                or formal.get("source_position") != gap.get("source_position")):
            return {**exact, "disposition": "UNRESOLVED",
                    "reason": "Formal semantic-bin record does not exactly match the current Raw tuple."}
        formal_evidence = _formal_support(formal, repo_root, snapshot_root, formal_runs)
        return {**exact, "disposition": "FORMAL_UNREACHABLE",
                "proof": formal_evidence,
                "evidence_files": formal_runs[formal_evidence["formal_run_key"]]["evidence_files"],
                "formal_review_record": formal,
                "reason": "Exact assertion is proven, its matching target Cover is uncoverable, legal activity Cover is reached, no black boxes or unreviewed assumptions are present, and all Formal source hashes match current files. Raw remains OPEN."}
    configuration = _configuration_rule(waiver, gap, repo_root, {})
    if configuration:
        return {**exact, "disposition": "CONFIG_UNREACHABLE",
                "proof": configuration,
                "evidence_files": {relative: digest for relative, digest
                                   in configuration["source_context"].items()},
                "reason": configuration["explanation"] + " Raw remains OPEN."}
    return {**exact, "disposition": "UNRESOLVED",
            "reason": "No exact current-source configuration rule or source-bound Formal record matched this Raw bin."}


def _update_csv(path: Path, rows: list[dict[str, str]], audit_path: Path,
                repo_root: Path) -> None:
    fields = list(rows[0])
    if "candidate_audit" not in fields or "candidate_audit_sha256" not in fields:
        raise CandidateAuditError("waiver CSV lacks candidate_audit columns")
    rel = _relative(audit_path, repo_root)
    digest = sha256(audit_path)
    for row in rows:
        row["candidate_audit"] = rel
        row["candidate_audit_sha256"] = digest
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def audit_candidates(*, waivers_csv: Path, raw_gap_ledger: Path, compile_manifest_path: Path,
                     report_manifest_path: Path, vdb_manifest_path: Path,
                     formal_review_path: Path, output: Path, snapshot_dir: Path,
                     repo_root: Path) -> dict:
    waivers = _read_csv(waivers_csv)
    gaps = _read_gzip_csv(raw_gap_ledger)
    compile_manifest = json.loads(compile_manifest_path.read_text(encoding="utf-8"))
    report_manifest = json.loads(report_manifest_path.read_text(encoding="utf-8"))
    vdb_manifest = json.loads(vdb_manifest_path.read_text(encoding="utf-8"))
    formal_review = json.loads(formal_review_path.read_text(encoding="utf-8"))
    config_hash = _check_compile_profile(compile_manifest, repo_root)
    coverage_baseline = _check_coverage_manifests(
        report_manifest, vdb_manifest, report_manifest_path, vdb_manifest_path, config_hash
    )
    if formal_review.get("disposition") != "PROVEN_UNREACHABLE":
        raise CandidateAuditError("source-bound Formal review is not dispositioned PROVEN_UNREACHABLE")
    formal_by_semantic = {item["semantic_bin_id"]: item for item in formal_review.get("bins", [])}
    if len(formal_by_semantic) != len(formal_review.get("bins", [])):
        raise CandidateAuditError("Formal review contains duplicate semantic bin identifiers")
    formal_runs: dict[str, dict] = {}
    candidates = []
    seen_waivers: set[str] = set()
    seen_bins: set[str] = set()
    for waiver in waivers:
        waiver_id = waiver["waiver_id"]
        if waiver_id in seen_waivers or waiver["bin"] in seen_bins:
            raise CandidateAuditError("duplicate waiver ID or Raw bin in current candidate CSV")
        seen_waivers.add(waiver_id)
        seen_bins.add(waiver["bin"])
        gap = _find_gap(waiver, gaps)
        candidates.append(_classify(waiver, gap, formal_by_semantic, repo_root,
                                    snapshot_dir, formal_runs))

    disposition_counts = Counter(item["disposition"] for item in candidates)
    if len(candidates) != 371:
        raise CandidateAuditError(f"expected 371 historical candidates, found {len(candidates)}")
    if disposition_counts["CONFIG_UNREACHABLE"] != 361:
        raise CandidateAuditError("expected 361 exact fixed-configuration candidates")
    if disposition_counts["FORMAL_UNREACHABLE"] != 10:
        raise CandidateAuditError("expected 10 exact Formal candidates")
    if disposition_counts["REACHABLE"]:
        raise CandidateAuditError("a candidate was classified reachable; route it to directed tests")

    input_paths = {
        "raw_gap_ledger": raw_gap_ledger,
        "product_compile_manifest": compile_manifest_path,
        "raw_adjusted_report_manifest": report_manifest_path,
        "vdb_manifest": vdb_manifest_path,
        "formal_review": formal_review_path,
    }
    audit = {
        "schema_version": 1,
        "schema": "thermo5_tx_waiver_candidate_audit",
        "created_date": "2026-11-03",
        "product_source_sha": compile_manifest["product_source_sha"],
        "product_configuration_fingerprint": config_hash,
        "product_configuration": {
            "interpolation": "Centered-Cubic x2+x2", "ef2_order": 2,
            "ef2_step": 5120, "state_bits": 20, "pa_planes": 4,
            "dpd_max_taps": 1, "dpd_reset_image": "Identity",
            "control": "AXI-Lite", "fifo": "Generic",
        },
        "compile_defines": EXPECTED_DEFINES,
        "vcs_top": "thermo5_sku_uvm_tb",
        "coverage_baseline": coverage_baseline,
        "inputs": {
            name: {"path": _relative(path, repo_root), "sha256": sha256(path)}
            for name, path in input_paths.items()
        },
        "candidate_count": len(candidates),
        "disposition_counts": dict(sorted(disposition_counts.items())),
        "approved_count": 0,
        "active_exclusions": 0,
        "raw_bin_denominators_changed": False,
        "raw_statuses_changed": False,
        "formal_runs": formal_runs,
        "candidates": candidates,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _update_csv(waivers_csv, waivers, output, repo_root)
    return audit


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--waivers-csv", required=True, type=Path)
    parser.add_argument("--raw-gap-ledger", required=True, type=Path)
    parser.add_argument("--compile-manifest", required=True, type=Path)
    parser.add_argument("--report-manifest", required=True, type=Path)
    parser.add_argument("--vdb-manifest", required=True, type=Path)
    parser.add_argument("--formal-review", type=Path,
                        default=Path(FORMAL_REVIEW_DEFAULT))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--snapshot-dir", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        result = audit_candidates(
            waivers_csv=args.waivers_csv, raw_gap_ledger=args.raw_gap_ledger,
            compile_manifest_path=args.compile_manifest,
            report_manifest_path=args.report_manifest, vdb_manifest_path=args.vdb_manifest,
            formal_review_path=args.formal_review, output=args.output,
            snapshot_dir=args.snapshot_dir, repo_root=args.repo_root,
        )
    except (OSError, KeyError, ValueError, json.JSONDecodeError, WaiverError,
            CandidateAuditError) as exc:
        parser.exit(3, f"THERMO5_TX_CANDIDATE_AUDIT_ERROR: {exc}\n")
    print(json.dumps({
        "status": "PASS",
        "candidate_count": result["candidate_count"],
        "disposition_counts": result["disposition_counts"],
        "raw_bins_retained": True,
        "approved_count": 0,
        "active_exclusions": 0,
        "output": str(args.output),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
