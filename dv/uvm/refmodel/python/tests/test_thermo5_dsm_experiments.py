import math
import random
import unittest

from dsm_refmodel.thermo5 import tid_word_ef2
from dsm_refmodel.thermo5_experiments import (
    _error_feedback_quantize_ef2_fixed,
    generate_thermo5_tidsm_planes,
)
from dsm_refmodel.thermo5_receiver import audit_thermo5_plane_alignment
from benchmark_thermo5_step_ntf import _aggregate
from benchmark_thermo5_ef2_robust import _variant
from benchmark_thermo5_tid_receiver import make_256qam_ofdm


class Thermo5DsmExperimentTests(unittest.TestCase):
    def test_rtl_first_order_step_mode_matches_scalar_oracle(self):
        rng = random.Random(17)
        samples_i = [rng.randint(-9000, 9000) for _ in range(64)]
        samples_q = [rng.randint(-9000, 9000) for _ in range(64)]
        step = 6144
        planes, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, step, mode="rtl_first_order",
            rtl_latency_samples=32)
        audit = audit_thermo5_plane_alignment(
            planes, samples_i, samples_q, step=step, latency_samples=32)
        self.assertEqual(audit["mismatches"], 0)
        self.assertEqual(audit["compared_samples"], 256)
        self.assertEqual(stats["alignment_latency_samples"], 32)

    def test_second_order_error_feedback_has_observed_q4_15_headroom(self):
        samples_i = [0] * 1024
        samples_q = [0] * 1024
        _, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 7168, mode="ef_order2")
        self.assertTrue(stats["finite"])
        self.assertEqual(stats["ntf"], "(1-z^-1)^2")
        self.assertLess(stats["max_abs_error_state"], 8.0)
        self.assertLess(stats["max_abs_quantizer_input"], 8.0)

    def test_fixed_ef2_state_width_sweep_changes_only_saturation_rails(self):
        samples = [30000] * 128
        results = {}
        for state_width in (18, 19, 20):
            output, stats = _error_feedback_quantize_ef2_fixed(
                samples, 0, state_width=state_width)
            results[state_width] = (output, stats)
        self.assertGreater(results[18][1]["state_saturation_samples"], 0)
        self.assertGreater(results[19][1]["state_saturation_samples"], 0)
        self.assertEqual(results[20][1]["state_saturation_samples"], 0)
        self.assertEqual(results[20][1]["state_width_bits"], 20)
        self.assertNotEqual(results[18][0], results[20][0])
        self.assertNotEqual(results[20][1]["fixed_point"],
                            results[18][1]["fixed_point"])

    def test_fixed_ef2_stream_matches_word_bittrue_model_and_stays_unsaturated(self):
        rng = random.Random(29)
        samples_i = [rng.randint(-7000, 7000) for _ in range(128)]
        samples_q = [rng.randint(-7000, 7000) for _ in range(128)]
        planes, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 5120, mode="ef_order2_fixed")
        float_planes, _ = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 5120, mode="ef_order2")
        states = None
        expected = []
        for first in range(0, len(samples_i), 32):
            word, states, _ = tid_word_ef2(
                samples_i[first:first + 32], samples_q[first:first + 32],
                states=states, width=16, step=5120)
            expected.append(tuple(word))
        self.assertEqual(planes, expected)
        self.assertEqual(planes, float_planes)
        self.assertEqual(stats["state_saturation_samples"], 0)
        self.assertLess(stats["max_abs_error_state"], 8.0)
        self.assertLess(stats["max_abs_quantizer_input"], 8.0)

    def test_third_order_error_feedback_exposes_instability(self):
        samples_i = [0] * 1024
        samples_q = [0] * 1024
        _, stats = generate_thermo5_tidsm_planes(
            samples_i, samples_q, 7168, mode="ef_order3")
        self.assertTrue(stats["finite"])
        self.assertGreater(stats["max_abs_error_state"], 1e6)
        self.assertGreater(stats["max_abs_quantizer_input"], 1e6)

    def test_software_candidate_is_not_reported_as_rtl_audited(self):
        record = {
            "mode": "ef_order2",
            "step": 5120,
            "digital_metrics": {
                "evm_percent": 2.4,
                "sndr_db": 32.4,
                "symbol_errors": 0,
                "qam_symbols": 584,
                "uncoded_bit_errors_natural_binary": 0,
            },
            "ef_q4_15_observed_headroom_pass": True,
            "scalar_rtl_audit": None,
            "analog_profiles": [],
        }
        summary = _aggregate([record])[0]
        self.assertIsNone(summary["all_seed_scalar_rtl_audit_pass"])
        self.assertTrue(summary["all_seed_q4_15_observed_headroom_pass"])

    def test_benchmark_summary_ranks_bit_error_rate_before_evm(self):
        def record(step, bit_errors, evm):
            return {
                "mode": "ef_order2_fixed",
                "step": step,
                "state_width_bits": 20,
                "digital_metrics": {
                    "evm_percent": evm,
                    "sndr_db": 30.0,
                    "symbol_errors": bit_errors,
                    "qam_symbols": 100,
                    "uncoded_bit_errors_natural_binary": bit_errors,
                },
                "ef_q4_15_observed_headroom_pass": True,
                "scalar_rtl_audit": None,
                "analog_profiles": [],
            }
        summary = _aggregate([record(5120, 0, 2.8), record(5248, 1, 2.0)])
        self.assertEqual(summary[0]["step"], 5120)

    def test_joint_input_backoff_and_papr_clipping_are_applied_before_dsm(self):
        stimulus = make_256qam_ofdm(701, symbols=2, rms_drive=0.10)
        variant = _variant(stimulus, backoff_db=3, papr_limit_db=7)
        self.assertGreater(variant["input_clip_samples"], 0)
        self.assertLess(variant["input_rms"], stimulus["input_rms"])
        original_papr = 20.0 * math.log10(
            stimulus["input_peak"] / stimulus["input_rms"])
        self.assertLess(variant["input_papr_db"], original_papr)
        self.assertLessEqual(variant["input_papr_db"], 7.1)
        self.assertLessEqual(variant["input_peak"], stimulus["input_peak"])


if __name__ == "__main__":
    unittest.main()
