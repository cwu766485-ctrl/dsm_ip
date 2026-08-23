#!/usr/bin/env python3
"""Extract portable PPA summaries from Design Compiler text reports."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


FIELDS = [
    "node", "label", "target_mhz", "period_ns", "status", "critical_path_ns",
    "setup_slack_ns", "fmax_est_mhz", "cell_area_lib_units",
    "comb_area_lib_units", "seq_area_lib_units", "dynamic_power_mw",
    "leakage_power_uw", "total_power_mw", "power_basis", "critical_startpoint",
    "critical_endpoint", "run_dir",
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def first_float(text: str, pattern: str) -> float | None:
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    return float(match.group(1)) if match else None


def first_text(text: str, pattern: str) -> str:
    match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
    return match.group(1).strip() if match else ""


def metadata(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in read_text(path).splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def power_to_mw(value: float | None, unit: str) -> float | None:
    if value is None:
        return None
    scale = {"w": 1000.0, "mw": 1.0, "uw": 0.001, "nw": 0.000001}
    return value * scale.get(unit.lower(), 1.0)


def parse_power(text: str) -> tuple[float | None, float | None, float | None]:
    dynamic = first_float(text, r"Total\s+Dynamic\s+Power\s*=\s*([0-9.eE+-]+)")
    leakage = first_float(text, r"Cell\s+Leakage\s+Power\s*=\s*([0-9.eE+-]+)")
    total_match = re.search(r"Total\s+Power\s*=\s*([0-9.eE+-]+)\s*([mun]?W)", text, re.I)
    if total_match is None:
        total_match = re.search(
            r"^Total\s+[0-9.eE+-]+\s*(?:mW|uW|nW)\s+"
            r"[0-9.eE+-]+\s*(?:mW|uW|nW)\s+[0-9.eE+-]+\s*(?:mW|uW|nW)\s+"
            r"([0-9.eE+-]+)\s*([mun]?W)",
            text,
            re.I | re.M,
        )
    unit_match = re.search(r"Total\s+Dynamic\s+Power\s*=\s*[0-9.eE+-]+\s*([mun]?W)", text, re.I)
    dynamic_mw = power_to_mw(dynamic, unit_match.group(1) if unit_match else "mW")
    leakage_unit = re.search(r"Cell\s+Leakage\s+Power\s*=\s*[0-9.eE+-]+\s*([mun]?W)", text, re.I)
    leakage_mw = power_to_mw(leakage, leakage_unit.group(1) if leakage_unit else "mW")
    total_mw = power_to_mw(float(total_match.group(1)), total_match.group(2)) if total_match else None
    return dynamic_mw, (leakage_mw * 1000.0 if leakage_mw is not None else None), total_mw


def number(value: float | None) -> str:
    return "" if value is None else f"{value:.6f}"


def parse_run(run_dir: Path) -> dict[str, str]:
    reports = run_dir / "reports"
    meta = metadata(run_dir / "metadata.txt")
    timing = read_text(reports / "timing.rpt")
    qor = read_text(reports / "qor.rpt")
    area = read_text(reports / "area.rpt")
    power = read_text(reports / "power.rpt")
    check_design = read_text(reports / "check_design.rpt")
    path_ns = first_float(qor, r"Critical\s+Path\s+Length:\s*([0-9.eE+-]+)")
    slack_ns = first_float(qor, r"Critical\s+Path\s+Slack:\s*([0-9.eE+-]+)")
    cell_area = first_float(area, r"Total\s+cell\s+area:\s*([0-9.eE+-]+)")
    comb_area = first_float(area, r"Combinational\s+area:\s*([0-9.eE+-]+)")
    seq_area = first_float(area, r"Noncombinational\s+area:\s*([0-9.eE+-]+)")
    dynamic_mw, leakage_uw, total_mw = parse_power(power)
    bad = "unmapped" in check_design.lower() or not timing or not area
    status = "PASS" if not bad and slack_ns is not None and slack_ns >= 0.0 else "FAIL"
    return {
        "node": meta.get("node", "unknown"),
        "label": meta.get("label", "unknown"),
        "target_mhz": meta.get("target_mhz", ""),
        "period_ns": meta.get("period_ns", ""),
        "status": status,
        "critical_path_ns": number(path_ns),
        "setup_slack_ns": number(slack_ns),
        "fmax_est_mhz": number(1000.0 / path_ns if path_ns and path_ns > 0 else None),
        "cell_area_lib_units": number(cell_area),
        "comb_area_lib_units": number(comb_area),
        "seq_area_lib_units": number(seq_area),
        "dynamic_power_mw": number(dynamic_mw),
        "leakage_power_uw": number(leakage_uw),
        "total_power_mw": number(total_mw),
        "power_basis": meta.get("power_basis", "unknown"),
        "critical_startpoint": first_text(timing, r"Startpoint:\s*(.+)"),
        "critical_endpoint": first_text(timing, r"Endpoint:\s*(.+)"),
        "run_dir": str(run_dir),
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--run-dir", type=Path)
    group.add_argument("--matrix-dir", type=Path)
    args = parser.parse_args()
    if args.run_dir:
        row = parse_run(args.run_dir)
        output = args.run_dir / "summary.csv"
        write_csv(output, [row])
        print(f"ASIC_PPA_SUMMARY status={row['status']} file={output}")
        return 0 if row["status"] == "PASS" else 1
    runs = sorted(path for path in args.matrix_dir.iterdir() if path.is_dir())
    rows = [parse_run(path) for path in runs]
    output = args.matrix_dir / "summary.csv"
    write_csv(output, rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"ASIC_PPA_MATRIX total={len(rows)} passed={passed} file={output}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
