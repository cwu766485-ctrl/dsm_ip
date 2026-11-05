#!/usr/bin/env python3
"""Run pre-RUN and post-boundary COMMIT scenarios with real PA backpressure."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from thermo5_urg_utils import cross_counts


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv/uvm/sim"
PY_DIR = ROOT / "dv/uvm/refmodel/python"
TRACE_CHECKER = PY_DIR / "check_thermo5_monitor_trace.py"
VECTOR_GENERATOR = PY_DIR / "generate_thermo5_frontend_vectors.py"
TEST_NAME = "thermo5_sku_axil_random_dpd_bittrue_test"
TIMING_CASES = ((0, "before_run"), (1, "after_first_boundary"))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fingerprint(path: Path) -> dict:
    digest = hashlib.sha256()
    count = size = 0
    for item in sorted(child for child in path.rglob("*") if child.is_file()):
        rel = item.relative_to(path).as_posix()
        nbytes = item.stat().st_size
        digest.update(rel.encode() + b"\0" + str(nbytes).encode() + b"\0" +
                      sha256(item).encode() + b"\n")
        count += 1
        size += nbytes
    return {"file_count": count, "size_bytes": size,
            "tree_sha256": digest.hexdigest()}


def run(command, *, cwd: Path, env: dict, log_path: Path) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError("command failed (%d): %s\n%s" % (
            result.returncode, shlex.join(map(str, command)),
            "\n".join(result.stdout.splitlines()[-60:])))
    return result.stdout


def read_events(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs/thermo5_tx_closure_current/commit_boundary_stall")
    parser.add_argument("--seed-base", type=int, default=950000)
    args = parser.parse_args()

    out = args.out.resolve()
    build = out / "build"
    vectors = out / "vectors/identity_ef2"
    logs, traces, vdbs = out / "logs", out / "traces", out / "vdb"
    for path in (logs, traces, vdbs):
        path.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    vcs_home = env.get("VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1")
    env["VCS_HOME"] = vcs_home
    env["PATH"] = str(Path(vcs_home) / "bin") + os.pathsep + env.get("PATH", "")
    env["PYTHONPATH"] = str(PY_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    urg = Path(vcs_home) / "bin/urg"
    if not urg.is_file():
        raise SystemExit("URG not found below VCS_HOME")

    vector_command = [
        sys.executable, str(VECTOR_GENERATOR), "--output-dir", str(vectors),
        "--words", "56", "--seed", str(args.seed_base ^ 0x54483544),
        "--profile", "random", "--interp-mode", "centered_cubic",
        "--dpd-profile", "identity", "--step", "5120", "--tidsm-order", "2",
        "--frame-start-words", "1,15,36", "--frame-gains", "16384,16384,16384",
    ]
    vector_output = run(vector_command, cwd=ROOT, env=env,
                        log_path=logs / "vector_generation.log")
    if "THERMO5_PYTHON_VECTORS=PASS" not in vector_output:
        raise RuntimeError("Python did not produce online EF2 reference vectors")

    compile_command = [
        "make", "-C", str(SIM_DIR), "thermo5-vcs", "PYTHON=python3.12",
        "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
        "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
        "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
        "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
        "THERMO5_VECTORS=" + str(vectors), "THERMO5_OUT=" + str(build),
    ]
    compile_log = run(compile_command, cwd=ROOT, env=env,
                      log_path=logs / "compile.log")
    simv = build / "simv"
    if not simv.is_file():
        raise RuntimeError("VCS compile returned success without a simv binary")

    results = []
    for case_index, (timing_id, timing_name) in enumerate(TIMING_CASES):
        seed = args.seed_base + case_index
        trace = traces / ("seed_%d.jsonl" % seed)
        uvm_log = logs / ("seed_%d.log" % seed)
        stdout_log = logs / ("seed_%d.stdout.log" % seed)
        oracle_log = logs / ("seed_%d_oracle.log" % seed)
        vdb = vdbs / ("seed_%d.vdb" % seed)
        command = [
            str(simv), "+UVM_TESTNAME=" + TEST_NAME,
            "+UVM_VERBOSITY=UVM_LOW", "+VEC_DIR=" + str(vectors),
            "+ntb_random_seed=" + str(seed), "+CORE_WORDS=56",
            "+THERMO5_EXPECT_FRAME_STARTS=3",
            "+THERMO5_DPD_C1_RE_Q14=16384", "+THERMO5_DPD_C1_IM_Q14=0",
            "+THERMO5_GAIN_CLASS_ID=1", "+THERMO5_INPUT_PROFILE_ID=0",
            "+THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL",
            "+THERMO5_TRACE_JSONL=" + str(trace),
        ]
        if timing_id:
            command.append("+THERMO5_COMMIT_AFTER_FIRST_BOUNDARY")
        command += ["-cm", "line+cond+fsm+tgl+branch+assert",
                    "-cm_dir", str(vdb), "-l", str(uvm_log)]
        run(command, cwd=ROOT, env=env, log_path=stdout_log)
        uvm_text = uvm_log.read_text(encoding="utf-8", errors="replace")
        if "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS" not in uvm_text:
            raise RuntimeError("UVM pass marker absent for %s" % timing_name)
        if "UVM_ERROR :    0" not in uvm_text or "UVM_FATAL :    0" not in uvm_text:
            raise RuntimeError("UVM reported errors/fatals for %s" % timing_name)

        oracle_command = [sys.executable, str(TRACE_CHECKER), str(trace),
                          "--step", "5120", "--tidsm-order", "2", "--max-taps", "1"]
        oracle = run(oracle_command, cwd=ROOT, env=env, log_path=oracle_log)
        if "TRACE_ORACLE=PASS" not in oracle or "PASS_NO_UNDERFLOW" not in oracle:
            raise RuntimeError("Trace oracle failed for %s" % timing_name)
        events = read_events(trace)
        commits = [event for event in events if event.get("type") == "axil_write_fire" and
                   int(event.get("addr", "0"), 0) == 0 and
                   int(event.get("data", "0"), 0) & 2]
        pending = [event for event in events if event.get("type") == "config_pending"]
        boundaries = [event for event in events if event.get("type") == "frame_boundary"]
        stalls = [event for event in events if event.get("type") == "pa_stall"]
        if not commits or not pending or not boundaries or not stalls:
            raise RuntimeError("Missing DUT event in commit/boundary/stall scenario %s" % timing_name)
        pending_seq = min(event["seq"] for event in pending)
        if not any(event["seq"] > pending_seq and event.get("config_pending") is True
                   for event in boundaries):
            raise RuntimeError("No frame boundary observed with the committed configuration pending")
        if timing_id and not any(event["seq"] < min(item["seq"] for item in commits)
                                 for event in boundaries):
            raise RuntimeError("Post-boundary schedule lacks an earlier frame-boundary witness")
        results.append({
            "seed": seed, "commit_timing": timing_name,
            "commit_events": len(commits), "pending_events": len(pending),
            "frame_boundaries": len(boundaries), "pa_stall_events": len(stalls),
            "trace": str(trace.relative_to(ROOT)), "trace_sha256": sha256(trace),
            "uvm_log": str(uvm_log.relative_to(ROOT)), "uvm_log_sha256": sha256(uvm_log),
            "oracle_log": str(oracle_log.relative_to(ROOT)), "oracle_log_sha256": sha256(oracle_log),
            "vdb": str(vdb.relative_to(ROOT)), "vdb_fingerprint": fingerprint(vdb),
            "pass": True,
        })

    urg_report = out / "urg_dut_product"
    urg_command = [str(urg), "-full64", "-dir", str(build / "simv.vdb"),
                   *[str(vdbs / ("seed_%d.vdb" % row["seed"])) for row in results],
                   "-format", "both", "-show", "ratios", "-report", str(urg_report),
                   "-dbname", "thermo5_tx_commit_boundary_stall", "-log", str(out / "urg_merge.log")]
    run(urg_command, cwd=ROOT, env=env, log_path=out / "urg.stdout.log")
    commit_cross = cross_counts(urg_report, "x_commit_boundary_stall")
    status_cross = cross_counts(urg_report, "x_status_commit_stop")
    if commit_cross != (2, 0, 2) or status_cross != (1, 0, 1):
        raise RuntimeError("URG did not close exact commit/status cross bins: commit=%s status=%s" %
                           (commit_cross, status_cross))
    summary = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "git_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "configuration": {"interpolation": "Centered-Cubic x2+x2", "ef2_order": 2,
                          "step": 5120, "state_bits": 20, "dpd_max_taps": 1,
                          "dpd_image": "Identity-equivalent legal 1-tap", "fifo": "Generic",
                          "control": "AXI-Lite"},
        "functional_cross": {"name": "commit_timing x applied_frame_boundary x PA_stall",
                              "expected_bins": 2, "observed_timing_classes": len(results),
                              "urg_expected_uncovered_covered": list(commit_cross),
                              "status_commit_stop_expected_uncovered_covered": list(status_cross),
                              "all_bins_closed": len(results) == 2},
        "results": results, "compile_command": shlex.join(compile_command),
        "urg_command": shlex.join(urg_command),
        "compile_log_sha256": sha256(logs / "compile.log"),
        "vector_generation_command": shlex.join(vector_command),
        "vector_generation_log_sha256": sha256(logs / "vector_generation.log"),
        "vector_directory": str(vectors.relative_to(ROOT)),
        "urg_report": str(urg_report.relative_to(ROOT)),
        "tool_versions": {"python": sys.version.split()[0], "vcs_home": vcs_home},
    }
    summary_path = out / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                             encoding="utf-8")
    print("THERMO5_COMMIT_BOUNDARY_STALL=%s scenarios=%d summary=%s" % (
        "PASS" if len(results) == 2 else "PARTIAL", len(results), summary_path))
    return 0 if len(results) == 2 else 3


if __name__ == "__main__":
    raise SystemExit(main())
