#!/usr/bin/env python3
"""Screen a 25 MHz TSMC40 switched-DPA output network before PVT closure.

The screen tunes the series BPF capacitor against the *total* BPF plus
transformer-primary inductance. It ranks valid PDK-MOS cases by 0 dBm target
error, DC-to-load efficiency trend, and peak supply current. This is a
pre-layout sizing screen, not a balun, matching-network, EM, or reliability
signoff.
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
DEFAULT_ROOT = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_25mhz_screen"
TT_SECTIONS = "stat,global_RFMOS,TT_RFMOS,Total_RF_MOS"


def invoke(arguments: list[str]) -> None:
    result = subprocess.run([sys.executable, *arguments], text=True, check=False)
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(arguments)}")


def score(metrics: dict[str, object], target_dbm: float, current_limit_ma: float) -> float:
    power_error = abs(float(metrics["output_50ohm_power_dbm"]) - target_dbm)
    efficiency = float(metrics["efficiency_trend_percent"])
    peak_ma = float(metrics["supply_current_peak_ma"])
    overlap = int(metrics["leg_a_overlap_samples"]) + int(metrics["leg_b_overlap_samples"])
    return 1000.0 * overlap + 100.0 * power_error - efficiency + 10.0 * max(0.0, peak_ma - current_limit_ma)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--fingers", type=int, nargs="+", default=(16, 32, 48))
    parser.add_argument("--driver-fingers", type=int, nargs="+", default=(4, 8))
    parser.add_argument("--c-bpf", nargs="+", default=("8.2p", "9.1p", "9.7p", "10p", "11p"))
    parser.add_argument("--l-bpf", default="3.18u")
    parser.add_argument("--l-pri", default="1u")
    parser.add_argument("--l-sec", default="0.5u")
    parser.add_argument("--dead-time", default="1n")
    parser.add_argument("--edge-time", default="100p")
    parser.add_argument("--switch-node-cap", default="100f")
    parser.add_argument("--target-dbm", type=float, default=0.0)
    parser.add_argument("--current-limit-ma", type=float, default=25.0)
    parser.add_argument("--stop-time", default="160n")
    parser.add_argument("--max-step", default="20p")
    args = parser.parse_args()

    root = args.run_root.resolve()
    root.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for c_bpf in args.c_bpf:
        for fingers in args.fingers:
            for driver_fingers in args.driver_fingers:
                label = f"cbpf_{c_bpf}_nr{fingers}_drv{driver_fingers}".replace(".", "p")
                run_dir = root / label
                invoke([
                    str(RUNNER), "--run-dir", str(run_dir), "--sections", TT_SECTIONS,
                    "--fingers", str(fingers), "--gate-driver", "pdk",
                    "--driver-fingers", str(driver_fingers), "--switch-node-cap", args.switch_node_cap,
                    "--dead-time", args.dead_time, "--edge-time", args.edge_time,
                    "--passive-model", "estimated", "--l-bpf", args.l_bpf, "--c-bpf", c_bpf,
                    "--l-pri", args.l_pri, "--l-sec", args.l_sec, "--stop-time", args.stop_time,
                    "--max-step", args.max_step,
                ])
                invoke([str(ANALYZER), "--run-dir", str(run_dir)])
                metrics = json.loads((run_dir / "analysis_summary.json").read_text(encoding="utf-8"))
                row = {
                    "c_bpf": c_bpf, "l_bpf": args.l_bpf, "l_pri": args.l_pri, "l_sec": args.l_sec,
                    "fingers": fingers, "driver_fingers": driver_fingers, "dead_time": args.dead_time,
                    **metrics,
                }
                row["target_error_db"] = abs(float(row["output_50ohm_power_dbm"]) - args.target_dbm)
                row["screen_score"] = score(metrics, args.target_dbm, args.current_limit_ma)
                rows.append(row)

    rows.sort(key=lambda row: float(row["screen_score"]))
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank
    summary = root / "summary.csv"
    with summary.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    best = rows[0]
    print(
        "25 MHz DPA screen PASS: "
        f"{len(rows)} cases; best rank=1 C_BPF={best['c_bpf']} fingers={best['fingers']} "
        f"driver_fingers={best['driver_fingers']} Pout={float(best['output_50ohm_power_dbm']):.3f} dBm "
        f"eff={float(best['efficiency_trend_percent']):.2f}% -> {summary}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
