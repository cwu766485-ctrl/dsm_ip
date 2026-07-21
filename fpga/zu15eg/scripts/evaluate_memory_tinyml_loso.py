#!/usr/bin/env python3
"""Compare small software models on memory-DPD package selection with PA LOSO."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
from collections import Counter, defaultdict
from pathlib import Path


PACKAGE_COUNT = 6
FALLBACK = 6
FEATURE_SCHEMA = "aligned_complex_pa_monitor_v2"
FEATURES = (
    "qam", "bandwidth_mhz", "backoff", "temperature_q8_8",
    "gain_ratio", "peak_to_average", "evm_ratio", "acpr_ratio",
    "spectral_ratio", "spectral_shape", "clip_rate", "saturation_rate",
    "observation_error_ratio",
)


def read_conditions(path: Path) -> list[dict[str, object]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        raw = list(csv.DictReader(handle))
    if not raw:
        raise ValueError(f"TinyML data set is empty: {path}")
    schemas = {row.get("monitor_schema", "") for row in raw}
    if schemas != {FEATURE_SCHEMA}:
        raise ValueError(
            f"Expected monitor_schema={FEATURE_SCHEMA}, got {sorted(schemas)}")
    grouped: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in raw:
        grouped[row["condition_id"]].append(row)
    conditions = []
    for condition_id, rows in grouped.items():
        if len(rows) != PACKAGE_COUNT:
            raise ValueError(f"{condition_id} has {len(rows)} packages")
        first = rows[0]
        safe = [row for row in rows if int(row["safe"]) != 0]
        best = min(safe, key=lambda row: float(row["cost"])) if safe else None
        packages = {int(row["seed_package"]): row for row in rows}
        inp = max(float(first["input_power"]), 1.0)
        out = max(float(first["output_power"]), 1.0)
        avg = max(float(first["avg_mag"]), 1.0)
        bin0 = max(float(first["spec_bin0"]), 1.0)
        bin1 = max(float(first["spec_bin1"]), 1.0)
        samples = float(first["monitor_sample_count"])
        if samples <= 0:
            raise ValueError(f"{condition_id} has invalid monitor_sample_count={samples}")
        feature = (
            float(first["qam"]) / 64.0,
            float(first["bandwidth_mhz"]) / 40.0,
            float(first["backoff"]),
            float(first["temperature_q8_8"]) / (85.0 * 256.0),
            out / inp,
            float(first["peak"]) / avg,
            float(first["evm_proxy"]) / inp,
            float(first["acpr_proxy"]) / out,
            float(first["spec_adj"]) / bin1,
            float(first["spec_bin2"]) / bin0,
            float(first["clip"]) / samples,
            float(first["saturation"]) / samples,
            float(first["observation_error_l1"]) / inp,
        )
        conditions.append({
            "condition_id": condition_id,
            "profile_id": first["profile_id"],
            "waveform_id": first["waveform_id"],
            "monitor_schema": first["monitor_schema"],
            "monitor_sample_count": int(samples),
            "feature": feature,
            "label": int(best["seed_package"]) if best else FALLBACK,
            "oracle_cost": float(best["cost"]) if best else math.nan,
            "packages": packages,
        })
    return conditions


def normalize(train: list[dict[str, object]], test: list[dict[str, object]]) -> None:
    columns = list(zip(*(row["feature"] for row in train)))
    mean = [sum(column) / len(column) for column in columns]
    scale = [max(math.sqrt(sum((value - center) ** 2 for value in column) /
                           max(len(column) - 1, 1)), 1e-9)
             for column, center in zip(columns, mean)]
    for row in train + test:
        row["x"] = tuple((value - center) / width
                         for value, center, width in zip(row["feature"], mean, scale))


def distance(left: tuple[float, ...], right: tuple[float, ...]) -> float:
    return math.sqrt(sum((a - b) ** 2 for a, b in zip(left, right)))


def softmax(values: list[float]) -> list[float]:
    peak = max(values)
    exp_values = [math.exp(min(value - peak, 50.0)) for value in values]
    total = sum(exp_values)
    return [value / total for value in exp_values]


def solve(matrix: list[list[float]], vector: list[float]) -> list[float]:
    work = [row[:] + [value] for row, value in zip(matrix, vector)]
    for column in range(len(vector)):
        pivot = max(range(column, len(vector)), key=lambda row: abs(work[row][column]))
        work[column], work[pivot] = work[pivot], work[column]
        divisor = work[column][column]
        if abs(divisor) < 1e-12:
            divisor = 1e-12
        work[column] = [value / divisor for value in work[column]]
        for row in range(len(vector)):
            if row == column:
                continue
            factor = work[row][column]
            work[row] = [a - factor * b for a, b in zip(work[row], work[column])]
    return [row[-1] for row in work]


class LutModel:
    def fit(self, rows: list[dict[str, object]]) -> None:
        self.table = {}
        groups: dict[str, list[int]] = defaultdict(list)
        for row in rows:
            groups[str(row["waveform_id"])].append(int(row["label"]))
        for key, labels in groups.items():
            counts = Counter(labels)
            label, count = counts.most_common(1)[0]
            self.table[key] = (label, count / len(labels))

    def predict(self, row: dict[str, object]) -> tuple[int, float]:
        return self.table.get(str(row["waveform_id"]), (FALLBACK, 1.0))


class LinearModel:
    def fit(self, rows: list[dict[str, object]]) -> None:
        x = [(1.0, *row["x"]) for row in rows]
        width = len(x[0])
        gram = [[sum(sample[i] * sample[j] for sample in x)
                 for j in range(width)] for i in range(width)]
        for index in range(width):
            gram[index][index] += 0.1
        self.weights = []
        for label in range(PACKAGE_COUNT + 1):
            rhs = [sum(sample[i] * (1.0 if int(row["label"]) == label else 0.0)
                       for sample, row in zip(x, rows)) for i in range(width)]
            self.weights.append(solve(gram, rhs))

    def predict(self, row: dict[str, object]) -> tuple[int, float]:
        sample = (1.0, *row["x"])
        scores = [sum(weight * value for weight, value in zip(weights, sample))
                  for weights in self.weights]
        probability = softmax(scores)
        label = max(range(len(scores)), key=lambda index: scores[index])
        return label, probability[label]


class KnnModel:
    def fit(self, rows: list[dict[str, object]]) -> None:
        self.rows = rows

    def predict(self, row: dict[str, object]) -> tuple[int, float]:
        nearest = sorted(self.rows, key=lambda item: distance(row["x"], item["x"]))[:7]
        weights: dict[int, float] = defaultdict(float)
        for item in nearest:
            weights[int(item["label"])] += 1.0 / (distance(row["x"], item["x"]) + 1e-6)
        label = max(weights, key=weights.get)
        return label, weights[label] / sum(weights.values())


class TreeModel:
    def fit(self, rows: list[dict[str, object]]) -> None:
        self.root = self._build(rows, 0)

    def _build(self, rows: list[dict[str, object]], depth: int) -> dict[str, object]:
        counts = Counter(int(row["label"]) for row in rows)
        label, count = counts.most_common(1)[0]
        node: dict[str, object] = {"label": label, "confidence": count / len(rows)}
        if depth >= 4 or len(rows) < 16 or len(counts) == 1:
            return node
        base = 1.0 - sum((value / len(rows)) ** 2 for value in counts.values())
        best = None
        width = len(rows[0]["x"])
        for feature in range(width):
            values = sorted({row["x"][feature] for row in rows})
            if len(values) < 2:
                continue
            candidates = [values[index * (len(values)-1) // 8] for index in range(1, 8)]
            for threshold in candidates:
                left = [row for row in rows if row["x"][feature] <= threshold]
                right = [row for row in rows if row["x"][feature] > threshold]
                if len(left) < 6 or len(right) < 6:
                    continue
                impurity = sum(len(part) / len(rows) * (1.0 - sum(
                    (value / len(part)) ** 2 for value in Counter(
                        int(row["label"]) for row in part).values()))
                    for part in (left, right))
                gain = base - impurity
                if best is None or gain > best[0]:
                    best = (gain, feature, threshold, left, right)
        if best is None or best[0] < 1e-6:
            return node
        _, feature, threshold, left, right = best
        node.update({"feature": feature, "threshold": threshold,
                     "left": self._build(left, depth + 1),
                     "right": self._build(right, depth + 1)})
        return node

    def predict(self, row: dict[str, object]) -> tuple[int, float]:
        node = self.root
        while "feature" in node:
            node = node["left"] if row["x"][node["feature"]] <= node["threshold"] else node["right"]
        return int(node["label"]), float(node["confidence"])


class MlpModel:
    def fit(self, rows: list[dict[str, object]]) -> None:
        rng = random.Random(17)
        width = len(rows[0]["x"])
        hidden = 8
        self.w1 = [[rng.uniform(-0.2, 0.2) for _ in range(width + 1)] for _ in range(hidden)]
        self.w2 = [[rng.uniform(-0.2, 0.2) for _ in range(hidden + 1)]
                   for _ in range(PACKAGE_COUNT + 1)]
        rate = 0.04
        for _ in range(180):
            g1 = [[0.0] * (width + 1) for _ in range(hidden)]
            g2 = [[0.0] * (hidden + 1) for _ in range(PACKAGE_COUNT + 1)]
            for row in rows:
                x = (1.0, *row["x"])
                h = [math.tanh(sum(weight * value for weight, value in zip(weights, x)))
                     for weights in self.w1]
                logits = [sum(weight * value for weight, value in zip(weights, (1.0, *h)))
                          for weights in self.w2]
                probability = softmax(logits)
                output_error = [value - (1.0 if index == int(row["label"]) else 0.0)
                                for index, value in enumerate(probability)]
                for output in range(len(self.w2)):
                    for index, value in enumerate((1.0, *h)):
                        g2[output][index] += output_error[output] * value
                for unit in range(hidden):
                    hidden_error = sum(output_error[output] * self.w2[output][unit+1]
                                       for output in range(len(self.w2))) * (1.0 - h[unit] ** 2)
                    for index, value in enumerate(x):
                        g1[unit][index] += hidden_error * value
            scale = rate / len(rows)
            for unit in range(hidden):
                self.w1[unit] = [weight - scale * gradient
                                 for weight, gradient in zip(self.w1[unit], g1[unit])]
            for output in range(len(self.w2)):
                self.w2[output] = [weight - scale * gradient
                                   for weight, gradient in zip(self.w2[output], g2[output])]

    def predict(self, row: dict[str, object]) -> tuple[int, float]:
        x = (1.0, *row["x"])
        h = [math.tanh(sum(weight * value for weight, value in zip(weights, x)))
             for weights in self.w1]
        probability = softmax([sum(weight * value for weight, value in zip(weights, (1.0, *h)))
                               for weights in self.w2])
        label = max(range(len(probability)), key=probability.__getitem__)
        return label, probability[label]


MODELS = {"lut": LutModel, "linear": LinearModel, "tree": TreeModel,
          "knn": KnnModel, "mlp": MlpModel}


def safety_gate(train: list[dict[str, object]], row: dict[str, object], package: int,
                confidence: float) -> tuple[bool, float, float]:
    if package == FALLBACK or confidence < 0.50:
        return False, math.inf, 0.0
    nearest = sorted(train, key=lambda item: distance(row["x"], item["x"]))[:9]
    nearest_distance = distance(row["x"], nearest[0]["x"])
    safe_rate = sum(int(item["packages"][package]["safe"]) != 0
                    for item in nearest) / len(nearest)
    # A package is released only when every nearby retained observation was safe.
    return safe_rate == 1.0 and nearest_distance <= 4.0, nearest_distance, safe_rate


def evaluate(conditions: list[dict[str, object]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    profiles = sorted({str(row["profile_id"]) for row in conditions})
    decisions = []
    fold_summary = []
    for held_profile in profiles:
        train = [dict(row) for row in conditions if row["profile_id"] != held_profile]
        held = [dict(row) for row in conditions if row["profile_id"] == held_profile]
        normalize(train, held)
        for model_name, model_type in MODELS.items():
            model = model_type()
            model.fit(train)
            fold = {"profile": held_profile, "model": model_name, "direct": 0,
                    "violations": 0, "regret": 0.0, "candidates": 0}
            for row in held:
                raw_package, confidence = model.predict(row)
                release, nearest_distance, safe_rate = safety_gate(
                    train, row, raw_package, confidence)
                action = raw_package if release else FALLBACK
                violation = False
                regret = 0.0
                if action != FALLBACK:
                    package_row = row["packages"][action]
                    violation = int(package_row["safe"]) == 0
                    if not math.isnan(float(row["oracle_cost"])):
                        regret = float(package_row["cost"]) - float(row["oracle_cost"])
                    fold["direct"] += 1
                    fold["candidates"] += 1
                else:
                    fold["candidates"] += 14
                fold["violations"] += int(violation)
                fold["regret"] += regret
                decisions.append({
                    "held_profile": held_profile, "model": model_name,
                    "condition_id": row["condition_id"], "oracle_package": row["label"],
                    "raw_package": raw_package, "action": action,
                    "confidence": confidence, "nearest_distance": nearest_distance,
                    "neighbor_safe_rate": safe_rate, "safety_violation": int(violation),
                    "regret": regret, "candidate_count": 1 if action != FALLBACK else 14,
                })
            fold["mean_regret"] = fold.pop("regret") / len(held)
            fold["mean_candidates"] = fold.pop("candidates") / len(held)
            fold_summary.append(fold)
    summaries = []
    lut_folds = {row["profile"]: row for row in fold_summary if row["model"] == "lut"}
    for model_name in MODELS:
        rows = [row for row in fold_summary if row["model"] == model_name]
        stable_fold_wins = 0
        stable_fold_nonlosses = 0
        if model_name != "lut":
            for row in rows:
                lut_fold = lut_folds[row["profile"]]
                nonloss = (row["violations"] == 0 and
                           row["mean_regret"] <= lut_fold["mean_regret"] + 1e-9 and
                           row["mean_candidates"] <= lut_fold["mean_candidates"] + 1e-9)
                strict = nonloss and (row["mean_regret"] < lut_fold["mean_regret"] - 1e-9 or
                                      row["mean_candidates"] < lut_fold["mean_candidates"] - 1e-9)
                stable_fold_nonlosses += int(nonloss)
                stable_fold_wins += int(strict)
        summaries.append({
            "model": model_name,
            "direct_decisions": sum(int(row["direct"]) for row in rows),
            "fallback_decisions": len(profiles) * 24 - sum(int(row["direct"]) for row in rows),
            "safety_violations": sum(int(row["violations"]) for row in rows),
            "mean_regret": sum(float(row["mean_regret"]) for row in rows) / len(rows),
            "mean_candidates": sum(float(row["mean_candidates"]) for row in rows) / len(rows),
            "folds_zero_violation": sum(int(row["violations"]) == 0 for row in rows),
            "folds_not_worse_than_lut": stable_fold_nonlosses,
            "folds_strictly_better_than_lut": stable_fold_wins,
        })
    lut = next(row for row in summaries if row["model"] == "lut")
    for row in summaries:
        row["beats_lut"] = (row["model"] != "lut" and row["safety_violations"] == 0 and
                            row["folds_zero_violation"] == len(profiles) and
                            row["folds_not_worse_than_lut"] == len(profiles) and
                            row["folds_strictly_better_than_lut"] > 0)
    qualified = [row for row in summaries if row["beats_lut"]]
    hardware_preference = {"tree": 0, "linear": 1, "mlp": 2, "knn": 3}
    qualified.sort(key=lambda row: (row["mean_candidates"], row["mean_regret"],
                                    hardware_preference.get(str(row["model"]), 9)))
    winner = qualified[0]["model"] if qualified else None
    report = {"profiles": len(profiles), "conditions": len(conditions),
              "features": FEATURES, "summary": summaries,
              "rtl_evaluation_qualified": bool(winner),
              "qualified_models": [row["model"] for row in qualified],
              "preferred_rtl_candidate": winner, "fold_summary": fold_summary,
              "rule": "in every PA LOSO fold: zero violations, no candidate increase, no regret increase; strict improvement in at least one fold"}
    return decisions, report


def write_outputs(out_dir: Path, decisions: list[dict[str, object]], report: dict[str, object]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / "memory_tinyml_loso_decisions.csv").open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(decisions[0]))
        writer.writeheader(); writer.writerows(decisions)
    with (out_dir / "memory_tinyml_loso.json").open("w", encoding="ascii") as handle:
        json.dump(report, handle, indent=2); handle.write("\n")
    with (out_dir / "memory_tinyml_loso.md").open("w", encoding="ascii") as handle:
        handle.write("# Memory-DPD Software TinyML LOSO\n\n")
        handle.write("| Model | Direct | Fallback | Safety violations | Mean regret | Mean candidates | Zero-violation folds | Non-worse folds | Strictly better folds | Beats LUT |\n")
        handle.write("|---|---:|---:|---:|---:|---:|---:|---:|---:|---|\n")
        for row in report["summary"]:
            handle.write(f"| {row['model']} | {row['direct_decisions']} | {row['fallback_decisions']} | {row['safety_violations']} | {row['mean_regret']:.3f} | {row['mean_candidates']:.3f} | {row['folds_zero_violation']}/12 | {row['folds_not_worse_than_lut']}/12 | {row['folds_strictly_better_than_lut']}/12 | {row['beats_lut']} |\n")
        handle.write(f"\nRTL evaluation qualified: **{report['rtl_evaluation_qualified']}**. Preferred candidate: `{report['preferred_rtl_candidate']}`.\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    decisions, report = evaluate(read_conditions(args.input))
    write_outputs(args.out_dir, decisions, report)
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
