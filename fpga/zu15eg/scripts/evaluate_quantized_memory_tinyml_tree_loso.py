#!/usr/bin/env python3
"""Evaluate the deployable fixed-point tree policy under PA-profile LOSO."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_memory_tinyml_loso import (  # noqa: E402
    FALLBACK,
    LutModel,
    normalize,
    read_conditions,
    safety_gate,
)
from export_memory_tinyml_tree import infer, make_model, quantize  # noqa: E402


def evaluate(conditions: list[dict[str, object]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    profiles = sorted({str(row["profile_id"]) for row in conditions})
    decisions = []
    folds = []
    for held_profile in profiles:
        train = [dict(row) for row in conditions if str(row["profile_id"]) != held_profile]
        held = [dict(row) for row in conditions if str(row["profile_id"]) == held_profile]
        model, fit_report = make_model(train)
        lut_train = [dict(row) for row in conditions if str(row["profile_id"]) != held_profile]
        lut_held = [dict(row) for row in conditions if str(row["profile_id"]) == held_profile]
        normalize(lut_train, lut_held)
        lut = LutModel()
        lut.fit(lut_train)
        lut_regret = 0.0
        lut_candidates = 0
        lut_violations = 0
        lut_actions: dict[str, tuple[int, int, int, float]] = {}
        for lut_row in lut_held:
            lut_package, confidence = lut.predict(lut_row)
            release, _, _ = safety_gate(lut_train, lut_row, lut_package, confidence)
            if release:
                package_row = lut_row["packages"][lut_package]
                lut_violations += int(int(package_row["safe"]) == 0)
                if not math.isnan(float(lut_row["oracle_cost"])):
                    lut_regret += float(package_row["cost"]) - float(lut_row["oracle_cost"])
                lut_candidates += 1
                lut_actions[str(lut_row["condition_id"])] = (
                    lut_package, 1, int(int(package_row["safe"]) == 0),
                    (float(package_row["cost"]) - float(lut_row["oracle_cost"]))
                    if not math.isnan(float(lut_row["oracle_cost"])) else 0.0)
            else:
                lut_candidates += 14
                lut_actions[str(lut_row["condition_id"])] = (FALLBACK, 14, 0, 0.0)
        fold = {
            "held_profile": held_profile,
            "train_conditions": len(train),
            "held_conditions": len(held),
            "direct": 0,
            "fallback": 0,
            "safety_violations": 0,
            "regret": 0.0,
            "candidates": 0,
            "fit_float_fixed_path_mismatches": fit_report["float_fixed_path_mismatches"],
            "lut_safety_violations": lut_violations,
            "lut_mean_regret": lut_regret / len(lut_held),
            "lut_mean_candidates": lut_candidates / len(lut_held),
            "hybrid_direct": 0,
            "hybrid_fallback": 0,
            "hybrid_safety_violations": 0,
            "hybrid_regret": 0.0,
            "hybrid_candidates": 0,
        }
        for row in held:
            features = tuple(quantize(float(value)) for value in row["feature"])
            result = infer(model, features)
            package = int(result["package"])
            violation = 0
            regret = 0.0
            if result["direct"]:
                package_row = row["packages"][package]
                violation = int(int(package_row["safe"]) == 0)
                if not math.isnan(float(row["oracle_cost"])):
                    regret = float(package_row["cost"]) - float(row["oracle_cost"])
                fold["direct"] += 1
                fold["candidates"] += 1
            else:
                fold["fallback"] += 1
                fold["candidates"] += 14
            fold["safety_violations"] += violation
            fold["regret"] += regret
            if result["direct"]:
                hybrid_package = package
                hybrid_candidates = 1
                hybrid_violation = violation
                hybrid_regret = regret
                hybrid_source = "tree"
            else:
                hybrid_package, hybrid_candidates, hybrid_violation, hybrid_regret = \
                    lut_actions[str(row["condition_id"])]
                hybrid_source = "lut" if hybrid_candidates == 1 else "fallback_14"
            fold["hybrid_direct"] += int(hybrid_candidates == 1)
            fold["hybrid_fallback"] += int(hybrid_candidates == 14)
            fold["hybrid_safety_violations"] += hybrid_violation
            fold["hybrid_regret"] += hybrid_regret
            fold["hybrid_candidates"] += hybrid_candidates
            decisions.append({
                "held_profile": held_profile,
                "condition_id": row["condition_id"],
                "oracle_package": row["label"],
                "action_package": package,
                "action": "direct" if result["direct"] else "fallback_14",
                "decision_path": result["path"],
                "decision_path_length": result["path_len"],
                "out_of_distribution": result["ood"],
                "safety_violation": violation,
                "regret": regret,
                "candidate_count": 1 if result["direct"] else 14,
                "hybrid_package": hybrid_package,
                "hybrid_source": hybrid_source,
                "hybrid_safety_violation": hybrid_violation,
                "hybrid_regret": hybrid_regret,
                "hybrid_candidate_count": hybrid_candidates,
            })
        fold["mean_regret"] = fold.pop("regret") / len(held)
        fold["mean_candidates"] = fold.pop("candidates") / len(held)
        fold["hybrid_mean_regret"] = fold.pop("hybrid_regret") / len(held)
        fold["hybrid_mean_candidates"] = fold.pop("hybrid_candidates") / len(held)
        fold["not_worse_than_lut"] = (
            fold["safety_violations"] == 0 and
            fold["mean_regret"] <= fold["lut_mean_regret"] + 1e-9 and
            fold["mean_candidates"] <= fold["lut_mean_candidates"] + 1e-9)
        fold["strictly_better_than_lut"] = (
            fold["not_worse_than_lut"] and
            (fold["mean_regret"] < fold["lut_mean_regret"] - 1e-9 or
             fold["mean_candidates"] < fold["lut_mean_candidates"] - 1e-9))
        fold["hybrid_not_worse_than_lut"] = (
            fold["hybrid_safety_violations"] == 0 and
            fold["hybrid_mean_regret"] <= fold["lut_mean_regret"] + 1e-9 and
            fold["hybrid_mean_candidates"] <= fold["lut_mean_candidates"] + 1e-9)
        fold["hybrid_strictly_better_than_lut"] = (
            fold["hybrid_not_worse_than_lut"] and
            (fold["hybrid_mean_regret"] < fold["lut_mean_regret"] - 1e-9 or
             fold["hybrid_mean_candidates"] < fold["lut_mean_candidates"] - 1e-9))
        folds.append(fold)

    report = {
        "profiles": len(profiles),
        "conditions": len(conditions),
        "direct_decisions": sum(int(row["direct"]) for row in folds),
        "fallback_decisions": sum(int(row["fallback"]) for row in folds),
        "safety_violations": sum(int(row["safety_violations"]) for row in folds),
        "mean_regret": sum(float(row["mean_regret"]) for row in folds) / len(folds),
        "mean_candidates": sum(float(row["mean_candidates"]) for row in folds) / len(folds),
        "zero_violation_folds": sum(int(row["safety_violations"]) == 0 for row in folds),
        "fit_float_fixed_path_mismatches": sum(
            int(row["fit_float_fixed_path_mismatches"]) for row in folds),
        "folds_not_worse_than_lut": sum(bool(row["not_worse_than_lut"]) for row in folds),
        "folds_strictly_better_than_lut": sum(bool(row["strictly_better_than_lut"])
                                                for row in folds),
        "hybrid_direct_decisions": sum(int(row["hybrid_direct"]) for row in folds),
        "hybrid_fallback_decisions": sum(int(row["hybrid_fallback"]) for row in folds),
        "hybrid_safety_violations": sum(int(row["hybrid_safety_violations"])
                                          for row in folds),
        "hybrid_mean_regret": sum(float(row["hybrid_mean_regret"])
                                    for row in folds) / len(folds),
        "hybrid_mean_candidates": sum(float(row["hybrid_mean_candidates"])
                                        for row in folds) / len(folds),
        "hybrid_folds_not_worse_than_lut": sum(
            bool(row["hybrid_not_worse_than_lut"]) for row in folds),
        "hybrid_folds_strictly_better_than_lut": sum(
            bool(row["hybrid_strictly_better_than_lut"]) for row in folds),
        "folds": folds,
        "note": "Each fold retrains, freezes, quantizes, and applies domain/leaf fallback using training rows only.",
    }
    report["promotion_allowed"] = (
        report["zero_violation_folds"] == len(profiles) and
        report["folds_not_worse_than_lut"] == len(profiles) and
        report["folds_strictly_better_than_lut"] > 0 and
        report["fit_float_fixed_path_mismatches"] == 0)
    report["hybrid_promotion_allowed"] = (
        report["hybrid_safety_violations"] == 0 and
        report["hybrid_folds_not_worse_than_lut"] == len(profiles) and
        report["hybrid_folds_strictly_better_than_lut"] > 0 and
        report["fit_float_fixed_path_mismatches"] == 0)
    return decisions, report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    args = parser.parse_args()
    decisions, report = evaluate(read_conditions(args.input))
    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(decisions[0]))
        writer.writeheader()
        writer.writerows(decisions)
    with args.out_json.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
