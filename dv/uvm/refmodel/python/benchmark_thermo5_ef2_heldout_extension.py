#!/usr/bin/env python3
"""Run a focused, longer held-out EF2/256-QAM benchmark.

This deliberately avoids the development sweeps in
``benchmark_thermo5_ef2_robust.py``.  It evaluates a fixed candidate on an
independent seed set and reports finite-sample Wilson confidence bounds for
the uncoded bit-error rate.  The result is a software link-model statistic,
not a GT or board-level BER measurement.
"""

import argparse
import json
import math
from pathlib import Path

from benchmark_thermo5_ef2_robust import (
    _map_groups,
    _run_width_group,
    _summary,
)
from benchmark_thermo5_tid_receiver import (
    MAX_INPUT_DRIVE,
    RX_FIR_TAPS,
    make_256qam_ofdm,
)


DEFAULT_SEEDS = (1117, 1123, 1129, 1151, 1153, 1163)
WILSON_Z_95 = 1.959963984540054


def _wilson_interval(errors, trials, z=WILSON_Z_95):
    if trials <= 0 or errors < 0 or errors > trials:
        raise ValueError("Wilson interval requires 0 <= errors <= trials")
    p = errors / trials
    z2 = z * z
    denominator = 1.0 + z2 / trials
    center = (p + z2 / (2.0 * trials)) / denominator
    radius = z * math.sqrt(p * (1.0 - p) / trials +
                           z2 / (4.0 * trials * trials)) / denominator
    return [max(0.0, center - radius), min(1.0, center + radius)]


def run(seeds=DEFAULT_SEEDS, symbols=24, rms_drive=0.08, step=5120,
        state_width=20, jobs=4, fir_taps=RX_FIR_TAPS):
    if not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("seed list must be non-empty and contain no duplicates")
    if any(seed in (701, 709, 719, 809, 811, 821, 101, 307, 503)
           for seed in seeds):
        raise ValueError("extension seeds must be disjoint from prior sets")
    if symbols < 1 or jobs < 1 or state_width < 18 or state_width > 20:
        raise ValueError("invalid symbols, jobs, or state width")

    preflight = []
    for seed in seeds:
        stimulus = make_256qam_ofdm(seed, symbols=symbols,
                                    rms_drive=rms_drive)
        peak = stimulus["input_peak"]
        if peak > MAX_INPUT_DRIVE + 1e-12:
            raise ValueError(
                "seed %d peak %.6f exceeds input-drive limit %.6f; "
                "choose a lower RMS level" % (seed, peak, MAX_INPUT_DRIVE))
        preflight.append({"seed": seed, "input_peak": peak,
                          "input_rms": stimulus["input_rms"]})

    tasks = [(seed, symbols, rms_drive, step, state_width, fir_taps,
              "heldout_extension") for seed in seeds]
    records = _map_groups(_run_width_group, tasks, jobs)
    summary = _summary(records, ("state_width_bits", "step",
                                 "rms_drive_target"))[0]
    summary["ber_wilson_95pct_interval"] = _wilson_interval(
        summary["uncoded_bit_errors_natural_binary"],
        summary["uncoded_bit_count"])
    return {
        "benchmark": "thermo5_ef2_independent_heldout_extension",
        "scope": "fixed-point software link model; not GT/board/production BER",
        "configuration": {
            "seeds": list(seeds),
            "symbols_per_seed": symbols,
            "step": step,
            "state_width_bits": state_width,
            "rms_drive_target": rms_drive,
            "rx_fir_taps": fir_taps,
            "input_peak_limit": MAX_INPUT_DRIVE,
        },
        "input_preflight": preflight,
        "aggregate": summary,
        "per_seed": [
            {
                "seed": row["seed"],
                "uncoded_bit_count": 8 * row["digital_metrics"]["qam_symbols"],
                "uncoded_bit_errors": row["digital_metrics"][
                    "uncoded_bit_errors_natural_binary"],
                "uncoded_ber": row["digital_metrics"][
                    "uncoded_bit_errors_natural_binary"] /
                    max(1, 8 * row["digital_metrics"]["qam_symbols"]),
                "evm_percent": row["digital_metrics"]["evm_percent"],
                "sndr_db": row["digital_metrics"]["sndr_db"],
                "input_saturation_samples": row["model_diagnostics"][
                    "input_saturation_samples"],
                "state_saturation_samples": row.get(
                    "state_saturation_samples", 0),
                "max_abs_error_state": row["model_diagnostics"][
                    "max_abs_error_state"],
                "max_abs_quantizer_input": row["model_diagnostics"][
                    "max_abs_quantizer_input"],
            }
            for row in records
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", default=",".join(map(str, DEFAULT_SEEDS)))
    parser.add_argument("--symbols", type=int, default=24)
    parser.add_argument("--rms-drive", type=float, default=0.08)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--state-width", type=int, default=20)
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--rx-fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()
    try:
        seeds = tuple(int(item) for item in args.seeds.split(",") if item)
    except ValueError as error:
        parser.error(str(error))
    result = run(seeds, args.symbols, args.rms_drive, args.step,
                 args.state_width, args.jobs, args.rx_fir_taps)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "benchmark": result["benchmark"],
        "configuration": result["configuration"],
        "aggregate": result["aggregate"],
        "json": str(args.json),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
