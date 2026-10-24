import random
import unittest

from benchmark_thermo5_interp import metrics as interpolation_metrics
from benchmark_thermo5_link import _symbol_metrics, run
from dsm_refmodel.link_models import (
    BehavioralDPA,
    add_thermal_noise,
    apply_complex_fir,
    inject_gt_plane_bit_errors,
    thermal_noise_dbm,
)
from dsm_refmodel.thermo5 import generate_source_vectors, run_frozen_frontend


class LinkModelTests(unittest.TestCase):
    def test_gt_no_error_preserves_bittrue_four_plane_words(self):
        source = generate_source_vectors(words=12, seed=2,
                                         frame_start_words=(1,),
                                         frame_gains=(16384,))
        planes = run_frozen_frontend(*source, interp_taps=2)
        output, stats = inject_gt_plane_bit_errors(planes, random.Random(1))
        self.assertEqual(output, planes)
        self.assertEqual(stats["flipped_bits"], 0)
        self.assertEqual(stats["serialized_data_bits"], 4 * 64 * len(planes))
        self.assertEqual(stats["affected_words"], 0)

    def test_gt_ber_one_flips_every_bit_in_every_plane(self):
        planes = [[0x0123456789ABCDEF] * 4, [0x0] * 4]
        output, stats = inject_gt_plane_bit_errors(
            planes, random.Random(2), ber=1.0)
        self.assertEqual(output[0], [value ^ ((1 << 64) - 1)
                                     for value in planes[0]])
        self.assertEqual(output[1], [(1 << 64) - 1] * 4)
        self.assertEqual(stats["flipped_bits"], 4 * 64 * len(planes))
        self.assertEqual(stats["affected_words"], len(planes))

    def test_dpa_and_output_network_are_deterministic(self):
        samples = [0.0j, complex(0.3, -0.4), complex(-0.2, 0.1)]
        dpa_a = BehavioralDPA(saturation=0.5)
        dpa_b = BehavioralDPA(saturation=0.5)
        self.assertEqual(dpa_a.process(samples), dpa_b.process(samples))
        filtered = apply_complex_fir(samples, (1.0, 0.5j))
        self.assertEqual(filtered, [0.0j, complex(0.3, -0.4),
                                    complex(0.0, 0.25)])

    def test_thermal_noise_uses_kTB_and_is_seed_reproducible(self):
        self.assertAlmostEqual(thermal_noise_dbm(1.0, temperature_k=290.0),
                               -173.975, places=2)
        samples = [1.0 + 0.0j] * 1000
        a, stats_a = add_thermal_noise(
            samples, random.Random(3), signal_power_dbm=-30.0,
            bandwidth_hz=1e6, noise_figure_db=5.0)
        b, stats_b = add_thermal_noise(
            samples, random.Random(3), signal_power_dbm=-30.0,
            bandwidth_hz=1e6, noise_figure_db=5.0)
        self.assertEqual(a, b)
        self.assertEqual(stats_a, stats_b)
        self.assertAlmostEqual(stats_a["noise_power_dbm"], -108.975, places=2)
        self.assertGreater(stats_a["realized_normalized_noise_power"], 0.0)

    def test_thermal_noise_rejects_zero_normalized_reference(self):
        with self.assertRaises(ValueError):
            add_thermal_noise([0j, 0j], random.Random(4),
                              signal_power_dbm=-20.0,
                              bandwidth_hz=1e6)

    def test_gain_phase_fit_removes_a_complex_scalar(self):
        reference = [1.0 + 0.5j, -0.25 + 0.75j, 0.5 - 1.0j, -0.75 - 0.25j]
        phase_shifted = [value * complex(0.8, 0.6) for value in reference]
        raw_error, fitted_error = _symbol_metrics(phase_shifted, reference)[:2]
        self.assertGreater(raw_error, 0.0)
        self.assertLess(fitted_error, 1e-24)

    def test_interpolation_evm_fit_corrects_phase_direction(self):
        reference = [0.25 + 0.5j, -0.125 + 0.75j,
                     0.5 - 0.25j, -0.75 - 0.125j]
        shifted = [value * complex(0.8, 0.6) for value in reference]
        output = [(round(value.real * 32768), round(value.imag * 32768))
                  for value in shifted]
        result = interpolation_metrics(output, reference)
        self.assertGreater(result["error_energy"], 0.0)
        self.assertLess(result["fitted_error_energy"], 1e-8)

    def test_custom_profile_records_analog_overrides(self):
        result = run(symbols=1, seed=4, profiles=("custom",),
                     custom_overrides={"signal_power_dbm": -42.0,
                                       "noise_enabled": False,
                                       "dpa": False,
                                       "output_filter_taps": [[1.0, 0.0]]})
        profile = result["profiles"][0]
        self.assertEqual(profile["assumptions"]["signal_power_dbm"], -42.0)
        result_row = profile["results"][0]
        self.assertIsNone(result_row["thermal_noise"])
        self.assertEqual(result_row["digital_interpolation"],
                         result_row["after_dpa_and_output_network"])


if __name__ == "__main__":
    unittest.main()
