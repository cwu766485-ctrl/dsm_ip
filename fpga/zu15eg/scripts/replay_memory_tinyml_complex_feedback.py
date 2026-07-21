#!/usr/bin/env python3
"""Replay aligned complex-feedback traces through the frozen Q20 tree."""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from evaluate_memory_tinyml_loso import FEATURE_SCHEMA, read_conditions  # noqa: E402
from export_memory_tinyml_tree import infer, quantize  # noqa: E402


MONITOR_FIELDS = (
    "input_power", "output_power", "peak", "avg_mag", "evm_proxy",
    "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
    "clip", "saturation", "observation_error_l1",
)


def abs_s16(value: int) -> int:
    return 32767 if value == -32768 else abs(value)


def signed32(value: int) -> int:
    value &= 0xffffffff
    return value - 0x100000000 if value & 0x80000000 else value


def abs_s32(value: int) -> int:
    return 0x7fffffff if value == -0x80000000 else abs(value)


def finish_trace(state: dict[str, int]) -> dict[str, int]:
    bin0 = min(abs_s32(state["bin0_i"]) + abs_s32(state["bin0_q"]), 0xffffffff)
    bin1 = min(abs_s32(state["bin1_i"]) + abs_s32(state["bin1_q"]), 0xffffffff)
    bin2 = min(abs_s32(state["bin2_i"]) + abs_s32(state["bin2_q"]), 0xffffffff)
    return {
        "input_power": state["input_power"],
        "output_power": state["output_power"],
        "peak": state["peak"],
        "avg_mag": state["output_power"] // max(state["samples"], 1),
        "evm_proxy": state["error_l1"] & 0xffffffff,
        "acpr_proxy": state["slew"] & 0xffffffff,
        "spec_bin0": bin0,
        "spec_bin1": bin1,
        "spec_bin2": bin2,
        "spec_adj": min(bin0 + bin2, 0xffffffff),
        "clip": state["clip"],
        "saturation": state["saturation"],
        "observation_error_l1": state["error_l1"],
        "sample_count": state["samples"],
    }


def replay_raw_traces(path: Path) -> dict[int, dict[str, int]]:
    states: dict[int, dict[str, int]] = {}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            trace_id = int(row["trace_id"])
            state = states.setdefault(trace_id, defaultdict(int))
            ref_i = int(row["ref_i_q1_15"])
            ref_q = int(row["ref_q_q1_15"])
            obs_i = int(row["obs_i_q1_15"])
            obs_q = int(row["obs_q_q1_15"])
            gain_re = int(row["gain_re_q2_14"])
            gain_im = int(row["gain_im_q2_14"])
            aligned_i_wide = (obs_i * gain_re - obs_q * gain_im) >> 14
            aligned_q_wide = (obs_i * gain_im + obs_q * gain_re) >> 14
            aligned_i = min(max(aligned_i_wide, -32768), 32767)
            aligned_q = min(max(aligned_q_wide, -32768), 32767)
            ref_mag = abs_s16(ref_i) + abs_s16(ref_q)
            obs_mag = abs_s16(aligned_i) + abs_s16(aligned_q)
            state["input_power"] = (state["input_power"] + ref_mag) & 0xffffffff
            state["output_power"] = (state["output_power"] + obs_mag) & 0xffffffff
            state["peak"] = max(state["peak"], obs_mag)
            state["error_l1"] += abs(aligned_i_wide - ref_i) + abs(aligned_q_wide - ref_q)
            state["clip"] += int(abs_s16(aligned_i) >= 31130 or abs_s16(aligned_q) >= 31130)
            state["saturation"] += int(not (-32768 <= aligned_i_wide <= 32767) or
                                        not (-32768 <= aligned_q_wide <= 32767))
            if state["samples"]:
                state["slew"] = (state["slew"] + abs(aligned_i - state["prev_i"]) +
                                  abs(aligned_q - state["prev_q"])) & 0xffffffff
            phase = state["samples"] & 3
            state["bin0_i"] = signed32(state["bin0_i"] + aligned_i)
            state["bin0_q"] = signed32(state["bin0_q"] + aligned_q)
            sign = 1 if not (phase & 1) else -1
            state["bin2_i"] = signed32(state["bin2_i"] + sign * aligned_i)
            state["bin2_q"] = signed32(state["bin2_q"] + sign * aligned_q)
            if phase == 0:
                state["bin1_i"] = signed32(state["bin1_i"] + aligned_i)
                state["bin1_q"] = signed32(state["bin1_q"] + aligned_q)
            elif phase == 1:
                state["bin1_i"] = signed32(state["bin1_i"] + aligned_q)
                state["bin1_q"] = signed32(state["bin1_q"] - aligned_i)
            elif phase == 2:
                state["bin1_i"] = signed32(state["bin1_i"] - aligned_i)
                state["bin1_q"] = signed32(state["bin1_q"] - aligned_q)
            else:
                state["bin1_i"] = signed32(state["bin1_i"] - aligned_q)
                state["bin1_q"] = signed32(state["bin1_q"] + aligned_i)
            state["prev_i"] = aligned_i
            state["prev_q"] = aligned_q
            state["samples"] += 1
    return {trace_id: finish_trace(state) for trace_id, state in states.items()}


def replay(model: dict[str, object], conditions: list[dict[str, object]],
           raw_stats: dict[int, dict[str, int]],
           trace_ids: dict[str, int]) -> tuple[list[dict[str, object]], dict[str, object]]:
    if model.get("feature_schema") != FEATURE_SCHEMA:
        raise ValueError(
            f"Expected model schema {FEATURE_SCHEMA}, got {model.get('feature_schema')}")
    rows = []
    for condition in conditions:
        condition_id = str(condition["condition_id"])
        trace_id = trace_ids[condition_id]
        stats = raw_stats[trace_id]
        first_package = condition["packages"][0]
        mismatches = [field for field in MONITOR_FIELDS
                      if int(float(first_package[field])) != stats[field]]
        if int(condition["monitor_sample_count"]) != stats["sample_count"]:
            mismatches.append("monitor_sample_count")
        features = tuple(quantize(float(value)) for value in condition["feature"])
        result = infer(model, features)
        package = int(result["package"])
        direct = bool(result["direct"])
        package_row = condition["packages"].get(package) if direct else None
        safe = int(package_row["safe"]) if package_row is not None else 1
        oracle_cost = float(condition["oracle_cost"])
        cost = float(package_row["cost"]) if package_row is not None else math.nan
        regret = cost - oracle_cost if direct and math.isfinite(oracle_cost) else math.nan
        rows.append({
            "condition_id": condition_id,
            "trace_id": trace_id,
            "profile_id": condition["profile_id"],
            "waveform_id": condition["waveform_id"],
            "monitor_schema": condition["monitor_schema"],
            "monitor_sample_count": condition["monitor_sample_count"],
            "tree_package": package,
            "tree_action": "direct_suggestion" if direct else "fallback_14",
            "decision_path": result["path"],
            "decision_path_length": result["path_len"],
            "out_of_distribution": result["ood"],
            "actual_safe": safe,
            "actual_cost": round(cost) if math.isfinite(cost) else "",
            "oracle_cost": round(oracle_cost) if math.isfinite(oracle_cost) else "",
            "actual_regret": round(regret) if math.isfinite(regret) else "",
            "raw_trace_monitor_match": int(not mismatches),
            "raw_trace_mismatches": ";".join(mismatches),
            "deployment_action": "fallback_14",
        })
    direct_rows = [row for row in rows if row["tree_action"] == "direct_suggestion"]
    report = {
        "feature_schema": FEATURE_SCHEMA,
        "model_version": model["model_version"],
        "traces": len(rows),
        "direct_suggestions": len(direct_rows),
        "tree_fallbacks": len(rows) - len(direct_rows),
        "direct_safety_violations": sum(not row["actual_safe"] for row in direct_rows),
        "direct_mean_regret": (sum(float(row["actual_regret"]) for row in direct_rows) /
                               len(direct_rows)) if direct_rows else 0.0,
        "direct_max_regret": max((int(row["actual_regret"]) for row in direct_rows), default=0),
        "raw_trace_monitor_matches": sum(int(row["raw_trace_monitor_match"]) for row in rows),
        "raw_trace_monitor_mismatches": sum(not row["raw_trace_monitor_match"] for row in rows),
        "all_features_in_domain": all(not row["out_of_distribution"] for row in rows),
        "runtime_policy": "mandatory_14_candidate",
        "tinyml_axi_integration_enabled": False,
        "note": ("Frozen-tree outputs are replayed as suggestions only. The deployed policy "
                 "continues to execute the 14-candidate safety search."),
    }
    return rows, report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--traces", type=Path, required=True)
    parser.add_argument("--out-csv", type=Path, required=True)
    parser.add_argument("--out-json", type=Path, required=True)
    args = parser.parse_args()
    with args.model.open(encoding="ascii") as handle:
        model = json.load(handle)["model"]
    with args.input.open(newline="", encoding="utf-8-sig") as handle:
        trace_ids: dict[str, int] = {}
        for row in csv.DictReader(handle):
            trace_ids.setdefault(row["condition_id"], int(float(row["monitor_trace_id"])))
    rows, report = replay(model, read_conditions(args.input),
                          replay_raw_traces(args.traces), trace_ids)
    args.out_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.out_csv.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    with args.out_json.open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(json.dumps(report, indent=2))
    return int(report["direct_safety_violations"] != 0 or
               report["raw_trace_monitor_mismatches"] != 0 or
               not math.isfinite(float(report["direct_mean_regret"])))


if __name__ == "__main__":
    raise SystemExit(main())
