#!/usr/bin/env python3
"""Evaluate a dependency-free tiny MLP DPD seed selector under strict LOSO.

The model observes one fixed package-3 probe, predicts the post-bounded-search
cost of all six seed packages, and selects only the seed. The mandatory
14-candidate local search remains outside the model and is never bypassed.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path

import numpy as np


PACKAGES = 6
PROBE_PACKAGE = 3


def read_conditions(path: Path) -> list[dict[str, object]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    grouped: dict[tuple[str, str, int], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[(row["profile_id"], row["waveform_id"],
                 int(float(row["simulation_seed"])))].append(row)
    conditions = []
    for key, values in sorted(grouped.items()):
        by_package = {int(float(row["seed_package"])): row for row in values}
        if set(by_package) != set(range(PACKAGES)):
            raise ValueError(f"Incomplete package set for {key}")
        probe = by_package[PROBE_PACKAGE]
        final_costs = np.array([float(by_package[p]["final_cost"])
                                for p in range(PACKAGES)], dtype=np.float64)
        conditions.append({
            "profile": key[0], "waveform": key[1], "seed": key[2],
            "features": make_features(probe), "final_costs": final_costs,
            "final_evm": np.array([float(by_package[p]["final_evm_pct"])
                                    for p in range(PACKAGES)]),
            "final_aclr": np.array([float(by_package[p]["final_aclr_db"])
                                     for p in range(PACKAGES)]),
            "clip": np.array([int(float(by_package[p]["clip"]))
                               for p in range(PACKAGES)]),
            "saturation": np.array([int(float(by_package[p]["saturation"]))
                                     for p in range(PACKAGES)]),
        })
    if len(conditions) != 288:
        raise ValueError(f"Expected 288 conditions, got {len(conditions)}")
    return conditions


def ratio(num: str, den: str) -> float:
    return float(num) / max(abs(float(den)), 1.0)


def make_features(row: dict[str, str]) -> np.ndarray:
    return np.array([
        float(row["qam"]) / 64.0,
        float(row["bandwidth_mhz"]) / 40.0,
        float(row["input_backoff"]),
        ratio(row["output_power"], row["input_power"]),
        ratio(row["peak"], row["avg_mag"]),
        ratio(row["evm_proxy"], row["input_power"]),
        ratio(row["acpr_proxy"], row["output_power"]),
        ratio(row["spec_adj"], row["spec_bin1"]),
        ratio(row["spec_bin2"], row["spec_bin0"]),
        float(row["clip"]),
        float(row["saturation"]),
    ], dtype=np.float64)


class TinyMlp:
    def __init__(self, n_in: int, n_hidden: int, seed: int) -> None:
        rng = np.random.default_rng(seed)
        self.w1 = rng.normal(0.0, np.sqrt(2.0 / n_in), (n_in, n_hidden))
        self.b1 = np.zeros(n_hidden)
        self.w2 = rng.normal(0.0, np.sqrt(2.0 / n_hidden), (n_hidden, PACKAGES))
        self.b2 = np.zeros(PACKAGES)

    def fit(self, x: np.ndarray, y: np.ndarray, epochs: int,
            learning_rate: float, l2: float) -> None:
        params = (self.w1, self.b1, self.w2, self.b2)
        moment1 = [np.zeros_like(value) for value in params]
        moment2 = [np.zeros_like(value) for value in params]
        for step in range(1, epochs + 1):
            hidden = np.tanh(x @ self.w1 + self.b1)
            pred = hidden @ self.w2 + self.b2
            grad_pred = 2.0 * (pred - y) / y.size
            grads = (
                x.T @ ((grad_pred @ self.w2.T) * (1.0 - hidden * hidden)) +
                l2 * self.w1,
                np.sum((grad_pred @ self.w2.T) * (1.0 - hidden * hidden), axis=0),
                hidden.T @ grad_pred + l2 * self.w2,
                np.sum(grad_pred, axis=0),
            )
            for index, (param, grad) in enumerate(zip(params, grads)):
                moment1[index] = 0.9 * moment1[index] + 0.1 * grad
                moment2[index] = 0.999 * moment2[index] + 0.001 * grad * grad
                m_hat = moment1[index] / (1.0 - 0.9 ** step)
                v_hat = moment2[index] / (1.0 - 0.999 ** step)
                param -= learning_rate * m_hat / (np.sqrt(v_hat) + 1e-8)

    def predict(self, x: np.ndarray) -> np.ndarray:
        return np.tanh(x @ self.w1 + self.b1) @ self.w2 + self.b2


def split_value(item: dict[str, object], split: str) -> object:
    return item[{"profile": "profile", "waveform": "waveform", "seed": "seed"}[split]]


def evaluate_split(conditions: list[dict[str, object]], split: str,
                   hidden: int, epochs: int) -> dict[str, object]:
    decisions = []
    held_values = sorted({split_value(item, split) for item in conditions}, key=str)
    for fold_index, held in enumerate(held_values):
        train = [item for item in conditions if split_value(item, split) != held]
        test = [item for item in conditions if split_value(item, split) == held]
        x_train = np.stack([item["features"] for item in train])
        center = np.mean(x_train, axis=0)
        scale = np.std(x_train, axis=0)
        scale[scale < 1e-9] = 1.0
        x_train = (x_train - center) / scale
        costs = np.stack([item["final_costs"] for item in train])
        regrets = np.maximum(costs - np.min(costs, axis=1, keepdims=True), 0.0)
        target_scale = max(float(np.percentile(regrets, 75)), 1.0)
        y_train = np.log1p(regrets / target_scale)
        model = TinyMlp(x_train.shape[1], hidden, seed=20260721 + fold_index)
        model.fit(x_train, y_train, epochs=epochs, learning_rate=0.015, l2=1e-4)
        x_test = (np.stack([item["features"] for item in test]) - center) / scale
        predicted = model.predict(x_test)
        for item, prediction in zip(test, predicted):
            package = int(np.argmin(prediction))
            costs_i = item["final_costs"]
            best = int(np.argmin(costs_i))
            decisions.append({
                "held": held, "profile": item["profile"],
                "waveform": item["waveform"], "seed": item["seed"],
                "selected_package": package, "best_package": best,
                "selected_cost": float(costs_i[package]),
                "best_cost": float(costs_i[best]),
                "fixed_package_3_cost": float(costs_i[PROBE_PACKAGE]),
                "regret": float(costs_i[package] - costs_i[best]),
                "delta_vs_fixed_package_3": float(costs_i[package] - costs_i[PROBE_PACKAGE]),
                "evm_pct": float(item["final_evm"][package]),
                "aclr_dbc": float(item["final_aclr"][package]),
                "clip": int(item["clip"][package]),
                "saturation": int(item["saturation"][package]),
                "fixed_evm_pct": float(item["final_evm"][PROBE_PACKAGE]),
                "fixed_aclr_dbc": float(item["final_aclr"][PROBE_PACKAGE]),
                "fixed_clip": int(item["clip"][PROBE_PACKAGE]),
                "fixed_saturation": int(item["saturation"][PROBE_PACKAGE]),
            })
    for row in decisions:
        selected_failure = (row["evm_pct"] > 8.0 or row["aclr_dbc"] > -20.0 or
                            row["clip"] != 0 or row["saturation"] != 0)
        fixed_failure = (row["fixed_evm_pct"] > 8.0 or
                         row["fixed_aclr_dbc"] > -20.0 or
                         row["fixed_clip"] != 0 or row["fixed_saturation"] != 0)
        row["constraint_failure"] = bool(selected_failure)
        row["fixed_constraint_failure"] = bool(fixed_failure)
        row["new_constraint_failure"] = bool(selected_failure and not fixed_failure)
    constraint_failures = sum(row["constraint_failure"] for row in decisions)
    fixed_constraint_failures = sum(row["fixed_constraint_failure"] for row in decisions)
    new_constraint_failures = sum(row["new_constraint_failure"] for row in decisions)
    mean_delta = float(np.mean([row["delta_vs_fixed_package_3"] for row in decisions]))
    return {
        "split": split, "conditions": len(decisions),
        "package_accuracy": float(np.mean([row["selected_package"] == row["best_package"]
                                            for row in decisions])),
        "mean_regret": float(np.mean([row["regret"] for row in decisions])),
        "max_regret": float(np.max([row["regret"] for row in decisions])),
        "mean_delta_vs_fixed_package_3": mean_delta,
        "wins_vs_fixed_package_3": sum(row["delta_vs_fixed_package_3"] < 0 for row in decisions),
        "ties_vs_fixed_package_3": sum(row["delta_vs_fixed_package_3"] == 0 for row in decisions),
        "constraint_failures": int(constraint_failures),
        "fixed_package_3_constraint_failures": int(fixed_constraint_failures),
        "new_constraint_failures": int(new_constraint_failures),
        "mandatory_search_candidates": 14,
        "offline_candidate_qualified": bool(mean_delta < 0 and new_constraint_failures == 0),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    parser.add_argument("--out-md", type=Path, required=True)
    parser.add_argument("--hidden", type=int, default=16)
    parser.add_argument("--epochs", type=int, default=500)
    args = parser.parse_args()
    conditions = read_conditions(args.input)
    splits = {split: evaluate_split(conditions, split, args.hidden, args.epochs)
              for split in ("profile", "waveform", "seed")}
    result = {
        "model": "tiny_mlp_seed_cost_regressor_v1", "simulation_only": True,
        "input_features": 11, "hidden_units": args.hidden,
        "output_costs": PACKAGES, "epochs": args.epochs,
        "direct_execution_allowed": False,
        "mandatory_search_candidates": 14,
        "splits": splits,
        "all_splits_qualified": all(item["offline_candidate_qualified"]
                                      for item in splits.values()),
        "deployment_allowed": False,
    }
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    with args.out_json.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(result, handle, indent=2, sort_keys=True)
        handle.write("\n")
    with args.out_md.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# Tiny MLP Seed Selector Strict LOSO\n\n")
        handle.write("Simulation-only model. Every selected seed still runs the mandatory 14-candidate bounded search.\n\n")
        handle.write("| Split | Accuracy | Mean regret | Max regret | Mean delta vs fixed package 3 | Wins | Failures selected/fixed/new | Promoted |\n")
        handle.write("|---|---:|---:|---:|---:|---:|---:|---|\n")
        for split, row in splits.items():
            handle.write(f"| {split} | {row['package_accuracy']:.4f} | {row['mean_regret']:.3f} | "
                         f"{row['max_regret']:.3f} | {row['mean_delta_vs_fixed_package_3']:.3f} | "
                         f"{row['wins_vs_fixed_package_3']}/288 | {row['constraint_failures']}/"
                         f"{row['fixed_package_3_constraint_failures']}/{row['new_constraint_failures']} | "
                         f"{row['offline_candidate_qualified']} |\n")
        handle.write("\nDeployment remains disabled regardless of this behavioral result.\n")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
