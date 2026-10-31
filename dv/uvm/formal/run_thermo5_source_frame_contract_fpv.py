#!/usr/bin/env python3.12
"""Run exact-product Formal reachability for the legal TX frame-end contract."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


ROOT = Path(__file__).resolve().parents[3]
PRODUCT_SOURCE_SHA = "19d295360aa6438f4af20e7a6ab44bfebf2fc1ea"
SOURCES = (
    "rtl/axis/dsm_reset_sync.sv",
    "rtl/axis/dsm_async_fifo.sv",
    "rtl/axis/dsm_axis14_to_core8_cdc.sv",
    "rtl/frontend/dsm_frame_gain_vector.sv",
    "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
    "rtl/interp/dsm_interp_x2_polyphase_vector.sv",
    "rtl/dpd/dpd_poly.v",
    "rtl/dpd/dpd_memory_poly.v",
    "rtl/dpd/dpd_vector16_memory_poly.sv",
    "rtl/gt/gt_tx_user_bridge.sv",
    "rtl/gt/gt_tx_raw64_boundary.sv",
    "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
    "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
    "dv/uvm/formal/thermo5_source_frame_contract_harness.sv",
    "dv/uvm/formal/run_thermo5_source_frame_contract_fpv.tcl",
    "dv/uvm/formal/run_thermo5_source_frame_contract_fpv.py",
)
EXPECTED_ASSERTIONS = {"a_no_early_tlast": "proven"}
EXPECTED_COVERS = {
    "c_source_accept": "covered",
    "c_legal_packet_end": "covered",
    "c_early_tlast_target": "uncoverable",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("--out-dir must be a new directory under runs/")
    out.mkdir(parents=True)

    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    command = ["vcf", "-batch", "-fmode", "FPV", "-f",
               str(ROOT / "dv/uvm/formal/run_thermo5_source_frame_contract_fpv.tcl")]
    log_path = out / "console.log"
    started = time.monotonic()
    try:
        with log_path.open("w", encoding="utf-8") as log:
            completed = subprocess.run(command, cwd=out, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=args.timeout,
                                       check=False)
        exit_code, timeout = completed.returncode, False
    except subprocess.TimeoutExpired:
        exit_code, timeout = None, True

    props_path, setup_path = out / "properties.txt", out / "setup.txt"
    props = props_path.read_text(encoding="utf-8", errors="replace") if props_path.exists() else ""
    setup = setup_path.read_text(encoding="utf-8", errors="replace") if setup_path.exists() else ""
    console = log_path.read_text(encoding="utf-8", errors="replace")
    assertions = {name: state for state, name in re.findall(
        r"^\s*\[\s*\d+\]\s+(proven|failed|inconclusive|undetermined|unprocessed)\b.*?-\s+\S*\.(a_\S+)\s*$",
        props, re.M)}
    covers = {name: state for state, name in re.findall(
        r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\b.*?-\s+\S*\.(c_\S+)\s*$",
        props, re.M)}
    errors = []
    mismatches = []
    for name, expected in EXPECTED_ASSERTIONS.items():
        if assertions.get(name) != expected:
            mismatches.append(f"{name}: expected {expected}, got {assertions.get(name)}")
    for name, expected in EXPECTED_COVERS.items():
        if covers.get(name) != expected:
            mismatches.append(f"{name}: expected {expected}, got {covers.get(name)}")
    if re.search(r"^\s*\[\s*\d+\]\s+\w+\b.*?-\s+\S*\.asm_", props, re.M):
        errors.append("the legal packet driver must not require environment assumptions")
    if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
        errors.append("Formal setup reported nonzero selected checks")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        errors.append("zero-black-box evidence missing")
    non_vacuous = [int(x) for x in re.findall(r"# non_vacuous\s*:\s*(\d+)", props)]
    if not non_vacuous or max(non_vacuous) < 1:
        errors.append("the early-TLAST assertion has no non-vacuous legal packet witness")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console:
        errors.append("VC Formal marked a target goal tautological")
    if timeout:
        errors.append(f"VC Formal timed out after {args.timeout} seconds")
    elif exit_code != 0:
        errors.append(f"VC Formal exit code {exit_code}")

    states = list(assertions.values()) + list(covers.values())
    inconclusive = timeout or any(x in {"inconclusive", "undetermined", "unprocessed"} for x in states)
    failed = any(x == "failed" for x in states)
    status = "FAIL" if errors or failed else "INCONCLUSIVE" if inconclusive or mismatches else "PASS"
    manifest = {
        "schema_version": 1,
        "status": status,
        "product_source_sha": PRODUCT_SOURCE_SHA,
        "scope": {
            "configuration": "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120 STATE_BITS=20; DPD_MAX_TAPS=1 identity; Generic FIFO",
            "driver": "one legal 32-beat AXIS packet; TVALID/data remain stable until handshake; TLAST generated only at accepted beat 31",
            "environment_assumptions": 0,
            "target_semantic_bin": "TXB-646dd03c99766d877d30",
            "target_source": "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:141",
        },
        "source_sha256": {name: sha(ROOT / name) for name in SOURCES},
        "command": command,
        "tool_banner": next((line.strip() for line in console.splitlines() if "Version V-" in line), "UNKNOWN"),
        "exit_code": exit_code,
        "timeout": timeout,
        "duration_seconds": round(time.monotonic() - started, 2),
        "assertions": assertions,
        "covers": covers,
        "maximum_non_vacuous_goal_count": max(non_vacuous) if non_vacuous else None,
        "expectation_mismatches": mismatches,
        "errors": errors,
        "setup_sha256": sha(setup_path) if setup_path.exists() else None,
        "properties_sha256": sha(props_path) if props_path.exists() else None,
        "console_sha256": sha(log_path),
    }
    (out / "formal_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": status, "errors": errors, "expectation_mismatches": mismatches,
                      "manifest": str(out / "formal_manifest.json")}, sort_keys=True))
    return 0 if status == "PASS" else 2 if status == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
