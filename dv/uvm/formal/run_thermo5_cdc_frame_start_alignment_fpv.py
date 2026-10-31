#!/usr/bin/env python3.12
"""Prove legal packet frame-start alignment through the product CDC gearbox."""

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
    "dv/uvm/formal/thermo5_cdc_frame_start_alignment_harness.sv",
    "dv/uvm/formal/run_thermo5_cdc_frame_start_alignment_fpv.tcl",
    "dv/uvm/formal/run_thermo5_cdc_frame_start_alignment_fpv.py",
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
    work = out / "cdc_frame_start_alignment"
    work.mkdir()
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(work))
    argv = ["vcf", "-batch", "-fmode", "FPV", "-f",
            str(ROOT / "dv/uvm/formal/run_thermo5_cdc_frame_start_alignment_fpv.tcl")]
    started = time.monotonic()
    console = work / "console.log"
    with console.open("w", encoding="utf-8") as stream:
        run = subprocess.run(argv, cwd=work, env=env, stdout=stream,
                             stderr=subprocess.STDOUT, check=False)

    properties_path, setup_path = work / "properties.txt", work / "setup.txt"
    if not properties_path.is_file() or not setup_path.is_file():
        print(json.dumps({"status": "FAIL", "reason": "missing Formal reports",
                          "console": str(console)}))
        return 1
    props = properties_path.read_text(encoding="utf-8", errors="replace")
    setup = setup_path.read_text(encoding="utf-8", errors="replace")
    banner = console.read_text(encoding="utf-8", errors="replace")
    assertions = re.findall(
        r"^\s*\[\s*\d+\]\s+(proven|falsified|failed|vacuous|"
        r"inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)", props, re.M)
    covers = re.findall(
        r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)",
        props, re.M)
    observed_assertions = {name: status for status, name in assertions}
    observed_covers = {name: status for status, name in covers}
    expected_assertions = {
        "thermo5_cdc_frame_start_alignment_harness.a_frame_start_pop_aligned",
        "thermo5_cdc_frame_start_alignment_harness.a_no_product_protocol_error",
    }
    expected_covers = {
        "thermo5_cdc_frame_start_alignment_harness.c_first_frame_start_pop": "covered",
        "thermo5_cdc_frame_start_alignment_harness.c_second_frame_start_pop": "covered",
        "thermo5_cdc_frame_start_alignment_harness.c_second_frame_end_pop": "covered",
        "thermo5_cdc_frame_start_alignment_harness.c_second_frame_output_end": "covered",
        "thermo5_cdc_frame_start_alignment_harness.c_misaligned_frame_start_target": "uncoverable",
    }
    blackboxes = re.findall(r"Number of Black-Box Instances\s*=\s*(\d+)", banner)
    setup_clean = not re.search(r":\s+[1-9]\d*\s*$", setup, re.M)
    no_tautology = not re.search(r"Warning-\[SVAC-TAUT-(?:PROPERTY|COVER)\]", banner)
    assertion_vacuity = not re.search(
        r"a_frame_start_pop_aligned\s+vacuous|a_no_product_protocol_error\s+vacuous", banner)
    no_assumptions = not re.search(r"\bconstrained\s+\(non_vacuous\)", props)
    passed = (
        run.returncode == 0
        and set(observed_assertions) == expected_assertions
        and all(observed_assertions[name] == "proven" for name in expected_assertions)
        and observed_covers == expected_covers
        and setup_clean and blackboxes and all(n == "0" for n in blackboxes)
        and no_tautology and assertion_vacuity and no_assumptions
    )
    summary = {
        "status": "PASS_TWO_PACKET_ALIGNMENT" if passed else "INCONCLUSIVE_OR_FAIL",
        "git_revision": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            check=True, stdout=subprocess.PIPE, text=True).stdout.strip(),
        "git_worktree_dirty": bool(subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
            check=True, stdout=subprocess.PIPE, text=True).stdout.strip()),
        "tool": next((line.strip() for line in banner.splitlines() if "Version V-" in line), "UNKNOWN"),
        "argv": argv,
        "exit_code": run.returncode,
        "duration_seconds": round(time.monotonic() - started, 2),
        "scope": "Production 14:8 CDC and Generic FIFO; two consecutive legal 32-beat packets; fixed payload/gain; source VALID is reset-delayed and markers advance only on accepted handshakes; exact 14:8 clocks; no environment assumptions.",
        "assertions": assertions,
        "covers": covers,
        "assumptions": re.findall(r"^\s*\[\s*\d+\]\s+constrained\s+\(non_vacuous\).*? -\s+(\S+)", props, re.M),
        "black_box_instances": blackboxes,
        "source_sha256": {name: sha256(ROOT / name) for name in SOURCES},
        "evidence_sha256": {
            "console": sha256(console), "properties": sha256(properties_path),
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
