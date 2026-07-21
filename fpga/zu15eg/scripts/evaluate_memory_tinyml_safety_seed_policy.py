#!/usr/bin/env python3
"""Fit a safety-first DPD seed policy without touching frozen blind PA data.

The policy never enables a one-candidate path.  It selects an initial package
only when nearest development evidence for that package is unanimously safe;
otherwise it returns FALLBACK and the existing 14-candidate bounded search
remains responsible for calibration.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from collections import defaultdict
from pathlib import Path

from evaluate_memory_tinyml_loso import FALLBACK, PACKAGE_COUNT, distance, normalize, read_conditions


BLIND_PROFILE_IDS = frozenset((
    "blind_gain_memory",
    "blind_compression_noise",
    "blind_thermal_memory",
))
K_OPTIONS = (3, 5, 7)
# A finite in-distribution bound is mandatory for an unknown-PA safety claim.
DISTANCE_OPTIONS = (1.50, 2.50, 4.00)


def profile_ids(rows: list[dict[str, object]]) -> set[str]:
    return {str(row["profile_id"]) for row in rows}


def assert_contract(base: list[dict[str, object]], development: list[dict[str, object]],
                    blind: list[dict[str, object]]) -> None:
    base_ids = profile_ids(base)
    development_ids = profile_ids(development)
    blind_ids = profile_ids(blind)
    if blind_ids != BLIND_PROFILE_IDS:
        raise ValueError(f"Blind profile IDs changed: expected {sorted(BLIND_PROFILE_IDS)}, got {sorted(blind_ids)}")
    if base_ids & development_ids or base_ids & blind_ids or development_ids & blind_ids:
        raise ValueError("Training, development, and blind profile sets must be disjoint")
    if any(profile.startswith("blind_") for profile in base_ids | development_ids):
        raise ValueError("Blind profiles cannot enter fitting, threshold selection, or model choice")
    if len(development_ids) < 2:
        raise ValueError("At least two development profiles are required for leave-one-profile-out validation")


def package_evidence(train: list[dict[str, object]], row: dict[str, object], package: int,
                     k: int) -> list[dict[str, object]]:
    same_waveform = [candidate for candidate in train
                     if str(candidate["waveform_id"]) == str(row["waveform_id"])]
    ordered = sorted(same_waveform, key=lambda candidate: distance(row["x"], candidate["x"]))
    return ordered[:k]


def choose_seed(train: list[dict[str, object]], row: dict[str, object], k: int,
                max_distance: float) -> dict[str, object]:
    qualified: list[tuple[float, float, int, int]] = []
    for package in range(PACKAGE_COUNT):
        evidence = package_evidence(train, row, package, k)
        if len(evidence) != k:
            continue
        nearest_distance = distance(row["x"], evidence[0]["x"])
        package_rows = [candidate["packages"].get(package) for candidate in evidence]
        if nearest_distance > max_distance or any(candidate is None for candidate in package_rows):
            continue
        # Safety is the gate. Cost may only rank already safe packages.
        if any(int(candidate["safe"]) == 0 for candidate in package_rows):
            continue
        expected_cost = sum(float(candidate["cost"]) for candidate in package_rows) / k
        qualified.append((expected_cost, nearest_distance, package, k))
    if not qualified:
        return {"package": FALLBACK, "source": "fallback_14", "nearest_distance": math.nan,
                "safe_support": 0, "expected_cost": math.nan}
    expected_cost, nearest_distance, package, support = min(qualified)
    return {"package": package, "source": "safety_knn", "nearest_distance": nearest_distance,
            "safe_support": support, "expected_cost": expected_cost}


def evaluate_split(train: list[dict[str, object]], test: list[dict[str, object]], k: int,
                   max_distance: float, held_profile: str) -> tuple[list[dict[str, object]], dict[str, object]]:
    normalize(train, test)
    decisions: list[dict[str, object]] = []
    for row in test:
        choice = choose_seed(train, row, k, max_distance)
        package = int(choice["package"])
        package_row = row["packages"].get(package)
        unsafe = int(package != FALLBACK and (package_row is None or int(package_row["safe"]) == 0))
        regret = (float(package_row["cost"]) - float(row["oracle_cost"])
                  if package_row is not None and not math.isnan(float(row["oracle_cost"])) else math.nan)
        decisions.append({
            "held_profile": held_profile,
            "condition_id": row["condition_id"],
            "profile_id": row["profile_id"],
            "oracle_package": row["label"],
            "selected_seed": package,
            "seed_source": choice["source"],
            "seed_safe": "" if package == FALLBACK else 1 - unsafe,
            "seed_regret": "" if math.isnan(regret) else f"{regret:.6f}",
            "nearest_distance": "" if math.isnan(float(choice["nearest_distance"])) else f"{float(choice['nearest_distance']):.6f}",
            "safe_support": choice["safe_support"],
            "expected_safe_cost": "" if math.isnan(float(choice["expected_cost"])) else f"{float(choice['expected_cost']):.6f}",
            "mandatory_search_candidates": 14,
            "deployment_action": "fallback_14",
            "seed_safety_violation": unsafe,
        })
    seeds = [row for row in decisions if row["selected_seed"] != FALLBACK]
    regret_values = [float(row["seed_regret"]) for row in seeds
                     if str(row["seed_regret"]) != ""]
    return decisions, {
        "held_profile": held_profile,
        "conditions": len(test),
        "safe_seed_count": len(seeds),
        "fallback_14_count": len(test) - len(seeds),
        "seed_safety_violations": sum(int(row["seed_safety_violation"]) for row in decisions),
        "mean_seed_regret": (sum(regret_values) / len(regret_values)) if regret_values else math.nan,
        "mandatory_search_candidates": 14,
    }


def evaluate_development(base: list[dict[str, object]], development: list[dict[str, object]],
                         k: int, max_distance: float) -> tuple[list[dict[str, object]], dict[str, object]]:
    decisions: list[dict[str, object]] = []
    folds: list[dict[str, object]] = []
    for held_profile in sorted(profile_ids(development)):
        held = [row for row in development if str(row["profile_id"]) == held_profile]
        fit = base + [row for row in development if str(row["profile_id"]) != held_profile]
        fold_decisions, fold = evaluate_split(fit, held, k, max_distance, held_profile)
        decisions.extend(fold_decisions)
        folds.append(fold)
    seeds = [row for row in decisions if row["selected_seed"] != FALLBACK]
    regret_values = [float(row["seed_regret"]) for row in seeds
                     if str(row["seed_regret"]) != ""]
    return decisions, {
        "k": k,
        "max_distance": None if math.isinf(max_distance) else max_distance,
        "development_profiles": len(folds),
        "development_conditions": len(decisions),
        "safe_seed_count": len(seeds),
        "fallback_14_count": len(decisions) - len(seeds),
        "seed_safety_violations": sum(int(row["seed_safety_violation"]) for row in decisions),
        "mean_seed_regret": (sum(regret_values) / len(regret_values)) if regret_values else math.nan,
        "folds": folds,
    }


def select_policy(base: list[dict[str, object]], development: list[dict[str, object]]) -> tuple[dict[str, object], list[dict[str, object]]]:
    candidates: list[dict[str, object]] = []
    for k in K_OPTIONS:
        for max_distance in DISTANCE_OPTIONS:
            _, report = evaluate_development(base, development, k, max_distance)
            candidates.append(report)
    # Safety is lexicographically primary; only then seek useful coverage and lower regret.
    candidates.sort(key=lambda report: (
        int(report["seed_safety_violations"]),
        -int(report["safe_seed_count"]),
        float("inf") if math.isnan(float(report["mean_seed_regret"])) else float(report["mean_seed_regret"]),
        int(report["k"]),
        math.inf if report["max_distance"] is None else float(report["max_distance"]),
    ))
    return candidates[0], candidates


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-train", type=Path, required=True)
    parser.add_argument("--development", type=Path, required=True)
    parser.add_argument("--blind", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    base = read_conditions(args.base_train)
    development = read_conditions(args.development)
    blind = read_conditions(args.blind)
    assert_contract(base, development, blind)
    selected, candidates = select_policy(base, development)
    k = int(selected["k"])
    max_distance = math.inf if selected["max_distance"] is None else float(selected["max_distance"])
    development_decisions, development_report = evaluate_development(base, development, k, max_distance)
    # The blind data is consumed only here, after selection is frozen from development LOSO.
    blind_decisions, blind_summary = evaluate_split(base + development, blind, k, max_distance, "final_blind")
    promotion = (int(development_report["seed_safety_violations"]) == 0 and
                 int(blind_summary["seed_safety_violations"]) == 0 and
                 int(blind_summary["safe_seed_count"]) > 0)
    report = {
        "policy": "safety_first_nearest_safe_package_v1",
        "feature_schema": "aligned_complex_pa_monitor_v2",
        "blind_profile_ids": sorted(BLIND_PROFILE_IDS),
        "blind_data_used_for_selection": False,
        "selected_hyperparameters": {"k": k, "max_distance": selected["max_distance"]},
        "selection_rule": "among finite in-distribution bounds, minimize development seed safety violations, then maximize safety-qualified seed coverage, then minimize seed regret",
        "development_validation": development_report,
        "model_selection_candidates": candidates,
        "final_blind_test": blind_summary,
        "mandatory_search_candidates": 14,
        "direct_execution_allowed": False,
        "tinyml_axi_integration_enabled": False,
        "promotion_allowed": promotion,
        "promotion_rule": "zero development and blind unsafe selected seeds plus at least one blind safety-qualified seed; all runs retain 14-candidate local search",
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.out_dir / "memory_tinyml_safety_seed_development_decisions.csv", development_decisions)
    write_csv(args.out_dir / "memory_tinyml_safety_seed_blind_decisions.csv", blind_decisions)
    with (args.out_dir / "memory_tinyml_safety_seed_policy.json").open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2, allow_nan=False)
        handle.write("\n")
    with (args.out_dir / "memory_tinyml_safety_seed_policy.md").open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# Safety-First DPD Seed Policy\n\n")
        handle.write("The three `blind_*` PA profiles are frozen final-test data and are never used for fitting, threshold selection, or model choice. A package is seeded only when all same-waveform nearest nonblind observations are safe and the nearest monitor state is inside the selected finite distance bound; cost ranks only those safety-qualified packages. Every action remains a 14-candidate local search.\n\n")
        handle.write("| Data split | Conditions | Safety-qualified seeds | Fallback-14 | Unsafe selected seeds | Mean seed regret |\n")
        handle.write("|---|---:|---:|---:|---:|---:|\n")
        for name, summary in (("Development PA LOSO", development_report), ("Frozen final blind PA", blind_summary)):
            regret = summary["mean_seed_regret"]
            regret_text = "n/a" if math.isnan(float(regret)) else f"{float(regret):.3f}"
            condition_count = summary["development_conditions"] if "development_conditions" in summary else summary["conditions"]
            handle.write(f"| {name} | {condition_count} | {summary['safe_seed_count']} | {summary['fallback_14_count']} | {summary['seed_safety_violations']} | {regret_text} |\n")
        handle.write(f"\nSelected only from development LOSO: `k={k}`, `max_distance={selected['max_distance']}`. Promotion allowed: **{promotion}**. Direct execution remains disabled.\n")
    print(json.dumps(report, indent=2, allow_nan=False))
    return 0 if promotion else 1


if __name__ == "__main__":
    raise SystemExit(main())
