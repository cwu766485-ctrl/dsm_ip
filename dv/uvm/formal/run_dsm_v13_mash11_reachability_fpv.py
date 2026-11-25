#!/usr/bin/env python3
"""Run the unwaived MASH weighted-output reachability proof with VC Formal."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[3]
TCL = ROOT / "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.tcl"


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path,
        default=ROOT / "runs" / "dsm_v13_round3" / "formal_mash_reachability")
    parser.add_argument("--vcf", default="vcf")
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("--out-dir must be a new directory below runs/")
    executable = shutil.which(args.vcf) if "/" not in args.vcf else str(Path(args.vcf).resolve())
    if not executable or not Path(executable).is_file():
        parser.error("VC Formal executable not found: " + args.vcf)
    out.mkdir(parents=True)
    command = [executable, "-batch", "-fmode", "FPV", "-f", str(TCL)]
    env = os.environ.copy()
    env.update(DSM_V13_FORMAL_REPO=str(ROOT), DSM_V13_FORMAL_OUT=str(out))
    start = time.monotonic()
    timed_out = False
    try:
        with (out / "vcf.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=out, env=env, stdout=log,
                stderr=subprocess.STDOUT, timeout=args.timeout, check=False)
        returncode: int | None = result.returncode
    except subprocess.TimeoutExpired:
        timed_out = True
        returncode = None
    properties_path = out / "properties.txt"
    property_text = properties_path.read_text(encoding="utf-8") if properties_path.is_file() else ""
    required_assertions = (
        "a_atomic_four_plane_valid", "a_held_word_stable",
        "a_no_unreachable_weighted_level",
        "a_minimum_rail_never_stage1_positive",
    )
    required_covers = (
        "c_accepted_sample", "c_output_stall", "c_reset_restart",
        "c_startup_plus_two",
    )
    assertions_proven = all(
        any("proven" in line and name in line for line in property_text.splitlines())
        for name in required_assertions)
    covers_hit = all(
        any("covered" in line and "uncoverable" not in line and name in line
            for line in property_text.splitlines())
        for name in required_covers)
    closure_pass = returncode == 0 and not timed_out and assertions_proven and covers_hit
    evidence = {
        "schema": "dsm_v13_mash11_reachability_fpv_v2",
        "command": command,
        "vcf": executable,
        "returncode": returncode,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout,
        "duration_seconds": round(time.monotonic() - start, 2),
        "source_revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "required_assertions": list(required_assertions),
        "assertions_proven": assertions_proven,
        "required_covers": list(required_covers),
        "covers_hit": covers_hit,
        "status": "PASS" if closure_pass else "OPEN",
        "waiver_status": "NO_WAIVER_REQUESTED",
    }
    (out / "run_result.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print("DSM_V13_MASH_REACHABILITY_%s=%s" % (evidence["status"], out))
    return 0 if evidence["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
