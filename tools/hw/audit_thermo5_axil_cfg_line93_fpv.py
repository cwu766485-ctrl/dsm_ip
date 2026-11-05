#!/usr/bin/env python3.12
"""Fail-closed audit of the exact AXI-Lite line-93 Formal/Raw evidence."""

from __future__ import annotations

import argparse
import hashlib
from html import unescape
import json
from pathlib import Path
import re
import subprocess
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[2]
RTL = "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv"
HARNESS = "dv/uvm/formal/thermo5_axil_cfg_line93_harness.sv"
TCL = "dv/uvm/formal/run_thermo5_axil_cfg_line93_fpv.tcl"
EXPECTED_RTL_SHA256 = "780130a318b4c4e272c4b95d32749ca669ed51585784fa4cb789bf0c1a584ba7"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--formal-dir", type=Path, required=True)
    ap.add_argument("--raw-html", type=Path, required=True)
    ap.add_argument("--raw-report-manifest", type=Path, required=True)
    ap.add_argument("--raw-vdb-manifest", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    formal_dir = args.formal_dir.resolve()
    inputs = {n: formal_dir / n for n in ("console.log", "setup.txt", "properties.txt")}
    errors = [f"missing Formal output: {n}" for n, p in inputs.items() if not p.is_file()]
    console = inputs["console.log"].read_text(errors="replace") if inputs["console.log"].is_file() else ""
    setup = inputs["setup.txt"].read_text(errors="replace") if inputs["setup.txt"].is_file() else ""
    props = inputs["properties.txt"].read_text(errors="replace") if inputs["properties.txt"].is_file() else ""

    rows = re.findall(
        r"^\s*\[\s*\d+\]\s+(proven|failed|inconclusive(?:\(depth=\d+\))?|"
        r"undetermined|unprocessed|covered|uncoverable)(?=\s|$)"
        r"\s*(?:\((non_vacuous)\))?.*?-\s+\S+\.(\w+)\s*$",
        props, re.M,
    )
    assertions: dict[str, dict[str, object]] = {}
    covers: dict[str, str] = {}
    for state, qualifier, name in rows:
        if name.startswith("a_"):
            assertions[name] = {"state": state,
                                "non_vacuous": qualifier == "non_vacuous"}
        elif name.startswith("c_"):
            covers[name] = state

    target = assertions.get("a_bvalid_excludes_line93_tuple", {})
    if target.get("state") != "proven" or not target.get("non_vacuous"):
        errors.append("exact line-93 assertion is not proven non-vacuously")
    expected_covers = {
        "c_write_response_active": "covered",
        "c_write_fire": "covered",
        "c_line93_uncovered_tuple": "uncoverable",
    }
    for name, expected in expected_covers.items():
        if covers.get(name) != expected:
            errors.append(f"{name}: expected {expected}, got {covers.get(name)}")
    if re.search(r"\bassume\s+property\b", (ROOT / HARNESS).read_text(), re.I):
        errors.append("unexpected Formal environment assumption")
    if re.search(r":\s*[1-9]\d*\s*$", setup, re.M):
        errors.append("selected Formal setup checks reported a violation")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        errors.append("zero-black-box result missing")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console:
        errors.append("VC Formal marked a goal tautological")

    rtl_path = ROOT / RTL
    rtl_sha = sha256(rtl_path)
    if rtl_sha != EXPECTED_RTL_SHA256:
        errors.append("product AXI-Lite RTL SHA differs from the Raw URG source")
    raw_html = args.raw_html.resolve()
    if not raw_html.is_file():
        errors.append("Raw URG module report is missing")
        html_text = ""
    else:
        html_text = unescape(raw_html.read_text(errors="replace"))
    condition = "EXPRESSION (((!s_axil_bvalid)) && (aw_pending || aw_take) && (w_pending || w_take))"
    pos = html_text.find(condition)
    region = html_text[pos:pos + 1800] if pos >= 0 else ""
    if pos < 0 or not re.search(
            r'<tr class="uRed"><td>0</td><td>1</td><td>1</td>'
            r'<td class="lf">Not Covered</td></tr>', region):
        errors.append("latest Raw URG does not show the exact 0/1/1 bin Not Covered")

    report_manifest = json.loads(args.raw_report_manifest.read_text())
    vdb_manifest = json.loads(args.raw_vdb_manifest.read_text())
    metrics = report_manifest.get("raw_summary", {}).get("metrics", {})
    cond = metrics.get("cond", {})
    test_count = len(vdb_manifest.get("tests", []))
    if cond != {"covered": 658, "missing": 191, "total": 849}:
        errors.append(f"unexpected Raw Condition summary: {cond}")
    if test_count != 247:
        errors.append(f"expected 247 test VDB trees, found {test_count}")
    if report_manifest.get("approved_waiver_count") != 0 or report_manifest.get("adjusted_exclusions_applied"):
        errors.append("Raw report is not an unexcluded, zero-approved-waiver baseline")

    revision = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                              check=True, capture_output=True, text=True).stdout.strip()
    target_ok = not errors
    evidence = {
        "schema_version": 1,
        "status": "TARGET_PROVEN" if target_ok else "OPEN",
        "semantic_bin_id": "TXB-872eb98e51c3229e4c86",
        "raw_bin_id": "13d6754bf69d80bac0ac",
        "task_id": "TXC-4a1d631568353e7f8633",
        "metric": "condition",
        "raw_urg_bin": "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:93 operands 0/1/1",
        "instance": "thermo5_sku_uvm_tb.dut.u_cfg",
        "disposition": "PROVEN_UNREACHABLE" if target_ok else "OPEN",
        "formal": {
            "assertions": assertions,
            "covers": covers,
            "environment_assumption_count": 0,
            "reset_initial_constraints": ["axil_rst_n==1", "core_rst_n==1"],
            "black_box_instances": 0 if "Number of Black-Box Instances = 0" in console else None,
            "tool_banner": next((line.strip() for line in console.splitlines()
                                  if "Version V-" in line), "UNKNOWN"),
            "directory": str(formal_dir),
            "run_command": "THERMO5_FORMAL_REPO=$PWD THERMO5_FORMAL_OUT=$PWD/runs/thermo5_axil_cfg_line93_formal_20261103 PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV -f $PWD/dv/uvm/formal/run_thermo5_axil_cfg_line93_fpv.tcl",
            "sha256": {name: sha256(path) for name, path in inputs.items() if path.is_file()},
        },
        "product_source": {
            "rtl_path": RTL,
            "rtl_sha256": rtl_sha,
            "formal_harness_sha256": sha256(ROOT / HARNESS),
            "formal_tcl_sha256": sha256(ROOT / TCL),
            "audit_git_revision": revision,
        },
        "raw_coverage": {
            "bin_state": "NOT_COVERED_RETAINED",
            "condition": cond,
            "raw_adjusted_equal": True,
            "approved_waivers": 0,
            "active_exclusions": 0,
            "test_vdb_tree_count": test_count,
            "report_manifest_sha256": sha256(args.raw_report_manifest.resolve()),
            "vdb_manifest_sha256": sha256(args.raw_vdb_manifest.resolve()),
            "raw_module_html_sha256": sha256(raw_html) if raw_html.is_file() else None,
        },
        "errors": errors,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": evidence["status"], "errors": errors,
                      "output": str(args.output)}, sort_keys=True))
    return 0 if target_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
