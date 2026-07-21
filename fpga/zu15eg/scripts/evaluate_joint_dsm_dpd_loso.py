#!/usr/bin/env python3
"""Evaluate joint DSM, polynomial-seed, and search decisions by waveform LOSO.

The evaluator is deliberately offline and evidence-aware. A direct candidate
cost comes from the held full-calibration trace. A bounded-search result is
called validated only when the selected polynomial seed equals the seed used by
the held measured 14-record trace; otherwise it is a required future replay.
"""

from __future__ import annotations

import argparse
import csv
import math
import statistics
import tempfile
from collections import defaultdict
from pathlib import Path


FEATURES = ("qam", "bandwidth_mhz", "used_subcarriers", "input_backoff",
            "dsm_algorithm", "mon_input_power", "mon_peak", "mon_avg_mag",
            "mon_evm_proxy", "mon_acpr_proxy", "mon_spec_bin0", "mon_spec_bin1",
            "mon_spec_bin2", "mon_spec_adj")
GROUP_FIELDS = ("pa_profile", "pa_strength_db", "qam", "bandwidth_mhz",
                "used_subcarriers", "input_backoff", "waveform_id")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def parse_int(value: str) -> int:
    return int(value, 0)


def resolve(path: Path, value: str) -> Path:
    item = Path(value)
    return item if item.is_absolute() else path.parent / item


def condition_key(row: dict[str, str]) -> tuple[str, ...]:
    return tuple(row[field] for field in GROUP_FIELDS)


def replay_key(row: dict[str, str]) -> tuple[object, ...]:
    """Use numeric values so CSV formatting cannot hide a valid board replay."""
    return (
        row["pa_profile"], float(row["pa_strength_db"]), int(float(row["qam"])),
        float(row["bandwidth_mhz"]), int(float(row["used_subcarriers"])),
        float(row["input_backoff"]), row["waveform_id"], row["dsm_config_id"],
        int(float(row["dpd_mode"])), int(float(row["dpd_package"])),
    )


def median(values: list[float]) -> float:
    return statistics.median(values) if values else 0.0


def feature_distance(left: dict[str, str], right: dict[str, str], scales: dict[str, float]) -> float:
    return sum(abs(float(left[field]) - float(right[field])) / scales[field] for field in FEATURES)


def normalization(rows: list[dict[str, str]]) -> dict[str, float]:
    scales = {}
    for field in FEATURES:
        values = sorted(float(row[field]) for row in rows)
        q1 = values[len(values) // 4]
        q3 = values[(3 * len(values)) // 4]
        scales[field] = max(q3 - q1, abs(median(values)) * 0.05, 1.0)
    return scales


def package_cost(row: dict[str, str], mode: int, package: int) -> int | None:
    trace = Path(row["full_calibration_trace_csv"])
    for item in read_csv(trace):
        if item.get("stage") == "package" and parse_int(item["mode"]) == mode and parse_int(item["package"]) == package:
            return parse_int(item["cost"])
    return None


def choose_action(training: list[dict[str, str]], target: dict[str, str], neighbors: int,
                  benefit_budget: float) -> tuple[dict[str, str], int, int, float, str]:
    scales = normalization(training)
    ranked = sorted(((feature_distance(target, row, scales), row) for row in training), key=lambda item: item[0])[:neighbors]
    grouped: dict[tuple[str, str, str], list[tuple[float, dict[str, str]]]] = defaultdict(list)
    for distance, row in ranked:
        grouped[(row["dsm_config_id"], row["dpd_mode"], row["dpd_package"])].append((1.0 / (1.0e-6 + distance), row))
    key, values = min(grouped.items(), key=lambda item: sum(weight * float(row["local_search_final_cost"])
                                                               for weight, row in item[1]) / sum(weight for weight, _ in item[1]))
    weight_sum = sum(weight for weight, _ in values)
    expected_benefit = sum(weight * float(row["search_benefit"]) for weight, row in values) / weight_sum
    seed_row = values[0][1]
    return seed_row, parse_int(key[1]), parse_int(key[2]), expected_benefit, ("direct" if expected_benefit <= benefit_budget else "local_search")


def evaluate(rows: list[dict[str, str]], joint_replays: list[dict[str, str]],
             neighbors: int, benefit_budget: float) -> tuple[list[dict[str, object]], dict[str, object]]:
    by_condition: dict[tuple[str, ...], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        by_condition[condition_key(row)].append(row)
    results = []
    for key, held in sorted(by_condition.items()):
        training = [row for other_key, items in by_condition.items() if other_key != key for row in items]
        if not training:
            continue
        selected_seed_row, mode, package, expected_benefit, decision = choose_action(training, held[0], neighbors, benefit_budget)
        target_rows = [row for row in held if row["dsm_config_id"] == selected_seed_row["dsm_config_id"]]
        if not target_rows:
            results.append({**dict(zip(GROUP_FIELDS, key)), "status": "selected_dsm_missing", "decision": decision})
            continue
        target = target_rows[0]
        initial_cost = package_cost(target, mode, package)
        seed_matches = parse_int(target["dpd_mode"]) == mode and parse_int(target["dpd_package"]) == package
        if initial_cost is None:
            status, realized_cost, candidates = "selected_seed_missing", "", 0
        elif decision == "direct":
            status, realized_cost, candidates = "validated_direct_full_trace", initial_cost, 1
        elif seed_matches:
            status, realized_cost, candidates = "validated_local_search", parse_int(target["local_search_final_cost"]), 14
        else:
            requested_replay = {**target, "dpd_mode": str(mode), "dpd_package": str(package)}
            matching_replays = [replay for replay in joint_replays
                                if replay_key(replay) == replay_key(requested_replay)]
            if matching_replays:
                replay = matching_replays[-1]
                status = "validated_joint_seed_replay"
                realized_cost = parse_int(replay["final_cost"])
                candidates = parse_int(replay["records"])
            else:
                status, realized_cost, candidates = "board_replay_required", "", 14
        fixed = {}
        for config in sorted({row["dsm_config_id"] for row in held}):
            item = next(row for row in held if row["dsm_config_id"] == config)
            fixed[config] = parse_int(item["local_search_final_cost"])
        results.append({
            **dict(zip(GROUP_FIELDS, key)), "status": status,
            "selected_dsm_config": selected_seed_row["dsm_config_id"],
            "selected_dsm_algorithm": selected_seed_row["dsm_algorithm"],
            "selected_dpd_mode": mode, "selected_dpd_package": package,
            "expected_search_benefit": f"{expected_benefit:.6f}", "decision": decision,
            "seed_matches_measured_local_trace": int(seed_matches),
            "realized_cost": realized_cost, "candidate_count": candidates,
            "fixed_local_costs": ";".join(f"{name}:{value}" for name, value in fixed.items()),
            "best_fixed_local_cost": min(fixed.values()),
            "joint_minus_best_fixed": "" if realized_cost == "" else int(realized_cost) - min(fixed.values()),
        })
    validated = [row for row in results if row.get("realized_cost", "") != ""]
    aggregate = {
        "held_waveform_conditions": len(results), "validated_actions": len(validated),
        "board_replay_required": sum(row["status"] == "board_replay_required" for row in results),
        "mean_joint_minus_best_fixed": ("" if not validated else statistics.fmean(float(row["joint_minus_best_fixed"]) for row in validated)),
        "mean_candidates": ("" if not validated else statistics.fmean(float(row["candidate_count"]) for row in validated)),
    }
    return results, aggregate


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else [])
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, aggregate: dict[str, object]) -> None:
    path.write_text("\n".join([
        "# Joint DSM + DPD LOSO Report", "",
        "Each held waveform/PA condition excludes every DSM replicate of that condition from training.",
        "Inputs are waveform fields, DSM metadata, and first-candidate PL monitor state.",
        "A local-search result is validated only by a matching held trace or an explicitly supplied matching board replay.", "",
        f"- Held waveform conditions: `{aggregate['held_waveform_conditions']}`",
        f"- Validated actions: `{aggregate['validated_actions']}`",
        f"- Required future board replays: `{aggregate['board_replay_required']}`",
        f"- Mean joint minus best fixed local cost: `{aggregate['mean_joint_minus_best_fixed']}`",
        f"- Mean joint candidates: `{aggregate['mean_candidates']}`", "",
        "This is a Python/PS design evaluation, not a TinyML RTL result or RF performance claim.", "",
    ]), encoding="ascii")


def self_test() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        rows = []
        for condition, qam in (("a", 16), ("b", 64)):
            for config, algorithm, cost in (("ef1", 2, 100), ("ef2", 3, 90)):
                trace = root / f"{condition}_{config}.csv"
                trace.write_text("stage,mode,package,cost\npackage,1,3,100\n", encoding="ascii")
                rows.append({"pa_profile": "n", "pa_strength_db": "0", "qam": str(qam), "bandwidth_mhz": "20", "used_subcarriers": "48", "input_backoff": "0.58", "waveform_id": condition, "dsm_config_id": config, "dsm_algorithm": str(algorithm), "dpd_mode": "1", "dpd_package": "3", "search_benefit": "5", "local_search_final_cost": str(cost), "full_calibration_trace_csv": str(trace), "mon_input_power": "100", "mon_peak": "200", "mon_avg_mag": "150", "mon_evm_proxy": "10", "mon_acpr_proxy": "20", "mon_spec_bin0": "1", "mon_spec_bin1": "2", "mon_spec_bin2": "3", "mon_spec_adj": "4"})
        result, aggregate = evaluate(rows, [], 2, 1.0)
        assert len(result) == 2 and aggregate["validated_actions"] == 2
    print("PASS joint DSM+DPD LOSO self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-csv", type=Path)
    parser.add_argument("--joint-replay-csv", action="append", type=Path, default=[],
                        help="Optional validated 14-candidate replays for held seed mismatches.")
    parser.add_argument("--neighbors", type=int, default=5)
    parser.add_argument("--search-benefit-budget", type=float, default=100.0)
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out/dsm_aware_dataset"))
    parser.add_argument("--prefix", default="joint_dsm_dpd_loso")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.dataset_csv:
        parser.error("--dataset-csv is required")
    replays = [row for path in args.joint_replay_csv for row in read_csv(path)]
    required_replay_columns = set(GROUP_FIELDS) | {"dsm_config_id", "dpd_mode", "dpd_package",
                                                    "records", "final_cost"}
    for replay in replays:
        if required_replay_columns - set(replay):
            raise ValueError("Joint replay CSV lacks required provenance or result columns")
        if parse_int(replay["records"]) != 14:
            raise ValueError("Joint replay must contain exactly 14 trace records")
    rows, aggregate = evaluate(read_csv(args.dataset_csv), replays,
                               args.neighbors, args.search_benefit_budget)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.out_dir / f"{args.prefix}.csv", rows)
    write_report(args.out_dir / f"{args.prefix}.md", aggregate)
    print(f"Validated actions: {aggregate['validated_actions']}/{aggregate['held_waveform_conditions']}")
    print(f"Board replays required: {aggregate['board_replay_required']}")


if __name__ == "__main__":
    main()
