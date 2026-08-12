#!/usr/bin/env python3
"""Compare two ADS DPA candidate directories at one identical circuit endpoint.

This script reports electrical deltas only. It deliberately cannot accept or
reject a DPD coefficient package because its short PWL window lacks coherent
EVM recovery and a standard ACLR mask.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
DEFAULT_ROOT = REPO / "ads" / "low_power_dpa" / "simulation"


def read_summary(directory: Path, filename: str) -> dict[str, object]:
    path = directory.resolve() / filename
    if not path.is_file():
        raise RuntimeError(f"Missing {filename}: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def delta(candidate: dict[str, object], baseline: dict[str, object], key: str) -> float | None:
    left, right = candidate.get(key), baseline.get(key)
    if left is None or right is None:
        return None
    return float(left) - float(right)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-dir", type=Path,
                        default=DEFAULT_ROOT / "tsmc40_dpa_pdkdrv_estimated_pwl_pair_no_dpd")
    parser.add_argument("--candidate-dir", type=Path,
                        default=DEFAULT_ROOT / "tsmc40_dpa_pdkdrv_estimated_pwl_pair_memory_poly5_tap4")
    args = parser.parse_args()
    base = read_summary(args.baseline_dir, "analysis_summary.json")
    candidate = read_summary(args.candidate_dir, "analysis_summary.json")
    base_spectrum = read_summary(args.baseline_dir, "spectrum_summary.json")
    candidate_spectrum = read_summary(args.candidate_dir, "spectrum_summary.json")
    comparison = {
        "measurement_contract": "same PDK driver, passive proxy, PWL length, dead time, and 50-ohm endpoint",
        "classification": "electrical trend comparison only; not an EVM/ACLR or DPD release decision",
        "baseline": str(args.baseline_dir.resolve()),
        "candidate": str(args.candidate_dir.resolve()),
        "output_power_delta_db": delta(candidate, base, "output_50ohm_power_dbm"),
        "dc_power_delta_mw": delta(candidate, base, "dc_power_mw"),
        "efficiency_delta_percent": delta(candidate, base, "efficiency_trend_percent"),
        "peak_current_delta_ma": delta(candidate, base, "supply_current_peak_ma"),
        "inband_power_delta_mw": delta(candidate_spectrum, base_spectrum, "inband_power_mw"),
        "lower_adjacent_delta_dbc": delta(candidate_spectrum, base_spectrum, "lower_adjacent_to_inband_dbc"),
        "upper_adjacent_delta_dbc": delta(candidate_spectrum, base_spectrum, "upper_adjacent_to_inband_dbc"),
        "third_harmonic_delta_dbc": delta(candidate_spectrum, base_spectrum, "third_harmonic_to_inband_dbc"),
        "baseline_overlap_samples": int(base["leg_a_overlap_samples"]) + int(base["leg_b_overlap_samples"]),
        "candidate_overlap_samples": int(candidate["leg_a_overlap_samples"]) + int(candidate["leg_b_overlap_samples"]),
    }
    output = args.candidate_dir.resolve() / "candidate_comparison.json"
    output.write_text(json.dumps(comparison, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(comparison, indent=2))
    print("ADS DPA candidate comparison PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
