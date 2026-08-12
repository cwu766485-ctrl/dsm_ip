#!/usr/bin/env python3
"""Run a local ADS HSPICE-compatibility DC probe against a TSMC40 model deck.

The PDK location is deliberately supplied only by ``TSMC40_PDK_ROOT`` or
``--pdk-root``. No vendor model, model name listing, or absolute PDK path is
written into the repository.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_hspice_probe"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdk-root", type=Path, default=os.environ.get("TSMC40_PDK_ROOT"))
    parser.add_argument("--model", default="nmos_rf", help="Local PDK NMOS subcircuit identifier.")
    parser.add_argument(
        "--model-deck",
        default="models/hspice/crn40lp_2d5_v2d0_2.l",
        help="PDK-relative HSPICE model deck containing the selected section.",
    )
    parser.add_argument(
        "--sections",
        default="stat,global_RFMOS,TT_RFMOS,Total_RF_MOS",
        help=(
            "Comma-separated HSPICE sections in dependency order. The default is "
            "the local typical RF-MOS corner plus the RF subcircuit section."
        ),
    )
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    args = parser.parse_args()

    if args.pdk_root is None:
        raise RuntimeError("Set TSMC40_PDK_ROOT to the local extracted PDK root.")
    pdk_root = args.pdk_root.resolve()
    model_deck = pdk_root / args.model_deck
    if not model_deck.is_file():
        raise RuntimeError(f"TSMC40 HSPICE top-level deck not found: {model_deck}")

    hpeesof_dir = os.environ.get("HPEESOF_DIR")
    if not hpeesof_dir:
        raise RuntimeError("HPEESOF_DIR is not set. Start from an ADS 2025 environment.")
    simulator = Path(hpeesof_dir) / "bin" / "hpeesofsim.exe"
    if not simulator.is_file():
        raise RuntimeError(f"ADS simulator not found: {simulator}")

    run_dir = args.run_dir.resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    deck_path = str(model_deck).replace("\\", "/")
    sections = [section.strip() for section in args.sections.split(",") if section.strip()]
    if not sections:
        raise RuntimeError("At least one HSPICE library section is required.")
    includes = [f'.lib "{deck_path}" {section}' for section in sections]
    netlist = "\n".join(
        (
            "* Local TSMC40 ADS HSPICE compatibility probe.",
            "simulator lang=spice",
            *includes,
            "VDD vdd 0 1.2",
            "VGATE gate 0 1.2",
            "RDRAIN vdd drain 10k",
            f"XN1 drain gate 0 0 {args.model} lr=0.04u wr=1u nr=4 multi=1",
            "simulator lang=ads",
            "DC:DC1",
            "",
        )
    )
    netlist_path = run_dir / "tsmc40_hspice_probe.sp"
    netlist_path.write_text(netlist, encoding="ascii")

    result = subprocess.run(
        [str(simulator), str(netlist_path)], cwd=run_dir, text=True, capture_output=True, check=False
    )
    (run_dir / "hpeesofsim.stdout.log").write_text(result.stdout, encoding="utf-8")
    (run_dir / "hpeesofsim.stderr.log").write_text(result.stderr, encoding="utf-8")
    print(f"ADS HSPICE probe return code: {result.returncode}")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    print("TSMC40 ADS HSPICE probe PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
