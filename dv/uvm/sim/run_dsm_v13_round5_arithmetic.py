#!/usr/bin/env python3
"""Run checked arithmetic cases against the frozen Round 5 SKU binaries."""
import argparse
import json
import os
from pathlib import Path
import re
import sys

from run_thermo5_product_dpd_matrix import GENERATOR, ROOT, run, sha256

CASES = {
    "product": (
        ("gain_rail", "extreme", 32767, 16384, 0, 0),
        ("interp_range", "range_stress", 20480, 16384, 0, 0),
    ),
    "axil": (
        ("coeff_transport", "random", 16384, 16384, 0, 0),
        ("boost", "extreme", 20480, 20480, 0, 0),
        ("cubic_positive", "range_stress", 20480, 16384, 2048, 0),
        ("quintic_positive", "extreme", 20480, 16384, 0, 8192),
        ("quintic_negative", "range_stress", 20480, 16384, 0, -8192),
    ),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    build = args.build.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory under runs/")
    out.mkdir(parents=True)
    manifest = []
    arithmetic_seed = 953000
    transport_seed = 953100
    for sku, step, order in (("ef1", 7168, 1), ("ef2", 5120, 2), ("mash11", 5120, 2)):
        for interface, cases in CASES.items():
            config = f"{sku}_{interface}"
            simv = build / config / "simv"
            for name, profile, gain, c1, c3, c5 in cases:
                if name == "coeff_transport":
                    seed = transport_seed
                    transport_seed += 1
                else:
                    seed = arithmetic_seed
                    arithmetic_seed += 1
                case = out / config / name
                vectors = case / "vectors"
                single_frame = interface == "axil" and name != "coeff_transport"
                gen = [sys.executable, str(GENERATOR), "--output-dir", str(vectors),
                       "--words", "56", "--seed", str(seed), "--profile", profile,
                       "--step", str(step), "--tidsm-order", str(order),
                       "--dsm-mode", "mash11" if sku == "mash11" else "tidsm",
                       "--frame-start-words", "1" if single_frame else "1,15,36",
                       "--frame-gains", str(gain) if single_frame else f"{gain},{gain},{gain}",
                       "--dpd-profile", "custom_1tap", "--dpd-c1-re-q14", str(c1),
                       "--dpd-c3-re-q14", str(c3), "--dpd-c5-re-q14", str(c5)]
                run(gen, cwd=ROOT, env=os.environ.copy(), log_path=case / "vectors.log")
                if name == "coeff_transport":
                    test = "thermo5_sku_axil_coeff_transport_test"
                    marker = "THERMO5_AXIL_COEFF_TRANSPORT_UVM_PASS"
                    options = ["+PACKET_BEATS=32"]
                elif interface == "axil":
                    test = "thermo5_sku_axil_random_dpd_bittrue_test"
                    marker = "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS"
                    options = ["+PACKET_BEATS=32", "+THERMO5_EXPECT_FRAME_STARTS=1",
                               f"+THERMO5_DPD_C1_RE_Q14={c1}", f"+THERMO5_DPD_C3_RE_Q14={c3}",
                               f"+THERMO5_DPD_C5_RE_Q14={c5}", "+THERMO5_GAIN_CLASS_ID=2",
                               f"+THERMO5_INPUT_PROFILE_ID={1 if profile == 'extreme' else 2}"]
                else:
                    test = "thermo5_sku_bittrue_test"
                    marker = "THERMO5_SKU_UVM_PASS"
                    options = []
                vdb = case / "coverage.vdb"
                log = case / "simulation.log"
                command = [str(simv), f"+UVM_TESTNAME={test}", f"+VEC_DIR={vectors}",
                           f"+ntb_random_seed={seed}", "+CORE_WORDS=56", *options,
                           "-cm", "line+cond+fsm+tgl+branch+assert",
                           "-cm_dir", str(vdb), "-l", str(log)]
                stdout = run(command, cwd=ROOT, env=os.environ.copy(), log_path=case / "stdout.log")
                if (marker not in stdout or not vdb.is_dir()
                        or any(not re.search(rf"UVM_{kind}\s*:\s*0\b", stdout)
                               for kind in ("ERROR", "FATAL"))):
                    raise SystemExit(f"checker failed: {log}")
                manifest.append(dict(configuration=config, case=name, seed=seed, profile=profile,
                                     gain=gain, c1=c1, c3=c3, c5=c5, vdb=str(vdb), log=str(log),
                                     log_sha256=sha256(log), status="PASS"))
                (out / "summary.json").write_text(json.dumps(manifest, indent=2) + "\n")
                print(config, name, "PASS", flush=True)


if __name__ == "__main__":
    main()
