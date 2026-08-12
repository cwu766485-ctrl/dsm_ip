#!/usr/bin/env python3
"""Run a local TSMC40 RF-MOS H-bridge switch-core transient in ADS.

This is a reproducible circuit-level pre-layout flow.  It uses a local PDK
through ``TSMC40_PDK_ROOT`` and writes every netlist, dataset, and simulator
log under the ignored ADS simulation directory.  It does not copy any PDK
collateral into the repository.

The first configuration deliberately uses ideal gate voltage sources.  It
validates the PDK switch core, explicit non-overlap, 100-ohm differential
bridge plane, and a 2:1 impedance-transforming path to a 50-ohm output.  A
PDK gate driver and layout parasitics are separate follow-on work.
"""

from __future__ import annotations

import argparse
import csv
import os
import re
import statistics
import subprocess
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
DEFAULT_RUN_DIR = REPO / "ads" / "low_power_dpa" / "simulation" / "tsmc40_dpa_switch_core_tt"
DEFAULT_SECTIONS = "stat,global_RFMOS,TT_RFMOS,Total_RF_MOS"
DEFAULT_PWL_FILE = REPO / "ads" / "low_power_dpa" / "data" / "rf_bit_samples.csv"


def parse_time_seconds(value: str) -> float:
    """Convert a compact SPICE time value to seconds for waveform generation."""
    match = re.fullmatch(r"\s*([0-9]*\.?[0-9]+(?:[eE][-+]?\d+)?)\s*(s|ms|m|us|u|ns|n|ps|p)?\s*", value)
    if match is None:
        raise RuntimeError(f"Invalid time value: {value}")
    scale = {None: 1.0, "s": 1.0, "ms": 1e-3, "m": 1e-3, "us": 1e-6,
             "u": 1e-6, "ns": 1e-9, "n": 1e-9, "ps": 1e-12, "p": 1e-12}
    return float(match.group(1)) * scale[match.group(2)]


def periodic_gate_sources(dead_s: float, edge_s: float) -> tuple[tuple[str, str], ...]:
    """Create one 25 MHz differential commutation period with explicit all-off gaps."""
    half_s = 20e-9
    period_s = 40e-9
    if dead_s <= edge_s or dead_s >= half_s:
        raise RuntimeError("Dead time must be larger than edge time and shorter than a half period.")
    on_s = half_s - dead_s
    return (
        ("ap", f"PULSE(0 1.2 {on_s:.12g} {edge_s:.12g} {edge_s:.12g} {half_s + dead_s:.12g} {period_s:.12g})"),
        ("an", f"PULSE(0 1.2 {half_s:.12g} {edge_s:.12g} {edge_s:.12g} {on_s:.12g} {period_s:.12g})"),
        ("bp", f"PULSE(1.2 0 {half_s:.12g} {edge_s:.12g} {edge_s:.12g} {on_s:.12g} {period_s:.12g})"),
        ("bn", f"PULSE(0 1.2 0 {edge_s:.12g} {edge_s:.12g} {on_s:.12g} {period_s:.12g})"),
    )


def load_rf_bits(path: Path, count: int) -> tuple[list[float], list[int], float]:
    if not path.is_file():
        raise RuntimeError(f"DSM PWL input file was not found: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    rows = rows[:count]
    if len(rows) < 16:
        raise RuntimeError("DSM PWL input must provide at least 16 samples.")
    try:
        times = [float(row["time_s"]) for row in rows]
        bits = [int(float(row["rf_bit"])) for row in rows]
    except KeyError as error:
        raise RuntimeError("DSM PWL input requires time_s and rf_bit columns.") from error
    if any(bit not in (0, 1) for bit in bits) or any(b <= a for a, b in zip(times, times[1:])):
        raise RuntimeError("DSM PWL input must contain increasing binary samples.")
    return times, bits, statistics.median([b - a for a, b in zip(times, times[1:])])


def hspice_pwl(points: list[tuple[float, float]]) -> str:
    tokens: list[str] = []
    for time_s, voltage_v in points:
        tokens.extend((f"{time_s:.12g}", f"{voltage_v:.12g}"))
    return "PWL(" + " ".join(tokens) + ")"


def make_gate_pwls(
    times: list[float], bits: list[int], period_s: float, dead_s: float, edge_s: float
) -> tuple[dict[str, str], float]:
    if dead_s <= edge_s:
        raise RuntimeError("Dead time must be larger than the PWL edge time.")
    kinds = {"ap": "p", "an": "n", "bp": "p", "bn": "n"}

    def state(bit: int) -> dict[str, float]:
        # bit=1 drives the A-high/B-low diagonal; bit=0 drives the opposite.
        return {"ap": 0.0 if bit else 1.2, "an": 0.0 if bit else 1.2,
                "bp": 1.2 if bit else 0.0, "bn": 1.2 if bit else 0.0}

    current = state(bits[0])
    points = {name: [(0.0, value)] for name, value in current.items()}
    for time_s, bit in zip(times[1:], bits[1:]):
        target = state(bit)
        if target == current:
            continue
        for name, old_value in current.items():
            new_value = target[name]
            if old_value == new_value:
                continue
            is_turning_off = (kinds[name] == "p" and old_value < new_value) or (
                kinds[name] == "n" and old_value > new_value
            )
            if is_turning_off:
                points[name].extend(((time_s - edge_s, old_value), (time_s, new_value)))
            else:
                points[name].extend(
                    ((time_s + dead_s - edge_s, old_value), (time_s + dead_s, new_value))
                )
        current = target
    stop_s = times[-1] + period_s
    for name, value in current.items():
        points[name].append((stop_s, value))
    return {name: hspice_pwl(value) for name, value in points.items()}, stop_s


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pdk-root", type=Path, default=os.environ.get("TSMC40_PDK_ROOT"))
    parser.add_argument(
        "--model-deck",
        default="models/hspice/crn40lp_2d5_v2d0_2.l",
        help="PDK-relative HSPICE RF-MOS model deck.",
    )
    parser.add_argument("--sections", default=DEFAULT_SECTIONS)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--stop-time", default=None, help="Transient stop time, in HSPICE notation.")
    parser.add_argument("--max-step", default="20p", help="Maximum transient step, in HSPICE notation.")
    parser.add_argument("--vdd", type=float, default=1.2, help="Supply voltage in volts.")
    parser.add_argument("--temperature-c", type=float, default=25.0, help="Circuit temperature in degrees Celsius.")
    parser.add_argument("--nmos-w", default="1u", help="NMOS RF subcircuit width parameter.")
    parser.add_argument("--pmos-w", default="1u", help="PMOS RF subcircuit width parameter.")
    parser.add_argument("--fingers", type=int, default=16, help="RF subcircuit finger-count parameter.")
    parser.add_argument(
        "--gate-driver",
        choices=("ideal", "pdk"),
        default="ideal",
        help="Use direct ideal control sources or two PDK-CMOS inverter stages per gate.",
    )
    parser.add_argument("--driver-fingers", type=int, default=4, help="PDK gate-driver inverter finger count.")
    parser.add_argument(
        "--switch-node-cap",
        default="0p",
        help="Estimated external capacitance from each switch node to ground, in HSPICE notation.",
    )
    parser.add_argument("--l-bpf", default="3.18u", help="Series BPF inductance, in HSPICE notation.")
    parser.add_argument("--c-bpf", default="12.7p", help="Series BPF capacitance, in HSPICE notation.")
    parser.add_argument("--l-pri", default="1u", help="Transformer primary inductance, in HSPICE notation.")
    parser.add_argument("--l-sec", default="0.5u", help="Transformer secondary inductance, in HSPICE notation.")
    parser.add_argument("--output-load-ohm", type=float, default=50.0, help="Single-ended secondary load in ohms.")
    parser.add_argument("--pwl-file", type=Path, help="MATLAB-generated rf_bit CSV for non-periodic DSM drive.")
    parser.add_argument("--pwl-samples", type=int, default=256, help="Number of CSV samples used by --pwl-file.")
    parser.add_argument("--dead-time", default="1n", help="PWL non-overlap time, in HSPICE notation.")
    parser.add_argument("--edge-time", default="100p", help="PWL transition time, in HSPICE notation.")
    parser.add_argument(
        "--passive-model",
        choices=("ideal", "estimated"),
        default="ideal",
        help="Ideal transformer or an explicitly estimated lossy transformer/matching proxy.",
    )
    parser.add_argument("--transformer-k", type=float, default=None, help="Transformer coupling coefficient.")
    parser.add_argument("--bpf-series-r", type=float, default=None, help="BPF series-loss estimate in ohms.")
    parser.add_argument("--primary-series-r", type=float, default=None, help="Primary winding loss estimate in ohms.")
    parser.add_argument("--secondary-series-r", type=float, default=None, help="Secondary winding loss estimate in ohms.")
    args = parser.parse_args()

    if args.pdk_root is None:
        raise RuntimeError("Set TSMC40_PDK_ROOT to the local extracted PDK root.")
    if args.output_load_ohm <= 0.0:
        raise RuntimeError("--output-load-ohm must be positive.")
    pdk_root = args.pdk_root.resolve()
    model_deck = pdk_root / args.model_deck
    if not model_deck.is_file():
        raise RuntimeError("TSMC40 HSPICE RF-MOS deck was not found under the supplied PDK root.")

    hpeesof_dir = os.environ.get("HPEESOF_DIR")
    if not hpeesof_dir:
        raise RuntimeError("HPEESOF_DIR is not set. Start from an ADS 2025 environment.")
    simulator = Path(hpeesof_dir) / "bin" / "hpeesofsim.exe"
    if not simulator.is_file():
        raise RuntimeError("ADS simulator was not found under HPEESOF_DIR.")

    sections = [section.strip() for section in args.sections.split(",") if section.strip()]
    if not sections:
        raise RuntimeError("At least one HSPICE model section is required.")
    run_dir = args.run_dir.resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    deck_path = str(model_deck).replace("\\", "/")
    includes = [f'.lib "{deck_path}" {section}' for section in sections]

    dead_s = parse_time_seconds(args.dead_time)
    edge_s = parse_time_seconds(args.edge_time)
    gate_pulses = periodic_gate_sources(dead_s, edge_s)
    stop_time = args.stop_time or "160n"
    if args.pwl_file is not None:
        times, bits, period_s = load_rf_bits(args.pwl_file.resolve(), args.pwl_samples)
        pwls, stop_s = make_gate_pwls(times, bits, period_s, dead_s, edge_s)
        gate_pulses = tuple((name, pwls[name]) for name, _ in gate_pulses)
        if args.stop_time is None:
            stop_time = f"{stop_s:.12g}"
    drive_lines: list[str] = []
    if args.gate_driver == "ideal":
        drive_lines.extend(f"V_G_{name.upper()} g_{name} 0 {pulse}" for name, pulse in gate_pulses)
    else:
        for name, pulse in gate_pulses:
            raw = f"raw_{name}"
            mid = f"drv_{name}_mid"
            gate = f"g_{name}"
            drive_lines.extend(
                (
                    f"V_G_{name.upper()} {raw} 0 {pulse}",
                    f"X_DRV_{name.upper()}_P1 {mid} {raw} vdd vdd pmos_rf lr=0.04u wr=1u nr={args.driver_fingers} multi=1",
                    f"X_DRV_{name.upper()}_N1 {mid} {raw} 0 0 nmos_rf lr=0.04u wr=1u nr={args.driver_fingers} multi=1",
                    f"X_DRV_{name.upper()}_P2 {gate} {mid} vdd vdd pmos_rf lr=0.04u wr=1u nr={args.driver_fingers} multi=1",
                    f"X_DRV_{name.upper()}_N2 {gate} {mid} 0 0 nmos_rf lr=0.04u wr=1u nr={args.driver_fingers} multi=1",
                )
            )

    transformer_k = args.transformer_k
    bpf_series_r = args.bpf_series_r
    primary_series_r = args.primary_series_r
    secondary_series_r = args.secondary_series_r
    if args.passive_model == "estimated":
        transformer_k = 0.990 if transformer_k is None else transformer_k
        bpf_series_r = 0.20 if bpf_series_r is None else bpf_series_r
        primary_series_r = 0.50 if primary_series_r is None else primary_series_r
        secondary_series_r = 0.25 if secondary_series_r is None else secondary_series_r
    else:
        transformer_k = 0.999 if transformer_k is None else transformer_k

    passive_lines = [
        "* Series BPF plus transformer primary. Tune total series inductance and C_BPF together.",
        f"L_BPF swa bpf {args.l_bpf}",
    ]
    if bpf_series_r is not None and bpf_series_r > 0:
        passive_lines.extend((f"R_BPF bpf bpf_c {bpf_series_r:g}", f"C_BPF bpf_c pri_p {args.c_bpf}"))
    else:
        passive_lines.append(f"C_BPF bpf pri_p {args.c_bpf}")
    if primary_series_r is not None and primary_series_r > 0:
        passive_lines.extend((f"R_PRI pri_p pri_w {primary_series_r:g}", f"L_PRI pri_w swb {args.l_pri}"))
    else:
        passive_lines.append(f"L_PRI pri_p swb {args.l_pri}")
    if secondary_series_r is not None and secondary_series_r > 0:
        passive_lines.extend((f"L_SEC sec_w 0 {args.l_sec}", f"R_SEC sec_w sec_p {secondary_series_r:g}"))
    else:
        passive_lines.append(f"L_SEC sec_p 0 {args.l_sec}")
    passive_lines.extend((f"K_OUT L_PRI L_SEC {transformer_k:.6g}", f"R_LOAD sec_p 0 {args.output_load_ohm:g}"))

    # The four independent gate sources make every dead-time interval visible
    # in the netlist. PMOS turns on at a low gate voltage; NMOS at a high one.
    # A and B therefore commutate differentially without overlapping a leg's
    # high-side and low-side switches.
    netlist = "\n".join(
        (
            "simulator lang=spice",
            "* Local TSMC40 RF-MOS differential DPA switch-core, pre-layout circuit proxy.",
            "* 100-ohm differential bridge plane -> sqrt(2):1 turns transformer -> 50 ohm.",
            f"* Output network: L_BPF={args.l_bpf}, C_BPF={args.c_bpf}, L_PRI={args.l_pri}, L_SEC={args.l_sec}, R_LOAD={args.output_load_ohm:g}.",
            *includes,
            ".option post=2",
            f"VDD_SRC vdd 0 {args.vdd:g}",
            f"* Explicit differential gate dead time: {dead_s:.6g} s; edge time: {edge_s:.6g} s.",
            f"* Passive model: {args.passive_model}; values are not extracted balun or package parasitics.",
            *drive_lines,
            f"X_AH swa g_ap vdd vdd pmos_rf lr=0.04u wr={args.pmos_w} nr={args.fingers} multi=1",
            f"X_AL swa g_an 0 0 nmos_rf lr=0.04u wr={args.nmos_w} nr={args.fingers} multi=1",
            f"X_BH swb g_bp vdd vdd pmos_rf lr=0.04u wr={args.pmos_w} nr={args.fingers} multi=1",
            f"X_BL swb g_bn 0 0 nmos_rf lr=0.04u wr={args.nmos_w} nr={args.fingers} multi=1",
            f"C_SWA swa 0 {args.switch_node_cap}",
            f"C_SWB swb 0 {args.switch_node_cap}",
            *passive_lines,
            "simulator lang=ads",
            f"Options Temp={args.temperature_c:g}",
            f"Tran:TRAN1 StartTime=0 StopTime={stop_time} MaxTimeStep={args.max_step}",
            "",
        )
    )
    netlist_path = run_dir / "tsmc40_dpa_switch_core_tt.net"
    netlist_path.write_text(netlist, encoding="ascii")

    result = subprocess.run(
        [str(simulator), str(netlist_path)], cwd=run_dir, text=True, capture_output=True, check=False
    )
    (run_dir / "hpeesofsim.stdout.log").write_text(result.stdout, encoding="utf-8")
    (run_dir / "hpeesofsim.stderr.log").write_text(result.stderr, encoding="utf-8")
    print(f"ADS TSMC40 switch-core return code: {result.returncode}")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)
    print(f"ADS TSMC40 switch-core PASS: {run_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
