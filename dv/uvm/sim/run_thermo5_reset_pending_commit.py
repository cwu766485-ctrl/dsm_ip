#!/usr/bin/env python3
"""Run legal pending-COMMIT reset recovery scenarios on the product TX path."""

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
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
TRACE_CHECKER = ROOT / "dv" / "uvm" / "refmodel" / "python" / "check_thermo5_monitor_trace.py"
TEST_NAME = "thermo5_sku_axil_reset_pending_commit_test"
PREFIXES = (1, 3, 5, 7, 8, 10, 12, 15)
COEFFICIENTS = (12288, 20480)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def fingerprint(path: Path) -> dict:
    digest = hashlib.sha256()
    files = size = 0
    for item in sorted(child for child in path.rglob("*") if child.is_file()):
        rel = item.relative_to(path).as_posix()
        count = item.stat().st_size
        digest.update(rel.encode() + b"\0" + str(count).encode() + b"\0" + sha256(item).encode() + b"\n")
        files += 1
        size += count
    return {"path": str(path.resolve()), "file_count": files,
            "size_bytes": size, "tree_sha256": digest.hexdigest()}


def run(command, *, cwd: Path, env: dict, log_path: Path) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError("command failed (%d): %s\n%s" % (
            result.returncode, shlex.join(map(str, command)),
            "\n".join(result.stdout.splitlines()[-60:])))
    return result.stdout


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "thermo5_tx_reset_pending_commit")
    parser.add_argument("--seed-base", type=int, default=940000)
    parser.add_argument("--limit", type=int,
                        help="development-only prefix of the deterministic 8-run matrix")
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    args = parser.parse_args()
    if args.limit is not None and not 1 <= args.limit <= len(PREFIXES):
        parser.error("--limit must be in [1, 8]")

    count = args.limit or len(PREFIXES)
    out = args.out.resolve()
    build = out / "build"
    vectors = ROOT / "runs" / "uvm_thermo5_i2_d1" / "vectors"
    logs, traces, vdbs = out / "logs", out / "traces", out / "vdb"
    for path in (logs, traces, vdbs):
        path.mkdir(parents=True, exist_ok=True)
    if not (vectors / "tid32_thermo5_frontend_pa3.mem").is_file():
        raise SystemExit("product Identity vectors are missing; generate the frozen default vectors first")

    env = os.environ.copy()
    vcs_home = env.get("VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1")
    env["VCS_HOME"] = vcs_home
    env["PATH"] = str(Path(vcs_home) / "bin") + os.pathsep + env.get("PATH", "")
    env["PYTHONPATH"] = str(ROOT / "dv/uvm/refmodel/python") + os.pathsep + env.get("PYTHONPATH", "")
    urg = Path(vcs_home) / "bin" / "urg"
    if not urg.is_file():
        raise SystemExit("URG not found below VCS_HOME")

    compile_command = [
        "make", "-C", str(SIM_DIR), "thermo5-vcs", "PYTHON=python3.12",
        "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
        "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
        "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
        "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
        "THERMO5_VECTORS=" + str(vectors), "THERMO5_OUT=" + str(build),
    ]
    if not args.skip_compile:
        run(compile_command, cwd=ROOT, env=env, log_path=logs / "compile.log")
    simv = build / "simv"
    if not simv.is_file():
        raise SystemExit("VCS simulation binary is missing: %s" % simv)

    results = []
    for index in range(count):
        seed = args.seed_base + index
        prefix = PREFIXES[index]
        coeff = COEFFICIENTS[index % len(COEFFICIENTS)]
        trace = traces / ("seed_%d.jsonl" % seed)
        uvm_log = logs / ("seed_%d.log" % seed)
        stdout_log = logs / ("seed_%d.stdout.log" % seed)
        oracle_log = logs / ("seed_%d_oracle.log" % seed)
        vdb = vdbs / ("seed_%d.vdb" % seed)
        sim_command = [
            str(simv), "+UVM_TESTNAME=" + TEST_NAME, "+UVM_VERBOSITY=UVM_LOW",
            "+VEC_DIR=" + str(vectors), "+ntb_random_seed=" + str(seed),
            "+CORE_WORDS=56", "+THERMO5_RESET_PREFIX_BEATS=" + str(prefix),
            "+THERMO5_PENDING_C1_RE_Q14=" + str(coeff),
            "+THERMO5_TRACE_JSONL=" + str(trace),
            "-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb),
            "-l", str(uvm_log),
        ]
        run(sim_command, cwd=ROOT, env=env, log_path=stdout_log)
        text = uvm_log.read_text(encoding="utf-8", errors="replace")
        marker = "THERMO5_AXIL_RESET_PENDING_COMMIT_UVM_PASS"
        if marker not in text:
            raise RuntimeError("UVM pass marker missing for reset seed %d" % seed)
        oracle_command = [
            sys.executable, str(TRACE_CHECKER), str(trace), "--step", "5120",
            "--tidsm-order", "2", "--max-taps", "1",
        ]
        oracle = run(oracle_command, cwd=ROOT, env=env, log_path=oracle_log)
        if "TRACE_ORACLE=PASS" not in oracle or "PASS_NO_UNDERFLOW" not in oracle:
            raise RuntimeError("independent reset-epoch oracle failed for seed %d" % seed)
        results.append({
            "seed": seed, "prefix_beats": prefix,
            "prefix_class": "short" if prefix < 8 else "long",
            "pending_c1_re_q14": coeff,
            "pending_coeff_class": "attenuate" if coeff < 16384 else "boost",
            "trace": str(trace.relative_to(ROOT)), "trace_sha256": sha256(trace),
            "uvm_log": str(uvm_log.relative_to(ROOT)), "uvm_log_sha256": sha256(uvm_log),
            "oracle_log": str(oracle_log.relative_to(ROOT)), "oracle_log_sha256": sha256(oracle_log),
            "vdb": str(vdb.relative_to(ROOT)), "vdb_fingerprint": fingerprint(vdb),
            "pass": True,
        })

    observed = {(row["prefix_class"], row["pending_coeff_class"])
                for row in results}
    expected = {(prefix, coeff) for prefix in ("short", "long")
                for coeff in ("attenuate", "boost")}
    if count == 8 and observed != expected:
        raise RuntimeError("reset cross matrix did not hit all prefix x pending coefficient classes")

    report = out / "urg_dut_product"
    urg_command = [str(urg), "-full64", "-dir", str(build / "simv.vdb")] + [
        str(vdbs / ("seed_%d.vdb" % row["seed"])) for row in results
    ] + ["-format", "both", "-show", "ratios", "-report", str(report),
         "-dbname", "thermo5_tx_reset_pending_commit", "-log", str(out / "urg_merge.log")]
    if not args.skip_urg:
        run(urg_command, cwd=ROOT, env=env, log_path=logs / "urg.stdout.log")
    reset_cross = cross_counts(report, "x_reset_pending_config")
    if reset_cross != (4, 0, 4):
        raise RuntimeError("URG did not report 4/4 Reset/pending-config bins: %s" %
                           (reset_cross,))

    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "git_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "configuration": {"centered_cubic": True, "tidsm_order": 2, "step": 5120,
                          "state_bits": 20, "dpd_max_taps": 1,
                          "reset_image": "Identity", "fifo": "Generic", "control": "AXI-Lite"},
        "matrix": {"cases_run": len(results), "expected_cross_bins": 4,
                   "observed_cross_bins": len(observed),
                   "urg_cross_expected_uncovered_covered": list(reset_cross),
                   "full_matrix": count == 8 and observed == expected},
        "results": results,
        "compile_command": shlex.join(compile_command),
        "urg_command": shlex.join(urg_command),
        "tools": {"python": sys.version.split()[0], "vcs_home": vcs_home},
        "urg_report": str(report.relative_to(ROOT)),
    }
    summary = out / "summary.json"
    summary.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("THERMO5_RESET_PENDING_COMMIT=%s cases=%d cross_bins=%d summary=%s" % (
        "PASS" if count == 8 and observed == expected else "PARTIAL",
        len(results), len(observed), summary))
    return 0 if count == 8 and observed == expected else 3


if __name__ == "__main__":
    raise SystemExit(main())
