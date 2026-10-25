#!/usr/bin/env python3
"""Exercise the frozen thermo5 RTL timing through raw TID planes to OFDM RX.

This standard-library-only benchmark audits all four TID planes against an
independent scalar EFM recurrence, reconstructs the 14-GS/s Fs/4 output,
downconverts it, applies a declared receive low-pass filter, and reports
256-QAM EVM/SNDR. It compares the frozen causal x2 FIR with a block-mode
centered-cubic candidate after the frozen TID contract passes.
"""

import argparse
import cmath
import json
import math
import random
from pathlib import Path

from dsm_refmodel.link_models import (
    BehavioralDPA,
    add_thermal_noise,
    apply_complex_fir,
)
from dsm_refmodel.thermo5 import (
    LANES_IN,
    Q14_ONE,
    run_frozen_frontend,
    saturate_signed,
)
from dsm_refmodel.thermo5_receiver import (
    audit_thermo5_plane_alignment,
    centered_cubic_stream_contract,
    interpolate_x4,
    run_tid_plane_stream,
    serialize_thermo5_plane_words,
)


SOURCE_FS_HZ = 1.75e9
RAW_FS_HZ = 14e9
OCCUPIED_BW_HZ = 250e6
NFFT = 4096
NCP = 512
ACTIVE_CARRIERS = 584
TID_STEP = 7168
TID_LATENCY_AFTER_FRONTEND_TRIM = 1024
GUARD_SAMPLES = 32 * 80
RX_FIR_TAPS = 4097
RX_CUTOFF_RATIO_OF_OCCUPIED_BW = 0.75
MAX_INPUT_DRIVE = 0.35
PA_OUTPUT_PROFILES = {
    "nominal": {
        "dpa_saturation": 0.82,
        "dpa_smoothness": 2.0,
        "dpa_ampm_degrees": 5.0,
        "dpa_envelope_memory": 0.15,
        "output_network_taps": (1.0 + 0.0j, 0.02 - 0.01j, 0.005 + 0.004j),
        "signal_power_dbm": -30.0,
        "noise_bandwidth_hz": OCCUPIED_BW_HZ,
        "noise_figure_db": 6.0,
        "temperature_k": 290.0,
    },
    "stress": {
        "dpa_saturation": 0.68,
        "dpa_smoothness": 1.7,
        "dpa_ampm_degrees": 10.0,
        "dpa_envelope_memory": 0.10,
        "output_network_taps": (1.0 + 0.0j, 0.07 - 0.035j, 0.02 + 0.015j),
        "signal_power_dbm": -50.0,
        "noise_bandwidth_hz": OCCUPIED_BW_HZ,
        "noise_figure_db": 10.0,
        "temperature_k": 290.0,
    },
}
_FIR_SPECTRUM_CACHE = {}


def fft(values, inverse=False):
    """In-place radix-2 Cooley-Tukey transform returned as a new list."""
    count = len(values)
    if count == 0 or count & (count - 1):
        raise ValueError("FFT size must be a nonzero power of two")
    out = list(values)
    j = 0
    for i in range(1, count):
        bit = count >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            out[i], out[j] = out[j], out[i]
    length = 2
    sign = 1.0 if inverse else -1.0
    while length <= count:
        step = cmath.exp(sign * 2.0j * math.pi / length)
        half = length >> 1
        for base in range(0, count, length):
            twiddle = 1.0 + 0.0j
            for offset in range(half):
                even = out[base + offset]
                odd = out[base + offset + half] * twiddle
                out[base + offset] = even + odd
                out[base + offset + half] = even - odd
                twiddle *= step
        length <<= 1
    if inverse:
        out = [value / count for value in out]
    return out


def _next_power_of_two(value):
    result = 1
    while result < value:
        result <<= 1
    return result


def make_256qam_ofdm(seed, symbols=8, bandwidth_hz=OCCUPIED_BW_HZ,
                     rms_drive=0.10):
    """Create 256-QAM OFDM at 1.75 GHz and Q1.15 quantize for the RTL model."""
    if symbols < 1 or rms_drive <= 0.0:
        raise ValueError("symbols and rms_drive must be positive")
    rng = random.Random(seed)
    spacing = SOURCE_FS_HZ / NFFT
    used = 2 * int(bandwidth_hz / (2.0 * spacing))
    if used < 2 or used % 2:
        raise ValueError("bandwidth must select an even, nonzero carrier count")
    edge = used // 2
    active_bins = list(range(-edge, 0)) + list(range(1, edge + 1))
    qam_rows = []
    time_rows = []
    qam_norm = math.sqrt(170.0)
    for _ in range(symbols):
        spectrum = [0.0j] * NFFT
        row = []
        for carrier in active_bins:
            value = rng.randrange(256)
            qam = complex(2 * (value % 16) - 15,
                          2 * (value // 16) - 15) / qam_norm
            spectrum[carrier % NFFT] = qam
            row.append(qam)
        samples = fft(spectrum, inverse=True)
        row_with_cp = samples[-NCP:] + samples
        qam_rows.append(row)
        time_rows.extend(row_with_cp)

    rms = math.sqrt(sum(abs(value) ** 2 for value in time_rows) /
                    max(1, len(time_rows)))
    scale = rms_drive / max(rms, 1e-30)
    waveform = [value * scale for value in time_rows]
    peak = max(abs(value) for value in waveform)
    if peak > MAX_INPUT_DRIVE:
        raise ValueError("OFDM peak %.6f exceeds the %.3f input-drive limit" %
                         (peak, MAX_INPUT_DRIVE))
    quantized = [
        (saturate_signed(int(round(value.real * 32767.0)), 16),
         saturate_signed(int(round(value.imag * 32767.0)), 16))
        for value in waveform
    ]
    guard = [(0, 0)] * GUARD_SAMPLES
    framed = guard + quantized + guard
    if len(framed) % LANES_IN:
        raise ValueError("guarded frame must align to eight source lanes")
    actual_bw = used * spacing
    return {
        "seed": int(seed),
        "symbols": int(symbols),
        "active_bins": active_bins,
        "qam_rows": qam_rows,
        "source_iq": framed,
        "data_start": GUARD_SAMPLES,
        "data_samples": len(quantized),
        "input_rms": math.sqrt(sum((i * i + q * q) for i, q in quantized) /
                                max(1, len(quantized))) / 32768.0,
        "input_peak": peak,
        "rms_drive_target": float(rms_drive),
        "actual_bandwidth_hz": actual_bw,
        "guard_samples": GUARD_SAMPLES,
    }


def _frontend_words(source_iq):
    i_words = []
    q_words = []
    for first in range(0, len(source_iq), LANES_IN):
        chunk = source_iq[first:first + LANES_IN]
        i_words.append([sample[0] for sample in chunk])
        q_words.append([sample[1] for sample in chunk])
    starts = [0] * len(i_words)
    gains = [Q14_ONE] * len(i_words)
    return i_words, q_words, starts, gains


def _expand_iq_x4(source_iq, method):
    source_i = [sample[0] for sample in source_iq]
    source_q = [sample[1] for sample in source_iq]
    pairs = list(zip(source_i, source_q))
    expanded = interpolate_x4(pairs, method=method)
    return [sample[0] for sample in expanded], [sample[1] for sample in expanded]


def _make_plane_words(stimulus, method):
    if method == "rtl2":
        i_words, q_words, starts, gains = _frontend_words(stimulus["source_iq"])
        plane_words = run_frozen_frontend(
            i_words, q_words, starts, gains, interp_taps=2, step=TID_STEP)
        # Independently expand the front-end sample stream for the scalar TID
        # state recurrence check. This also checks Python block/sample ordering.
        expected_i, expected_q = _expand_iq_x4(stimulus["source_iq"], "rtl2")
    elif method == "centered_cubic":
        expected_i, expected_q = _expand_iq_x4(
            stimulus["source_iq"], "centered_cubic")
        plane_words = run_tid_plane_stream(
            expected_i, expected_q, step=TID_STEP, drop_first_word=True,
            append_flush=True)
    else:
        raise ValueError("unknown candidate: " + method)
    audit = audit_thermo5_plane_alignment(
        plane_words, expected_i, expected_q, step=TID_STEP,
        latency_samples=TID_LATENCY_AFTER_FRONTEND_TRIM)
    return plane_words, expected_i, expected_q, audit


def _blackman_lowpass(cutoff_hz, sample_rate_hz, taps):
    if taps < 3 or taps % 2 == 0:
        raise ValueError("FIR tap count must be odd and at least three")
    midpoint = (taps - 1) // 2
    ratio = 2.0 * cutoff_hz / sample_rate_hz
    coefficients = []
    for index in range(taps):
        offset = index - midpoint
        if offset == 0:
            ideal = ratio
        else:
            ideal = math.sin(math.pi * ratio * offset) / (math.pi * offset)
        window = (0.42 - 0.5 * math.cos(2.0 * math.pi * index / (taps - 1)) +
                  0.08 * math.cos(4.0 * math.pi * index / (taps - 1)))
        coefficients.append(ideal * window)
    total = sum(coefficients)
    return [value / total for value in coefficients]


def _linear_fir_decimate(samples, coefficients, decimation, phase=0):
    """Centered, zero-phase linear FIR convolution followed by decimation."""
    if decimation < 1 or not 0 <= phase < decimation:
        raise ValueError("invalid decimation or phase")
    convolution_size = len(samples) + len(coefficients) - 1
    transform_size = _next_power_of_two(convolution_size)
    x = list(samples) + [0.0j] * (transform_size - len(samples))
    x_spectrum = fft(x)
    cache_key = (transform_size, tuple(coefficients))
    h_spectrum = _FIR_SPECTRUM_CACHE.get(cache_key)
    if h_spectrum is None:
        h = [complex(value, 0.0) for value in coefficients]
        h.extend([0.0j] * (transform_size - len(h)))
        h_spectrum = fft(h)
        _FIR_SPECTRUM_CACHE[cache_key] = h_spectrum
    product = [left * right for left, right in zip(x_spectrum, h_spectrum)]
    convolution = fft(product, inverse=True)
    delay = (len(coefficients) - 1) // 2
    count = (len(samples) - phase + decimation - 1) // decimation
    return [convolution[delay + phase + decimation * index]
            for index in range(count)]


def reconstruct_baseband_7g(plane_words, actual_bandwidth_hz,
                            latency_samples=TID_LATENCY_AFTER_FRONTEND_TRIM,
                            fir_taps=RX_FIR_TAPS):
    """Reconstruct the four-branch-sum complex baseband at 7 GHz."""
    raw = serialize_thermo5_plane_words(plane_words)
    crop = 2 * int(latency_samples)
    if len(raw) <= crop:
        raise ValueError("raw TID stream is shorter than its declared latency")
    raw = raw[crop:]
    # The crop is an integer multiple of four raw samples, so resetting this
    # NCO phase preserves the absolute Fs/4 phase.
    ddc = []
    phase = (1.0 + 0.0j, -1.0j, -1.0 + 0.0j, 1.0j)
    for index, value in enumerate(raw):
        ddc.append(2.0 * float(value) * phase[index & 3])
    cutoff = RX_CUTOFF_RATIO_OF_OCCUPIED_BW * actual_bandwidth_hz
    coefficients = _blackman_lowpass(cutoff, RAW_FS_HZ, fir_taps)
    baseband_7g = _linear_fir_decimate(ddc, coefficients, 2, phase=0)
    return baseband_7g, {
        "raw_sample_rate_hz": RAW_FS_HZ,
        "complex_baseband_sample_rate_hz": RAW_FS_HZ / 2.0,
        "carrier_hz": RAW_FS_HZ / 4.0,
        "latency_samples_at_7ghz_complex_rate": int(latency_samples),
        "latency_cropped_raw_samples": crop,
        "fs4_reconstruction_filter": "Blackman-windowed linear-phase FIR, centered offline",
        "fs4_filter_taps": int(fir_taps),
        "fs4_filter_cutoff_hz": cutoff,
        "decimation": 2,
        "decimation_phase": 0,
    }


def receive_filter_decimate(baseband_7g, actual_bandwidth_hz,
                            fir_taps=RX_FIR_TAPS):
    """Apply receiver channel filter and decimate complex 7-GHz baseband by 4."""
    cutoff = RX_CUTOFF_RATIO_OF_OCCUPIED_BW * actual_bandwidth_hz
    coefficients = _blackman_lowpass(cutoff, RAW_FS_HZ / 2.0, fir_taps)
    return _linear_fir_decimate(baseband_7g, coefficients, 4, phase=0), {
        "receiver_filter": "Blackman-windowed linear-phase FIR, centered offline",
        "receiver_filter_taps": int(fir_taps),
        "receiver_filter_cutoff_hz": cutoff,
        "input_sample_rate_hz": RAW_FS_HZ / 2.0,
        "output_sample_rate_hz": SOURCE_FS_HZ,
        "decimation": 4,
        "decimation_phase": 0,
    }


def reconstruct_baseband(plane_words, actual_bandwidth_hz,
                         latency_samples=TID_LATENCY_AFTER_FRONTEND_TRIM,
                         fir_taps=RX_FIR_TAPS):
    """Deserialize raw planes and recover the source-rate complex baseband."""
    baseband_7g, fs4_config = reconstruct_baseband_7g(
        plane_words, actual_bandwidth_hz, latency_samples, fir_taps)
    baseband, rx_config = receive_filter_decimate(
        baseband_7g, actual_bandwidth_hz, fir_taps)
    return baseband, {"fs4": fs4_config, "receiver": rx_config}


def demodulate_metrics(baseband, stimulus):
    """Measure OFDM QAM EVM and in-band SNDR with one global complex gain."""
    data_start = stimulus["data_start"]
    data_end = data_start + stimulus["data_samples"]
    received = baseband[data_start:data_end]
    frame_size = NFFT + NCP
    expected_count = stimulus["symbols"] * frame_size
    if len(received) != expected_count:
        raise ValueError("receiver sample count does not match the OFDM frame")
    received_qam = []
    expected_qam = []
    for symbol in range(stimulus["symbols"]):
        start = symbol * frame_size + NCP
        time_samples = received[start:start + NFFT]
        spectrum = fft(time_samples)
        for carrier_index, carrier in enumerate(stimulus["active_bins"]):
            received_qam.append(spectrum[carrier % NFFT])
            expected_qam.append(stimulus["qam_rows"][symbol][carrier_index])
    output_energy = sum(abs(value) ** 2 for value in received_qam)
    cross = sum(expected * actual.conjugate()
                for actual, expected in zip(received_qam, expected_qam))
    gain = cross / max(output_energy, 1e-30)
    error_energy = sum(abs(gain * actual - expected) ** 2
                       for actual, expected in zip(received_qam, expected_qam))
    raw_error_energy = sum(abs(actual - expected) ** 2
                           for actual, expected in zip(received_qam, expected_qam))
    reference_energy = sum(abs(value) ** 2 for value in expected_qam)
    evm = math.sqrt(error_energy / max(reference_energy, 1e-30))
    raw_evm = math.sqrt(raw_error_energy / max(reference_energy, 1e-30))
    constellation_scale = math.sqrt(170.0)
    symbol_errors = 0
    bit_errors = 0
    for actual, expected in zip(received_qam, expected_qam):
        corrected = gain * actual
        actual_i = min(15, max(0, int(math.floor(
            (corrected.real * constellation_scale + 15.0) / 2.0 + 0.5))))
        actual_q = min(15, max(0, int(math.floor(
            (corrected.imag * constellation_scale + 15.0) / 2.0 + 0.5))))
        expected_i = min(15, max(0, int(math.floor(
            (expected.real * constellation_scale + 15.0) / 2.0 + 0.5))))
        expected_q = min(15, max(0, int(math.floor(
            (expected.imag * constellation_scale + 15.0) / 2.0 + 0.5))))
        actual_index = actual_i | (actual_q << 4)
        expected_index = expected_i | (expected_q << 4)
        difference = actual_index ^ expected_index
        symbol_errors += int(difference != 0)
        while difference:
            bit_errors += difference & 1
            difference >>= 1
    symbol_count = len(expected_qam)
    return {
        "qam_symbols": symbol_count,
        "global_complex_equalizer": [gain.real, gain.imag],
        "raw_evm_percent": 100.0 * raw_evm,
        "evm_percent": 100.0 * evm,
        "sndr_db": -20.0 * math.log10(max(evm, 1e-30)),
        "symbol_errors": symbol_errors,
        "symbol_error_rate": symbol_errors / max(1, symbol_count),
        "uncoded_bit_errors_natural_binary": bit_errors,
        "uncoded_ber_natural_binary": bit_errors / max(1, 8 * symbol_count),
        "gain_corrected_error_energy": error_energy,
        "reference_energy": reference_energy,
    }


def run_candidate(stimulus, method, fir_taps=RX_FIR_TAPS):
    plane_words, expected_i, expected_q, audit = _make_plane_words(stimulus, method)
    if audit["mismatches"]:
        raise RuntimeError("TID plane/scalar EFM contract mismatch: %d/%d" %
                           (audit["mismatches"], audit["compared_samples"]))
    baseband_7g, fs4_config = reconstruct_baseband_7g(
        plane_words, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    baseband, rx_config = receive_filter_decimate(
        baseband_7g, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
    metrics = demodulate_metrics(baseband, stimulus)
    normalized_pa_input = [value / 4.0 for value in baseband_7g]
    pa_input_rms = math.sqrt(sum(abs(value) ** 2 for value in normalized_pa_input) /
                             max(1, len(normalized_pa_input)))
    analog_results = []
    for profile_index, (profile_name, profile) in enumerate(PA_OUTPUT_PROFILES.items()):
        dpa = BehavioralDPA(
            saturation=profile["dpa_saturation"],
            smoothness=profile["dpa_smoothness"],
            ampm_degrees=profile["dpa_ampm_degrees"],
            envelope_memory=profile["dpa_envelope_memory"],
        )
        deterministic_output = dpa.process(normalized_pa_input)
        deterministic_output = apply_complex_fir(
            deterministic_output, profile["output_network_taps"])
        deterministic_received, analog_rx_config = receive_filter_decimate(
            deterministic_output, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        deterministic_metrics = demodulate_metrics(deterministic_received, stimulus)
        noisy_output, noise = add_thermal_noise(
            deterministic_output,
            random.Random(stimulus["seed"] + profile_index * 7919),
            signal_power_dbm=profile["signal_power_dbm"],
            bandwidth_hz=profile["noise_bandwidth_hz"],
            noise_figure_db=profile["noise_figure_db"],
            temperature_k=profile["temperature_k"],
        )
        analog_received, analog_rx_config = receive_filter_decimate(
            noisy_output, stimulus["actual_bandwidth_hz"], fir_taps=fir_taps)
        analog_results.append({
            "profile": profile_name,
            "assumptions": {
                key: [[tap.real, tap.imag] for tap in value]
                if key == "output_network_taps" else value
                for key, value in profile.items()
            },
            "metrics_after_dpa_and_output_network": deterministic_metrics,
            "metrics_after_output_noise_and_rx_filter": demodulate_metrics(
                analog_received, stimulus),
            "thermal_noise": noise,
            "receiver": analog_rx_config,
        })
    return {
        "candidate": method,
        "plane_words": len(plane_words),
        "interpolated_complex_samples": len(expected_i),
        "tid_scalar_efm_audit": audit,
        "fs4_reconstruction": fs4_config,
        "receiver": rx_config,
        "normalized_pa_input_rms": pa_input_rms,
        "digital_metrics": metrics,
        "analog_profiles": analog_results,
    }


def run(seed=101, symbols=8, candidates=("rtl2", "centered_cubic"),
        fir_taps=RX_FIR_TAPS, rms_drive=0.10):
    stimulus = make_256qam_ofdm(seed, symbols, rms_drive=rms_drive)
    results = []
    # The frozen RTL path is measured first and acts as the contract gate.
    ordered = ("rtl2",) + tuple(candidate for candidate in candidates
                                 if candidate != "rtl2")
    for candidate in ordered:
        results.append(run_candidate(stimulus, candidate, fir_taps))
    return {
        "benchmark": "thermo5_raw_tid_to_ofdm_receiver",
        "seed": int(seed),
        "symbols": int(symbols),
        "source_rate_hz": SOURCE_FS_HZ,
        "input_rms": stimulus["input_rms"],
        "input_peak": stimulus["input_peak"],
        "rms_drive_target": stimulus["rms_drive_target"],
        "input_peak_limit": MAX_INPUT_DRIVE,
        "nfft": NFFT,
        "cyclic_prefix": NCP,
        "qam_order": 256,
        "active_subcarriers": ACTIVE_CARRIERS,
        "requested_bandwidth_hz": OCCUPIED_BW_HZ,
        "actual_bandwidth_hz": stimulus["actual_bandwidth_hz"],
        "step": TID_STEP,
        "guard_samples_each_side": stimulus["guard_samples"],
        "centered_cubic_stream_contract": centered_cubic_stream_contract(8),
        "candidates": results,
        "scope": [
            "Frozen digital front-end and actual four 64-bit TID output planes are included for rtl2.",
            "The scalar EFM recurrence is an independent bit-level timing oracle; all branch/component mismatches must be zero before receiver metrics are accepted.",
            "The Fs/4 receiver uses the actual serialized plane sum, an Fs/4 DDC, a declared 14-GHz reconstruction FIR, and a 7-GHz receiver FIR before decimation.",
            "Digital EVM/SNDR include fixed-point interpolation, TID quantization, raw serialization, DDC, and receive filtering.",
            "Nominal/stress DPA, output-network, and kTB+NF cases are illustrative behavioral models after the reconstructed four-branch average; they are not calibrated circuit/board predictions.",
            "Centered cubic is block-mode and uses zero extension; streaming lookahead and final-frame drain remain separate implementation questions.",
        ],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=int, default=101)
    parser.add_argument("--symbols", type=int, default=8)
    parser.add_argument("--candidates", default="rtl2,centered_cubic")
    parser.add_argument("--rx-fir-taps", type=int, default=RX_FIR_TAPS)
    parser.add_argument("--rms-drive", type=float, default=0.10)
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()
    candidates = tuple(value.strip() for value in args.candidates.split(",")
                       if value.strip())
    if args.symbols < 1 or not candidates:
        parser.error("symbols must be positive and at least one candidate is required")
    if any(value not in ("rtl2", "centered_cubic") for value in candidates):
        parser.error("candidates must be rtl2 and/or centered_cubic")
    if args.rx_fir_taps < 3 or args.rx_fir_taps % 2 == 0:
        parser.error("--rx-fir-taps must be odd and at least three")
    if args.rms_drive <= 0.0:
        parser.error("--rms-drive must be positive")
    result = run(args.seed, args.symbols, candidates, args.rx_fir_taps,
                 args.rms_drive)
    rendered = json.dumps(result, indent=2, sort_keys=True)
    print(rendered)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(rendered + "\n")


if __name__ == "__main__":
    main()
