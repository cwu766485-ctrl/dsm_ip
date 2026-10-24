"""Behavioral digital-link and analog-output models for thermo5 screening.

GT bit errors operate on the four 64-bit TID planes and are discrete digital
faults. The DPA and output network are deterministic complex-envelope models.
Thermal noise is added at a declared analog observation plane using kTB, noise
figure, and signal power. None of these models replaces vendor GT simulation,
ADS, transistor-level simulation, or measured hardware characterization.
"""

import cmath
import math


BOLTZMANN_J_PER_K = 1.380649e-23


def inject_gt_plane_bit_errors(plane_words, rng, ber=0.0):
    """Flip serialized data bits in four-plane TID words with independent BER.

    ``plane_words`` is a sequence of words, each containing four unsigned
    64-bit values. Bit position zero is a transmitted data bit; the function
    does not model line coding, CDR, jitter, eye closure, or burst errors.
    """
    if not 0.0 <= ber <= 1.0:
        raise ValueError("BER must be between zero and one")
    mask = (1 << 64) - 1
    output = []
    plane_flips = [0, 0, 0, 0]
    affected_words = 0
    for word in plane_words:
        if len(word) != 4:
            raise ValueError("each TID word must contain four planes")
        output_word = []
        word_changed = False
        for plane_index, plane in enumerate(word):
            plane = int(plane)
            if not 0 <= plane <= mask:
                raise ValueError("each plane value must fit in 64 bits")
            corrupted = plane
            if ber:
                for bit in range(64):
                    if rng.random() < ber:
                        corrupted ^= 1 << bit
                        plane_flips[plane_index] += 1
            output_word.append(corrupted)
            word_changed = word_changed or corrupted != plane
        output.append(output_word)
        affected_words += int(word_changed)

    bit_count = 4 * 64 * len(plane_words)
    flipped_bits = sum(plane_flips)
    return output, {
        "serialized_data_bits": bit_count,
        "flipped_bits": flipped_bits,
        "observed_ber": flipped_bits / max(1, bit_count),
        "plane_bit_flips": plane_flips,
        "affected_words": affected_words,
        "word_error_rate": affected_words / max(1, len(plane_words)),
    }


class BehavioralDPA:
    """Deterministic Rapp-like AM/AM and AM/PM model with envelope memory.

    Inputs are normalized complex-envelope samples. ``saturation`` is in the
    same normalized units. Envelope memory is a one-pole state on input power;
    it is a tunable behavioral approximation, not a fitted transistor model.
    """

    def __init__(self, saturation=0.82, smoothness=2.0, ampm_degrees=5.0,
                 envelope_memory=0.15):
        if saturation <= 0.0 or smoothness <= 0.0:
            raise ValueError("saturation and smoothness must be positive")
        if not 0.0 < envelope_memory <= 1.0:
            raise ValueError("envelope_memory must be in (0, 1]")
        self.saturation = float(saturation)
        self.smoothness = float(smoothness)
        self.ampm_radians = math.radians(ampm_degrees)
        self.envelope_memory = float(envelope_memory)
        self.envelope_power = 0.0

    def process(self, samples):
        output = []
        for sample in samples:
            input_power = abs(sample) ** 2
            self.envelope_power = (
                (1.0 - self.envelope_memory) * self.envelope_power +
                self.envelope_memory * input_power)
            envelope = math.sqrt(self.envelope_power)
            ratio = envelope / self.saturation
            compressed = envelope / (1.0 + ratio ** (2.0 * self.smoothness)) ** (
                1.0 / (2.0 * self.smoothness))
            gain = compressed / envelope if envelope > 1e-15 else 1.0
            phase = self.ampm_radians * ratio * ratio / (1.0 + ratio * ratio)
            output.append(sample * gain * cmath.exp(1j * phase))
        return output


def apply_complex_fir(samples, taps):
    """Apply a deterministic complex-envelope output network from zero state."""
    taps = tuple(complex(tap) for tap in taps)
    if not taps:
        raise ValueError("output network must contain at least one tap")
    history = [0.0j] * (len(taps) - 1)
    output = []
    for sample in samples:
        values = (complex(sample),) + tuple(history)
        output.append(sum(tap * value for tap, value in zip(taps, values)))
        if history:
            history = [complex(sample)] + history[:-1]
    return output


def thermal_noise_dbm(bandwidth_hz, noise_figure_db=0.0,
                      temperature_k=290.0):
    """Return available thermal-noise power plus NF over the given bandwidth."""
    if bandwidth_hz <= 0.0:
        raise ValueError("noise bandwidth must be positive")
    if temperature_k <= 0.0:
        raise ValueError("temperature must be positive")
    noise_watts = (BOLTZMANN_J_PER_K * float(temperature_k) *
                   float(bandwidth_hz))
    return 10.0 * math.log10(noise_watts / 1e-3) + float(noise_figure_db)


def add_thermal_noise(samples, rng, signal_power_dbm, bandwidth_hz,
                      noise_figure_db=0.0, temperature_k=290.0):
    """Add complex Gaussian noise referenced to an analog output plane.

    The waveform is normalized, so ``signal_power_dbm`` supplies its physical
    average power at the observation plane. The kTB+NF noise power is converted
    to normalized complex-envelope variance using the measured input sequence's
    mean-square magnitude. Returns noisy samples and noise bookkeeping.
    """
    signal_power = sum(abs(value) ** 2 for value in samples) / max(1, len(samples))
    if signal_power <= 0.0:
        if not samples:
            return [], {
                "noise_power_dbm": thermal_noise_dbm(
                    bandwidth_hz, noise_figure_db, temperature_k),
                "normalized_noise_power": 0.0,
                "normalized_snr_db": None,
                "realized_normalized_noise_power": 0.0,
            }
        raise ValueError("cannot scale physical noise to a zero-power waveform")

    noise_dbm = thermal_noise_dbm(bandwidth_hz, noise_figure_db, temperature_k)
    snr_db = float(signal_power_dbm) - noise_dbm
    normalized_noise_power = signal_power * 10.0 ** (-snr_db / 10.0)
    sigma = math.sqrt(normalized_noise_power / 2.0)
    noise = [complex(rng.gauss(0.0, sigma), rng.gauss(0.0, sigma))
             for _ in samples]
    output = [value + error for value, error in zip(samples, noise)]
    realized_noise_power = sum(abs(value) ** 2 for value in noise) / len(noise)
    return output, {
        "signal_power_dbm": float(signal_power_dbm),
        "noise_power_dbm": noise_dbm,
        "bandwidth_hz": float(bandwidth_hz),
        "noise_figure_db": float(noise_figure_db),
        "temperature_k": float(temperature_k),
        "normalized_noise_power": normalized_noise_power,
        "normalized_snr_db": snr_db,
        "realized_normalized_noise_power": realized_noise_power,
    }
