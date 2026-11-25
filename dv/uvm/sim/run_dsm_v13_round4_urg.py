#!/usr/bin/env python3
"""Merge only the Round 4 focused functional VDB matrix, per SKU/config."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
RUN_DIR = ROOT / "runs/dsm_v13_round4"
CASES = {
    "ef1_product": {
        "vdbs": [
            "cov_thermo5_sku_bittrue_test_seed440410.vdb",
            "cov_thermo5_sku_reset_sweep_test_seed440611.vdb",
            "cov_thermo5_sku_fifo_full_reset_test_seed440412.vdb",
            "cov_thermo5_sku_product_random_test_seed440414.vdb",
            "cov_thermo5_sku_bubble_backpressure_test_seed440621.vdb",
            "cov_thermo5_sku_fifo_boundary_test_seed440622.vdb",
            "cov_thermo5_sku_fifo_empty_test_seed440623.vdb",
            "cov_thermo5_sku_reset_test_seed440624.vdb",
            "cov_illegal_frame_seed440401.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_bittrue_test_seed440410.log",
            "thermo5_sku_reset_sweep_test_seed440611.log",
            "thermo5_sku_fifo_full_reset_test_seed440412.log",
            "thermo5_sku_product_random_test_seed440414.log",
            "thermo5_sku_bubble_backpressure_test_seed440621.log",
            "thermo5_sku_fifo_boundary_test_seed440622.log",
            "thermo5_sku_fifo_empty_test_seed440623.log",
            "thermo5_sku_reset_test_seed440624.log",
        ],
        "positive_markers": {
            "thermo5_sku_bittrue_test_seed440410.log": "THERMO5_SKU_UVM_PASS",
            "thermo5_sku_reset_sweep_test_seed440611.log": "THERMO5_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_fifo_full_reset_test_seed440412.log": "THERMO5_FULL_FIFO_RESET_UVM_PASS",
            "thermo5_sku_product_random_test_seed440414.log": "DSM_V13_PRODUCT_RANDOM_PASS",
            "thermo5_sku_bubble_backpressure_test_seed440621.log": "THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS",
            "thermo5_sku_fifo_boundary_test_seed440622.log": "THERMO5_FIFO_BOUNDARY_UVM_PASS",
            "thermo5_sku_fifo_empty_test_seed440623.log": "THERMO5_FIFO_EMPTY_UVM_PASS",
            "thermo5_sku_reset_test_seed440624.log": "THERMO5_RESET_UVM_PASS",
        },
        "negative_log": "illegal_frame_seed440401.log",
        "negative_markers": [
            "DSM frame_start was not aligned to a 56-sample boundary",
            "THERMO5_ILLEGAL_FRAME_OBSERVED",
        ],
    },
    "ef2_product": {
        "vdbs": [
            "cov_thermo5_sku_bittrue_test_seed440410.vdb",
            "cov_thermo5_sku_reset_sweep_test_seed440611.vdb",
            "cov_thermo5_sku_fifo_full_reset_test_seed440412.vdb",
            "cov_thermo5_sku_product_random_test_seed440414.vdb",
            "cov_thermo5_sku_ef2_corner_test_seed440415.vdb",
            "cov_thermo5_sku_bubble_backpressure_test_seed440621.vdb",
            "cov_thermo5_sku_fifo_boundary_test_seed440622.vdb",
            "cov_thermo5_sku_fifo_empty_test_seed440623.vdb",
            "cov_thermo5_sku_reset_test_seed440624.vdb",
            "cov_illegal_frame_seed440402.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_bittrue_test_seed440410.log",
            "thermo5_sku_reset_sweep_test_seed440611.log",
            "thermo5_sku_fifo_full_reset_test_seed440412.log",
            "thermo5_sku_product_random_test_seed440414.log",
            "thermo5_sku_ef2_corner_test_seed440415.log",
            "thermo5_sku_bubble_backpressure_test_seed440621.log",
            "thermo5_sku_fifo_boundary_test_seed440622.log",
            "thermo5_sku_fifo_empty_test_seed440623.log",
            "thermo5_sku_reset_test_seed440624.log",
        ],
        "positive_markers": {
            "thermo5_sku_bittrue_test_seed440410.log": "THERMO5_SKU_UVM_PASS",
            "thermo5_sku_reset_sweep_test_seed440611.log": "THERMO5_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_fifo_full_reset_test_seed440412.log": "THERMO5_FULL_FIFO_RESET_UVM_PASS",
            "thermo5_sku_product_random_test_seed440414.log": "DSM_V13_PRODUCT_RANDOM_PASS",
            "thermo5_sku_ef2_corner_test_seed440415.log": "THERMO5_EF2_CORNER_UVM_PASS",
            "thermo5_sku_bubble_backpressure_test_seed440621.log": "THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS",
            "thermo5_sku_fifo_boundary_test_seed440622.log": "THERMO5_FIFO_BOUNDARY_UVM_PASS",
            "thermo5_sku_fifo_empty_test_seed440623.log": "THERMO5_FIFO_EMPTY_UVM_PASS",
            "thermo5_sku_reset_test_seed440624.log": "THERMO5_RESET_UVM_PASS",
        },
        "negative_log": "illegal_frame_seed440402.log",
        "negative_markers": [
            "DSM frame_start was not aligned to a 56-sample boundary",
            "THERMO5_ILLEGAL_FRAME_OBSERVED",
        ],
    },
    "mash11_product": {
        "vdbs": [
            "cov_thermo5_sku_bittrue_test_seed440410.vdb",
            "cov_thermo5_sku_reset_sweep_test_seed440611.vdb",
            "cov_thermo5_sku_fifo_full_reset_test_seed440412.vdb",
            "cov_thermo5_sku_product_random_test_seed440414.vdb",
            "cov_thermo5_sku_bittrue_test_seed440416.vdb",
            "cov_thermo5_sku_bittrue_test_seed440418.vdb",
            "cov_illegal_frame_seed440403.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_bittrue_test_seed440410.log",
            "thermo5_sku_reset_sweep_test_seed440611.log",
            "thermo5_sku_fifo_full_reset_test_seed440412.log",
            "thermo5_sku_product_random_test_seed440414.log",
            "thermo5_sku_bittrue_test_seed440416.log",
            "thermo5_sku_bittrue_test_seed440418.log",
        ],
        "positive_markers": {
            "thermo5_sku_bittrue_test_seed440410.log": "THERMO5_SKU_UVM_PASS",
            "thermo5_sku_reset_sweep_test_seed440611.log": "THERMO5_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_fifo_full_reset_test_seed440412.log": "THERMO5_FULL_FIFO_RESET_UVM_PASS",
            "thermo5_sku_product_random_test_seed440414.log": "DSM_V13_PRODUCT_RANDOM_PASS",
            "thermo5_sku_bittrue_test_seed440416.log": "THERMO5_SKU_UVM_PASS",
            "thermo5_sku_bittrue_test_seed440418.log": "THERMO5_SKU_UVM_PASS",
        },
        "negative_log": "illegal_frame_seed440403.log",
        "negative_markers": [
            "DSM frame_start was not aligned to a 56-sample boundary",
            "THERMO5_ILLEGAL_FRAME_OBSERVED",
        ],
    },
    "ef1_axil": {
        "vdbs": [
            "cov_thermo5_sku_axil_config_test_seed440501.vdb",
            "cov_thermo5_sku_axil_register_access_test_seed440502.vdb",
            "cov_thermo5_sku_axil_reset_sweep_test_seed440503.vdb",
            "cov_thermo5_sku_axil_stop_restart_test_seed440504.vdb",
            "cov_thermo5_sku_axil_random_packet_test_seed440505.vdb",
            "cov_thermo5_sku_axil_graceful_stop_test_seed440506.vdb",
            "cov_axil_illegal_frame_seed420102.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_axil_config_test_seed440501.log",
            "thermo5_sku_axil_register_access_test_seed440502.log",
            "thermo5_sku_axil_reset_sweep_test_seed440503.log",
            "thermo5_sku_axil_stop_restart_test_seed440504.log",
            "thermo5_sku_axil_random_packet_test_seed440505.log",
            "thermo5_sku_axil_graceful_stop_test_seed440506.log",
        ],
        "positive_markers": {
            "thermo5_sku_axil_config_test_seed440501.log": "THERMO5_AXIL_CONFIG_UVM_PASS",
            "thermo5_sku_axil_register_access_test_seed440502.log": "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS",
            "thermo5_sku_axil_reset_sweep_test_seed440503.log": "THERMO5_AXIL_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_axil_stop_restart_test_seed440504.log": "THERMO5_AXIL_STOP_RESTART_UVM_PASS",
            "thermo5_sku_axil_random_packet_test_seed440505.log": "THERMO5_TX_RANDOM_PACKET_PASS",
            "thermo5_sku_axil_graceful_stop_test_seed440506.log": "THERMO5_AXIL_GRACEFUL_STOP_UVM_PASS",
        },
        "negative_log": "axil_illegal_frame_seed420102.log",
        "negative_markers": [
            "THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED",
            "THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS",
        ],
    },
    "ef2_axil": {
        "vdbs": [
            "cov_thermo5_sku_axil_config_test_seed440511.vdb",
            "cov_thermo5_sku_axil_register_access_test_seed440512.vdb",
            "cov_thermo5_sku_axil_reset_sweep_test_seed440513.vdb",
            "cov_thermo5_sku_axil_stop_restart_test_seed440514.vdb",
            "cov_thermo5_sku_axil_random_packet_test_seed440515.vdb",
            "cov_thermo5_sku_axil_graceful_stop_test_seed440516.vdb",
            "cov_thermo5_sku_axil_ef2_corner_test_seed440517.vdb",
            "cov_axil_illegal_frame_seed420102.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_axil_config_test_seed440511.log",
            "thermo5_sku_axil_register_access_test_seed440512.log",
            "thermo5_sku_axil_reset_sweep_test_seed440513.log",
            "thermo5_sku_axil_stop_restart_test_seed440514.log",
            "thermo5_sku_axil_random_packet_test_seed440515.log",
            "thermo5_sku_axil_graceful_stop_test_seed440516.log",
            "thermo5_sku_axil_ef2_corner_test_seed440517.log",
        ],
        "positive_markers": {
            "thermo5_sku_axil_config_test_seed440511.log": "THERMO5_AXIL_CONFIG_UVM_PASS",
            "thermo5_sku_axil_register_access_test_seed440512.log": "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS",
            "thermo5_sku_axil_reset_sweep_test_seed440513.log": "THERMO5_AXIL_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_axil_stop_restart_test_seed440514.log": "THERMO5_AXIL_STOP_RESTART_UVM_PASS",
            "thermo5_sku_axil_random_packet_test_seed440515.log": "THERMO5_TX_RANDOM_PACKET_PASS",
            "thermo5_sku_axil_graceful_stop_test_seed440516.log": "THERMO5_AXIL_GRACEFUL_STOP_UVM_PASS",
            "thermo5_sku_axil_ef2_corner_test_seed440517.log": "THERMO5_AXIL_EF2_CORNER_UVM_PASS",
        },
        "negative_log": "axil_illegal_frame_seed420102.log",
        "negative_markers": [
            "THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED",
            "THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS",
        ],
    },
    "mash11_axil": {
        "vdbs": [
            "cov_thermo5_sku_axil_config_test_seed440521.vdb",
            "cov_thermo5_sku_axil_register_access_test_seed440522.vdb",
            "cov_thermo5_sku_axil_reset_sweep_test_seed440523.vdb",
            "cov_thermo5_sku_axil_stop_restart_test_seed440524.vdb",
            "cov_thermo5_sku_axil_random_packet_test_seed440525.vdb",
            "cov_thermo5_sku_axil_graceful_stop_test_seed440527.vdb",
            "cov_thermo5_sku_axil_random_packet_test_seed440526.vdb",
            "cov_thermo5_sku_axil_mash11_rail_history_test_seed440529.vdb",
            "cov_axil_illegal_frame_seed420102.vdb",
        ],
        "positive_logs": [
            "thermo5_sku_axil_config_test_seed440521.log",
            "thermo5_sku_axil_register_access_test_seed440522.log",
            "thermo5_sku_axil_reset_sweep_test_seed440523.log",
            "thermo5_sku_axil_stop_restart_test_seed440524.log",
            "thermo5_sku_axil_random_packet_test_seed440525.log",
            "thermo5_sku_axil_graceful_stop_test_seed440527.log",
            "thermo5_sku_axil_random_packet_test_seed440526.log",
            "thermo5_sku_axil_mash11_rail_history_test_seed440529.log",
        ],
        "positive_markers": {
            "thermo5_sku_axil_config_test_seed440521.log": "THERMO5_AXIL_CONFIG_UVM_PASS",
            "thermo5_sku_axil_register_access_test_seed440522.log": "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS",
            "thermo5_sku_axil_reset_sweep_test_seed440523.log": "THERMO5_AXIL_RESET_SWEEP_UVM_PASS",
            "thermo5_sku_axil_stop_restart_test_seed440524.log": "THERMO5_AXIL_STOP_RESTART_UVM_PASS",
            "thermo5_sku_axil_random_packet_test_seed440525.log": "THERMO5_TX_RANDOM_PACKET_PASS",
            "thermo5_sku_axil_graceful_stop_test_seed440527.log": "THERMO5_AXIL_GRACEFUL_STOP_UVM_PASS",
            "thermo5_sku_axil_random_packet_test_seed440526.log": "THERMO5_TX_RANDOM_PACKET_PASS",
            "thermo5_sku_axil_mash11_rail_history_test_seed440529.log": "THERMO5_AXIL_MASH11_RAIL_HISTORY_PASS",
        },
        "negative_log": "axil_illegal_frame_seed420102.log",
        "negative_markers": [
            "THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED",
            "THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS",
        ],
    },
    "mash11_wrapper_core": {
        # The legacy block-level elaboration is deliberately isolated from
        # the Product-top MASH database and has its own build/schema.
        "build_dir": "mash11_core",
        "vdbs": ["core_seed130011.vdb"],
        "positive_logs": ["core_seed130011.log"],
        "positive_markers": {
            "core_seed130011.log": "DSM_V13_MASH11_UVM_PASS",
        },
    },
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
    candidates.append(Path("/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg"))
    return next((str(path) for path in candidates if path.is_file()), "")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_pass_log(path: Path, required_markers: list[str]) -> str:
    if not path.is_file():
        raise RuntimeError(f"missing required log: {path}")
    text = path.read_text(encoding="utf-8", errors="replace")
    for marker in required_markers:
        if marker not in text:
            raise RuntimeError(f"{path} lacks required marker {marker!r}")
    for severity in ("UVM_WARNING", "UVM_ERROR", "UVM_FATAL"):
        if f"{severity} :    0" not in text and f"{severity} :   0" not in text:
            raise RuntimeError(f"{path} does not prove {severity}=0")
    return sha256(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=RUN_DIR)
    parser.add_argument("--urg", default=os.environ.get("URG"))
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    urg = find_urg(args.urg)
    if not urg:
        raise SystemExit("URG V-2023.12-SP1 was not found")
    summary: dict = {
        "schema": "dsm_v13_round4_functional_urg_v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "urg": urg,
        "merge_policy": "same Round 4 source/schema, SKU and elaboration only; failed runs excluded",
        "configurations": {},
    }
    all_pass = True
    for name, case in CASES.items():
        build = run_dir / case.get("build_dir", name)
        design = build / "simv.vdb"
        test_vdbs = [build / item for item in case["vdbs"]]
        log_hashes: dict[str, str] = {}
        record = {"status": "OPEN", "design_vdb": str(design),
                  "test_vdbs": [], "positive_log_sha256": log_hashes}
        summary["configurations"][name] = record
        if not design.is_dir():
            record["reason"] = "missing compiled design VDB"
            all_pass = False
            continue
        try:
            for log_name in case["positive_logs"]:
                required = ["UVM_WARNING :    0", "UVM_ERROR :    0", "UVM_FATAL :    0"]
                marker = case.get("positive_markers", {}).get(log_name)
                if marker:
                    required.append(marker)
                log_hashes[log_name] = require_pass_log(build / log_name, required)
            negative_log_name = case.get("negative_log")
            if negative_log_name:
                negative_log = build / negative_log_name
                log_hashes[negative_log_name] = require_pass_log(
                    negative_log, ["UVM_WARNING :    0", *case["negative_markers"]])
            for vdb in test_vdbs:
                if not vdb.is_dir():
                    raise RuntimeError(f"missing passing test VDB: {vdb}")
            record["test_vdbs"] = [str(path) for path in test_vdbs]
        except RuntimeError as error:
            record["reason"] = str(error)
            all_pass = False
            continue

        report = run_dir / "urg" / name
        report.parent.mkdir(parents=True, exist_ok=True)
        command = [urg, "-full64", "-dir", str(design)] + [str(path) for path in test_vdbs] + [
            "-report", str(report), "-dbname", "dsm_v13_r4_" + name]
        result = subprocess.run(command, cwd=ROOT, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                check=False)
        log_path = report.parent / f"{name}.log"
        log_path.write_text(result.stdout, encoding="utf-8")
        record.update({"command": command, "urg_log": str(log_path),
                       "urg_returncode": result.returncode,
                       "status": "PASS" if result.returncode == 0 else "FAIL"})
        if result.returncode == 0:
            record["report"] = str(report)
            record["report_sha256"] = sha256(report / "groups.html") if (report / "groups.html").is_file() else ""
            record["design_vdb_file_count"] = sum(1 for p in design.rglob("*") if p.is_file())
            record["test_vdb_file_counts"] = {
                str(path): sum(1 for item in path.rglob("*") if item.is_file())
                for path in test_vdbs}
        else:
            all_pass = False

    # Keep assertion tail/abort state attributable to the individual positive
    # MASH AXI-Lite tests. The merged assertion report cannot identify which
    # scenario disabled an in-flight property attempt at reset.
    mash_axil = summary["configurations"].get("mash11_axil", {})
    case = CASES["mash11_axil"]
    if mash_axil.get("status") == "PASS":
        build = run_dir / case.get("build_dir", "mash11_axil")
        design = build / "simv.vdb"
        isolated_records = []
        isolated_ok = True
        for index, vdb_name in enumerate(case["vdbs"][:len(case["positive_logs"])]):
            vdb = build / vdb_name
            report = run_dir / "assertions_isolated" / "mash11_axil" / f"test_{index:02d}"
            report.parent.mkdir(parents=True, exist_ok=True)
            command = [urg, "-full64", "-dir", str(design), str(vdb),
                       "-report", str(report), "-dbname", f"dsm_v13_r4_mash_axil_test_{index:02d}"]
            result = subprocess.run(command, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    check=False)
            log_path = report.parent / f"test_{index:02d}.log"
            log_path.write_text(result.stdout, encoding="utf-8")
            if result.returncode != 0 or not (report / "asserts.html").is_file():
                isolated_ok = False
            isolated_records.append({
                "test_vdb": str(vdb), "test_name": vdb_name.removeprefix("cov_").removesuffix(".vdb"),
                "report": str(report), "asserts_html_sha256": (
                    sha256(report / "asserts.html") if (report / "asserts.html").is_file() else ""),
                "urg_log": str(log_path), "urg_returncode": result.returncode,
            })
        mash_axil["assertion_isolation"] = {
            "status": "PASS" if isolated_ok else "OPEN",
            "policy": "One positive test VDB per report; identify incomplete attempts without merging test coverage.",
            "reports": isolated_records,
        }
        if not isolated_ok:
            all_pass = False
    else:
        mash_axil["assertion_isolation"] = {"status": "OPEN", "reports": []}

    summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
    summary["status"] = "PASS" if all_pass else "OPEN"
    summary_path = run_dir / "round4_urg" / "summary.json"
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n",
                            encoding="utf-8")
    print("DSM_V13_R4_URG_SUMMARY=" + str(summary_path))
    for name, record in summary["configurations"].items():
        print(f"DSM_V13_R4_URG_{name}={record['status']} tests={len(record.get('test_vdbs', []))}")
    return 0 if all_pass else 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        raise SystemExit(str(error))
