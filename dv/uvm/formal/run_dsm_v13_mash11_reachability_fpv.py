#!/usr/bin/env python3
"""Run the unwaived MASH weighted-output reachability proof with VC Formal."""

from __future__ import annotations

import hashlib
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
    engines_path = out / "engines.txt"
    required_assertions = (
        "a_atomic_four_plane_valid", "a_held_word_stable",
        "a_no_unreachable_weighted_level",
        "a_minimum_rail_never_stage1_positive",
        "a_accepted_combined_levels_legal",
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
    unreachable_candidate_covers = (
        "c_output_minus_four", "c_output_minus_two", "c_output_zero",
        "c_output_plus_four", "c_minimum_rail_stage1_positive",
    )
    candidate_bins_unreachable = all(
        any("uncoverable" in line and name in line for line in property_text.splitlines())
        for name in unreachable_candidate_covers)
    closure_pass = (returncode == 0 and not timed_out and assertions_proven and
                    covers_hit and candidate_bins_unreachable)
    evidence = {
        "schema": "dsm_v13_mash11_reachability_fpv_v3",
        "command": command,
        "vcf": executable,
        "returncode": returncode,
        "timed_out": timed_out,
        "timeout_seconds": args.timeout,
        "duration_seconds": round(time.monotonic() - start, 2),
        "source_revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "source_sha256": {
            str(path.relative_to(ROOT)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in (
                ROOT / "rtl/tx_bandpass_if/tid32_mash11_weighted_pa_tx.sv",
                ROOT / "dv/uvm/formal/dsm_v13_mash11_reachability_harness.sv",
                ROOT / "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.tcl",
                Path(__file__).resolve(),
            )
        },
        "counterexample_trace": str(
            (out / "mash11_weighted_level_counterexample.fsdb").relative_to(ROOT)
        ) if (out / "mash11_weighted_level_counterexample.fsdb").is_file() else None,
        "output_zero_witness": str(
            (out / "mash11_output_zero_witness.fsdb").relative_to(ROOT)
        ) if (out / "mash11_output_zero_witness.fsdb").is_file() else None,
        "required_assertions": list(required_assertions),
        "assertions_proven": assertions_proven,
        "formal_parameters": {"W": 16, "CHANNELS": 32, "ACC_W": 18,
                              "IN_SHIFT": 0, "SATURATE": True},
        "formal_contract": "reset-constrained sequential MASH 1-1; arbitrary legal 16-bit samples across all 32 lanes; source payload stable while valid is held without ready",
        "required_covers": list(required_covers),
        "covers_hit": covers_hit,
        "unreachable_candidate_covers": list(unreachable_candidate_covers),
        "candidate_bins_unreachable": candidate_bins_unreachable,
        "properties_sha256": hashlib.sha256(property_text.encode("utf-8")).hexdigest(),
        "engines_sha256": hashlib.sha256(engines_path.read_bytes()).hexdigest()
        if engines_path.is_file() else None,
        "vcf_log_sha256": hashlib.sha256((out / "vcf.log").read_bytes()).hexdigest()
        if (out / "vcf.log").is_file() else None,
        "status": "PASS" if closure_pass else "OPEN",
        "waiver_status": "NO_WAIVER_REQUESTED",
    }
    (out / "run_result.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print("DSM_V13_MASH_REACHABILITY_%s=%s" % (evidence["status"], out))
    return 0 if evidence["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
