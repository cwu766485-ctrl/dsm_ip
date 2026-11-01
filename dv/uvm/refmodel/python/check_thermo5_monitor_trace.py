#!/usr/bin/env python3
"""Compare a VCS/UVM monitor JSONL trace against the independent Python oracle."""

import argparse
from pathlib import Path
import sys

from dsm_refmodel.monitor_trace import run_monitor_trace


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--tidsm-order", type=int, choices=(1, 2), default=2)
    parser.add_argument("--max-taps", type=int, choices=(1, 2, 3, 4), default=1)
    parser.add_argument(
        "--allow-underflow", action="store_true",
        help="report but do not fail on observed underflow (use only for classified fault runs)")
    args = parser.parse_args()
    results = run_monitor_trace(args.trace, step=args.step,
                                tidsm_order=args.tidsm_order,
                                max_taps=args.max_taps)
    total_words = sum(result.compared_words for result in results)
    total_underflows = sum(result.underflow_events for result in results)
    for result in results:
        print("epoch=%d data=%s compared_words=%d applied_config_frames=%s underflow_events=%d" % (
            result.epoch, "PASS" if result.passed else "FAIL",
            result.compared_words, list(result.applied_config_frames),
            result.underflow_events))
    print("TRACE_ORACLE=%s total_words=%d underflow_events=%d" % (
        "PASS" if all(result.passed for result in results) else "FAIL",
        total_words, total_underflows))
    if not all(result.passed for result in results):
        return 1
    if total_underflows and not args.allow_underflow:
        print("TRACE_CLASSIFICATION=FAIL_UNEXPECTED_UNDERFLOW", file=sys.stderr)
        return 2
    if total_underflows:
        print("TRACE_CLASSIFICATION=DATA_PASS_UNDERFLOW_REQUIRES_EXTERNAL_CLASSIFICATION")
    else:
        print("TRACE_CLASSIFICATION=PASS_NO_UNDERFLOW")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
