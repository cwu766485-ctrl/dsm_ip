#!/usr/bin/env python3
"""Freeze and quantize the memory-DPD decision tree for C/RTL replay."""

from __future__ import annotations

import argparse
import json
import math
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_memory_tinyml_loso import (  # noqa: E402
    FALLBACK,
    FEATURES,
    TreeModel,
    normalize,
    read_conditions,
)


FRAC_BITS = 20
SCALE = 1 << FRAC_BITS
MODEL_VERSION = 0x00020000
FEATURE_SCHEMA = "aligned_complex_pa_monitor_v2"


def quantize(value: float) -> int:
    scaled = value * SCALE
    return math.floor(scaled + 0.5) if scaled >= 0.0 else math.ceil(scaled - 0.5)


def training_stats(conditions: list[dict[str, object]]) -> tuple[list[float], list[float]]:
    columns = list(zip(*(row["feature"] for row in conditions)))
    mean = [sum(column) / len(column) for column in columns]
    scale = [max(math.sqrt(sum((value - center) ** 2 for value in column) /
                           max(len(column) - 1, 1)), 1e-9)
             for column, center in zip(columns, mean)]
    return mean, scale


def leaf_rows(root: dict[str, object], rows: list[dict[str, object]]) -> dict[str, list[dict[str, object]]]:
    leaves: dict[str, list[dict[str, object]]] = {}
    for row in rows:
        node = root
        path = ""
        while "feature" in node:
            feature = int(node["feature"])
            take_left = row["x"][feature] <= float(node["threshold"])
            path += "0" if take_left else "1"
            node = node["left"] if take_left else node["right"]
        leaves.setdefault(path, []).append(row)
    return leaves


def freeze_node(node: dict[str, object], mean: list[float], scale: list[float],
                rows: list[dict[str, object]], path: str = "") -> dict[str, object]:
    if "feature" not in node:
        predicted = int(node["label"])
        all_safe = predicted != FALLBACK and all(
            int(row["packages"][predicted]["safe"]) != 0 for row in rows)
        all_oracle = predicted != FALLBACK and all(int(row["label"]) == predicted for row in rows)
        action = predicted if all_safe and all_oracle else FALLBACK
        result = {
            "leaf_id": int(path or "0", 2),
            "path": path,
            "samples": len(rows),
            "raw_label": predicted,
            "action": action,
            "released": action != FALLBACK,
            "all_safe": all_safe,
            "all_oracle": all_oracle,
        }
        if action != FALLBACK:
            result["envelope_q20"] = [
                [min(quantize(float(row["feature"][index])) for row in rows),
                 max(quantize(float(row["feature"][index])) for row in rows)]
                for index in range(len(FEATURES))
            ]
        return result
    feature = int(node["feature"])
    threshold_raw = mean[feature] + scale[feature] * float(node["threshold"])
    left_rows = [row for row in rows
                 if float(row["x"][feature]) <= float(node["threshold"])]
    right_rows = [row for row in rows
                  if float(row["x"][feature]) > float(node["threshold"])]
    left_max_q20 = max(quantize(float(row["feature"][feature])) for row in left_rows)
    right_min_q20 = min(quantize(float(row["feature"][feature])) for row in right_rows)
    if left_max_q20 >= right_min_q20:
        raise RuntimeError(
            f"Q20 cannot preserve node {path or 'root'} feature {feature}: "
            f"left_max={left_max_q20} right_min={right_min_q20}")
    return {
        "feature": feature,
        "feature_name": FEATURES[feature],
        "threshold_q20": left_max_q20,
        "threshold_raw": threshold_raw,
        "left": freeze_node(node["left"], mean, scale, left_rows, path + "0"),
        "right": freeze_node(node["right"], mean, scale, right_rows, path + "1"),
    }


def infer(model: dict[str, object], features: tuple[int, ...], valid: bool = True) -> dict[str, int]:
    bounds = model["feature_bounds_q20"]
    ood = int(not valid or any(value < bound[0] or value > bound[1]
                               for value, bound in zip(features, bounds)))
    if ood:
        return {"package": FALLBACK, "direct": 0, "path": 0, "path_len": 0, "ood": 1}
    node = model["tree"]
    path = 0
    path_len = 0
    while "feature" in node:
        take_right = features[int(node["feature"])] > int(node["threshold_q20"])
        path = (path << 1) | int(take_right)
        path_len += 1
        node = node["right"] if take_right else node["left"]
    action = int(node["action"])
    if action != FALLBACK and any(
            value < bound[0] or value > bound[1]
            for value, bound in zip(features, node["envelope_q20"])):
        return {"package": FALLBACK, "direct": 0, "path": path,
                "path_len": path_len, "ood": 1}
    return {"package": action, "direct": int(action != FALLBACK),
            "path": path, "path_len": path_len, "ood": 0}


def float_path(root: dict[str, object], row: dict[str, object]) -> str:
    node = root
    path = ""
    while "feature" in node:
        feature = int(node["feature"])
        take_right = row["x"][feature] > float(node["threshold"])
        path += "1" if take_right else "0"
        node = node["right"] if take_right else node["left"]
    return path


def make_model(conditions: list[dict[str, object]]) -> tuple[dict[str, object], dict[str, object]]:
    # Train only on distinctions available to the fixed-point implementation.
    for row in conditions:
        row["feature"] = tuple(quantize(float(value)) / SCALE
                               for value in row["feature"])
    mean, width = training_stats(conditions)
    normalize(conditions, [])
    tree = TreeModel()
    tree.fit(conditions)
    frozen = freeze_node(tree.root, mean, width, conditions)
    bounds = [[min(quantize(float(row["feature"][index])) for row in conditions),
               max(quantize(float(row["feature"][index])) for row in conditions)]
              for index in range(len(FEATURES))]
    model = {
        "model_version": MODEL_VERSION,
        "feature_schema": FEATURE_SCHEMA,
        "feature_source": "bit-true aligned dpd_observer complex PA observation",
        "format": "signed Q12.20 raw features",
        "fractional_bits": FRAC_BITS,
        "fallback_package": FALLBACK,
        "fallback_candidate_count": 14,
        "features": list(FEATURES),
        "feature_bounds_q20": bounds,
        "tree": frozen,
    }

    direct = 0
    violations = 0
    regret = 0.0
    path_mismatch = 0
    for row in conditions:
        features = tuple(quantize(float(value)) for value in row["feature"])
        result = infer(model, features)
        path_mismatch += int(format(result["path"], f"0{result['path_len']}b") !=
                             float_path(tree.root, row))
        if result["direct"]:
            direct += 1
            package = row["packages"][result["package"]]
            violations += int(package["safe"]) == 0
            regret += float(package["cost"]) - float(row["oracle_cost"])
    report = {
        "conditions": len(conditions),
        "direct_decisions": direct,
        "fallback_decisions": len(conditions) - direct,
        "training_safety_violations": violations,
        "training_mean_regret": regret / len(conditions),
        "float_fixed_path_mismatches": path_mismatch,
        "label_histogram": dict(sorted(Counter(int(row["label"]) for row in conditions).items())),
        "qualification": ("standalone inference artifact; only the hierarchical "
                          "tree-then-LUT policy is LOSO-promoted; board replay required"),
    }
    return model, report


def collect_thresholds(node: dict[str, object], output: list[tuple[int, int]]) -> None:
    if "feature" not in node:
        return
    output.append((int(node["feature"]), int(node["threshold_q20"])))
    collect_thresholds(node["left"], output)
    collect_thresholds(node["right"], output)


def collect_released_leaves(node: dict[str, object], output: list[dict[str, object]]) -> None:
    if "feature" not in node:
        if int(node["action"]) != FALLBACK:
            output.append(node)
        return
    collect_released_leaves(node["left"], output)
    collect_released_leaves(node["right"], output)


def write_vectors(path: Path, model: dict[str, object], conditions: list[dict[str, object]]) -> int:
    vectors: list[tuple[str, bool, tuple[int, ...]]] = []
    for row in conditions:
        vectors.append((str(row["condition_id"]), True,
                        tuple(quantize(float(value)) for value in row["feature"])))
    midpoint = tuple((bound[0] + bound[1]) // 2 for bound in model["feature_bounds_q20"])
    thresholds: list[tuple[int, int]] = []
    collect_thresholds(model["tree"], thresholds)
    for index, (feature, threshold) in enumerate(thresholds):
        for delta in (0, 1):
            values = list(midpoint)
            values[feature] = threshold + delta
            vectors.append((f"threshold_{index}_{delta}", True, tuple(values)))
    for feature, bound in enumerate(model["feature_bounds_q20"]):
        for side, value in (("lo", bound[0] - 1), ("hi", bound[1] + 1)):
            values = list(midpoint)
            values[feature] = value
            vectors.append((f"ood_{feature}_{side}", True, tuple(values)))
    released: list[dict[str, object]] = []
    collect_released_leaves(model["tree"], released)
    condition_vectors = vectors[:len(conditions)]
    for leaf in released:
        representative = next(values for _, _, values in condition_vectors
                              if infer(model, values)["direct"] and
                              infer(model, values)["path"] == int(leaf["leaf_id"]))
        envelope_vector = None
        envelope_name = ""
        for feature, (envelope, global_bound) in enumerate(zip(
                leaf["envelope_q20"], model["feature_bounds_q20"])):
            candidates = []
            if envelope[0] > global_bound[0]:
                candidates.append(("lo", envelope[0] - 1))
            if envelope[1] < global_bound[1]:
                candidates.append(("hi", envelope[1] + 1))
            if candidates:
                for side, value in candidates:
                    values = list(representative)
                    values[feature] = value
                    result = infer(model, tuple(values))
                    if (result["path"] == int(leaf["leaf_id"]) and
                            not result["direct"] and result["ood"]):
                        envelope_vector = tuple(values)
                        envelope_name = f"envelope_{leaf['leaf_id']}_{feature}_{side}"
                        break
            if envelope_vector is not None:
                break
        if envelope_vector is None:
            raise RuntimeError(f"No path-preserving envelope test for leaf {leaf['leaf_id']}")
        vectors.append((envelope_name, True, envelope_vector))
    vectors.append(("invalid", False, midpoint))

    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# name valid f0..f12 package direct path path_len ood\n")
        for name, valid, features in vectors:
            result = infer(model, features, valid)
            words = [name, str(int(valid)), *(str(value) for value in features),
                     str(result["package"]), str(result["direct"]), str(result["path"]),
                     str(result["path_len"]), str(result["ood"])]
            handle.write(" ".join(words) + "\n")
    return len(vectors)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--model-out", type=Path, required=True)
    parser.add_argument("--vectors-out", type=Path, required=True)
    args = parser.parse_args()
    conditions = read_conditions(args.input)
    model, report = make_model(conditions)
    report["equivalence_vectors"] = write_vectors(args.vectors_out, model, conditions)
    payload = {"model": model, "report": report}
    args.model_out.parent.mkdir(parents=True, exist_ok=True)
    with args.model_out.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    print(json.dumps(report, indent=2))
    if report["float_fixed_path_mismatches"] or report["training_safety_violations"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
