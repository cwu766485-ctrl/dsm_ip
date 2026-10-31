#!/usr/bin/env python3.12
"""Check CDC end_remaining coverage reachability for legal TX packet lengths."""

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
    "dv/uvm/formal/thermo5_cdc_end_remaining_harness.sv",
    "dv/uvm/formal/run_thermo5_cdc_end_remaining_fpv.tcl",
    "dv/uvm/formal/run_thermo5_cdc_end_remaining_fpv.py",
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
    work = out / "cdc_end_remaining"
    work.mkdir()
    env = os.environ.copy()
    env.update(THERMO5_FORMAL_REPO=str(ROOT), THERMO5_FORMAL_OUT=str(work))
    argv = ["vcf", "-batch", "-fmode", "FPV", "-f",
            str(ROOT / "dv/uvm/formal/run_thermo5_cdc_end_remaining_fpv.tcl")]
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
        r"inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)",
        props, re.M,
    )
    covers = re.findall(
        r"^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S+)",
        props, re.M,
    )
    expected_assertions = {
        "thermo5_cdc_end_remaining_harness.a_product_residual_legal",
        "thermo5_cdc_end_remaining_harness.a_source_ready_low_during_internal_reset",
        "thermo5_cdc_end_remaining_harness.a_no_product_protocol_error",
        "thermo5_cdc_end_remaining_harness.a_product_frame_start_aligned",
        "thermo5_cdc_end_remaining_harness.a_end_remaining_false_arm_unreachable",
    }
    expected_covers = {
        "thermo5_cdc_end_remaining_harness.c_target_false_arm",
        "thermo5_cdc_end_remaining_harness.c_target_false_arm_protocol_clean",
        "thermo5_cdc_end_remaining_harness.c_product_frame_start_pop",
        "thermo5_cdc_end_remaining_harness.c_valid_during_internal_source_reset",
        "thermo5_cdc_end_remaining_harness.c_legal_end_arm",
        "thermo5_cdc_end_remaining_harness.c_64beat_packet_end",
        "thermo5_cdc_end_remaining_harness.c_completed_legal_frame",
    }
    observed_assertions = {name: status for status, name in assertions}
    observed_covers = {name: status for status, name in covers}
    blackboxes = re.findall(r"Number of Black-Box Instances\s*=\s*(\d+)", banner)
    setup_clean = not re.search(r":\s+[1-9]\d*\s*$", setup, re.M)
    no_tautology = not re.search(r"Warning-\[SVAC-TAUT-(?:PROPERTY|COVER)\]", banner)
    expected_sets_present = set(observed_assertions) == expected_assertions and set(observed_covers) == expected_covers
    support_covers_hit = all(observed_covers.get(name) == "covered" for name in (
        "thermo5_cdc_end_remaining_harness.c_legal_end_arm",
        "thermo5_cdc_end_remaining_harness.c_product_frame_start_pop",
        "thermo5_cdc_end_remaining_harness.c_valid_during_internal_source_reset",
        "thermo5_cdc_end_remaining_harness.c_64beat_packet_end",
        "thermo5_cdc_end_remaining_harness.c_completed_legal_frame",
    ))
    assertions_proven = all(observed_assertions.get(name) == "proven" for name in expected_assertions)
    target_cover = observed_covers.get("thermo5_cdc_end_remaining_harness.c_target_false_arm")
    clean_target_cover = observed_covers.get(
        "thermo5_cdc_end_remaining_harness.c_target_false_arm_protocol_clean")
    if (run.returncode == 0 and expected_sets_present and setup_clean and blackboxes
            and all(n == "0" for n in blackboxes) and no_tautology and support_covers_hit
            and assertions_proven and target_cover == "uncoverable"):
        status = "PASS_PROVEN_UNREACHABLE"
    elif (run.returncode == 0 and expected_sets_present and target_cover == "covered"
          and observed_assertions.get("thermo5_cdc_end_remaining_harness.a_end_remaining_false_arm_unreachable") == "falsified"
          and setup_clean and blackboxes and all(n == "0" for n in blackboxes)):
        status = ("TARGET_REACHABLE_PROTOCOL_CLEAN" if clean_target_cover == "covered"
                  else "TARGET_REACHABLE_CONTEXT_UNRESOLVED")
    else:
        status = "INCONCLUSIVE_OR_FAIL"
    trace_dir = work / "traces"
    trace_files = []
    if trace_dir.is_dir():
        trace_files = [
            {"path": str(path.relative_to(ROOT)), "sha256": sha256(path),
             "size_bytes": path.stat().st_size}
            for path in sorted(trace_dir.rglob("*")) if path.is_file()
        ]
    summary = {
        "status": status,
        "git_revision": subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
            check=True, stdout=subprocess.PIPE, text=True).stdout.strip(),
        "git_worktree_dirty": bool(subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
            check=True, stdout=subprocess.PIPE, text=True).stdout.strip()),
        "tool": next((line.strip() for line in banner.splitlines() if "Version V-" in line), "UNKNOWN"),
        "argv": argv,
        "exit_code": run.returncode,
        "duration_seconds": round(time.monotonic() - started, 2),
        "scope": "Production 14:8 CDC, Generic FIFO, explicit W=16/FIFO depth=16. Source VALID remains low through the first source-clock cycle after external reset release, then may assert before the internal two-flop reset synchronizer releases; the unconstrained close_quantum input selects packet lengths of positive multiples of 32 accepted beats. Ready-low-during-reset, core protocol error, and frame-start alignment are asserted. Exact 14:8 clock ratio; no SVA assumptions.",
        "assertions": assertions,
        "covers": covers,
        "assumptions": re.findall(r"^\s*\[\s*\d+\]\s+constrained\s+\(non_vacuous\).*? -\s+(\S+)", props, re.M),
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
        "trace_files": trace_files,
    }
    (out / "formal_summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({"status": status, "manifest": str(out / "formal_summary.json")}))
    return 0 if status in {"PASS_PROVEN_UNREACHABLE", "TARGET_REACHABLE_PROTOCOL_CLEAN"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
