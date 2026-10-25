#!/usr/bin/env python3
"""Sweep thermo5 threshold spacing and TIDSM error-feedback order in Python.

This is a 256-QAM communications screen. The current first-order path is
bit-aligned to its scalar RTL recurrence. Floating EF candidates are
architecture studies; ``ef_order2_fixed`` is the integer model for the
optional second-order RTL.
"""

import argparse
import csv
import json
import math
import random
import statistics
from pathlib import Path

from benchmark_thermo5_tid_receiver import (
    MAX_INPUT_DRIVE,
    OCCUPIED_BW_HZ,
    PA_OUTPUT_PROFILES,
    RX_FIR_TAPS,
    TID_LATENCY_AFTER_FRONTEND_TRIM,
    _expand_iq_x4,
    demodulate_metrics,
    make_256qam_ofdm,
    receive_filter_decimate,
    reconstruct_baseband_7g,
)
from dsm_refmodel.link_models import (
    BehavioralDPA,
    add_thermal_noise,
    apply_complex_fir,
)
from dsm_refmodel.thermo5_experiments import generate_thermo5_tidsm_planes
from dsm_refmodel.thermo5_receiver import audit_thermo5_plane_alignment


DEFAULT_STEPS = (0, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192)
DEFAULT_SEEDS = (101, 307, 503)
MODES = ("rtl_first_order", "ef_order1", "ef_order2", "ef_order2_fixed",
         "ef_order3")
EVM_GATE_PERCENT = 3.5
EF_STATE_BOUND = 8.0  # candidate internal states fit signed Q4.15 in this screen


def _analog_metrics(baseband_7g, stimulus, profile_names, fir_taps,
                    reference_output_rms=None):
    normalized_pa_input = [value / 4.0 for value in baseband_7g]
    results = []
    for profile_index, name in enumerate(profile_names):
        profile = PA_OUTPUT_PROFILES[name]
        dpa = BehavioralDPA(
            saturation=profile["dpa_saturation"],
            smoothness=profile["dpa_smoothness"],
            ampm_degrees=profile["dpa_ampm_degrees"],
            envelope_memory=profile["dpa_envelope_memory"],
        )
        output = dpa.process(normalized_pa_input)
        output = apply_complex_fir(output, profile["output_network_taps"])
        output_rms = math.sqrt(sum(abs(value) ** 2 for value in output) /
                               max(1, len(output)))
        reference_rms = ((reference_output_rms or {}).get(name) or output_rms)
        relative_power_db = 20.0 * math.log10(
            max(output_rms, 1e-30) / max(reference_rms, 1e-30))
        modeled_signal_power_dbm = (
            profile["signal_power_dbm"] + relative_power_db)
        deterministic_bb7, _ = receive_filter_decimate(
            output, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        deterministic_metrics = demodulate_metrics(deterministic_bb7, stimulus)
        noisy, noise = add_thermal_noise(
            output,
            random.Random(stimulus["seed"] + profile_index * 7919),
            signal_power_dbm=modeled_signal_power_dbm,
            bandwidth_hz=profile["noise_bandwidth_hz"],
            noise_figure_db=profile["noise_figure_db"],
            temperature_k=profile["temperature_k"],
        )
        noisy_bb7, _ = receive_filter_decimate(
            noisy, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        results.append({
            "profile": name,
            "dpa_output_rms_normalized": output_rms,
            "reference_output_rms_normalized": reference_rms,
            "modeled_signal_power_dbm": modeled_signal_power_dbm,
            "relative_output_power_db": relative_power_db,
            "assumptions": {
                key: [[tap.real, tap.imag] for tap in value]
                if key == "output_network_taps" else value
                for key, value in profile.items()
            },
            "metrics_after_dpa_output_network": deterministic_metrics,
            "metrics_after_thermal_noise": demodulate_metrics(noisy_bb7, stimulus),
            "thermal_noise": noise,
        })
    return results


def _run_case(stimulus, interpolated_i, interpolated_q, mode, step,
              fir_taps, analog_profiles, state_width=None,
              analog_reference_output_rms=None):
    planes, model_stats = generate_thermo5_tidsm_planes(
        interpolated_i, interpolated_q, step, mode=mode,
        rtl_latency_samples=TID_LATENCY_AFTER_FRONTEND_TRIM,
        state_width=state_width)
    if mode == "rtl_first_order":
        audit = audit_thermo5_plane_alignment(
            planes, interpolated_i, interpolated_q, step=step,
            latency_samples=TID_LATENCY_AFTER_FRONTEND_TRIM)
        if audit["mismatches"]:
            raise RuntimeError("RTL scalar recurrence audit failed: %d/%d" %
                               (audit["mismatches"], audit["compared_samples"]))
    else:
        audit = None

    latency = model_stats["alignment_latency_samples"]
    baseband_7g, reconstruction = reconstruct_baseband_7g(
        planes, stimulus["actual_bandwidth_hz"], latency_samples=latency,
        fir_taps=fir_taps)
    baseband, receiver = receive_filter_decimate(
        baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    digital = demodulate_metrics(baseband, stimulus)
    max_state = model_stats["max_abs_error_state"]
    max_u = model_stats["max_abs_quantizer_input"]
    actual_state_width = model_stats.get("state_width_bits")
    if mode == "ef_order2_fixed":
        state_limit = (1 << (actual_state_width - 1)) / float(1 << 15)
        ef_state_headroom = (
            model_stats["finite"] and
            model_stats["state_saturation_samples"] == 0 and
            model_stats["input_saturation_samples"] == 0 and
            max_state < state_limit and max_u < 64.0)
    else:
        state_limit = None
        ef_state_headroom = (None if mode == "rtl_first_order" else
                             model_stats["finite"] and
                             max_state < EF_STATE_BOUND and
                             max_u < EF_STATE_BOUND)
    return {
        "mode": mode,
        "step": int(step),
        "state_width_bits": actual_state_width,
        "state_saturation_samples": model_stats.get(
            "state_saturation_samples"),
        "state_limit_magnitude": state_limit,
        "seed": int(stimulus["seed"]),
        "symbols": int(stimulus["symbols"]),
        "input_rms": stimulus["input_rms"],
        "input_peak": stimulus["input_peak"],
        "interpolation": "centered cubic [-1,9,9,-1]/16 in both x2 stages",
        "tid_latency_samples": latency,
        "scalar_rtl_audit": audit,
        "model_diagnostics": model_stats,
        "ef_q4_15_observed_headroom_pass": ef_state_headroom,
        "digital_metrics": digital,
        "reconstruction": reconstruction,
        "receiver": receiver,
        "analog_profiles": _analog_metrics(
            baseband_7g, stimulus, analog_profiles, fir_taps,
            reference_output_rms=analog_reference_output_rms)
        if analog_profiles else [],
    }


def _aggregate(records):
    groups = {}
    for record in records:
        groups.setdefault((record["mode"], record["step"],
                           record.get("state_width_bits")), []).append(record)
    summary = []
    for (mode, step, state_width), rows in sorted(
            groups.items(), key=lambda item: str(item[0])):
        evms = [row["digital_metrics"]["evm_percent"] for row in rows]
        sndrs = [row["digital_metrics"]["sndr_db"] for row in rows]
        symbol_errors = sum(row["digital_metrics"]["symbol_errors"] for row in rows)
        symbol_count = sum(row["digital_metrics"]["qam_symbols"] for row in rows)
        ef_headroom = (None if mode == "rtl_first_order" else
                       all(row["ef_q4_15_observed_headroom_pass"] for row in rows))
        scalar_audits = [row["scalar_rtl_audit"] for row in rows]
        entry = {
            "mode": mode,
            "step": step,
            "state_width_bits": state_width,
            "seed_count": len(rows),
            "mean_digital_evm_percent": statistics.mean(evms),
            "worst_seed_digital_evm_percent": max(evms),
            "mean_digital_sndr_db": statistics.mean(sndrs),
            "symbol_errors": symbol_errors,
            "qam_symbols": symbol_count,
            "symbol_error_rate": symbol_errors / max(1, symbol_count),
            "uncoded_bit_errors_natural_binary": sum(
                row["digital_metrics"]["uncoded_bit_errors_natural_binary"]
                for row in rows),
            "uncoded_bit_count": 8 * symbol_count,
            "uncoded_ber_natural_binary": sum(
                row["digital_metrics"]["uncoded_bit_errors_natural_binary"]
                for row in rows) / max(1, 8 * symbol_count),
            "zero_error_95pct_ber_upper_bound": (
                -math.log(0.05) / max(1, 8 * symbol_count)
                if sum(row["digital_metrics"][
                    "uncoded_bit_errors_natural_binary"] for row in rows) == 0
                else None),
            "all_seed_evm_gate_pass": all(value <= EVM_GATE_PERCENT
                                           for value in evms),
            "all_seed_q4_15_observed_headroom_pass": ef_headroom,
            "all_seed_scalar_rtl_audit_pass": (
                None if any(audit is None for audit in scalar_audits) else
                all(audit["mismatches"] == 0 for audit in scalar_audits)),
        }
        profile_names = sorted(set(
            result["profile"] for row in rows for result in row["analog_profiles"]))
        for profile_name in profile_names:
            profile_rows = [
                next(result for result in row["analog_profiles"]
                     if result["profile"] == profile_name)
                for row in rows]
            for metric_set in ("metrics_after_dpa_output_network",
                               "metrics_after_thermal_noise"):
                values = [profile[metric_set]["evm_percent"]
                          for profile in profile_rows]
                key = "%s_%s" % (profile_name, metric_set)
                entry[key] = {
                    "mean_evm_percent": statistics.mean(values),
                    "worst_seed_evm_percent": max(values),
                    "all_seed_evm_gate_pass": all(
                        value <= EVM_GATE_PERCENT for value in values),
                    "symbol_errors": sum(
                        profile[metric_set]["symbol_errors"]
                        for profile in profile_rows),
                    "uncoded_bit_errors_natural_binary": sum(
                        profile[metric_set]["uncoded_bit_errors_natural_binary"]
                        for profile in profile_rows),
                }
        summary.append(entry)
    summary.sort(key=lambda row: (
        row["uncoded_ber_natural_binary"],
        row["uncoded_bit_errors_natural_binary"],
        row["worst_seed_digital_evm_percent"],
    ))
    return summary


def run(seeds=DEFAULT_SEEDS, symbols=8, steps=DEFAULT_STEPS,
        modes=("rtl_first_order",), rms_drive=0.10, fir_taps=RX_FIR_TAPS,
        analog_profiles=()):
    if not seeds or not steps or not modes:
        raise ValueError("seeds, steps and modes must be non-empty")
    if symbols < 1 or rms_drive <= 0.0:
        raise ValueError("symbols and rms_drive must be positive")
    if any(mode not in MODES for mode in modes):
        raise ValueError("unknown mode; use " + ", ".join(MODES))
    if any(name not in PA_OUTPUT_PROFILES for name in analog_profiles):
        raise ValueError("unknown analog profile; use " +
                         ", ".join(sorted(PA_OUTPUT_PROFILES)))
    if fir_taps < 3 or fir_taps % 2 == 0:
        raise ValueError("FIR tap count must be odd and at least three")

    records = []
    for seed in seeds:
        stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
        if stimulus["input_peak"] > MAX_INPUT_DRIVE:
            raise ValueError("seed %d exceeds the shared input peak limit" % seed)
        interpolated_i, interpolated_q = _expand_iq_x4(
            stimulus["source_iq"], "centered_cubic")
        for mode in modes:
            for step in steps:
                records.append(_run_case(
                    stimulus, interpolated_i, interpolated_q, mode, step,
                    fir_taps, analog_profiles))
    return {
        "benchmark": "thermo5_256qam_step_and_ntf_order_sweep",
        "symbols_per_seed": int(symbols),
        "seeds": [int(seed) for seed in seeds],
        "qam_order": 256,
        "nfft": 4096,
        "cyclic_prefix": 512,
        "occupied_bandwidth_hz": OCCUPIED_BW_HZ,
        "source_rate_hz": 1.75e9,
        "rms_drive_target": float(rms_drive),
        "input_peak_limit": MAX_INPUT_DRIVE,
        "interpolation": "centered cubic [-1,9,9,-1]/16 in both x2 stages",
        "step_definition": "branch offsets are {+3,+1,-1,-3} * STEP in signed Q1.15 units",
        "ntf_candidates": {
            "rtl_first_order": "current four-branch first-order RTL, scalar recurrence checked",
            "ef_order1": "software error-feedback comparator; NTF=(1-z^-1)",
            "ef_order2": "software error-feedback candidate; NTF=(1-z^-1)^2",
            "ef_order2_fixed": "integer Q1.15/Q4.15 EF2 with state saturation",
            "ef_order3": "software error-feedback stress candidate; NTF=(1-z^-1)^3",
        },
        "acceptance_gates": {
            "digital_evm_percent": EVM_GATE_PERCENT,
            "error_feedback_observed_state_bound": EF_STATE_BOUND,
            "error_feedback_bound_note": "Q4.15 observed finite-frame headroom only; not a global stability proof",
        },
        "uncoded_ber_note": "Natural-binary labeling is used by this OFDM source; BER is a screening metric, not Gray-coded standard BER.",
        "analog_profile_assumptions": "Nominal/stress DPA, output FIR, output power, kTB and NF are illustrative sensitivity assumptions.",
        "records": records,
        "ranked_summary": _aggregate(records),
    }


def _write_csv(path, result):
    fields = (
        "mode", "step", "state_width_bits", "seed", "symbols",
        "input_rms", "input_peak",
        "digital_evm_percent", "digital_sndr_db", "symbol_errors",
        "symbol_error_rate", "uncoded_bit_errors_natural_binary",
        "uncoded_ber_natural_binary", "input_saturation_samples",
        "max_abs_quantizer_input", "max_abs_error_state",
        "ef_q4_15_observed_headroom_pass", "scalar_rtl_mismatches",
        "nominal_evm_percent", "stress_evm_percent",
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for row in result["records"]:
            digital = row["digital_metrics"]
            diag = row["model_diagnostics"]
            audit = row["scalar_rtl_audit"]
            analog = {item["profile"]: item for item in row["analog_profiles"]}
            writer.writerow({
                "mode": row["mode"], "step": row["step"], "seed": row["seed"],
                "state_width_bits": row["state_width_bits"],
                "symbols": row["symbols"], "input_rms": row["input_rms"],
                "input_peak": row["input_peak"],
                "digital_evm_percent": digital["evm_percent"],
                "digital_sndr_db": digital["sndr_db"],
                "symbol_errors": digital["symbol_errors"],
                "symbol_error_rate": digital["symbol_error_rate"],
                "uncoded_bit_errors_natural_binary": digital[
                    "uncoded_bit_errors_natural_binary"],
                "uncoded_ber_natural_binary": digital[
                    "uncoded_ber_natural_binary"],
                "input_saturation_samples": diag["input_saturation_samples"],
                "max_abs_quantizer_input": diag["max_abs_quantizer_input"],
                "max_abs_error_state": diag["max_abs_error_state"],
                "ef_q4_15_observed_headroom_pass":
                    row["ef_q4_15_observed_headroom_pass"],
                "scalar_rtl_mismatches":
                    "" if audit is None else audit["mismatches"],
                "nominal_evm_percent": analog.get("nominal", {}).get(
                    "metrics_after_thermal_noise", {}).get("evm_percent", ""),
                "stress_evm_percent": analog.get("stress", {}).get(
                    "metrics_after_thermal_noise", {}).get("evm_percent", ""),
            })


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", default="101,307,503")
    parser.add_argument("--symbols", type=int, default=8)
    parser.add_argument("--steps", default=",".join(str(x) for x in DEFAULT_STEPS))
    parser.add_argument("--modes", default="rtl_first_order")
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--rx-fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--analog-profiles", default="")
    parser.add_argument("--json", type=Path)
    parser.add_argument("--csv", type=Path)
    args = parser.parse_args()
    try:
        seeds = tuple(int(value.strip()) for value in args.seeds.split(",")
                      if value.strip())
        steps = tuple(int(value.strip()) for value in args.steps.split(",")
                      if value.strip())
        modes = tuple(value.strip() for value in args.modes.split(",")
                      if value.strip())
        profiles = tuple(value.strip() for value in args.analog_profiles.split(",")
                         if value.strip())
    except ValueError as error:
        parser.error(str(error))
    result = run(seeds, args.symbols, steps, modes, args.rms_drive,
                 args.rx_fir_taps, profiles)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")
    if args.csv:
        _write_csv(args.csv, result)


if __name__ == "__main__":
    main()
