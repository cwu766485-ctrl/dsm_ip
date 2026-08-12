#!/usr/bin/env python3
"""Generate the initial low-power switched-DPA schematic with ADS DE Python.

The script intentionally creates a new cell instead of modifying a hand-edited
schematic.  It uses the ADS Design Environment database API, so the generated
cell is a normal editable ADS schematic rather than an imported netlist.
"""

from __future__ import annotations

import argparse
import csv
import statistics
import sys
from pathlib import Path

from keysight.ads import de
from keysight.ads.de import db_uu
from keysight.ads.de._db.parameters import add_variable_to_var_instance
from keysight.ads.de._db.transaction import Transaction


DEFAULT_WORKSPACE = Path(__file__).resolve().parents[1] / "low_power_dpa" / "workspace"
DEFAULT_SAMPLE_FILE = Path(__file__).resolve().parents[1] / "low_power_dpa" / "data" / "rf_bit_samples.csv"
LIBRARY = "workspace_lib"
VIEW = "schematic"


def set_values(instance, values: dict[str, str]) -> None:
    for name, value in values.items():
        if name not in instance.parameters:
            available = ", ".join(instance.parameters.keys())
            raise RuntimeError(f"{instance.name} has no {name} parameter; available: {available}")
        instance.parameters[name].value = value


def term(instance, pin_number: int):
    return instance.inst_terms[f"{instance.name}.{pin_number}"]


def connect(design, name: str, endpoints: list[tuple[object, int]]):
    net = design.find_or_add_net(name)
    for instance, pin_number in endpoints:
        term(instance, pin_number).net = net
    return net


def wire(design, points: list[tuple[float, float]], label: str | None = None) -> None:
    line = design.add_wire(points)
    if label:
        line.add_wire_label(label, points[len(points) // 2])


def add_instance(design, master: tuple[str, str, str], origin, name: str, values=None):
    instance = design.add_instance(master, origin, name=name)
    if values:
        set_values(instance, values)
    return instance


def require_new_cell(workspace, cell: str) -> None:
    if workspace.libraries[LIBRARY].cell_exists(cell):
        raise RuntimeError(
            f"{LIBRARY}:{cell}:{VIEW} already exists. Choose a different --cell name; "
            "the generator never overwrites an ADS cell."
        )


def load_rf_bit_samples(sample_file: Path) -> tuple[list[float], list[int], float]:
    if not sample_file.is_file():
        raise RuntimeError(f"PWL sample file is missing: {sample_file}")
    with sample_file.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    if len(rows) < 16:
        raise RuntimeError("PWL sample file must contain at least 16 samples")
    try:
        times = [float(row["time_s"]) for row in rows]
        bits = [int(float(row["rf_bit"])) for row in rows]
    except KeyError as error:
        raise RuntimeError("PWL sample file needs time_s and rf_bit columns") from error
    if any(bit not in (0, 1) for bit in bits):
        raise RuntimeError("rf_bit samples must be binary")
    periods = [b - a for a, b in zip(times, times[1:])]
    if any(period <= 0.0 for period in periods):
        raise RuntimeError("PWL sample times must be strictly increasing")
    return times, bits, statistics.median(periods)


def pwl_expression(times: list[float], bits: list[int], active_when_one: bool, dead_s: float, edge_s: float, vdd_v: float) -> str:
    """Create one gate PWL with explicit turn-off, dead time, then turn-on."""
    if dead_s <= edge_s:
        raise RuntimeError("dead time must exceed the PWL edge time")
    points: list[tuple[float, float]] = [(0.0, 0.0)]
    current = False
    for index, (time_s, bit) in enumerate(zip(times, bits)):
        target = bool(bit) if active_when_one else not bool(bit)
        if target == current:
            continue
        if time_s > 0.0:
            points.append((time_s - edge_s, vdd_v if current else 0.0))
            points.append((time_s, 0.0))
        on_time = time_s + dead_s
        points.append((on_time - edge_s, 0.0))
        points.append((on_time, vdd_v if target else 0.0))
        current = target
    end_s = times[-1] + statistics.median([b - a for a, b in zip(times, times[1:])])
    points.append((end_s, vdd_v if current else 0.0))

    # The source terminal orientation is ground -> signal in this schematic,
    # so source voltage is the negative of the desired positive gate voltage.
    tokens = []
    for time_s, voltage_v in points:
        tokens.append(f"{time_s:.12g}sec")
        tokens.append(f"{-voltage_v:.12g}V")
    return "pwl(time, " + ", ".join(tokens) + ")"


def build(workspace_path: Path, cell: str, drive_mode: str, sample_file: Path | None, params: dict[str, str]) -> str:
    workspace = de.open_workspace(str(workspace_path))
    require_new_cell(workspace, cell)
    design = db_uu.create_schematic((LIBRARY, cell, VIEW))

    with Transaction(design, "Generate low-power switched DPA") as transaction:
        variables = design.add_var_instance((2.0, 18.0), name="VAR_DPA")
        tstop = "2.56 usec"
        if drive_mode == "pwl":
            assert sample_file is not None
            sample_times, sample_bits, sample_period_s = load_rf_bit_samples(sample_file)
            tstop = f"{sample_times[-1] + sample_period_s:.12g} sec"
        for name, value in {
            "VDD": params["vdd"],
            "RON": params["ron"],
            "ROFF": "1.0 GOhm",
            "VTH_LO": "0.5 V",
            "VTH_HI": "0.7 V",
            "TR": params["edge"],
            "TDEAD": params["dead_time"],
            "COUT": params["cout"],
            "DIODE_RS": "0.1 Ohm",
            "LBPF": params["lbpf"],
            "CBPF": params["cbpf"],
            "RLOAD": params["rload"],
            "TSTOP": tstop,
        }.items():
            add_variable_to_var_instance(variables, name, value)

        # The whole schematic uses physical wires.  ADS rebuilds connectivity
        # from wire geometry, so explicit local grounds avoid fragile long
        # control/ground buses and make the netlisted circuit unambiguous.
        vdd = add_instance(
            design,
            ("ads_sources", "V_DC", "symbol"),
            (20.0, 15.0),
            "VDD_SRC",
            # ADS V_DC is defined from terminal 1 to terminal 2. Terminal 1
            # is grounded in this cell, so use -VDD to make the named VDD node
            # positive with respect to ground.
            {"Vdc": "-VDD", "SaveCurrent": "1"},
        )
        # SwitchV_Model maps R1 at the low control threshold and R2 at the
        # high control threshold. This maps low gate voltage to OFF and high
        # gate voltage to ON with a small hysteresis for numerical robustness.
        switch_values = {"R1": "ROFF", "V1": "VTH_LO", "R2": "RON", "V2": "VTH_HI"}
        # SwitchV instances reference a separately netlisted switch model.
        # Keep the model instance name aligned with the four Model parameters.
        add_instance(
            design,
            ("ads_behavioral", "SwitchV_Model", "symbol"),
            (5.0, 18.0),
            "SWITCHVM1",
            switch_values,
        )
        ah = add_instance(design, ("ads_behavioral", "SwitchV", "symbol"), (20.0, 12.0), "S_AH", switch_values)
        al = add_instance(design, ("ads_behavioral", "SwitchV", "symbol"), (20.0, 8.0), "S_AL", switch_values)
        bh = add_instance(design, ("ads_behavioral", "SwitchV", "symbol"), (30.0, 12.0), "S_BH", switch_values)
        bl = add_instance(design, ("ads_behavioral", "SwitchV", "symbol"), (30.0, 8.0), "S_BL", switch_values)

        if drive_mode == "pulse":
            # The same source-reference convention applies to VtPulse.
            pulse_hi = {"Vlow": "0 V", "Vhigh": "-VDD", "Delay": "0 nsec", "Rise": "TR", "Fall": "TR", "Width": "19 nsec", "Period": "40 nsec"}
            pulse_lo = {"Vlow": "0 V", "Vhigh": "-VDD", "Delay": "20 nsec", "Rise": "TR", "Fall": "TR", "Width": "19 nsec", "Period": "40 nsec"}
            ctrl_ha = add_instance(design, ("ads_sources", "VtPulse", "symbol"), (17.0, 11.25), "CTRL_H_A", pulse_hi)
            ctrl_la = add_instance(design, ("ads_sources", "VtPulse", "symbol"), (17.0, 4.0), "CTRL_L_A", pulse_lo)
            ctrl_lb = add_instance(design, ("ads_sources", "VtPulse", "symbol"), (27.0, 11.25), "CTRL_L_B", pulse_lo)
            ctrl_hb = add_instance(design, ("ads_sources", "VtPulse", "symbol"), (27.0, 4.0), "CTRL_H_B", pulse_hi)
        else:
            assert sample_file is not None
            vdd_v = float(params["vdd"].split()[0])
            dead_s = float(params["dead_time"].split()[0]) * 1e-9
            edge_s = float(params["edge"].split()[0]) * 1e-12
            pwl_hi = {"V_Tran": pwl_expression(sample_times, sample_bits, True, dead_s, edge_s, vdd_v), "SaveCurrent": "0"}
            pwl_lo = {"V_Tran": pwl_expression(sample_times, sample_bits, False, dead_s, edge_s, vdd_v), "SaveCurrent": "0"}
            ctrl_ha = add_instance(design, ("ads_sources", "VtPWL", "symbol"), (17.0, 11.25), "CTRL_H_A", pwl_hi)
            ctrl_la = add_instance(design, ("ads_sources", "VtPWL", "symbol"), (17.0, 4.0), "CTRL_L_A", pwl_lo)
            ctrl_lb = add_instance(design, ("ads_sources", "VtPWL", "symbol"), (27.0, 11.25), "CTRL_L_B", pwl_lo)
            ctrl_hb = add_instance(design, ("ads_sources", "VtPWL", "symbol"), (27.0, 4.0), "CTRL_H_B", pwl_hi)

        bpf_l = add_instance(design, ("ads_rflib", "L", "symbol"), (2.0, 10.0), "L_BPF", {"L": "LBPF", "R": "0.2 Ohm"})
        bpf_c = add_instance(design, ("ads_rflib", "C", "symbol"), (6.0, 10.0), "C_BPF", {"C": "CBPF"})
        load = add_instance(design, ("ads_rflib", "R", "symbol"), (10.0, 10.0), "R_LOAD", {"R": "RLOAD"})
        c_out_a = add_instance(design, ("ads_rflib", "C", "symbol"), (15.0, 16.0), "C_OUT_A", {"C": "COUT"})
        c_out_b = add_instance(design, ("ads_rflib", "C", "symbol"), (35.0, 4.0), "C_OUT_B", {"C": "COUT"})
        if drive_mode == "pwl":
            # Ideal SwitchV has no MOS body diode.  Explicit rail clamps keep
            # the bridge nodes physical during non-overlap; this is required
            # before interpreting a PWL-driven H-bridge transient result.
            add_instance(
                design,
                ("ads_rflib", "Diode_Model", "symbol"),
                (8.0, 17.0),
                "DIODEM1",
                {"Is": "1e-15 A", "N": "1", "Rs": "DIODE_RS", "Cjo": "COUT"},
            )
            d_a_up = add_instance(design, ("ads_rflib", "Diode", "symbol"), (12.0, 15.0), "D_A_UP")
            d_a_lo = add_instance(design, ("ads_rflib", "Diode", "symbol"), (12.0, 13.0), "D_A_LO")
            d_b_up = add_instance(design, ("ads_rflib", "Diode", "symbol"), (38.0, 15.0), "D_B_UP")
            d_b_lo = add_instance(design, ("ads_rflib", "Diode", "symbol"), (38.0, 13.0), "D_B_LO")
        tran = add_instance(
            design,
            ("ads_simulation", "Tran", "symbol"),
            (4.0, 14.0),
            "TRAN1",
            # A 5 ps maximum step resolves the 100 ps gate edge and the
            # ideal-switch/L-C transient.  A 100 ps step is too coarse and
            # can inject nonphysical energy into the resonator.
            {"StartTime": "0 nsec", "StopTime": "TSTOP", "MaxTimeStep": "5 psec"},
        )

        # Switch pins 1/2 are the current path. Pins 3/4 are control +/-.
        # Local grounds are placed at every return terminal, so the geometry
        # remains valid even when ADS recomputes all physical nets.
        gnd_points = [
            (20.0, 15.0), (17.0, 11.25), (17.0, 4.0), (27.0, 11.25), (27.0, 4.0),
            (20.75, 11.25), (20.75, 7.25), (30.75, 11.25), (30.75, 7.25),
            (21.0, 8.0), (31.0, 8.0), (16.0, 16.0), (36.0, 4.0),
        ]
        for index, point in enumerate(gnd_points):
            add_instance(design, ("ads_rflib", "GROUND", "symbol"), point, f"GND{index}")
        if drive_mode == "pwl":
            add_instance(design, ("ads_rflib", "GROUND", "symbol"), (12.0, 13.0), "GND_D_A_LO")
            add_instance(design, ("ads_rflib", "GROUND", "symbol"), (38.0, 13.0), "GND_D_B_LO")

        wire(design, [(21.0, 15.0), (21.0, 14.0), (20.0, 14.0), (20.0, 12.0)], "VDD")
        wire(design, [(21.0, 15.0), (30.0, 15.0), (30.0, 12.0)], "VDD")
        wire(design, [(21.0, 12.0), (22.0, 12.0), (22.0, 11.0), (15.0, 11.0), (15.0, 14.0), (2.0, 14.0), (2.0, 10.0)], "SW_A")
        wire(design, [(20.0, 8.0), (15.0, 8.0), (15.0, 14.0)], "SW_A")
        wire(design, [(3.0, 10.0), (6.0, 10.0)], "BPF_LC")
        wire(design, [(7.0, 10.0), (10.0, 10.0)], "BPF_OUT")
        wire(design, [(15.0, 16.0), (15.0, 14.0)], "SW_A")
        wire(design, [(35.0, 4.0), (35.0, 6.0)], "SW_B")
        wire(design, [(11.0, 10.0), (11.0, 6.0), (29.0, 6.0), (29.0, 8.0), (30.0, 8.0)], "SW_B")
        wire(design, [(31.0, 12.0), (35.0, 12.0), (35.0, 6.0), (29.0, 6.0)], "SW_B")
        wire(design, [(18.0, 11.25), (20.25, 11.25)], "CTRL_H_A")
        wire(design, [(18.0, 4.0), (18.0, 7.25), (20.25, 7.25)], "CTRL_L_A")
        wire(design, [(28.0, 11.25), (30.25, 11.25)], "CTRL_L_B")
        wire(design, [(28.0, 4.0), (28.0, 7.25), (30.25, 7.25)], "CTRL_H_B")

        if drive_mode == "pwl":
            # Diode terminal 1 is anode and terminal 2 cathode.  The A-side
            # upper-clamp route deliberately reaches VDD at (30, 15), not
            # the source pin at (21, 15), to avoid the adjacent ground pin.
            wire(design, [(12.0, 15.0), (12.0, 14.0), (15.0, 14.0)], "SW_A")
            wire(design, [(13.0, 15.0), (13.0, 17.0), (30.0, 17.0), (30.0, 15.0)], "VDD")
            wire(design, [(13.0, 13.0), (13.0, 14.0), (15.0, 14.0)], "SW_A")
            wire(design, [(38.0, 15.0), (36.0, 15.0), (36.0, 12.0), (35.0, 12.0)], "SW_B")
            wire(design, [(39.0, 15.0), (39.0, 17.0), (30.0, 17.0), (30.0, 15.0)], "VDD")
            wire(design, [(39.0, 13.0), (39.0, 12.0), (35.0, 12.0)], "SW_B")

        transaction.commit()

    design.save_design()

    netlist = design.create_netlist()
    required = ("VDD_SRC", "S_AH", "S_AL", "S_BH", "S_BL", "L_BPF", "C_BPF", "R_LOAD", "TRAN1")
    missing = [name for name in required if name not in netlist]
    if missing:
        raise RuntimeError(f"Generated netlist is incomplete; missing: {', '.join(missing)}")
    return netlist


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=DEFAULT_WORKSPACE)
    parser.add_argument("--cell", default="low_power_dpa_api_v10")
    parser.add_argument("--drive", choices=("pulse", "pwl"), default="pulse")
    parser.add_argument("--sample-file", type=Path, default=DEFAULT_SAMPLE_FILE)
    parser.add_argument("--vdd", default="1.2 V")
    parser.add_argument("--ron", default="0.5 Ohm")
    parser.add_argument("--cout", default="2 pF")
    parser.add_argument("--lbpf", default="3.18 uH")
    parser.add_argument("--cbpf", default="12.7 pF")
    parser.add_argument("--rload", default="100 Ohm")
    parser.add_argument("--dead-time", default="1 nsec")
    parser.add_argument("--edge", default="100 psec")
    args = parser.parse_args()

    if not args.workspace.is_dir():
        raise RuntimeError(f"ADS workspace does not exist: {args.workspace}")
    params = {
        "vdd": args.vdd, "ron": args.ron, "cout": args.cout,
        "lbpf": args.lbpf, "cbpf": args.cbpf, "rload": args.rload,
        "dead_time": args.dead_time, "edge": args.edge,
    }
    netlist = build(
        args.workspace.resolve(),
        args.cell,
        args.drive,
        args.sample_file.resolve() if args.drive == "pwl" else None,
        params,
    )
    print(f"ADS DPA schematic created: {LIBRARY}:{args.cell}:{VIEW}")
    print(f"Netlist generated successfully ({len(netlist)} characters).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise
