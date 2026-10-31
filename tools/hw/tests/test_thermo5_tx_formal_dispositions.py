import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_formal_dispositions import (
    FIXED_PARAMETER_BRANCH_SPECS,
    FIXED_PARAMETER_SOURCE_FILES,
    append_current_source_formal_section,
    exact_pairlookahead_bin_ids,
    tautological_property_names,
    validate_refresh_evidence,
    validate_pairlookahead_source_chain,
    validate_fixed_parameter_source_chain,
    verify_fixed_parameter_dispositions,
    read_csv,
)


ROOT = Path(__file__).resolve().parents[3]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class TautologyAuditTests(unittest.TestCase):
    def test_extracts_only_the_property_named_by_a_tautology_warning(self):
        console = """Warning-[SVAC-TAUT-PROPERTY] Property is a tautology
formal_harness.sv, 42
thermo5_harness, "a_constant_parameter_check"
  Property is a tautology if it is used as an assertion.
Info: SIMON completed
[Info] PROP_I_RESULT: thermo5_harness.a_other_property proven
"""
        self.assertEqual(
            tautological_property_names(console),
            {"a_constant_parameter_check"},
        )

    def test_current_source_update_preserves_historical_sections(self):
        closure = "# Report\n\n## Formal disposition update\n\nOld SHA: 8/10 proven.\n"
        updated = append_current_source_formal_section(
            closure,
            "a" * 40,
            ["New SHA: 1/22,626 proven."],
        )
        self.assertIn("Old SHA: 8/10 proven.", updated)
        self.assertIn("## Current-source Formal disposition update — `" + "a" * 40 + "`", updated)
        self.assertIn("New SHA: 1/22,626 proven.", updated)


class ProductElaborationAuditTests(unittest.TestCase):
    def test_exact_pair_bin_selector_keeps_only_helper_and_selector_branch(self):
        rows = [
            {"source_files": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
             "source_position": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:117",
             "metric": "line", "semantic_bin_id": "helper_start"},
            {"source_files": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
             "source_position": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:231",
             "metric": "branch", "branch_target_expression": "if (PAIR_LOOKAHEAD) begin",
             "semantic_bin_id": "selector"},
            {"source_files": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
             "source_position": "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:231",
             "metric": "cond", "branch_target_expression": "if (PAIR_LOOKAHEAD) begin",
             "semantic_bin_id": "not_selector_branch"},
            {"source_files": "rtl/other.sv", "source_position": "rtl/other.sv:150",
             "metric": "line", "semantic_bin_id": "other_source"},
        ]
        self.assertEqual(
            exact_pairlookahead_bin_ids(
                rows, "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
            ),
            {"helper_start", "selector"},
        )

    def test_exact_product_parameter_chain_is_present_and_fail_closed(self):
        source = lambda path: (ROOT / path).read_text(encoding="utf-8")
        ef2 = source("rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv")
        multipa = source("rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv")
        boundary = source("rtl/gt/gt_tx_raw64_boundary.sv")
        bridge = source("rtl/gt/gt_tx_user_bridge.sv")
        validate_pairlookahead_source_chain(ef2, multipa, boundary, bridge)
        with self.assertRaisesRegex(ValueError, "overrides or obscures"):
            validate_pairlookahead_source_chain(
                ef2,
                multipa.replace(".CHANNELS(CHANNELS)", ".CHANNELS(CHANNELS), .PAIR_LOOKAHEAD(1'b1)"),
                boundary,
                bridge,
            )
        with self.assertRaisesRegex(ValueError, "overrides or obscures"):
            validate_pairlookahead_source_chain(
                ef2,
                multipa.replace("TIDSM_ORDER == 2", "TIDSM_ORDER == 1", 1),
                boundary,
                bridge,
            )
        with self.assertRaisesRegex(ValueError, "unreviewed declaration or call site"):
            validate_pairlookahead_source_chain(
                ef2 + "\n// ef2_pair_lookahead( unexpected extra call site\n",
                multipa,
                boundary,
                bridge,
            )

    def test_fixed_parameter_chain_is_exact_and_fail_closed(self):
        texts = {
            path: (ROOT / path).read_text(encoding="utf-8")
            for path in FIXED_PARAMETER_SOURCE_FILES
        }
        validate_fixed_parameter_source_chain(texts)
        changed = dict(texts)
        source_path = "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        changed[source_path] = changed[source_path].replace(
            ".DPD_LANES(16)", ".DPD_LANES(8)", 1
        )
        with self.assertRaisesRegex(ValueError, "DPD_LANES"):
            validate_fixed_parameter_source_chain(changed)

    def test_fixed_parameter_dispositions_bind_exact_raw_bins_and_evidence(self):
        data_dir = ROOT / "docs/verification/data/thermo5-tx-current-source-gaps"
        review = json.loads((data_dir / "thermo5-tx-focused-product-formal-review.json").read_text())
        summary = json.loads((data_dir / "thermo5-tx-focused-product-gap-summary.json").read_text())
        _, ledger = read_csv(data_dir / "thermo5-tx-focused-product-gap-ledger.csv.gz", compressed=True)
        validated = verify_fixed_parameter_dispositions(
            review, ledger, summary["source_product_sha"]
        )
        self.assertEqual(validated[0]["validated_bin_count"], 17)
        self.assertEqual(set(validated[0]["semantic_bin_ids"]), set(FIXED_PARAMETER_BRANCH_SPECS))

        changed_rows = [dict(row) for row in ledger]
        changed_rows_by_id = {row["semantic_bin_id"]: row for row in changed_rows}
        changed_rows_by_id["TXB-054d97a87a8d74c36c8b"]["branch_decision_path"] = "0"
        with self.assertRaisesRegex(ValueError, "branch_decision_path mismatch"):
            verify_fixed_parameter_dispositions(
                review, changed_rows, summary["source_product_sha"]
            )


class RefreshEvidenceTests(unittest.TestCase):
    def test_accepts_matching_raw_report_summary_and_gate(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "runs") as temporary:
            folder = Path(temporary)
            report = folder / "groups.html"
            report.write_text("raw urg groups", encoding="utf-8")
            raw_summary = folder / "raw-summary.json"
            raw_summary.write_text(json.dumps({"source_product_sha": "product-sha"}), encoding="utf-8")
            gate = folder / "gate.json"
            project = {"line": {"covered": 1, "total": 2}}
            gate.write_text(json.dumps({
                "status": "RAW_100_OPEN",
                "exclusions_applied": False,
                "inputs": {
                    "groups_html": str(report.relative_to(ROOT)),
                    "raw_summary": str(raw_summary.relative_to(ROOT)),
                },
                "raw_project_rtl": project,
                "adjusted_project_rtl": project,
            }), encoding="utf-8")
            record = folder / "refresh.json"
            record.write_text(json.dumps({
                "product_source_sha": "product-sha",
                "coverage": {
                    "urg_refresh_status": "PASS",
                    "groups_html": str(report.relative_to(ROOT)),
                    "groups_html_sha256": sha256(report),
                    "raw_summary": str(raw_summary.relative_to(ROOT)),
                    "raw_summary_sha256": sha256(raw_summary),
                    "coverage_gate": str(gate.relative_to(ROOT)),
                    "coverage_gate_sha256": sha256(gate),
                },
            }), encoding="utf-8")
            manifest = {"input_sha256": {"raw_groups_html": {
                str(report.relative_to(ROOT)): sha256(report),
            }}}

            result = validate_refresh_evidence(
                record,
                {"source_product_sha": "product-sha"},
                manifest,
            )

            self.assertEqual(result["product_source_sha"], "product-sha")

    def test_rejects_report_not_used_by_rootcause_audit(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "runs") as temporary:
            folder = Path(temporary)
            report = folder / "groups.html"
            report.write_text("raw urg groups", encoding="utf-8")
            raw_summary = folder / "raw-summary.json"
            raw_summary.write_text(json.dumps({"source_product_sha": "product-sha"}), encoding="utf-8")
            gate = folder / "gate.json"
            project = {"line": {"covered": 1, "total": 2}}
            gate.write_text(json.dumps({
                "status": "RAW_100_OPEN", "exclusions_applied": False,
                "inputs": {
                    "groups_html": str(report.relative_to(ROOT)),
                    "raw_summary": str(raw_summary.relative_to(ROOT)),
                },
                "raw_project_rtl": project, "adjusted_project_rtl": project,
            }), encoding="utf-8")
            record = folder / "refresh.json"
            record.write_text(json.dumps({
                "product_source_sha": "product-sha",
                "coverage": {
                    "urg_refresh_status": "PASS",
                    "groups_html": str(report.relative_to(ROOT)),
                    "groups_html_sha256": sha256(report),
                    "raw_summary": str(raw_summary.relative_to(ROOT)),
                    "raw_summary_sha256": sha256(raw_summary),
                    "coverage_gate": str(gate.relative_to(ROOT)),
                    "coverage_gate_sha256": sha256(gate),
                },
            }), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "not one of the root-cause audit inputs"):
                validate_refresh_evidence(
                    record,
                    {"source_product_sha": "product-sha"},
                    {"input_sha256": {"raw_groups_html": {}}},
                )


if __name__ == "__main__":
    unittest.main()
