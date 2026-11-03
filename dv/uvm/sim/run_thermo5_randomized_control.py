#!/usr/bin/env python3.12
"""Run seeded legal reset/COMMIT control trials on the frozen Thermo5 TX SKU."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import shlex
import subprocess
import sys
from datetime import datetime, timezone

from thermo5_urg_utils import cross_counts


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv/uvm/sim"
PY_DIR = ROOT / "dv/uvm/refmodel/python"
VECTORS = ROOT / "runs/uvm_thermo5_i2_d1/vectors"
TRACE_CHECKER = PY_DIR / "check_thermo5_monitor_trace.py"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(path: Path) -> dict:
    digest = hashlib.sha256()
    files = size = 0
    for item in sorted(child for child in path.rglob("*") if child.is_file()):
        relative = item.relative_to(path).as_posix()
        count = item.stat().st_size
        digest.update(relative.encode() + b"\0" + str(count).encode() + b"\0" +
                      sha256(item).encode() + b"\n")
        files += 1
        size += count
    return {"file_count": files, "size_bytes": size,
            "tree_sha256": digest.hexdigest()}


def run(command: list[str], *, env: dict[str, str], log: Path) -> str:
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(
            f"exit {result.returncode}: {shlex.join(command)}\n" +
            "\n".join(result.stdout.splitlines()[-60:]))
    return result.stdout


def check_uvm_pass(log: Path, marker: str) -> None:
    text = log.read_text(encoding="utf-8", errors="replace")
    if marker not in text:
        raise RuntimeError(f"missing UVM pass marker in {log}")
    if "UVM_ERROR :    0" not in text or "UVM_FATAL :    0" not in text:
        raise RuntimeError(f"legal control test reported UVM errors/fatals in {log}")


def check_oracle(trace: Path, log: Path, env: dict[str, str]) -> None:
    output = run([
        sys.executable, str(TRACE_CHECKER), str(trace), "--step", "5120",
        "--tidsm-order", "2", "--max-taps", "1",
    ], env=env, log=log)
    if "TRACE_ORACLE=PASS" not in output or "PASS_NO_UNDERFLOW" not in output:
        raise RuntimeError(f"independent trace oracle failed for {trace}")


def run_reset_case(simv: Path, env: dict[str, str], out: Path,
                   seed: int, prefix: int, coefficient: int) -> dict:
    logs, traces, vdbs = out / "logs", out / "traces", out / "reset_vdb"
    trace = traces / f"reset_{seed}.jsonl"
    uvm_log = logs / f"reset_{seed}.log"
    stdout_log = logs / f"reset_{seed}.stdout.log"
    oracle_log = logs / f"reset_{seed}.oracle.log"
    vdb = vdbs / f"reset_{seed}.vdb"
    command = [
        str(simv), "+UVM_TESTNAME=thermo5_sku_axil_reset_pending_commit_test",
        "+UVM_VERBOSITY=UVM_LOW", "+VEC_DIR=" + str(VECTORS),
        "+ntb_random_seed=" + str(seed), "+CORE_WORDS=56",
        "+THERMO5_RESET_PREFIX_BEATS=" + str(prefix),
        "+THERMO5_PENDING_C1_RE_Q14=" + str(coefficient),
        "+THERMO5_TRACE_JSONL=" + str(trace), "-cm",
        "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb),
        "-l", str(uvm_log),
    ]
    run(command, env=env, log=stdout_log)
    check_uvm_pass(uvm_log, "THERMO5_AXIL_RESET_PENDING_COMMIT_UVM_PASS")
    check_oracle(trace, oracle_log, env)
    return {
        "kind": "reset_pending_commit", "seed": seed,
        "prefix_beats": prefix,
        "prefix_class": "short" if prefix < 8 else "long",
        "pending_c1_re_q14": coefficient,
        "pending_coeff_class": "attenuate" if coefficient < 16384 else "boost",
        "command": shlex.join(command),
        "trace": str(trace.relative_to(ROOT)), "trace_sha256": sha256(trace),
        "uvm_log": str(uvm_log.relative_to(ROOT)), "uvm_log_sha256": sha256(uvm_log),
        "oracle_log": str(oracle_log.relative_to(ROOT)), "oracle_log_sha256": sha256(oracle_log),
        "vdb": str(vdb.relative_to(ROOT)), "vdb_fingerprint": fingerprint(vdb),
        "pass": True,
    }


def run_commit_case(simv: Path, env: dict[str, str], out: Path,
                    seed: int, after_first_boundary: bool) -> dict:
    logs, traces, vdbs = out / "logs", out / "traces", out / "commit_vdb"
    trace = traces / f"commit_{seed}.jsonl"
    uvm_log = logs / f"commit_{seed}.log"
    stdout_log = logs / f"commit_{seed}.stdout.log"
    oracle_log = logs / f"commit_{seed}.oracle.log"
    vdb = vdbs / f"commit_{seed}.vdb"
    command = [
        str(simv), "+UVM_TESTNAME=thermo5_sku_axil_random_dpd_bittrue_test",
        "+UVM_VERBOSITY=UVM_LOW", "+VEC_DIR=" + str(VECTORS),
        "+ntb_random_seed=" + str(seed), "+CORE_WORDS=56",
        "+THERMO5_EXPECT_FRAME_STARTS=3", "+THERMO5_DPD_C1_RE_Q14=16384",
        "+THERMO5_DPD_C1_IM_Q14=0", "+THERMO5_DPD_C3_RE_Q14=0",
        "+THERMO5_DPD_C5_RE_Q14=0", "+THERMO5_GAIN_CLASS_ID=1",
        "+THERMO5_INPUT_PROFILE_ID=0", "+THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL",
        "+THERMO5_TRACE_JSONL=" + str(trace), "-cm",
        "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb),
        "-l", str(uvm_log),
    ]
    if after_first_boundary:
        command.append("+THERMO5_COMMIT_AFTER_FIRST_BOUNDARY")
    run(command, env=env, log=stdout_log)
    check_uvm_pass(uvm_log, "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS")
    check_oracle(trace, oracle_log, env)
    return {
        "kind": "commit_boundary_stall", "seed": seed,
        "commit_timing": "after_first_boundary" if after_first_boundary else "before_run",
        "command": shlex.join(command),
        "trace": str(trace.relative_to(ROOT)), "trace_sha256": sha256(trace),
        "uvm_log": str(uvm_log.relative_to(ROOT)), "uvm_log_sha256": sha256(uvm_log),
        "oracle_log": str(oracle_log.relative_to(ROOT)), "oracle_log_sha256": sha256(oracle_log),
        "vdb": str(vdb.relative_to(ROOT)), "vdb_fingerprint": fingerprint(vdb),
        "pass": True,
    }


def merge_urg(urg: Path, design_vdb: Path, test_vdbs: list[Path],
              report: Path, log: Path, name: str, env: dict[str, str]) -> None:
    run([str(urg), "-full64", "-dir", str(design_vdb),
         *[str(item) for item in test_vdbs], "-format", "both", "-show", "ratios",
         "-report", str(report), "-dbname", name, "-log", str(log)],
        env=env, log=log.with_suffix(".stdout.log"))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed-base", type=int, default=1040000)
    parser.add_argument("--reset-cases", type=int, default=24)
    parser.add_argument("--commit-cases", type=int, default=24)
    parser.add_argument("--schedule-seed", type=int, default=20261103)
    args = parser.parse_args()
    if not 8 <= args.reset_cases <= 128 or not 8 <= args.commit_cases <= 128:
        parser.error("reset/commit case counts must be in [8, 128]")
    if not (VECTORS / "tid32_thermo5_frontend_pa3.mem").is_file():
        parser.error("frozen Identity vectors are missing")

    out = args.out.resolve()
    for folder in (out / "logs", out / "traces", out / "reset_vdb", out / "commit_vdb"):
        folder.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    vcs_home = env.get("VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1")
    env["VCS_HOME"] = vcs_home
    env["PATH"] = str(Path(vcs_home) / "bin") + os.pathsep + env.get("PATH", "")
    env["PYTHONPATH"] = str(PY_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    urg = Path(vcs_home) / "bin/urg"
    if not urg.is_file():
        parser.error(f"URG does not exist below VCS_HOME={vcs_home}")

    build = out / "build"
    compile_command = [
        "make", "-C", str(SIM_DIR), "thermo5-vcs", "PYTHON=python3.12",
        "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
        "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
        "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
        "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
        "THERMO5_VECTORS=" + str(VECTORS), "THERMO5_OUT=" + str(build),
    ]
    run(compile_command, env=env, log=out / "logs/compile.log")
    simv = build / "simv"
    if not simv.is_file():
        raise RuntimeError("VCS compile completed without creating simv")

    schedule = random.Random(args.schedule_seed)
    reset_params = [
        (args.seed_base + index, schedule.randint(1, 15),
         schedule.choice((12288, 20480)))
        for index in range(args.reset_cases)
    ]
    commit_params = [
        (args.seed_base + args.reset_cases + index, bool(schedule.getrandbits(1)))
        for index in range(args.commit_cases)
    ]
    # Require both legal classes in the replayable randomized schedule.
    if {"short" if p < 8 else "long" for _, p, _ in reset_params} != {"short", "long"}:
        raise RuntimeError("seeded reset schedule missed a prefix class")
    if {c for _, c in commit_params} != {False, True}:
        raise RuntimeError("seeded COMMIT schedule missed a timing class")

    results = []
    for seed, prefix, coefficient in reset_params:
        results.append(run_reset_case(simv, env, out, seed, prefix, coefficient))
    for seed, after_boundary in commit_params:
        results.append(run_commit_case(simv, env, out, seed, after_boundary))

    reset_report, commit_report = out / "reset_urg", out / "commit_urg"
    reset_vdbs = [ROOT / row["vdb"] for row in results if row["kind"] == "reset_pending_commit"]
    commit_vdbs = [ROOT / row["vdb"] for row in results if row["kind"] == "commit_boundary_stall"]
    merge_urg(urg, build / "simv.vdb", reset_vdbs, reset_report,
              out / "logs/reset_urg.log", "thermo5_randomized_reset_pending", env)
    merge_urg(urg, build / "simv.vdb", commit_vdbs, commit_report,
              out / "logs/commit_urg.log", "thermo5_randomized_commit_boundary", env)
    reset_cross = cross_counts(reset_report, "x_reset_pending_config")
    commit_cross = cross_counts(commit_report, "x_commit_boundary_stall")
    status_cross = cross_counts(commit_report, "x_status_commit_stop")
    if reset_cross != (4, 0, 4) or commit_cross != (2, 0, 2) or status_cross != (1, 0, 1):
        raise RuntimeError(
            f"random control crosses incomplete: reset={reset_cross}, "
            f"commit={commit_cross}, status={status_cross}")

    summary = {
        "schema_version": 1,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "product_source_sha": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "configuration": {
            "interpolation": "Centered-Cubic x2+x2", "ef2_order": 2,
            "step": 5120, "state_bits": 20, "dpd_max_taps": 1,
            "reset_image": "Identity", "fifo": "Generic", "control": "AXI-Lite",
        },
        "random_schedule": {
            "scheduler": "Python random.Random", "schedule_seed": args.schedule_seed,
            "reset_trials": args.reset_cases, "commit_trials": args.commit_cases,
            "reset_classes": sorted({(row["prefix_class"], row["pending_coeff_class"])
                                      for row in results if row["kind"] == "reset_pending_commit"}),
            "commit_timing_classes": sorted({row["commit_timing"] for row in results
                                              if row["kind"] == "commit_boundary_stall"}),
        },
        "cross_coverage": {
            "reset_prefix_x_pending_coefficient": list(reset_cross),
            "commit_timing_x_boundary_apply_x_pa_stall": list(commit_cross),
            "status_x_commit_x_stop": list(status_cross),
        },
        "compile_command": shlex.join(compile_command),
        "compile_log": str((out / "logs/compile.log").relative_to(ROOT)),
        "compile_log_sha256": sha256(out / "logs/compile.log"),
        "results": results,
        "tool_versions": {"python": sys.version.split()[0], "vcs_home": vcs_home},
        "urg_reports": {"reset": str(reset_report.relative_to(ROOT)),
                        "commit": str(commit_report.relative_to(ROOT))},
        "status": "PASS",
    }
    summary_path = out / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    print(f"THERMO5_RANDOMIZED_CONTROL=PASS reset={args.reset_cases} "
          f"commit={args.commit_cases} summary={summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
