#!/usr/bin/env python3
"""Generate a software DPD seed table from MATLAB sweep and board replay data.

This is intentionally lightweight: it builds a deterministic lookup /
nearest-neighbor seed artifact for the PS-side calibration loop. It does not
claim to train a neural PA model.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_SWEEP = Path("matlab/out/dpd/ai_assisted_dpd_sweep.csv")
DEFAULT_REPLAY_GLOB = "fpga/zu15eg/out/dsm_replay_counters_*.csv"


@dataclass
class Target:
    qam: float | None
    used_subcarriers: float | None
    input_backoff: float | None


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    with path.open(newline="") as f:
        return list(csv.DictReader(f))


def parse_float(value: str | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def parse_int_auto(value: str | None) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value, 0)
    except ValueError:
        return None


def latest_existing(paths: Iterable[Path]) -> Path | None:
    existing = [p for p in paths if p.exists()]
    if not existing:
        return None
    return max(existing, key=lambda p: p.stat().st_mtime)


def coeff_distance(row: dict[str, str], replay: dict[str, str]) -> int | None:
    total = 0
    pairs = [
        ("C1_hex", "DPD_C1"),
        ("C3_hex", "DPD_C3"),
        ("C5_hex", "DPD_C5"),
    ]
    for left, right in pairs:
        a = parse_int_auto(row.get(left))
        b = parse_int_auto(replay.get(right))
        if a is None or b is None:
            return None
        total += abs(a - b)
    return total


def scenario_distance(row: dict[str, str], target: Target) -> float | None:
    terms: list[float] = []
    qam = parse_float(row.get("QAM"))
    sc = parse_float(row.get("UsedSubcarriers"))
    backoff = parse_float(row.get("InputBackoff"))

    if target.qam is not None and qam is not None:
        terms.append(abs(qam - target.qam) / max(target.qam, qam, 1.0))
    if target.used_subcarriers is not None and sc is not None:
        terms.append(abs(sc - target.used_subcarriers) / max(target.used_subcarriers, sc, 1.0))
    if target.input_backoff is not None and backoff is not None:
        terms.append(abs(backoff - target.input_backoff) / max(target.input_backoff, backoff, 0.01))

    if not terms:
        return None
    return sum(terms)


def loss_value(row: dict[str, str]) -> float:
    value = parse_float(row.get("optimized_poly_loss"))
    if value is None:
        value = parse_float(row.get("OptimizedPoly_Loss"))
    return value if value is not None else 1.0e30


def build_seed_rows(sweep_paths: list[Path], replay_paths: list[Path], target: Target) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    replay_rows: list[dict[str, str]] = []
    for replay_path in replay_paths:
        for replay in read_csv_rows(replay_path):
            replay["source_file"] = str(replay_path)
            replay_rows.append(replay)

    latest_replay = replay_rows[-1] if replay_rows else None

    for sweep_path in sweep_paths:
        for src in read_csv_rows(sweep_path):
            dist = scenario_distance(src, target)
            coeff_delta = coeff_distance(src, latest_replay) if latest_replay else None
            row = {
                "row_type": "matlab_sweep",
                "scenario": src.get("Scenario", ""),
                "qam": src.get("QAM", ""),
                "used_subcarriers": src.get("UsedSubcarriers", ""),
                "input_backoff": src.get("InputBackoff", ""),
                "seed_mode": "poly",
                "c1": src.get("C1_hex", ""),
                "c3": src.get("C3_hex", ""),
                "c5": src.get("C5_hex", ""),
                "lut0": src.get("LUT0_hex", ""),
                "lut15": src.get("LUT15_hex", ""),
                "optimized_poly_loss": src.get("OptimizedPoly_Loss", ""),
                "evm_improvement_x": src.get("EVM_Improvement_x", ""),
                "sndr_improvement_db": src.get("SNDR_Improvement_dB", ""),
                "nearest_target_distance": "" if dist is None else f"{dist:.9g}",
                "coeff_distance_to_latest_replay": "" if coeff_delta is None else str(coeff_delta),
                "mon_input_power": "",
                "mon_output_power": "",
                "mon_clip_count": "",
                "mon_peak": "",
                "mon_avg_mag": "",
                "mon_evm_proxy": "",
                "mon_acpr_proxy": "",
                "mon_spec_adj": "",
                "timestamp": "",
                "source_file": str(sweep_path),
            }
            rows.append(row)

    for replay in replay_rows:
        rows.append(
            {
                "row_type": "board_replay",
                "scenario": "latest_board_replay",
                "qam": "",
                "used_subcarriers": "",
                "input_backoff": "",
                "seed_mode": "board_final",
                "c1": replay.get("DPD_C1", ""),
                "c3": replay.get("DPD_C3", ""),
                "c5": replay.get("DPD_C5", ""),
                "lut0": "",
                "lut15": "",
                "optimized_poly_loss": "",
                "evm_improvement_x": "",
                "sndr_improvement_db": "",
                "nearest_target_distance": "",
                "coeff_distance_to_latest_replay": "0",
                "mon_input_power": replay.get("MON_INPUT_POWER", ""),
                "mon_output_power": replay.get("MON_OUTPUT_POWER", ""),
                "mon_clip_count": replay.get("MON_CLIP_COUNT", ""),
                "mon_peak": replay.get("MON_PEAK", ""),
                "mon_avg_mag": replay.get("MON_AVG_MAG", ""),
                "mon_evm_proxy": replay.get("MON_EVM_PROXY", ""),
                "mon_acpr_proxy": replay.get("MON_ACPR_PROXY", ""),
                "mon_spec_adj": replay.get("MON_SPEC_ADJ", ""),
                "timestamp": replay.get("timestamp", ""),
                "source_file": replay.get("source_file", ""),
            }
        )

    return rows


def choose_recommendation(rows: list[dict[str, str]], target: Target) -> dict[str, str] | None:
    candidates = [r for r in rows if r.get("row_type") == "matlab_sweep"]
    if not candidates:
        board = [r for r in rows if r.get("row_type") == "board_replay"]
        return board[-1] if board else None

    has_target = (
        target.qam is not None
        or target.used_subcarriers is not None
        or target.input_backoff is not None
    )
    if has_target:
        def target_key(row: dict[str, str]) -> tuple[float, float]:
            dist = parse_float(row.get("nearest_target_distance"))
            return (dist if dist is not None else 1.0e30, loss_value(row))

        return min(candidates, key=target_key)

    return min(candidates, key=loss_value)


def find_package_index(recommendation: dict[str, str] | None,
                       rows: list[dict[str, str]]) -> int:
    """Map a selected MATLAB row to the matching exported DPD package."""
    if recommendation is None:
        return 0
    poly_rows = [row for row in rows if row.get("row_type") == "matlab_sweep"]
    for index, row in enumerate(poly_rows):
        if all(row.get(key) == recommendation.get(key) for key in ("c1", "c3", "c5")):
            return index
    return 0


def write_seed_csv(path: Path, rows: list[dict[str, str]]) -> None:
    fields = [
        "row_type",
        "scenario",
        "qam",
        "used_subcarriers",
        "input_backoff",
        "seed_mode",
        "c1",
        "c3",
        "c5",
        "lut0",
        "lut15",
        "optimized_poly_loss",
        "evm_improvement_x",
        "sndr_improvement_db",
        "nearest_target_distance",
        "coeff_distance_to_latest_replay",
        "mon_input_power",
        "mon_output_power",
        "mon_clip_count",
        "mon_peak",
        "mon_avg_mag",
        "mon_evm_proxy",
        "mon_acpr_proxy",
        "mon_spec_adj",
        "timestamp",
        "source_file",
    ]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path: Path, rows: list[dict[str, str]], recommendation: dict[str, str] | None, target: Target) -> None:
    matlab_count = sum(1 for r in rows if r.get("row_type") == "matlab_sweep")
    replay_count = sum(1 for r in rows if r.get("row_type") == "board_replay")
    latest_replay = [r for r in rows if r.get("row_type") == "board_replay"]

    with path.open("w", encoding="utf-8") as f:
        f.write("# DPD Seed Recommendation\n\n")
        f.write("This artifact is a deterministic software lookup seed for PS-side calibration. It is tiny-ML-ready training/input data, not a trained neural PA model.\n\n")
        f.write(f"- MATLAB sweep rows: {matlab_count}\n")
        f.write(f"- Board replay rows: {replay_count}\n")
        f.write(f"- Target QAM: `{'' if target.qam is None else target.qam}`\n")
        f.write(f"- Target used subcarriers: `{'' if target.used_subcarriers is None else target.used_subcarriers}`\n")
        f.write(f"- Target input backoff: `{'' if target.input_backoff is None else target.input_backoff}`\n\n")

        if recommendation is None:
            f.write("No recommendation could be generated because no sweep or replay rows were available.\n")
            return

        f.write("## Recommended Seed\n\n")
        f.write(f"- Source type: `{recommendation.get('row_type', '')}`\n")
        f.write(f"- Scenario: `{recommendation.get('scenario', '')}`\n")
        f.write(f"- Mode: `{recommendation.get('seed_mode', '')}`\n")
        f.write(f"- C1/C3/C5: `{recommendation.get('c1', '')}`, `{recommendation.get('c3', '')}`, `{recommendation.get('c5', '')}`\n")
        f.write(f"- LUT0/LUT15: `{recommendation.get('lut0', '')}`, `{recommendation.get('lut15', '')}`\n")
        f.write(f"- Optimized polynomial loss: `{recommendation.get('optimized_poly_loss', '')}`\n")
        f.write(f"- Target distance: `{recommendation.get('nearest_target_distance', '')}`\n")
        f.write(f"- Source file: `{recommendation.get('source_file', '')}`\n\n")

        if latest_replay:
            replay = latest_replay[-1]
            f.write("## Latest Board Replay\n\n")
            f.write(f"- Timestamp: `{replay.get('timestamp', '')}`\n")
            f.write(f"- C1/C3/C5: `{replay.get('c1', '')}`, `{replay.get('c3', '')}`, `{replay.get('c5', '')}`\n")
            f.write(f"- MON_EVM_PROXY/MON_ACPR_PROXY/MON_SPEC_ADJ: `{replay.get('mon_evm_proxy', '')}` / `{replay.get('mon_acpr_proxy', '')}` / `{replay.get('mon_spec_adj', '')}`\n")
            f.write(f"- MON_CLIP_COUNT: `{replay.get('mon_clip_count', '')}`\n\n")


def write_seed_header(path: Path, recommendation: dict[str, str] | None,
                      rows: list[dict[str, str]]) -> None:
    """Emit the optional bare-metal seed consumed before package evaluation."""
    package_index = find_package_index(recommendation, rows)
    c1 = parse_int_auto(recommendation.get("c1")) if recommendation else None
    c3 = parse_int_auto(recommendation.get("c3")) if recommendation else None
    c5 = parse_int_auto(recommendation.get("c5")) if recommendation else None

    with path.open("w", encoding="ascii", newline="\n") as f:
        f.write("#ifndef DSM_DPD_SEED_H\n")
        f.write("#define DSM_DPD_SEED_H\n\n")
        f.write("/* Generated by generate_dpd_seed_table.py; do not edit manually. */\n")
        if c1 is None or c3 is None or c5 is None:
            f.write("#define DSM_DPD_SEED_AVAILABLE 0U\n")
            f.write("#define DSM_DPD_SEED_PACKAGE_IDX 0U\n")
            f.write("#define DSM_DPD_SEED_C1_WORD 0U\n")
            f.write("#define DSM_DPD_SEED_C3_WORD 0U\n")
            f.write("#define DSM_DPD_SEED_C5_WORD 0U\n")
        else:
            f.write("#define DSM_DPD_SEED_AVAILABLE 1U\n")
            f.write(f"#define DSM_DPD_SEED_PACKAGE_IDX {package_index}U\n")
            f.write(f"#define DSM_DPD_SEED_C1_WORD 0x{c1:08X}U\n")
            f.write(f"#define DSM_DPD_SEED_C3_WORD 0x{c3:08X}U\n")
            f.write(f"#define DSM_DPD_SEED_C5_WORD 0x{c5:08X}U\n")
        f.write("\n#endif /* DSM_DPD_SEED_H */\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sweep-csv", action="append", type=Path, default=[], help="MATLAB DPD sweep CSV. Can be repeated.")
    parser.add_argument("--replay-csv", action="append", type=Path, default=[], help="Board replay counter CSV. Can be repeated.")
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out"))
    parser.add_argument("--prefix", default="dpd_seed_table")
    parser.add_argument("--header", type=Path,
                        help="Optional generated C header for the bare-metal seed.")
    parser.add_argument("--qam", type=float)
    parser.add_argument("--used-subcarriers", type=float)
    parser.add_argument("--input-backoff", type=float)
    args = parser.parse_args()

    sweep_paths = args.sweep_csv or ([DEFAULT_SWEEP] if DEFAULT_SWEEP.exists() else [])
    if args.replay_csv:
        replay_paths = args.replay_csv
    else:
        latest_replay = latest_existing(Path(".").glob(DEFAULT_REPLAY_GLOB))
        replay_paths = [latest_replay] if latest_replay else []

    target = Target(args.qam, args.used_subcarriers, args.input_backoff)
    rows = build_seed_rows(sweep_paths, replay_paths, target)
    recommendation = choose_recommendation(rows, target)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    seed_csv = args.out_dir / f"{args.prefix}.csv"
    markdown = args.out_dir / f"{args.prefix}_recommendation.md"
    write_seed_csv(seed_csv, rows)
    write_markdown(markdown, rows, recommendation, target)
    if args.header is not None:
        args.header.parent.mkdir(parents=True, exist_ok=True)
        write_seed_header(args.header, recommendation, rows)

    print(f"Seed rows: {len(rows)}")
    if recommendation is not None:
        print(f"Recommended: {recommendation.get('scenario', '')} {recommendation.get('c1', '')} {recommendation.get('c3', '')} {recommendation.get('c5', '')}")
    print(f"Wrote: {seed_csv}")
    print(f"Wrote: {markdown}")
    if args.header is not None:
        print(f"Wrote: {args.header}")


if __name__ == "__main__":
    main()
