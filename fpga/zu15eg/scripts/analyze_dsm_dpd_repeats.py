#!/usr/bin/env python3
"""Summarize repeat-aware paired DSM/DPD calibration evidence.

This tool operates only on PL monitor proxy costs. It reports a predeclared
stability gate for deciding whether a third DSM collection is justified.
"""

from __future__ import annotations

import argparse
import csv
import math
import statistics
import tempfile
from collections import defaultdict
from pathlib import Path


PAIR_FIELDS = ("pa_profile", "pa_strength_db", "qam", "bandwidth_mhz",
               "used_subcarriers", "input_backoff", "waveform_id")
T95_BY_DF = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447,
             7: 2.365, 8: 2.306, 9: 2.262, 10: 2.228, 11: 2.201, 12: 2.179,
             13: 2.160, 14: 2.145, 15: 2.131, 16: 2.120, 17: 2.110,
             18: 2.101, 19: 2.093, 20: 2.086, 21: 2.080, 22: 2.074,
             23: 2.069, 24: 2.064, 25: 2.060, 26: 2.056, 27: 2.052,
             28: 2.048, 29: 2.045, 30: 2.042}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def mean_ci(values: list[float]) -> tuple[float, float, float, float]:
    mean = statistics.fmean(values)
    if len(values) < 2:
        return mean, 0.0, mean, mean
    stddev = statistics.stdev(values)
    critical = T95_BY_DF.get(len(values) - 1, 1.96)
    margin = critical * stddev / math.sqrt(len(values))
    return mean, stddev, mean - margin, mean + margin


def pair_key(row: dict[str, str]) -> tuple[str, ...]:
    return tuple(row[field] for field in PAIR_FIELDS)


def summarize(rows: list[dict[str, str]], baseline: str, candidate: str,
              required_repeats: int, required_win_rate: float) -> tuple[list[dict[str, object]], dict[str, object]]:
    grouped: dict[tuple[str, tuple[str, ...]], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        grouped[(row["dsm_config_id"], pair_key(row))].append(row)
    keys = sorted({key for config, key in grouped if config == baseline} &
                  {key for config, key in grouped if config == candidate})
    paired = []
    for key in keys:
        left = grouped[(baseline, key)]
        right = grouped[(candidate, key)]
        left_values = [float(row["local_search_final_cost"]) for row in left]
        right_values = [float(row["local_search_final_cost"]) for row in right]
        left_mean, left_std, _, _ = mean_ci(left_values)
        right_mean, right_std, _, _ = mean_ci(right_values)
        paired.append({
            **dict(zip(PAIR_FIELDS, key)),
            "baseline_config": baseline,
            "candidate_config": candidate,
            "baseline_repeats": len(left_values),
            "candidate_repeats": len(right_values),
            "baseline_local_mean": f"{left_mean:.6f}",
            "baseline_local_stddev": f"{left_std:.6f}",
            "candidate_local_mean": f"{right_mean:.6f}",
            "candidate_local_stddev": f"{right_std:.6f}",
            "candidate_minus_baseline": f"{right_mean - left_mean:.6f}",
            "candidate_wins": int(right_mean < left_mean),
        })
    deltas = [float(row["candidate_minus_baseline"]) for row in paired]
    mean, stddev, lower, upper = mean_ci(deltas) if deltas else (0.0, 0.0, 0.0, 0.0)
    min_repeats = min((min(int(row["baseline_repeats"]), int(row["candidate_repeats"]))
                       for row in paired), default=0)
    wins = sum(int(row["candidate_wins"]) for row in paired)
    win_rate = wins / len(paired) if paired else 0.0
    stable = min_repeats >= required_repeats and upper < 0.0 and win_rate >= required_win_rate
    aggregate = {
        "baseline_config": baseline,
        "candidate_config": candidate,
        "matched_conditions": len(paired),
        "minimum_repeats_per_condition": min_repeats,
        "mean_candidate_minus_baseline": mean,
        "stddev_candidate_minus_baseline": stddev,
        "ci95_lower": lower,
        "ci95_upper": upper,
        "candidate_wins": wins,
        "candidate_win_rate": win_rate,
        "required_repeats": required_repeats,
        "required_win_rate": required_win_rate,
        "third_dsm_collection_allowed": int(stable),
    }
    return paired, aggregate


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]) if rows else [])
        writer.writeheader()
        writer.writerows(rows)


def write_report(path: Path, aggregate: dict[str, object]) -> None:
    lines = ["# DSM Repeat Statistics", "",
             "All costs are PL monitor proxy costs, not measured RF EVM/ACLR.", "",
             f"- Baseline: `{aggregate['baseline_config']}`",
             f"- Candidate: `{aggregate['candidate_config']}`",
             f"- Matched conditions: `{aggregate['matched_conditions']}`",
             f"- Minimum repeats per condition: `{aggregate['minimum_repeats_per_condition']}`",
             f"- Mean candidate-minus-baseline local cost: `{aggregate['mean_candidate_minus_baseline']:.2f}`",
             f"- 95% CI: `{aggregate['ci95_lower']:.2f}` to `{aggregate['ci95_upper']:.2f}`",
             f"- Candidate win rate: `{aggregate['candidate_win_rate']:.3f}`",
             f"- Third DSM collection allowed: `{aggregate['third_dsm_collection_allowed']}`", "",
             "The gate requires the configured repeat count, a 95% paired-condition CI below zero, and the configured win rate. It is an evidence-planning gate, not an RF safety or deployment decision.", ""]
    path.write_text("\n".join(lines), encoding="ascii")


def self_test() -> None:
    rows = []
    for config, values in (("ef1", (100, 102, 101)), ("ef2", (90, 91, 89))):
        for index, value in enumerate(values):
            rows.append({"dsm_config_id": config, "pa_profile": "n", "pa_strength_db": "0",
                         "qam": "16", "bandwidth_mhz": "20", "used_subcarriers": "48",
                         "input_backoff": "0.58", "waveform_id": "w", "local_search_final_cost": str(value),
                         "run_id": str(index)})
    paired, aggregate = summarize(rows, "ef1", "ef2", 3, 0.75)
    assert len(paired) == 1 and aggregate["third_dsm_collection_allowed"] == 1
    with tempfile.TemporaryDirectory() as directory:
        report = Path(directory) / "report.md"
        write_report(report, aggregate)
        assert "Third DSM collection allowed" in report.read_text(encoding="ascii")
    print("PASS DSM repeat-statistics self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-csv", type=Path)
    parser.add_argument("--baseline-config", required=False)
    parser.add_argument("--candidate-config", required=False)
    parser.add_argument("--required-repeats", type=int, default=3)
    parser.add_argument("--required-win-rate", type=float, default=0.75)
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out/dsm_aware_dataset"))
    parser.add_argument("--prefix", default="dsm_repeat_statistics")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.dataset_csv or not args.baseline_config or not args.candidate_config:
        parser.error("--dataset-csv, --baseline-config, and --candidate-config are required")
    rows = read_csv(args.dataset_csv)
    paired, aggregate = summarize(rows, args.baseline_config, args.candidate_config,
                                  args.required_repeats, args.required_win_rate)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_csv(args.out_dir / f"{args.prefix}.csv", paired)
    write_report(args.out_dir / f"{args.prefix}.md", aggregate)
    print(f"Third DSM collection allowed: {aggregate['third_dsm_collection_allowed']}")


if __name__ == "__main__":
    main()
