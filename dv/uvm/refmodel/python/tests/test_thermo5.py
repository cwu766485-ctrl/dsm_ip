import tempfile
import unittest

from dsm_refmodel.thermo5 import (
    generate_source_vectors,
    interpolate_centered_cubic_x4,
    interp_x2_vector,
    read_source_vectors,
    round_shift_symmetric,
    run_frozen_frontend,
    run_centered_cubic_frontend,
    apply_memory_polynomial,
    nonlinear_test_dpd_coefficients,
    write_vectors,
)


class Thermo5ReferenceTests(unittest.TestCase):
    def test_rounding_is_symmetric_with_ties_away_from_zero(self):
        self.assertEqual(round_shift_symmetric(8192, 14), 1)
        self.assertEqual(round_shift_symmetric(-8192, 14), -1)
        self.assertEqual(round_shift_symmetric(8191, 14), 0)
        self.assertEqual(round_shift_symmetric(-8191, 14), 0)

    def test_tap_presets_preserve_constant_after_warmup(self):
        for taps in (2, 3, 4):
            history_i = [1234] * (taps - 1)
            history_q = [-2345] * (taps - 1)
            out_i, out_q, _, _ = interp_x2_vector(
                [1234] * 8, [-2345] * 8, history_i, history_q, taps)
            self.assertEqual(out_i, [1234] * 16)
            self.assertEqual(out_q, [-2345] * 16)

    def test_vector_chunking_preserves_interpolator_state(self):
        for taps in (2, 3, 4):
            source_i = [17 * n - 93 for n in range(16)]
            source_q = [101 - 11 * n for n in range(16)]
            history_i = [0] * (taps - 1)
            history_q = [0] * (taps - 1)
            vector_i, vector_q = [], []
            for start in (0, 8):
                out_i, out_q, history_i, history_q = interp_x2_vector(
                    source_i[start:start + 8], source_q[start:start + 8],
                    history_i, history_q, taps)
                vector_i.extend(out_i)
                vector_q.extend(out_q)

            history_i = [0] * (taps - 1)
            history_q = [0] * (taps - 1)
            sample_i, sample_q = [], []
            for start in range(0, 16, 4):
                out_i, out_q, history_i, history_q = interp_x2_vector(
                    source_i[start:start + 4], source_q[start:start + 4],
                    history_i, history_q, taps)
                sample_i.extend(out_i)
                sample_q.extend(out_q)
            self.assertEqual(vector_i, sample_i)
            self.assertEqual(vector_q, sample_q)

    def test_python_vector_files_round_trip_and_output_count(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=12, seed=7, profile="range_stress",
            frame_start_words=(1, 7, 12))
        outputs = run_frozen_frontend(i_words, q_words, starts, gains, interp_taps=2)
        self.assertEqual(len(outputs), 12)
        self.assertTrue(all(len(word) == 4 for word in outputs))
        with tempfile.TemporaryDirectory() as root:
            write_vectors(root, i_words, q_words, starts, gains, outputs)
            recovered = read_source_vectors(root)
            self.assertEqual(recovered, (i_words, q_words, starts, gains))

    def test_centered_cubic_x4_preserves_exact_phase_and_length(self):
        samples = [(17 * index, -9 * index) for index in range(32)]
        output = interpolate_centered_cubic_x4(samples)
        self.assertEqual(len(output), 4 * len(samples))
        self.assertEqual(output[0::4], samples)

    def test_centered_frontend_oracle_has_one_pa_word_per_source_word(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=56, seed=113, frame_start_words=(1, 15, 36),
            frame_gains=(16384, 14336, 12288))
        output = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        self.assertEqual(len(output), 56)
        self.assertTrue(all(len(word) == 4 for word in output))

    def test_memory_polynomial_unity_and_nonlinear_q_formats(self):
        samples = [(16384, 0), (0, -8192), (12000, 7000)]
        unity = {
            "c1_re": (16384, 0, 0, 0), "c1_im": (0, 0, 0, 0),
            "c3_re": (0, 0, 0, 0), "c3_im": (0, 0, 0, 0),
            "c5_re": (0, 0, 0, 0), "c5_im": (0, 0, 0, 0),
        }
        output, _, saturated = apply_memory_polynomial(samples, unity, 1)
        self.assertEqual(output, samples)
        self.assertEqual(saturated, 0)

        nonlinear = nonlinear_test_dpd_coefficients()
        output, _, _ = apply_memory_polynomial([(16384, 0)], nonlinear, 2)
        self.assertEqual(output, [(16896, 0)])
        output, _, _ = apply_memory_polynomial(
            [(16384, 0), (0, 0)], nonlinear, 2)
        self.assertEqual(output[1], (1152, 0))

    def test_centered_frontend_non_linear_dpd_changes_bit_true_output(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=56, seed=610211, frame_start_words=(1,),
            frame_gains=(16384,))
        identity = run_centered_cubic_frontend(i_words, q_words, starts, gains)
        nonlinear = run_centered_cubic_frontend(
            i_words, q_words, starts, gains,
            dpd_coefficients=nonlinear_test_dpd_coefficients(),
            dpd_active_taps=2)
        self.assertEqual(len(nonlinear), 56)
        self.assertNotEqual(nonlinear, identity)

    def test_centered_frontend_rejects_unaligned_frame_start(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=14, seed=23, frame_start_words=(1, 3))
        with self.assertRaisesRegex(ValueError, "align to 7-word"):
            run_centered_cubic_frontend(i_words, q_words, starts, gains)


if __name__ == "__main__":
    unittest.main()
