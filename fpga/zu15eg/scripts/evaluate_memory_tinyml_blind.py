#!/usr/bin/env python3
"""Evaluate frozen observer-v2 TinyML policy on an isolated blind PA matrix."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_memory_tinyml_loso import FALLBACK, LutModel, read_conditions
from export_memory_tinyml_tree import infer, quantize


def load_model(path: Path) -> dict[str, object]:
    with path.open(encoding="ascii") as handle:
        payload = json.load(handle)
    model = payload["model"]
    if model["feature_schema"] != "aligned_complex_pa_monitor_v2":
        raise ValueError("Frozen model does not use aligned_complex_pa_monitor_v2")
    return model


def choose_lut(lut: LutModel, row: dict[str, object]) -> int:
    package, _ = lut.predict(row)
    return package if package != FALLBACK else FALLBACK


def evaluate(train: list[dict[str, object]], blind: list[dict[str, object]],
             model: dict[str, object]) -> tuple[list[dict[str, object]], dict[str, object]]:
    lut = LutModel()
    lut.fit(train)
    decisions: list[dict[str, object]] = []
    totals: dict[str, dict[str, float]] = defaultdict(lambda: {
        "conditions": 0.0, "safety_violations": 0.0, "seed_regret": 0.0,
        "fallback_seed": 0.0, "tree_seed": 0.0, "lut_seed": 0.0,
    })
    for row in blind:
        features = tuple(quantize(float(value)) for value in row["feature"])
        tree = infer(model, features)
        lut_package = choose_lut(lut, row)
        source = "tree" if tree["direct"] else "lut"
        package = int(tree["package"]) if tree["direct"] else lut_package
        if package == FALLBACK:
            source = "fallback_default"
        package_row = row["packages"].get(package)
        # A missing tree/LUT package is a fail-closed policy rejection, not a safe seed.
        violation = int(package == FALLBACK or package_row is None or
                        int(package_row["safe"]) == 0)
        regret = (float(package_row["cost"]) - float(row["oracle_cost"])
                  if package_row is not None and not math.isnan(float(row["oracle_cost"]))
                  else 0.0)
        profile = str(row["profile_id"])
        total = totals[profile]
        total["conditions"] += 1.0
        total["safety_violations"] += violation
        total["seed_regret"] += regret
        total["fallback_seed"] += int(source == "fallback_default")
        total["tree_seed"] += int(source == "tree")
        total["lut_seed"] += int(source == "lut")
        decisions.append({
            "condition_id": row["condition_id"], "profile_id": profile,
            "oracle_package": row["label"], "tree_package": tree["package"],
            "tree_direct": tree["direct"], "tree_ood": tree["ood"],
            "lut_package": lut_package, "selected_seed": package,
            "seed_source": source, "seed_safe": 1 - violation,
            "seed_regret": f"{regret:.6f}",
            "mandatory_search_candidates": 14,
            "deployment_action": "fallback_14",
        })
    report_profiles = []
    for profile, value in sorted(totals.items()):
        count = max(value["conditions"], 1.0)
        report_profiles.append({
            "profile": profile, "conditions": int(count),
            "tree_seeds": int(value["tree_seed"]), "lut_seeds": int(value["lut_seed"]),
            "fallback_default_seeds": int(value["fallback_seed"]),
            "safety_violations": int(value["safety_violations"]),
            "mean_seed_regret": value["seed_regret"] / count,
            "mandatory_search_candidates": 14,
        })
    report = {
        "feature_schema": "aligned_complex_pa_monitor_v2",
        "model_version": int(model["model_version"]),
        "training_conditions": len(train), "blind_conditions": len(blind),
        "blind_profiles": len(report_profiles), "profiles": report_profiles,
        "tree_seed_count": sum(int(row["seed_source"] == "tree") for row in decisions),
        "lut_seed_count": sum(int(row["seed_source"] == "lut") for row in decisions),
        "fallback_default_count": sum(int(row["seed_source"] == "fallback_default") for row in decisions),
        "seed_safety_violations": sum(int(row["seed_safe"]) == 0 for row in decisions),
        "mean_seed_regret": sum(float(row["seed_regret"]) for row in decisions) / len(decisions),
        "mandatory_search_candidates": 14,
        "tinyml_axi_integration_enabled": False,
        "promotion_allowed": False,
        "note": "Blind PA profiles are excluded from fitting and policy selection. This evaluates package-stage seed safety/regret only; every deployment action remains a 14-candidate local search.",
    }
    report["promotion_allowed"] = report["seed_safety_violations"] == 0
    return decisions, report


def write_markdown(path: Path, report: dict[str, object]) -> None:
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# Observer-v2 Blind PA Evaluation\n\n")
        handle.write("The frozen model and waveform LUT were fitted only on the 12-profile training matrix. "
                     "Every evaluated action remains a mandatory 14-candidate local search.\n\n")
        handle.write("| Blind profile | Conditions | Tree seeds | LUT seeds | Default fallback | Seed safety violations | Mean seed regret | Local candidates |\n")
        handle.write("|---|---:|---:|---:|---:|---:|---:|---:|\n")
        for row in report["profiles"]:
            handle.write(f"| {row['profile']} | {row['conditions']} | {row['tree_seeds']} | {row['lut_seeds']} | {row['fallback_default_seeds']} | {row['safety_violations']} | {row['mean_seed_regret']:.3f} | 14 |\n")
        handle.write("\n")
        handle.write(f"Overall seed safety violations: `{report['seed_safety_violations']}`. "
                     f"Tree/LUT/default seed counts: `{report['tree_seed_count']}`/"
                     f"`{report['lut_seed_count']}`/`{report['fallback_default_count']}`.\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--train", type=Path, required=True)
    parser.add_argument("--blind", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    parser.add_argument("--out-md", type=Path, required=True)
    parser.add_argument("--allow-safety-fail", action="store_true",
                        help="Write a non-promoted report without returning an error.")
    args = parser.parse_args()
    train = read_conditions(args.train)
    blind = read_conditions(args.blind)
    model = load_model(args.model)
    training_profiles = {str(row["profile_id"]) for row in train}
    blind_profiles = {str(row["profile_id"]) for row in blind}
    if training_profiles & blind_profiles:
        raise ValueError("Blind profiles overlap training profiles")
    decisions, report = evaluate(train, blind, model)
    for path in (args.out_csv, args.out_json, args.out_md):
        path.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(decisions[0]))
        writer.writeheader(); writer.writerows(decisions)
    with args.out_json.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2); handle.write("\n")
    write_markdown(args.out_md, report)
    print(json.dumps(report, indent=2))
    return 0 if args.allow_safety_fail or report["seed_safety_violations"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
