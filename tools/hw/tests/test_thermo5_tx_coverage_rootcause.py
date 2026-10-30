import json
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_coverage_rootcause import (
    branch_path_context,
    audited_source_position,
    root_cause_for_row,
    ROOT,
    source_bound_branch_context,
    validate_diagnostic_instrumentation,
)


class BranchPathContextTests(unittest.TestCase):
    def test_nested_dpd_path_points_to_saturation_counter(self):
        predicates = (
            "1:199 if (!rst_n) begin; "
            "2:225 end else if (pipe_ce) begin; "
            "3:328 if (in_valid) begin; "
            "4:337 if (valid_pipe[PIPE_STAGES-1] && (sat_i || sat_q)) begin"
        )

        context = branch_path_context("0/1/-/1", predicates)

        self.assertEqual(context["branch_target_line"], "337")
        self.assertIn("sat_i || sat_q", context["branch_target_expression"])
        self.assertEqual(
            context["branch_predicate_path"],
            "1:199 if (!rst_n) begin=0 ; 2:225 end else if (pipe_ce) begin=1 ; "
            "4:337 if (valid_pipe[PIPE_STAGES-1] && (sat_i || sat_q)) begin=1",
        )

    def test_else_if_saturation_points_to_negative_limit(self):
        predicates = (
            "1:415 if (din > MAX_VAL) begin; "
            "2:418 end else if (din < MIN_VAL) begin"
        )

        context = branch_path_context("0/1", predicates)

        self.assertEqual(context["branch_target_line"], "418")
        self.assertIn("din < MIN_VAL", context["branch_target_expression"])

    def test_case_default_uses_mapped_case_source(self):
        context = branch_path_context("default", "1:135 case (addr & 8'hf8)")

        self.assertEqual(context["branch_target_line"], "135")
        self.assertEqual(context["branch_target_expression"], "case (addr & 8'hf8)")

    def test_dpd_saturation_is_not_classified_as_reset(self):
        row = {
            "metric": "branch",
            "source_files": "rtl/dpd/dpd_memory_poly.v",
            "evidence_hint": "OPEN_PROJECT_BIN_REVIEW",
            "reason": "Needs legal stimulus/checker/URG hit or specific proof; do not exclude.",
        }
        branch = {
            "branch_target_expression": "if (valid_pipe[PIPE_STAGES-1] && (sat_i || sat_q)) begin"
        }

        category, hypothesis, action = root_cause_for_row(row, branch)

        self.assertEqual(category, "IDENTITY_DPD_ARITHMETIC")
        self.assertIn("saturation event", hypothesis)
        self.assertIn("independent checker", action)

    def test_parameter_branch_uses_exact_source_expression(self):
        predicates = '1:294 if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2");'
        context = branch_path_context("1", predicates)
        context = source_bound_branch_context(
            context, predicates, "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv"
        )
        row = {
            "metric": "branch",
            "source_files": "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
            "evidence_hint": "OPEN_PROJECT_BIN_REVIEW",
            "reason": "Needs legal stimulus/checker/URG hit or specific proof; do not exclude.",
        }

        category, _, _ = root_cause_for_row(row, context)

        self.assertIn("LANES < 2", context["branch_target_expression"])
        self.assertEqual(category, "FIXED_PRODUCT_CONFIGURATION")

    def test_centered_interpolator_single_entry_pop_push_stays_product_open(self):
        row = {
            "metric": "branch",
            "source_files": "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",
            "evidence_hint": "OPEN_PROJECT_BIN_REVIEW",
            "reason": "Needs legal stimulus/checker/URG hit or specific proof; do not exclude.",
        }
        branch = {
            "branch_target_line": "255",
            "branch_target_expression": "end else if (push_input) begin",
            "branch_predicate_path": (
                "1:182 if (!rst_n) begin=0 ; 2:201 end else if (!enable) begin=0 ; "
                "8:234 if (pop_head) begin=1 ; 9:235 if (q_count == 2) begin=0 ; "
                "11:255 end else if (push_input) begin=1"
            ),
        }

        category, hypothesis, action = root_cause_for_row(row, branch)

        self.assertEqual(category, "PRODUCT_CADENCE_ALIGNMENT")
        self.assertIn("stage-level Formal cover", hypothesis)
        self.assertIn("end-to-end Formal cover witness", action)
        self.assertIn("Keep the Raw bin OPEN", action)

    def test_diagnostic_instrumentation_requires_exact_product_and_source_hashes(self):
        evidence_path = ROOT / "docs/verification/data/thermo5-tx-frame-replacement-coverage-review.json"
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))

        accepted = validate_diagnostic_instrumentation(
            evidence_path, evidence["product_source_sha"]
        )
        self.assertEqual(accepted["review"], "Centered-Cubic product frame-boundary pop/push Branch stimulus review")

        evidence["product_source_sha"] = "0" * 40
        with tempfile.TemporaryDirectory() as temp_dir:
            stale_path = Path(temp_dir) / "stale.json"
            stale_path.write_text(json.dumps(evidence), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "different product RTL SHA"):
                validate_diagnostic_instrumentation(stale_path, "c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b")

    def test_branch_source_position_uses_terminal_predicate_line(self):
        row = {
            "source_files": "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv",
            "bin": "190:0/-/-/-/-/1/0/-/default/-/-/-/-/-/-/-/-/-",
        }
        branch = {
            "branch_target_position": "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:246",
            "branch_target_expression": "if (write_resp != 2'b00) begin",
        }

        position, expression = audited_source_position(row, branch)

        self.assertTrue(position.endswith(":246"))
        self.assertIn("write_resp", expression)


if __name__ == "__main__":
    unittest.main()
