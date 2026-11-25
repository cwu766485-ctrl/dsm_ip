import unittest

from dsm_refmodel.mash11 import (
    Mash11Fixed,
    Mash11Float,
    MashObservation,
    one_sided_spectrum_dbfs,
    saturate_or_wrap,
    simulate_transactions,
)
from dsm_refmodel.thermo5 import mash11_weighted_plane_code


def assert_observation_matches(testcase, expected, observed):
    testcase.assertEqual(expected, observed)


class Mash11ReferenceTests(unittest.TestCase):
    def test_saturate_and_twos_complement_wrap_boundaries(self):
        self.assertEqual(saturate_or_wrap(128, 8, True), 127)
        self.assertEqual(saturate_or_wrap(-129, 8, True), -128)
        self.assertEqual(saturate_or_wrap(128, 8, False), -128)
        self.assertEqual(saturate_or_wrap(-129, 8, False), 127)

    def test_reset_and_idle_hold(self):
        model = Mash11Fixed(accumulator_width=18)
        initial = model.step(False, 123)
        self.assertFalse(initial.valid)
        first = model.step(True, 0)
        self.assertEqual((first.stage1_bit, first.stage2_bit,
                          first.combined_level), (1, 1, 2))
        held = model.step(False, -32768)
        self.assertFalse(held.valid)
        self.assertEqual((held.stage1_bit, held.stage2_bit,
                          held.combined_level, held.v1, held.v2),
                         (first.stage1_bit, first.stage2_bit,
                          first.combined_level, first.v1, first.v2))
        model.reset()
        self.assertEqual(model.step(True, 0), first)

    def test_bubbles_do_not_advance_transaction_state(self):
        dense = Mash11Fixed()
        sparse = Mash11Fixed()
        samples = [0, 32767, -32768, 1, -1, 12000, -12000]
        dense_outputs = [dense.step(True, sample) for sample in samples]
        sparse_outputs = []
        for sample in samples:
            sparse.step(False, 0)
            sparse_outputs.append(sparse.step(True, sample))
        self.assertEqual(dense_outputs, sparse_outputs)

    def test_directed_quantizer_levels_and_state_width(self):
        vectors = ([0] * 128 + [32767] * 128 + [-32768] * 128 +
                   [32767, -32768] * 128 + [0] * 128)
        model = Mash11Fixed(accumulator_width=18)
        observed = [model.step(True, value) for value in vectors]
        steady_levels = {-3, -1, 1, 3}
        for index, item in enumerate(observed):
            if index == 0:
                self.assertEqual(item.combined_level, 2)
            else:
                self.assertIn(item.combined_level, steady_levels)
        self.assertNotIn(-2, {item.combined_level for item in observed})
        self.assertNotIn(0, {item.combined_level for item in observed})
        low, high = -(1 << 17), (1 << 17) - 1
        self.assertTrue(all(low <= item.v1 <= high and low <= item.v2 <= high
                            for item in observed))
        self.assertGreater(len(set(item.combined_level for item in observed)), 1)

    def test_reset_epoch_discards_prior_state(self):
        samples = [32767] * 32 + [-32768] * 32
        reset_outputs = simulate_transactions(samples, reset_before=(32,))
        clean_second_epoch = simulate_transactions(samples[32:])
        self.assertEqual(reset_outputs[32:], clean_second_epoch)

    def test_mutation_check_detects_level_and_order_faults(self):
        model = Mash11Fixed()
        expected = [model.step(True, sample)
                    for sample in [0, 5000, -9000, 32767, -32768, 1, 1, 1]]
        flipped_level = list(expected)
        item = expected[3]
        flipped_level[3] = MashObservation(
            item.valid, item.stage1_bit, item.stage2_bit,
            -item.combined_level, item.sign_bit, item.v1, item.v2,
            item.e1, item.e2)
        reordered = list(expected)
        reordered[2], reordered[3] = reordered[3], reordered[2]
        with self.assertRaises(AssertionError):
            for ref, got in zip(expected, flipped_level):
                assert_observation_matches(self, ref, got)
        with self.assertRaises(AssertionError):
            for ref, got in zip(expected, reordered):
                assert_observation_matches(self, ref, got)

    def test_float_model_and_fixed_model_have_legal_cancellation_levels(self):
        fixed = Mash11Fixed()
        floating = Mash11Float()
        levels = []
        for sample in [0, 1, -1, 4096, -8192, 32767, -32768] * 32:
            f = floating.step(sample)
            q = fixed.step(True, sample)
            if not levels:
                self.assertIn(f["combined_level"], (0.0, 2.0))
                self.assertIn(q.combined_level, (0, 2))
            else:
                self.assertIn(f["combined_level"], (-3.0, -1.0, 1.0, 3.0))
                self.assertIn(q.combined_level, (-3, -1, 1, 3))
            levels.append(q.combined_level)
        self.assertGreater(len(set(levels)), 1)

    def test_weighted_pa_codebook_reconstructs_every_reachable_level(self):
        weights = (-3, -1, 1, 3)
        for level in (-3, -1, 1, 2, 3):
            code = mash11_weighted_plane_code(level)
            self.assertEqual(len(code), 4)
            self.assertEqual(sum(weight * bit
                                 for weight, bit in zip(weights, code)), level)
        for level in (-2, 0, 4):
            with self.assertRaises(ValueError):
                mash11_weighted_plane_code(level)

    def test_one_sided_spectrum_uses_peak_full_scale_amplitude(self):
        import math

        samples = [math.sin(2.0 * math.pi * 3 * index / 64) for index in range(64)]
        spectrum = one_sided_spectrum_dbfs(samples)
        self.assertAlmostEqual(spectrum[3], 0.0, places=10)
        self.assertEqual(one_sided_spectrum_dbfs([0.0] * 16),
                         [float("-inf")] * 9)


if __name__ == "__main__":
    unittest.main()
