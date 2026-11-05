#!/usr/bin/env python3
"""Run a replayable one-tap C1/C3/C5 product-DPD/gain/profile matrix.

This flow never changes the product reset image. Every run explicitly writes a
legal one-tap coefficient image through AXI-Lite and compares the accepted
four-plane PA stream against both the static vector files and the independent trace
oracle. VCS code coverage is restricted to the elaborated DUT hierarchy.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
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
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
PY_DIR = ROOT / "dv" / "uvm" / "refmodel" / "python"
GENERATOR = PY_DIR / "generate_thermo5_frontend_vectors.py"
TRACE_CHECKER = PY_DIR / "check_thermo5_monitor_trace.py"
TEST_NAME = "thermo5_sku_axil_random_dpd_bittrue_test"
DPD_CLASSES = ("attenuation", "identity", "boost", "cubic", "quintic")
GAIN_CLASSES = {"low": 8192, "nominal": 16384, "high": 20480}
PROFILES = ("random", "extreme", "range_stress", "ef2_saturation")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_fingerprint(path: Path) -> dict:
    digest = hashlib.sha256()
    files = 0
    size_bytes = 0
    for item in sorted(child for child in path.rglob("*") if child.is_file()):
        relative = item.relative_to(path).as_posix()
        size = item.stat().st_size
        file_sha = sha256(item)
        digest.update(relative.encode() + b"\0" + str(size).encode() + b"\0" + file_sha.encode() + b"\n")
        files += 1
        size_bytes += size
    return {"path": str(path.resolve()), "files": files,
            "size_bytes": size_bytes, "tree_sha256": digest.hexdigest()}


def run(command, *, cwd: Path, env: dict, log_path: Path) -> str:
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        tail = "\n".join(result.stdout.splitlines()[-60:])
        raise RuntimeError("command failed (%d): %s\n%s" % (
            result.returncode, shlex.join(map(str, command)), tail))
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "thermo5_tx_random_dpd_matrix")
    parser.add_argument("--seed-base", type=int, default=930000)
    parser.add_argument("--limit", type=int,
                        help="development-only prefix of the deterministic 60-case matrix")
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    args = parser.parse_args()

    cases = list(itertools.product(DPD_CLASSES, GAIN_CLASSES.items(),
                                   enumerate(PROFILES)))
    if args.limit is not None:
        if args.limit < 1 or args.limit > len(cases):
            parser.error("--limit must be in [1, 60]")
        cases = cases[:args.limit]

    out = args.out.resolve()
    build = out / "build"
    vectors_root = out / "vectors"
    traces_root = out / "traces"
    logs_root = out / "logs"
    vdb_root = out / "vdb"
    for directory in (vectors_root, traces_root, logs_root, vdb_root):
        directory.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    vcs_home = env.get("VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1")
    env["VCS_HOME"] = vcs_home
    env["PATH"] = str(Path(vcs_home) / "bin") + os.pathsep + env.get("PATH", "")
    env["PYTHONPATH"] = str(PY_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    urg = Path(vcs_home) / "bin" / "urg"
    if not urg.is_file():
        raise SystemExit("URG not found below VCS_HOME; set VCS_HOME to the licensed VCS installation")

    compile_command = [
        "make", "-C", str(SIM_DIR), "thermo5-vcs", "PYTHON=python3.12",
        "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
        "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
        "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
        "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
        "THERMO5_VECTORS=" + str(ROOT / "runs/uvm_thermo5_i2_d1/vectors"),
        "THERMO5_OUT=" + str(build),
    ]
    if not args.skip_compile:
        run(compile_command, cwd=ROOT, env=env,
            log_path=logs_root / "compile.log")
    simv = build / "simv"
    if not simv.is_file():
        raise SystemExit("VCS simulation binary not found: %s" % simv)

    results = []
    for index, (dpd_name, (gain_name, gain),
                (profile_id, profile)) in enumerate(cases):
        seed = args.seed_base + index
        coeff_rng = random.Random(seed ^ 0x54483544)
        c3_re = 0
        c5_re = 0
        if dpd_name == "attenuation":
            c1_re = coeff_rng.randint(12288, 16383)
        elif dpd_name == "identity":
            c1_re = 16384
        elif dpd_name == "boost":
            c1_re = coeff_rng.randint(16385, 20480)
        elif dpd_name == "cubic":
            c1_re = 16384
            c3_re = coeff_rng.choice((-1, 1)) * coeff_rng.randint(256, 2048)
        else:
            c1_re = 16384
            c5_re = coeff_rng.choice((-1, 1)) * coeff_rng.randint(1024, 8192)
        case_id = "%s_%s_%s" % (dpd_name, gain_name, profile)
        vector_dir = vectors_root / ("seed_%d" % seed)
        trace = traces_root / ("seed_%d.jsonl" % seed)
        uvm_log = logs_root / ("seed_%d.log" % seed)
        oracle_log = logs_root / ("seed_%d_oracle.log" % seed)
        vdb = vdb_root / ("seed_%d.vdb" % seed)
        generate_command = [
            sys.executable, str(GENERATOR), "--output-dir", str(vector_dir),
            "--words", "56", "--seed", str(seed), "--profile", profile,
            "--interp-mode", "centered_cubic", "--dpd-profile", "custom_1tap",
            "--dpd-c1-re-q14", str(c1_re), "--frame-start-words", "1",
            "--dpd-c3-re-q14", str(c3_re),
            "--dpd-c5-re-q14", str(c5_re),
            "--frame-gains", str(gain), "--tidsm-order", "2", "--step", "5120",
        ]
        run(generate_command, cwd=ROOT, env=env,
            log_path=logs_root / ("seed_%d_vectors.log" % seed))
        sim_command = [
            str(simv), "+UVM_TESTNAME=" + TEST_NAME, "+UVM_VERBOSITY=UVM_LOW",
            "+VEC_DIR=" + str(vector_dir), "+ntb_random_seed=" + str(seed),
            "+CORE_WORDS=56", "+PACKET_BEATS=32",
            "+THERMO5_EXPECT_FRAME_STARTS=1",
            "+THERMO5_DPD_C1_RE_Q14=" + str(c1_re),
            "+THERMO5_DPD_C1_IM_Q14=0",
            "+THERMO5_DPD_C3_RE_Q14=" + str(c3_re),
            "+THERMO5_DPD_C5_RE_Q14=" + str(c5_re),
            "+THERMO5_DPD_CLASS_ID=" + str(DPD_CLASSES.index(dpd_name)),
            "+THERMO5_GAIN_CLASS_ID=" + str(list(GAIN_CLASSES).index(gain_name)),
            "+THERMO5_INPUT_PROFILE_ID=" + str(profile_id),
            "+THERMO5_TRACE_JSONL=" + str(trace),
            "-cm", "line+cond+fsm+tgl+branch+assert",
            "-cm_dir", str(vdb), "-l", str(uvm_log),
        ]
        run(sim_command, cwd=ROOT, env=env, log_path=logs_root / ("seed_%d.stdout.log" % seed))
        sim_text = uvm_log.read_text(encoding="utf-8", errors="replace")
        if "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS" not in sim_text:
            raise RuntimeError("UVM pass marker missing for seed %d" % seed)
        oracle_command = [
            sys.executable, str(TRACE_CHECKER), str(trace), "--step", "5120",
            "--tidsm-order", "2", "--max-taps", "1",
        ]
        oracle_text = run(oracle_command, cwd=ROOT, env=env, log_path=oracle_log)
        if "TRACE_ORACLE=PASS" not in oracle_text or "PASS_NO_UNDERFLOW" not in oracle_text:
            raise RuntimeError("Trace oracle did not close cleanly for seed %d" % seed)
        results.append({
            "case_id": case_id, "seed": seed, "dpd_class": dpd_name,
            "c1_re_q14": c1_re, "c3_re_q14": c3_re,
            "c5_re_q14": c5_re, "gain_class": gain_name,
            "frame_gain_q14": gain, "input_profile": profile,
            "input_profile_id": profile_id,
            "vectors": str(vector_dir.relative_to(ROOT)),
            "vectors_fingerprint": tree_fingerprint(vector_dir),
            "trace": str(trace.relative_to(ROOT)), "trace_sha256": sha256(trace),
            "uvm_log": str(uvm_log.relative_to(ROOT)), "uvm_log_sha256": sha256(uvm_log),
            "oracle_log": str(oracle_log.relative_to(ROOT)), "oracle_log_sha256": sha256(oracle_log),
            "vdb": str(vdb.relative_to(ROOT)), "vdb_fingerprint": tree_fingerprint(vdb),
            "pass": True,
        })

    observed = {(row["dpd_class"], row["gain_class"], row["input_profile"])
                for row in results}
    expected = {(dpd, gain, profile)
                for dpd in DPD_CLASSES for gain in GAIN_CLASSES for profile in PROFILES}
    if len(results) == len(expected) and observed != expected:
        raise RuntimeError("full matrix did not exercise all DPD x gain x profile tuples")

    urg_report = out / "urg_dut_product"
    design_vdb = build / "simv.vdb"
    urg_command = [str(urg), "-full64", "-dir", str(design_vdb)] + [
        str(vdb_root / ("seed_%d.vdb" % row["seed"])) for row in results
    ] + ["-format", "both", "-show", "ratios", "-report", str(urg_report),
         "-dbname", "thermo5_tx_random_dpd_matrix", "-log", str(out / "urg_merge.log")]
    if not args.skip_urg:
        run(urg_command, cwd=ROOT, env=env, log_path=out / "urg.stdout.log")
    dpd_cross = cross_counts(urg_report, "x_dpd_gain_profile")
    if dpd_cross != (len(expected), 0, len(observed)):
        raise RuntimeError("URG cross denominator/hits differ from the observed matrix: %s" %
                           (dpd_cross,))

    manifest = {
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "git_sha": subprocess.check_output(["git", "rev-parse", "HEAD"],
                                            cwd=ROOT, text=True).strip(),
        "configuration": {
            "interpolation": "Centered-Cubic x2 + x2", "tidsm_order": 2,
            "step": 5120, "state_bits": 20, "dpd_max_taps": 1,
            "reset_image": "Identity", "fifo": "Generic", "control": "AXI-Lite",
        },
        "matrix": {"expected_full_tuples": len(expected), "observed_tuples": len(observed),
                   "cases_run": len(results), "full_matrix": len(results) == len(expected) and observed == expected,
                   "urg_cross_expected_uncovered_covered": list(dpd_cross),
                   "non_identity_coefficients_seeded_with": "seed XOR 0x54483544",
                   "polynomial_classes": {
                       "cubic": "C1 unity; nonzero signed C3; C5 zero",
                       "quintic": "C1 unity; C3 zero; nonzero signed C5"},
                   "attenuation_q2_14_range": [12288, 16383],
                   "identity_q2_14": 16384,
                   "boost_q2_14_range": [16385, 20480]},
        "results": results,
        "compile_command": shlex.join(compile_command),
        "urg_command": shlex.join(urg_command),
        "tool_versions": {
            "python": sys.version.split()[0],
            "vcs_home": vcs_home,
            "vcs_version": subprocess.run([str(Path(vcs_home) / "bin" / "vcs"), "-ID"],
                                          text=True, stdout=subprocess.PIPE,
                                          stderr=subprocess.STDOUT, check=False).stdout.splitlines()[:1],
        },
        "urg_report": str(urg_report.relative_to(ROOT)),
    }
    summary = out / "summary.json"
    summary.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                       encoding="utf-8")
    print("THERMO5_PRODUCT_DPD_MATRIX=%s cases=%d tuples=%d summary=%s" % (
        "PASS" if len(results) == len(expected) and observed == expected else "PARTIAL",
        len(results), len(observed), summary))
    return 0 if len(results) == len(expected) and observed == expected else 3


if __name__ == "__main__":
    raise SystemExit(main())
