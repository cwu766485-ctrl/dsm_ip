#!/usr/bin/env python3.12
"""Apply exact, source-bound VC Formal reachability dispositions to TX bins.

This utility changes only the audit ledger's review status. It never edits URG
data, the raw denominator, or an exclusion file.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]

FIXED_PARAMETER_BRANCH_SPECS = {
    "TXB-91d5b4a40917c980da7a": (
        "rtl/frontend/dsm_frame_gain_vector.sv",
        "rtl/frontend/dsm_frame_gain_vector.sv:97",
        "if (!HOLD_STATE_ON_DISABLE) begin",
        "0/1/0/-/-/-/-/-/-/-/-",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain",
    ),
    "TXB-6dcbab82b9fdc86cecc5": (
        "rtl/gt/gt_tx_user_bridge.sv", "rtl/gt/gt_tx_user_bridge.sv:20",
        "if (PARALLEL_W != GT_USER_W)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid.u_raw_boundary.u_bridge",
    ),
    "TXB-2df3affe59cb2ae409d4": (
        "rtl/gt/gt_tx_user_bridge.sv", "rtl/gt/gt_tx_user_bridge.sv:20",
        "if (PARALLEL_W != GT_USER_W)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid.u_raw_boundary.u_bridge",
    ),
    "TXB-2d576118dd5c1a6784cd": (
        "rtl/gt/gt_tx_user_bridge.sv", "rtl/gt/gt_tx_user_bridge.sv:20",
        "if (PARALLEL_W != GT_USER_W)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid.u_raw_boundary.u_bridge",
    ),
    "TXB-cd475fde35a66be60e79": (
        "rtl/gt/gt_tx_user_bridge.sv", "rtl/gt/gt_tx_user_bridge.sv:20",
        "if (PARALLEL_W != GT_USER_W)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid.u_raw_boundary.u_bridge",
    ),
    "TXB-054d97a87a8d74c36c8b": (
        "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
        "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:348",
        "if (MAX_TAPS < 1 || MAX_TAPS > 4)", "1",
        "thermo5_sku_uvm_tb.dut.u_cfg",
    ),
    "TXB-32b923f55e34401249a8": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210",
        "if (!HOLD_STATE_ON_DISABLE) begin", "0/1/0/-/-/-/-/-/-/-/-/-/-",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2",
    ),
    "TXB-e381d5af8a96457cab44": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294",
        'if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2");', "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2",
    ),
    "TXB-063113e1e4634f39c014": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295",
        'if (COEFF_FRAC != 14) $error("centered cubic coefficients require Q14");', "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2",
    ),
    "TXB-e8358208ee175c15bb7d": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210",
        "if (!HOLD_STATE_ON_DISABLE) begin", "0/1/0/-/-/-/-/-/-/-/-/-/-",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1",
    ),
    "TXB-e27080825871240f6ec3": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294",
        'if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2");', "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1",
    ),
    "TXB-0fe97016b03e97cafb72": (
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295",
        'if (COEFF_FRAC != 14) $error("centered cubic coefficients require Q14");', "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1",
    ),
    "TXB-84be21fab6f11958312f": (
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96",
        "if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid",
    ),
    "TXB-fa074bca34512589b54d": (
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96",
        "if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid",
    ),
    "TXB-9fd36ae54068498e255f": (
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96",
        "if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid",
    ),
    "TXB-70fb16ddca930f3fdb87": (
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:96",
        "if (W < 2 || CHANNELS < 2 || (CHANNELS % 2) != 0)", "1",
        "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[*].g_order2.u_tid",
    ),
    "TXB-32e3753ea6b78b647658": (
        "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:274",
        "if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)", "1",
        "thermo5_sku_uvm_tb.dut",
    ),
}

FIXED_PARAMETER_SOURCE_FILES = {
    "dv/uvm/tb/thermo5_sku_uvm_tb.sv",
    "rtl/frontend/dsm_frame_gain_vector.sv",
    "rtl/gt/gt_tx_raw64_boundary.sv",
    "rtl/gt/gt_tx_user_bridge.sv",
    "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
    "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
    "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv",
}


def validate_fixed_parameter_source_chain(source_texts: dict[str, str]) -> None:
    """Check the frozen AXI-Lite product's exact constant parameter chain."""
    def parameter_body(text: str, module: str, instance: str) -> str:
        declarations = list(re.finditer(rf"\b{re.escape(module)}\s*#\s*\(", text))
        if not declarations:
            fail(f"missing parameterized instance {module} {instance}")
        for declaration in declarations:
            open_paren = text.find("(", declaration.start())
            depth = 0
            for index in range(open_paren, len(text)):
                if text[index] == "(":
                    depth += 1
                elif text[index] == ")":
                    depth -= 1
                    if depth == 0:
                        tail = text[index + 1:index + 1 + len(instance) + 8]
                        if re.match(rf"\s*{re.escape(instance)}\b", tail):
                            return text[open_paren + 1:index]
                        break
        fail(f"could not parse parameter list for {module} {instance}")

    required = {
        "dv/uvm/tb/thermo5_sku_uvm_tb.sv",
        "rtl/frontend/dsm_frame_gain_vector.sv",
        "rtl/gt/gt_tx_raw64_boundary.sv",
        "rtl/gt/gt_tx_user_bridge.sv",
        "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
        "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
        "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
        "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv",
    }
    if set(source_texts) != required:
        fail("fixed-parameter review does not contain the exact ten-source chain")
    top = source_texts["dv/uvm/tb/thermo5_sku_uvm_tb.sv"]
    frame_gain = source_texts["rtl/frontend/dsm_frame_gain_vector.sv"]
    boundary = source_texts["rtl/gt/gt_tx_raw64_boundary.sv"]
    bridge = source_texts["rtl/gt/gt_tx_user_bridge.sv"]
    interp = source_texts["rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"]
    cfg = source_texts["rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv"]
    ef2 = source_texts["rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"]
    axil = source_texts["rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"]
    frontend = source_texts["rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv"]
    multipa = source_texts["rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"]

    checks = (
        (top, r"`ifdef\s+THERMO5_CENTERED_CUBIC\s+localparam\s+bit\s+USE_CENTERED_CUBIC\s*=\s*1'b1"),
        (top, r"`ifdef\s+THERMO5_TIDSM_ORDER\s+localparam\s+int\s+USE_TIDSM_ORDER\s*=\s*`THERMO5_TIDSM_ORDER"),
        (top, r"`ifdef\s+THERMO5_STEP\s+localparam\s+int\s+USE_STEP\s*=\s*`THERMO5_STEP"),
        (top, r"`ifdef\s+THERMO5_DPD_MAX_TAPS\s+localparam\s+int\s+USE_DPD_MAX_TAPS\s*=\s*`THERMO5_DPD_MAX_TAPS"),
        (top, r"`ifdef\s+THERMO5_AXIL_CONTROL(?:(?!`else).)*?\.INTERP_CENTERED_CUBIC\(USE_CENTERED_CUBIC\)(?:(?!`else).)*?\.DPD_MAX_TAPS\(USE_DPD_MAX_TAPS\)"),
        (axil, r"parameter\s+int\s+W\s*=\s*16\b"),
        (axil, r"thermo5_dpd_axi_lite_cfg\s*#\s*\(\s*\.MAX_TAPS\(DPD_MAX_TAPS\)\s*\)\s+u_cfg"),
        (axil, r"if\s*\(DPD_MAX_TAPS\s*<\s*1\s*\|\|\s*DPD_MAX_TAPS\s*>\s*4\)"),
        (cfg, r"if\s*\(MAX_TAPS\s*<\s*1\s*\|\|\s*MAX_TAPS\s*>\s*4\)"),
        (frontend, r"parameter\s+bit\s+HOLD_STATE_ON_DISABLE\s*=\s*1'b0"),
        (interp, r"parameter\s+int\s+COEFF_FRAC\s*=\s*14\b"),
        (interp, r"if\s*\(LANES\s*<\s*2\)\s*\$error\(\"centered cubic interpolator requires LANES >= 2\"\)"),
        (interp, r"if\s*\(COEFF_FRAC\s*!=\s*14\)\s*\$error\(\"centered cubic coefficients require Q14\"\)"),
        (frontend, r"tid32_thermo5_fs4_multipa_tx\s*#\s*\(\s*\.W\(W\),\s*\.CHANNELS\(2\*DPD_LANES\),\s*\.STEP\(STEP\),\s*\.TIDSM_ORDER\(TIDSM_ORDER\)\s*\)\s*u_tid"),
        (ef2, r"if\s*\(W\s*<\s*2\s*\|\|\s*CHANNELS\s*<\s*2\s*\|\|\s*\(CHANNELS\s*%\s*2\)\s*!=\s*0\)"),
        (ef2, r"gt_tx_raw64_boundary\s*#\s*\(\.DATA_W\(2\*CHANNELS\)\)\s+u_raw_boundary"),
        (boundary, r"gt_tx_user_bridge\s*#\s*\(\s*\.PARALLEL_W\(DATA_W\),\s*\.GT_USER_W\(DATA_W\)\s*\)\s+u_bridge"),
        (bridge, r"if\s*\(PARALLEL_W\s*!=\s*GT_USER_W\)"),
    )
    for text, pattern in checks:
        if not re.search(pattern, text, re.S):
            fail("fixed product parameter chain changed; missing reviewed source relation: " + pattern)

    axil_frontend_params = parameter_body(axil, "tid32_thermo5_frontend_tx", "u_frontend")
    for pattern in (
        r"\.W\(W\)", r"\.IN_LANES\(8\)", r"\.DPD_LANES\(16\)",
        r"\.STEP\(STEP\)", r"\.TIDSM_ORDER\(TIDSM_ORDER\)",
        r"\.MAX_TAPS\(DPD_MAX_TAPS\)",
        r"\.INTERP_CENTERED_CUBIC\(INTERP_CENTERED_CUBIC\)",
    ):
        if not re.search(pattern, axil_frontend_params):
            fail("AXI-Lite frontend parameter pass-through changed: " + pattern)
    frame_gain_params = parameter_body(frontend, "dsm_frame_gain_vector", "u_frame_gain")
    if not re.search(r"\.HOLD_STATE_ON_DISABLE\(HOLD_STATE_ON_DISABLE\)", frame_gain_params):
        fail("frame-gain HOLD_STATE_ON_DISABLE pass-through changed")
    centered_1 = parameter_body(frontend, "dsm_interp_x2_centered_cubic_vector", "u_interp_1")
    centered_2 = parameter_body(frontend, "dsm_interp_x2_centered_cubic_vector", "u_interp_2")
    for body, lanes, tail, label in (
        (centered_1, "IN_LANES", "1'b1", "stage 1"),
        (centered_2, "DPD_LANES", "1'b0", "stage 2"),
    ):
        for pattern in (
            rf"\.W\(W\)", rf"\.LANES\({lanes}\)",
            rf"\.APPEND_TAIL_VECTOR\({re.escape(tail)}\)",
            r"\.HOLD_STATE_ON_DISABLE\(HOLD_STATE_ON_DISABLE\)",
        ):
            if not re.search(pattern, body):
                fail(f"centered interpolator {label} parameter pass-through changed: {pattern}")
        if re.search(r"\.COEFF_FRAC\s*\(", body):
            fail(f"centered interpolator {label} overrides reviewed Q14 default")
    if "HOLD_STATE_ON_DISABLE" in axil:
        fail("AXI-Lite product unexpectedly exposes a HOLD_STATE_ON_DISABLE override")
    order2_branch = re.search(
        r"(?:end\s+)?else\s+if\s*\(TIDSM_ORDER\s*==\s*2\)\s*begin\s*:\s*g_order2",
        multipa,
    )
    ef2_instance = re.search(r"\btid32_cartesian_ef2_fs4_gt_tx\s*#", multipa)
    if order2_branch is None or ef2_instance is None or ef2_instance.start() < order2_branch.end():
        fail("four-plane parent no longer instantiates EF2 under the ORDER=2 generate arm")
    ef2_params = parameter_body(multipa, "tid32_cartesian_ef2_fs4_gt_tx", "u_tid")
    if not re.search(r"\.W\(W\)", ef2_params) or not re.search(
        r"\.CHANNELS\(CHANNELS\)", ef2_params
    ):
        fail("EF2 product W/CHANNELS parameter pass-through changed")


def verify_fixed_parameter_dispositions(
    review: dict, ledger_rows: list[dict[str, str]], product_source_sha: str
) -> list[dict]:
    """Validate exact Raw Branch IDs and source-bound fixed product parameters."""
    dispositions = review.get("fixed_parameter_dispositions", [])
    if not isinstance(dispositions, list):
        fail("fixed_parameter_dispositions must be an array")
    if not dispositions:
        return []
    if len(dispositions) != 1:
        fail("this closure increment requires one grouped fixed-parameter review")
    item = dispositions[0]
    if item.get("method") != "EXACT_PRODUCT_STATIC_PARAMETER_CHAIN":
        fail("unsupported fixed-parameter disposition method")
    if item.get("review_id") != "THERMO5_FIXED_PRODUCT_PARAMETER_GUARDS":
        fail("fixed-parameter review ID mismatch")
    if item.get("status") != "PROVEN_UNREACHABLE":
        fail("fixed-parameter disposition must be PROVEN_UNREACHABLE")
    if item.get("product_source_sha") != product_source_sha:
        fail("fixed-parameter disposition and Raw ledger product SHAs differ")

    compile_manifest_path = ROOT / item["product_compile_manifest"]
    if not compile_manifest_path.is_file() or sha256(compile_manifest_path) != item.get(
        "product_compile_manifest_sha256"
    ):
        fail("missing or stale exact-product compile manifest for fixed-parameter audit")
    compile_manifest = json.loads(compile_manifest_path.read_text(encoding="utf-8"))
    provenance = compile_manifest.get("compile_provenance", {})
    expected_defines = {
        "+define+THERMO5_AXIL_CONTROL",
        "+define+THERMO5_CENTERED_CUBIC",
        "+define+THERMO5_TIDSM_ORDER=2",
        "+define+THERMO5_STEP=5120",
        "+define+THERMO5_DPD_MAX_TAPS=1",
    }
    if not expected_defines.issubset(set(provenance.get("configuration_defines", []))):
        fail("product compile manifest does not bind the frozen AXI-Lite/centered/EF2/1-tap product")
    if provenance.get("top") != "thermo5_sku_uvm_tb":
        fail("product compile manifest has the wrong fixed-product top")
    if compile_manifest.get("base_commit") != product_source_sha:
        fail("product compile manifest is not bound to the Raw product source SHA")
    if len(compile_manifest.get("source_file_sha256", {})) != 77:
        fail("product compile manifest does not contain the reviewed 77 source/control entries")

    witness_path = ROOT / item["active_product_witness"]
    if not witness_path.is_file() or sha256(witness_path) != item.get(
        "active_product_witness_sha256"
    ):
        fail("missing or stale exact-product positive VCS witness")
    witness = json.loads(witness_path.read_text(encoding="utf-8"))
    if (witness.get("product_source_sha") != product_source_sha
            or witness.get("git_head_at_compile") != product_source_sha
            or witness.get("positive_tests", {}).get("all_pass") is not True
            or witness.get("positive_tests", {}).get("count") != 13):
        fail("active witness is not the exact 13-test product-source PASS")
    command = witness.get("compile", {}).get("command", "")
    for token in (
        "-top thermo5_sku_uvm_tb",
        "+define+THERMO5_AXIL_CONTROL",
        "+define+THERMO5_CENTERED_CUBIC",
        "+define+THERMO5_TIDSM_ORDER=2",
        "+define+THERMO5_STEP=5120",
        "+define+THERMO5_DPD_MAX_TAPS=1",
    ):
        if token not in command:
            fail("active product witness compile command lacks " + token)

    source_hashes = item.get("source_sha256")
    if not isinstance(source_hashes, dict) or set(source_hashes) != FIXED_PARAMETER_SOURCE_FILES:
        fail("fixed-parameter review must hash the exact ten-file elaboration chain")
    compile_hashes = compile_manifest.get("source_file_sha256", {})
    witness_hashes = witness.get("compile", {}).get("parsed_project_source_sha256", {})
    source_texts = {}
    for relative, expected in source_hashes.items():
        path = (ROOT / relative).resolve()
        if not path.is_relative_to(ROOT.resolve()) or not path.is_file() or sha256(path) != expected:
            fail("fixed product source changed since review: " + relative)
        if compile_hashes.get(relative) != expected or witness_hashes.get(relative) != expected:
            fail("compile or positive witness does not bind fixed product source: " + relative)
        source_texts[relative] = path.read_text(encoding="utf-8")
    validate_fixed_parameter_source_chain(source_texts)

    ledger_by_id = {row["semantic_bin_id"]: row for row in ledger_rows}
    if len(ledger_by_id) != len(ledger_rows):
        fail("semantic Bin IDs are not unique in the fixed-parameter Raw ledger")
    reviewed_ids = item.get("semantic_bin_ids", [])
    if set(reviewed_ids) != set(FIXED_PARAMETER_BRANCH_SPECS) or len(reviewed_ids) != len(FIXED_PARAMETER_BRANCH_SPECS):
        fail("fixed-parameter Bin ID set differs from the exact 17 reviewed Raw bins")
    for bin_id, (source, position, expression, decision_path, instance) in FIXED_PARAMETER_BRANCH_SPECS.items():
        row = ledger_by_id.get(bin_id)
        if row is None:
            fail("fixed-parameter semantic Bin is absent from Raw ledger: " + bin_id)
        expected = {
            "configuration": "axil",
            "metric": "branch",
            "source_files": source,
            "source_position": position,
            "branch_target_line": position.rsplit(":", 1)[1],
            "branch_target_position": position,
            "branch_target_expression": expression,
            "branch_decision_path": decision_path,
            "normalized_instance": instance,
            "product_source_sha": product_source_sha,
        }
        for key, value in expected.items():
            if row.get(key) != value:
                fail(f"{bin_id}: Raw {key} mismatch (expected {value!r}, got {row.get(key)!r})")
        if row.get("closure_status") not in {"OPEN", "PROVEN_UNREACHABLE"}:
            fail(f"{bin_id}: refusing to overwrite an unexpected Raw closure status")
        source_line_number = int(position.rsplit(":", 1)[1])
        source_line = source_texts[source].splitlines()[source_line_number - 1].strip()
        if source_line != expression:
            fail(f"{bin_id}: exact source line no longer matches the audited Branch expression")
        try:
            row_source_hashes = dict(
                part.split("=", 1) for part in row["source_file_sha256"].split(";") if "=" in part
            )
        except ValueError as error:
            raise ValueError(f"{bin_id}: malformed Raw source hash field") from error
        if row_source_hashes.get(source) != source_hashes.get(source):
            fail(f"{bin_id}: Source SHA differs from its exact Raw URG record")
    item["validated_bin_count"] = len(reviewed_ids)
    item["source_chain_sha256"] = {key: sha256(ROOT / key) for key in source_hashes}
    item["compile_manifest_sha256"] = sha256(compile_manifest_path)
    item["active_product_witness_sha256"] = sha256(witness_path)
    return dispositions


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise ValueError(message)


def tautological_property_names(console: str) -> set[str]:
    names: set[str] = set()
    for warning in re.finditer(r"Warning-\[SVAC-TAUT-(?:PROPERTY|COVER)\]", console):
        heading = console[warning.start():].splitlines()[:5]
        names.update(re.findall(r',\s*"([^"]+)"', "\n".join(heading)))
    return names


def validate_refresh_evidence(path: Path, summary: dict, rootcause_manifest: dict) -> dict:
    """Validate a VCS/URG refresh record against the audited Raw inputs."""
    evidence = json.loads(path.read_text(encoding="utf-8"))
    if evidence.get("product_source_sha") != summary.get("source_product_sha"):
        fail("VCS refresh record and root-cause summary product SHAs differ")
    coverage = evidence.get("coverage", {})
    if coverage.get("urg_refresh_status") != "PASS":
        fail("refresh record does not report a passing URG refresh")
    raw_summary_path = ROOT / coverage.get("raw_summary", "")
    gate_path = ROOT / coverage.get("coverage_gate", "")
    if not raw_summary_path.is_file() or not gate_path.is_file():
        fail("refresh record is missing its Raw summary or coverage-gate evidence")
    if sha256(raw_summary_path) != coverage.get("raw_summary_sha256"):
        fail("Raw summary SHA differs from the refresh record")
    if sha256(gate_path) != coverage.get("coverage_gate_sha256"):
        fail("coverage-gate SHA differs from the refresh record")
    gate = json.loads(gate_path.read_text(encoding="utf-8"))
    report_hashes = rootcause_manifest.get("input_sha256", {}).get("raw_groups_html", {})
    report_path = coverage.get("groups_html", "")
    if report_hashes.get(report_path) != coverage.get("groups_html_sha256"):
        fail("URG Group Report SHA is not one of the root-cause audit inputs")
    gate_inputs = gate.get("inputs", {})
    if gate_inputs.get("groups_html") != report_path:
        fail("coverage gate did not audit the same URG Group Report")
    if gate_inputs.get("raw_summary") != coverage.get("raw_summary"):
        fail("coverage gate did not audit the recorded Raw summary")
    if gate.get("status") != "RAW_100_OPEN" or gate.get("exclusions_applied"):
        fail("refresh coverage gate is not fail-closed Raw_100_OPEN with no exclusions")
    if gate.get("raw_project_rtl") != gate.get("adjusted_project_rtl"):
        fail("Raw and adjusted coverage differ in the refresh gate")
    return evidence


def read_csv(path: Path, compressed: bool = False) -> tuple[list[str], list[dict[str, str]]]:
    opener = gzip.open if compressed else open
    with opener(path, "rt", newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames:
            fail(f"missing CSV header: {path}")
        return list(reader.fieldnames), list(reader)


def write_gzip_csv(path: Path, fields: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("wb") as binary:
        with gzip.GzipFile(filename="", mode="wb", fileobj=binary, mtime=0) as compressed:
            import io

            text = io.TextIOWrapper(compressed, encoding="utf-8", newline="")
            writer = csv.DictWriter(text, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            text.flush()
            text.detach()


def exact_pairlookahead_bin_ids(
    ledger_rows: list[dict[str, str]], source_file: str,
    helper_start: int = 117, helper_end: int = 191, guard_line: int = 231,
) -> set[str]:
    """Return all Raw bins in the EF2 pair helper and its selecting Branch."""
    result: set[str] = set()
    for row in ledger_rows:
        if row.get("source_files") != source_file:
            continue
        match = re.search(r":(\d+)(?::|$)", row.get("source_position", ""))
        line = int(match.group(1)) if match else None
        helper_bin = line is not None and helper_start <= line <= helper_end
        guard_bin = (
            row.get("metric") == "branch"
            and line == guard_line
            and row.get("branch_target_expression") == "if (PAIR_LOOKAHEAD) begin"
        )
        if helper_bin or guard_bin:
            result.add(row["semantic_bin_id"])
    return result


def validate_pairlookahead_source_chain(ef2: str, multipa: str, boundary: str, bridge: str) -> None:
    """Fail closed if the exact source-level configuration chain has changed."""
    if not re.search(r"parameter\s+bit\s+PAIR_LOOKAHEAD\s*=\s*1'b0", ef2):
        fail("EF2 PAIR_LOOKAHEAD default is not the reviewed disabled value")
    if ef2.count("ef2_pair_lookahead(") != 3:
        fail("EF2 pair helper gained an unreviewed declaration or call site")
    guarded_calls = re.search(
        r"if\s*\(PAIR_LOOKAHEAD\)\s*begin(?:(?!\bend\s*else\s*begin).)*"
        r"ef2_pair_lookahead\((?:(?!\bend\s*else\s*begin).)*"
        r"ef2_pair_lookahead\((?:(?!\bend\s*else\s*begin).)*"
        r"end\s*else\s*begin",
        ef2,
        re.S,
    )
    if not guarded_calls:
        fail("pair helper calls are no longer confined to the PAIR_LOOKAHEAD arm")
    if multipa.count("tid32_cartesian_ef2_fs4_gt_tx") != 1 or not re.search(
        r"for\s*\(\s*b\s*=\s*0;\s*b\s*<\s*4;\s*b\s*=\s*b\s*\+\s*1\)\s*begin\s*:\s*g_branch"
        r"(?:(?!\bendgenerate).)*?else\s+if\s*\(TIDSM_ORDER\s*==\s*2\)\s*begin\s*:\s*g_order2"
        r"(?:(?!\bend\s*else\s+begin).)*"
        r"tid32_cartesian_ef2_fs4_gt_tx\s*#\s*\(\.W\(W\),\s*\.CHANNELS\(CHANNELS\)\)\s+u_tid",
        multipa,
        re.S,
    ):
        fail("four-plane parent overrides or obscures the reviewed EF2 defaults")
    if not re.search(
        r"gt_tx_user_bridge\s*#\s*\(\s*\.PARALLEL_W\(DATA_W\),\s*\.GT_USER_W\(DATA_W\)\s*\)",
        boundary,
    ):
        fail("raw GT boundary no longer ties bridge widths to the same parameter")
    if not re.search(r"if\s*\(PARALLEL_W\s*!=\s*GT_USER_W\)", bridge):
        fail("GT bridge width guard source has changed")


def verify_review(review: dict) -> list[dict]:
    if review.get("disposition") != "PROVEN_UNREACHABLE":
        fail("only explicit PROVEN_UNREACHABLE dispositions are accepted")
    dispositions = review.get("bins")
    if not isinstance(dispositions, list) or not dispositions:
        fail("review must contain a non-empty bins array")
    seen: set[str] = set()
    for item in dispositions:
        bin_id = item.get("semantic_bin_id", "")
        if not bin_id or bin_id in seen:
            fail(f"missing or duplicate semantic_bin_id: {bin_id}")
        seen.add(bin_id)
        proof_dir = (ROOT / item["formal_run"]).resolve()
        if not proof_dir.is_relative_to(ROOT.resolve()):
            fail(f"formal run escapes repository: {proof_dir}")
        properties_path = proof_dir / item.get("properties_file", "properties.txt")
        setup_path = proof_dir / item.get("setup_file", "setup.txt")
        console_path = proof_dir / item.get("console_file", "console.log")
        for path, key in ((properties_path, "properties_sha256"),
                          (setup_path, "setup_sha256"),
                          (console_path, "console_sha256")):
            if not path.is_file() or sha256(path) != item.get(key):
                fail(f"missing or stale formal evidence: {path}")
        properties = properties_path.read_text(encoding="utf-8", errors="replace")
        escaped_assert = re.escape(item["assertion"])
        escaped_cover = re.escape(item["cover"])
        if not re.search(r"\bproven\b.*" + escaped_assert + r"\s*$", properties, re.M):
            fail(f"assertion is not proven: {item['assertion']}")
        if not re.search(r"\buncoverable\b.*" + escaped_cover + r"\s*$", properties, re.M):
            fail(f"cover is not formally uncoverable: {item['cover']}")
        setup = setup_path.read_text(encoding="utf-8", errors="replace")
        if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
            fail(f"Formal setup violations are present: {setup_path}")
        console = console_path.read_text(encoding="utf-8", errors="replace")
        if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
            fail(f"zero-black-box evidence is absent: {console_path}")
        tautology_report = proof_dir / "vcst_rtdb/logs/tautologySVAGoals.rpt"
        if tautology_report.is_file():
            tautologies = tautology_report.read_text(encoding="utf-8", errors="replace")
            if item["assertion"] in tautologies or item["cover"] in tautologies:
                fail(f"{bin_id}: an exact Formal property is tautological")
        tautological_names = tautological_property_names(console)
        exact_names = {item["assertion"].rsplit(".", 1)[-1], item["cover"].rsplit(".", 1)[-1]}
        if exact_names & tautological_names:
            fail(f"{bin_id}: an exact Formal property is marked tautological in the console")
        assumptions = item.get("assumptions", [])
        observed_assumptions = re.findall(r"^\s*\[\s*\d+\]\s+constrained\s+\(non_vacuous\).*?-\s+(\S*\.asm_\S+)\s*$", properties, re.M)
        if set(observed_assumptions) != set(assumptions):
            fail(f"{bin_id}: formal assumptions are missing, vacuous, or not reviewed")
        source_hashes = item.get("source_sha256")
        if not isinstance(source_hashes, dict) or not source_hashes:
            fail(f"missing source hashes for {bin_id}")
        for relative, expected in source_hashes.items():
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(ROOT.resolve()) or not path.is_file():
                fail(f"formal source path missing or escapes repository: {relative}")
            if sha256(path) != expected:
                fail(f"formal source changed since proof: {relative}")
        item["status"] = "PROVEN_UNREACHABLE"
        item["evidence_sha256"] = {
            "properties": sha256(properties_path),
            "setup": sha256(setup_path),
            "console": sha256(console_path),
        }
    return dispositions


def verify_elaboration_dispositions(
    review: dict, ledger_rows: list[dict[str, str]], product_source_sha: str
) -> list[dict]:
    """Validate source-bound dispositions caused by exact static parameters.

    This path is intentionally narrower than Formal: it accepts only the EF2
    pair-look-ahead helper, whose sole call sites are dominated by a constant
    product parameter. It requires the exact current-source VCS compile,
    positive product replay, compile parameter defines, wrapper chain, and an
    exact semantic-bin set. It does not create an URG exclusion or alter Raw.
    """
    dispositions = review.get("elaboration_dispositions", [])
    if not isinstance(dispositions, list):
        fail("elaboration_dispositions must be an array")
    if not dispositions:
        return []

    by_id = {row["semantic_bin_id"]: row for row in ledger_rows}
    if len(by_id) != len(ledger_rows):
        fail("semantic Bin IDs are not unique in the ledger")

    for item in dispositions:
        if item.get("method") != "EXACT_PRODUCT_STATIC_PARAMETER_CHAIN":
            fail("unsupported elaboration disposition method")
        if item.get("product_source_sha") != product_source_sha:
            fail("elaboration disposition and Raw ledger product SHAs differ")
        if item.get("status") != "PROVEN_UNREACHABLE":
            fail("elaboration disposition must explicitly be PROVEN_UNREACHABLE")

        compile_manifest_path = ROOT / item["product_compile_manifest"]
        if not compile_manifest_path.is_file() or sha256(compile_manifest_path) != item.get(
            "product_compile_manifest_sha256"
        ):
            fail("missing or stale exact-product compile manifest")
        compile_manifest = json.loads(compile_manifest_path.read_text(encoding="utf-8"))
        compile_provenance = compile_manifest.get("compile_provenance", {})
        defines = compile_provenance.get("configuration_defines", [])
        expected_defines = {
            "+define+THERMO5_AXIL_CONTROL",
            "+define+THERMO5_CENTERED_CUBIC",
            "+define+THERMO5_TIDSM_ORDER=2",
            "+define+THERMO5_STEP=5120",
            "+define+THERMO5_DPD_MAX_TAPS=1",
        }
        if not expected_defines.issubset(set(defines)):
            fail("product compile manifest does not bind the frozen TX configuration")
        if compile_provenance.get("top") != "thermo5_sku_uvm_tb":
            fail("product compile manifest has the wrong elaborated top")
        if compile_manifest.get("base_commit") != product_source_sha:
            fail("product compile manifest is not bound to the current product source SHA")
        if len(compile_manifest.get("source_file_sha256", {})) != 77:
            fail("product compile manifest does not contain the reviewed 77 source/control entries")

        active_witness_path = ROOT / item["active_product_witness"]
        if not active_witness_path.is_file() or sha256(active_witness_path) != item.get(
            "active_product_witness_sha256"
        ):
            fail("missing or stale active-product VCS witness")
        witness = json.loads(active_witness_path.read_text(encoding="utf-8"))
        if (witness.get("product_source_sha") != product_source_sha
                or witness.get("git_head_at_compile") != product_source_sha
                or witness.get("positive_tests", {}).get("all_pass") is not True
                or witness.get("positive_tests", {}).get("count") != 13):
            fail("active-product witness is not the exact 13-test current-source PASS")
        if witness.get("compile", {}).get("command", "").find("THERMO5_TIDSM_ORDER=2") < 0:
            fail("active-product VCS witness does not compile EF2 ORDER=2")
        compile_command = witness.get("compile", {}).get("command", "")
        for token in (
            "-top thermo5_sku_uvm_tb",
            "+define+THERMO5_AXIL_CONTROL",
            "+define+THERMO5_CENTERED_CUBIC",
            "+define+THERMO5_TIDSM_ORDER=2",
            "+define+THERMO5_STEP=5120",
            "+define+THERMO5_DPD_MAX_TAPS=1",
        ):
            if token not in compile_command:
                fail(f"active-product VCS command is missing exact product option: {token}")

        source_hashes = item.get("source_sha256")
        if not isinstance(source_hashes, dict) or not source_hashes:
            fail("elaboration disposition is missing source hashes")
        expected_chain_sources = {
            "dv/uvm/tb/thermo5_sku_uvm_tb.sv",
            "rtl/gt/gt_tx_raw64_boundary.sv",
            "rtl/gt/gt_tx_user_bridge.sv",
            "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
            "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
            "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
            "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv",
        }
        if set(source_hashes) != expected_chain_sources:
            fail("elaboration disposition source hashes do not cover the exact product parameter chain")
        compile_hashes = compile_manifest.get("source_file_sha256", {})
        witness_hashes = witness.get("compile", {}).get("parsed_project_source_sha256", {})
        for relative, expected in source_hashes.items():
            path = (ROOT / relative).resolve()
            if not path.is_relative_to(ROOT.resolve()) or not path.is_file() or sha256(path) != expected:
                fail(f"elaboration source changed since review: {relative}")
            if compile_hashes.get(relative) != expected or witness_hashes.get(relative) != expected:
                fail(f"compile or active witness does not bind elaboration source: {relative}")

        ef2 = (ROOT / "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv").read_text(
            encoding="utf-8"
        )
        multipa = (ROOT / "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv").read_text(
            encoding="utf-8"
        )
        frontend = (ROOT / "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv").read_text(
            encoding="utf-8"
        )
        axil_frontend = (
            ROOT / "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        ).read_text(encoding="utf-8")
        uvm_top = (ROOT / "dv/uvm/tb/thermo5_sku_uvm_tb.sv").read_text(encoding="utf-8")
        boundary = (ROOT / "rtl/gt/gt_tx_raw64_boundary.sv").read_text(encoding="utf-8")
        bridge = (ROOT / "rtl/gt/gt_tx_user_bridge.sv").read_text(encoding="utf-8")
        validate_pairlookahead_source_chain(ef2, multipa, boundary, bridge)
        if not re.search(r"\.TIDSM_ORDER\(USE_TIDSM_ORDER\)", uvm_top):
            fail("UVM product top does not bind the compiled TIDSM_ORDER define")
        if not re.search(
            r"`ifdef\s+THERMO5_AXIL_CONTROL(?:(?!`else).)*"
            r"tid32_thermo5_axi_lite_axis_frontend_tx\s*#\s*\((?:(?!\)\s*dut).)*"
            r"\.TIDSM_ORDER\(USE_TIDSM_ORDER\)",
            uvm_top,
            re.S,
        ):
            fail("compiled AXI-Lite product top does not pass the exact order parameter")
        if not re.search(r"\.TIDSM_ORDER\(TIDSM_ORDER\)", axil_frontend):
            fail("AXI-Lite product parent does not pass its exact TIDSM_ORDER")
        if not re.search(r"\.TIDSM_ORDER\(TIDSM_ORDER\)", frontend):
            fail("TX frontend does not pass its exact TIDSM_ORDER to the four-plane parent")

        helper_start, helper_end = item.get("source_line_range", [0, 0])
        if (helper_start, helper_end) != (117, 191):
            fail("unexpected pair helper source range; review the exact code boundary")
        helper_decl = re.search(
            r"^\s*function\s+automatic\s+ef2_pair_result_t\s+ef2_pair_lookahead\(",
            ef2,
            re.M,
        )
        if helper_decl is None or len(ef2[:helper_decl.start()].splitlines()) + 1 != helper_start:
            fail("pair helper declaration moved; exact source range must be reviewed")

        target_source = "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
        expected_ids = exact_pairlookahead_bin_ids(
            ledger_rows, target_source, helper_start, helper_end
        )
        reviewed_ids = set(item.get("semantic_bin_ids", []))
        if not reviewed_ids or reviewed_ids != expected_ids:
            fail(
                "elaboration Bin ID set does not exactly match the source-line-derived Raw bins "
                f"(reviewed={len(reviewed_ids)}, expected={len(expected_ids)})"
            )
        for bin_id in reviewed_ids:
            row = by_id.get(bin_id)
            if row is None:
                fail(f"elaboration Bin ID is absent from Raw ledger: {bin_id}")
            if row.get("configuration") != "axil" or row.get("product_source_sha") != product_source_sha:
                fail(f"{bin_id}: product configuration/source mismatch")
            row_sources = dict(
                part.split("=", 1) for part in row["source_file_sha256"].split(";") if "=" in part
            )
            if row_sources.get(target_source) != source_hashes.get(target_source):
                fail(f"{bin_id}: source hash differs from the Raw ledger")
            if row.get("normalized_instance", "").count("g_order2.u_tid") != 1:
                fail(f"{bin_id}: bin is not in the elaborated order-2 product instances")
        item["validated_bin_count"] = len(reviewed_ids)
        item["source_chain_sha256"] = {
            relative: sha256(ROOT / relative) for relative in source_hashes
        }
        item["compile_manifest_sha256"] = sha256(compile_manifest_path)
        item["active_product_witness_sha256"] = sha256(active_witness_path)
    return dispositions


def append_current_source_formal_section(
    closure: str, product_source_sha: str, formal_lines: list[str]
) -> str:
    """Replace only this product SHA's generated section; preserve history."""
    marker = f"## Current-source Formal disposition update — `{product_source_sha}`"
    if marker in closure:
        closure = closure[:closure.index(marker)].rstrip()
    return closure.rstrip() + "\n\n" + "\n".join([marker, "", *formal_lines]).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--tasks", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--closure-report", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument(
        "--refresh-evidence", type=Path,
        help="Optional machine-readable fresh VCS/URG record, checked against the exact Raw report and gate.",
    )
    args = parser.parse_args()
    ledger_fields, ledger_rows = read_csv(args.ledger, compressed=True)
    task_fields, tasks = read_csv(args.tasks)
    summary = json.loads(args.summary.read_text(encoding="utf-8"))
    review = json.loads(args.review.read_text(encoding="utf-8"))
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    if review.get("product_source_sha") != summary.get("source_product_sha"):
        fail("Formal review and source-ledger product SHAs differ")
    refresh_evidence = None
    if args.refresh_evidence:
        refresh_evidence = validate_refresh_evidence(args.refresh_evidence, summary, manifest)
    dispositions = verify_review(review)
    elaboration_dispositions = verify_elaboration_dispositions(
        review, ledger_rows, summary["source_product_sha"]
    )
    fixed_parameter_dispositions = verify_fixed_parameter_dispositions(
        review, ledger_rows, summary["source_product_sha"]
    )
    reviewed_open = review.get("reviewed_candidates", [])
    if not isinstance(reviewed_open, list):
        fail("reviewed_candidates must be an array")
    by_id = {row["semantic_bin_id"]: row for row in ledger_rows}
    if len(by_id) != len(ledger_rows):
        fail("semantic Bin IDs are not unique in the ledger")
    disposition_ids = {item["semantic_bin_id"] for item in dispositions}
    elaboration_ids = {
        bin_id for item in elaboration_dispositions for bin_id in item["semantic_bin_ids"]
    }
    fixed_parameter_ids = {
        bin_id for item in fixed_parameter_dispositions for bin_id in item["semantic_bin_ids"]
    }
    if disposition_ids & elaboration_ids or disposition_ids & fixed_parameter_ids or elaboration_ids & fixed_parameter_ids:
        fail("a semantic Bin ID cannot have conflicting Formal/static dispositions")
    disposition_ids |= elaboration_ids | fixed_parameter_ids
    for candidate in reviewed_open:
        bin_id = candidate.get("semantic_bin_id", "")
        if not bin_id or bin_id in disposition_ids:
            fail(f"missing or conflicting reviewed OPEN candidate Bin ID: {bin_id}")
        if candidate.get("status") != "OPEN" or not candidate.get("reason"):
            fail(f"{bin_id}: reviewed candidate must have OPEN status and an audit reason")
        row = by_id.get(bin_id)
        if row is None:
            fail(f"reviewed OPEN candidate is absent from raw ledger: {bin_id}")
        row["closure_status"] = "OPEN"
        row["status"] = "OPEN"
        row["reason"] = candidate["reason"]
        row["evidence_hint"] = "FORMAL_TAUTOLOGY_REJECTED; retain Raw bin"
        row["root_cause_hypothesis"] = candidate["reason"]
        row["next_action"] = "Keep this exact Raw bin OPEN until valid non-tautological evidence or a separately reviewed configuration disposition is supplied."
    for item in dispositions:
        bin_id = item["semantic_bin_id"]
        row = by_id.get(bin_id)
        if row is None:
            fail(f"Formal Bin ID is absent from raw ledger: {bin_id}")
        for field in ("configuration", "instance", "metric", "bin", "source_position"):
            if row.get(field) != item.get(field):
                fail(f"{bin_id}: exact {field} mismatch ({row.get(field)!r} != {item.get(field)!r})")
        source_file = item["source_file"]
        expected_sha = item["source_sha256"].get(source_file)
        if not expected_sha:
            fail(f"{bin_id}: Formal evidence does not hash the DUT source file")
        ledger_source_hashes = dict(
            part.split("=", 1) for part in row["source_file_sha256"].split(";") if "=" in part
        )
        if ledger_source_hashes.get(source_file) != expected_sha:
            fail(f"{bin_id}: source file SHA differs from the raw-ledger source")
        row["closure_status"] = "PROVEN_UNREACHABLE"
        row["status"] = "PROVEN_UNREACHABLE"
        row["reason"] = "Exact product-configuration Formal assertion proven and matching Cover reported uncoverable; Raw bin retained."
        row["evidence_hint"] = item["assertion"] + "; " + item["cover"]
        row["root_cause_hypothesis"] = "Formal proves this exact raw bin unreachable under the recorded product parameter ties."
        row["next_action"] = "Retain the bin in Raw; no exclusion is approved by this disposition."

    for item in elaboration_dispositions:
        for bin_id in item["semantic_bin_ids"]:
            row = by_id[bin_id]
            row["closure_status"] = "PROVEN_UNREACHABLE"
            row["status"] = "PROVEN_UNREACHABLE"
            row["reason"] = item["reason"]
            row["evidence_hint"] = (
                "EXACT_PRODUCT_STATIC_PARAMETER_CHAIN; "
                + item["product_compile_manifest"]
                + "; active 13-test product VCS witness"
            )
            row["root_cause_hypothesis"] = item["reason"]
            row["next_action"] = "Retain the bin in Raw; exact product parameter chain is reviewed; no exclusion is approved."

    for item in fixed_parameter_dispositions:
        for bin_id in item["semantic_bin_ids"]:
            row = by_id[bin_id]
            row["closure_status"] = "PROVEN_UNREACHABLE"
            row["status"] = "PROVEN_UNREACHABLE"
            row["reason"] = item["reason"]
            row["evidence_hint"] = (
                "EXACT_PRODUCT_STATIC_PARAMETER_CHAIN; "
                + item["product_compile_manifest"]
                + "; active 13-test product VCS witness; source hashes in review JSON"
            )
            row["root_cause_hypothesis"] = item["reason"]
            row["next_action"] = (
                "Retain the bin in Raw; reopen if the product parameters or source chain change; "
                "no exclusion is approved."
            )

    for task in tasks:
        ids = set(filter(None, task["semantic_bin_ids"].split(";")))
        closed = ids and all(by_id[bin_id]["closure_status"] == "PROVEN_UNREACHABLE" for bin_id in ids)
        task["current_status"] = "PROVEN_UNREACHABLE" if closed else "OPEN"
        if closed:
            task["status_note"] = "Exact source bin proven unreachable under product configuration; Raw denominator retained; no waiver."
            task["next_action"] = "Retain all bins in Raw; do not exclude or reduce the denominator. Reopen if product parameters or source change."
    if "current_status" not in task_fields:
        insert_at = task_fields.index("initial_status") + 1
        task_fields.insert(insert_at, "current_status")
    with args.tasks.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=task_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(tasks)
    write_gzip_csv(args.ledger, ledger_fields, ledger_rows)

    import collections

    counts = collections.Counter(row["closure_status"] for row in ledger_rows)
    summary["closure_status_counts"] = dict(sorted(counts.items()))
    summary["all_rows_have_allowed_status"] = all(
        row["closure_status"] in {"HIT", "PROVEN_UNREACHABLE", "WAIVER_CANDIDATE", "OPEN"}
        for row in ledger_rows
    )
    formal_map = summary.setdefault("formal_dispositions", {})
    for item in reviewed_open:
        formal_map.pop(item["semantic_bin_id"], None)
    for item in dispositions:
        formal_map[item["semantic_bin_id"]] = {
            "status": "PROVEN_UNREACHABLE",
            "formal_run": item["formal_run"],
            "assertion": item["assertion"],
            "cover": item["cover"],
            "source_sha256": item["source_sha256"],
            "evidence_sha256": item["evidence_sha256"],
            "assumptions": item.get("assumptions", []),
        }
    elaboration_map = summary.setdefault("elaboration_dispositions", {})
    for item in elaboration_dispositions:
        for bin_id in item["semantic_bin_ids"]:
            elaboration_map[bin_id] = {
                "status": "PROVEN_UNREACHABLE",
                "method": item["method"],
                "review_id": item.get("review_id"),
                "source_line_range": item["source_line_range"],
                "source_sha256": item["source_sha256"],
                "compile_manifest": item["product_compile_manifest"],
                "active_product_witness": item["active_product_witness"],
                "reason": item["reason"],
            }
    fixed_parameter_map = summary.setdefault("fixed_parameter_dispositions", {})
    for item in fixed_parameter_dispositions:
        for bin_id in item["semantic_bin_ids"]:
            fixed_parameter_map[bin_id] = {
                "status": "PROVEN_UNREACHABLE",
                "method": item["method"],
                "review_id": item["review_id"],
                "source_sha256": item["source_sha256"],
                "compile_manifest": item["product_compile_manifest"],
                "compile_manifest_sha256": item["compile_manifest_sha256"],
                "active_product_witness": item["active_product_witness"],
                "active_product_witness_sha256": item["active_product_witness_sha256"],
                "reason": item["reason"],
            }
    summary["approved_waivers"] = 0
    summary["exclusions_applied"] = 0
    summary["reviewed_formal_open_candidates"] = reviewed_open
    summary["interpretation"] = (
        f"{len(dispositions)} exact bins are Formal-proven unreachable and "
        f"{len(elaboration_ids | fixed_parameter_ids)} are unreachable by exact product static-parameter elaboration "
        f"({len(elaboration_ids)} EF2 pair-look-ahead and {len(fixed_parameter_ids)} fixed-parameter guard bins); "
        f"{counts.get('OPEN', 0)} code gaps remain OPEN. Raw URG bins and denominators are unchanged; "
        "no waiver or exclusion is applied."
    )
    args.summary.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    closure = args.closure_report.read_text(encoding="utf-8")
    formal_lines = [
        f"The source-bound review closed {counts.get('PROVEN_UNREACHABLE', 0)} exact bins as "
        f"PROVEN_UNREACHABLE; {counts.get('OPEN', 0)} remain OPEN. Formal Inconclusive is not "
        "a closure. Raw URG and its denominator are unchanged; approved waivers and active "
        ".el exclusions are both zero.",
        "",
        "| Semantic Bin ID | Assertion | Cover | Disposition |",
        "|---|---|---|---|",
    ]
    for item in sorted(dispositions, key=lambda row: row["semantic_bin_id"]):
        formal_lines.append(
            f"| `{item['semantic_bin_id']}` | `{item['assertion']}` | `{item['cover']}` | "
            "PROVEN_UNREACHABLE; retained in Raw |"
        )
    formal_lines.extend([
        "",
        "The following candidate-only source paths are statically unreachable in the exact product elaboration. This is not based on the rejected tautological parameter SVA goals and does not alter Raw URG:",
        "",
        "| Review ID | Exact bin count | Source span / guard | Method |",
        "|---|---:|---|---|",
    ])
    for item in elaboration_dispositions:
        formal_lines.append(
            f"| `{item.get('review_id', '')}` | {len(item['semantic_bin_ids'])} | "
            f"`rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:"
            f"{item['source_line_range'][0]}-{item['source_line_range'][1]}` "
            f"and `PAIR_LOOKAHEAD` guard | exact static product parameter chain |"
        )
    for item in fixed_parameter_dispositions:
        formal_lines.append(
            f"| `{item.get('review_id', '')}` | {len(item['semantic_bin_ids'])} | "
            "17 exact Branch bins across frame gain, centered interpolators, EF2, AXI-Lite DPD guard, "
            "and GT width guard | exact product parameter chain with compile manifest, active VCS witness, "
            "and source hashes |"
        )
    formal_lines.extend([
        "",
        "Reviewed candidates with tautological or otherwise invalid Formal evidence remain OPEN:",
        "",
        "| Semantic Bin ID | Status | Reason |",
        "|---|---|---|",
    ])
    for item in sorted(reviewed_open, key=lambda row: row["semantic_bin_id"]):
        formal_lines.append(
            f"| `{item['semantic_bin_id']}` | OPEN | {item['reason']} |"
        )
    formal_lines.append("")
    closure = append_current_source_formal_section(
        closure, summary["source_product_sha"], formal_lines
    )
    args.closure_report.write_text(closure, encoding="utf-8")

    manifest["followup"] = {
        **manifest.get("followup", {}),
        "formal_review_json": str(args.review.resolve().relative_to(ROOT)),
        "formal_review_sha256": sha256(args.review),
        "formal_disposition_script_sha256": sha256(Path(__file__).resolve()),
        "formal_status": "PASS_FOR_EXACT_REACHABILITY_DISPOSITIONS; DPD_IDENTITY_OPEN",
        "proven_unreachable_bin_count": counts.get("PROVEN_UNREACHABLE", 0),
        "static_elaboration_bin_count": len(elaboration_ids),
        "static_fixed_parameter_branch_bin_count": len(fixed_parameter_ids),
        "reviewed_open_candidate_count": len(reviewed_open),
        "raw_coverage_edited": False,
        "product_urg_refreshed": refresh_evidence is not None,
        "product_urg_refresh_evidence": (
            str(args.refresh_evidence.resolve().relative_to(ROOT)) if refresh_evidence else None
        ),
        "product_urg_refresh_evidence_sha256": (
            sha256(args.refresh_evidence) if refresh_evidence else None
        ),
        "approved_waivers": 0,
        "exclusions_applied": 0,
    }
    output_hashes = manifest.setdefault("output_sha256", {})
    for path in (args.ledger, args.tasks, args.summary, args.closure_report):
        output_hashes[path.name] = sha256(path)
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"ledger_rows": len(ledger_rows), "closure_status_counts": dict(counts),
                      "formal_disposition_bins": len(dispositions),
                      "static_elaboration_disposition_bins": len(elaboration_ids),
                      "static_fixed_parameter_branch_bins": len(fixed_parameter_ids),
                      "raw_coverage_edited": False, "exclusions_applied": 0}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
