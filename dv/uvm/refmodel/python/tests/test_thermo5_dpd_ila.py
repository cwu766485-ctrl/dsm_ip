import unittest

from fit_thermo5_dpd_ila import (
    _quantize_coefficients,
    fit_ila,
    solve_complex_system,
)


class Thermo5DpdIlaTest(unittest.TestCase):
    def test_complex_solver(self):
        solution, stats = solve_complex_system(
            [[2 + 0j, 1j], [-1j, 3 + 0j]], [1 + 2j, 4 - 1j])
        self.assertAlmostEqual(2 * solution[0] + 1j * solution[1], 1 + 2j)
        self.assertAlmostEqual(-1j * solution[0] + 3 * solution[1], 4 - 1j)
        self.assertGreater(stats["pivot_ratio"], 0.0)

    def test_q214_quantizer_clips_to_signed_coefficient_range(self):
        coefficients, clips = _quantize_coefficients(
            [2.5 + 0j, -2.5j, 0.125 + 0.25j], 1)
        self.assertEqual(coefficients["c1_re"][0], 32767)
        self.assertEqual(coefficients["c1_im"][0], 0)
        self.assertEqual(coefficients["c3_re"][0], 0)
        self.assertEqual(coefficients["c3_im"][0], -32768)
        self.assertEqual(coefficients["c5_re"][0], 2048)
        self.assertEqual(coefficients["c5_im"][0], 4096)
        self.assertEqual(clips, 2)

    def test_fit_returns_hardware_width_candidate_arrays(self):
        result = fit_ila((271001,), symbols=2, rms_drive=0.10,
                         taps=2, samples_per_seed=512)
        self.assertEqual(result["active_taps"], 2)
        self.assertEqual(set(result["coefficients"]),
                         {"c1_re", "c1_im", "c3_re", "c3_im", "c5_re", "c5_im"})
        self.assertTrue(all(len(values) == 4 for values in
                            result["coefficients"].values()))
        self.assertEqual(result["fit"]["coefficient_format"],
                         "signed Q2.14, int16 saturation")


if __name__ == "__main__":
    unittest.main()
