#!/usr/bin/env python3
"""Compile once, run a testcase/seed matrix, and summarize UVM results."""

import argparse
import csv
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


class Case:
    def __init__(self, test, seed):
        self.test = test
        self.seed = seed

    @property
    def tag(self):
        safe_test = re.sub(r"[^A-Za-z0-9_.-]", "_", self.test)
        return f"{safe_test}_seed{self.seed}"


def run_command(command, cwd):
    # Keep the controller runnable on Python 3.6 common in Linux EDA setups.
    # text/capture_output were added after Python 3.6.
    return subprocess.run(command, cwd=cwd, universal_newlines=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def parse_uvm_summary(log_text):
    error_matches = re.findall(r"UVM_ERROR\s*:\s*(\d+)", log_text)
    fatal_matches = re.findall(r"UVM_FATAL\s*:\s*(\d+)", log_text)
    errors = int(error_matches[-1]) if error_matches else None
    fatals = int(fatal_matches[-1]) if fatal_matches else None
    return errors, fatals


def run_case(case, args, root):
    command = [
        "make", "-C", "uvm_verif/sim", f"{args.sim}-run-only",
        f"UVM_TESTNAME={case.test}", f"UVM_SEED={case.seed}",
        f"UVM_VERBOSITY={args.verbosity}", f"RUN_TAG={case.tag}",
        f"COVERAGE={int(args.coverage)}", f"FSDB={int(args.fsdb)}",
    ]
    result = run_command(command, root)
    log_path = root / "uvm_verif" / "sim" / "out" / args.sim / "runs" / case.tag / "run.log"
    log_text = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    errors, fatals = parse_uvm_summary(log_text)
    passed = result.returncode == 0 and errors == 0 and fatals == 0
    return {
        "test": case.test,
        "seed": case.seed,
        "tag": case.tag,
        "status": "PASS" if passed else "FAIL",
        "returncode": result.returncode,
        "uvm_error": "MISSING" if errors is None else errors,
        "uvm_fatal": "MISSING" if fatals is None else fatals,
        "log": str(log_path.relative_to(root)),
        "stderr": result.stderr.strip(),
    }


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim", choices=("vcs", "questa"), default="vcs")
    parser.add_argument("--tests", default=("dsm_bp_test,dsm_axi_protocol_test,"
                                             "dsm_performance_bittrue_test,"
                                             "dsm_memory_dpd_bittrue_test,"
                                             "dsm_memory_dpd_safety_test,"
                                             "dsm_control_stress_test,"
                                             "dsm_axis_coverage_test"),
                        help="comma-separated UVM test names")
    parser.add_argument("--seeds", default="1,2,3",
                        help="comma-separated positive integer seeds")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--verbosity", default="UVM_LOW")
    parser.add_argument("--coverage", dest="coverage", action="store_true", default=True)
    parser.add_argument("--no-coverage", dest="coverage", action="store_false")
    parser.add_argument("--fsdb", action="store_true")
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--summary", default="",
                        help="CSV path relative to repository root; defaults to regression_summary.csv")
    return parser.parse_args()


def main():
    args = parse_args()
    root = Path(__file__).resolve().parents[2]
    tests = [item.strip() for item in args.tests.split(",") if item.strip()]
    seeds = [int(item) for item in args.seeds.split(",") if item.strip()]
    cases = [Case(test, seed) for test in tests for seed in seeds]
    if not cases or any(seed <= 0 for seed in seeds):
        raise SystemExit("tests and positive seeds are required")

    if not args.skip_compile:
        compile_result = run_command([
            "make", "-C", "uvm_verif/sim", args.sim,
            f"COVERAGE={int(args.coverage)}", f"FSDB={int(args.fsdb)}",
        ], root)
        if compile_result.returncode:
            sys.stdout.write(compile_result.stdout)
            sys.stderr.write(compile_result.stderr)
            return compile_result.returncode

    results = []
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as executor:
        future_map = {executor.submit(run_case, case, args, root): case for case in cases}
        for future in as_completed(future_map):
            result = future.result()
            results.append(result)
            print(f"{result['status']:4} {result['tag']} errors={result['uvm_error']} "
                  f"fatals={result['uvm_fatal']}")

    results.sort(key=lambda row: (str(row["test"]), int(row["seed"])))
    summary_path = (root / args.summary) if args.summary else (
        root / "uvm_verif" / "sim" / "out" / args.sim / "regression_summary.csv")
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["test", "seed", "tag", "status", "returncode", "uvm_error", "uvm_fatal", "log"]
    with summary_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(results)
    print(f"Summary: {summary_path.relative_to(root)}")
    return 1 if any(row["status"] != "PASS" for row in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
