#!/usr/bin/env python3
"""Replay retained board monitor rows against the fixed-point TinyML tree."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from export_memory_tinyml_tree import FALLBACK, infer, quantize  # noqa: E402


FEATURE_COUNT = 13
REQUIRED_COLUMNS = {
    "scenario_id", "qam", "bandwidth_mhz", "input_backoff",
    "mon_input_power", "mon_output_power", "mon_peak", "mon_avg_mag",
    "mon_evm_proxy", "mon_acpr_proxy", "mon_spec_bin0", "mon_spec_bin1",
    "mon_spec_bin2", "mon_spec_adj", "mon_clip", "mon_saturation",
    "policy_cost", "local_search_final_cost", "full_search_final_cost",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    if not rows:
        raise ValueError(f"Board data set is empty: {path}")
    missing = REQUIRED_COLUMNS - set(rows[0])
    if missing:
        raise ValueError(f"Board data set lacks columns: {sorted(missing)}")
    return rows


def parse_int(value: str) -> int:
    return int(value, 0)


def upper_u16(word: int) -> int:
    return (word >> 16) & 0xffff


def ratio(numerator: int, denominator: int) -> float:
    return numerator / max(denominator, 1)


def optional_float(row: dict[str, str], name: str) -> float | None:
    value = row.get(name, "").strip()
    return float(value) if value else None


def board_features(row: dict[str, str]) -> tuple[tuple[int, ...], list[str]]:
    input_power = max(parse_int(row["mon_input_power"]), 1)
    output_power = max(parse_int(row["mon_output_power"]), 1)
    peak = upper_u16(parse_int(row["mon_peak"]))
    average = upper_u16(parse_int(row["mon_avg_mag"]))
    sample_count = optional_float(row, "monitor_sample_count")
    temperature_q8_8 = optional_float(row, "temperature_q8_8")
    observation_error = optional_float(row, "observation_error_l1")
    missing = []
    if temperature_q8_8 is None:
        missing.append("temperature_q8_8")
    if observation_error is None:
        missing.append("observation_error_l1")
    if sample_count is None or sample_count <= 0:
        # Zero safety counters have an exact zero rate without knowing the window.
        if parse_int(row["mon_clip"]) != 0 or parse_int(row["mon_saturation"]) != 0:
            missing.append("monitor_sample_count")
        sample_count = 1.0

    raw = (
        float(row["qam"]) / 64.0,
        float(row["bandwidth_mhz"]) / 40.0,
        float(row["input_backoff"]),
        0.0 if temperature_q8_8 is None else temperature_q8_8 / (85.0 * 256.0),
        ratio(output_power, input_power),
        ratio(peak, average),
        ratio(parse_int(row["mon_evm_proxy"]), input_power),
        ratio(parse_int(row["mon_acpr_proxy"]), output_power),
        ratio(parse_int(row["mon_spec_adj"]), parse_int(row["mon_spec_bin1"])),
        ratio(parse_int(row["mon_spec_bin2"]), parse_int(row["mon_spec_bin0"])),
        parse_int(row["mon_clip"]) / sample_count,
        parse_int(row["mon_saturation"]) / sample_count,
        0.0 if observation_error is None else observation_error / input_power,
    )
    return tuple(quantize(value) for value in raw), missing


def replay(model: dict[str, object], rows: list[dict[str, str]]) -> tuple[list[dict[str, object]], dict[str, object]]:
    output = []
    known_ood_rows = 0
    for row in rows:
        features, missing = board_features(row)
        bounds = model["feature_bounds_q20"]
        ood_features = [model["features"][index] for index, (value, bound) in
                        enumerate(zip(features, bounds))
                        if not (bound[0] <= value <= bound[1]) and
                        not ((index == 3 and "temperature_q8_8" in missing) or
                             (index == 12 and "observation_error_l1" in missing))]
        known_ood_rows += int(bool(ood_features))
        result = infer(model, features, valid=not missing)
        output.append({
            "scenario_id": row["scenario_id"],
            "dsm_config_id": row.get("dsm_config_id", ""),
            "missing_features": ";".join(missing),
            "known_ood_features": ";".join(ood_features),
            "strict_package": result["package"],
            "strict_action": "direct" if result["direct"] else "fallback_14",
            "strict_ood": result["ood"],
            "policy_cost": parse_int(row["policy_cost"]),
            "local_search_final_cost": parse_int(row["local_search_final_cost"]),
            "full_search_final_cost": parse_int(row["full_search_final_cost"]),
            "recorded_search_benefit": (parse_int(row["policy_cost"]) -
                                         parse_int(row["local_search_final_cost"])),
            **{f"feature_{index}_q20": value for index, value in enumerate(features)},
        })
    direct = sum(item["strict_action"] == "direct" for item in output)
    report = {
        "model_feature_schema": model.get("feature_schema", "unspecified"),
        "replay_feature_schema": "pl_dsm_monitor_v1",
        "rows": len(output),
        "direct_decisions": direct,
        "fallback_decisions": len(output) - direct,
        "rows_with_missing_features": sum(bool(item["missing_features"]) for item in output),
        "rows_with_known_feature_ood": known_ood_rows,
        "mean_recorded_search_benefit": (sum(int(item["recorded_search_benefit"])
                                                for item in output) / len(output)),
        "deployment_allowed": False,
        "reason": ("schema mismatch: retained traces lack temperature and observer-error "
                   "features, while PL output monitors describe the post-DSM one-bit stream "
                   "rather than the complex behavioral PA observation"),
    }
    return output, report


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_vectors(path: Path, rows: list[dict[str, object]], model: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# name valid f0..f12 package direct path path_len ood\n")
        for row in rows:
            features = tuple(int(row[f"feature_{index}_q20"])
                             for index in range(FEATURE_COUNT))
            valid = not bool(row["missing_features"])
            result = infer(model, features, valid=valid)
            words = [str(row["scenario_id"]), str(int(valid)),
                     *(str(value) for value in features), str(result["package"]),
                     str(result["direct"]), str(result["path"]),
                     str(result["path_len"]), str(result["ood"])]
            handle.write(" ".join(words) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--board-dataset", type=Path, required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    parser.add_argument("--vectors-out", type=Path, required=True)
    args = parser.parse_args()
    with args.model.open(encoding="ascii") as handle:
        model = json.load(handle)["model"]
    rows, report = replay(model, read_csv(args.board_dataset))
    write_csv(args.out_csv, rows)
    write_vectors(args.vectors_out, rows, model)
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    with args.out_json.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(json.dumps(report, indent=2))
    if report["direct_decisions"] != 0:
        raise RuntimeError("Incomplete retained traces must not release a direct decision")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
