#!/usr/bin/env python3
"""Compare fixed thermo5 DPD images on held-out QAM256 waveforms.

The 2/4-tap coefficient sets are the non-identity verification images already
used by the bit-true VCS tests. They are intentionally not described as
inverse-PA coefficients or as production candidates.
"""

import argparse
import hashlib
import json
import math
import statistics
from multiprocessing import Pool
from pathlib import Path

from benchmark_thermo5_step_ntf import _analog_metrics
from benchmark_thermo5_arch_ablation import _papr_db, _spectrum
from benchmark_thermo5_tid_receiver import (
    PA_OUTPUT_PROFILES,
    RX_FIR_TAPS,
    SOURCE_FS_HZ,
    _expand_iq_x4,
    demodulate_metrics,
    make_256qam_ofdm,
    receive_filter_decimate,
    reconstruct_baseband_7g,
)
from dsm_refmodel.link_models import BehavioralDPA, apply_complex_fir
from dsm_refmodel.thermo5 import (
    nonlinear_test_dpd_coefficients,
    nonlinear_test_dpd_coefficients_4tap,
    run_centered_cubic_frontend,
)


DEFAULT_SEEDS = (281001, 281003, 281005, 281007)
CANDIDATES = (
    {"name": "identity_1tap", "active_taps": 1, "coefficients": None},
    {"name": "verification_image_2tap", "active_taps": 2,
     "coefficients": nonlinear_test_dpd_coefficients()},
    {"name": "verification_image_4tap", "active_taps": 4,
     "coefficients": nonlinear_test_dpd_coefficients_4tap()},
)


def _frontend_words(source_iq):
    if len(source_iq) % 8:
        raise ValueError("QAM stimulus must contain complete eight-sample beats")
    i_words, q_words = [], []
    for first in range(0, len(source_iq), 8):
        word = source_iq[first:first + 8]
        i_words.append([sample[0] for sample in word])
        q_words.append([sample[1] for sample in word])
    starts = [0] * len(i_words)
    starts[0] = 1
    if len(i_words) % 7:
        raise ValueError("centered-cubic DPD frame must contain a multiple of seven AXIS beats")
    gains = [1 << 14] * len(i_words)
    return i_words, q_words, starts, gains


def _plane_digest(plane_words):
    digest = hashlib.sha256()
    for word in plane_words:
        for plane in word:
            digest.update(int(plane).to_bytes(8, "little", signed=False))
    return digest.hexdigest()


def _wilson(errors, trials, z=1.959963984540054):
    if trials <= 0:
        return [None, None]
    p = errors / trials
    denom = 1.0 + z * z / trials
    center = (p + z * z / (2.0 * trials)) / denom
    radius = z * math.sqrt(p * (1.0 - p) / trials +
                           z * z / (4.0 * trials * trials)) / denom
    return [max(0.0, center - radius), min(1.0, center + radius)]


def _analog_chain_diagnostics(baseband_7g, stimulus):
    """Measure per-profile PAPR, compression incidence, and adjacent-band proxy."""
    normalized_input = [value / 4.0 for value in baseband_7g]
    diagnostics = []
    for profile_name, profile in PA_OUTPUT_PROFILES.items():
        pa = BehavioralDPA(
            saturation=profile["dpa_saturation"],
            smoothness=profile["dpa_smoothness"],
            ampm_degrees=profile["dpa_ampm_degrees"],
            envelope_memory=profile["dpa_envelope_memory"],
        )
        pa_output = pa.process(normalized_input)
        output = apply_complex_fir(pa_output, profile["output_network_taps"])
        spectrum = _spectrum(
            output, SOURCE_FS_HZ * 4.0, stimulus["actual_bandwidth_hz"])
        compressed = sum(
            abs(after) < abs(before) * (1.0 - 1e-12)
            for before, after in zip(normalized_input, pa_output)
        )
        diagnostics.append({
            "profile": profile_name,
            "pa_input_papr_db": _papr_db(normalized_input),
            "dpa_output_papr_db": _papr_db(pa_output),
            "output_network_papr_db": _papr_db(output),
            "pa_am_am_compressed_samples": compressed,
            "pa_input_peak_normalized": max(map(abs, normalized_input), default=0.0),
            "dpa_output_peak_normalized": max(map(abs, pa_output), default=0.0),
            "output_network_peak_normalized": max(map(abs, output), default=0.0),
            "adjacent_band_proxy_dbc": spectrum["adjacent_band_proxy_dbc"],
            "mainband_power_normalized": spectrum["mainband_power"],
            "measurement": "4k Blackman-window PSD integrated over adjacent +/-125..375 MHz bands; model proxy only",
        })
    return diagnostics


def _one_seed(task):
    seed, symbols, rms_drive, step, fir_taps, candidates = task
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    i_words, q_words, starts, gains = _frontend_words(stimulus["source_iq"])
    candidate_data = []
    for candidate in candidates:
        planes = run_centered_cubic_frontend(
            i_words, q_words, starts, gains, step=step,
            dpd_coefficients=candidate["coefficients"],
            dpd_active_taps=candidate["active_taps"], tidsm_order=2)
        planes = [tuple(int(value) for value in word) for word in planes]
        baseband_7g, reconstruction = reconstruct_baseband_7g(
            planes, stimulus["actual_bandwidth_hz"], latency_samples=0,
            fir_taps=fir_taps)
        rx, receiver = receive_filter_decimate(
            baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        candidate_data.append({
            "candidate": candidate,
            "planes": planes,
            "plane_sha256": _plane_digest(planes),
            "baseband_7g": baseband_7g,
            "reconstruction": reconstruction,
            "receiver": receiver,
            "digital_metrics": demodulate_metrics(rx, stimulus),
        })

    identity = candidate_data[0]
    identity_i, identity_q = _expand_iq_x4(stimulus["source_iq"],
                                            "centered_cubic")
    # Confirm the no-DPD streaming model exactly matches the independent
    # sample-serial EF2 oracle used by the main QAM robustness campaign.
    from dsm_refmodel.thermo5_experiments import generate_thermo5_tidsm_planes
    oracle_planes, _ = generate_thermo5_tidsm_planes(
        identity_i, identity_q, step, mode="ef_order2_fixed", state_width=20)
    if identity["planes"] != oracle_planes:
        raise RuntimeError("identity centered front-end planes differ from EF2 oracle")

    baseline_analog = _analog_metrics(
        identity["baseband_7g"], stimulus, tuple(PA_OUTPUT_PROFILES), fir_taps)
    reference_output_rms = {
        profile["profile"]: profile["dpa_output_rms_normalized"]
        for profile in baseline_analog
    }
    results = []
    for index, data in enumerate(candidate_data):
        analog = (baseline_analog if index == 0 else _analog_metrics(
            data["baseband_7g"], stimulus, tuple(PA_OUTPUT_PROFILES), fir_taps,
            reference_output_rms=reference_output_rms))
        chain_diagnostics = _analog_chain_diagnostics(data["baseband_7g"], stimulus)
        results.append({
            "seed": int(seed),
            "candidate": data["candidate"]["name"],
            "active_taps": data["candidate"]["active_taps"],
            "coefficient_image": data["candidate"]["coefficients"],
            "plane_words": len(data["planes"]),
            "plane_sha256": data["plane_sha256"],
            "identity_plane_match": data["planes"] == oracle_planes,
            "input": {
                "symbols": int(symbols),
                "rms_drive_target": float(rms_drive),
                "measured_rms": stimulus["input_rms"],
                "peak": stimulus["input_peak"],
                "actual_bandwidth_hz": stimulus["actual_bandwidth_hz"],
            },
            "step": int(step),
            "digital_metrics": data["digital_metrics"],
            "analog_profiles": analog,
            "analog_chain_diagnostics": chain_diagnostics,
            "reconstruction": data["reconstruction"],
            "receiver": data["receiver"],
        })
    return results


def _summaries(records, candidates):
    result = []
    for candidate_config in candidates:
        candidate = candidate_config["name"]
        rows = [row for row in records if row["candidate"] == candidate]
        bits = sum(8 * row["digital_metrics"]["qam_symbols"] for row in rows)
        errors = sum(row["digital_metrics"][
            "uncoded_bit_errors_natural_binary"] for row in rows)
        seed_bers = [row["digital_metrics"][
            "uncoded_bit_errors_natural_binary"] /
            max(1, 8 * row["digital_metrics"]["qam_symbols"])
            for row in rows]
        summary = {
            "candidate": candidate,
            "seed_count": len(rows),
            "qam_symbols": sum(row["digital_metrics"]["qam_symbols"]
                               for row in rows),
            "uncoded_bit_count": bits,
            "uncoded_bit_errors_natural_binary": errors,
            "uncoded_ber_natural_binary": errors / max(1, bits),
            "ber_95pct_wilson_ci": _wilson(errors, bits),
            "worst_seed_ber": max(seed_bers, default=0.0),
            "mean_evm_percent": statistics.mean(
                row["digital_metrics"]["evm_percent"] for row in rows),
            "worst_seed_evm_percent": max(
                row["digital_metrics"]["evm_percent"] for row in rows),
            "mean_sndr_db": statistics.mean(
                row["digital_metrics"]["sndr_db"] for row in rows),
            "all_identity_planes_match": all(
                row["identity_plane_match"] for row in rows
                if row["candidate"] == "identity_1tap"),
            "analog": {},
        }
        for profile_name in PA_OUTPUT_PROFILES:
            profile_rows = [next(item for item in row["analog_profiles"]
                                 if item["profile"] == profile_name)
                            for row in rows]
            deterministic = [item["metrics_after_dpa_output_network"]
                             for item in profile_rows]
            noisy = [item["metrics_after_thermal_noise"]
                     for item in profile_rows]
            analog_bits = sum(8 * item["qam_symbols"] for item in noisy)
            analog_errors = sum(item[
                "uncoded_bit_errors_natural_binary"] for item in noisy)
            summary["analog"][profile_name] = {
                "uncoded_bit_count": analog_bits,
                "uncoded_bit_errors_natural_binary": analog_errors,
                "uncoded_ber_natural_binary": analog_errors / max(1, analog_bits),
                "ber_95pct_wilson_ci": _wilson(analog_errors, analog_bits),
                "worst_seed_ber": max(
                    item["uncoded_bit_errors_natural_binary"] /
                    max(1, 8 * item["qam_symbols"]) for item in noisy),
                "mean_evm_after_dpa_percent": statistics.mean(
                    item["evm_percent"] for item in deterministic),
                "mean_evm_after_noise_percent": statistics.mean(
                    item["evm_percent"] for item in noisy),
                "worst_seed_evm_after_noise_percent": max(
                    item["evm_percent"] for item in noisy),
                "modeled_output_power_dbm": statistics.mean(
                    item["modeled_signal_power_dbm"] for item in profile_rows),
            }
            diagnostic_rows = [next(
                item for item in row["analog_chain_diagnostics"]
                if item["profile"] == profile_name) for row in rows]
            mean_adjacent_ratio = statistics.mean(
                10.0 ** (item["adjacent_band_proxy_dbc"] / 10.0)
                for item in diagnostic_rows)
            summary["analog"][profile_name].update({
                "mean_adjacent_band_proxy_dbc": 10.0 * math.log10(
                    max(mean_adjacent_ratio, 1e-30)),
                "worst_seed_adjacent_band_proxy_dbc": max(
                    item["adjacent_band_proxy_dbc"] for item in diagnostic_rows),
                "mean_pa_input_papr_db": statistics.mean(
                    item["pa_input_papr_db"] for item in diagnostic_rows),
                "mean_output_network_papr_db": statistics.mean(
                    item["output_network_papr_db"] for item in diagnostic_rows),
                "pa_am_am_compressed_samples": sum(
                    item["pa_am_am_compressed_samples"] for item in diagnostic_rows),
            })
        result.append(summary)
    return result


def run(seeds=DEFAULT_SEEDS, symbols=9, rms_drive=0.10, step=5120,
        fir_taps=RX_FIR_TAPS, jobs=1, candidates=None):
    if not seeds or len(set(seeds)) != len(seeds):
        raise ValueError("seeds must be non-empty and unique")
    if symbols < 1 or jobs < 1:
        raise ValueError("symbols and jobs must be positive")
    candidates = tuple(CANDIDATES if candidates is None else candidates)
    if not candidates or len({item["name"] for item in candidates}) != len(candidates):
        raise ValueError("candidate names must be non-empty and unique")
    if not any(item["name"] == "identity_1tap" for item in candidates):
        raise ValueError("candidate set must include the identity reference")
    tasks = [(seed, symbols, rms_drive, step, fir_taps, candidates)
             for seed in seeds]
    if jobs == 1:
        batches = [_one_seed(task) for task in tasks]
    else:
        with Pool(processes=jobs) as pool:
            batches = pool.map(_one_seed, tasks)
    records = [row for batch in batches for row in batch]
    return {
        "benchmark": "thermo5_tx_dpd_image_qam256_ab",
        "scope": "behavioral model only; bit-true frontend and four TID planes, modeled output chain",
        "seeds": [int(seed) for seed in seeds],
        "symbols_per_seed": int(symbols),
        "qam_order": 256,
        "nfft": 4096,
        "cyclic_prefix": 512,
        "active_subcarriers": 584,
        "step": int(step),
        "state_width_bits": 20,
        "rms_drive": float(rms_drive),
        "heldout_selection": "All coefficient images fixed before held-out run; no fitting to these seeds.",
        "candidates": [
            {key: value for key, value in candidate.items()
             if key not in ("coefficients", "fit")} |
            {"coefficient_image": candidate["coefficients"],
             **({"fit": candidate["fit"]} if "fit" in candidate else {})}
            for candidate in candidates
        ],
        "pa_models": {
            name: {key: value for key, value in profile.items()
                   if key != "output_network_taps"} |
                  {"output_network_taps": [[tap.real, tap.imag]
                                             for tap in profile["output_network_taps"]]}
            for name, profile in PA_OUTPUT_PROFILES.items()
        },
        "summaries": _summaries(records, candidates),
        "records": records,
        "limitations": [
            "non-identity coefficients are verification stimuli, not fitted inverse-PA solutions",
            "behavioral DPA and output/noise profiles are not calibrated to a device",
            "no standard ACLR, physical BER, or implementation PPA conclusion is made",
            "the 2/4-tap RTL configuration was bit-true tested separately and is not selected by the GT parent SKU",
        ],
    }


def _seed_list(text):
    values = tuple(int(item.strip(), 0) for item in text.split(",") if item.strip())
    if not values:
        raise argparse.ArgumentTypeError("seed list cannot be empty")
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seeds", type=_seed_list, default=DEFAULT_SEEDS)
    parser.add_argument("--symbols", type=int, default=9)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--step", type=int, default=5120)
    parser.add_argument("--fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--jobs", type=int, default=1)
    parser.add_argument("--candidate-json", type=Path,
                        help="append separately fitted candidates from an ILA JSON file")
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()
    candidates = list(CANDIDATES)
    if args.candidate_json:
        candidate_data = json.loads(args.candidate_json.read_text())
        fitted = candidate_data.get("candidates", [])
        if not fitted:
            parser.error("candidate JSON contains no candidates")
        candidates.extend(fitted)
    result = run(args.seeds, args.symbols, args.rms_drive, args.step,
                 args.fir_taps, args.jobs, candidates)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(result, indent=2) + "\n")
    for row in result["summaries"]:
        print("%-26s BER=%8.3g CI95=[%.3g,%.3g] EVM=%6.3f%% SNDR=%6.2fdB "
              "nomBER=%8.3g stressBER=%8.3g" % (
                  row["candidate"], row["uncoded_ber_natural_binary"],
                  *row["ber_95pct_wilson_ci"], row["mean_evm_percent"],
                  row["mean_sndr_db"],
                  row["analog"]["nominal"]["uncoded_ber_natural_binary"],
                  row["analog"]["stress"]["uncoded_ber_natural_binary"]))
    print("wrote %s (%d seed-candidate records)" %
          (args.json, len(result["records"])))


if __name__ == "__main__":
    main()
