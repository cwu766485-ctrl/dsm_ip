import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_formal_dispositions import (
    tautological_property_names,
    validate_refresh_evidence,
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
