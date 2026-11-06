#!/usr/bin/env python3.12
"""Fail-closed audit for the scoped DPD vector ready/valid Formal result."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    "rtl/dpd/dpd_poly.v",
    "rtl/dpd/dpd_memory_poly.v",
    "rtl/dpd/dpd_vector16_memory_poly.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
    "dv/uvm/formal/thermo5_dpd_vector_ready_harness.sv",
    "dv/uvm/formal/run_thermo5_dpd_vector_ready_fpv.tcl",
)
EXPECTED_COVERS = {
    "c_input_accept": "covered",
    "c_output_transfer": "covered",
    "c_output_stall": "covered",
    "c_stall_release": "covered",
    "c_line93_uncovered_tuple": "uncoverable",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_relative_or_absolute(path: Path) -> str:
    resolved = path.resolve()
    try:
        return resolved.relative_to(ROOT).as_posix()
    except ValueError:
        return str(resolved)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--formal-dir", type=Path, required=True,
                    help="VC Formal output directory containing console/setup/properties")
    ap.add_argument("--raw-urg-html", type=Path,
                    help="Optional Raw URG module HTML used to bind the prior miss")
    ap.add_argument("--raw-report-manifest", type=Path,
                    help="Optional same-list Raw/Adjusted URG manifest")
    ap.add_argument("--raw-vdb-manifest", type=Path,
                    help="Optional exact VDB inventory manifest")
    ap.add_argument("--output", type=Path, required=True,
                    help="Machine-readable audit output JSON")
    args = ap.parse_args()

    formal_dir = args.formal_dir.resolve()
    required = {name: formal_dir / name for name in
                ("console.log", "setup.txt", "properties.txt")}
    errors: list[str] = []
    for name, path in required.items():
        if not path.is_file():
            errors.append(f"missing Formal output: {name}")

    properties_text = (required["properties.txt"].read_text(errors="replace")
                       if required["properties.txt"].is_file() else "")
    setup_text = (required["setup.txt"].read_text(errors="replace")
                  if required["setup.txt"].is_file() else "")
    console_text = (required["console.log"].read_text(errors="replace")
                    if required["console.log"].is_file() else "")

    property_rows = re.findall(
        r"^\s*\[\s*\d+\]\s+"
        r"(?P<state>proven|inconclusive(?:\(depth=\d+\))?|failed|"
        r"undetermined|unprocessed|covered|uncoverable)(?=\s|$)"
        r"\s*(?:\((?P<qualifier>non_vacuous)\))?.*?-\s+\S+\."
        r"(?P<name>\w+)\s*$",
        properties_text, re.M,
    )
    assertions: dict[str, dict[str, object]] = {}
    covers: dict[str, str] = {}
    for row in property_rows:
        state = row[0]
        non_vacuous = row[1]
        name = row[2]
        if state.startswith("inconclusive("):
            state = "inconclusive"
        if name.startswith("a_"):
            assertions[name] = {"state": state,
                                "non_vacuous": non_vacuous == "non_vacuous"}
        elif name.startswith("c_"):
            covers[name] = state

    exact_assertion = assertions.get("a_empty_output_allows_input", {})
    if exact_assertion.get("state") != "proven" or not exact_assertion.get("non_vacuous"):
        errors.append("empty-output ready implication is not proven non-vacuously")
    for name, expected in EXPECTED_COVERS.items():
        if covers.get(name) != expected:
            errors.append(f"{name}: expected {expected}, got {covers.get(name)}")
    assumption_names = re.findall(r"^\s*\[\s*\d+\]\s+\w+.*?-\s+\S*\.(assume_\S+)\s*$",
                                  properties_text, re.M)
    if assumption_names or re.search(r"\bassume\s+property\b",
                                     (ROOT / SOURCES[-2]).read_text(), re.I):
        errors.append("unexpected Formal environment assumption")
    if re.search(r":\s*[1-9]\d*\s*$", setup_text, re.M):
        errors.append("selected Formal setup checks reported a violation")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console_text):
        errors.append("zero-black-box result missing")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console_text:
        errors.append("VC Formal marked a goal tautological")

    source_hashes = {name: sha256(ROOT / name) for name in SOURCES}
    revision = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                              check=True, capture_output=True, text=True).stdout.strip()
    raw_inputs: dict[str, object] = {}
    raw_input_metadata: dict[str, object] = {}
    for key, path in (("urg_html", args.raw_urg_html),
                      ("report_manifest", args.raw_report_manifest),
                      ("vdb_manifest", args.raw_vdb_manifest)):
        if path is not None:
            resolved = path.resolve()
            if not resolved.is_file():
                errors.append(f"Raw coverage evidence missing: {resolved}")
            else:
                raw_inputs[key] = {"path": repo_relative_or_absolute(resolved),
                                   "sha256": sha256(resolved)}
                if key in ("report_manifest", "vdb_manifest"):
                    manifest = json.loads(resolved.read_text(encoding="utf-8"))
                    if key == "report_manifest":
                        raw_input_metadata["report"] = {
                            "source_revision": manifest.get("source_revision"),
                            "raw_summary": manifest.get("raw_summary"),
                            "approved_waiver_count": manifest.get("approved_waiver_count"),
                            "adjusted_exclusions_applied": manifest.get("adjusted_exclusions_applied"),
                        }
                    else:
                        raw_input_metadata["vdb_inventory"] = {
                            "design_tree_sha256": manifest.get("design", {}).get("tree_sha256"),
                            "test_vdb_tree_count": len(manifest.get("tests", [])),
                        }

    target_ok = not errors
    extended_state = assertions.get("a_stalled_output_is_held", {}).get("state", "missing")
    if target_ok and extended_state in ("inconclusive", "undetermined", "unprocessed", "failed", "missing"):
        status = "TARGET_PROVEN_EXTENDED_PROPERTY_OPEN"
    elif target_ok:
        status = "TARGET_PROVEN"
    else:
        status = "OPEN"

    output = {
        "schema_version": 1,
        "status": status,
        "target_bin": {
            "task_id": "TXC-42b3e1174f6032fbbd84",
            "semantic_bin_id": "TXB-33613a1855fcc02e8ef4",
            "raw_bin_id": "ecc391f634f890dbadb6",
            "configuration": "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120; 20-bit state; DPD_MAX_TAPS=1; AXI-Lite; Generic FIFO",
            "instance": "thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd",
            "source_position": "rtl/dpd/dpd_vector16_memory_poly.sv:93",
            "urg_condition": "in_ready || !out_valid",
            "uncovered_operands": "0/1",
            "formal_target": "!in_ready && !out_valid",
            "disposition": "PROVEN_UNREACHABLE" if target_ok else "OPEN",
            "raw_coverage_action": "retain unhit bin in Raw and denominator; no Exclusion generated",
            "waiver": "none requested or approved",
        },
        "formal": {
            "assertions": assertions,
            "covers": covers,
            "environment_assumptions": assumption_names,
            "reset_initial_constraint": "rst_n==1",
            "black_box_instances": 0 if "Number of Black-Box Instances = 0" in console_text else None,
            "tool_banner": next((line.strip() for line in console_text.splitlines()
                                  if "Version V-" in line), "UNKNOWN"),
            "formal_directory": repo_relative_or_absolute(formal_dir),
            "sha256": {name: sha256(path) for name, path in required.items()
                       if path.is_file()},
            "run_command": "THERMO5_FORMAL_REPO=$PWD THERMO5_FORMAL_OUT=$PWD/runs/thermo5_dpd_vector_ready_formal_20261103 PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV -f $PWD/dv/uvm/formal/run_thermo5_dpd_vector_ready_fpv.tcl",
        },
        "source": {
            "git_revision_at_audit": revision,
            "source_sha256": source_hashes,
            "product_rtl_changed": False,
        },
        "raw_coverage": {
            "status": "UNHIT_RETAINED",
            "metric": "condition",
            "raw_coverage_before": "658/849",
            "raw_coverage_after": "658/849",
            "adjusted_coverage": "same as Raw; no approved exclusions",
            "latest_report_inputs": raw_inputs,
            "latest_report_metadata": raw_input_metadata,
            "note": "Formal reachability does not change URG hit counts or the denominator.",
        },
        "extended_output_hold_assertion": {
            "property": "a_stalled_output_is_held",
            "state": extended_state,
            "meaning": "The complete 512-bit output payload-hold property is separate from the line-93 ready/valid condition; it remains open unless proven.",
        },
        "errors": errors,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": status, "errors": errors,
                      "output": str(args.output)}, sort_keys=True))
    return 0 if target_ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
