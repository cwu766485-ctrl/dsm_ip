#!/usr/bin/env python3
"""Merge Round 3 VCS databases without crossing SKU/elaboration boundaries."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
CONFIGS = {
    "ef1_product": ("ef1", "ef1", "ef1"),
    "ef1_axil": ("ef1_axil", "ef1_axil", "ef1"),
    "ef2_product": ("ef2", "ef2", "ef2"),
    "ef2_axil": ("ef2_axil", "ef2_axil", "ef2"),
    "mash11_product": ("mash11_product", "mash11_product", "mash11"),
    "mash11_axil": ("mash11_axil", "mash11_axil", "mash11"),
    "mash11_wrapper_core": ("mash11_core", "mash11_core", None),
}


def find_urg(requested: str | None) -> str:
    candidate = requested or os.environ.get("URG", "")
    if candidate:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        if Path(candidate).is_file():
            return str(Path(candidate).resolve())
    vcs_home = os.environ.get("VCS_HOME", "")
    candidates = [Path(vcs_home) / "bin/urg"] if vcs_home else []
    vcs = shutil.which("vcs")
    if vcs:
        candidates.append(Path(vcs).resolve().parent / "urg")
    candidates.append(Path("/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg"))
    return next((str(path) for path in candidates if path.is_file()), "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directed-out", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/directed")
    parser.add_argument("--axil-random-out", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/axil_random")
    parser.add_argument("--product-random-out", type=Path,
                        default=ROOT / "runs/dsm_v13_round3/product_random_matrix_b")
    parser.add_argument("--round2-axil-random-out", type=Path, default=None,
                        help="matching Round 2 AXI-Lite random VDB root")
    parser.add_argument("--urg", default=os.environ.get("URG"))
    args = parser.parse_args()
    directed = args.directed_out.resolve()
    axil_random = args.axil_random_out.resolve()
    product_random = args.product_random_out.resolve()
    round2_random = (args.round2_axil_random_out.resolve()
                     if args.round2_axil_random_out and str(args.round2_axil_random_out)
                     else None)
    urg = find_urg(args.urg)
    summary = {
        "schema": "dsm_v13_round3_urg_merge_v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "urg": urg or "NOT_FOUND",
        "merge_policy": "same SKU and elaboration only; Product and AXI-Lite databases remain separate",
        "inputs": {"directed_out": str(directed), "axil_random_out": str(axil_random),
                   "product_random_out": str(product_random),
                   "round2_axil_random_out": str(round2_random) if round2_random else "NOT_SUPPLIED"},
        "configurations": {},
    }
    all_pass = bool(urg)
    for name, (build_name, report_name, random_sku) in CONFIGS.items():
        build = directed / build_name
        design = build / "simv.vdb"
        tests = sorted(path for path in build.glob("*.vdb")
                       if path.is_dir() and path != design)
        axil_vdbs: list[Path] = []
        round2_axil_vdbs: list[Path] = []
        product_vdbs: list[Path] = []
        if random_sku and name.endswith("_axil"):
            axil_vdbs = sorted(path for path in
                               (axil_random / random_sku / "vdb").glob("*.vdb")
                               if path.is_dir())
            if round2_random:
                round2_axil_vdbs = sorted(path for path in
                    (round2_random / random_sku / "vdb").glob("*.vdb")
                    if path.is_dir())
        elif random_sku and name.endswith("_product"):
            product_vdbs = sorted(path for path in
                                  (product_random / random_sku / "vdb").glob("*.vdb")
                                  if path.is_dir())
        tests.extend(axil_vdbs)
        tests.extend(round2_axil_vdbs)
        tests.extend(product_vdbs)
        record = {
            "status": "NOT_RUN", "build": str(build),
            "design_vdb": str(design), "test_vdbs": [str(path) for path in tests],
            "directed_test_vdb_count": len(tests) - len(axil_vdbs) - len(round2_axil_vdbs) - len(product_vdbs),
            "axil_random_vdbs": [str(path) for path in axil_vdbs],
            "round2_axil_random_vdbs": [str(path) for path in round2_axil_vdbs],
            "product_random_vdbs": [str(path) for path in product_vdbs],
            "report": str(directed / "round3_urg" / report_name),
        }
        summary["configurations"][name] = record
        if not urg:
            record["status"] = "NOT_AVAILABLE"
            continue
        if not design.is_dir() or not tests or any(not path.is_dir() for path in tests):
            record["status"] = "MISSING_MATCHING_VDB"
            all_pass = False
            continue
        report = Path(record["report"])
        log_path = report.parent / (report_name + ".log")
        command = [urg, "-full64", "-dir", str(design)] + [str(x) for x in tests] + [
            "-report", str(report), "-dbname", "dsm_v13_r3_" + name]
        result = subprocess.run(command, cwd=ROOT, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                check=False)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(result.stdout, encoding="utf-8")
        record.update({"command": command, "log": str(log_path),
                       "returncode": result.returncode,
                       "status": "PASS" if result.returncode == 0 else "FAIL"})
        if result.returncode:
            all_pass = False

    summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
    summary["status"] = "PASS" if all_pass else "OPEN"
    summary_path = directed / "round3_urg" / "summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    print("DSM_V13_R3_URG_SUMMARY=" + str(summary_path))
    for name, record in summary["configurations"].items():
        print("DSM_V13_R3_URG_%s=%s tests=%d product_random=%d axil_random=%d round2_axil_random=%d" %
              (name, record["status"], len(record["test_vdbs"]),
               len(record["product_random_vdbs"]), len(record["axil_random_vdbs"]),
               len(record["round2_axil_random_vdbs"])))
    return 0 if all_pass else 2


if __name__ == "__main__":
    sys.exit(main())
