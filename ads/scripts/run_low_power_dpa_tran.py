#!/usr/bin/env python3
"""Netlist and run the ADS low-power DPA transient smoke configuration."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

from keysight.ads import de
from keysight.ads.de import db_uu


REPO = Path(__file__).resolve().parents[2]
DEFAULT_WORKSPACE = REPO / "ads" / "low_power_dpa" / "workspace"
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "low_power_dpa_api_v10_tran"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE)
    parser.add_argument("--cell", default="low_power_dpa_api_v10")
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    args = parser.parse_args()
    args.workspace = args.workspace.resolve()
    args.run_dir = args.run_dir.resolve()

    hpeesof_dir = os.environ.get("HPEESOF_DIR")
    if not hpeesof_dir:
        raise RuntimeError("HPEESOF_DIR is not set. Start from an ADS 2025 environment.")
    simulator = Path(hpeesof_dir) / "bin" / "hpeesofsim.exe"
    if not simulator.is_file():
        raise RuntimeError(f"ADS simulator not found: {simulator}")
    if not args.workspace.is_dir():
        raise RuntimeError(f"ADS workspace not found: {args.workspace}")

    workspace = de.open_workspace(str(args.workspace))
    design = db_uu.open_design(("workspace_lib", args.cell, "schematic"), db_uu.DesignMode.READ_ONLY)
    netlist = design.create_netlist()
    args.run_dir.mkdir(parents=True, exist_ok=True)
    netlist_path = args.run_dir / f"{args.cell}.net"
    netlist_path.write_text(netlist, encoding="utf-8")

    result = subprocess.run(
        [str(simulator), str(netlist_path)], cwd=args.run_dir, text=True, capture_output=True, check=False
    )
    (args.run_dir / "hpeesofsim.stdout.log").write_text(result.stdout, encoding="utf-8")
    (args.run_dir / "hpeesofsim.stderr.log").write_text(result.stderr, encoding="utf-8")
    print(f"ADS netlist: {netlist_path}")
    print(f"ADS transient return code: {result.returncode}")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    print("ADS run artifacts: " + ", ".join(sorted(path.name for path in args.run_dir.iterdir())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
