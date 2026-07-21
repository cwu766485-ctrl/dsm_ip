#!/usr/bin/env python3
"""Evaluate the trace-aware DPD policy with leave-one-scenario-out splits.

Every manifest row points at one completed full-calibration trace.  All rows
with the held-out scenario_id are excluded before the policy chooses a DPD
mode/package.  This prevents same-condition trace leakage from being reported
as generalization.
"""

from __future__ import annotations

import argparse
import csv
import json
import tempfile
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path


REQUIRED_MANIFEST_COLUMNS = {
    "scenario_id", "pa_profile", "pa_strength_db", "qam", "bandwidth_mhz",
    "used_subcarriers", "input_backoff", "waveform_id", "calibration_profile",
    "trace_csv",
}


@dataclass(frozen=True)
class Scenario:
    scenario_id: str
    pa_profile: str
    pa_strength_db: float
    qam: float
    bandwidth_mhz: float
    used_subcarriers: float
    input_backoff: float
    waveform_id: str
    calibration_profile: str


@dataclass(frozen=True)
class Observation:
    scenario: Scenario
    mode: int
    package: int
    cost: int


def parse_int(value: str) -> int:
    return int(value, 0)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def resolve_trace(manifest: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else manifest.parent / path


def scenario_from_row(row: dict[str, str]) -> Scenario:
    return Scenario(
        scenario_id=row["scenario_id"].strip(),
        pa_profile=row["pa_profile"].strip(),
        pa_strength_db=float(row["pa_strength_db"]),
        qam=float(row["qam"]),
        bandwidth_mhz=float(row["bandwidth_mhz"]),
        used_subcarriers=float(row["used_subcarriers"]),
        input_backoff=float(row["input_backoff"]),
        waveform_id=row["waveform_id"].strip(),
        calibration_profile=row["calibration_profile"].strip(),
    )


def load_manifest(path: Path) -> list[tuple[Scenario, Path]]:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"Manifest is empty: {path}")
    missing = REQUIRED_MANIFEST_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Manifest missing columns: {', '.join(sorted(missing))}")

    entries: list[tuple[Scenario, Path]] = []
    for index, row in enumerate(rows, start=2):
        try:
            scenario = scenario_from_row(row)
            if not scenario.scenario_id:
                raise ValueError("scenario_id is empty")
            trace = resolve_trace(path, row["trace_csv"].strip())
            if not trace.exists():
                raise ValueError(f"trace does not exist: {trace}")
            entries.append((scenario, trace))
        except (KeyError, ValueError) as exc:
            raise ValueError(f"Invalid manifest row {index}: {exc}") from exc
    return entries


def package_observations(trace: Path, scenario: Scenario) -> list[Observation]:
    observations: list[Observation] = []
    for row in read_csv(trace):
        if row.get("stage") != "package":
            continue
        try:
            observations.append(Observation(scenario, parse_int(row["mode"]),
                                            parse_int(row["package"]),
                                            parse_int(row["cost"])))
        except (KeyError, ValueError):
            continue
    if not observations:
        raise ValueError(f"Trace has no usable package observations: {trace}")
    return observations


def trace_rows(trace: Path) -> list[dict[str, str]]:
    return read_csv(trace)


def distance(left: Scenario, right: Scenario) -> float:
    """Use only run-time observable numeric scenario features.

    `pa_profile` and waveform identifiers define provenance and held-out groups,
    but are intentionally not categorical lookup keys.  A future on-board PA
    estimator can replace pa_strength_db with its measured estimate.
    """
    return (
        abs(left.pa_strength_db - right.pa_strength_db) / max(abs(left.pa_strength_db), abs(right.pa_strength_db), 1.0)
        + abs(left.qam - right.qam) / max(left.qam, right.qam, 1.0)
        + abs(left.bandwidth_mhz - right.bandwidth_mhz) / max(left.bandwidth_mhz, right.bandwidth_mhz, 0.001)
        + abs(left.used_subcarriers - right.used_subcarriers) / max(left.used_subcarriers, right.used_subcarriers, 1.0)
        + abs(left.input_backoff - right.input_backoff) / max(left.input_backoff, right.input_backoff, 0.01)
    )


def weighted_policy(observations: list[Observation], target: Scenario) -> tuple[int, int, int, float]:
    grouped: dict[tuple[int, int], list[tuple[float, int]]] = defaultdict(list)
    for item in observations:
        d = distance(item.scenario, target)
        grouped[(item.mode, item.package)].append((1.0 / (1.0e-6 + d), item.cost))
    if not grouped:
        raise ValueError("No training package observations")

    scores: list[tuple[float, int, int, float]] = []
    for (mode, package), values in grouped.items():
        weight = sum(value[0] for value in values)
        predicted = sum(value[0] * value[1] for value in values) / weight
        nearest = min(distance(item.scenario, target) for item in observations
                      if item.mode == mode and item.package == package)
        scores.append((predicted, mode, package, nearest))
    predicted, mode, package, nearest = min(scores)
    return mode, package, round(predicted), nearest


def full_calibration_summary(rows: list[dict[str, str]]) -> tuple[int, int, int]:
    costs = []
    for row in rows:
        try:
            costs.append(parse_int(row["cost"]))
        except (KeyError, ValueError):
            continue
    final = [row for row in rows if row.get("stage") == "final"]
    final_cost = parse_int(final[-1]["cost"]) if final else min(costs)
    final_candidate = parse_int(final[-1]["candidate_id"]) if final else len(rows)
    return len(rows), final_cost, final_candidate


def coverage(entries: list[tuple[Scenario, Path]]) -> dict[str, int]:
    scenarios = {item[0].scenario_id: item[0] for item in entries}
    values = list(scenarios.values())
    return {
        "scenario_count": len(values),
        "pa_profile_count": len({item.pa_profile for item in values}),
        "pa_strength_count": len({item.pa_strength_db for item in values}),
        "qam_count": len({item.qam for item in values}),
        "bandwidth_count": len({item.bandwidth_mhz for item in values}),
        "backoff_count": len({item.input_backoff for item in values}),
    }


def evaluate(entries: list[tuple[Scenario, Path]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    by_scenario: dict[str, list[tuple[Scenario, Path]]] = defaultdict(list)
    for item in entries:
        by_scenario[item[0].scenario_id].append(item)

    results: list[dict[str, object]] = []
    for scenario_id, held_entries in sorted(by_scenario.items()):
        target = held_entries[0][0]
        training_entries = [
            item for key, grouped in by_scenario.items() if key != scenario_id
            for item in grouped if item[0].calibration_profile == target.calibration_profile
        ]
        training = [observation for scenario, trace in training_entries
                    for observation in package_observations(trace, scenario)]
        held = [observation for scenario, trace in held_entries
                for observation in package_observations(trace, scenario)]
        best_cost = min(item.cost for item in held)
        all_rows = [row for _, trace in held_entries for row in trace_rows(trace)]
        baseline_candidates, baseline_final_cost, baseline_convergence = full_calibration_summary(all_rows)
        if training:
            mode, package, predicted_cost, nearest = weighted_policy(training, target)
            selected = [item.cost for item in held if item.mode == mode and item.package == package]
            measured = min(selected) if selected else ""
            status = "evaluated" if selected else "held_action_missing"
        else:
            mode, package, predicted_cost, nearest = "", "", "", ""
            measured = ""
            selected = []
            status = "insufficient_training"
        results.append({
            "scenario_id": target.scenario_id,
            "pa_profile": target.pa_profile,
            "pa_strength_db": target.pa_strength_db,
            "qam": target.qam,
            "bandwidth_mhz": target.bandwidth_mhz,
            "used_subcarriers": target.used_subcarriers,
            "input_backoff": target.input_backoff,
            "waveform_id": target.waveform_id,
            "calibration_profile": target.calibration_profile,
            "status": status,
            "training_observations": len(training),
            "selected_mode": mode,
            "selected_package": package,
            "predicted_cost": predicted_cost,
            "nearest_scenario_distance": "" if nearest == "" else f"{nearest:.9g}",
            "held_best_package_cost": best_cost,
            "measured_policy_cost": measured,
            "package_regret": "" if measured == "" else measured - best_cost,
            "baseline_candidates": baseline_candidates,
            "baseline_final_cost": baseline_final_cost,
            "baseline_convergence_candidate": baseline_convergence,
            "policy_candidates": 1,
            "candidate_reduction": max(baseline_candidates - 1, 0),
            "policy_action_present_in_held_trace": int(bool(selected)),
        })

    evaluated = [row for row in results if row["status"] == "evaluated"]
    exact = [row for row in evaluated if row["package_regret"] == 0]
    aggregate: dict[str, object] = {
        **coverage(entries),
        "held_out_scenarios": len(results),
        "insufficient_training_scenarios": sum(row["status"] == "insufficient_training" for row in results),
        "evaluated_scenarios": len(evaluated),
        "exact_best_scenarios": len(exact),
        "exact_best_rate": "" if not evaluated else len(exact) / len(evaluated),
        "mean_package_regret": "" if not evaluated else sum(int(row["package_regret"]) for row in evaluated) / len(evaluated),
        "mean_candidate_reduction": "" if not results else sum(int(row["candidate_reduction"]) for row in results) / len(results),
    }
    return results, aggregate


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else [])
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, aggregate: dict[str, object], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("# Leave-One-Scenario-Out DPD Policy Report\n\n")
        handle.write("Each reported decision excludes every trace with that `scenario_id` from training. Package-stage costs are the only policy labels.\n\n")
        for key in ("scenario_count", "pa_profile_count", "pa_strength_count", "qam_count", "bandwidth_count", "backoff_count", "held_out_scenarios", "insufficient_training_scenarios", "evaluated_scenarios", "exact_best_scenarios", "exact_best_rate", "mean_package_regret", "mean_candidate_reduction"):
            handle.write(f"- {key.replace('_', ' ')}: `{aggregate[key]}`\n")
        handle.write("\n## Held-Out Results\n\n")
        handle.write("| Scenario | Status | PA | QAM | BW MHz | Backoff | Action | Measured cost | Best package cost | Regret | Candidate reduction |\n")
        handle.write("|---|---|---|---:|---:|---:|---|---:|---:|---:|---:|\n")
        for row in rows:
            action = f"{row['selected_mode']}/{row['selected_package']}"
            handle.write(f"| {row['scenario_id']} | {row['status']} | {row['pa_profile']} | {row['qam']} | {row['bandwidth_mhz']} | {row['input_backoff']} | {action} | {row['measured_policy_cost']} | {row['held_best_package_cost']} | {row['package_regret']} | {row['candidate_reduction']} |\n")
        handle.write("\nA result is valid only when the held trace contains the selected action. These costs remain PL monitor proxies until an RF feedback receiver supplies calibrated EVM/ACLR measurements.\n")


def run_self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        manifest = root / "manifest.csv"
        scenarios = [
            ("pa_low_qam16_bw20_bo058", "low", -6, 16, 20, 48, 0.58, 1, 100, 300),
            ("pa_mid_qam16_bw40_bo058", "mid", 0, 16, 40, 96, 0.58, 1, 140, 200),
            ("pa_high_qam64_bw40_bo070", "high", 6, 64, 40, 96, 0.70, 2, 220, 120),
        ]
        with manifest.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=sorted(REQUIRED_MANIFEST_COLUMNS))
            writer.writeheader()
            for index, (name, profile, strength, qam, bw, sc, backoff, best_package, cost0, cost1) in enumerate(scenarios):
                trace = root / f"trace_{index}.csv"
                with trace.open("w", newline="", encoding="ascii") as trace_handle:
                    trace_writer = csv.DictWriter(trace_handle, fieldnames=["candidate_id", "stage", "mode", "package", "cost"])
                    trace_writer.writeheader()
                    trace_writer.writerows([
                        {"candidate_id": 1, "stage": "package", "mode": 1, "package": 0, "cost": cost0},
                        {"candidate_id": 2, "stage": "package", "mode": 2, "package": 1, "cost": cost1},
                        {"candidate_id": 3, "stage": "final", "mode": 2, "package": best_package, "cost": min(cost0, cost1)},
                    ])
                writer.writerow({
                    "scenario_id": name, "pa_profile": profile, "pa_strength_db": strength,
                    "qam": qam, "bandwidth_mhz": bw, "used_subcarriers": sc,
                    "input_backoff": backoff, "waveform_id": "synthetic", "calibration_profile": "self_test",
                    "trace_csv": trace.name,
                })
        rows, aggregate = evaluate(load_manifest(manifest))
        assert len(rows) == 3 and aggregate["evaluated_scenarios"] == 3
        assert all(row["training_observations"] == 4 for row in rows)
    print("PASS leave-one-scenario-out self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest-csv", type=Path)
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out"))
    parser.add_argument("--prefix", default="dpd_trace_policy_loso")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
        return
    if args.manifest_csv is None:
        parser.error("--manifest-csv is required unless --self-test is used")

    entries = load_manifest(args.manifest_csv)
    results, aggregate = evaluate(entries)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.out_dir / f"{args.prefix}.csv"
    json_path = args.out_dir / f"{args.prefix}.json"
    report_path = args.out_dir / f"{args.prefix}.md"
    write_csv(csv_path, results)
    json_path.write_text(json.dumps({"aggregate": aggregate, "results": results}, indent=2) + "\n", encoding="ascii")
    write_report(report_path, aggregate, results)
    print(f"Wrote: {csv_path}")
    print(f"Wrote: {json_path}")
    print(f"Wrote: {report_path}")
    print(f"Held-out scenarios: {aggregate['held_out_scenarios']}")
    print(f"Exact best rate: {aggregate['exact_best_rate']}")


if __name__ == "__main__":
    main()
