#!/usr/bin/env python3
"""Fit a conservative trace-aware DPD policy from retained calibration logs.

The predictor is deliberately an instance-based weighted k-NN policy rather
than a neural model. Board trace cost is only comparable within the same
calibration-cost configuration, so each historical trace is labelled with its
waveform scenario and used as a local policy observation. With sparse history,
the tool falls back to the existing MATLAB polynomial nearest-neighbor seed.
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


DEFAULT_SWEEP = Path("matlab/out/dpd/ai_assisted_dpd_sweep.csv")
DEFAULT_TRACE_GLOB = "fpga/zu15eg/out/calibration_trace_jtag_*.csv"
REQUIRED_MANIFEST_COLUMNS = {
    "scenario_id", "pa_strength_db", "qam", "bandwidth_mhz",
    "used_subcarriers", "input_backoff", "calibration_profile", "trace_csv",
}
MONITOR_FIELDS = (
    "input_power", "output_power", "peak", "avg_mag", "evm_proxy",
    "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
    "clip", "saturation",
)


@dataclass(frozen=True)
class Scenario:
    qam: float
    used_subcarriers: float
    input_backoff: float
    bandwidth_mhz: float = 0.0
    pa_strength_db: float = 0.0


@dataclass
class Observation:
    scenario: Scenario
    mode: int
    package: int
    cost: int
    source: Path
    monitors: tuple[int, ...]


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def parse_int(value: str) -> int:
    return int(value, 0)


def distance(left: Scenario, right: Scenario) -> float:
    return (
        abs(left.pa_strength_db - right.pa_strength_db)
        / max(abs(left.pa_strength_db), abs(right.pa_strength_db), 1.0)
        + abs(left.qam - right.qam) / max(left.qam, right.qam, 1.0)
        + abs(left.bandwidth_mhz - right.bandwidth_mhz)
        / max(left.bandwidth_mhz, right.bandwidth_mhz, 0.001)
        + abs(left.used_subcarriers - right.used_subcarriers)
        / max(left.used_subcarriers, right.used_subcarriers, 1.0)
        + abs(left.input_backoff - right.input_backoff)
        / max(left.input_backoff, right.input_backoff, 0.01)
    )


def manifest_observations(path: Path, held_out_scenario: str) -> tuple[list[Observation], Scenario, Path]:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"Manifest is empty: {path}")
    missing = REQUIRED_MANIFEST_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Manifest missing columns: {', '.join(sorted(missing))}")

    held = [row for row in rows if row["scenario_id"].strip() == held_out_scenario]
    if not held:
        raise ValueError(f"Held-out scenario is absent from manifest: {held_out_scenario}")
    target_row = held[0]
    target = Scenario(
        qam=float(target_row["qam"]),
        used_subcarriers=float(target_row["used_subcarriers"]),
        input_backoff=float(target_row["input_backoff"]),
        bandwidth_mhz=float(target_row["bandwidth_mhz"]),
        pa_strength_db=float(target_row["pa_strength_db"]),
    )
    held_trace = Path(target_row["trace_csv"].strip())
    if not held_trace.is_absolute():
        held_trace = path.parent / held_trace

    observations: list[Observation] = []
    for row in rows:
        if row["scenario_id"].strip() == held_out_scenario:
            continue
        if row["calibration_profile"].strip() != target_row["calibration_profile"].strip():
            continue
        scenario = Scenario(
            qam=float(row["qam"]),
            used_subcarriers=float(row["used_subcarriers"]),
            input_backoff=float(row["input_backoff"]),
            bandwidth_mhz=float(row["bandwidth_mhz"]),
            pa_strength_db=float(row["pa_strength_db"]),
        )
        trace = Path(row["trace_csv"].strip())
        if not trace.is_absolute():
            trace = path.parent / trace
        observations.extend(trace_observations([trace], scenario))
    return observations, target, held_trace


def trace_observations(paths: list[Path], scenario: Scenario) -> list[Observation]:
    observations: list[Observation] = []
    for path in paths:
        # Package evaluations are the comparable mode/package policy labels.
        for row in read_csv(path):
            if row.get("stage") != "package":
                continue
            try:
                monitors = tuple(parse_int(row[field]) for field in MONITOR_FIELDS)
                observations.append(
                    Observation(
                        scenario=scenario,
                        mode=parse_int(row["mode"]),
                        package=parse_int(row["package"]),
                        cost=parse_int(row["cost"]),
                        source=path,
                        monitors=monitors,
                    )
                )
            except (KeyError, ValueError):
                continue
    return observations


def weighted_policy(observations: list[Observation], target: Scenario,
                    allowed_modes: set[int] | None = None) -> tuple[int, int, int, float, int, int] | None:
    grouped: dict[tuple[int, int], list[tuple[float, int]]] = defaultdict(list)
    for item in observations:
        if allowed_modes is not None and item.mode not in allowed_modes:
            continue
        d = distance(item.scenario, target)
        grouped[(item.mode, item.package)].append((1.0 / (1.0e-6 + d), item.cost))

    if not grouped:
        return None

    scores: list[tuple[float, int, int, int, float]] = []
    for (mode, package), values in grouped.items():
        weight = sum(v[0] for v in values)
        predicted_cost = sum(v[0] * v[1] for v in values) / weight
        nearest_distance = min(distance(item.scenario, target) for item in observations
                               if item.mode == mode and item.package == package)
        scores.append((predicted_cost, mode, package, round(predicted_cost), nearest_distance))
    _, mode, package, predicted_cost, nearest_distance = min(scores)
    selected = [item for item in observations
                if item.mode == mode and item.package == package]
    selected_weights = [1.0 / (1.0e-6 + distance(item.scenario, target))
                        for item in selected]
    weight = sum(selected_weights)
    variance = sum(item_weight * (item.cost - predicted_cost) ** 2
                   for item_weight, item in zip(selected_weights, selected)) / weight
    cost_stddev = round(math.sqrt(variance))
    relative_stddev_ppm = round(cost_stddev * 1_000_000 / max(predicted_cost, 1))
    return (mode, package, predicted_cost, nearest_distance,
            cost_stddev, relative_stddev_ppm)


def monitor_profile(observations: list[Observation], target: Scenario,
                    mode: int, package: int) -> tuple[tuple[int, ...], int] | None:
    selected = [item for item in observations
                if item.mode == mode and item.package == package and item.monitors]
    if not selected:
        return None
    weights = [1.0 / (1.0e-6 + distance(item.scenario, target)) for item in selected]
    total = sum(weights)
    center = tuple(round(sum(weight * item.monitors[index]
                             for weight, item in zip(weights, selected)) / total)
                   for index in range(len(MONITOR_FIELDS)))
    distances = []
    for item in selected:
        relative_sum = sum(abs(value - reference) * 1_000_000 /
                           max(abs(reference), 1)
                           for value, reference in zip(item.monitors, center))
        distances.append(relative_sum / len(MONITOR_FIELDS))
    # Include observed variation and a modest margin for repeated measurement noise.
    return center, round(max(distances, default=0) + 50_000)


def matlab_fallback(path: Path, target: Scenario) -> tuple[int, int, int] | None:
    candidates: list[tuple[float, float, int]] = []
    for index, row in enumerate(read_csv(path)):
        try:
            scenario = Scenario(float(row["QAM"]), float(row["UsedSubcarriers"]),
                                float(row["InputBackoff"]))
            candidates.append((distance(scenario, target), float(row["OptimizedPoly_Loss"]), index))
        except (KeyError, ValueError):
            continue
    if not candidates:
        return None
    _, _, package = min(candidates)
    return 1, package, 0


def trace_summary(paths: list[Path]) -> dict[str, int]:
    rows = [row for path in paths for row in read_csv(path)]
    final = [row for row in rows if row.get("stage") == "final"]
    best = min((parse_int(row["cost"]) for row in rows if row.get("cost")), default=0)
    return {
        "baseline_candidates": len(rows),
        "baseline_final_cost": parse_int(final[-1]["cost"]) if final else 0,
        "baseline_best_cost": best,
        "baseline_convergence_candidate": parse_int(final[-1]["candidate_id"]) if final else 0,
    }


def policy_measurement(paths: list[Path], mode: int, package: int) -> int | None:
    rows = [row for path in paths for row in read_csv(path)]
    matches = [row for row in rows if row.get("stage") == "policy"
               and parse_int(row.get("mode", "-1")) == mode
               and parse_int(row.get("package", "-1")) == package]
    return parse_int(matches[-1]["cost"]) if matches else None


def write_header(path: Path, mode: int, package: int, predicted_cost: int,
                 training_rows: int, nearest_distance_ppm: int,
                 cost_stddev: int, relative_stddev_ppm: int,
                 max_distance_ppm: int, max_relative_stddev_ppm: int,
                 max_runtime_residual_ppm: int,
                 monitor_center: tuple[int, ...] | None, max_monitor_distance_ppm: int,
                 direct: bool, fallback_rounds: int, fallback_initial_step: int) -> None:
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("#ifndef DSM_DPD_TRACE_POLICY_H\n")
        handle.write("#define DSM_DPD_TRACE_POLICY_H\n\n")
        handle.write("/* Generated by train_dpd_trace_policy.py; do not edit manually. */\n")
        handle.write("#define DSM_DPD_TRACE_POLICY_AVAILABLE 1U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MODE {mode}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_PACKAGE_IDX {package}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_PREDICTED_COST {predicted_cost}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_TRAINING_ROWS {training_rows}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_NEAREST_DISTANCE_PPM {nearest_distance_ppm}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_COST_STDDEV {cost_stddev}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_REL_STDDEV_PPM {relative_stddev_ppm}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MAX_DISTANCE_PPM {max_distance_ppm}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MAX_REL_STDDEV_PPM {max_relative_stddev_ppm}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM {max_runtime_residual_ppm}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE {1 if monitor_center else 0}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_MAX_MONITOR_DISTANCE_PPM {max_monitor_distance_ppm}U\n")
        for field, value in zip(MONITOR_FIELDS, monitor_center or (0,) * len(MONITOR_FIELDS)):
            handle.write(f"#define DSM_DPD_TRACE_POLICY_MON_{field.upper()} {value}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_DIRECT {1 if direct else 0}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS {fallback_rounds}U\n")
        handle.write(f"#define DSM_DPD_TRACE_POLICY_FALLBACK_INITIAL_STEP {fallback_initial_step}\n")
        handle.write("\n#endif /* DSM_DPD_TRACE_POLICY_H */\n")


def write_csv(path: Path, result: dict[str, object]) -> None:
    fields = list(result)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerow(result)


def write_markdown(path: Path, result: dict[str, object]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("# Trace-Aware DPD Policy Report\n\n")
        handle.write("This is a deterministic weighted k-NN policy over retained board trace observations. It is not a trained neural PA model.\n\n")
        handle.write(f"- Training package observations: `{result['training_observations']}`\n")
        handle.write(f"- Predictor: `{result['predictor']}`\n")
        handle.write(f"- Selected mode/package: `{result['mode']}` / `{result['package']}`\n")
        handle.write(f"- Predicted board cost: `{result['predicted_cost']}`\n")
        handle.write(f"- Nearest scenario distance: `{result['nearest_scenario_distance']}`\n\n")
        handle.write(f"- Selected-action cost standard deviation: `{result['cost_stddev']}`\n")
        handle.write(f"- Relative cost standard deviation ppm: `{result['relative_stddev_ppm']}`\n")
        handle.write(f"- Gate decision: `{result['gate_decision']}`\n")
        handle.write(f"- Gate reason: `{result['gate_reason']}`\n\n")
        handle.write(f"- Maximum runtime cost residual ppm: `{result['max_runtime_residual_ppm']}`\n\n")
        handle.write(f"- Runtime monitor-state distance ppm: `{result['monitor_distance_ppm']}`\n")
        handle.write(f"- Maximum monitor-state distance ppm: `{result['max_monitor_distance_ppm']}`\n\n")
        handle.write("## Candidate Comparison\n\n")
        handle.write(f"- Full-calibration candidates: `{result['baseline_candidates']}`\n")
        handle.write(f"- Policy replay candidates: `{result['policy_candidates']}`\n")
        handle.write(f"- Runtime-guarded maximum candidates: `{result['policy_max_candidates']}`\n")
        handle.write(f"- Candidate reduction: `{result['candidate_reduction']}`\n")
        handle.write(f"- Full-calibration final cost: `{result['baseline_final_cost']}`\n")
        handle.write(f"- Policy predicted cost: `{result['predicted_cost']}`\n")
        if result["measured_policy_cost"] != "":
            handle.write(f"- Policy measured cost: `{result['measured_policy_cost']}`\n")
            handle.write(f"- Measured minus predicted cost: `{result['measured_cost_delta']}`\n")
        handle.write(f"- Full-calibration convergence candidate: `{result['baseline_convergence_candidate']}`\n")
        handle.write(f"- Policy convergence candidate: `{result['policy_candidates']}`\n\n")
        if result["measured_policy_cost"] == "":
            handle.write("A policy replay must be measured on board before treating the predicted cost or candidate reduction as board-confirmed.\n")
        else:
            handle.write("This validates one-candidate reproduction for the same scenario used in retained history. It does not establish generalization to an unseen PA, waveform, or board condition.\n")


def run_self_test() -> None:
    target = Scenario(64, 96, 0.58, 40, 0)
    observations = [
        Observation(Scenario(64, 96, 0.70, 40, 0), 1, 3, 300_000, Path("a"), (100,) * 10),
        Observation(Scenario(16, 96, 0.58, 40, 0), 1, 3, 320_000, Path("b"), (110,) * 10),
        Observation(Scenario(64, 48, 0.58, 20, 0), 1, 2, 360_000, Path("c"), (120,) * 10),
    ]
    policy = weighted_policy(observations, target)
    assert policy is not None
    mode, package, predicted, nearest, stddev, relative_ppm = policy
    assert (mode, package) == (1, 3)
    assert predicted > 0 and nearest > 0 and stddev > 0 and relative_ppm > 0
    assert round(nearest * 1_000_000) <= 200_000
    assert round(nearest * 1_000_000) > 100_000

    with tempfile.TemporaryDirectory() as directory:
        header = Path(directory) / "policy.h"
        write_header(header, mode, package, predicted, len(observations),
                     round(nearest * 1_000_000), stddev, relative_ppm,
                     100_000, 100_000, 150_000, (105,) * 10, 200_000,
                     False, 1, 64)
        text = header.read_text(encoding="ascii")
        assert "DSM_DPD_TRACE_POLICY_DIRECT 0U" in text
        assert "DSM_DPD_TRACE_POLICY_FALLBACK_ROUNDS 1U" in text
        assert "DSM_DPD_TRACE_POLICY_MAX_RUNTIME_RESIDUAL_PPM 150000U" in text
        assert "DSM_DPD_TRACE_POLICY_MONITOR_AVAILABLE 1U" in text
    print("PASS trace policy confidence/runtime-gate self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace-csv", action="append", type=Path, default=[])
    parser.add_argument("--manifest-csv", type=Path)
    parser.add_argument("--held-out-scenario")
    parser.add_argument("--policy-trace-csv", action="append", type=Path, default=[],
                        help="Optional measured one-candidate policy replay trace.")
    parser.add_argument("--sweep-csv", type=Path, default=DEFAULT_SWEEP)
    parser.add_argument("--qam", type=float)
    parser.add_argument("--used-subcarriers", type=float)
    parser.add_argument("--input-backoff", type=float)
    parser.add_argument("--bandwidth-mhz", type=float, default=0.0)
    parser.add_argument("--pa-strength-db", type=float, default=0.0)
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out"))
    parser.add_argument("--prefix", default="dpd_trace_policy")
    parser.add_argument("--header", type=Path)
    parser.add_argument("--max-distance", type=float, default=0.20)
    parser.add_argument("--max-relative-stddev", type=float, default=0.10)
    parser.add_argument("--max-runtime-residual", type=float, default=0.15,
                        help="Maximum absolute measured/predicted cost residual before fallback.")
    parser.add_argument("--max-monitor-distance", type=float,
                        help="Optional monitor-state relative distance limit. Defaults to observed spread plus 5%%.")
    parser.add_argument("--fallback-rounds", type=int, default=1)
    parser.add_argument("--fallback-initial-step", type=int, default=64)
    parser.add_argument("--allowed-mode", action="append", type=int,
                        help="Restrict policy selection to one or more DPD modes.")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        run_self_test()
        return

    if args.manifest_csv or args.held_out_scenario:
        if not args.manifest_csv or not args.held_out_scenario:
            parser.error("--manifest-csv and --held-out-scenario must be supplied together")
        observations, target, baseline_trace = manifest_observations(
            args.manifest_csv, args.held_out_scenario)
        trace_paths = [baseline_trace]
        predictor = "manifest_loso_weighted_knn"
    else:
        if args.qam is None or args.used_subcarriers is None or args.input_backoff is None:
            parser.error("--qam, --used-subcarriers, and --input-backoff are required without a manifest")
        target = Scenario(args.qam, args.used_subcarriers, args.input_backoff,
                          args.bandwidth_mhz, args.pa_strength_db)
        trace_paths = args.trace_csv or sorted(Path(".").glob(DEFAULT_TRACE_GLOB))[-1:]
        observations = trace_observations(trace_paths, target)
        predictor = "trace_weighted_knn"
    allowed_modes = set(args.allowed_mode) if args.allowed_mode else None
    policy = weighted_policy(observations, target, allowed_modes)
    if policy is None:
        policy = matlab_fallback(args.sweep_csv, target)
        predictor = "matlab_nearest_neighbor_fallback"
    if policy is None:
        raise SystemExit("No usable trace observations or MATLAB sweep fallback were found.")

    if len(policy) == 6:
        mode, package, predicted_cost, nearest_distance, cost_stddev, relative_stddev_ppm = policy
    else:
        mode, package, predicted_cost = policy
        nearest_distance, cost_stddev, relative_stddev_ppm = 0.0, 0, 0
    max_distance_ppm = round(args.max_distance * 1_000_000)
    max_relative_stddev_ppm = round(args.max_relative_stddev * 1_000_000)
    max_runtime_residual_ppm = round(args.max_runtime_residual * 1_000_000)
    monitor = monitor_profile(observations, target, mode, package) if len(policy) == 6 else None
    monitor_center, observed_monitor_distance_ppm = monitor or (None, 0)
    max_monitor_distance_ppm = (round(args.max_monitor_distance * 1_000_000)
                                if args.max_monitor_distance is not None
                                else observed_monitor_distance_ppm)
    nearest_distance_ppm = round(nearest_distance * 1_000_000)
    distance_ok = nearest_distance_ppm <= max_distance_ppm
    dispersion_ok = relative_stddev_ppm <= max_relative_stddev_ppm
    direct = distance_ok and dispersion_ok
    gate_reason = "within_thresholds" if direct else (
        "distance_and_dispersion" if not distance_ok and not dispersion_ok else
        "distance" if not distance_ok else "dispersion")
    fallback_supported = mode == 1
    policy_candidates = (1 + args.fallback_rounds * 12 + 1
                         if not direct and fallback_supported else 1)
    policy_max_candidates = (1 + args.fallback_rounds * 12 + 1
                             if fallback_supported else 1)
    summary = trace_summary(trace_paths)
    measured_policy_cost = policy_measurement(args.policy_trace_csv, mode, package)
    result: dict[str, object] = {
        "qam": target.qam,
        "bandwidth_mhz": target.bandwidth_mhz,
        "pa_strength_db": target.pa_strength_db,
        "used_subcarriers": target.used_subcarriers,
        "input_backoff": target.input_backoff,
        "predictor": predictor,
        "training_observations": len(observations),
        "mode": mode,
        "package": package,
        "predicted_cost": predicted_cost,
        "nearest_scenario_distance": f"{nearest_distance:.9g}",
        "nearest_distance_ppm": nearest_distance_ppm,
        "cost_stddev": cost_stddev,
        "relative_stddev_ppm": relative_stddev_ppm,
        "max_distance_ppm": max_distance_ppm,
        "max_relative_stddev_ppm": max_relative_stddev_ppm,
        "max_runtime_residual_ppm": max_runtime_residual_ppm,
        "monitor_distance_ppm": observed_monitor_distance_ppm,
        "max_monitor_distance_ppm": max_monitor_distance_ppm,
        "monitor_available": int(monitor_center is not None),
        "gate_decision": "direct" if direct else "local_search",
        "gate_reason": gate_reason,
        "fallback_rounds": args.fallback_rounds,
        "fallback_initial_step": args.fallback_initial_step,
        "policy_candidates": policy_candidates,
        "policy_max_candidates": policy_max_candidates,
        "candidate_reduction": max(summary["baseline_candidates"] - policy_candidates, 0),
        "measured_policy_cost": "" if measured_policy_cost is None else measured_policy_cost,
        "measured_cost_delta": "" if measured_policy_cost is None else measured_policy_cost - predicted_cost,
        **summary,
        "trace_sources": ";".join(str(path) for path in trace_paths),
        "held_out_scenario": args.held_out_scenario or "",
    }

    args.out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.out_dir / f"{args.prefix}.csv"
    markdown_path = args.out_dir / f"{args.prefix}.md"
    write_csv(csv_path, result)
    write_markdown(markdown_path, result)
    if args.header:
        args.header.parent.mkdir(parents=True, exist_ok=True)
        write_header(args.header, mode, package, predicted_cost, len(observations),
                     nearest_distance_ppm, cost_stddev, relative_stddev_ppm,
                     max_distance_ppm, max_relative_stddev_ppm,
                     max_runtime_residual_ppm, monitor_center,
                     max_monitor_distance_ppm, direct,
                     args.fallback_rounds, args.fallback_initial_step)

    print(f"Predictor: {predictor}")
    print(f"Recommended mode/package: {mode}/{package}")
    print(f"Predicted cost: {predicted_cost}")
    print(f"Gate decision: {'direct' if direct else 'local_search'} ({gate_reason})")
    print(f"Wrote: {csv_path}")
    print(f"Wrote: {markdown_path}")
    if args.header:
        print(f"Wrote: {args.header}")


if __name__ == "__main__":
    main()
