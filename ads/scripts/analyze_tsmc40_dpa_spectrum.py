#!/usr/bin/env python3
"""Report repeatable 50-ohm spectral trend proxies for a PDK DPA transient.

The reported adjacent-band ratios are not standard ACLR. They support only a
same-waveform, same-window comparison between DPD candidates before a real
balun, output filter, package, and receiver calibration are available.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from keysight.ads import dds  # DDS must be imported before the dataset API.
from keysight.ads import dataset


REPO = Path(__file__).resolve().parents[2]
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_pdkdrv_estimated_pwl_no_dpd"


def normalized(name: str) -> str:
    return "".join(char for char in name.lower() if char.isalnum())


def column(frame, candidates: list[str]) -> np.ndarray:
    columns = {normalized(name): name for name in frame.columns}
    for candidate in candidates:
        actual = columns.get(normalized(candidate))
        if actual is not None:
            return frame[actual].to_numpy(dtype=float)
    raise KeyError(f"Missing one of {candidates}; found: {', '.join(frame.columns)}")


def band_power(freq_hz: np.ndarray, power_w: np.ndarray, low_hz: float, high_hz: float) -> float:
    return float(np.sum(power_w[(freq_hz >= low_hz) & (freq_hz <= high_hz)]))


def db_ratio(value_w: float, reference_w: float) -> float | None:
    if value_w <= 0.0 or reference_w <= 0.0:
        return None
    return float(10.0 * np.log10(value_w / reference_w))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--dataset", default="tsmc40_dpa_switch_core_tt.net.ds")
    parser.add_argument("--center-hz", type=float, default=25e6)
    parser.add_argument("--channel-half-bandwidth-hz", type=float, default=0.25e6)
    parser.add_argument("--adjacent-inner-offset-hz", type=float, default=0.50e6)
    parser.add_argument("--adjacent-outer-offset-hz", type=float, default=2.50e6)
    parser.add_argument("--settling-s", type=float, default=0.20e-6)
    parser.add_argument("--analysis-sample-hz", type=float, default=1e9)
    args = parser.parse_args()

    path = args.run_dir.resolve() / args.dataset
    with dataset.open(path) as ds:
        frame = ds["TRAN1.TRAN"].to_dataframe()
    time_s = frame.index.to_numpy(dtype=float)
    vout = column(frame, ["secp", "v.secp"])
    if not 0.0 <= args.settling_s < time_s[-1]:
        raise RuntimeError("--settling-s must be within the transient interval.")
    keep = time_s >= args.settling_s
    time_s, vout = time_s[keep], vout[keep]
    count = int(np.floor((time_s[-1] - time_s[0]) * args.analysis_sample_hz))
    if count < 1024:
        raise RuntimeError("Analysis window is too short for a spectral trend.")
    uniform_time = time_s[0] + np.arange(count) / args.analysis_sample_hz
    uniform_v = np.interp(uniform_time, time_s, vout)
    window = np.hanning(count)
    spectrum = np.fft.rfft((uniform_v - np.mean(uniform_v)) * window)
    frequency_hz = np.fft.rfftfreq(count, 1.0 / args.analysis_sample_hz)
    power_w = np.abs(spectrum) ** 2 / (count * np.sum(window**2) * 50.0)
    if power_w.size > 2:
        power_w[1:-1] *= 2.0
    c, h = args.center_hz, args.channel_half_bandwidth_hz
    inband = band_power(frequency_hz, power_w, c - h, c + h)
    lower = band_power(frequency_hz, power_w, c - args.adjacent_outer_offset_hz, c - args.adjacent_inner_offset_hz)
    upper = band_power(frequency_hz, power_w, c + args.adjacent_inner_offset_hz, c + args.adjacent_outer_offset_hz)
    third = band_power(frequency_hz, power_w, 3*c - h, 3*c + h)
    summary = {
        "measurement_plane": "50 ohm single-ended estimated-transformer secondary",
        "classification": "spectral trend proxy, not standard ACLR",
        "analysis_duration_s": float(count / args.analysis_sample_hz),
        "frequency_resolution_hz": float(args.analysis_sample_hz / count),
        "inband_power_mw": 1e3 * inband,
        "lower_adjacent_to_inband_dbc": db_ratio(lower, inband),
        "upper_adjacent_to_inband_dbc": db_ratio(upper, inband),
        "third_harmonic_to_inband_dbc": db_ratio(third, inband),
    }
    np.savetxt(path.parent / "spectrum_power.csv", np.column_stack((frequency_hz, power_w)),
               delimiter=",", header="frequency_hz,power_w", comments="")
    (path.parent / "spectrum_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print("ADS TSMC40 DPA spectral trend PASS")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
