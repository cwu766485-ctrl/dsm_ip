#!/usr/bin/env python3
"""Merge only same-configuration DSM V1.3 Round 2 VCS databases with URG."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[3]
CONFIGS = {
    "ef1_product": "ef1",
    "ef1_axil": "ef1_axil",
    "ef2_product": "ef2",
    "ef2_axil": "ef2_axil",
    "mash11_product": "mash11_product",
    "mash11_axil": "mash11_axil",
    "mash11_wrapper_core": "mash11_core",
}
RANDOM_SKU_FOR_CONFIG = {
    "ef1_axil": "ef1",
    "ef2_axil": "ef2",
    "mash11_axil": "mash11",
}


def run(command, log_path):
    result = subprocess.run(command, cwd=ROOT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(result.stdout, encoding="utf-8")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "dsm_v13_round2")
    parser.add_argument("--urg", default=os.environ.get("URG"))
    parser.add_argument("--random-out", type=Path,
                        help="optional matching AXI-Lite random campaign root")
    args = parser.parse_args()

    out = args.out.resolve()
    random_out = args.random_out.resolve() if args.random_out else None
    urg = args.urg or ""
    if urg and shutil.which(urg):
        urg = shutil.which(urg)
    if not urg and os.environ.get("VCS_HOME"):
        candidate = Path(os.environ["VCS_HOME"]) / "bin" / "urg"
        if candidate.is_file():
            urg = str(candidate)
    if urg and not Path(urg).is_file() and shutil.which(urg) is None:
        urg = ""
    summary = {
        "schema": "dsm_v13_round2_urg_merge_v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "urg": urg or "NOT_FOUND",
        "sku_database_policy": "separate per SKU and elaboration configuration",
        "configurations": {},
    }
    all_pass = True
    for name, relative in CONFIGS.items():
        build = out / relative
        design_vdb = build / "simv.vdb"
        test_vdbs = sorted(path for path in build.glob("*.vdb")
                           if path.is_dir() and path != design_vdb)
        random_test_vdbs = []
        random_sku = RANDOM_SKU_FOR_CONFIG.get(name)
        if random_out and random_sku:
            random_test_vdbs = sorted(
                path for path in (random_out / random_sku / "vdb").glob("*.vdb")
                if path.is_dir())
        test_vdbs.extend(random_test_vdbs)
        record = {"build": str(build), "design_vdb": str(design_vdb),
                  "test_vdbs": [str(path) for path in test_vdbs],
                  "included_random_test_vdbs": [str(path) for path in random_test_vdbs],
                  "status": "NOT_RUN"}
        summary["configurations"][name] = record
        if not urg:
            record["status"] = "NOT_AVAILABLE"
            all_pass = False
            continue
        if not design_vdb.is_dir() or not test_vdbs:
            record["status"] = "NO_MATCHING_VDBS"
            all_pass = False
            continue
        report = out / "urg" / name
        log_path = out / "urg" / (name + ".log")
        command = [urg, "-full64", "-dir", str(design_vdb)] + \
            [str(path) for path in test_vdbs] + \
            ["-report", str(report), "-dbname", "dsm_v13_r2_" + name]
        result = run(command, log_path)
        record["command"] = command
        record["log"] = str(log_path)
        record["returncode"] = result.returncode
        record["status"] = "PASS" if result.returncode == 0 else "FAIL"
        record["report"] = str(report)
        if result.returncode:
            all_pass = False

    summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
    summary["status"] = "PASS" if all_pass else "OPEN"
    summary_path = out / "urg" / "summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    print("DSM_V13_URG_SUMMARY=%s" % summary_path)
    for name, record in summary["configurations"].items():
        print("DSM_V13_URG_%s=%s" % (name, record["status"]))
    return 0 if all_pass else 2


if __name__ == "__main__":
    sys.exit(main())
