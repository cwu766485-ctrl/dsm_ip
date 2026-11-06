#!/usr/bin/env python3.12
"""Qualify the expected-underflow path on the frozen AXI-Lite TX product."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv/uvm/sim"
PY_DIR = ROOT / "dv/uvm/refmodel/python"
VECTORS = ROOT / "runs/uvm_thermo5_i2_d1/vectors"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], env: dict[str, str], log: Path) -> str:
    result = subprocess.run(command, cwd=ROOT, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False)
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(result.stdout, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"exit {result.returncode}: {shlex.join(command)}\n" +
                           "\n".join(result.stdout.splitlines()[-60:]))
    return result.stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=1060001)
    parser.add_argument("--vcs-home", default=os.environ.get(
        "VCS_HOME", "/opt/Synopsys/vcs/V-2023.12-SP1"))
    args = parser.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("--out-dir must be a new directory below runs/")
    if not VECTORS.is_dir():
        parser.error(f"missing bit-true vectors: {VECTORS}")

    env = os.environ.copy()
    env["VCS_HOME"] = args.vcs_home
    env["PATH"] = str(Path(args.vcs_home) / "bin") + os.pathsep + env.get("PATH", "")
    env["PYTHONPATH"] = str(PY_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    out.mkdir(parents=True)
    build = out / "build"
    compile_command = [
        "make", "-C", str(SIM_DIR), "thermo5-vcs", "PYTHON=python3.12",
        "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
        "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
        "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
        "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
        "THERMO5_VECTORS=" + str(VECTORS), "THERMO5_OUT=" + str(build),
    ]
    run(compile_command, env, out / "logs/compile.log")
    simv = build / "simv"
    if not simv.is_file():
        raise RuntimeError("VCS compile did not produce simv")

    trace = out / "starvation_trace.jsonl"
    uvm_log = out / "logs/starvation_uvm.log"
    vdb = out / "starvation.vdb"
    sim_command = [
        str(simv), "+UVM_TESTNAME=thermo5_sku_axil_starvation_test",
        "+UVM_VERBOSITY=UVM_LOW", "+VEC_DIR=" + str(VECTORS),
        "+ntb_random_seed=" + str(args.seed), "+CORE_WORDS=56",
        "+THERMO5_TRACE_JSONL=" + str(trace), "-cm",
        "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb),
        "-l", str(uvm_log),
    ]
    sim_output = run(sim_command, env, out / "logs/starvation_stdout.log")
    uvm_text = uvm_log.read_text(encoding="utf-8", errors="replace")
    if ("THERMO5_AXIL_STARVATION_PASS" not in uvm_text or
            "UVM_ERROR :    0" not in uvm_text or "UVM_FATAL :    0" not in uvm_text):
        raise RuntimeError("UVM expected-starvation checker did not pass cleanly")
    if not vdb.is_dir() or not trace.is_file():
        raise RuntimeError("VCS run omitted the expected VDB or monitor trace")

    oracle = run([
        sys.executable, str(PY_DIR / "check_thermo5_monitor_trace.py"),
        str(trace), "--allow-underflow", "--step", "5120",
        "--tidsm-order", "2", "--max-taps", "1",
    ], env, out / "logs/starvation_oracle.log")
    if ("TRACE_ORACLE=PASS total_words=56 underflow_events=1" not in oracle or
            "TRACE_CLASSIFICATION=DATA_PASS_UNDERFLOW_REQUIRES_EXTERNAL_CLASSIFICATION" not in oracle):
        raise RuntimeError("Python trace oracle did not observe the exact expected starvation outcome")

    urg = Path(args.vcs_home) / "bin/urg"
    report = out / "starvation_urg"
    urg_command = [str(urg), "-full64", "-dir", str(build / "simv.vdb"),
                   str(vdb), "-format", "both", "-report", str(report),
                   "-dbname", "thermo5_axil_starvation", "-log",
                   str(out / "logs/starvation_urg.log")]
    run(urg_command, env, out / "logs/starvation_urg_stdout.log")
    if not (report / "groups.html").is_file():
        raise RuntimeError("URG did not write the starvation functional report")
    # Verify the exact functional bin in both the covergroup-type and monitor
    # instance views; the directed test itself also checks the DUT event and
    # all 56 PA words through the independent scoreboard and trace oracle.
    import html
    sys.path.insert(0, str(ROOT / "tools/hw"))
    from thermo5_tx_functional_bin_detail import GROUP_LINK, parse_table_rows
    group_html = (report / "groups.html").read_text(encoding="utf-8", errors="replace")
    group_links = [(filename, html.unescape(scope).strip())
                   for filename, scope in GROUP_LINK.findall(group_html)]
    if not group_links:
        raise RuntimeError("Could not identify URG functional groups")
    underflow_rows = []
    for group_file, scope in group_links:
        if not (scope.endswith("::core_cg") or scope.endswith(".core_cg")):
            continue
        page = (report / group_file).read_text(encoding="utf-8", errors="replace")
        anchors = list(re.finditer(
            r'<a name="inst_tag_([^\"]+)\.cp_underflow"></a>', page))
        for index, match in enumerate(anchors):
            view = match.group(1)
            start = match.start()
            end = anchors[index + 1].start() if index + 1 < len(anchors) else len(page)
            section = page[start:end if end >= 0 else len(page)]
            table = re.search(
                r"<span class=repname>User Defined Bins for cp_underflow</span>.*?"
                r"<span class=repname>Bins</span>.*?<table\b[^>]*>(.*?)</table>",
                section, re.I | re.S)
            if not table:
                raise RuntimeError(f"Missing cp_underflow bin table for {view}")
            _, bins = parse_table_rows("<table>" + table.group(1) + "</table>")
            empty = next((row for row in bins if row.get("NAME") == "empty"), None)
            if empty is None or int(empty["COUNT"]) < 1:
                raise RuntimeError(f"The empty bin was not hit for {view}")
            underflow_rows.append({"scope": view, "hits": int(empty["COUNT"]),
                                   "status": "COVERED"})
    if len(underflow_rows) != 2:
        raise RuntimeError(f"Expected exactly two covered applicable starvation bins, got {underflow_rows}")

    summary = {
        "schema_version": 1,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source_git_sha": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "worktree_dirty": bool(subprocess.check_output(
            ["git", "status", "--porcelain=v1"], cwd=ROOT, text=True).strip()),
        "configuration": {
            "interpolation": "Centered-Cubic x2+x2", "ef2_order": 2,
            "step": 5120, "state_bits": 20, "dpd_max_taps": 1,
            "reset_image": "Identity", "fifo": "Generic", "control": "AXI-Lite",
        },
        "classification": "EXPECTED_STARVATION_SEPARATE_FROM_NORMAL_STREAM_REGRESSION",
        "seed": args.seed,
        "expected": {"source_beats": 32, "accepted_tlast": 1,
                     "bittrue_pa_words": 56, "protocol_errors": 0,
                     "underflow_events": 1},
        "observed": {"uvm_pass_marker": "THERMO5_AXIL_STARVATION_PASS",
                     "python_oracle": oracle.strip().splitlines(),
                     "vdb": str(vdb.relative_to(ROOT)),
                     "vdb_file_count": sum(p.is_file() for p in vdb.rglob("*")),
                     "functional_underflow_bin_views": underflow_rows},
        "compile_command": shlex.join(compile_command),
        "simulation_command": shlex.join(sim_command),
        "urg_command": shlex.join(urg_command),
        "logs": {},
        "tool_versions": {"python": sys.version.split()[0],
                          "vcs_home": args.vcs_home},
        "status": "PASS",
    }
    for name, path in (("compile", out / "logs/compile.log"),
                       ("vcs_build", build / "compile.log"),
                       ("uvm", uvm_log),
                       ("simulation_stdout", out / "logs/starvation_stdout.log"),
                       ("oracle", out / "logs/starvation_oracle.log"),
                       ("urg", out / "logs/starvation_urg.log"),
                       ("trace", trace)):
        summary["logs"][name] = {"path": str(path.relative_to(ROOT)),
                                 "sha256": sha256(path), "bytes": path.stat().st_size}
    summary_path = out / "summary.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    print(f"THERMO5_AXIL_STARVATION=PASS summary={summary_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
