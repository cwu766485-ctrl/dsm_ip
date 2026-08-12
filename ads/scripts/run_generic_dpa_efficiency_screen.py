#!/usr/bin/env python3
"""Screen a generic 3.3 V switched-DPA circuit without a process PDK.

The source is the checked long PWL ADS ideal-switch H-bridge.  Each candidate
retains the same LPDSM2 100 MHz one-bit waveform, 25 MHz series LC network,
100 ohm differential load, 1 ns non-overlap, and finite switch resistance and
node capacitance.  Results are generic circuit trends only, never PDK or
silicon claims.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
SOURCE_NETLIST = REPO / "ads" / "low_power_dpa" / "simulation" / "low_power_dpa_api_v17_4096bit_pwl_tran" / "low_power_dpa_api_v17.net"
RUN_ROOT = REPO / "ads" / "low_power_dpa" / "simulation" / "generic_dpa_3v3_efficiency_screen"
ANALYZER = REPO / "ads" / "scripts" / "analyze_low_power_dpa_tran.py"


def run_case(source: str, root: Path, name: str, ron: str, cout: str) -> dict[str, object]:
    run_dir = root / name
    run_dir.mkdir(parents=True, exist_ok=True)
    netlist = source.replace("VDD=1.2 V", "VDD=3.3 V")
    netlist = netlist.replace("RON=0.5 Ohm", f"RON={ron}")
    netlist = netlist.replace("COUT=2 pF", f"COUT={cout}")
    netlist = netlist.replace("-1.2V", "-3.3V")
    netlist = netlist.replace('TopDesignName="workspace_lib:low_power_dpa_api_v17:schematic"',
                              f'TopDesignName="generic:{name}"')
    netlist_path = run_dir / f"{name}.net"
    netlist_path.write_text(netlist, encoding="utf-8")
    simulator = Path(os.environ["HPEESOF_DIR"]) / "bin" / "hpeesofsim.exe"
    result = subprocess.run([str(simulator), str(netlist_path)], cwd=run_dir,
                            text=True, capture_output=True, check=False)
    (run_dir / "hpeesofsim.stdout.log").write_text(result.stdout, encoding="utf-8")
    (run_dir / "hpeesofsim.stderr.log").write_text(result.stderr, encoding="utf-8")
    if result.returncode:
        raise RuntimeError(f"{name} transient failed ({result.returncode})")
    observation = REPO / "ads" / "low_power_dpa" / "data" / f"{name}_observation.csv"
    analyze = subprocess.run([sys.executable, str(ANALYZER), "--run-dir", str(run_dir),
                              "--cell", name, "--observation-output", str(observation)],
                             text=True, capture_output=True, check=False)
    (run_dir / "analyze.stdout.log").write_text(analyze.stdout, encoding="utf-8")
    (run_dir / "analyze.stderr.log").write_text(analyze.stderr, encoding="utf-8")
    if analyze.returncode:
        raise RuntimeError(f"{name} analysis failed ({analyze.returncode}): {analyze.stderr}")
    metrics = json.loads((run_dir / "analysis_summary.json").read_text(encoding="utf-8"))
    return {"candidate": name, "vdd_v": 3.3, "ron": ron, "cout": cout, **metrics}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-root", type=Path, default=RUN_ROOT)
    args = parser.parse_args()
    if not os.environ.get("HPEESOF_DIR"):
        raise RuntimeError("Set HPEESOF_DIR before running ADS.")
    if not SOURCE_NETLIST.is_file():
        raise RuntimeError(f"Source generic netlist is missing: {SOURCE_NETLIST}")
    source = SOURCE_NETLIST.read_text(encoding="utf-8")
    root = args.run_root.resolve()
    candidates = (("low_loss", "0.10 Ohm", "0.5 pF"),
                  ("balanced", "0.20 Ohm", "1 pF"),
                  ("conservative", "0.50 Ohm", "2 pF"))
    rows = [run_case(source, root, *candidate) for candidate in candidates]
    rows.sort(key=lambda row: float(row["efficiency_trend_percent"]), reverse=True)
    for index, row in enumerate(rows, start=1):
        row["rank"] = index
    summary = root / "summary.csv"
    with summary.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(json.dumps(rows, indent=2))
    print(f"Generic DPA efficiency screen PASS: {summary}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
