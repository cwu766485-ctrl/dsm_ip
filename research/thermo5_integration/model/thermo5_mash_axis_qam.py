#!/usr/bin/env python3
"""Prepare and evaluate a captured RTL Weighted-MASH QAM256 AXIS run."""

import argparse
import json
import math
import shutil
from pathlib import Path

from benchmark_thermo5_tid_receiver import (
    GUARD_SAMPLES,
    RAW_FS_HZ,
    RX_FIR_TAPS,
    make_256qam_ofdm,
    demodulate_metrics,
    fft,
    _blackman_lowpass,
    _linear_fir_decimate,
)
from dsm_refmodel.thermo5 import (
    LANES_IN,
    apply_q14_gain,
    one_tap_complex_coefficients,
    read_source_vectors,
    run_centered_cubic_ef2_inputs,
    write_vectors,
)
from mash11_reference import run_mash11
from mash_weighted_contract import weighted_encode


def _write_mem(path, values, width):
    digits = (width + 3) // 4
    path.write_text("".join("%0*X\n" % (digits, int(value) & ((1 << width) - 1))
                            for value in values))


def prepare(run_dir, seed, symbols, rms_drive):
    run_dir.mkdir(parents=True, exist_ok=False)
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    source_data = stimulus["source_iq"][GUARD_SAMPLES:
                                     GUARD_SAMPLES + stimulus["data_samples"]]
    pad_samples = (-len(source_data)) % 56
    guard = 46 * 56
    source_iq = ([(0, 0)] * guard + source_data + [(0, 0)] * pad_samples +
                 [(0, 0)] * guard)
    if len(source_iq) % 56 or len(source_iq) % 14:
        raise AssertionError("AXIS source must align to 56-sample quanta")
    i_words = [[sample[0] for sample in source_iq[first:first + LANES_IN]]
               for first in range(0, len(source_iq), LANES_IN)]
    q_words = [[sample[1] for sample in source_iq[first:first + LANES_IN]]
               for first in range(0, len(source_iq), LANES_IN)]
    starts = [1] + [0] * (len(i_words) - 1)
    gains = [16384] * len(i_words)
    write_vectors(run_dir / "frontend_vectors", i_words, q_words, starts, gains,
                  [(0, 0, 0, 0)] * len(i_words))

    coeffs = one_tap_complex_coefficients(16384, 0, 0, 0, 0, 0)
    pre_words = run_centered_cubic_ef2_inputs(
        i_words, q_words, starts, gains, dpd_coefficients=coeffs,
        dpd_active_taps=1)
    raw_pairs = run_mash11([list(i) for i, _ in pre_words],
                           [list(q) for _, q in pre_words])
    prev_q2 = (-1, -1)
    pa0, pa1 = [], []
    for stage1, stage2 in raw_pairs:
        word0, word1, _, prev_q2 = weighted_encode(
            stage1, stage2, prev_q2, channels=32)
        pa0.append(word0)
        pa1.append(word1)
    _write_mem(run_dir / "expected_mash_pa0.mem", pa0, 64)
    _write_mem(run_dir / "expected_mash_pa1.mem", pa1, 64)

    axis_i, axis_q = [], []
    for first in range(0, len(source_iq), 14):
        chunk = source_iq[first:first + 14]
        axis_i.extend(sample[0] for sample in chunk)
        axis_q.extend(sample[1] for sample in chunk)
    _write_mem(run_dir / "axis_i_samples.mem", axis_i, 16)
    _write_mem(run_dir / "axis_q_samples.mem", axis_q, 16)

    stimulus["data_start"] = guard
    stimulus["data_samples"] = len(source_data)
    stimulus["source_iq"] = source_iq
    stimulus["axis_beats"] = len(source_iq) // 14
    stimulus["frontend_words"] = len(pre_words)
    stimulus["pad_samples_after_qam"] = pad_samples
    (run_dir / "stimulus.json").write_text(json.dumps({
        key: value for key, value in stimulus.items()
        if key not in ("source_iq", "qam_rows", "active_bins")
    } | {
        "seed": seed, "qam_order": 256, "symbols": symbols,
        "active_bins": stimulus["active_bins"],
        "qam_rows": [[[v.real, v.imag] for v in row]
                     for row in stimulus["qam_rows"]],
    }, indent=2) + "\n")
    return stimulus


def _read_packed_words(path):
    return [int(line.strip(), 16) for line in path.read_text().splitlines()
            if line.strip()]


def evaluate(run_dir, seed, symbols, rms_drive):
    stimulus = make_256qam_ofdm(seed, symbols=symbols, rms_drive=rms_drive)
    meta = json.loads((run_dir / "stimulus.json").read_text())
    stimulus["data_start"] = int(meta["data_start"])
    stimulus["data_samples"] = int(meta["data_samples"])
    pa0 = _read_packed_words(run_dir / "captured_mash_pa0.mem")
    pa1 = _read_packed_words(run_dir / "captured_mash_pa1.mem")
    if len(pa0) != len(pa1) or len(pa0) != int(meta["frontend_words"]):
        raise ValueError("captured PA transaction counts do not match prepared stream")

    rf = []
    for word0, word1 in zip(pa0, pa1):
        for bit_index in range(64):
            bipolar0 = 1 if (word0 >> bit_index) & 1 else -1
            bipolar1 = 1 if (word1 >> bit_index) & 1 else -1
            rf.append(bipolar0 + 2 * bipolar1)
    ddc_phase = (1.0 + 0.0j, -1.0j, -1.0 + 0.0j, 1.0j)
    ddc = [2.0 * value * ddc_phase[index & 3]
           for index, value in enumerate(rf)]
    bandwidth_hz = 250e6
    fs4_coeff = _blackman_lowpass(0.75 * bandwidth_hz, RAW_FS_HZ, RX_FIR_TAPS)
    baseband_7g = _linear_fir_decimate(ddc, fs4_coeff, 2, phase=0)
    rx_coeff = _blackman_lowpass(0.75 * bandwidth_hz, RAW_FS_HZ / 2, RX_FIR_TAPS)
    baseband = _linear_fir_decimate(baseband_7g, rx_coeff, 4, phase=0)
    metrics = demodulate_metrics(baseband, stimulus)

    fs = RAW_FS_HZ
    segment = min(65536, 1 << (len(baseband_7g).bit_length() - 1))
    if segment < 4096:
        raise ValueError("not enough captured samples to evaluate PSD")
    start = max(0, (len(baseband_7g) - segment) // 2)
    values = baseband_7g[start:start + segment]
    spectrum = []
    transformed = fft(values)
    spectrum = [abs(value) ** 2 for value in transformed]
    freqs = [((k if k <= segment//2 else k-segment) * (fs/2) / segment)
             for k in range(segment)]
    main = sum(p for p, f in zip(spectrum, freqs) if abs(f) <= bandwidth_hz/2)
    adjacent = sum(p for p, f in zip(spectrum, freqs)
                   if bandwidth_hz/2 < abs(f) <= 1.5*bandwidth_hz)
    psd = [{"frequency_hz": f, "relative_db": 10*math.log10(max(p,1e-30)/max(main,1e-30))}
           for p, f in zip(spectrum, freqs)]
    result = {
        "source": "captured RTL PA0/PA1 words; independent Python receiver",
        "qam_order": 256,
        "seed": seed,
        "symbols": symbols,
        "source_rate_hz": 1.75e9,
        "raw_bit_rate_per_pa_hz": 64 * 218.75e6,
        "fs4_carrier_hz": RAW_FS_HZ / 4,
        "occupied_bandwidth_hz": bandwidth_hz,
        "receiver_filter_taps": RX_FIR_TAPS,
        "latency_cropped_7g_complex_samples": 0,
        "pa_words": len(pa0),
        "raw_rf_samples_after_latency_crop": len(rf),
        "ii": 1,
        "evm_percent": metrics["evm_percent"],
        "sndr_db": metrics["sndr_db"],
        "uncoded_ber_natural_binary": metrics["uncoded_ber_natural_binary"],
        "bit_errors": metrics["uncoded_bit_errors_natural_binary"],
        "bits_compared": metrics["qam_symbols"] * 8,
        "ber_95pct_upper_bound_if_zero": (3.0 / (metrics["qam_symbols"] * 8)
                                           if metrics["uncoded_bit_errors_natural_binary"] == 0 else None),
        "adjacent_band_proxy_dbc": 10*math.log10(max(adjacent,1e-30)/max(main,1e-30)),
        "psd_sample_rate_hz": RAW_FS_HZ/2,
        "psd_fft_size": segment,
        "relative_psd_db": psd,
        "latency_note": "capture begins at the first valid PA transaction, which corresponds to expected vector 0; transport latency does not remove serialized samples",
    }
    (run_dir / "qam256_rtl_capture_metrics.json").write_text(json.dumps(result, indent=2) + "\n")
    print("THERMO5_MASH_RTL_QAM256_EVALUATION_PASS evm_percent=%.6f sndr_db=%.4f ber=%.8g bit_errors=%d/%d" %
          (result["evm_percent"], result["sndr_db"], result["uncoded_ber_natural_binary"],
           result["bit_errors"], result["bits_compared"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "evaluate"))
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=281001)
    parser.add_argument("--symbols", type=int, default=8)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    args = parser.parse_args()
    if args.mode == "prepare":
        stimulus = prepare(args.run_dir, args.seed, args.symbols, args.rms_drive)
        print("THERMO5_MASH_AXIS_QAM_PREPARE_PASS beats=%d vectors=%d data=%d pad=%d" %
              (stimulus["axis_beats"], stimulus["frontend_words"],
               stimulus["data_samples"], stimulus["pad_samples_after_qam"]))
    else:
        evaluate(args.run_dir, args.seed, args.symbols, args.rms_drive)


if __name__ == "__main__":
    main()
