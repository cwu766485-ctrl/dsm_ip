#!/usr/bin/env python3
"""Replay the behavioral regret policy against retained full JTAG traces.

This tool mirrors the MATLAB first-candidate regret policy with C-friendly
fixed-point feature ratios, median/IQR normalization, and weighted k-NN. It
is an offline compatibility study only: it never writes a C header and does
not label a behavioral PA regret estimate as board or RF evidence.
"""

from __future__ import annotations

import argparse
import csv
import math
import tempfile
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


Q = 1 << 20
WEIGHT_Q = 1 << 30
MONITOR_FIELDS = (
    "input_power", "output_power", "peak", "avg_mag", "evm_proxy",
    "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
    "clip", "saturation",
)
REQUIRED_MANIFEST_COLUMNS = {
    "scenario_id", "pa_strength_db", "qam", "bandwidth_mhz",
    "used_subcarriers", "input_backoff", "calibration_profile", "trace_csv",
}
REQUIRED_SIMULATION_COLUMNS = {
    "profile_id", "qam", "bandwidth_mhz", "used_subcarriers",
    "input_backoff", "local_search_regret", *MONITOR_FIELDS,
}


@dataclass(frozen=True)
class Scenario:
    scenario_id: str
    qam: int
    bandwidth_mhz: int
    used_subcarriers: int
    input_backoff_q: int
    calibration_profile: str


@dataclass(frozen=True)
class TraceObservation:
    scenario: Scenario
    mode: int
    package: int
    cost: int
    monitors: tuple[int, ...]
    error: int
    stall: int


@dataclass(frozen=True)
class RegretSample:
    features: tuple[int, ...]
    regret: int


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def parse_int(value: str) -> int:
    return int(value, 0)


def parse_float_q(value: str) -> int:
    return round(float(value) * Q)


def scenario_from_row(row: dict[str, str]) -> Scenario:
    return Scenario(
        row["scenario_id"].strip(), round(float(row["qam"])),
        round(float(row["bandwidth_mhz"])), round(float(row["used_subcarriers"])),
        parse_float_q(row["input_backoff"]), row["calibration_profile"].strip(),
    )


def resolve_trace(manifest: Path, value: str) -> Path:
    trace = Path(value)
    return trace if trace.is_absolute() else manifest.parent / trace


def load_manifest(path: Path) -> list[tuple[Scenario, Path]]:
    rows = read_csv(path)
    if not rows or REQUIRED_MANIFEST_COLUMNS - set(rows[0]):
        raise ValueError("Manifest is empty or lacks required policy columns")
    result = []
    for row in rows:
        trace = resolve_trace(path, row["trace_csv"].strip())
        if not trace.exists():
            raise ValueError(f"Trace does not exist: {trace}")
        result.append((scenario_from_row(row), trace))
    return result


def trace_observations(trace: Path, scenario: Scenario) -> list[TraceObservation]:
    result = []
    for row in read_csv(trace):
        if row.get("stage") != "package":
            continue
        try:
            result.append(TraceObservation(
                scenario, parse_int(row["mode"]), parse_int(row["package"]),
                parse_int(row["cost"]),
                tuple(parse_int(row[field]) for field in MONITOR_FIELDS),
                parse_int(row["error"]), parse_int(row["stall"]),
            ))
        except (KeyError, ValueError):
            continue
    if not result:
        raise ValueError(f"Trace has no usable package rows: {trace}")
    return result


def scenario_distance(left: Scenario, right: Scenario) -> float:
    return (
        abs(left.qam - right.qam) / max(left.qam, right.qam, 1)
        + abs(left.bandwidth_mhz - right.bandwidth_mhz)
        / max(left.bandwidth_mhz, right.bandwidth_mhz, 1)
        + abs(left.used_subcarriers - right.used_subcarriers)
        / max(left.used_subcarriers, right.used_subcarriers, 1)
        + abs(left.input_backoff_q - right.input_backoff_q)
        / max(left.input_backoff_q, right.input_backoff_q, 1)
    )


def select_action(training: list[TraceObservation], target: Scenario) -> tuple[int, int]:
    grouped: dict[tuple[int, int], list[tuple[float, int]]] = defaultdict(list)
    for item in training:
        weight = 1.0 / (1.0e-6 + scenario_distance(item.scenario, target))
        grouped[(item.mode, item.package)].append((weight, item.cost))
    if not grouped:
        raise ValueError(f"No board training observations for {target.scenario_id}")
    scores = []
    for (mode, package), values in grouped.items():
        total = sum(weight for weight, _ in values)
        scores.append((sum(weight * cost for weight, cost in values) / total, mode, package))
    _, mode, package = min(scores)
    return mode, package


def upper_u16(word: int) -> int:
    return word >> 16


def ratio_q(numerator: int, denominator: int) -> int:
    return numerator * Q // max(denominator, 1)


def monitor_features_q(monitors: tuple[int, ...]) -> tuple[int, ...]:
    values = dict(zip(MONITOR_FIELDS, monitors))
    input_power = max(values["input_power"], 1)
    output_power = max(values["output_power"], 1)
    magnitude_count = max(input_power // 32767, 1)
    return (
        ratio_q(values["output_power"], input_power),
        ratio_q(upper_u16(values["peak"]), max(upper_u16(values["avg_mag"]), 1)),
        ratio_q(values["evm_proxy"], input_power),
        ratio_q(values["acpr_proxy"], output_power),
        ratio_q(values["spec_adj"], max(values["spec_bin1"], 1)),
        ratio_q(values["spec_bin2"], max(values["spec_bin0"], 1)),
        ratio_q(values["clip"], magnitude_count),
        ratio_q(values["saturation"], magnitude_count),
    )


def feature_vector_q(scenario: Scenario, monitors: tuple[int, ...]) -> tuple[int, ...]:
    return (
        scenario.qam * Q // 64,
        scenario.bandwidth_mhz * Q // 40,
        scenario.used_subcarriers * Q // 96,
        scenario.input_backoff_q,
        *monitor_features_q(monitors),
    )


def load_simulation_samples(path: Path) -> list[RegretSample]:
    rows = read_csv(path)
    if not rows or REQUIRED_SIMULATION_COLUMNS - set(rows[0]):
        raise ValueError("Simulation CSV lacks required regret-policy columns")
    result = []
    for row in rows:
        try:
            scenario = Scenario(
                row["profile_id"].strip(), round(float(row["qam"])),
                round(float(row["bandwidth_mhz"])), round(float(row["used_subcarriers"])),
                parse_float_q(row["input_backoff"]), "simulation",
            )
            monitors = tuple(parse_int(row[field]) for field in MONITOR_FIELDS)
            result.append(RegretSample(feature_vector_q(scenario, monitors),
                                       max(round(float(row["local_search_regret"])), 0)))
        except (KeyError, ValueError):
            continue
    if not result:
        raise ValueError("Simulation CSV has no usable regret samples")
    return result


def median(values: list[int]) -> int:
    ordered = sorted(values)
    middle = len(ordered) // 2
    return ordered[middle] if len(ordered) % 2 else (ordered[middle - 1] + ordered[middle]) // 2


def percentile_linear(values: list[int], numerator: int, denominator: int) -> int:
    ordered = sorted(values)
    position = (len(ordered) - 1) * numerator
    low = position // denominator
    high = min(low + 1, len(ordered) - 1)
    remainder = position % denominator
    return (ordered[low] * (denominator - remainder) + ordered[high] * remainder) // denominator


def normalization(samples: list[RegretSample]) -> tuple[tuple[int, ...], tuple[int, ...]]:
    columns = list(zip(*(sample.features for sample in samples)))
    center = tuple(median(list(column)) for column in columns)
    scale = tuple(max(percentile_linear(list(column), 3, 4) -
                      percentile_linear(list(column), 1, 4), 1)
                  for column in columns)
    return center, scale


def distance_q(left: tuple[int, ...], right: tuple[int, ...], scale: tuple[int, ...]) -> int:
    squared = sum(((value - reference) * Q // width) ** 2
                  for value, reference, width in zip(left, right, scale))
    return math.isqrt(squared)


def predict_regret(samples: list[RegretSample], target: tuple[int, ...], neighbors: int) -> tuple[int, int, int]:
    center, scale = normalization(samples)
    ranked = sorted((distance_q(sample.features, target, scale), sample.regret)
                    for sample in samples)[:neighbors]
    weights = [WEIGHT_Q // max(distance, 1) for distance, _ in ranked]
    total = sum(weights)
    predicted = sum(weight * regret for weight, (_, regret) in zip(weights, ranked)) // total
    variance = sum(weight * (regret - predicted) ** 2
                   for weight, (_, regret) in zip(weights, ranked)) // total
    return predicted, math.isqrt(variance), ranked[0][0] * 1_000_000 // Q


def final_cost(trace: Path) -> int:
    rows = read_csv(trace)
    final = [parse_int(row["cost"]) for row in rows
             if row.get("stage") == "final" and row.get("cost")]
    return final[-1] if final else min(parse_int(row["cost"]) for row in rows if row.get("cost"))


def replay(entries: list[tuple[Scenario, Path]], samples: list[RegretSample],
           budget: int, distance_limit_ppm: int, neighbors: int) -> list[dict[str, object]]:
    result = []
    for target, held_trace in entries:
        training = [item for scenario, trace in entries
                    if scenario.scenario_id != target.scenario_id
                    and scenario.calibration_profile == target.calibration_profile
                    for item in trace_observations(trace, scenario)]
        mode, package = select_action(training, target)
        matches = [item for item in trace_observations(held_trace, target)
                   if (item.mode, item.package) == (mode, package)]
        if not matches:
            raise ValueError(f"Held trace lacks selected action for {target.scenario_id}")
        first = min(matches, key=lambda item: item.cost)
        predicted, uncertainty, distance_ppm = predict_regret(
            samples, feature_vector_q(target, first.monitors), neighbors)
        upper = predicted + uncertainty
        hard_fault = int(any((first.monitors[-2], first.monitors[-1], first.error, first.stall)))
        direct = upper <= budget and distance_ppm <= distance_limit_ppm and not hard_fault
        final = final_cost(held_trace)
        result.append({
            "scenario_id": target.scenario_id,
            "selected_mode": mode,
            "selected_package": package,
            "first_candidate_cost": first.cost,
            "full_search_final_cost": final,
            "direct_cost_delta_to_full_search": first.cost - final,
            "predicted_regret": predicted,
            "predicted_uncertainty": uncertainty,
            "predicted_upper_regret": upper,
            "regret_budget": budget,
            "nearest_feature_distance_ppm": distance_ppm,
            "feature_distance_limit_ppm": distance_limit_ppm,
            "hard_monitor_or_runtime_fault": hard_fault,
            "gate_decision": "direct" if direct else "local_search",
            "candidate_count_model": 1 if direct else 14,
            "direct_cost_validated": int(direct),
            "local_search_cost_source": "not_measured" if not direct else "not_applicable",
            "board_replay_required": int(not direct),
            "header_update_allowed": 0,
        })
    return result


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def self_test() -> None:
    sample = RegretSample((Q,) * 12, 7)
    predicted, uncertainty, distance = predict_regret([sample], sample.features, 1)
    assert (predicted, uncertainty, distance) == (7, 0, 0)
    assert ratio_q(3, 2) == 3 * Q // 2
    print("PASS simulation regret-policy replay self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest-csv", type=Path)
    parser.add_argument("--simulation-csv", type=Path)
    parser.add_argument("--regret-budget", type=int, default=100)
    parser.add_argument("--feature-distance-ppm", type=int, default=100000)
    parser.add_argument("--neighbors", type=int, default=5)
    parser.add_argument("--out-csv", type=Path,
                        default=Path("fpga/zu15eg/out/dpd_sim_regret_policy_board_replay.csv"))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.manifest_csv is None or args.simulation_csv is None:
        parser.error("--manifest-csv and --simulation-csv are required")
    if args.neighbors < 1:
        parser.error("--neighbors must be positive")
    rows = replay(load_manifest(args.manifest_csv), load_simulation_samples(args.simulation_csv),
                  args.regret_budget, args.feature_distance_ppm, args.neighbors)
    write_csv(args.out_csv, rows)
    direct = sum(row["gate_decision"] == "direct" for row in rows)
    print(f"Board regret replay: {direct} direct, {len(rows) - direct} local-search")
    print(f"Wrote: {args.out_csv}")
    print("No header update: board trace compatibility is not board deployment evidence.")


if __name__ == "__main__":
    main()
