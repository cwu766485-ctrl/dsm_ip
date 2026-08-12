#!/usr/bin/env python3
"""Run the local TSMC40 DPA switch-core RF-MOS finger-count sweep.

This screen holds the pre-layout topology fixed at TT, 25 C, and 1.2 V, then
compares PDK-valid RF-MOS finger counts.  It writes generated data below the
ignored ADS simulation tree and never packages PDK collateral.
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
DEFAULT_ROOT = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_size_tt"


def invoke(arguments: list[str]) -> None:
    completed = subprocess.run([sys.executable, *arguments], text=True, check=False)
    if completed.returncode != 0:
        raise RuntimeError(f"Command failed with return code {completed.returncode}: {' '.join(arguments)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--nmos-w", default="1u")
    parser.add_argument("--pmos-w", default="1u")
    parser.add_argument("--stop-time", default="160n")
    parser.add_argument("--max-step", default="20p")
    parser.add_argument("--fingers", default="4,8,16,32")
    args = parser.parse_args()

    fingers = [int(value.strip()) for value in args.fingers.split(",") if value.strip()]
    if not fingers or any(value <= 0 for value in fingers):
        raise RuntimeError("--fingers must contain positive integers.")
    run_root = args.run_root.resolve()
    run_root.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for finger_count in fingers:
        run_dir = run_root / f"nr{finger_count}"
        invoke(
            [
                str(RUNNER),
                "--run-dir",
                str(run_dir),
                "--fingers",
                str(finger_count),
                "--nmos-w",
                args.nmos_w,
                "--pmos-w",
                args.pmos_w,
                "--stop-time",
                args.stop_time,
                "--max-step",
                args.max_step,
            ]
        )
        invoke([str(ANALYZER), "--run-dir", str(run_dir)])
        metrics = json.loads((run_dir / "analysis_summary.json").read_text(encoding="utf-8"))
        rows.append({"fingers": finger_count, **metrics})

    summary = run_root / "summary.csv"
    with summary.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Size sweep PASS: {len(rows)} cases -> {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
