#!/usr/bin/env python3
"""Replay the frozen AXI-Lite regressions and sweep external gap/stall phases."""
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys

from run_thermo5_product_dpd_matrix import GENERATOR, ROOT, sha256

CONFIGS = {"ef1_axil": 30, "mash11_axil": 32}
SWEEP = ((8, 4, 24), (8, 16, 64), (16, 4, 40), (16, 16, 96),
         (20, 4, 48), (20, 16, 128), (24, 4, 56), (24, 16, 160))
START_DELAYS = range(4, 49, 4)


def old_command(vdb):
    if not vdb.is_dir():
        raise ValueError(f"Missing accepted coverage database {vdb}")
    for log in sorted(vdb.parent.glob("*.log")):
        with log.open(errors="replace") as stream:
            line = stream.readline()
        if line.startswith("Command: "):
            command = shlex.split(line.removeprefix("Command: "))
            if "-cm_dir" in command and Path(command[command.index("-cm_dir") + 1]).resolve() == vdb:
                return command, log.read_text(errors="replace")
    raise ValueError(f"Missing simulator command for {vdb}")


def run_case(config, build, path, vdb, extra=(), vectors=None):
    command, old_log = old_command(vdb)
    path.mkdir(parents=True)
    log = path / "sim.log"
    target = path / "coverage.vdb"
    command[0] = str(build / config / "simv")
    if vectors is not None:
        command = [f"+VEC_DIR={vectors}" if arg.startswith("+VEC_DIR=") else arg for arg in command]
    command[command.index("-cm_dir") + 1] = str(target)
    command[command.index("-l") + 1] = str(log)
    result = subprocess.run(command + list(extra), cwd=ROOT, text=True, capture_output=True)
    output = log.read_text(errors="replace") if log.is_file() else result.stdout
    markers = re.findall(r"\[SKU_PASS\]\s+(\w+PASS)\b", old_log)
    if not markers and "ILLEGAL_FRAME_OBSERVED" in old_log:
        markers = ["ILLEGAL_FRAME_OBSERVED"]
    ok = (result.returncode == 0 and target.is_dir() and bool(markers)
          and all(marker in output for marker in markers)
          and all(re.search(rf"UVM_{level}\s*:\s*0\b", output) for level in ("ERROR", "FATAL")))
    print(config, path.name, "PASS" if ok else "FAIL", flush=True)
    probe = re.search(r"ROUND6_DPD_PROBE full=(\d+) fill=(\d+) fill_bubble=(\d+) target=(\d+)", output)
    return dict(configuration=config, case=path.name, status="PASS" if ok else "FAIL",
                source_vdb=vdb.name, options=list(extra),
                probe=list(map(int, probe.groups())) if probe else None,
                log=str(log.relative_to(ROOT)), vdb=str(target.relative_to(ROOT)),
                log_sha256=sha256(log) if log.is_file() else None)


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--round5", type=Path, required=True)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--urg", type=Path, required=True)
    args = parser.parse_args()
    old, build, out = (p.resolve() for p in (args.round5, args.build, args.out))
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory below runs/")
    prior = json.loads((old / "runs/dsm_v13_round5_arithmetic_urg_v4/summary.json").read_text())
    focus = json.loads((old / "docs/verification/data/dsm-v13-round5-axil-focus/round5_focus_cases.json").read_text())
    jobs = []
    for config, count in CONFIGS.items():
        accepted = [Path(p).resolve() for p in prior["configurations"][config]["test_vdbs"]]
        accepted += [(old / p["vdb"]).resolve() for p in focus if p["configuration"] == config and p["status"] == "PASS"]
        if len(accepted) != count or len(set(accepted)) != count:
            raise ValueError(f"Baseline case count differs for {config}")
        for i, path in enumerate(accepted):
            jobs.append((config, build, out / config / f"baseline_{i:02}", path))
        template = next(p for p in accepted if p.parent.name == "late_commit_stall")
        for beat, gap, hold in SWEEP:
            options = ("+ROUND6_DPD_PROBE", f"+THERMO5_SOURCE_GAP_BEAT={beat}", f"+THERMO5_SOURCE_GAP_CYCLES={gap}",
                       f"+THERMO5_EXTRA_COMMIT_STALL_CYCLES={hold}")
            jobs.append((config, build, out / config / f"gap_{beat}_{gap}_hold_{hold}", template, options))
        for delay in START_DELAYS:
            options = ("+ROUND6_DPD_PROBE", "+THERMO5_SOURCE_GAP_BEAT=20", "+THERMO5_SOURCE_GAP_CYCLES=12",
                       "+THERMO5_EXTRA_COMMIT_STALL_CYCLES=48", f"+THERMO5_COMMIT_STALL_START_DELAY={delay}")
            jobs.append((config, build, out / config / f"stall_start_{delay}", template, options))
        # Start-delay 48 hit the target with a source gap, but that case
        # starved the source. Search the same edge neighborhood with no gap.
        for delay in range(40, 69, 2):
            options = ("+ROUND6_DPD_PROBE", "+THERMO5_EXTRA_COMMIT_STALL_CYCLES=48",
                       f"+THERMO5_COMMIT_STALL_START_DELAY={delay}")
            jobs.append((config, build, out / config / f"continuous_start_{delay}", template, options))
        for delay in (44, 46, 48, 50, 52, 54):
            for gap in (2, 4, 6, 8):
                options = ("+ROUND6_DPD_PROBE", "+THERMO5_SOURCE_GAP_BEAT=20",
                           f"+THERMO5_SOURCE_GAP_CYCLES={gap}", "+THERMO5_EXTRA_COMMIT_STALL_CYCLES=48",
                           f"+THERMO5_COMMIT_STALL_START_DELAY={delay}")
                jobs.append((config, build, out / config / f"short_gap_{gap}_start_{delay}", template, options))
        order, step, mode = (1, 7168, "tidsm") if config == "ef1_axil" else (2, 5120, "mash11")
        for boundary, gain in ((15, -32768), (22, -1), (29, -17357), (43, 32767)):
            vectors = out / "vectors" / config / f"frame_{boundary}"
            vectors.parent.mkdir(parents=True, exist_ok=True)
            command = [
                sys.executable, str(GENERATOR), "--output-dir", str(vectors),
                "--words", "56", "--seed", "956007", "--profile", "extreme",
                "--step", str(step), "--tidsm-order", str(order), "--dsm-mode", mode,
                "--frame-start-words", f"1,{boundary}", "--frame-gains", f"16384,{gain}",
                "--dpd-profile", "custom_1tap", "--dpd-c1-re-q14", "19411",
                "--dpd-c1-im-q14", "747", "--dpd-c3-re-q14", "2277",
                "--dpd-c3-im-q14", "-5227", "--dpd-c5-re-q14", "-349",
                "--dpd-c5-im-q14", "1711",
            ]
            generated = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            (vectors.parent / f"frame_{boundary}.log").write_text(generated.stdout + generated.stderr)
            generated.check_returncode()
            for delay in (40, 48, 56):
                options = ("+ROUND6_DPD_PROBE", "+THERMO5_EXTRA_COMMIT_STALL_CYCLES=48",
                           f"+THERMO5_COMMIT_STALL_START_DELAY={delay}")
                jobs.append((config, build, out / config / f"frame_{boundary}_start_{delay}",
                             template, options, vectors))
        # STOP with an open packet keeps ingress open through TLAST and
        # exercises the documented drain path during the delayed input.
        for delay in range(12, 61, 4):
            options = ("+ROUND6_DPD_PROBE", "+ROUND6_IN_PACKET_STOP",
                       "+THERMO5_SOURCE_GAP_BEAT=20", "+THERMO5_SOURCE_GAP_CYCLES=12",
                       "+THERMO5_EXTRA_COMMIT_STALL_CYCLES=48",
                       f"+THERMO5_COMMIT_STALL_START_DELAY={delay}")
            jobs.append((config, build, out / config / f"drain_start_{delay}", template, options))
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(lambda job: run_case(*job), jobs))
    (out / "cases.json").write_text(json.dumps(rows, indent=2) + "\n")
    for config in CONFIGS:
        accepted = [r for r in rows if r["configuration"] == config and r["case"].startswith("baseline")]
        if not all(r["status"] == "PASS" for r in accepted):
            raise SystemExit(f"Baseline replay failed: {config}")
        for label in ("baseline", "cumulative"):
            vdbs = [str(ROOT / r["vdb"]) for r in rows if r["configuration"] == config
                    and r["status"] == "PASS" and (label == "cumulative" or r in accepted)]
            report = out / label / config
            command = [str(args.urg), "-full64", "-dir", str(build / config / "simv.vdb"), *vdbs,
                       "-report", str(report), "-dbname", f"r6_{label}_{config}"]
            merge = subprocess.run(command, cwd=out, text=True, capture_output=True)
            output = merge.stdout + merge.stderr
            (out / f"{label}_{config}.log").write_text(output)
            if (merge.returncode or not (report / "hierarchy.html").exists()
                    or re.search(r"UCAPI-MAP|checksum.*mismatch|incompatible.*(test|database)", output, re.I)):
                raise RuntimeError(f"URG did not produce compatible output: {report}")


if __name__ == "__main__":
    main()
