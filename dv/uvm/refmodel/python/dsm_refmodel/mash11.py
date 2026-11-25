"""Independent MASH 1-1 models for the V1.3 verification experiments.

The implementation is organized around quantizer decisions and delayed error
terms, rather than mirroring the RTL's signal/process structure. Integer mode
uses the MATLAB P0 SKU's 16-bit input and 18-bit saturating accumulator.
"""

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class MashObservation:
    valid: bool
    stage1_bit: int
    stage2_bit: int
    combined_level: int
    sign_bit: int
    v1: int
    v2: int
    e1: int
    e2: int


def signed_value(value, bits):
    value = int(value) & ((1 << bits) - 1)
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def saturate_or_wrap(value, bits, saturate):
    low, high = -(1 << (bits - 1)), (1 << (bits - 1)) - 1
    if saturate:
        return min(max(int(value), low), high)
    return signed_value(value, bits)


class Mash11Fixed:
    """Bit-true transaction model of the legacy fixed-point MASH 1-1 SKU."""

    def __init__(self, input_width=16, accumulator_width=18, input_shift=0,
                 saturate=True):
        if accumulator_width < input_width or input_shift < 0:
            raise ValueError("invalid MASH width or input shift")
        self.input_width = input_width
        self.accumulator_width = accumulator_width
        self.input_shift = input_shift
        self.saturate = bool(saturate)
        self.reset()

    def reset(self):
        self._e1 = self._e2 = self._e1_to_stage2 = 0
        self._previous_stage1_pm = 1
        self._previous_stage2_pm = 0
        self._previous_stage1_bit = 1
        self._out = MashObservation(False, 1, 1, 1, 1, 0, 0, 0, 0)

    def step(self, valid, sample=0):
        if not valid:
            held = self._out
            self._out = MashObservation(False, held.stage1_bit,
                held.stage2_bit, held.combined_level, held.sign_bit,
                held.v1, held.v2, held.e1, held.e2)
            return self._out

        x = signed_value(sample, self.input_width) >> self.input_shift
        q_positive = (1 << (self.input_width - 1)) - 1
        q_negative = -q_positive

        # First stage maps the input plus accumulated residue to one of two
        # rails. Its error becomes feedback for stage one and a delayed input
        # to stage two.
        v1 = saturate_or_wrap(x + self._e1, self.accumulator_width,
                              self.saturate)
        stage1_bit_now = int(v1 >= 0)
        stage1_pm_now = 1 if stage1_bit_now else -1
        e1_next = v1 - (q_positive if stage1_bit_now else q_negative)

        # Stage two consumes the prior first-stage residue. A separate delay
        # in the output combiner cancels its quantization noise.
        v2 = saturate_or_wrap(self._e1_to_stage2 + self._e2,
                              self.accumulator_width, self.saturate)
        stage2_bit_now = int(v2 >= 0)
        stage2_pm_now = 1 if stage2_bit_now else -1
        e2_next = v2 - (q_positive if stage2_bit_now else q_negative)
        combined = self._previous_stage1_pm + stage2_pm_now - self._previous_stage2_pm

        self._out = MashObservation(
            True, self._previous_stage1_bit, stage2_bit_now, combined,
            int(combined >= 0), v1, v2, e1_next, e2_next)
        self._e1, self._e2 = e1_next, e2_next
        self._e1_to_stage2 = e1_next
        self._previous_stage1_pm = stage1_pm_now
        self._previous_stage2_pm = stage2_pm_now
        self._previous_stage1_bit = stage1_bit_now
        return self._out


class Mash11Float:
    """Floating-point algorithm model with ideal bipolar quantizers."""

    def __init__(self, input_scale=32767.0):
        if input_scale <= 0:
            raise ValueError("input_scale must be positive")
        self.input_scale = float(input_scale)
        self.reset()

    def reset(self):
        self._e1 = self._e2 = self._e1_to_stage2 = 0.0
        self._previous_stage1_pm = 1.0
        self._previous_stage2_pm = 0.0
        self._previous_stage1_bit = 1

    def step(self, sample, valid=True):
        if not valid:
            return None
        x = float(sample) / self.input_scale
        v1 = x + self._e1
        q1 = 1.0 if v1 >= 0.0 else -1.0
        e1_next = v1 - q1
        v2 = self._e1_to_stage2 + self._e2
        q2 = 1.0 if v2 >= 0.0 else -1.0
        e2_next = v2 - q2
        level = self._previous_stage1_pm + q2 - self._previous_stage2_pm
        observation = {
            "stage1_bit": self._previous_stage1_bit,
            "stage2_bit": int(q2 > 0),
            "combined_level": level,
            "sign_bit": int(level >= 0),
            "v1": v1,
            "v2": v2,
        }
        self._e1, self._e2, self._e1_to_stage2 = e1_next, e2_next, e1_next
        self._previous_stage1_pm = q1
        self._previous_stage2_pm = q2
        self._previous_stage1_bit = int(q1 > 0)
        return observation


def simulate_transactions(samples, valid=None, reset_before=(), **model_args):
    """Return valid-qualified MASH observations, including explicit resets."""
    samples = list(samples)
    if valid is None:
        valid = [True] * len(samples)
    if len(valid) != len(samples):
        raise ValueError("valid mask length must match samples")
    reset_before = set(reset_before)
    model = Mash11Fixed(**model_args)
    outputs = []
    for index, (sample, is_valid) in enumerate(zip(samples, valid)):
        if index in reset_before:
            model.reset()
        outputs.append(model.step(is_valid, sample))
    return outputs


def one_sided_spectrum_dbfs(samples, full_scale=1.0):
    """Return a rectangular-window one-sided amplitude spectrum in dBFS.

    ``full_scale`` is the peak amplitude represented as 0 dBFS. This helper
    reports deterministic coherent-bin levels only; it does not define SNR,
    SNDR, EVM, ACLR, or an RF measurement setup.
    """
    values = [float(value) for value in samples]
    if len(values) < 2:
        raise ValueError("at least two samples are required")
    if full_scale <= 0.0:
        raise ValueError("full_scale must be positive")
    if not any(values):
        return [float("-inf")] * (len(values) // 2 + 1)
    result = []
    for bin_index in range(len(values) // 2 + 1):
        real = sum(value * math.cos(2.0 * math.pi * bin_index * n / len(values))
                   for n, value in enumerate(values))
        imag = -sum(value * math.sin(2.0 * math.pi * bin_index * n / len(values))
                    for n, value in enumerate(values))
        edge_bin = bin_index == 0 or (len(values) % 2 == 0 and bin_index == len(values) // 2)
        amplitude = math.hypot(real, imag) / len(values) * (1.0 if edge_bin else 2.0)
        result.append(20.0 * math.log10(max(amplitude / full_scale, 1e-30)))
    return result
