#!/usr/bin/env python3
"""Run the exact COMMIT witness and bounded counter pilots on both V1.4 DUTs."""
from argparse import ArgumentParser
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import subprocess
import sys

from audit_dsm_v13_round6_condition import bins
from run_dsm_v14_frame_replacement import CONFIGS, GENERATOR, ROOT, sha256


CASE_NAMES = ("commit", "sample", "saturation")
COEFFICIENTS = ("c1-re", "c1-im", "c3-re", "c3-im", "c5-re", "c5-im")
BITTRUE_PASS = "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS"
COUNTER_SNAPSHOT = re.compile(r"\[COUNTER_PILOT\] lane=(\d+) samples=(\d+) saturation=(\d+)")


def checked_command(command, log, cwd=ROOT):
    with log.open("w") as stream:
        subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, check=True)
    return log.read_text(errors="replace")


def run_case(build, out, sku, case):
    order, step, mode = CONFIGS[sku]
    path = out / sku / case
    path.mkdir(parents=True)
    vectors = path / "vectors"
    words = 56 if case == "commit" else 8960
    starts = (1, 8, 15) if case == "commit" else tuple(range(1, words + 1, 56))
    gain = 32767 if case == "saturation" else 16384
    coefficients = (32767,) * 6 if case == "saturation" else (16384, 0, 0, 0, 0, 0)
    seed = 956007 if case == "commit" else 961426
    generate = [
        sys.executable, str(GENERATOR), "--output-dir", str(vectors),
        "--words", str(words), "--seed", str(seed), "--profile", "extreme",
        "--step", str(step), "--tidsm-order", str(order), "--dsm-mode", mode,
        "--frame-start-words", ",".join(map(str, starts)),
        "--frame-gains", ",".join([str(gain)] * len(starts)),
        "--dpd-profile", "custom_1tap",
    ]
    for field, value in zip(COEFFICIENTS, coefficients):
        generate.extend((f"--dpd-{field}-q14", str(value)))
    checked_command(generate, path / "vectors.log")
    vdb = path / "coverage.vdb"
    log = path / "sim.log"
    simulation = [
        str(build / sku / "simv"), "+UVM_TESTNAME=thermo5_sku_axil_random_dpd_bittrue_test",
        f"+VEC_DIR={vectors}", f"+ntb_random_seed={seed}", f"+CORE_WORDS={words}",
        "+PACKET_BEATS=32", f"+THERMO5_EXPECT_FRAME_STARTS={len(starts)}",
        "-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb), "-l", str(log),
    ]
    simulation.extend(f"+THERMO5_DPD_{field.replace('-', '_').upper()}_Q14={value}"
                      for field, value in zip(COEFFICIENTS, coefficients))
    if case == "commit":
        simulation.extend((
            "+THERMO5_GAIN_CLASS_ID=1", "+THERMO5_COMMIT_AFTER_FIRST_BOUNDARY",
            "+THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL", "+AXIL_CLOCK_PHASE_PS=2857",
            "+THERMO5_AXIL_PHASE_TRACE", "+THERMO5_LATE_COMMIT_DELAY_CYCLES=4",
        ))
    else:
        simulation.extend(("+THERMO5_COMPLEX_DPD_COVERAGE", "+THERMO5_COUNTER_PILOT"))
    checked_command(simulation, path / "stdout.log")
    output = log.read_text()
    if (not vdb.is_dir() or BITTRUE_PASS not in output or
            any(not re.search(rf"(?m)^UVM_{severity}\s*:\s*0\s*$", output)
                for severity in ("ERROR", "FATAL"))):
        raise RuntimeError(f"{sku}/{case} failed: {log}")
    result = dict(configuration=sku, case=case, words=words, log_sha256=sha256(log),
                  vdb=str(vdb.relative_to(out)))
    if case == "commit":
        result["target_edges"] = output.count("req_sync2=1 pending=0 boundary=1")
        if result["target_edges"] == 0:
            raise RuntimeError(f"{sku} missed its COMMIT target: {log}")
    else:
        snapshots = [tuple(map(int, row)) for row in COUNTER_SNAPSHOT.findall(output)]
        if (sorted(lane for lane, _, _ in snapshots) != list(range(16)) or
                any(samples != words + len(starts) for _, samples, _ in snapshots) or
                any((saturation > 0) != (case == "saturation")
                    for _, _, saturation in snapshots)):
            raise RuntimeError(f"{sku}/{case} has invalid counter snapshots: {log}")
        result["counters"] = snapshots
        result["cpu_seconds"] = float(re.search(r"CPU Time:\s+([\d.]+) seconds", output)[1])
    print(f"{sku}/{case} PASS", flush=True)
    return result


def main():
    parser = ArgumentParser(description=__doc__)
    for name in ("build", "baseline", "out", "urg"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    build, baseline, out, urg = (path.resolve() for path in
                                 (args.build, args.baseline, args.out, args.urg))
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory below runs/")
    for sku in CONFIGS:
        for path in (build / sku / "simv", baseline / f"v14_cumulative_{sku}.vdb",
                     baseline / "cumulative" / sku / "hierarchy.html"):
            if not path.exists():
                parser.error(f"required input missing: {path}")
    with ThreadPoolExecutor(max_workers=2) as pool:
        jobs = (pool.submit(run_case, build, out, sku, case)
                for sku in CONFIGS for case in CASE_NAMES)
        results = [job.result() for job in list(jobs)]
    (out / "cases.json").write_text(json.dumps(results, indent=2) + "\n")
    delta = {}
    for sku in CONFIGS:
        vdbs = [str(out / row["vdb"]) for row in results if row["configuration"] == sku]
        report = out / "cumulative" / sku
        original = baseline / f"v14_cumulative_{sku}.vdb"
        command = [str(urg), "-full64", "-dir", str(original), *vdbs,
                   "-report", str(report), "-dbname", f"v14_commit_counter_{sku}"]
        output = checked_command(command, out / f"urg_{sku}.log", cwd=out)
        if (not (report / "hierarchy.html").is_file() or
                re.search(r"UCAPI-MAP|checksum.*mismatch|incompatible.*(test|database)", output, re.I)):
            raise RuntimeError(f"URG did not produce compatible output: {report}")
        before, old_hits = bins(baseline / "cumulative" / sku, sku)
        after, new_hits = bins(report, sku)
        gains = new_hits - old_hits
        if before != after or old_hits - new_hits:
            raise RuntimeError(f"URG Condition universe or previous hits changed: {sku}")
        if not any(key[1] == "thermo5_dpd_axi_lite_cfg" and
                   key[3] == 333 and key[-1] == ("1", "0", "1") for key in gains):
            raise RuntimeError(f"URG did not credit the exact COMMIT tuple: {sku}")
        delta[sku] = list(gains.elements())
    (out / "condition_delta.json").write_text(json.dumps(delta, indent=2) + "\n")


if __name__ == "__main__":
    main()
