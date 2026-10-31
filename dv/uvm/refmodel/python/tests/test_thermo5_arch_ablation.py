import unittest

from benchmark_thermo5_arch_ablation import run


class Thermo5ArchitectureAblationTest(unittest.TestCase):
    def test_four_architecture_cells_share_seed_and_receiver_contract(self):
        result = run(
            development_seeds=(271001,), heldout_seeds=(281001,), symbols=1,
            rms_drive=0.10, rx_fir_taps=31, profiles=("nominal",),
            first_order_steps=(5120,))

        expected = {
            "first_order_causal_step5120",
            "first_order_centered_cubic_step5120",
            "ef2_causal_step5120",
            "ef2_centered_cubic_step5120",
        }
        self.assertEqual(
            {row["architecture"] for row in result["summaries"]}, expected)
        self.assertEqual(len(result["summaries"]), 8)
        self.assertEqual(len(result["records"]), 8)
        self.assertTrue(all(row["digital"]["qam_symbols"] == 584
                            for row in result["records"]))
        self.assertTrue(all(row["input_rms"] <= 0.35
                            for row in result["records"]))
        self.assertTrue(all(row["receiver"]["channel_filter"]["receiver_filter_taps"] == 31
                            for row in result["records"]))
        self.assertTrue(all(row["state_width_bits"] == 20
                            for row in result["records"]
                            if row["tidsm"] == "ef2"))
        self.assertEqual({row["partition"] for row in result["summaries"]},
                         {"development", "heldout"})
        self.assertEqual({row["seed_count"] for row in result["summaries"]}, {1})
        self.assertEqual(len(result["spectra"]), 8)

    def test_development_and_heldout_seeds_must_be_disjoint(self):
        with self.assertRaisesRegex(ValueError, "must be disjoint"):
            run(development_seeds=(7,), heldout_seeds=(7,), symbols=1,
                rx_fir_taps=31, profiles=("nominal",),
                first_order_steps=(5120,))


if __name__ == "__main__":
    unittest.main()
