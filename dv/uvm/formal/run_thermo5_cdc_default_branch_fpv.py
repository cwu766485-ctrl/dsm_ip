#!/usr/bin/env python3.12
"""Run and validate the product-bound CDC outer-case-default proof."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[3]
SOURCES = (
    "rtl/axis/dsm_reset_sync.sv",
    "rtl/axis/dsm_async_fifo.sv",
    "rtl/axis/dsm_axis14_to_core8_cdc.sv",
    "dv/uvm/formal/thermo5_cdc_default_branch_harness.sv",
    "dv/uvm/formal/run_thermo5_cdc_default_branch_fpv.tcl",
    "dv/uvm/formal/run_thermo5_cdc_default_branch_fpv.py",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} RUNS_OUTPUT_DIR", file=sys.stderr)
        return 2
    out = Path(sys.argv[1]).resolve()
    runs = (ROOT / "runs").resolve()
    if not out.is_relative_to(runs) or out.exists():
        print("output must be a new directory under repository runs/", file=sys.stderr)
        return 2
    out.mkdir(parents=True)
    work = out / "cdc_default_branch"
    work.mkdir()
    env = os.environ.copy()
    env.update(
        THERMO5_FORMAL_REPO=str(ROOT),
        THERMO5_FORMAL_OUT=str(work),
    )
    argv = [
        "vcf", "-batch", "-fmode", "FPV", "-f",
        str(ROOT / "dv/uvm/formal/run_thermo5_cdc_default_branch_fpv.tcl"),
    ]
    started = time.monotonic()
    console = work / "console.log"
    with console.open("w", encoding="utf-8") as stream:
        result = subprocess.run(argv, cwd=work, env=env, stdout=stream,
                                stderr=subprocess.STDOUT, check=False)

    properties_path = work / "properties.txt"
    setup_path = work / "setup.txt"
    if not properties_path.is_file() or not setup_path.is_file():
        print(json.dumps({"status": "FAIL", "reason": "missing Formal reports",
                          "console": str(console)}))
        return 1
    properties = properties_path.read_text(encoding="utf-8", errors="replace")
    setup = setup_path.read_text(encoding="utf-8", errors="replace")
    banner = console.read_text(encoding="utf-8", errors="replace")
    assertions = re.findall(
        r"^\s*\[\s*\d+\]\s+(proven|failed|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)",
        properties, re.M,
    )
    covers = re.findall(
        r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)",
        properties, re.M,
    )
    expected_assertions = {
        "thermo5_cdc_default_branch_harness.a_product_residual_legal",
        "thermo5_cdc_default_branch_harness.a_exact_default_path_unreachable",
    }
    expected_covers = {
        "thermo5_cdc_default_branch_harness.c_exact_default_path": "uncoverable",
        "thermo5_cdc_default_branch_harness.c_product_advance": "covered",
        "thermo5_cdc_default_branch_harness.c_completed_legal_frame": "covered",
    }
    observed_assertions = {name: status for status, name in assertions}
    observed_covers = {name: status for status, name in covers}
    blackboxes = re.findall(r"Number of Black-Box Instances\s*=\s*(\d+)", banner)
    passed = (
        result.returncode == 0
        and observed_assertions == {name: "proven" for name in expected_assertions}
        and observed_covers == expected_covers
        and not re.search(r":\s+[1-9]\d*\s*$", setup, re.M)
        and blackboxes
        and all(count == "0" for count in blackboxes)
        and observed_covers.get(
            "thermo5_cdc_default_branch_harness.c_product_advance"
        ) == "covered"
        and observed_covers.get(
            "thermo5_cdc_default_branch_harness.c_completed_legal_frame"
        ) == "covered"
        and not re.search(r"Warning-\[SVAC-TAUT-(?:PROPERTY|COVER)\]", banner)
    )
    summary = {
        "status": "PASS" if passed else "FAIL",
        "git_revision": subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "HEAD"], check=True,
            stdout=subprocess.PIPE, text=True,
        ).stdout.strip(),
        "git_worktree_dirty": bool(subprocess.run(
            ["git", "-C", str(ROOT), "status", "--porcelain"], check=True,
            stdout=subprocess.PIPE, text=True,
        ).stdout.strip()),
        "tool": next((line.strip() for line in banner.splitlines()
                      if "Version V-" in line), "UNKNOWN"),
        "argv": argv,
        "exit_code": result.returncode,
        "duration_seconds": round(time.monotonic() - started, 2),
        "scope": "Exact production CDC 14:8, Generic FIFO, 16-bit lanes, FIFO depth 16; deterministic aligned 32-beat legal packet source; 14:8 clocks; no environment assumptions.",
        "assertions": assertions,
        "covers": covers,
        "assumptions": re.findall(
            r"^\s*\[\s*\d+\]\s+constrained\s+\(non_vacuous\).*? -\s+(\S+)",
            properties, re.M,
        ),
        "black_box_instances": blackboxes,
        "source_sha256": {name: sha256(ROOT / name) for name in SOURCES},
        "evidence_sha256": {
            "console": sha256(console),
            "properties": sha256(properties_path),
            "setup": sha256(setup_path),
        },
        "evidence": {
            "console": str(console.relative_to(ROOT)),
            "properties": str(properties_path.relative_to(ROOT)),
            "setup": str(setup_path.relative_to(ROOT)),
        },
    }
    (out / "formal_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"status": summary["status"], "manifest": str(out / "formal_summary.json")}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
