#!/usr/bin/env python3.12
"""Run and fail-closed audit scoped AXI-Lite configuration reachability proof."""

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
    "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
    "dv/uvm/formal/thermo5_axil_cfg_coverage_harness.sv",
    "dv/uvm/formal/run_thermo5_axil_cfg_coverage.tcl",
)
EXPECTED_ASSERTIONS = {
    "a_bvalid_clears_pending": "proven",
    "a_coeff_read_default_unreachable": "proven",
    "a_line88_tuple_unreachable": "proven",
    "a_product_max_taps_guard_inactive": "proven",
    "a_write_case_default_unreachable": "proven",
}
EXPECTED_COVERS = {
    "c_coeff_read_transaction": "covered",
    "c_coeff_read_default_arm_unreachable": "uncoverable",
    "c_invalid_max_taps_guard": "uncoverable",
    "c_line88_tuple_unreachable": "uncoverable",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("--out-dir must be a new directory under repository runs/")
    out.mkdir(parents=True)

    source_hashes = {name: sha(ROOT / name) for name in SOURCES}
    revision = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"], check=True,
        capture_output=True, text=True,
    ).stdout.strip()
    git_status = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain"], check=True,
        capture_output=True, text=True,
    ).stdout.splitlines()
    tcl = ROOT / SOURCES[-1]
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    command = ["vcf", "-batch", "-fmode", "FPV", "-f", str(tcl)]
    started = time.monotonic()
    with (out / "console.log").open("w", encoding="utf-8") as log:
        exit_code = subprocess.run(command, cwd=out, env=env, stdout=log,
                                   stderr=subprocess.STDOUT).returncode

    errors: list[str] = []
    prop_path, setup_path = out / "properties.txt", out / "setup.txt"
    console_path = out / "console.log"
    if not prop_path.is_file() or not setup_path.is_file():
        errors.append("VC Formal did not produce properties.txt and setup.txt")
        properties = setup = console = ""
    else:
        properties = prop_path.read_text(encoding="utf-8", errors="replace")
        setup = setup_path.read_text(encoding="utf-8", errors="replace")
        console = console_path.read_text(encoding="utf-8", errors="replace")

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
    for name, expected in EXPECTED_ASSERTIONS.items():
        if assertions.get(name) != expected:
            errors.append(f"{name}: expected {expected}, got {assertions.get(name)}")
    for name, expected in EXPECTED_COVERS.items():
        if covers.get(name) != expected:
            errors.append(f"{name}: expected {expected}, got {covers.get(name)}")
    if re.search(r"^\s*\[\s*\d+\]\s+\w+\b.*?-\s+\S*\.assume_", properties, re.M):
        errors.append("the AXI-Lite reachability harness must not contain environment assumptions")
    if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
        errors.append("Formal setup reported nonzero clock/reset/loop/multidriver checks")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        errors.append("zero black-box evidence missing")
    if not re.search(r"# non_vacuous\s*:\s*3\b", properties):
        errors.append("expected three non-vacuous AXI-Lite assertions")
    if exit_code != 0:
        errors.append(f"VC Formal exit code {exit_code}")

    manifest = {
        "schema_version": 1,
        "status": "PASS" if not errors else "FAIL",
        "product_configuration": {"MAX_TAPS": 1, "AXIL": True},
        "source": {"git_revision": revision, "worktree_dirty": bool(git_status),
                   "git_status": git_status, "source_sha256": source_hashes},
        "tool_banner": next((line.strip() for line in console.splitlines()
                              if "Version V-" in line), "UNKNOWN"),
        "command": command,
        "cwd": str(out),
        "exit_code": exit_code,
        "duration_seconds": round(time.monotonic() - started, 2),
        "assertions": assertions,
        "covers": covers,
        "assumption_count": 0,
        "non_vacuous_assertion_count": 3,
        "black_box_instances": 0 if "Number of Black-Box Instances = 0" in console else None,
        "setup_sha256": sha(setup_path) if setup_path.exists() else None,
        "properties_sha256": sha(prop_path) if prop_path.exists() else None,
        "console_sha256": sha(console_path),
        "errors": errors,
    }
    (out / "formal_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "errors": errors,
                      "manifest": str(out / "formal_manifest.json")}, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
