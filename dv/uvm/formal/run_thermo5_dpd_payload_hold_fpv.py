#!/usr/bin/env python3.12
"""Run and fail-closed audit the Thermo5 DPD vector stall-hold Formal proof."""

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
TCL = ROOT / "dv/uvm/formal/run_thermo5_dpd_payload_hold_fpv.tcl"
AUDITOR = ROOT / "tools/hw/audit_thermo5_dpd_payload_hold_fpv.py"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--timeout", type=int, default=360)
    ap.add_argument("--vcf", default="vcf", help="VC Formal executable or path")
    args = ap.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        ap.error("--out-dir must be a new directory below runs/")
    out.mkdir(parents=True)

    vcf = shutil.which(args.vcf) if "/" not in args.vcf else str(Path(args.vcf).resolve())
    if not vcf or not Path(vcf).is_file():
        ap.error(f"VC Formal executable not found: {args.vcf}")
    command = [vcf, "-batch", "-fmode", "FPV", "-f", str(TCL)]
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(out))
    log_path = out / "vcf.log"
    started = time.monotonic()
    timeout = False
    exit_code: int | None
    try:
        with log_path.open("w", encoding="utf-8") as log:
            completed = subprocess.run(command, cwd=out, env=env, stdout=log,
                                       stderr=subprocess.STDOUT, timeout=args.timeout,
                                       check=False)
        exit_code = completed.returncode
    except subprocess.TimeoutExpired:
        timeout = True
        exit_code = None
    run_result = {
        "command": command,
        "exit_code": exit_code,
        "timeout": timeout,
        "timeout_seconds": args.timeout,
        "duration_seconds": round(time.monotonic() - started, 2),
        "vcf_resolved_path": vcf,
    }
    (out / "run_result.json").write_text(json.dumps(run_result, indent=2) + "\n")
    audit = subprocess.run(
        [sys.executable, str(AUDITOR), "--formal-dir", str(out),
         "--output", str(out / "thermo5_dpd_payload_hold_audit.json")],
        cwd=ROOT, check=False,
    )
    return audit.returncode


if __name__ == "__main__":
    raise SystemExit(main())
