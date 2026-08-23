#!/usr/bin/env python3
"""Compare a Vivado ILA CSV capture with the frozen board golden RF trace."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path


def parse_value(text: str) -> int:
    value = text.strip().replace("_", "")
    match = re.fullmatch(r"(?:\d+)?'([bBhHdD])([0-9a-fA-FxXzZ]+)", value)
    if match:
        base = match.group(1).lower()
        digits = match.group(2)
        if any(char in digits.lower() for char in "xz"):
            raise ValueError(f"unknown ILA value: {text}")
        return int(digits, {"b": 2, "h": 16, "d": 10}[base])
    if value.lower().startswith("0x"):
        return int(value, 0)
    if any(char in value.lower() for char in "xz"):
        raise ValueError(f"unknown ILA value: {text}")
    return int(value, 2) if set(value) <= {"0", "1"} else int(value)


def select_column(names: list[str], preferred: str, fallback: str) -> str:
    for name in names:
        if preferred in name.lower():
            return name
    for name in names:
        if fallback in name.lower():
            return name
    raise KeyError(f"ILA CSV has no {preferred} or {fallback} column: {names}")


def signed16(value: int) -> int:
    value &= 0xFFFF
    return value - 0x10000 if value & 0x8000 else value


def main() -> int:
    root = Path(__file__).resolve().parents[3]
    parser = argparse.ArgumentParser()
    parser.add_argument("capture", type=Path)
    parser.add_argument("--golden-dir", type=Path,
                        default=root / "fpga" / "zu15eg" / "out" / "ila_golden_memory_pkg0")
    parser.add_argument("--report", type=Path, default=None)
    args = parser.parse_args()

    with (args.golden_dir / "expected_rf.csv").open(newline="", encoding="ascii") as handle:
        expected = list(csv.DictReader(handle))
    with args.capture.open(newline="", encoding="utf-8-sig") as handle:
        captured = list(csv.DictReader(handle))
    if not captured:
        raise RuntimeError("ILA CSV has no data rows")

    names = list(captured[0])
    valid_name = select_column(names, "rf_valid", "probe4")
    bit_name = select_column(names, "rf_bit", "probe5")
    signed_name = select_column(names, "rf_signed", "probe6")
    phase_name = select_column(names, "phase", "probe8")
    rf_rows = [row for row in captured if parse_value(row[valid_name]) == 1]
    if len(rf_rows) < len(expected):
        raise RuntimeError(f"ILA has {len(rf_rows)} rf_valid samples; expected at least {len(expected)}")

    mismatches: list[dict[str, object]] = []
    for index, (want, got) in enumerate(zip(expected, rf_rows)):
        actual = {
            "rf_bit": parse_value(got[bit_name]),
            "rf_signed": signed16(parse_value(got[signed_name])),
            "phase": parse_value(got[phase_name]),
        }
        desired = {name: int(want[name]) for name in actual}
        if actual != desired:
            mismatches.append({"n": index, "expected": desired, "actual": actual})
            if len(mismatches) == 20:
                break

    report = {
        "capture": str(args.capture),
        "golden_dir": str(args.golden_dir),
        "expected_rf_samples": len(expected),
        "captured_rf_samples": len(rf_rows),
        "mismatch_count": len(mismatches),
        "first_mismatches": mismatches,
    }
    report_path = args.report or args.capture.with_suffix(".compare.json")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="ascii")
    if mismatches:
        print(f"FAIL ILA golden compare mismatches={len(mismatches)} report={report_path}")
        return 1
    print(f"PASS ILA golden compare rf={len(expected)} report={report_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
