#!/usr/bin/env python3
"""Screen a generic finite-loss switched DPA from the project DSM waveform.

This PDK-independent numerical model is used only while ADS transient is not
available. It keeps the one-bit 100 MHz DSM input, a 25 MHz series-LC output
network, and a 100 ohm differential load. Finite switch resistance, LC loss,
switch-node charging, and gate-drive energy are explicitly included. It emits
an analog-equivalent voltage/current observation for later MATLAB import.

It is a system-model efficiency trend, not an ADS, PDK, layout, or silicon
result. The frozen winning point must be cross-checked with ADS when its
transient feature is available.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np


REPO = Path(__file__).resolve().parents[2]
DEFAULT_BITS = REPO / "ads" / "low_power_dpa" / "data" / "rf_bit_samples.csv"
DEFAULT_OUT = REPO / "ads" / "low_power_dpa" / "data" / "generic_dpa_loss_model"


def read_bits(path: Path) -> tuple[np.ndarray, np.ndarray]:
    with path.open(newline="", encoding="ascii") as handle:
        rows = list(csv.DictReader(handle))
    return (np.asarray([float(row["time_s"]) for row in rows]),
            np.asarray([float(row["rf_signed"]) for row in rows]))


def rlc_step(current_a: float, capacitor_v: float, source_v: float,
             dt_s: float, l_h: float, c_f: float, resistance_ohm: float) -> tuple[float, float]:
    """Advance the series-RLC state by a fourth-order Runge-Kutta step."""
    def derivative(i_a: float, vc_v: float) -> tuple[float, float]:
        return ((source_v - resistance_ohm * i_a - vc_v) / l_h, i_a / c_f)

    k1_i, k1_v = derivative(current_a, capacitor_v)
    k2_i, k2_v = derivative(current_a + 0.5 * dt_s * k1_i,
                             capacitor_v + 0.5 * dt_s * k1_v)
    k3_i, k3_v = derivative(current_a + 0.5 * dt_s * k2_i,
                             capacitor_v + 0.5 * dt_s * k2_v)
    k4_i, k4_v = derivative(current_a + dt_s * k3_i,
                             capacitor_v + dt_s * k3_v)
    return (current_a + dt_s * (k1_i + 2.0 * k2_i + 2.0 * k3_i + k4_i) / 6.0,
            capacitor_v + dt_s * (k1_v + 2.0 * k2_v + 2.0 * k3_v + k4_v) / 6.0)


def synthesize_bridge_source(time_s: np.ndarray, rf_signed: np.ndarray, vdd: float,
                             dead_time_s: float, oversample: int) -> tuple[np.ndarray, np.ndarray]:
    """Expand held DSM bits to a bridge source with explicit all-off dead time."""
    bit_dt = float(np.median(np.diff(time_s)))
    dt = bit_dt / oversample
    source = np.repeat(vdd * rf_signed, oversample)
    dead_samples = max(0, int(round(dead_time_s / dt)))
    if dead_samples:
        changes = np.flatnonzero(np.diff(rf_signed) != 0.0) + 1
        for change in changes:
            start = change * oversample
            source[start:start + dead_samples] = 0.0
    fine_time = time_s[0] + np.arange(source.size) * dt
    return fine_time, source


def evaluate(time_s: np.ndarray, rf_signed: np.ndarray, *, name: str, vdd: float,
             ron: float, c_node: float, r_l: float, c_gate: float,
             r_load: float, l_h: float, c_f: float, dead_time_s: float,
             oversample: int = 10) -> tuple[dict[str, object], np.ndarray, np.ndarray, np.ndarray]:
    bit_dt = float(np.median(np.diff(time_s)))
    fine_time, v_source = synthesize_bridge_source(time_s, rf_signed, vdd,
                                                    dead_time_s, oversample)
    dt = bit_dt / oversample
    fs = 1.0 / dt
    r_series = 2.0 * ron + r_l
    current_a = 0.0
    capacitor_v = 0.0
    i_load = np.empty(v_source.size)
    for index, source_v in enumerate(v_source):
        current_a, capacitor_v = rlc_step(current_a, capacitor_v, source_v,
                                           dt, l_h, c_f, r_series + r_load)
        i_load[index] = current_a
    v_out = r_load * i_load
    i_load = v_out / r_load
    p_out = float(np.mean(v_out**2) / r_load)
    p_cond = float(np.mean(i_load**2) * r_series)
    transitions = int(np.count_nonzero(np.diff(rf_signed) != 0.0))
    duration_s = float(time_s[-1] - time_s[0] + bit_dt)
    transition_rate = transitions / duration_s
    # Two bridge nodes are charged/discharged per diagonal transition.
    p_switch = 2.0 * c_node * vdd**2 * transition_rate
    # Four gate controls toggle; Cgate is a declared generic total per gate.
    p_driver = 4.0 * c_gate * vdd**2 * transition_rate
    p_dc = p_out + p_cond + p_switch + p_driver
    i_dc = np.full(v_out.size, p_dc / vdd)
    f0 = 1.0 / (2.0 * np.pi * np.sqrt(l_h * c_f))
    metrics: dict[str, object] = {
        "candidate": name,
        "classification": "generic finite-loss numerical DPA trend, not ADS/PDK/silicon",
        "vdd_v": vdd,
        "switch_ron_ohm": ron,
        "switch_node_cap_f": c_node,
        "gate_cap_f": c_gate,
        "lc_series_loss_ohm": r_l,
        "load_ohm_differential": r_load,
        "l_h": l_h,
        "c_f": c_f,
        "lc_resonance_hz": f0,
        "dead_time_ns": dead_time_s * 1e9,
        "observation_sample_rate_hz": fs,
        "observation_samples": int(v_out.size),
        "dsm_sample_rate_hz": 1.0 / bit_dt,
        "dsm_samples": int(rf_signed.size),
        "time_domain_solver": "series-RLC RK4 with held DSM bits and all-off dead time",
        "rf_bit_transition_rate_hz": transition_rate,
        "output_rms_v": float(np.sqrt(np.mean(v_out**2))),
        "output_peak_v": float(np.max(np.abs(v_out))),
        "pout_mw": 1e3 * p_out,
        "pout_dbm": float(10.0 * np.log10(p_out / 1e-3)),
        "pdc_mw": 1e3 * p_dc,
        "conduction_loss_mw": 1e3 * p_cond,
        "switching_loss_mw": 1e3 * p_switch,
        "driver_loss_mw": 1e3 * p_driver,
        "efficiency_percent": 100.0 * p_out / p_dc,
        "dc_current_mean_ma": 1e3 * p_dc / vdd,
    }
    return metrics, fine_time, v_out, i_dc


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rf-bits", type=Path, default=DEFAULT_BITS)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--vdd", type=float, default=3.3,
                        help="Declared H-bridge supply in volts (default: 3.3).")
    parser.add_argument("--load-ohm", type=float, default=100.0,
                        help="Differential bridge-side load in ohms (default: 100).")
    args = parser.parse_args()
    time_s, rf_signed = read_bits(args.rf_bits)
    candidates = (
        ("conservative", 0.50, 2.0e-12, 0.30e-12),
        ("balanced", 0.20, 1.0e-12, 0.20e-12),
        ("low_loss", 0.10, 0.5e-12, 0.10e-12),
    )
    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, object]] = []
    for name, ron, c_node, c_gate in candidates:
        metrics, _, _, _ = evaluate(time_s, rf_signed, name=name, vdd=args.vdd,
                                    ron=ron, c_node=c_node, c_gate=c_gate,
                                    r_l=0.20, r_load=args.load_ohm, l_h=3.18e-6,
                                    c_f=12.7e-12, dead_time_s=1e-9)
        rows.append(metrics)
    rows.sort(key=lambda row: float(row["efficiency_percent"]), reverse=True)
    for rank, row in enumerate(rows, start=1):
        row["rank"] = rank
    winner = rows[0]
    winner_metrics, winner_time, winner_vout, winner_idc = evaluate(
        time_s, rf_signed, name=str(winner["candidate"]), vdd=args.vdd,
        ron=float(winner["switch_ron_ohm"]), c_node=float(winner["switch_node_cap_f"]),
        c_gate=float(winner["gate_cap_f"]), r_l=0.20, r_load=args.load_ohm,
        l_h=3.18e-6, c_f=12.7e-12, dead_time_s=1e-9,
    )
    with (args.out_dir / "summary.csv").open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    np.savetxt(args.out_dir / "winner_observation.csv",
               np.column_stack((winner_time, winner_vout, winner_idc)), delimiter=",",
               header="time_s,vout_v,ivdd_a", comments="")
    (args.out_dir / "summary.json").write_text(json.dumps({"winner": winner_metrics, "all": rows}, indent=2) + "\n", encoding="ascii")
    print(json.dumps({"winner": winner_metrics, "all": rows}, indent=2))
    print("Generic finite-loss DPA screen PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
