#!/usr/bin/env python3.12
"""Run fail-closed MAX_TAPS=1 DPD Pair-1 structural proofs."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parents[3]
SOURCES = (
    "rtl/dpd/dpd_poly.v",
    "rtl/dpd/dpd_memory_poly.v",
    "rtl/dpd/dpd_vector16_memory_poly.sv",
    "dv/uvm/formal/thermo5_dpd_pair1_harness.sv",
    "dv/uvm/formal/run_thermo5_dpd_pair1_fpv.tcl",
    "dv/uvm/formal/run_thermo5_dpd_pair1_fpv.py",
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
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
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    command = ["vcf", "-batch", "-fmode", "FPV", "-f",
               str(ROOT / "dv/uvm/formal/run_thermo5_dpd_pair1_fpv.tcl")]
    log_path = out / "console.log"
    started = time.monotonic()
    try:
        with log_path.open("w", encoding="utf-8") as log:
            exit_code = subprocess.run(command, cwd=out, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=600).returncode
        timeout = False
    except subprocess.TimeoutExpired:
        exit_code, timeout = None, True

    properties_path, setup_path = out / "properties.txt", out / "setup.txt"
    properties = properties_path.read_text(encoding="utf-8", errors="replace") if properties_path.exists() else ""
    setup = setup_path.read_text(encoding="utf-8", errors="replace") if setup_path.exists() else ""
    console = log_path.read_text(encoding="utf-8", errors="replace")
    assertions = re.findall(
        r"^\s*\[\s*\d+\]\s+(proven|failed|inconclusive|undetermined|unprocessed)\b.*?\.a_(\S+)\s*$",
        properties, re.M,
    )
    covers = {
        name: state for state, name in re.findall(
            r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\b.*?\.((?:c_\S+))\s*$",
            properties, re.M,
        )
    }
    errors: list[str] = []
    if len(assertions) != 64 or any(state != "proven" for state, _ in assertions):
        errors.append(f"expected 64 proven Pair-1 lane invariants, got {len(assertions)}")
    if covers != {"c_product_input_accept": "covered",
                  "c_product_output_transfer": "covered"}:
        errors.append(f"product activity covers did not resolve: {covers}")
    constraint_lines = re.findall(
        r"^\s*\[\s*\d+\]\s+constrained\b.*$", properties, re.M
    )
    constraints = [line.rsplit("-", 1)[-1].strip() for line in constraint_lines]
    if constraints != ["rst_n==1"]:
        errors.append(f"expected only the formal reset constraint rst_n==1, got {constraints}")
    if re.search(r":\s+[1-9]\d*\s*$", setup, re.M):
        errors.append("Formal setup reported a nonzero structural check")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        errors.append("zero black-box evidence missing")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console:
        errors.append("VC Formal marked a Pair-1 goal tautological")
    if timeout:
        errors.append("VC Formal timed out after 600 seconds")
    elif exit_code != 0:
        errors.append(f"VC Formal exit code {exit_code}")
    states = [state for state, _ in assertions] + list(covers.values())
    if errors or "failed" in states:
        status = "FAIL"
    elif any(x in {"inconclusive", "undetermined", "unprocessed"} for x in states):
        status = "INCONCLUSIVE"
    else:
        status = "PASS"
    manifest = {
        "schema_version": 1,
        "status": status,
        "scope": "Sixteen production dpd_memory_poly lanes, MAX_TAPS=1, arbitrary input/coefficient/tap-enable data and arbitrary backpressure; proves four Pair-1 accumulator nodes per lane are zero.",
        "product_configuration": {"lanes": 16, "max_taps": 1},
        "source": {"git_revision": revision, "worktree_dirty": bool(git_status),
                   "git_status": git_status, "sha256": {name: sha(ROOT / name) for name in SOURCES}},
        "command": command,
        "exit_code": exit_code,
        "timeout": timeout,
        "duration_seconds": round(time.monotonic() - started, 2),
        "tool_banner": next((line.strip() for line in console.splitlines() if "Version V-" in line), "UNKNOWN"),
        "proven_lane_invariants": len(assertions),
        "covers": covers,
        "non_vacuity_evidence": {
            "formal_reset_constraint_only": constraints == ["rst_n==1"],
            "input_accept_cover": covers.get("c_product_input_accept"),
            "output_transfer_cover": covers.get("c_product_output_transfer"),
        },
        "setup_sha256": sha(setup_path) if setup_path.exists() else None,
        "properties_sha256": sha(properties_path) if properties_path.exists() else None,
        "console_sha256": sha(log_path),
        "errors": errors,
    }
    (out / "formal_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": status, "errors": errors,
                      "manifest": str(out / "formal_manifest.json")}, sort_keys=True))
    return 0 if status == "PASS" else 2 if status == "INCONCLUSIVE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
