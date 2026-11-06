#!/usr/bin/env python3.12
"""Run and audit the composed one-tap Identity DPD arithmetic proof."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[3]
TCL = ROOT / "dv/uvm/formal/run_thermo5_dpd_identity_stall_fpv.tcl"
AUDITOR = ROOT / "tools/hw/audit_thermo5_dpd_identity_stall_fpv.py"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--evidence", type=Path)
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--vcf", default="vcf", help="VC Formal executable or path")
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("--out-dir must be a new directory below runs/")
    out.mkdir(parents=True)

    vcf = shutil.which(args.vcf) if "/" not in args.vcf else str(Path(args.vcf).resolve())
    if not vcf or not Path(vcf).is_file():
        parser.error(f"VC Formal executable not found: {args.vcf}")
    command = [vcf, "-batch", "-fmode", "FPV", "-f", str(TCL)]
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    source_git_revision = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    source_git_status = subprocess.run(
        ["git", "-C", str(ROOT), "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    started = time.monotonic()
    timed_out = False
    exit_code: int | None
    try:
        with (out / "vcf.log").open("w", encoding="utf-8") as log:
            result = subprocess.run(command, cwd=out, env=env, stdout=log,
                                    stderr=subprocess.STDOUT, timeout=args.timeout,
                                    check=False)
        exit_code = result.returncode
    except subprocess.TimeoutExpired:
        timed_out = True
        exit_code = None
    run_result = {
        "command": command,
        "exit_code": exit_code,
        "timeout": timed_out,
        "timeout_seconds": args.timeout,
        "duration_seconds": round(time.monotonic() - started, 2),
        "vcf_resolved_path": vcf,
        "source_git_revision": source_git_revision,
        "source_worktree_clean_at_start": not source_git_status,
    }
    (out / "run_result.json").write_text(json.dumps(run_result, indent=2) + "\n")
    audit_command = [sys.executable, str(AUDITOR), "--formal-dir", str(out)]
    if args.evidence:
        audit_command += ["--output", str(args.evidence.resolve())]
    return subprocess.run(audit_command, cwd=ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
