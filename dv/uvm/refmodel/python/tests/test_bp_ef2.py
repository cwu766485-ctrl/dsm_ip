import unittest

from dsm_refmodel import (BpEf2, ComplexCoeff, Fs4Mixer, TxBpEf2Model,
                          interp_frontend, memory_poly, saturate_signed, wrap_signed)
from generate_performance_sku_vectors import MEMORY_DPD_COEFFICIENTS


class FixedPointTest(unittest.TestCase):
    def test_saturate_and_wrap(self) -> None:
        self.assertEqual(saturate_signed(140, 8), 127)
        self.assertEqual(saturate_signed(-140, 8), -128)
        self.assertEqual(wrap_signed(128, 8), -128)
        self.assertEqual(wrap_signed(-129, 8), 127)


class Fs4MixerTest(unittest.TestCase):
    def test_phase_sequence(self) -> None:
        mixer = Fs4Mixer()
        values = [mixer.step(100, -25) for _ in range(4)]
        self.assertEqual(values, [(0, 100), (1, -25), (2, -100), (3, 25)])

    def test_minimum_value_negation_wraps(self) -> None:
        mixer = Fs4Mixer()
        mixer.phase = 2
        self.assertEqual(mixer.step(-32768, 0), (2, -32768))


class BpEf2Test(unittest.TestCase):
    def test_registered_trace_is_one_sample_behind_core_trace(self) -> None:
        model = BpEf2()
        steps = [model.step(value) for value in (1000, -2000, 3000, -4000)]
        self.assertEqual(steps[0].registered_bit, 1)
        for previous, current in zip(steps, steps[1:]):
            self.assertEqual(current.registered_bit, previous.core_bit)

    def test_reset_restores_state(self) -> None:
        model = TxBpEf2Model()
        for _ in range(9):
            model.step(1234, -5678)
        model.reset()
        self.assertEqual(model.mixer.phase, 0)
        self.assertEqual(model.dsm.error_1, 0)
        self.assertEqual(model.dsm.error_2, 0)
        self.assertEqual(model.dsm.output_bit, 1)


class InterpAndDpdTest(unittest.TestCase):
    def test_mode_ratios(self) -> None:
        values = [1000, -2000, 3000]
        self.assertEqual(len(interp_frontend(values, 0)), 3)
        self.assertEqual(len(interp_frontend(values, 1)), 12)
        self.assertEqual(len(interp_frontend(values, 2)), 24)
        self.assertEqual(len(interp_frontend(values, 3)), 48)
        self.assertEqual(len(interp_frontend(values, 4)), 96)

    def test_memory_poly_history_and_saturation(self) -> None:
        unity = [ComplexCoeff(16384, 0)]
        zero = [ComplexCoeff(0, 0)]
        out_i, out_q, saturated = memory_poly([1000, -2000], [500, -250], unity, zero, zero,
                                               active_taps=1)
        self.assertEqual(out_i, [1000, -2000])
        self.assertEqual(out_q, [500, -250])
        self.assertEqual(saturated, [False, False])

    def test_memory_dpd_system_package_is_safe_and_non_identity(self) -> None:
        c1 = [ComplexCoeff(*tap[0]) for tap in MEMORY_DPD_COEFFICIENTS]
        c3 = [ComplexCoeff(*tap[1]) for tap in MEMORY_DPD_COEFFICIENTS]
        c5 = [ComplexCoeff(*tap[2]) for tap in MEMORY_DPD_COEFFICIENTS]
        for coefficient in (*c1, *c3, *c5):
            self.assertLessEqual(abs(coefficient.real), 24576)
            self.assertLessEqual(abs(coefficient.imag), 24576)
        input_i = [4096, -4096, 2048, -2048]
        input_q = [-2048, 2048, -1024, 1024]
        output_i, output_q, saturated = memory_poly(
            input_i, input_q, c1, c3, c5, active_taps=4,
        )
        self.assertFalse(any(saturated))
        self.assertNotEqual(list(zip(output_i, output_q)), list(zip(input_i, input_q)))


if __name__ == "__main__":
    unittest.main()
