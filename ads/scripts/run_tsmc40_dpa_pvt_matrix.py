#!/usr/bin/env python3
"""Run a local TSMC40 pre-layout PVT matrix for the DPA switch core.

The script is intentionally limited to validated PDK RF-MOS geometry and a
selected pre-layout driver/passive configuration. It is a sizing and robustness
screen, not a foundry signoff flow. PDK files are read only through
``TSMC40_PDK_ROOT``; generated artifacts remain under ignored ``simulation``.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
RUNNER = REPO / "ads" / "scripts" / "run_tsmc40_dpa_switch_core.py"
ANALYZER = REPO / "ads" / "scripts" / "analyze_tsmc40_dpa_switch_core.py"
DEFAULT_ROOT = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_pvt_nr16"
CORNER_SECTIONS = {
    "tt": "stat,global_RFMOS,TT_RFMOS,Total_RF_MOS",
    "ss": "stat,global_RFMOS,SS_RFMOS,Total_RF_MOS",
    "ff": "stat,global_RFMOS,FF_RFMOS,Total_RF_MOS",
}


def invoke(arguments: list[str]) -> None:
    completed = subprocess.run([sys.executable, *arguments], text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed with return code {completed.returncode}: {' '.join(arguments)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--fingers", type=int, default=16)
    parser.add_argument("--nmos-w", default="1u")
    parser.add_argument("--pmos-w", default="1u")
    parser.add_argument("--stop-time", default="160n")
    parser.add_argument("--max-step", default="20p")
    parser.add_argument("--gate-driver", choices=("ideal", "pdk"), default="ideal")
    parser.add_argument("--driver-fingers", type=int, default=4)
    parser.add_argument("--switch-node-cap", default="0p")
    parser.add_argument("--dead-time", default="1n")
    parser.add_argument("--edge-time", default="100p")
    parser.add_argument("--passive-model", choices=("ideal", "estimated"), default="ideal")
    parser.add_argument("--corners", nargs="+", choices=tuple(CORNER_SECTIONS), default=tuple(CORNER_SECTIONS))
    args = parser.parse_args()

    run_root = args.run_root.resolve()
    run_root.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for corner in args.corners:
        sections = CORNER_SECTIONS[corner]
        for temperature_c in (0.0, 25.0, 85.0):
            for vdd_v in (1.14, 1.20, 1.26):
                label = f"{corner}_t{temperature_c:g}_v{vdd_v:.2f}".replace(".", "p")
                run_dir = run_root / label
                invoke(
                    [
                        str(RUNNER),
                        "--run-dir",
                        str(run_dir),
                        "--sections",
                        sections,
                        "--fingers",
                        str(args.fingers),
                        "--nmos-w",
                        args.nmos_w,
                        "--pmos-w",
                        args.pmos_w,
                        "--temperature-c",
                        str(temperature_c),
                        "--vdd",
                        str(vdd_v),
                        "--stop-time",
                        args.stop_time,
                        "--max-step",
                        args.max_step,
                        "--gate-driver",
                        args.gate_driver,
                        "--driver-fingers",
                        str(args.driver_fingers),
                        "--switch-node-cap",
                        args.switch_node_cap,
                        "--dead-time",
                        args.dead_time,
                        "--edge-time",
                        args.edge_time,
                        "--passive-model",
                        args.passive_model,
                    ]
                )
                invoke([str(ANALYZER), "--run-dir", str(run_dir)])
                metrics = json.loads((run_dir / "analysis_summary.json").read_text(encoding="utf-8"))
                rows.append({"corner": corner, "temperature_c": temperature_c, "vdd_v": vdd_v, **metrics})

    summary = run_root / "summary.csv"
    with summary.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"PVT matrix PASS: {len(rows)} cases -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
