#!/usr/bin/env python3
"""Check the ADS low-power DPA transient dataset and export MATLAB feedback."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from keysight.ads import dds  # Dataset requires DDS to be imported first.
from keysight.ads import dataset


REPO = Path(__file__).resolve().parents[2]
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "low_power_dpa_api_v10_tran"
DEFAULT_OBSERVATION = REPO / "ads" / "low_power_dpa" / "data" / "ads_observation.csv"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--cell", default="low_power_dpa_api_v10")
    parser.add_argument("--observation-output", type=Path, default=DEFAULT_OBSERVATION)
    parser.add_argument("--observation-sample-hz", type=float, default=1.0e9)
    args = parser.parse_args()

    dataset_path = args.run_dir / f"{args.cell}.ds"
    if not dataset_path.is_file():
        raise RuntimeError(f"ADS dataset not found: {dataset_path}")
    with dataset.open(dataset_path) as ds:
        frame = ds["TRAN1.TRAN"].to_dataframe()

    required = {"VDD", "SW_A", "SW_B", "BPF_OUT", "VDD_SRC.i", "CTRL_H_A", "CTRL_L_A"}
    missing = required.difference(frame.columns)
    if missing:
        raise RuntimeError(f"ADS dataset is missing: {', '.join(sorted(missing))}")

    time_s = frame.index.to_numpy(dtype=float)
    sw_a = frame["SW_A"].to_numpy(dtype=float)
    sw_b = frame["SW_B"].to_numpy(dtype=float)
    bpf_out = frame["BPF_OUT"].to_numpy(dtype=float)
    ivdd_a = frame["VDD_SRC.i"].to_numpy(dtype=float)
    bridge_diff = sw_a - sw_b
    load_diff = bpf_out - sw_b
    duration_s = time_s[-1] - time_s[0]
    time_mean = lambda values: float(np.trapz(values, time_s) / duration_s)
    vdd_v = time_mean(frame["VDD"].to_numpy(dtype=float))
    output_power_w = time_mean(load_diff**2) / 100.0
    dc_power_w = time_mean(frame["VDD"].to_numpy(dtype=float) * ivdd_a)
    metrics = {
        "samples": int(len(frame)),
        "vdd_v": vdd_v,
        "bridge_diff_pp_v": float(np.ptp(bridge_diff)),
        "load_diff_pp_v": float(np.ptp(load_diff)),
        "load_diff_rms_v": float(np.sqrt(time_mean(load_diff**2))),
        "supply_current_mean_a": time_mean(ivdd_a),
        "supply_current_peak_a": float(np.max(ivdd_a)),
        "dc_power_mw": 1.0e3 * dc_power_w,
        "load_power_mw": 1.0e3 * output_power_w,
        "efficiency_trend_percent": float(100.0 * output_power_w / dc_power_w) if dc_power_w > 0.0 else None,
    }

    # These are smoke bounds, not silicon design targets or PAE claims.
    assert 1.1 < metrics["vdd_v"] < 1.3, "supply polarity or value is invalid"
    assert np.max(frame["CTRL_H_A"].to_numpy()) > 1.1, "high-side gate does not turn on"
    assert np.max(frame["CTRL_L_A"].to_numpy()) > 1.1, "low-side gate does not turn on"
    gate_overlap = np.logical_and(
        frame["CTRL_H_A"].to_numpy(dtype=float) > 0.7,
        frame["CTRL_L_A"].to_numpy(dtype=float) > 0.7,
    )
    assert not np.any(gate_overlap), "bridge-leg gate overlap was observed"
    assert np.max(np.abs(bridge_diff)) < 5.0, "bridge differential voltage exceeds smoke bound"
    assert np.max(np.abs(load_diff)) < 5.0, "load differential voltage exceeds smoke bound"
    assert metrics["load_diff_pp_v"] > 0.05, "load differential output is static"

    args.observation_output.parent.mkdir(parents=True, exist_ok=True)
    observation_count = int(np.floor((time_s[-1] - time_s[0]) * args.observation_sample_hz))
    observation_edges_s = time_s[0] + np.arange(observation_count + 1) / args.observation_sample_hz
    observation_time_s = 0.5 * (observation_edges_s[:-1] + observation_edges_s[1:])
    # Point-sampling ideal-switch current misses narrow switching pulses and
    # corrupts PDC. Export interval-average current from a trapezoidal integral
    # while keeping the voltage waveform at the bin center.
    current_integral_as = np.concatenate(
        (
            np.array([0.0]),
            np.cumsum(0.5 * (ivdd_a[1:] + ivdd_a[:-1]) * np.diff(time_s)),
        )
    )
    edge_integral_as = np.interp(observation_edges_s, time_s, current_integral_as)
    observation_current_a = np.diff(edge_integral_as) * args.observation_sample_hz
    observation = np.column_stack(
        (
            observation_time_s,
            np.interp(observation_time_s, time_s, load_diff),
            observation_current_a,
        )
    )
    np.savetxt(
        args.observation_output,
        observation,
        delimiter=",",
        header="time_s,vout_v,ivdd_a",
        comments="",
    )
    metrics["gate_overlap_samples"] = int(np.count_nonzero(gate_overlap))
    metrics["load_reference"] = "100 ohm differential pre-balun"
    metrics["observation_sample_hz"] = args.observation_sample_hz
    metrics["observation_samples"] = observation_count
    (args.run_dir / "analysis_summary.json").write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=2))
    print("ADS DPA transient analysis PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
