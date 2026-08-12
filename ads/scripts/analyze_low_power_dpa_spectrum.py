#!/usr/bin/env python3
"""Extract reproducible power and spectrum trends from an ADS DPA transient."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from keysight.ads import dds  # Dataset requires DDS to be imported first.
from keysight.ads import dataset


REPO = Path(__file__).resolve().parents[2]
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "low_power_dpa_api_v16_pwl_clamped_tran"


def db_ratio(numerator_w: float, denominator_w: float) -> float | None:
    if numerator_w <= 0.0 or denominator_w <= 0.0:
        return None
    return float(10.0 * np.log10(numerator_w / denominator_w))


def band_power(frequency_hz: np.ndarray, power_w: np.ndarray, low_hz: float, high_hz: float) -> float:
    return float(np.sum(power_w[(frequency_hz >= low_hz) & (frequency_hz <= high_hz)]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--cell", default="low_power_dpa_api_v16")
    parser.add_argument("--load-ohm", type=float, default=100.0)
    parser.add_argument("--center-hz", type=float, default=25.0e6)
    parser.add_argument("--channel-half-bandwidth-hz", type=float, default=0.25e6)
    parser.add_argument("--adjacent-inner-offset-hz", type=float, default=0.50e6)
    parser.add_argument("--adjacent-outer-offset-hz", type=float, default=2.50e6)
    parser.add_argument("--settling-s", type=float, default=0.25e-6)
    parser.add_argument("--analysis-sample-hz", type=float, default=1.0e9)
    args = parser.parse_args()
    args.run_dir = args.run_dir.resolve()

    dataset_path = args.run_dir / f"{args.cell}.ds"
    if not dataset_path.is_file():
        raise RuntimeError(f"ADS dataset not found: {dataset_path}")
    with dataset.open(dataset_path) as ds:
        frame = ds["TRAN1.TRAN"].to_dataframe()

    required = {"SW_B", "BPF_OUT", "VDD", "VDD_SRC.i"}
    missing = required.difference(frame.columns)
    if missing:
        raise RuntimeError(f"ADS dataset is missing: {', '.join(sorted(missing))}")

    time_s = frame.index.to_numpy(dtype=float)
    load_diff_v = frame["BPF_OUT"].to_numpy(dtype=float) - frame["SW_B"].to_numpy(dtype=float)
    supply_v = frame["VDD"].to_numpy(dtype=float)
    supply_i_a = frame["VDD_SRC.i"].to_numpy(dtype=float)
    if args.settling_s >= time_s[-1]:
        raise RuntimeError("settling time must be shorter than the transient window")

    keep = time_s >= args.settling_s
    time_s = time_s[keep]
    load_diff_v = load_diff_v[keep]
    supply_v = supply_v[keep]
    supply_i_a = supply_i_a[keep]
    uniform_count = int(np.floor((time_s[-1] - time_s[0]) * args.analysis_sample_hz))
    if uniform_count < 1024:
        raise RuntimeError("analysis window is too short for the requested sample rate")
    uniform_time_s = time_s[0] + np.arange(uniform_count) / args.analysis_sample_hz
    uniform_v = np.interp(uniform_time_s, time_s, load_diff_v)

    # Hann-window periodogram.  It is appropriate for the modulated waveform
    # and produces band-power trends rather than an unsupported EVM/ACLR claim.
    count = uniform_v.size
    window = np.hanning(count)
    spectrum = np.fft.rfft((uniform_v - np.mean(uniform_v)) * window)
    frequency_hz = np.fft.rfftfreq(count, d=1.0 / args.analysis_sample_hz)
    power_w = np.abs(spectrum) ** 2 / (count * np.sum(window**2) * args.load_ohm)
    if power_w.size > 2:
        power_w[1:-1] *= 2.0

    center = args.center_hz
    half_bw = args.channel_half_bandwidth_hz
    inband_w = band_power(frequency_hz, power_w, center - half_bw, center + half_bw)
    lower_adjacent_w = band_power(
        frequency_hz,
        power_w,
        center - args.adjacent_outer_offset_hz,
        center - args.adjacent_inner_offset_hz,
    )
    upper_adjacent_w = band_power(
        frequency_hz,
        power_w,
        center + args.adjacent_inner_offset_hz,
        center + args.adjacent_outer_offset_hz,
    )
    third_harmonic_w = band_power(frequency_hz, power_w, 3.0 * center - half_bw, 3.0 * center + half_bw)
    duration_s = time_s[-1] - time_s[0]
    dc_power_w = float(np.trapz(supply_v * supply_i_a, time_s) / duration_s)
    load_power_w = float(np.trapz(load_diff_v**2, time_s) / duration_s / args.load_ohm)
    summary = {
        "measurement_plane": "100 ohm differential pre-balun",
        "analysis_start_s": float(time_s[0]),
        "analysis_duration_s": float(uniform_count / args.analysis_sample_hz),
        "analysis_sample_hz": args.analysis_sample_hz,
        "frequency_resolution_hz": float(args.analysis_sample_hz / uniform_count),
        "load_power_mw": 1.0e3 * load_power_w,
        "dc_power_mw": 1.0e3 * dc_power_w,
        "efficiency_trend_percent": float(100.0 * load_power_w / dc_power_w) if dc_power_w > 0.0 else None,
        "inband_power_mw": 1.0e3 * inband_w,
        "lower_adjacent_power_mw": 1.0e3 * lower_adjacent_w,
        "upper_adjacent_power_mw": 1.0e3 * upper_adjacent_w,
        "lower_adjacent_to_inband_dbc": db_ratio(lower_adjacent_w, inband_w),
        "upper_adjacent_to_inband_dbc": db_ratio(upper_adjacent_w, inband_w),
        "third_harmonic_power_mw": 1.0e3 * third_harmonic_w,
        "third_harmonic_to_inband_dbc": db_ratio(third_harmonic_w, inband_w),
    }

    np.savetxt(
        args.run_dir / "spectrum_power.csv",
        np.column_stack((frequency_hz, power_w)),
        delimiter=",",
        header="frequency_hz,power_w",
        comments="",
    )
    (args.run_dir / "spectrum_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print("ADS DPA spectrum analysis PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
