#!/usr/bin/env python3
"""Calibrate DPD policy gates from repeated simulation or measured feedback.

The existing policy cost is a PL monitor proxy.  This tool therefore consumes
the policy prediction, its JTAG replay, and a calibrated receiver measurement
as separate records.  It never changes a generated C policy header.
"""

from __future__ import annotations

import argparse
import csv
import itertools
import json
import tempfile
from collections import Counter, defaultdict
from pathlib import Path


REQUIRED_SCENARIO_COLUMNS = {
    "scenario_id", "pa_strength_db", "calibration_profile",
}
REQUIRED_RUN_COLUMNS = {
    "scenario_id", "run_id", "policy_report_csv", "policy_trace_csv",
    "feedback_csv", "feedback_receiver", "feedback_calibration_id",
}
REQUIRED_FEEDBACK_COLUMNS = {
    "run_id", "feedback_pass", "evm_pct", "aclr_db", "rx_power_dbm",
    "timestamp_utc",
}
REQUIRED_SIMULATION_COLUMNS = {
    "scenario_id", "run_id", "pa_strength_db", "predicted_cost",
    "measured_cost", "nearest_distance_ppm", "relative_stddev_ppm",
    "feedback_pass", "evm_pct", "aclr_db", "simulation_model",
    "simulation_config_id", "simulation_seed", "observation_id",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        raise ValueError(f"File does not exist: {path}")
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def resolve_path(manifest: Path, value: str) -> Path:
    path = Path(value.strip())
    return path if path.is_absolute() else manifest.parent / path


def parse_int(value: str) -> int:
    return int(value, 0)


def parse_bool(value: str) -> bool:
    lowered = value.strip().lower()
    if lowered in {"1", "true", "pass", "passed", "yes"}:
        return True
    if lowered in {"0", "false", "fail", "failed", "no"}:
        return False
    raise ValueError(f"feedback_pass must be pass/fail or 1/0, got {value!r}")


def residual_ppm(measured: int, predicted: int) -> int:
    return abs(measured - predicted) * 1_000_000 // max(predicted, 1)


def load_scenarios(path: Path) -> dict[str, dict[str, str]]:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"Scenario manifest is empty: {path}")
    missing = REQUIRED_SCENARIO_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Scenario manifest missing columns: {', '.join(sorted(missing))}")
    scenarios = {row["scenario_id"].strip(): row for row in rows}
    if "" in scenarios:
        raise ValueError("Scenario manifest has an empty scenario_id")
    return scenarios


def policy_metrics(report_path: Path, trace_path: Path, scenario_id: str) -> dict[str, int]:
    reports = read_csv(report_path)
    if len(reports) != 1:
        raise ValueError(f"Policy report must contain exactly one row: {report_path}")
    report = reports[0]
    if report.get("held_out_scenario", "").strip() != scenario_id:
        raise ValueError(f"Policy report scenario does not match {scenario_id}: {report_path}")
    try:
        predicted = parse_int(report["predicted_cost"])
        distance = parse_int(report["nearest_distance_ppm"])
        dispersion = parse_int(report["relative_stddev_ppm"])
    except (KeyError, ValueError) as exc:
        raise ValueError(f"Invalid policy report: {report_path}") from exc

    policy_rows = [row for row in read_csv(trace_path) if row.get("stage") == "policy"]
    if not policy_rows:
        raise ValueError(f"Policy JTAG trace has no policy row: {trace_path}")
    try:
        measured = parse_int(policy_rows[-1]["cost"])
    except (KeyError, ValueError) as exc:
        raise ValueError(f"Invalid policy JTAG trace: {trace_path}") from exc
    return {
        "predicted_cost": predicted,
        "measured_cost": measured,
        "distance_ppm": distance,
        "dispersion_ppm": dispersion,
        "residual_ppm": residual_ppm(measured, predicted),
    }


def feedback_result(path: Path, run_id: str) -> bool:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"Feedback CSV is empty: {path}")
    missing = REQUIRED_FEEDBACK_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Feedback CSV missing columns: {', '.join(sorted(missing))}")
    matches = [row for row in rows if row.get("run_id", "").strip() == run_id]
    if len(matches) != 1:
        raise ValueError(f"Feedback CSV requires exactly one row for run_id {run_id}: {path}")
    for field in ("evm_pct", "aclr_db", "rx_power_dbm"):
        try:
            float(matches[0][field])
        except ValueError as exc:
            raise ValueError(f"Feedback CSV has non-numeric {field} for run_id {run_id}: {path}") from exc
    if not matches[0]["timestamp_utc"].strip():
        raise ValueError(f"Feedback CSV has an empty timestamp_utc for run_id {run_id}: {path}")
    return parse_bool(matches[0]["feedback_pass"])


def load_runs(path: Path, scenarios: dict[str, dict[str, str]]) -> list[dict[str, object]]:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"RF feedback manifest is empty: {path}")
    missing = REQUIRED_RUN_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"RF feedback manifest missing columns: {', '.join(sorted(missing))}")
    records: list[dict[str, object]] = []
    for index, row in enumerate(rows, start=2):
        scenario_id = row["scenario_id"].strip()
        run_id = row["run_id"].strip()
        if scenario_id not in scenarios:
            raise ValueError(f"RF feedback manifest row {index} has unknown scenario_id {scenario_id!r}")
        if not run_id:
            raise ValueError(f"RF feedback manifest row {index} has an empty run_id")
        if not row["feedback_receiver"].strip() or not row["feedback_calibration_id"].strip():
            raise ValueError(f"RF feedback manifest row {index} lacks receiver or calibration ID")
        metrics = policy_metrics(resolve_path(path, row["policy_report_csv"]),
                                 resolve_path(path, row["policy_trace_csv"]), scenario_id)
        passed = feedback_result(resolve_path(path, row["feedback_csv"]), run_id)
        records.append({
            "scenario_id": scenario_id,
            "run_id": run_id,
            "pa_strength_db": float(scenarios[scenario_id]["pa_strength_db"]),
            "feedback_pass": passed,
            **metrics,
        })
    return records


def load_simulation_runs(path: Path) -> list[dict[str, object]]:
    rows = read_csv(path)
    if not rows:
        raise ValueError(f"Simulation feedback CSV is empty: {path}")
    missing = REQUIRED_SIMULATION_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Simulation feedback CSV missing columns: {', '.join(sorted(missing))}")
    records: list[dict[str, object]] = []
    for index, row in enumerate(rows, start=2):
        try:
            if not row["simulation_model"].strip() or not row["simulation_config_id"].strip():
                raise ValueError("simulation model/configuration is empty")
            if not row["observation_id"].strip():
                raise ValueError("observation_id is empty")
            records.append({
                "scenario_id": row["scenario_id"].strip(),
                "run_id": row["run_id"].strip(),
                "pa_strength_db": float(row["pa_strength_db"]),
                "feedback_pass": parse_bool(row["feedback_pass"]),
                "predicted_cost": parse_int(row["predicted_cost"]),
                "measured_cost": parse_int(row["measured_cost"]),
                "distance_ppm": parse_int(row["nearest_distance_ppm"]),
                "dispersion_ppm": parse_int(row["relative_stddev_ppm"]),
                "residual_ppm": residual_ppm(parse_int(row["measured_cost"]),
                                              parse_int(row["predicted_cost"])),
                "simulation_model": row["simulation_model"].strip(),
                "simulation_config_id": row["simulation_config_id"].strip(),
                "simulation_seed": row["simulation_seed"].strip(),
                "profile_id": row.get("profile_id", "").strip(),
            })
        except (KeyError, ValueError) as exc:
            raise ValueError(f"Invalid simulation feedback row {index}: {exc}") from exc
    if any(not str(record["scenario_id"]) or not str(record["run_id"]) for record in records):
        raise ValueError("Simulation feedback CSV has an empty scenario_id or run_id")
    return records


def candidate_thresholds(records: list[dict[str, object]], field: str) -> list[int]:
    return sorted({0, *(int(record[field]) for record in records)})


def select_thresholds(records: list[dict[str, object]]) -> dict[str, int | str]:
    fields = ("distance_ppm", "dispersion_ppm", "residual_ppm")
    candidates = [candidate_thresholds(records, field) for field in fields]
    best_strict: tuple[tuple[int, int, int, int], tuple[int, int, int], int, int] | None = None
    best_tradeoff: tuple[tuple[int, int, int, int], tuple[int, int, int], int, int] | None = None
    for values in itertools.product(*candidates):
        accepted = [record for record in records if all(
            int(record[field]) <= value for field, value in zip(fields, values))]
        false_accepted = sum(not bool(record["feedback_pass"]) for record in accepted)
        true_accepted = sum(bool(record["feedback_pass"]) for record in accepted)
        # Strict gates must retain a passing run without accepting a known failure.
        strict_score = (true_accepted, -sum(values), -values[0], -values[1])
        if false_accepted == 0 and true_accepted > 0:
            if best_strict is None or strict_score > best_strict[0]:
                best_strict = (strict_score, values, false_accepted, true_accepted)
        # If the features overlap, report the least-risky tradeoff rather than
        # disguising an empty direct-accept region as a usable gate.
        tradeoff_score = (-false_accepted, true_accepted, -sum(values), -values[0])
        if true_accepted > 0 and (best_tradeoff is None or tradeoff_score > best_tradeoff[0]):
            best_tradeoff = (tradeoff_score, values, false_accepted, true_accepted)
    if best_strict is not None:
        _, selected, false_accepted, true_accepted = best_strict
        separable = True
    elif best_tradeoff is not None:
        _, selected, false_accepted, true_accepted = best_tradeoff
        separable = False
    else:
        raise ValueError("Feedback data contains no passing run.")
    return {
        "max_distance_ppm": selected[0],
        "max_relative_stddev_ppm": selected[1],
        "max_runtime_residual_ppm": selected[2],
        "accepted_runs": false_accepted + true_accepted,
        "false_accepted_runs": false_accepted,
        "true_accepted_runs": true_accepted,
        "separable": separable,
    }


def assess_coverage(records: list[dict[str, object]], min_repeats: int) -> dict[str, object]:
    by_scenario = Counter(str(record["scenario_id"]) for record in records)
    strengths = {float(record["pa_strength_db"]) for record in records}
    failures = sum(not bool(record["feedback_pass"]) for record in records)
    return {
        "run_count": len(records),
        "scenario_count": len(by_scenario),
        "pa_strength_count": len(strengths),
        "minimum_repeats": min(by_scenario.values()),
        "failed_feedback_runs": failures,
        "coverage_ready": len(strengths) >= 2 and min(by_scenario.values()) >= min_repeats,
        "discriminative": failures > 0,
    }


def accepted_by_thresholds(record: dict[str, object], thresholds: dict[str, int | str]) -> bool:
    return (int(record["distance_ppm"]) <= int(thresholds["max_distance_ppm"]) and
            int(record["dispersion_ppm"]) <= int(thresholds["max_relative_stddev_ppm"]) and
            int(record["residual_ppm"]) <= int(thresholds["max_runtime_residual_ppm"]))


def evaluate_profile_loso(records: list[dict[str, object]]) -> list[dict[str, object]]:
    """Fit gates on all other PA profiles, then score the held profile."""
    if not all(record.get("profile_id") for record in records):
        raise ValueError("Simulation records lack profile_id for leave-one-profile-out evaluation.")
    results: list[dict[str, object]] = []
    for profile_id in sorted({str(record["profile_id"]) for record in records}):
        training = [record for record in records if str(record["profile_id"]) != profile_id]
        held = [record for record in records if str(record["profile_id"]) == profile_id]
        try:
            thresholds = select_thresholds(training)
        except ValueError as exc:
            results.append({"profile_id": profile_id, "status": "training_not_separable",
                            "detail": str(exc), "held_runs": len(held)})
            continue
        accepted = [record for record in held if accepted_by_thresholds(record, thresholds)]
        results.append({
            "profile_id": profile_id,
            "status": "evaluated" if bool(thresholds["separable"]) else "training_not_separable",
            "held_runs": len(held),
            "held_accepted_runs": len(accepted),
            "held_true_accepted_runs": sum(bool(record["feedback_pass"]) for record in accepted),
            "held_false_accepted_runs": sum(not bool(record["feedback_pass"]) for record in accepted),
            "held_rejected_runs": len(held) - len(accepted),
            "training_accepted_runs": thresholds["accepted_runs"],
            "training_true_accepted_runs": thresholds["true_accepted_runs"],
            "training_false_accepted_runs": thresholds["false_accepted_runs"],
            "training_separable": thresholds["separable"],
            "max_distance_ppm": thresholds["max_distance_ppm"],
            "max_relative_stddev_ppm": thresholds["max_relative_stddev_ppm"],
            "max_runtime_residual_ppm": thresholds["max_runtime_residual_ppm"],
        })
    return results


def run_self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        scenarios = root / "scenarios.csv"
        runs = root / "runs.csv"
        with scenarios.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=sorted(REQUIRED_SCENARIO_COLUMNS))
            writer.writeheader()
            writer.writerows([
                {"scenario_id": "low", "pa_strength_db": -6, "calibration_profile": "rf"},
                {"scenario_id": "high", "pa_strength_db": 0, "calibration_profile": "rf"},
            ])
        run_rows = []
        for index, (scenario, passed, measured) in enumerate((("low", True, 105), ("low", True, 110), ("high", False, 170), ("high", True, 120))):
            report = root / f"report_{index}.csv"
            trace = root / f"trace_{index}.csv"
            feedback = root / f"feedback_{index}.csv"
            with report.open("w", newline="", encoding="ascii") as handle:
                writer = csv.DictWriter(handle, fieldnames=["held_out_scenario", "predicted_cost", "nearest_distance_ppm", "relative_stddev_ppm"])
                writer.writeheader()
                writer.writerow({"held_out_scenario": scenario, "predicted_cost": 100,
                                 "nearest_distance_ppm": 1000 + index * 100,
                                 "relative_stddev_ppm": 2000 + index * 100})
            with trace.open("w", newline="", encoding="ascii") as handle:
                writer = csv.DictWriter(handle, fieldnames=["stage", "cost"])
                writer.writeheader()
                writer.writerow({"stage": "policy", "cost": measured})
            with feedback.open("w", newline="", encoding="ascii") as handle:
                writer = csv.DictWriter(handle, fieldnames=["run_id", "feedback_pass", "evm_pct", "aclr_db", "rx_power_dbm", "timestamp_utc"])
                writer.writeheader()
                writer.writerow({"run_id": f"r{index}", "feedback_pass": int(passed),
                                 "evm_pct": 1.0 + index, "aclr_db": -40.0 + index,
                                 "rx_power_dbm": -20.0, "timestamp_utc": "2026-07-12T00:00:00Z"})
            run_rows.append({"scenario_id": scenario, "run_id": f"r{index}",
                             "policy_report_csv": report.name, "policy_trace_csv": trace.name,
                             "feedback_csv": feedback.name, "feedback_receiver": "rx",
                             "feedback_calibration_id": "cal"})
        with runs.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=sorted(REQUIRED_RUN_COLUMNS))
            writer.writeheader()
            writer.writerows(run_rows)
        records = load_runs(runs, load_scenarios(scenarios))
        coverage = assess_coverage(records, 2)
        thresholds = select_thresholds(records)
        assert coverage["coverage_ready"] and coverage["discriminative"]
        assert thresholds["separable"] and thresholds["false_accepted_runs"] == 0
        simulation = root / "simulation.csv"
        with simulation.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=sorted(REQUIRED_SIMULATION_COLUMNS))
            writer.writeheader()
            for index, (scenario, strength, passed, measured) in enumerate((
                    ("sim_low", 0, True, 105), ("sim_low", 0, True, 110),
                    ("sim_high", 6, False, 170), ("sim_high", 6, True, 120))):
                writer.writerow({
                    "scenario_id": scenario, "run_id": f"s{index}",
                    "pa_strength_db": strength, "predicted_cost": 100,
                    "measured_cost": measured, "nearest_distance_ppm": 1000 + index,
                    "relative_stddev_ppm": 2000 + index,
                    "feedback_pass": int(passed), "evm_pct": 1.0 + index,
                    "aclr_db": -40.0 + index, "simulation_model": "memory_pa",
                    "simulation_config_id": "self_test", "simulation_seed": index,
                    "observation_id": "sim_rx"})
        simulation_records = load_simulation_runs(simulation)
        simulation_coverage = assess_coverage(simulation_records, 2)
        simulation_thresholds = select_thresholds(simulation_records)
        assert simulation_coverage["coverage_ready"]
        assert simulation_thresholds["separable"] and simulation_thresholds["false_accepted_runs"] == 0
    print("PASS feedback threshold-calibration self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scenario-manifest-csv", type=Path)
    parser.add_argument("--rf-feedback-manifest-csv", type=Path)
    parser.add_argument("--simulation-feedback-csv", type=Path,
                        help="MATLAB PA/observation simulation feedback records.")
    parser.add_argument("--min-repeats", type=int, default=2)
    parser.add_argument("--leave-one-profile-out", action="store_true",
                        help="Evaluate simulation gates on each held PA profile.")
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out"))
    parser.add_argument("--prefix", default="dpd_policy_rf_thresholds")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
        return
    if args.simulation_feedback_csv is None and (
            args.scenario_manifest_csv is None or args.rf_feedback_manifest_csv is None):
        parser.error("provide --simulation-feedback-csv or both external-feedback manifests")
    if args.simulation_feedback_csv is not None and (
            args.scenario_manifest_csv is not None or args.rf_feedback_manifest_csv is not None):
        parser.error("--simulation-feedback-csv cannot be combined with external-feedback manifests")
    if args.min_repeats < 2:
        parser.error("--min-repeats must be at least 2")

    simulated = args.simulation_feedback_csv is not None
    records = (load_simulation_runs(args.simulation_feedback_csv) if simulated else
               load_runs(args.rf_feedback_manifest_csv,
                         load_scenarios(args.scenario_manifest_csv)))
    coverage = assess_coverage(records, args.min_repeats)
    if not coverage["coverage_ready"]:
        raise SystemExit("Insufficient coverage: need two PA strengths and repeated runs per scenario.")
    thresholds = select_thresholds(records)
    if not coverage["discriminative"]:
        status = "provisional_no_failed_feedback"
    elif not bool(thresholds["separable"]):
        status = "simulation_gate_not_separable" if simulated else "measured_gate_not_separable"
    else:
        status = ("simulation_calibrated_not_rf_certified" if simulated else
                  "evidence_calibrated_not_rf_certified")
    result = {"status": status, "evidence_domain": "simulation" if simulated else "measured",
              "coverage": coverage, "thresholds": thresholds,
              "records": records}
    if args.leave_one_profile_out:
        if not simulated:
            parser.error("--leave-one-profile-out requires --simulation-feedback-csv")
        result["leave_one_profile_out"] = evaluate_profile_loso(records)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    output = args.out_dir / f"{args.prefix}.json"
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="ascii")
    print(f"Status: {status}")
    print(f"Wrote: {output}")
    if status == "provisional_no_failed_feedback":
        print("No failed feedback run was supplied; thresholds are provisional and not RF safety certified.")
    elif status.endswith("gate_not_separable"):
        print("The gate features overlap passing and failing runs; do not deploy these thresholds.")
    elif simulated:
        print("Simulation evidence only: thresholds are not RF safety certified.")


if __name__ == "__main__":
    main()
