#!/usr/bin/env python3
"""Held-out 256-QAM robustness sweep for the fixed-point thermo5 EF2 model.

The script keeps the scalar-in-time EF2 recurrence and its 2/-1 feedback
coefficients unchanged. It sweeps STEP and input RMS on development seeds,
checks reduced state widths, evaluates PAPR clipping/backoff jointly, and
confirms the selected configurations on disjoint held-out seeds.
"""

import argparse
import json
import math
import statistics
from multiprocessing import Pool
from pathlib import Path

from benchmark_thermo5_step_ntf import _run_case
from benchmark_thermo5_tid_receiver import (
    MAX_INPUT_DRIVE,
    RX_FIR_TAPS,
    _expand_iq_x4,
    make_256qam_ofdm,
)


DEV_SEEDS = (701, 709, 719)
HELDOUT_SEEDS = (809, 811, 821)
STEP_GRID = (4864, 4992, 5120, 5248, 5376)
RMS_GRID = (0.06, 0.08, 0.10)
STATE_WIDTHS = (18, 19, 20)
BACKOFF_GRID_DB = (0, 3, 6)
PAPR_LIMITS_DB = (None, 7.0, 9.0)
FRAME_SYMBOLS = 12
FIXED_MODE = "ef_order2_fixed"
ANALOG_PROFILES = ("nominal", "stress")


def _rms(values):
    return math.sqrt(sum(abs(value) ** 2 for value in values) /
                     max(1, len(values)))


def _variant(stimulus, backoff_db=0.0, papr_limit_db=None):
    """Scale and radially clip a Q1.15 waveform before x4 interpolation."""
    data_start = stimulus["data_start"]
    data_end = data_start + stimulus["data_samples"]
    original = stimulus["source_iq"]
    samples = [complex(i / 32768.0, q / 32768.0)
               for i, q in original[data_start:data_end]]
    backoff_gain = 10.0 ** (-float(backoff_db) / 20.0)
    scaled = [value * backoff_gain for value in samples]
    rms_before_clip = _rms(scaled)
    limit = (None if papr_limit_db is None else
             rms_before_clip * 10.0 ** (float(papr_limit_db) / 20.0))
    clipped_count = 0
    adjusted = []
    for value in scaled:
        magnitude = abs(value)
        if limit is not None and magnitude > limit:
            value *= limit / magnitude
            clipped_count += 1
        i = max(-32768, min(32767, int(round(value.real * 32768.0))))
        q = max(-32768, min(32767, int(round(value.imag * 32768.0))))
        adjusted.append((i, q))

    source_iq = list(original)
    source_iq[data_start:data_end] = adjusted
    result = dict(stimulus)
    result["source_iq"] = source_iq
    result["input_rms"] = _rms(
        [complex(i / 32768.0, q / 32768.0) for i, q in adjusted])
    result["input_peak"] = max(
        (abs(complex(i / 32768.0, q / 32768.0)) for i, q in adjusted),
        default=0.0)
    result["input_papr_db"] = 20.0 * math.log10(
        max(result["input_peak"], 1e-30) / max(result["input_rms"], 1e-30))
    result["input_clip_samples"] = clipped_count
    result["backoff_db"] = float(backoff_db)
    result["papr_limit_db"] = papr_limit_db
    if result["input_peak"] > MAX_INPUT_DRIVE + 1e-12:
        raise ValueError("seed %d exceeds input peak after backoff/clipping: %.6f" %
                         (stimulus["seed"], result["input_peak"]))
    return result


def _attach_parameters(record, parameters):
    record["sweep_parameters"] = dict(parameters)
    record["input_papr_db"] = record.get(
        "input_papr_db", parameters.get("input_papr_db"))
    record["input_clip_samples"] = parameters.get("input_clip_samples", 0)
    return record


def _run_drive_group(task):
    seed, symbols, rms_drive, steps, fir_taps = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    interpolated_i, interpolated_q = _expand_iq_x4(
        stimulus["source_iq"], "centered_cubic")
    output = []
    for step in steps:
        record = _run_case(
            stimulus, interpolated_i, interpolated_q, FIXED_MODE, step,
            fir_taps, (), state_width=20)
        output.append(_attach_parameters(record, {
            "phase": "step_input_development",
            "step": step,
            "state_width_bits": 20,
            "rms_drive_target": rms_drive,
            "backoff_db": 0.0,
            "papr_limit_db": None,
            "input_papr_db": 20.0 * math.log10(
                stimulus["input_peak"] / max(stimulus["input_rms"], 1e-30)),
            "input_clip_samples": 0,
        }))
    return output


def _run_width_group(task):
    seed, symbols, rms_drive, step, state_width, fir_taps, phase = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    interpolated_i, interpolated_q = _expand_iq_x4(
        stimulus["source_iq"], "centered_cubic")
    record = _run_case(
        stimulus, interpolated_i, interpolated_q, FIXED_MODE, step,
        fir_taps, (), state_width=state_width)
    return _attach_parameters(record, {
        "phase": phase,
        "step": step,
        "state_width_bits": state_width,
        "rms_drive_target": rms_drive,
        "backoff_db": 0.0,
        "papr_limit_db": None,
        "input_papr_db": 20.0 * math.log10(
            stimulus["input_peak"] / max(stimulus["input_rms"], 1e-30)),
        "input_clip_samples": 0,
    })


def _run_joint_group(task):
    seed, symbols, rms_drive, step, fir_taps = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    scenarios = [(backoff, limit)
                 for backoff in BACKOFF_GRID_DB
                 for limit in PAPR_LIMITS_DB]
    # Run the reference (0-dB backoff, no clipping) first. Its modeled DPA
    # output RMS anchors the declared nominal/stress output-power assumptions.
    scenarios.sort(key=lambda pair: (pair[0] != 0 or pair[1] is not None,
                                     pair[0], 99.0 if pair[1] is None else pair[1]))
    reference_output_rms = None
    output = []
    for backoff, limit in scenarios:
        variant = _variant(stimulus, backoff, limit)
        interpolated_i, interpolated_q = _expand_iq_x4(
            variant["source_iq"], "centered_cubic")
        record = _run_case(
            variant, interpolated_i, interpolated_q, FIXED_MODE, step,
            fir_taps, ANALOG_PROFILES, state_width=20,
            analog_reference_output_rms=reference_output_rms)
        if reference_output_rms is None:
            reference_output_rms = {
                item["profile"]: item["dpa_output_rms_normalized"]
                for item in record["analog_profiles"]
            }
        parameters = {
            "phase": "papr_backoff_development",
            "step": step,
            "state_width_bits": 20,
            "rms_drive_target": rms_drive,
            "backoff_db": backoff,
            "papr_limit_db": limit,
            "input_papr_db": variant["input_papr_db"],
            "input_clip_samples": variant["input_clip_samples"],
        }
        output.append(_attach_parameters(record, parameters))
    return output


def _summary(records, dimensions, metrics="digital_metrics"):
    groups = {}
    for record in records:
        params = record["sweep_parameters"]
        key = tuple(params.get(name) for name in dimensions)
        groups.setdefault(key, []).append(record)
    result = []
    for key, rows in groups.items():
        metric_rows = [row[metrics] for row in rows]
        total_bits = sum(8 * row["qam_symbols"] for row in metric_rows)
        bit_errors = sum(row["uncoded_bit_errors_natural_binary"]
                         for row in metric_rows)
        per_seed_ber = [
            row[metrics]["uncoded_bit_errors_natural_binary"] /
            max(1, 8 * row[metrics]["qam_symbols"])
            for row in rows
        ]
        evms = [row["evm_percent"] for row in metric_rows]
        entry = {
            "configuration": dict(zip(dimensions, key)),
            "seed_count": len(rows),
            "qam_symbols": sum(row["qam_symbols"] for row in metric_rows),
            "uncoded_bit_count": total_bits,
            "uncoded_bit_errors_natural_binary": bit_errors,
            "uncoded_ber_natural_binary": bit_errors / max(1, total_bits),
            "worst_seed_ber": max(per_seed_ber),
            "all_seed_zero_bit_errors": bit_errors == 0,
            "zero_error_95pct_ber_upper_bound": (
                -math.log(0.05) / max(1, total_bits) if bit_errors == 0 else None),
            "mean_evm_percent": statistics.mean(evms),
            "worst_seed_evm_percent": max(evms),
            "mean_sndr_db": statistics.mean(row["sndr_db"]
                                             for row in metric_rows),
            "symbol_errors": sum(row["symbol_errors"] for row in metric_rows),
            "state_saturation_samples": sum(
                row.get("state_saturation_samples") or 0 for row in rows),
            "input_saturation_samples": sum(
                row["model_diagnostics"]["input_saturation_samples"]
                for row in rows),
            "max_abs_error_state": max(
                row["model_diagnostics"]["max_abs_error_state"] for row in rows),
            "max_abs_quantizer_input": max(
                row["model_diagnostics"]["max_abs_quantizer_input"]
                for row in rows),
            "all_seed_state_headroom_pass": all(
                row["ef_q4_15_observed_headroom_pass"] for row in rows),
        }
        result.append(entry)
    result.sort(key=lambda item: (
        item["uncoded_ber_natural_binary"], item["worst_seed_ber"],
        item["worst_seed_evm_percent"],
    ))
    return result


def _add_analog_summary(entries, records, profile_name):
    by_key = {}
    metric_name = "metrics_after_thermal_noise"
    for record in records:
        params = record["sweep_parameters"]
        key = (params["backoff_db"], params["papr_limit_db"])
        profile = next(item for item in record["analog_profiles"]
                       if item["profile"] == profile_name)
        by_key.setdefault(key, []).append((record, profile))
    for entry in entries:
        config = entry["configuration"]
        key = (config["backoff_db"], config["papr_limit_db"])
        rows = by_key[key]
        metrics = [profile[metric_name] for _, profile in rows]
        bits = sum(8 * item["qam_symbols"] for item in metrics)
        errors = sum(item["uncoded_bit_errors_natural_binary"]
                     for item in metrics)
        entry[profile_name + "_ber_after_output_chain"] = errors / max(1, bits)
        entry[profile_name + "_bit_errors_after_output_chain"] = errors
        entry[profile_name + "_worst_seed_ber_after_output_chain"] = max(
            item[metric_name]["uncoded_bit_errors_natural_binary"] /
            max(1, 8 * item[metric_name]["qam_symbols"])
            for _, item in rows)
        entry[profile_name + "_mean_evm_after_output_chain_percent"] = (
            statistics.mean(item["evm_percent"] for item in metrics))
        entry[profile_name + "_modeled_output_power_dbm"] = statistics.mean(
            profile["modeled_signal_power_dbm"] for _, profile in rows)


def _map_groups(worker, tasks, jobs):
    if jobs <= 1:
        return [worker(task) for task in tasks]
    with Pool(processes=jobs) as pool:
        return pool.map(worker, tasks)


def run(seeds=DEV_SEEDS, heldout_seeds=HELDOUT_SEEDS, symbols=FRAME_SYMBOLS,
        steps=STEP_GRID, rms_levels=RMS_GRID, state_widths=STATE_WIDTHS,
        jobs=1, fir_taps=RX_FIR_TAPS):
    if not seeds or not heldout_seeds:
        raise ValueError("development and held-out seed sets must be non-empty")
    if set(seeds) & set(heldout_seeds):
        raise ValueError("development and held-out seeds must be disjoint")
    if any(seed in (101, 307, 503) for seed in tuple(seeds) + tuple(heldout_seeds)):
        raise ValueError("do not reuse the prior EF2 development seeds")
    if symbols < 1 or jobs < 1:
        raise ValueError("symbols and jobs must be positive")
    if any(width < 18 or width > 20 for width in state_widths):
        raise ValueError("state-width experiment accepts 18, 19, or 20 bits")

    drive_tasks = [(seed, symbols, rms, tuple(steps), fir_taps)
                   for seed in seeds for rms in rms_levels]
    drive_groups = _map_groups(_run_drive_group, drive_tasks, jobs)
    drive_records = [record for group in drive_groups for record in group]
    drive_summary = _summary(
        drive_records, ("rms_drive_target", "step"))
    winner = drive_summary[0]["configuration"]
    winner_rms = float(winner["rms_drive_target"])
    winner_step = int(winner["step"])

    # Re-evaluate the incumbent width and the narrower widths on identical
    # development inputs; this is an experiment knob only, not a width change
    # to the RTL candidate.
    width_records = []
    width_tasks = [(seed, symbols, winner_rms, winner_step, width, fir_taps,
                    "state_width_development")
                   for width in state_widths for seed in seeds]
    width_records.extend(_map_groups(_run_width_group, width_tasks, jobs))
    width_summary = _summary(width_records, ("state_width_bits",))

    # Pick a STEP at the common 0.10 RMS operating point for the joint
    # clipping/backoff sweep, independent of a lower-RMS winner above.
    reference_rms = min(rms_levels, key=lambda value: abs(value - 0.10))
    at_reference_level = _summary([
        row for row in drive_records
        if abs(row["sweep_parameters"]["rms_drive_target"] -
               reference_rms) < 1e-12
    ], ("step",))
    joint_step = int(at_reference_level[0]["configuration"]["step"])
    joint_tasks = [(seed, symbols, reference_rms, joint_step, fir_taps)
                   for seed in seeds]
    joint_groups = _map_groups(_run_joint_group, joint_tasks, jobs)
    joint_records = [record for group in joint_groups for record in group]
    joint_summary = _summary(
        joint_records, ("backoff_db", "papr_limit_db"))
    for profile in ANALOG_PROFILES:
        _add_analog_summary(joint_summary, joint_records, profile)
    for entry in joint_summary:
        entry["worst_profile_ber_after_output_chain"] = max(
            entry[profile + "_ber_after_output_chain"]
            for profile in ANALOG_PROFILES)
    joint_summary.sort(key=lambda item: (
        item["worst_profile_ber_after_output_chain"],
        item["uncoded_ber_natural_binary"],
        item["nominal_modeled_output_power_dbm"],
        item["worst_seed_evm_percent"],
    ))
    joint_winner = joint_summary[0]["configuration"]

    # Final, disjoint held-out confirmation: best STEP/input point, all state
    # widths at that point, plus no-CFR and selected CFR/backoff candidates.
    heldout_tasks = [(seed, symbols, winner_rms, winner_step, 20, fir_taps,
                      "heldout_step_input") for seed in heldout_seeds]
    heldout_step_records = _map_groups(_run_width_group, heldout_tasks, jobs)
    heldout_width_tasks = [
        (seed, symbols, winner_rms, winner_step, width, fir_taps,
         "heldout_state_width")
        for width in state_widths if width != 20 for seed in heldout_seeds
    ]
    heldout_width_records = _map_groups(
        _run_width_group, heldout_width_tasks, jobs)

    heldout_joint_records = []
    baseline_scenario = {"backoff_db": 0, "papr_limit_db": None}
    heldout_scenarios = [baseline_scenario]
    if joint_winner != baseline_scenario:
        heldout_scenarios.append(joint_winner)
    for scenario in heldout_scenarios:
        tasks = [(seed, symbols, reference_rms, joint_step, fir_taps, scenario)
                 for seed in heldout_seeds]
        # The held-out no-CFR baseline is the output-power reference for each
        # seed. Run it first, then feed its measured DPA RMS to the winner.
        if scenario == {"backoff_db": 0, "papr_limit_db": None}:
            baseline_groups = _map_groups(_run_joint_single_group, tasks, jobs)
            heldout_joint_records.extend(
                record for group in baseline_groups for record in group)
            reference_by_seed = {}
            for group in baseline_groups:
                baseline = group[0]
                reference_by_seed[baseline["seed"]] = {
                    item["profile"]: item["dpa_output_rms_normalized"]
                    for item in baseline["analog_profiles"]
                }
        else:
            winner_tasks = [task + (reference_by_seed[task[0]],)
                            for task in tasks]
            winner_groups = _map_groups(
                _run_joint_single_group_with_reference, winner_tasks, jobs)
            heldout_joint_records.extend(
                record for group in winner_groups for record in group)

    heldout_step_summary = _summary(
        heldout_step_records, ("rms_drive_target", "step"))
    heldout_width_summary = _summary(
        heldout_step_records + heldout_width_records, ("state_width_bits",))
    heldout_joint_summary = _summary(
        heldout_joint_records, ("backoff_db", "papr_limit_db"))
    for profile in ANALOG_PROFILES:
        _add_analog_summary(heldout_joint_summary, heldout_joint_records, profile)

    return {
        "benchmark": "thermo5_ef2_long_frame_heldout_qam256_ber",
        "model": {
            "tidsm": "fixed-point EF2, sample-serial within every accepted 32-sample word",
            "recurrence": "u=x+2e1-e2; y=sign(u); e=sat(u-y)",
            "feedback_coefficients": [2, -1],
            "quantizer": "unchanged bipolar sign quantizer with negative decision at zero",
            "interpolation": "centered cubic [-1,9,9,-1]/16 in both x2 stages",
            "papr_location": "radial sample clipping before interpolation and EF2",
            "analog_power_scaling": "DPA/output-network RMS ratio to each seed's unclipped 0-dB baseline",
        },
        "frame": {
            "qam_order": 256,
            "fft": 4096,
            "cyclic_prefix": 512,
            "active_carriers": 584,
            "symbols_per_seed": symbols,
            "qam_decisions_per_seed": symbols * 584,
            "uncoded_bits_per_seed": symbols * 584 * 8,
            "input_peak_limit": MAX_INPUT_DRIVE,
        },
        "development_seeds": list(seeds),
        "heldout_seeds": list(heldout_seeds),
        "sweep_grid": {
            "step": list(steps),
            "rms_drive": list(rms_levels),
            "state_width_bits": list(state_widths),
            "backoff_db": list(BACKOFF_GRID_DB),
            "papr_limit_db": list(PAPR_LIMITS_DB),
        },
        "selection_rule": {
            "step_input_and_state_width": "minimum aggregate natural-binary uncoded BER; ties use worst-seed BER, then worst-seed EVM",
            "papr_backoff": "minimum worst-of-nominal-and-stress output-chain BER; ties use aggregate digital BER, nominal modeled output power, then EVM",
        },
        "development_winners": {
            "step_input": winner,
            "step_at_0p10_rms_for_papr_backoff": joint_step,
            "papr_backoff_reference_rms": reference_rms,
            "joint_papr_backoff": joint_winner,
            "step_input_summary": drive_summary,
            "state_width_summary": width_summary,
            "papr_backoff_summary": joint_summary,
        },
        "heldout_confirmation": {
            "step_input_records": heldout_step_records,
            "step_input_summary": heldout_step_summary,
            "state_width_records": heldout_width_records,
            "state_width_summary": heldout_width_summary,
            "papr_backoff_records": heldout_joint_records,
            "papr_backoff_summary": heldout_joint_summary,
        },
        "records": drive_records + width_records + joint_records,
    }


def _run_joint_single_group(task):
    seed, symbols, rms_drive, step, fir_taps, scenario = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    variant = _variant(stimulus, scenario["backoff_db"],
                       scenario["papr_limit_db"])
    interpolated_i, interpolated_q = _expand_iq_x4(
        variant["source_iq"], "centered_cubic")
    record = _run_case(
        variant, interpolated_i, interpolated_q, FIXED_MODE, step,
        fir_taps, ANALOG_PROFILES, state_width=20)
    return [_attach_parameters(record, {
        "phase": "heldout_papr_backoff",
        "step": step,
        "state_width_bits": 20,
        "rms_drive_target": rms_drive,
        "backoff_db": scenario["backoff_db"],
        "papr_limit_db": scenario["papr_limit_db"],
        "input_papr_db": variant["input_papr_db"],
        "input_clip_samples": variant["input_clip_samples"],
    })]


def _run_joint_single_group_with_reference(task):
    seed, symbols, rms_drive, step, fir_taps, scenario, reference = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    variant = _variant(stimulus, scenario["backoff_db"],
                       scenario["papr_limit_db"])
    interpolated_i, interpolated_q = _expand_iq_x4(
        variant["source_iq"], "centered_cubic")
    record = _run_case(
        variant, interpolated_i, interpolated_q, FIXED_MODE, step,
        fir_taps, ANALOG_PROFILES, state_width=20,
        analog_reference_output_rms=reference)
    return [_attach_parameters(record, {
        "phase": "heldout_papr_backoff",
        "step": step,
        "state_width_bits": 20,
        "rms_drive_target": rms_drive,
        "backoff_db": scenario["backoff_db"],
        "papr_limit_db": scenario["papr_limit_db"],
        "input_papr_db": variant["input_papr_db"],
        "input_clip_samples": variant["input_clip_samples"],
    })]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dev-seeds", default=",".join(map(str, DEV_SEEDS)))
    parser.add_argument("--heldout-seeds",
                        default=",".join(map(str, HELDOUT_SEEDS)))
    parser.add_argument("--symbols", type=int, default=FRAME_SYMBOLS)
    parser.add_argument("--steps", default=",".join(map(str, STEP_GRID)))
    parser.add_argument("--rms-levels", default=",".join(map(str, RMS_GRID)))
    parser.add_argument("--state-widths",
                        default=",".join(map(str, STATE_WIDTHS)))
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--rx-fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    try:
        seeds = tuple(int(item) for item in args.dev_seeds.split(",") if item)
        heldout_seeds = tuple(int(item) for item in
                              args.heldout_seeds.split(",") if item)
        steps = tuple(int(item) for item in args.steps.split(",") if item)
        rms_levels = tuple(float(item) for item in
                           args.rms_levels.split(",") if item)
        state_widths = tuple(int(item) for item in
                             args.state_widths.split(",") if item)
    except ValueError as error:
        parser.error(str(error))
    result = run(seeds, heldout_seeds, args.symbols, steps, rms_levels,
                 state_widths, args.jobs, args.rx_fir_taps)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "benchmark": result["benchmark"],
        "development_winners": result["development_winners"],
        "heldout_confirmation": {
            "step_input_summary": result["heldout_confirmation"][
                "step_input_summary"],
            "state_width_summary": result["heldout_confirmation"][
                "state_width_summary"],
            "papr_backoff_summary": result["heldout_confirmation"][
                "papr_backoff_summary"],
        },
        "json": str(args.json) if args.json else None,
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
