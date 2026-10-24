import random
import unittest

from dsm_refmodel.thermo5 import Q14_ONE, run_frozen_frontend
from dsm_refmodel.thermo5_receiver import (
    audit_thermo5_plane_alignment,
    centered_cubic_stream_contract,
    decode_fs4_branch_word,
    interpolate_x2_centered_cubic,
    interpolate_x2_rtl,
    interpolate_x4,
    run_tid_plane_stream,
    serialize_thermo5_plane_words,
)


class Thermo5ReceiverTests(unittest.TestCase):
    def test_rtl2_odd_phase_is_current_previous_average(self):
        samples = [(0, 20), (100, 40), (200, 60), (300, 80)]
        self.assertEqual(interpolate_x2_rtl(samples, 2), [
            (0, 20), (0, 10), (100, 40), (50, 30),
            (200, 60), (150, 50), (300, 80), (250, 70),
        ])

    def test_centered_cubic_uses_half_sample_lagrange_midpoint(self):
        samples = [(10 * index, -4 * index) for index in range(8)]
        output = interpolate_x2_centered_cubic(samples)
        self.assertEqual(output[2 * 3 + 1], (35, -14))
        self.assertEqual(output[2 * 5 + 1], (55, -22))

    def test_fs4_decode_removes_alternating_iq_polarity(self):
        expected_i = [1 if index % 3 else -1 for index in range(32)]
        expected_q = [-1 if index % 4 else 1 for index in range(32)]
        word = 0
        for index, (sample_i, sample_q) in enumerate(zip(expected_i, expected_q)):
            raw_i = sample_i if index % 2 == 0 else -sample_i
            raw_q = -sample_q if index % 2 == 0 else sample_q
            if raw_i > 0:
                word |= 1 << (2 * index)
            if raw_q > 0:
                word |= 1 << (2 * index + 1)
        decoded_i, decoded_q = decode_fs4_branch_word(word)
        self.assertEqual(decoded_i, expected_i)
        self.assertEqual(decoded_q, expected_q)

    def test_four_plane_serial_sum_is_lsb_first_bipolar(self):
        words = [[1, 0, 0, 0]]
        raw = serialize_thermo5_plane_words(words)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[0], -2)
        self.assertEqual(raw[1], -4)

    def test_centered_cubic_stream_lookahead_and_frame_tail(self):
        contract = centered_cubic_stream_contract(8)
        self.assertEqual(contract["max_future_dependency_source_samples"], 2.25)
        self.assertEqual(contract["required_integer_source_sample_lookahead"], 3)
        self.assertEqual(contract["zero_source_samples_to_flush_at_frame_end"], 3)
        self.assertEqual(contract["additional_input_words_to_lookahead"], 1)

    def test_centered_x4_frame_tail_matches_three_zero_flush(self):
        samples = [(index * 1700 - 5000, 4000 - index * 900)
                   for index in range(16)]
        actual = interpolate_x4(samples, method="centered_cubic")
        padded = samples + [(0, 0)] * 3
        stage = interpolate_x2_centered_cubic(padded)
        flushed = interpolate_x2_centered_cubic(stage)[:4 * len(samples)]
        self.assertEqual(actual, flushed)

    def test_frozen_frontend_plane_stream_matches_scalar_efm_timing(self):
        rng = random.Random(19)
        source_i = [[rng.randint(-9000, 9000) for _ in range(8)]
                    for _ in range(75)]
        source_q = [[rng.randint(-9000, 9000) for _ in range(8)]
                    for _ in range(75)]
        starts = [0] * len(source_i)
        gains = [Q14_ONE] * len(source_i)
        words = run_frozen_frontend(source_i, source_q, starts, gains,
                                    interp_taps=2, step=7168)
        flat_i = [sample for word in source_i for sample in word]
        flat_q = [sample for word in source_q for sample in word]
        expanded = interpolate_x4(list(zip(flat_i, flat_q)), method="rtl2")
        expected_i = [sample[0] for sample in expanded]
        expected_q = [sample[1] for sample in expanded]
        audit = audit_thermo5_plane_alignment(
            words, expected_i, expected_q, step=7168, latency_samples=1024)
        self.assertEqual(audit["mismatches"], 0)
        self.assertGreater(audit["compared_samples"], 0)
        separated_words = run_tid_plane_stream(
            expected_i, expected_q, step=7168, drop_first_word=True,
            append_flush=True)
        self.assertEqual(words, separated_words)


if __name__ == "__main__":
    unittest.main()
