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
    tid_word_ef2,
    apply_memory_polynomial,
    nonlinear_test_dpd_coefficients,
    nonlinear_test_dpd_coefficients_4tap,
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

    def test_four_tap_nonlinear_dpd_image_runs_through_centered_frontend(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=56, seed=612004, frame_start_words=(1,), frame_gains=(16384,))
        coefficients = nonlinear_test_dpd_coefficients_4tap()
        self.assertEqual(len(coefficients["c1_re"]), 4)
        self.assertTrue(all(coefficients["c1_re"][tap] != 0 for tap in range(4)))
        self.assertTrue(all(coefficients["c3_re"][tap] != 0 for tap in range(4)))
        output = run_centered_cubic_frontend(
            i_words, q_words, starts, gains, dpd_coefficients=coefficients,
            dpd_active_taps=4, tidsm_order=2)
        self.assertEqual(len(output), 56)
        self.assertTrue(all(len(word) == 4 for word in output))

    def test_ef2_frontend_produces_one_fixed_point_word_per_input(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=14, seed=227, frame_start_words=(1,), frame_gains=(16384,))
        output = run_frozen_frontend(
            i_words, q_words, starts, gains, interp_taps=2,
            step=5120, tidsm_order=2)
        self.assertEqual(len(output), len(i_words))
        self.assertTrue(all(len(word) == 4 for word in output))
        self.assertTrue(all(0 <= plane < (1 << 64)
                            for word in output for plane in word))

    def test_ef2_saturated_state_contains_rail_initial_conditions(self):
        state_min, state_max = -(1 << 19), (1 << 19) - 1
        states = [{"i": [state_max, state_min], "q": [state_min, state_max]}
                  for _ in range(4)]
        samples_i = [32767 if lane % 2 else -32768 for lane in range(32)]
        samples_q = [-32768 if lane % 2 else 32767 for lane in range(32)]
        _, states, diagnostics = tid_word_ef2(
            samples_i, samples_q, states=states, step=0)
        self.assertGreater(sum(
            row[component]["state_saturation_samples"]
            for row in diagnostics for component in ("i", "q")), 0)
        for branch in states:
            for component in ("i", "q"):
                self.assertTrue(all(state_min <= value <= state_max
                                    for value in branch[component]))

    def test_fixed_ef2_centered_frontend_has_no_frame_tail_word(self):
        i_words, q_words, starts, gains = generate_source_vectors(
            words=14, seed=228, frame_start_words=(1,), frame_gains=(16384,))
        output = run_centered_cubic_frontend(
            i_words, q_words, starts, gains, step=5120, tidsm_order=2)
        self.assertEqual(len(output), len(i_words))

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
