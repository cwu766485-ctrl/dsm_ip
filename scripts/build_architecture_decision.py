#!/usr/bin/env python3
"""Build an auditable architecture-selection summary from checked-in evidence.

The script intentionally consumes only compact, version-controlled evidence.
It does not run MATLAB, synthesis, or a simulator. Those flows generate the
source evidence; this utility verifies the input schema and calculates the
published comparison deltas without hand-maintained arithmetic.
"""

from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


REPO = Path(__file__).resolve().parents[1]
BP_COMPARISON = REPO / "docs" / "evidence" / "frontend" / "p0_bp_dsm_comparison_20260805.csv"
OOC_MATRIX = REPO / "docs" / "evidence" / "ooc" / "dsm_ip_axi_matrix_xczu15eg_ffvb1156_1_i_20260706_post_synth_summary.csv"
OUTPUT = REPO / "docs" / "evidence" / "architecture" / "frozen_sku_architecture_summary.csv"


@dataclass(frozen=True)
class Row:
    study: str
    baseline: str
    selected: str
    metric: str
    baseline_value: float
    selected_value: float
    absolute_delta: float
    relative_delta_percent: float
    unit: str
    evidence: str
    interpretation: str


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise FileNotFoundError(f"Required evidence is missing: {path}")
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def find_row(rows: Iterable[dict[str, str]], key: str, value: str) -> dict[str, str]:
    for row in rows:
        if row.get(key) == value:
            return row
    raise ValueError(f"No row with {key}={value!r}")


def make_row(
    study: str,
    baseline: str,
    selected: str,
    metric: str,
    base: float,
    candidate: float,
    unit: str,
    evidence: str,
    interpretation: str,
) -> Row:
    relative = 0.0 if base == 0.0 else 100.0 * (candidate - base) / abs(base)
    return Row(
        study=study,
        baseline=baseline,
        selected=selected,
        metric=metric,
        baseline_value=base,
        selected_value=candidate,
        absolute_delta=candidate - base,
        relative_delta_percent=relative,
        unit=unit,
        evidence=evidence,
        interpretation=interpretation,
    )


def build_rows() -> list[Row]:
    bp = read_csv(BP_COMPARISON)
    bp_base = find_row(bp, "Candidate", "BP DSM single-loop resonator")
    bp_selected = find_row(bp, "Candidate", "BP EFDSM2 error-feedback second-order")

    rows = [
        make_row(
            "one_bit_bp_dsm_narrow_digital_audit",
            bp_base["Candidate"],
            bp_selected["Candidate"],
            "EVM",
            float(bp_base["EVM_percent"]),
            float(bp_selected["EVM_percent"]),
            "percent",
            BP_COMPARISON.relative_to(REPO).as_posix(),
            "Lower is better in this narrow ideal-filter digital audit; not a system-level selection claim.",
        ),
        make_row(
            "one_bit_bp_dsm_narrow_digital_audit",
            bp_base["Candidate"],
            bp_selected["Candidate"],
            "SNDR",
            float(bp_base["SNDR_dB"]),
            float(bp_selected["SNDR_dB"]),
            "dB",
            BP_COMPARISON.relative_to(REPO).as_posix(),
            "Higher is better in this narrow ideal-filter digital audit; not a system-level selection claim.",
        ),
        make_row(
            "one_bit_bp_dsm_narrow_digital_audit",
            bp_base["Candidate"],
            bp_selected["Candidate"],
            "correlation",
            float(bp_base["Correlation"]),
            float(bp_selected["Correlation"]),
            "ratio",
            BP_COMPARISON.relative_to(REPO).as_posix(),
            "Higher is better; this is a supporting alignment metric.",
        ),
    ]

    ooc = read_csv(OOC_MATRIX)
    base = find_row(ooc, "Top", "dsm_ip_axi_alg3_interp3")
    selected = find_row(ooc, "Top", "dsm_ip_axi_alg3_interp4")
    evidence = OOC_MATRIX.relative_to(REPO).as_posix()
    for name, field, unit, interpretation in (
        ("LUT", "LUT", "count", "Lower is better; x32 is the required higher-OSR operating point."),
        ("FF", "FF", "count", "Lower is better; x32 is the required higher-OSR operating point."),
        ("DSP", "DSP", "count", "Lower is better; CIC compensation increases DSP usage."),
        ("estimated Fmax", "Fmax_est_MHz", "MHz", "Higher is better; both rows pass the 100 MHz OOC target."),
    ):
        rows.append(
            make_row(
                "interpolation_operating_point",
                "EFDSM2_1b + x16_halfband",
                "EFDSM2_1b + x32_hb_cic_equiv_comp_fir",
                name,
                float(base[field]),
                float(selected[field]),
                unit,
                evidence,
                interpretation,
            )
        )
    return rows


def write_rows(rows: list[Row], output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    fields = list(Row.__dataclass_fields__)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            data = row.__dict__.copy()
            for key in ("baseline_value", "selected_value", "absolute_delta", "relative_delta_percent"):
                data[key] = f"{data[key]:.6f}"
            writer.writerow(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail unless the checked-in summary matches regenerated output.")
    args = parser.parse_args()

    rows = build_rows()
    if args.check:
        if not OUTPUT.is_file():
            raise SystemExit(f"Missing generated summary: {OUTPUT}")
        expected = OUTPUT.read_text(encoding="utf-8")
        temporary = OUTPUT.with_suffix(".tmp")
        write_rows(rows, temporary)
        actual = temporary.read_text(encoding="utf-8")
        temporary.unlink()
        if actual != expected:
            raise SystemExit("Architecture summary is stale; run this script without --check.")
        print(f"ARCHITECTURE_DECISION_CHECK_PASS rows={len(rows)}")
        return 0

    write_rows(rows, OUTPUT)
    print(f"ARCHITECTURE_DECISION_BUILD_PASS rows={len(rows)} output={OUTPUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
