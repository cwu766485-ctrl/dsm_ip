#!/usr/bin/env python3
"""Replay a behavioral monitor-gate candidate against retained board traces.

This is an offline compatibility study only. It uses the behavioral LOSO gate
threshold as a candidate threshold, but never generates a C policy header or
claims RF safety. Each board scenario is held out from package selection and
monitor-center fitting before its retained full-calibration trace is scored.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


MONITOR_FIELDS = (
    "input_power", "output_power", "peak", "avg_mag", "evm_proxy",
    "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
    "clip", "saturation",
)
FEATURE_WEIGHTS = (1.0, 1.0, 2.5, 2.0, 2.5, 1.5, 3.0, 3.0)
REQUIRED_MANIFEST_COLUMNS = {
    "scenario_id", "pa_strength_db", "qam", "bandwidth_mhz",
    "used_subcarriers", "input_backoff", "calibration_profile", "trace_csv",
}


@dataclass(frozen=True)
class Scenario:
    scenario_id: str
    pa_strength_db: float
    qam: float
    bandwidth_mhz: float
    used_subcarriers: float
    input_backoff: float
    calibration_profile: str


@dataclass(frozen=True)
class Observation:
    scenario: Scenario
    mode: int
    package: int
    cost: int
    monitors: tuple[int, ...]


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def parse_int(value: str) -> int:
    return int(value, 0)


def scenario_from_row(row: dict[str, str]) -> Scenario:
    return Scenario(row["scenario_id"].strip(), float(row["pa_strength_db"]),
                    float(row["qam"]), float(row["bandwidth_mhz"]),
                    float(row["used_subcarriers"]), float(row["input_backoff"]),
                    row["calibration_profile"].strip())


def resolve_trace(manifest: Path, value: str) -> Path:
    trace = Path(value)
    return trace if trace.is_absolute() else manifest.parent / trace


def load_manifest(path: Path) -> list[tuple[Scenario, Path]]:
    rows = read_csv(path)
    if not rows or REQUIRED_MANIFEST_COLUMNS - set(rows[0]):
        raise ValueError("Manifest is empty or lacks required policy columns")
    entries = []
    for row in rows:
        trace = resolve_trace(path, row["trace_csv"].strip())
        if not trace.exists():
            raise ValueError(f"Trace does not exist: {trace}")
        entries.append((scenario_from_row(row), trace))
    return entries


def observations(trace: Path, scenario: Scenario) -> list[Observation]:
    result = []
    for row in read_csv(trace):
        if row.get("stage") != "package":
            continue
        try:
            result.append(Observation(scenario, parse_int(row["mode"]),
                                      parse_int(row["package"]), parse_int(row["cost"]),
                                      tuple(parse_int(row[field]) for field in MONITOR_FIELDS)))
        except (KeyError, ValueError):
            continue
    if not result:
        raise ValueError(f"Trace has no usable package rows: {trace}")
    return result


def scenario_distance(left: Scenario, right: Scenario) -> float:
    return (
        abs(left.pa_strength_db - right.pa_strength_db) / max(abs(left.pa_strength_db), abs(right.pa_strength_db), 1.0)
        + abs(left.qam - right.qam) / max(left.qam, right.qam, 1.0)
        + abs(left.bandwidth_mhz - right.bandwidth_mhz) / max(left.bandwidth_mhz, right.bandwidth_mhz, 0.001)
        + abs(left.used_subcarriers - right.used_subcarriers) / max(left.used_subcarriers, right.used_subcarriers, 1.0)
        + abs(left.input_backoff - right.input_backoff) / max(left.input_backoff, right.input_backoff, 0.01)
    )


def select_policy(training: list[Observation], target: Scenario) -> tuple[int, int]:
    grouped: dict[tuple[int, int], list[tuple[float, int]]] = defaultdict(list)
    for item in training:
        grouped[(item.mode, item.package)].append((1.0 / (1.0e-6 + scenario_distance(item.scenario, target)), item.cost))
    scores = []
    for action, values in grouped.items():
        weight = sum(item[0] for item in values)
        scores.append((sum(item[0] * item[1] for item in values) / weight, *action))
    _, mode, package = min(scores)
    return mode, package


def upper_u16(word: int) -> float:
    return float(word >> 16)


def features(monitors: tuple[int, ...]) -> tuple[float, ...]:
    values = dict(zip(MONITOR_FIELDS, monitors))
    return (
        values["output_power"] / max(values["input_power"], 1),
        upper_u16(values["peak"]) / max(upper_u16(values["avg_mag"]), 1),
        values["evm_proxy"] / max(values["input_power"], 1),
        values["acpr_proxy"] / max(values["output_power"], 1),
        values["spec_adj"] / max(values["spec_bin1"], 1),
        values["spec_bin2"] / max(values["spec_bin0"], 1),
        values["clip"] / max(values["input_power"] / 32767.0, 1),
        values["saturation"] / max(values["input_power"] / 32767.0, 1),
    )


def monitor_center(items: list[Observation]) -> tuple[float, ...]:
    columns = list(zip(*(features(item.monitors) for item in items)))
    return tuple(sorted(column)[len(column) // 2] for column in columns)


def monitor_distance(monitors: tuple[int, ...], center: tuple[float, ...]) -> int:
    value = sum(weight * abs(feature - reference) / max(abs(reference), 1.0e-9)
                for feature, reference, weight in zip(features(monitors), center, FEATURE_WEIGHTS))
    return round(value * 1_000_000 / sum(FEATURE_WEIGHTS))


def final_cost(trace: Path) -> int:
    rows = read_csv(trace)
    finals = [parse_int(row["cost"]) for row in rows if row.get("stage") == "final" and row.get("cost")]
    return finals[-1] if finals else min(parse_int(row["cost"]) for row in rows if row.get("cost"))


def candidate_threshold(path: Path, strategy: str) -> int:
    values = [int(float(row["monitor_distance_ppm"])) for row in read_csv(path)]
    if not values:
        raise ValueError(f"Simulation gate is empty: {path}")
    if strategy == "min":
        return min(values)
    if strategy == "median":
        return sorted(values)[len(values) // 2]
    return max(values)


def replay(entries: list[tuple[Scenario, Path]], threshold_ppm: int) -> list[dict[str, object]]:
    result = []
    for target, held_trace in entries:
        training = [item for scenario, trace in entries if scenario.scenario_id != target.scenario_id
                    and scenario.calibration_profile == target.calibration_profile
                    for item in observations(trace, scenario)]
        mode, package = select_policy(training, target)
        selected_training = [item for item in training if (item.mode, item.package) == (mode, package)]
        center = monitor_center(selected_training)
        held = observations(held_trace, target)
        selected_held = [item for item in held if (item.mode, item.package) == (mode, package)]
        if not selected_held:
            raise ValueError(f"Held trace lacks selected action for {target.scenario_id}")
        held_action = min(selected_held, key=lambda item: item.cost)
        distance_ppm = monitor_distance(held_action.monitors, center)
        direct = distance_ppm <= threshold_ppm
        result.append({
            "scenario_id": target.scenario_id,
            "selected_mode": mode,
            "selected_package": package,
            "monitor_distance_ppm": distance_ppm,
            "simulation_candidate_threshold_ppm": threshold_ppm,
            "gate_decision": "direct" if direct else "local_search",
            "policy_cost": held_action.cost,
            "full_search_final_cost": final_cost(held_trace),
            "policy_cost_delta": held_action.cost - final_cost(held_trace),
            "candidate_count_model": 1 if direct else 14,
            "header_update_allowed": 0,
        })
    return result


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        gate = root / "gate.csv"
        gate.write_text("monitor_distance_ppm\n100000\n", encoding="ascii")
        assert candidate_threshold(gate, "min") == 100000
    print("PASS simulation monitor-gate replay self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest-csv", type=Path)
    parser.add_argument("--simulation-gate-csv", type=Path)
    parser.add_argument("--threshold-strategy", choices=("min", "median", "max"), default="min")
    parser.add_argument("--out-csv", type=Path, default=Path("fpga/zu15eg/out/dpd_sim_monitor_gate_board_replay.csv"))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.manifest_csv is None or args.simulation_gate_csv is None:
        parser.error("--manifest-csv and --simulation-gate-csv are required")
    threshold_ppm = candidate_threshold(args.simulation_gate_csv, args.threshold_strategy)
    rows = replay(load_manifest(args.manifest_csv), threshold_ppm)
    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    write_csv(args.out_csv, rows)
    direct = sum(row["gate_decision"] == "direct" for row in rows)
    print(f"Simulation candidate threshold: {threshold_ppm} ppm ({args.threshold_strategy})")
    print(f"Board replay: {direct} direct, {len(rows) - direct} local-search")
    print(f"Wrote: {args.out_csv}")
    print("No header update: behavioral and board monitor distributions remain separate evidence domains.")


if __name__ == "__main__":
    main()
