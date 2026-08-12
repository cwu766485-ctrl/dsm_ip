#!/usr/bin/env python3
"""Sweep PDK gate-driver dead time over representative DPA PVT conditions.

The script uses the local TSMC40 PDK through the runner environment and writes
only generated data under the ignored ADS simulation directory. The
transformer/matching option is an explicitly estimated loss model, never an
extracted balun, package, or PCB result.
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
DEFAULT_ROOT = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_pdk_driver_deadtime"
PVT = {
    "tt_nom": ("stat,global_RFMOS,TT_RFMOS,Total_RF_MOS", 25.0, 1.20),
    "ss_hot_low": ("stat,global_RFMOS,SS_RFMOS,Total_RF_MOS", 85.0, 1.14),
    "ff_cold_high": ("stat,global_RFMOS,FF_RFMOS,Total_RF_MOS", 0.0, 1.26),
}


def invoke(arguments: list[str]) -> None:
    result = subprocess.run([sys.executable, *arguments], text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"Failed ({result.returncode}): {' '.join(arguments)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--fingers", type=int, default=16)
    parser.add_argument("--driver-fingers", type=int, default=4)
    parser.add_argument("--switch-node-cap", default="100f")
    parser.add_argument("--passive-model", choices=("ideal", "estimated"), default="estimated")
    parser.add_argument("--dead-times-ns", type=float, nargs="+", default=(0.5, 1.0, 1.5, 2.0))
    parser.add_argument("--pvt", nargs="+", choices=tuple(PVT), default=tuple(PVT), help="PVT labels to run.")
    parser.add_argument("--stop-time", default="160n")
    parser.add_argument("--max-step", default="20p")
    args = parser.parse_args()

    root = args.run_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for label in args.pvt:
        sections, temp_c, vdd_v = PVT[label]
        for dead_ns in args.dead_times_ns:
            run_dir = root / f"{label}_dead{dead_ns:g}ns".replace(".", "p")
            invoke([
                str(RUNNER), "--run-dir", str(run_dir), "--sections", sections,
                "--fingers", str(args.fingers), "--temperature-c", str(temp_c),
                "--vdd", str(vdd_v), "--gate-driver", "pdk", "--driver-fingers",
                str(args.driver_fingers), "--switch-node-cap", args.switch_node_cap,
                "--dead-time", f"{dead_ns:g}n", "--passive-model", args.passive_model,
                "--stop-time", args.stop_time, "--max-step", args.max_step,
            ])
            invoke([str(ANALYZER), "--run-dir", str(run_dir)])
            metrics = json.loads((run_dir / "analysis_summary.json").read_text(encoding="utf-8"))
            rows.append({"pvt": label, "dead_time_ns": dead_ns, "temperature_c": temp_c,
                         "vdd_v": vdd_v, "passive_model": args.passive_model, **metrics})

    summary = root / "summary.csv"
    with summary.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"PDK driver dead-time sweep PASS: {len(rows)} cases -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
