#!/usr/bin/env python3
"""Create the auditable AI-assisted DPD calibration comparison report."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def mean(rows: list[dict[str, str]], name: str) -> float:
    return sum(float(row[name]) for row in rows) / len(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dpd-summary", type=Path, required=True)
    parser.add_argument("--blind", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    dpd_rows = read_csv(args.dpd_summary)
    with args.blind.open(encoding="ascii") as handle:
        blind = json.load(handle)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("# AI-Assisted DPD Calibration Comparison\n\n")
        handle.write("Generated from the held-out memory-polynomial DPD comparison and the isolated observer-v2 blind PA matrix. "
                     "The PA is behavioral; no physical RF claim is made.\n\n")
        handle.write("## DPD Linearization\n\n")
        handle.write("| Mode | Mean EVM % | Mean NMSE dB | Mean SNDR dB | Mean ACLR dBc | DPD saturation | Drive limited |\n")
        handle.write("|---|---:|---:|---:|---:|---:|---:|\n")
        for row in dpd_rows:
            handle.write("| {Mode} | {Mean_EVM_percent:.6f} | {Mean_NMSE_dB:.6f} | {Mean_SNDR_dB:.6f} | {Mean_ACLR_avg_dBc:.6f} | {Total_DPDSaturationCount} | {Total_DriveLimitCount} |\n".format(
                Mode=row["Mode"], Mean_EVM_percent=float(row["Mean_EVM_percent"]),
                Mean_NMSE_dB=float(row["Mean_NMSE_dB"]), Mean_SNDR_dB=float(row["Mean_SNDR_dB"]),
                Mean_ACLR_avg_dBc=float(row["Mean_ACLR_avg_dBc"]),
                Total_DPDSaturationCount=row["Total_DPDSaturationCount"],
                Total_DriveLimitCount=row["Total_DriveLimitCount"]))
        handle.write("\n## AI Seed and Search Policy\n\n")
        handle.write("| Strategy | Seed source | Final selection | Candidate records | Safety evidence |\n")
        handle.write("|---|---|---|---:|---|\n")
        handle.write("| Fixed package + local search | Static package | Bounded local search | 14 | Baseline; final cost from search |\n")
        handle.write("| Waveform LUT + local search | Training-waveform LUT | Bounded local search | 14 | LUT safety arbitration |\n")
        handle.write("| Observer-v2 tree -> LUT + local search | Frozen Q12.20 tree, then LUT fallback | Bounded MP local search | 14 | Tree never enables direct execution |\n\n")
        handle.write("## Isolated Blind PA Evaluation\n\n")
        handle.write("| Blind profile | Conditions | Tree seeds | LUT seeds | Default fallback | Seed safety violations | Mean seed regret | Final candidates |\n")
        handle.write("|---|---:|---:|---:|---:|---:|---:|---:|\n")
        for row in blind["profiles"]:
            handle.write(f"| {row['profile']} | {row['conditions']} | {row['tree_seeds']} | {row['lut_seeds']} | {row['fallback_default_seeds']} | {row['safety_violations']} | {row['mean_seed_regret']:.3f} | 14 |\n")
        handle.write("\n")
        handle.write(f"Overall blind seed safety violations: `{blind['seed_safety_violations']}`. "
                     f"Tree/LUT/default seed counts: `{blind['tree_seed_count']}`/"
                     f"`{blind['lut_seed_count']}`/`{blind['fallback_default_count']}`.\n\n")
        handle.write("The blind policy evaluation judges only the seed package because the behavioral data labels package-stage costs. "
                     "On PS, every selected seed still executes the same 14-record deterministic local search and final replay. "
                     "The observer-v2 feature source must be a completed aligned complex-feedback window; post-DSM monitor proxies are not substituted for it.\n")
    print(f"Wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
