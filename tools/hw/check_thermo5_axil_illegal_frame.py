#!/usr/bin/env python3
"""Fail-closed checker for the expected AXI-Lite illegal-frame regression."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


class ExpectedNegativeCheckError(ValueError):
    pass


EXPECTED_EVENTS = (
    (
        "cdc_frame_alignment",
        re.compile(
            r'^"rtl/axis/dsm_axis14_to_core8_cdc\.sv", 262: '
            r'thermo5_sku_uvm_tb\.dut\.u_cdc\.unnamed\$\$_1: '
            r"started at \d+ps failed at \d+ps$",
            re.MULTILINE,
        ),
        "DSM frame_start was not aligned to a 56-sample boundary",
    ),
    (
        "centered_cubic_stage1_frame_tail",
        re.compile(
            r'^"rtl/interp/dsm_interp_x2_centered_cubic_vector\.sv", 310: '
            r'thermo5_sku_uvm_tb\.dut\.u_frontend\.g_interp1_centered\.'
            r'u_interp_1\.unnamed\$\$_1: started at \d+ps failed at \d+ps$',
            re.MULTILINE,
        ),
        "centered cubic frame-end vector was followed by same-frame data",
    ),
    (
        "centered_cubic_stage2_frame_tail",
        re.compile(
            r'^"rtl/interp/dsm_interp_x2_centered_cubic_vector\.sv", 310: '
            r'thermo5_sku_uvm_tb\.dut\.u_frontend\.g_interp2_centered\.'
            r'u_interp_2\.unnamed\$\$_1: started at \d+ps failed at \d+ps$',
            re.MULTILINE,
        ),
        "centered cubic frame-end vector was followed by same-frame data",
    ),
)


def audit_log_text(text: str) -> dict[str, object]:
    """Validate exact assertion identity/count and public reset recovery."""
    found: dict[str, int] = {}
    for name, event_re, _message in EXPECTED_EVENTS:
        events = event_re.findall(text)
        if len(events) != 1:
            raise ExpectedNegativeCheckError(
                f"{name}: expected one matching RTL event; found {len(events)}"
            )
        found[name] = len(events)

    cdc_message = EXPECTED_EVENTS[0][2]
    cubic_message = EXPECTED_EVENTS[1][2]
    if text.count(cdc_message) != 1 or text.count(cubic_message) != 2:
        raise ExpectedNegativeCheckError(
            "expected CDC assertion message once and centered-cubic frame-tail "
            f"message twice; found {text.count(cdc_message)} and "
            f"{text.count(cubic_message)}"
        )

    rtl_error_lines = re.findall(r'^Error: "rtl/', text, flags=re.MULTILINE)
    if len(rtl_error_lines) != len(EXPECTED_EVENTS):
        raise ExpectedNegativeCheckError(
            f"expected exactly {len(EXPECTED_EVENTS)} RTL assertion Error lines; "
            f"found {len(rtl_error_lines)}"
        )

    required_markers = (
        "THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED",
        "THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS sticky error cleared by public reset",
    )
    for marker in required_markers:
        if text.count(marker) != 1:
            raise ExpectedNegativeCheckError(
                f"expected exactly one recovery marker {marker!r}; "
                f"found {text.count(marker)}"
            )

    for severity in ("WARNING", "ERROR", "FATAL"):
        match = re.search(
            rf"^UVM_{severity}\s*:\s*(\d+)\s*$", text, flags=re.MULTILINE
        )
        if not match or int(match.group(1)) != 0:
            value = match.group(1) if match else "missing"
            raise ExpectedNegativeCheckError(
                f"UVM_{severity} must be zero; found {value}"
            )

    return {
        "status": "PASS",
        "expected_rtl_assertion_failures": found,
        "unexpected_rtl_assertion_error_lines": 0,
        "public_reset_recovery": "PASS",
        "uvm_warning_error_fatal": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="VCS log from the AXI-Lite negative test")
    args = parser.parse_args()
    try:
        result = audit_log_text(args.log.read_text(encoding="utf-8", errors="replace"))
    except (OSError, ExpectedNegativeCheckError) as exc:
        print(f"THERMO5_AXIL_ILLEGAL_FRAME_CHECK_FAIL: {exc}", file=sys.stderr)
        return 1
    print("THERMO5_AXIL_ILLEGAL_FRAME_CHECK_PASS")
    for name, count in result["expected_rtl_assertion_failures"].items():
        print(f"  {name}: {count}")
    print("  public reset recovery: PASS")
    print("  UVM warning/error/fatal: 0/0/0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
