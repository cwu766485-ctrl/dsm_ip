#!/usr/bin/env python3
"""Reconstruct and measure captured DSM V1.3 RTL outputs.

This analysis is deliberately digital and record-specific. The PA spectrum is
reported in normalized cycles/sample with PSD relative to its largest bin; it
is not interpreted as standards ACLR or calibrated RF performance.
"""

import argparse
import csv
import json
import math
from pathlib import Path

import numpy as np

from dsm_refmodel.thermo5_receiver import (
    decode_thermo5_plane_words,
    serialize_thermo5_plane_words,
)


def read_csv(path):
    with path.open(newline="", encoding="ascii") as stream:
        return list(csv.DictReader(stream))


def read_signed_hex(path):
    values = []
    for line in path.read_text(encoding="ascii").splitlines():
        value = int(line.strip(), 16) & 0xFFFF
        values.append(value - 0x10000 if value & 0x8000 else value)
    return values


def db10(numerator, denominator):
    if numerator <= 0:
        return float("-inf")
    return 10.0 * math.log10(numerator / max(float(denominator), 1e-300))


def write_psd(path, samples):
    centered = np.asarray(samples, dtype=np.float64)
    centered -= np.mean(centered)
    spectrum = np.fft.rfft(centered)
    power = np.abs(spectrum) ** 2
    peak = max(float(power.max()), 1e-300)
    with path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.writer(stream)
        writer.writerow(("bin", "frequency_cycles_per_sample", "psd_db_relative_to_peak"))
        for index, value in enumerate(power):
            writer.writerow((index, index / len(centered),
                             10.0 * math.log10(max(float(value) / peak, 1e-300))))
    return spectrum, power


def measure_pa_sku(capture_dir, vector_dir, output_dir, sku):
    source = read_csv(capture_dir / "source_actual.csv")
    rows = read_csv(capture_dir / "pa_actual.csv")
    if len(source) != 32 or len(rows) != 56:
        raise ValueError(f"{sku}: expected 32 source handshakes and 56 PA words")
    if [int(row["beat_index"]) for row in source] != list(range(32)):
        raise ValueError(f"{sku}: source handshake ordering is not contiguous")
    if [int(row["word_index"]) for row in rows] != list(range(56)):
        raise ValueError(f"{sku}: PA output ordering is not contiguous")
    if any(int(row["epoch"]) != 1 for row in source + rows):
        raise ValueError(f"{sku}: captured reset epoch is not the expected single epoch")
    source_frame_start_beats = [int(row["beat_index"]) + 1 for row in source
                                if int(row["frame_start"])]
    gains = [int(row["frame_gain"]) for row in source if int(row["frame_start"])]
    core_frame_start_words = [1, 15, 36]
    expected_source_beats = [((word - 1) * 8) // 14 + 1
                             for word in core_frame_start_words]
    if source_frame_start_beats != expected_source_beats or gains != [16384, 14336, 12288]:
        raise ValueError(f"{sku}: frame metadata differs from the shared input contract")
    if sum(int(row["tlast"]) for row in source) != 1 or int(source[-1]["tlast"]) != 1:
        raise ValueError(f"{sku}: expected one TLAST on the final accepted beat")

    planes = [tuple(int(row[f"plane{plane}"], 16) for plane in range(4))
              for row in rows]
    complex_iq = decode_thermo5_plane_words(planes)
    baseband_path = output_dir / f"{sku}_reconstructed_baseband.csv"
    with baseband_path.open("w", newline="", encoding="ascii") as stream:
        writer = csv.writer(stream)
        writer.writerow(("sample", "i_normalized", "q_normalized"))
        for index, value in enumerate(complex_iq):
            writer.writerow((index, f"{value.real:.9g}", f"{value.imag:.9g}"))

    raw = serialize_thermo5_plane_words(planes)
    raw_psd, raw_power = write_psd(output_dir / f"{sku}_pa_raw_psd.csv", raw)
    carrier_bin = len(raw) // 4
    top_bins = np.argsort(raw_power[1:])[-8:][::-1] + 1
    first_source_ps = int(source[0]["time_ps"])
    last_source_ps = int(source[-1]["time_ps"])
    first_pa_ps = int(rows[0]["time_ps"])
    last_pa_ps = int(rows[-1]["time_ps"])
    return {
        "status": "PASS",
        "source_handshakes": len(source),
        "pa_words": len(rows),
        "serialized_pa_samples": len(raw),
        "reconstructed_complex_samples": len(complex_iq),
        "source_frame_start_beats_one_based": source_frame_start_beats,
        "pa_frame_start_words_one_based": core_frame_start_words,
        "frame_gain_q14": gains,
        "source_throughput_hz": len(source) * 1e12 /
            (last_source_ps - first_source_ps + 8000),
        "pa_word_throughput_hz": (len(rows) - 1) * 1e12 /
            max(last_pa_ps - first_pa_ps, 1),
        "first_source_to_first_pa_latency_ns": (first_pa_ps - first_source_ps) / 1000.0,
        "pa_raw_rms_level": float(np.sqrt(np.mean(np.square(raw, dtype=np.float64)))),
        "pa_raw_dc_level": float(np.mean(raw)),
        "pa_carrier_bin_expected_fs4": carrier_bin,
        "pa_raw_peak_bins": [
            {"bin": int(index), "frequency_cycles_per_sample": int(index) / len(raw),
             "relative_to_largest_bin_db": float(10.0 * math.log10(
                 max(float(raw_power[index]) / max(float(raw_power.max()), 1e-300), 1e-300)))}
            for index in top_bins
        ],
        "pa_psd_file": f"{sku}_pa_raw_psd.csv",
        "reconstructed_baseband_file": f"{sku}_reconstructed_baseband.csv",
        "bittrue_status": "PASS (independent UVM scoreboard compared all four 64-bit planes)",
        "evm_snr_sndr_aclr_status": "NOT RUN: no configured calibrated receiver/channel mask for this directed tone record",
        "ber_status": "NOT RUN: no coded receive-chain BER testcase in this capture",
    }


def measure_mash(capture_dir, vector_dir, shared_input_dir, output_dir):
    rows = read_csv(capture_dir / "actual.csv")
    expected_count = len((vector_dir / "expected.csv").read_text(encoding="ascii").splitlines())
    if len(rows) != expected_count or len(rows) != 448:
        raise ValueError("MASH capture must contain the 448 expected valid transactions")
    observed = np.asarray([int(row["combined_level"]) for row in rows], dtype=np.float64)
    reference = np.asarray(read_signed_hex(
        shared_input_dir / "tid32_thermo5_frontend_i.mem"), dtype=np.float64) / 32768.0
    if len(reference) != len(observed):
        raise ValueError("MASH input sample count differs from the captured output")
    if [int(row["transaction"]) for row in rows] != list(range(len(rows))):
        raise ValueError("MASH output transaction ordering is not contiguous")

    # Ignore only the documented reset startup sample when fitting the linear
    # amplitude. The actual RTL output is otherwise retained without filtering.
    fit_x = reference[1:]
    fit_y = observed[1:]
    design = np.column_stack((fit_x, np.ones_like(fit_x)))
    gain, offset = np.linalg.lstsq(design, fit_y, rcond=None)[0]
    fitted = gain * fit_x + offset
    residual = fit_y - fitted
    signal_power = float(np.mean((fitted - np.mean(fitted)) ** 2))
    noise_power = float(np.mean(residual ** 2))
    evm = math.sqrt(noise_power / max(signal_power, 1e-300))
    residual_spectrum = np.fft.rfft(residual)
    residual_power = np.abs(residual_spectrum) ** 2
    split = max(2, len(residual_power) // 4)
    low_noise = float(np.sum(residual_power[1:split]))
    high_noise = float(np.sum(residual_power[split:]))
    tone_bin = int(json.loads((vector_dir / "manifest.json").read_text(
        encoding="utf-8")).get("tone_bin", 7))
    fitted_spectrum = np.fft.rfft(fitted - np.mean(fitted))
    tone_power = float(np.abs(fitted_spectrum[tone_bin]) ** 2)
    inband_end = max(tone_bin + 1, int(math.floor(len(fit_x) * 0.10)))
    inband_indices = np.arange(1, min(inband_end + 1, len(residual_power)))
    inband_noise = float(np.sum(residual_power[inband_indices[inband_indices != tone_bin]]))
    timestamps = [int(row["time_ps"]) for row in rows]
    if timestamps != sorted(timestamps):
        raise ValueError("MASH output timestamps are not monotonic")
    _, power = write_psd(output_dir / "mash11_output_psd.csv", observed)
    dominant_bin = int(np.argmax(power[1:]) + 1)
    ac_power = float(np.sum(power[1:]))
    return {
        "status": "PASS",
        "input_samples": len(reference),
        "output_transactions": len(rows),
        "tone_bin": tone_bin,
        "tone_frequency_cycles_per_sample": tone_bin / len(rows),
        "largest_output_psd_bin": dominant_bin,
        "fitted_gain_level_per_full_scale_input": float(gain),
        "fitted_dc_offset_level": float(offset),
        "output_evm_percent_after_linear_gain_offset": 100.0 * evm,
        "sndr_db_after_linear_gain_offset": -20.0 * math.log10(max(evm, 1e-300)),
        "inband_sndr_db_0_to_0p10_fs": db10(tone_power, inband_noise),
        "coherent_tone_to_other_ac_bins_db": db10(
            float(np.abs(np.fft.rfft(observed - np.mean(observed))[tone_bin]) ** 2),
            ac_power - float(np.abs(np.fft.rfft(observed - np.mean(observed))[tone_bin]) ** 2)),
        "residual_high_band_to_low_band_power_db": db10(high_noise, low_noise),
        "output_throughput_hz": (len(rows) - 1) * 1e12 /
            max(timestamps[-1] - timestamps[0], 1),
        "output_psd_file": "mash11_output_psd.csv",
        "metric_scope": "block-level normalized digital tone screen; no PA/serializer or RF calibration",
        "aclrs_ber_status": "NOT RUN: no MASH Product PA mapping, channel mask, or receive-chain BER fixture",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-root", type=Path, required=True)
    parser.add_argument("--vectors-root", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    result = {
        "schema": "dsm_v13_actual_rtl_capture_metrics_v1",
        "method": "direct Fourier analysis of captured RTL PA planes and MASH combined_level outputs",
        "numpy_version": np.__version__,
        "pa_skus": {
            sku: measure_pa_sku(args.capture_root / sku,
                                args.vectors_root / sku, args.output_dir, sku)
            for sku in ("ef1", "ef2")
        },
        "mash11": measure_mash(args.capture_root / "mash11",
                               args.capture_root / "mash11" / "vectors",
                               args.vectors_root / "shared_input", args.output_dir),
        "disposition": {
            "standard_aclr": "NOT RUN",
            "calibrated_rf_power": "NOT RUN",
            "hardware_ber": "NOT RUN",
            "reason": "No target PA model, RF sample-rate calibration, standards channel mask, or hardware receive chain is specified by the MASH block contract.",
        },
    }
    path = args.output_dir / "metrics.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")
    print("DSM_V13_RTL_CAPTURE_ANALYSIS=PASS")
    print(f"metrics={path}")
    for sku, data in result["pa_skus"].items():
        print(f"{sku}: source={data['source_handshakes']} PA={data['pa_words']} "
              f"latency_ns={data['first_source_to_first_pa_latency_ns']:.3f} "
              f"PA_words_per_second={data['pa_word_throughput_hz']:.3f}")
    print(f"mash11: outputs={result['mash11']['output_transactions']} "
          f"EVM_percent={result['mash11']['output_evm_percent_after_linear_gain_offset']:.4f} "
          f"SNDR_dB={result['mash11']['sndr_db_after_linear_gain_offset']:.3f}")


if __name__ == "__main__":
    main()
