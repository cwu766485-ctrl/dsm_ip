#!/usr/bin/env python3.12
"""Run fail-closed product-bound Formal reachability for the TX counter guards."""

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
    "dv/uvm/formal/thermo5_axil_outstanding_harness.sv",
    "dv/uvm/formal/run_thermo5_axil_outstanding_fpv.tcl",
    "dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py",
)
EXPECTED_ASSERTIONS = {
    "a_no_counter_saturation_guard": "proven",
    "a_no_counter_underflow_guard": "proven",
}
EXPECTED_COVERS = {
    "c_source_accept": "covered",
    "c_core_accept": "covered",
    "c_output_accept": "covered",
    "c_counter_saturation_guard": "uncoverable",
    "c_counter_underflow_guard": "uncoverable",
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

    revision = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], check=True,
        capture_output=True, text=True,
    ).stdout.strip()
    git_status = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain"], check=True,
        capture_output=True, text=True,
    ).stdout.splitlines()
    hashes = {name: sha(ROOT / name) for name in SOURCES}
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    command = ["vcf", "-batch", "-fmode", "FPV", "-f",
               str(ROOT / "dv/uvm/formal/run_thermo5_axil_outstanding_fpv.tcl")]
    log_path = out / "console.log"
    started = time.monotonic()
    try:
        with log_path.open("w", encoding="utf-8") as log:
            completed = subprocess.run(
                command, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT,
                timeout=args.timeout, check=False,
            )
        exit_code = completed.returncode
        timeout = False
    except subprocess.TimeoutExpired:
        exit_code = None
        timeout = True

    properties_path, setup_path = out / "properties.txt", out / "setup.txt"
    properties = properties_path.read_text(encoding="utf-8", errors="replace") if properties_path.exists() else ""
    setup = setup_path.read_text(encoding="utf-8", errors="replace") if setup_path.exists() else ""
    console = log_path.read_text(encoding="utf-8", errors="replace")
    assertions = {
        name: state for state, name in re.findall(
            r"^\s*\[\s*\d+\]\s+(proven|failed|inconclusive|undetermined|unprocessed)\b.*?-\s+\S*\.(a_\S+)\s*$",
            properties, re.M,
        )
    }
    covers = {
        name: state for state, name in re.findall(
            r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\b.*?-\s+\S*\.(c_\S+)\s*$",
            properties, re.M,
        )
    }
    errors: list[str] = []
    expectation_mismatches: list[str] = []
    for name, expected in EXPECTED_ASSERTIONS.items():
        if assertions.get(name) != expected:
            expectation_mismatches.append(f"{name}: expected {expected}, got {assertions.get(name)}")
    for name, expected in EXPECTED_COVERS.items():
        if covers.get(name) != expected:
            expectation_mismatches.append(f"{name}: expected {expected}, got {covers.get(name)}")
    if re.search(r"^\s*\[\s*\d+\]\s+\w+\b.*?-\s+\S*\.asm_", properties, re.M):
        errors.append("the product-bound reachability harness must not use assumptions")
    if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
        errors.append("Formal setup reported nonzero clock/reset/loop/multidriver checks")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        errors.append("zero black-box evidence missing")
    non_vacuous = [int(value) for value in re.findall(r"# non_vacuous\s*:\s*(\d+)", properties)]
    if not non_vacuous or max(non_vacuous) < 2:
        errors.append("both counter assertions must be non-vacuous")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console:
        errors.append("VC Formal marked at least one goal tautological")
    if timeout:
        errors.append(f"VC Formal timed out after {args.timeout} seconds")
    elif exit_code != 0:
        errors.append(f"VC Formal exit code {exit_code}")

    observed_states = list(assertions.values()) + list(covers.values())
    has_inconclusive = timeout or any(
        state in {"inconclusive", "undetermined", "unprocessed"}
        for state in observed_states
    )
    has_failed_goal = any(state == "failed" for state in observed_states)
    if errors or has_failed_goal:
        status = "FAIL"
    elif has_inconclusive or expectation_mismatches:
        status = "INCONCLUSIVE"
    else:
        status = "PASS"

    manifest = {
        "schema_version": 1,
        "status": status,
        "scope": {
            "product_configuration": {
                "interpolation": "Centered-Cubic x2+x2",
                "tidsm_order": 2,
                "step": 5120,
                "dpd_max_taps": 1,
                "dpd": "identity",
                "fifo": "Generic",
            },
            "clock_period_units": {"axil_clk": 35, "source_clk": 28, "core_clk": 16},
            "environment_assumptions": 0,
            "source_driver": "legal 32-beat AXIS packet; stable valid/data until handshake",
            "output_backpressure": "arbitrary per-plane PA ready",
            "target_bins": [
                "TXB-e99262dd92665c3b9ea8",
                "TXB-c16debdf7d9cbab220ac",
            ],
        },
        "source": {"git_revision": revision, "worktree_dirty": bool(git_status),
                   "git_status": git_status, "sha256": hashes},
        "command": command,
        "exit_code": exit_code,
        "timeout": timeout,
        "duration_seconds": round(time.monotonic() - started, 2),
        "tool_banner": next((line.strip() for line in console.splitlines()
                              if "Version V-" in line), "UNKNOWN"),
        "assertions": assertions,
        "covers": covers,
        "maximum_non_vacuous_goal_count": max(non_vacuous) if non_vacuous else None,
        "expectation_mismatches": expectation_mismatches,
        "setup_sha256": sha(setup_path) if setup_path.exists() else None,
        "properties_sha256": sha(properties_path) if properties_path.exists() else None,
        "console_sha256": sha(log_path),
        "errors": errors,
    }
    (out / "formal_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "errors": errors,
                      "manifest": str(out / "formal_manifest.json")}, sort_keys=True))
    return 0 if manifest["status"] == "PASS" else 2 if manifest["status"] == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
