#!/usr/bin/env python3
"""Replay two aligned packets on both AXI-Lite products with varied RUN timing."""
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import subprocess
import sys

from run_dsm_v13_round6_product import ROOT, GENERATOR, sha256


CONFIGS = {"ef1_axil": (1, 7168, "tidsm"), "mash11_axil": (2, 5120, "mash11")}
PHASES = ((0, 0), (1, 0), (2, 1), (4, 2), (6, 3), (8, 5))


def replay(build, out, sku, run_delay, source_delay):
    directory = out / sku / f"run{run_delay}_source{source_delay}"
    directory.mkdir()
    log = directory / "sim.log"
    vdb = directory / "coverage.vdb"
    command = [
        str(build / sku / "simv"), "+UVM_TESTNAME=thermo5_sku_axil_frame_replacement_test",
        f"+VEC_DIR={out / sku / 'vectors'}", "+ntb_random_seed=420113",
        "+CORE_WORDS=112", "+PACKET_BEATS=32",
        f"+THERMO5_RUN_PHASE_CYCLES={run_delay}",
        f"+THERMO5_SOURCE_START_DELAY_CYCLES={source_delay}",
        "-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb), "-l", str(log),
    ]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    output = log.read_text(errors="replace") if log.is_file() else result.stdout + result.stderr
    expected = re.search(
        r"THERMO5_AXIL_FRAME_REPLACEMENT_UVM_PASS stage1=(\d+) stage2=(\d+) "
        r"source=64 output=112 four_planes=bittrue", output,
    )
    passed = result.returncode == 0 and vdb.is_dir() and expected and all(
        re.search(rf"UVM_{level}\s*:\s*0\b", output) for level in ("ERROR", "FATAL")
    )
    print(sku, directory.name, "PASS" if passed else "FAIL", flush=True)
    return dict(configuration=sku, case=directory.name, status="PASS" if passed else "FAIL",
                hits=list(map(int, expected.groups())) if expected else None,
                log_sha256=sha256(log) if log.is_file() else None,
                vdb=str(vdb.relative_to(out)))


def main():
    parser = ArgumentParser(description=__doc__)
    for name in ("build", "baseline", "out", "urg"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    build, baseline, out, urg = (p.resolve() for p in
                                 (args.build, args.baseline, args.out, args.urg))
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory below runs/")
    for sku, (order, step, mode) in CONFIGS.items():
        (out / sku).mkdir(parents=True)
        command = [
            sys.executable, str(GENERATOR), "--output-dir", str(out / sku / "vectors"),
            "--words", "112", "--seed", "420113", "--profile", "extreme",
            "--step", str(step), "--tidsm-order", str(order), "--dsm-mode", mode,
            "--frame-start-words", "1,57", "--frame-gains", "16384,16384",
            "--dpd-profile", "identity",
        ]
        subprocess.run(command, cwd=ROOT, check=True)
    jobs = [(build, out, sku, *phase) for sku in CONFIGS for phase in PHASES]
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda job: replay(*job), jobs))
    (out / "cases.json").write_text(json.dumps(rows, indent=2) + "\n")
    for sku in CONFIGS:
        vdbs = [str(out / row["vdb"]) for row in rows
                if row["configuration"] == sku and row["status"] == "PASS"]
        report = out / "cumulative" / sku
        original = baseline / f"r6_cumulative_{sku}.vdb"
        if not vdbs or not original.is_dir():
            raise RuntimeError(f"Missing baseline or accepted VDBs for {sku}")
        command = [str(urg), "-full64", "-dir", str(original), *vdbs,
                   "-report", str(report), "-dbname", f"v14_cumulative_{sku}"]
        result = subprocess.run(command, cwd=out, capture_output=True, text=True)
        output = result.stdout + result.stderr
        (out / f"urg_{sku}.log").write_text(output)
        if (result.returncode or not (report / "hierarchy.html").is_file()
                or re.search(r"UCAPI-MAP|checksum.*mismatch|incompatible.*(test|database)", output, re.I)):
            raise RuntimeError(f"URG did not produce compatible output: {report}")


if __name__ == "__main__":
    main()
