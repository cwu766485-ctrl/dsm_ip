#!/usr/bin/env python3
"""Evaluate simulation-only seed/regret policy under three strict LOSO splits.

The input is emitted by ``run_dpd_seed_regret_benchmark.m``.  No board trace,
policy header, or RF claim is accepted as an input to this tool.  A direct
decision always starts from a selected polynomial package and is compared with
the same package's measured one-round, 14-candidate local-search label.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import tempfile
from collections import defaultdict
from pathlib import Path


MONITORS = ("input_power", "output_power", "peak", "avg_mag", "evm_proxy",
            "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
            "clip", "saturation")
REQUIRED = {"profile_id", "waveform_id", "simulation_seed", "seed_package",
            "best_seed", "initial_cost", "final_cost", "local_search_regret",
            "initial_evm_pct", "final_evm_pct", "initial_aclr_db", "final_aclr_db",
            "candidate_count_local", *MONITORS}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def as_int(row: dict[str, str], field: str) -> int:
    return int(round(float(row[field])))


def as_float(row: dict[str, str], field: str) -> float:
    return float(row[field])


def load_rows(path: Path) -> list[dict[str, object]]:
    raw = read_csv(path)
    if not raw or REQUIRED - set(raw[0]):
        missing = sorted(REQUIRED - set(raw[0] if raw else ()))
        raise ValueError(f"Benchmark is empty or missing columns: {', '.join(missing)}")
    rows = []
    for index, item in enumerate(raw, start=2):
        try:
            row = {"profile_id": item["profile_id"].strip(),
                   "waveform_id": item["waveform_id"].strip(),
                   "simulation_seed": as_int(item, "simulation_seed"),
                   "seed_package": as_int(item, "seed_package"),
                   "best_seed": as_int(item, "best_seed"),
                   "initial_cost": as_float(item, "initial_cost"),
                   "final_cost": as_float(item, "final_cost"),
                   "local_search_regret": as_float(item, "local_search_regret"),
                   "initial_evm_pct": as_float(item, "initial_evm_pct"),
                   "final_evm_pct": as_float(item, "final_evm_pct"),
                   "initial_aclr_db": as_float(item, "initial_aclr_db"),
                   "final_aclr_db": as_float(item, "final_aclr_db"),
                   "candidate_count_local": as_int(item, "candidate_count_local")}
            row.update({field: as_int(item, field) for field in MONITORS})
            rows.append(row)
        except (KeyError, ValueError) as exc:
            raise ValueError(f"Invalid benchmark row {index}: {exc}") from exc
    if {row["seed_package"] for row in rows} != set(range(6)):
        raise ValueError("Benchmark must contain deterministic packages 0 through 5")
    return rows


def metadata_features(row: dict[str, object]) -> tuple[float, ...]:
    waveform = str(row["waveform_id"])
    return (64.0 if "qam64" in waveform else 16.0,
            40.0 if "bw40" in waveform else 20.0,
            0.70 if "bo070" in waveform else 0.58)


def monitor_features(row: dict[str, object]) -> tuple[float, ...]:
    inp = max(float(row["input_power"]), 1.0)
    out = max(float(row["output_power"]), 1.0)
    peak = float(row["peak"]) / 65536.0
    avg = float(row["avg_mag"]) / 65536.0
    return (*metadata_features(row), out / inp, peak / max(avg, 1.0),
            float(row["evm_proxy"]) / inp, float(row["acpr_proxy"]) / out,
            float(row["spec_adj"]) / max(float(row["spec_bin1"]), 1.0),
            float(row["spec_bin2"]) / max(float(row["spec_bin0"]), 1.0))


def feature_scales(samples: list[tuple[float, ...]]) -> tuple[float, ...]:
    scales = []
    for column in zip(*samples):
        ordered = sorted(column)
        scales.append(max(ordered[3 * (len(ordered) - 1) // 4] -
                          ordered[(len(ordered) - 1) // 4], 1e-9))
    return tuple(scales)


def normalized_distance(left: tuple[float, ...], right: tuple[float, ...],
                        scales: tuple[float, ...]) -> float:
    return math.sqrt(sum(((a - b) / scale) ** 2
                         for a, b, scale in zip(left, right, scales)))


def weighted_best_seed(training: list[dict[str, object]], target: dict[str, object],
                       scales: tuple[float, ...]) -> int:
    target_f = metadata_features(target)
    scores: dict[int, list[tuple[float, int]]] = defaultdict(list)
    for row in training:
        distance = normalized_distance(metadata_features(row), target_f, scales)
        scores[int(row["seed_package"])].append((1.0 / max(distance, 1e-6),
                                                   float(row["final_cost"])))
    if not scores:
        raise ValueError("No training records")
    result = []
    for package, values in scores.items():
        total = sum(weight for weight, _ in values)
        result.append((sum(weight * cost for weight, cost in values) / total, package))
    return min(result)[1]


def predict_regret(training: list[dict[str, object]], selected: dict[str, object],
                   scales: tuple[float, ...]) -> tuple[int, int, int, float]:
    target = monitor_features(selected)
    ranked = sorted((normalized_distance(monitor_features(row), target, scales),
                     float(row["local_search_regret"])) for row in training)[:5]
    weights = [1.0 / max(distance, 1e-6) for distance, _ in ranked]
    total = sum(weights)
    mean = sum(weight * regret for weight, (_, regret) in zip(weights, ranked)) / total
    spread = math.sqrt(sum(weight * (regret - mean) ** 2
                           for weight, (_, regret) in zip(weights, ranked)) / total)
    return round(mean), round(spread), round(ranked[0][0] * 1_000_000), ranked[0][0]


def direct_label_safe(row: dict[str, object], regret_budget: int,
                      evm_limit: float, aclr_limit: float) -> bool:
    best_final = min(float(item["final_cost"]) for item in row["sample_rows"])
    return (float(row["initial_cost"]) - best_final <= regret_budget and
            float(row["initial_evm_pct"]) <= evm_limit and
            float(row["initial_aclr_db"]) <= aclr_limit and
            row["clip"] == 0 and row["saturation"] == 0)


def predict_neighbor_safety(training: list[dict[str, object]], selected: dict[str, object],
                            scales: tuple[float, ...], regret_budget: int,
                            evm_limit: float, aclr_limit: float) -> tuple[int, int]:
    target = monitor_features(selected)
    grouped: dict[tuple[object, object, object], list[dict[str, object]]] = defaultdict(list)
    for row in training:
        grouped[(row["profile_id"], row["waveform_id"], row["simulation_seed"])].append(row)
    labeled = []
    for rows in grouped.values():
        for row in rows:
            labeled.append((normalized_distance(monitor_features(row), target, scales),
                            direct_label_safe({**row, "sample_rows": rows}, regret_budget,
                                              evm_limit, aclr_limit)))
    nearest = sorted(labeled)[:5]
    return sum(safe for _, safe in nearest), len(nearest)


def group_value(row: dict[str, object], split: str) -> object:
    return row[{"profile": "profile_id", "waveform": "waveform_id", "seed": "simulation_seed"}[split]]


def evaluate_split(rows: list[dict[str, object]], split: str, regret_budget: int,
                   evm_limit: float, aclr_limit: float) -> list[dict[str, object]]:
    records = []
    values = sorted({group_value(row, split) for row in rows}, key=str)
    for held_value in values:
        held = [row for row in rows if group_value(row, split) == held_value]
        training = [row for row in rows if group_value(row, split) != held_value]
        if not training:
            continue
        metadata_scales = feature_scales([metadata_features(row) for row in training])
        monitor_scales = feature_scales([monitor_features(row) for row in training])
        lookup = {(row["profile_id"], row["waveform_id"], row["simulation_seed"], row["seed_package"]): row
                  for row in held}
        for key in sorted({(row["profile_id"], row["waveform_id"], row["simulation_seed"]) for row in held}):
            sample_rows = [row for row in held if (row["profile_id"], row["waveform_id"], row["simulation_seed"]) == key]
            target = sample_rows[0]
            fixed = lookup[key + (3,)]
            predicted_seed = weighted_best_seed(training, target, metadata_scales)
            selected = lookup[key + (predicted_seed,)]
            predicted, uncertainty, distance_ppm, _ = predict_regret(training, selected, monitor_scales)
            safety_neighbors, safety_neighbor_count = predict_neighbor_safety(
                training, selected, monitor_scales, regret_budget, evm_limit, aclr_limit)
            direct = (predicted + uncertainty <= regret_budget and
                      safety_neighbors == safety_neighbor_count and
                      selected["clip"] == 0 and selected["saturation"] == 0)
            best_final = min(float(row["final_cost"]) for row in sample_rows)
            fixed_cost = float(fixed["initial_cost"])
            knn_cost = float(selected["initial_cost"])
            action_final = float(selected["initial_cost"] if direct else selected["final_cost"])
            action_evm = float(selected["initial_evm_pct"] if direct else selected["final_evm_pct"])
            action_aclr = float(selected["initial_aclr_db"] if direct else selected["final_aclr_db"])
            direct_regret = float(selected["initial_cost"]) - best_final
            direct_validation_ok = (direct_regret <= regret_budget and
                                    float(selected["initial_evm_pct"]) <= evm_limit and
                                    float(selected["initial_aclr_db"]) <= aclr_limit and
                                    selected["clip"] == 0 and selected["saturation"] == 0)
            records.append({
                "split": split, "held_group": held_value, "profile_id": key[0],
                "waveform_id": key[1], "simulation_seed": key[2],
                "fixed_package_3_candidates": 1, "fixed_package_3_cost": fixed_cost,
                "fixed_package_3_regret": fixed_cost - best_final,
                "fixed_package_3_evm_pct": fixed["initial_evm_pct"],
                "fixed_package_3_aclr_db": fixed["initial_aclr_db"],
                "knn_seed": predicted_seed, "knn_seed_candidates": 1,
                "knn_seed_cost": knn_cost, "knn_seed_regret": knn_cost - best_final,
                "knn_seed_evm_pct": selected["initial_evm_pct"],
                "knn_seed_aclr_db": selected["initial_aclr_db"],
                "unconditional_local_candidates": selected["candidate_count_local"],
                "unconditional_local_final_cost": selected["final_cost"],
                "unconditional_local_regret": float(selected["final_cost"]) - best_final,
                "unconditional_local_evm_pct": selected["final_evm_pct"],
                "unconditional_local_aclr_db": selected["final_aclr_db"],
                "best_seed": target["best_seed"], "best_final_cost": best_final,
                "predicted_regret": predicted, "predicted_uncertainty": uncertainty,
                "nearest_feature_distance_ppm": distance_ppm,
                "safe_neighbor_count": safety_neighbors,
                "safety_neighbor_count": safety_neighbor_count,
                "regret_budget": regret_budget, "action": "direct" if direct else "local_search",
                "gated_candidates": 1 if direct else selected["candidate_count_local"],
                "gated_final_cost": action_final, "gated_regret": action_final - best_final,
                "gated_evm_pct": action_evm, "gated_aclr_db": action_aclr,
                "direct_actual_regret": direct_regret,
                "direct_validation_ok": int(not direct or direct_validation_ok),
            })
    return records


def aggregate(records: list[dict[str, object]], evm_limit: float, aclr_limit: float) -> dict[str, object]:
    if not records:
        return {"record_count": 0, "direct_count": 0, "direct_rate": 0.0,
                "mean_gated_candidates": 0.0, "mean_local_candidates": 0.0,
                "mean_candidate_reduction": 0.0, "mean_gated_regret": 0.0,
                "max_gated_regret": 0, "mean_fixed_package_3_regret": 0.0,
                "mean_knn_seed_regret": 0.0, "direct_constraint_preserved": False,
                "evm_limit_pct": evm_limit, "aclr_limit_dbc": aclr_limit,
                "export_allowed": False, "status": "insufficient_training"}
    direct = [row for row in records if row["action"] == "direct"]
    direct_safe = all(row["direct_validation_ok"] for row in direct)
    mean_candidates = sum(int(row["gated_candidates"]) for row in records) / len(records)
    local_candidates = sum(int(row["unconditional_local_candidates"]) for row in records) / len(records)
    # Export requires a nontrivial reduction and no held direct constraint breach.
    export_allowed = bool(direct and direct_safe and mean_candidates < local_candidates)
    return {"record_count": len(records), "direct_count": len(direct),
            "direct_rate": len(direct) / len(records),
            "mean_gated_candidates": mean_candidates,
            "mean_local_candidates": local_candidates,
            "mean_candidate_reduction": local_candidates - mean_candidates,
            "mean_gated_regret": sum(float(row["gated_regret"]) for row in records) / len(records),
            "max_gated_regret": max(float(row["gated_regret"]) for row in records),
            "mean_fixed_package_3_regret": sum(float(row["fixed_package_3_regret"]) for row in records) / len(records),
            "mean_knn_seed_regret": sum(float(row["knn_seed_regret"]) for row in records) / len(records),
            "direct_constraint_preserved": direct_safe,
            "evm_limit_pct": evm_limit, "aclr_limit_dbc": aclr_limit,
            "export_allowed": export_allowed, "status": "evaluated"}


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, aggregate_result: dict[str, object]) -> None:
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# Seed/Regret Strict LOSO Report\n\n")
        handle.write("This is behavioral memory-PA/observation simulation only. It is not physical PA, receiver, EVM, or ACLR evidence.\n\n")
        for split, values in aggregate_result["splits"].items():
            handle.write(f"## Leave-One-{split.title()}\n\n")
            for key, value in values.items():
                handle.write(f"- {key.replace('_', ' ')}: `{value}`\n")
            handle.write("\n")
        handle.write("## Export Gate\n\n")
        handle.write(f"- export allowed: `{aggregate_result['export_allowed']}`\n")
        handle.write("- Gate requires direct candidate reduction and no held direct EVM/ACLR proxy breach in every strict split.\n")


def evaluate(path: Path, out_dir: Path, regret_budget: int, evm_limit: float,
             aclr_limit: float) -> dict[str, object]:
    rows = load_rows(path)
    outputs = {}
    all_allowed = True
    for split in ("profile", "waveform", "seed"):
        decisions = evaluate_split(rows, split, regret_budget, evm_limit, aclr_limit)
        summary = aggregate(decisions, evm_limit, aclr_limit)
        all_allowed = all_allowed and bool(summary["export_allowed"])
        csv_path = out_dir / f"dpd_seed_regret_loso_{split}.csv"
        if decisions:
            write_csv(csv_path, decisions)
        outputs[split] = summary
    result = {"benchmark": str(path), "simulation_only": True,
              "dsm_config_id": "efdsm_1bit_osr32_interp0",
              "regret_budget": regret_budget, "splits": outputs,
              "export_allowed": all_allowed}
    with (out_dir / "dpd_seed_regret_loso.json").open("w", encoding="ascii", newline="\n") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
        handle.write("\n")
    write_report(out_dir / "dpd_seed_regret_loso.md", result)
    return result


def run_self_test() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        source = root / "bench.csv"
        fields = list(REQUIRED)
        with source.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            for profile in ("p0", "p1"):
                for waveform in ("qam16_bw20_bo058", "qam64_bw40_bo070"):
                    for seed in (41, 53):
                        for package in range(6):
                            cost = 100 + package * 10
                            row = {field: 0 for field in fields}
                            row.update({"profile_id": profile, "waveform_id": waveform,
                                        "simulation_seed": seed, "seed_package": package,
                                        "best_seed": 0, "initial_cost": cost + 5,
                                        "final_cost": cost, "local_search_regret": 5,
                                        "initial_evm_pct": 1.0, "final_evm_pct": 1.0,
                                        "initial_aclr_db": -30.0, "final_aclr_db": -30.0,
                                        "candidate_count_local": 14, "input_power": 1000,
                                        "output_power": 1000, "peak": 1, "avg_mag": 1})
                            writer.writerow(row)
        result = evaluate(source, root, 100, 8.0, -20.0)
        assert result["export_allowed"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--out-dir", type=Path)
    parser.add_argument("--regret-budget", type=int, default=100)
    parser.add_argument("--evm-limit-pct", type=float, default=8.0)
    parser.add_argument("--aclr-limit-dbc", type=float, default=-20.0)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
        print("seed/regret LOSO self-test passed")
        return 0
    if args.input is None or args.out_dir is None:
        parser.error("--input and --out-dir are required unless --self-test is used")
    args.out_dir.mkdir(parents=True, exist_ok=True)
    result = evaluate(args.input, args.out_dir, args.regret_budget,
                      args.evm_limit_pct, args.aclr_limit_dbc)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
