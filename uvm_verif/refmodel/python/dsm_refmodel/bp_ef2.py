"""Bit-exact Fs/4 mixer and one-bit band-pass EF2 DSM models."""

from collections import namedtuple

from .fixed import check_signed, saturate_signed, wrap_signed


BpEf2Step = namedtuple("BpEf2Step", [
    "registered_bit", "core_bit", "signed_output", "quantizer_input", "error_1", "error_2",
])


class Fs4Mixer:
    def __init__(self, width=16, phase=0):
        self.width = width
        self.phase = phase

    def reset(self):
        self.phase = 0

    def step(self, i_value, q_value):
        i_value = check_signed(i_value, self.width, "i_value")
        q_value = check_signed(q_value, self.width, "q_value")
        phase = self.phase
        if phase == 0:
            output = i_value
        elif phase == 1:
            output = q_value
        elif phase == 2:
            output = wrap_signed(-i_value, self.width)
        else:
            output = wrap_signed(-q_value, self.width)
        self.phase = (self.phase + 1) & 0x3
        return phase, output


class BpEf2:
    def __init__(self, input_width=16, accumulator_width=28, input_shift=0,
                 saturate=True, error_1=0, error_2=0, output_bit=1):
        self.input_width = input_width
        self.accumulator_width = accumulator_width
        self.input_shift = input_shift
        self.saturate = saturate
        self.error_1 = error_1
        self.error_2 = error_2
        self.output_bit = output_bit

    @property
    def positive_level(self):
        return (1 << (self.input_width - 1)) - 1

    def reset(self):
        self.error_1 = 0
        self.error_2 = 0
        self.output_bit = 1

    def step(self, sample):
        sample = check_signed(sample, self.input_width, "sample")
        registered_bit = self.output_bit
        shifted = sample >> self.input_shift
        raw = shifted - self.error_2
        if self.saturate:
            quantizer_input = saturate_signed(raw, self.accumulator_width)
        else:
            quantizer_input = wrap_signed(raw, self.accumulator_width)

        core_bit = int(quantizer_input >= 0)
        signed_output = self.positive_level if core_bit else -self.positive_level
        error_0 = wrap_signed(
            quantizer_input - signed_output, self.accumulator_width
        )
        self.error_2 = self.error_1
        self.error_1 = error_0
        self.output_bit = core_bit
        return BpEf2Step(
            registered_bit=registered_bit,
            core_bit=core_bit,
            signed_output=signed_output,
            quantizer_input=quantizer_input,
            error_1=self.error_1,
            error_2=self.error_2,
        )


BpEf4Step = namedtuple("BpEf4Step", [
    "registered_bit", "core_bit", "signed_output", "quantizer_input",
])


class BpEf4:
    """Bit-exact experimental Fs/4 EF4 core with NTF (1 + z^-2)^2."""

    def __init__(self, input_width=16, accumulator_width=28, input_shift=0,
                 saturate=True):
        self.input_width = input_width
        self.accumulator_width = accumulator_width
        self.input_shift = input_shift
        self.saturate = saturate
        self.reset()

    @property
    def positive_level(self):
        return (1 << (self.input_width - 1)) - 1

    def reset(self):
        self.error_1 = self.error_2 = self.error_3 = self.error_4 = 0
        self.output_bit = 1

    def step(self, sample):
        sample = check_signed(sample, self.input_width, "sample")
        registered_bit = self.output_bit
        raw = (sample >> self.input_shift) - 2 * self.error_2 - self.error_4
        if self.saturate:
            quantizer_input = saturate_signed(raw, self.accumulator_width)
        else:
            quantizer_input = wrap_signed(raw, self.accumulator_width)
        core_bit = int(quantizer_input >= 0)
        signed_output = self.positive_level if core_bit else -self.positive_level
        error_0 = wrap_signed(
            quantizer_input - signed_output, self.accumulator_width
        )
        self.error_4 = self.error_3
        self.error_3 = self.error_2
        self.error_2 = self.error_1
        self.error_1 = error_0
        self.output_bit = core_bit
        return BpEf4Step(
            registered_bit=registered_bit,
            core_bit=core_bit,
            signed_output=signed_output,
            quantizer_input=quantizer_input,
        )


TxBpEf2Step = namedtuple("TxBpEf2Step", [
    "phase", "if_sample", "registered_bit", "rf_bit", "rf_signed", "quantizer_input",
])


class TxBpEf2Model:
    def __init__(self, mixer=None, dsm=None):
        self.mixer = mixer if mixer is not None else Fs4Mixer()
        self.dsm = dsm if dsm is not None else BpEf2()

    def reset(self):
        self.mixer.reset()
        self.dsm.reset()

    def step(self, i_value, q_value):
        phase, if_sample = self.mixer.step(i_value, q_value)
        dsm_step = self.dsm.step(if_sample)
        return TxBpEf2Step(
            phase=phase,
            if_sample=if_sample,
            registered_bit=dsm_step.registered_bit,
            rf_bit=dsm_step.core_bit,
            rf_signed=dsm_step.signed_output,
            quantizer_input=dsm_step.quantizer_input,
        )
