#!/usr/bin/env python3
"""Exercise EF1 and MASH AXI-Lite complex DPD and burst boundaries."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import sys

from run_thermo5_product_dpd_matrix import GENERATOR, ROOT, run, sha256

SKUS = (("ef1_axil", 1, 7168, "tidsm"), ("mash11_axil", 2, 5120, "mash11"))
COEFF_ARGS = ("c1-re", "c1-im", "c3-re", "c3-im", "c5-re", "c5-im")
PROFILES = (
    ("checker_a", "range_stress", 8192, (21845, -21846, 21845, -21846, 21845, -21846)),
    ("checker_b", "extreme", 12288, (-21846, 21845, -21846, 21845, -21846, 21845)),
    ("i_clip", "extreme", 32767, (32767, 0, 0, 0, 0, 0)),
    ("q_rotate", "extreme", 20480, (0, -32768, 0, 0, 0, 0)),
    ("mixed", "random", 11351, (17937, -3151, -4977, 1512, 8781, -4210)),
    ("mixed_inverse", "range_stress", 19612, (-17938, 3150, 4976, -1513, -8782, 4209)),
)


def run_sku(item, build, out, env):
    config, order, step, mode = item
    simv = build / config / "simv"
    records = []
    extended = (
        ("long_gain_sweep", "random", 16384, (28747, -12719, -2743, 3009, 5139, -7731)),
        ("late_commit_stall", "range_stress", 20480, (19411, 747, 2277, -5227, -349, 1711)),
    )
    for index, (name, profile, gain, coeffs) in enumerate(PROFILES + extended):
        seed = 956000 + index
        case = out / config / name
        vectors = case / "vectors"
        vector_args = [arg for bit, value in zip(COEFF_ARGS, coeffs)
                       for arg in (f"--dpd-{bit}-q14", str(value))]
        words = 56
        starts = [1]
        gains = [gain]
        if name == "long_gain_sweep":
            words = 56 * 40
            starts = [56 * packet + delta for packet in range(40) for delta in (1, 15, 36)]
            gains = [((i * 7853 + 32767) & 32767) for i in range(len(starts))]
        if name == "late_commit_stall":
            starts = [1, 36]
            gains = [16384, gain]
        run([sys.executable, str(GENERATOR), "--output-dir", str(vectors),
             "--words", str(words), "--seed", str(seed), "--profile", profile,
             "--step", str(step), "--tidsm-order", str(order), "--dsm-mode", mode,
             "--frame-start-words", ",".join(map(str, starts)),
             "--frame-gains", ",".join(map(str, gains)),
             "--dpd-profile", "custom_1tap", *vector_args],
            cwd=ROOT, env=env, log_path=case / "vectors.log")
        vdb = case / "coverage.vdb"
        log = case / "sim.log"
        command = [
            str(simv), "+UVM_TESTNAME=thermo5_sku_axil_random_dpd_bittrue_test",
            "+THERMO5_COMPLEX_DPD_COVERAGE", f"+VEC_DIR={vectors}", f"+ntb_random_seed={seed}",
            f"+CORE_WORDS={words}", "+PACKET_BEATS=32", f"+THERMO5_EXPECT_FRAME_STARTS={len(starts)}",
            *(["+THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL"] if name == "late_commit_stall" else []),
            *(f"+THERMO5_DPD_{bit.upper().replace('-', '_')}_Q14={value}"
              for bit, value in zip(COEFF_ARGS, coeffs)),
            "-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb), "-l", str(log),
        ]
        output = run(command, cwd=ROOT, env=env, log_path=case / "stdout.log")
        if ("THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS" not in output
                or not vdb.is_dir() or any(not re.search(rf"UVM_{kind}\s*:\s*0\b", output)
                                           for kind in ("ERROR", "FATAL"))):
            raise RuntimeError(f"oracle or UVM failed: {log}")
        records.append(dict(configuration=config, name=name, seed=seed, profile=profile,
                            gain=gain, coefficients=coeffs, status="PASS",
                            log=str(log.relative_to(ROOT)), vdb=str(vdb.relative_to(ROOT)),
                            log_sha256=sha256(log)))
        print(config, name, "PASS", flush=True)
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--control-manifest", type=Path)
    parser.add_argument("--urg", type=Path, required=True)
    args = parser.parse_args()
    build, out = args.build.resolve(), args.out.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory under runs/")
    out.mkdir(parents=True)
    env = os.environ.copy()
    with ThreadPoolExecutor(max_workers=2) as pool:
        records = [record for result in pool.map(lambda item: run_sku(item, build, out, env), SKUS)
                   for record in result]
    control = json.loads(args.control_manifest.read_text()) if args.control_manifest else []
    for record in control:
        if (record["configuration"] not in {sku[0] for sku in SKUS}
                or record["status"] != "PASS"
                or sha256(ROOT / record["log"]) != record["log_sha256"]
                or not (ROOT / record["vdb"]).is_dir()):
            raise ValueError("Invalid control sweep evidence")
    prior = json.loads(args.baseline.read_text())
    for config, *_ in SKUS:
        vdbs = prior["configurations"][config]["test_vdbs"]
        new = [str(ROOT / record["vdb"]) for record in records + control if record["configuration"] == config]
        report = out / "urg" / config
        command = [str(args.urg), "-full64", "-dir", str(build / config / "simv.vdb"),
                   *vdbs, *new, "-report", str(report), "-dbname", "axil_focus_" + config]
        output = run(command, cwd=out, env=env, log_path=out / f"{config}_urg.log")
        if not (report / "hierarchy.html").is_file() or re.search(
                r"UCAPI-MAP|checksum.*mismatch|incompatible.*(test|database)", output, re.I):
            raise RuntimeError(f"URG report missing or incompatible: {config}")
    (out / "summary.json").write_text(json.dumps(records + control, indent=2) + "\n")


if __name__ == "__main__":
    main()
