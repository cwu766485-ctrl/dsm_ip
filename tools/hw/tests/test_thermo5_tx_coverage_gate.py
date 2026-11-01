import csv
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_coverage_gate import (
    AuditError, _applicable_functional_bins, _coverage_fingerprint,
    _vdb_tree_fingerprint,
    _verify_dual_report_manifest,
)


class ApplicableFunctionalBinTests(unittest.TestCase):
    def write_detail(self, path: Path, legal_status: str) -> None:
        fields = (
            "product_source_sha", "group", "raw_status",
            "raw_denominator_applicable", "legal_applicability",
        )
        rows = [
            {"product_source_sha": "a" * 40, "group": "source_cg",
             "raw_status": legal_status, "raw_denominator_applicable": "true",
             "legal_applicability": "LEGAL_PRODUCT"},
            {"product_source_sha": "a" * 40, "group": "source_cg",
             "raw_status": "UNCOVERED", "raw_denominator_applicable": "true",
             "legal_applicability": "ILLEGAL_TEST_ONLY"},
            {"product_source_sha": "a" * 40, "group": "source_cg",
             "raw_status": "EXCLUDED_BY_URG_MODEL", "raw_denominator_applicable": "false",
             "legal_applicability": "URG_MODEL_ILLEGAL_OR_EXCLUDED"},
        ]
        with path.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=fields)
            writer.writeheader()
            writer.writerows(rows)

    def test_negative_only_and_urg_model_bins_do_not_dilute_legal_score(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "detail.csv"
            self.write_detail(path, "COVERED")
            scores, counts, source_sha = _applicable_functional_bins(path)
        self.assertEqual(scores, {"source_cg": 100.0})
        self.assertEqual(counts, {"covered": 1, "total": 1, "uncovered": 0, "percent": 100.0})
        self.assertEqual(source_sha, "a" * 40)

    def test_uncovered_legal_bin_remains_open(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "detail.csv"
            self.write_detail(path, "UNCOVERED")
            scores, counts, _ = _applicable_functional_bins(path)
        self.assertEqual(scores["source_cg"], 0.0)
        self.assertEqual(counts["uncovered"], 1)


class DualReportManifestTests(unittest.TestCase):
    def _inputs(self):
        import hashlib, json
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            design_path = root / "design.vdb"
            test_path = root / "test.vdb"
            design_path.mkdir()
            test_path.mkdir()
            (design_path / "design.bin").write_bytes(b"design")
            (test_path / "test.bin").write_bytes(b"test")
            vdb = {"design": _vdb_tree_fingerprint(design_path),
                   "tests": [_vdb_tree_fingerprint(test_path)]}
            vdb_sha = hashlib.sha256(json.dumps(vdb, sort_keys=True,
                                                separators=(",", ":")).encode()).hexdigest()
            summary = {
                "metrics": [{"ownership": "PROJECT_RTL", "metric": "branch",
                             "covered": 9, "total": 10, "missing": 1}],
                "fsm_denominators": [{"ownership": "PROJECT_RTL", "metric": "states",
                                      "covered": 2, "total": 2}],
                "dut_assertion_status_counts": {"SUCCESS": 1},
            }
            audit_path = root / "audit.json"
            audit_path.write_text("audit\n")
            audit = {"product_configuration_fingerprint": "cfg"}
            manifest = {
                "raw_summary": _coverage_fingerprint(summary),
                "adjusted_summary": _coverage_fingerprint(summary),
                "waiver_audit_sha256": hashlib.sha256(audit_path.read_bytes()).hexdigest(),
                "product_configuration_fingerprint": "cfg",
                "vdb_manifest": vdb,
                "vdb_manifest_sha256": vdb_sha,
                "post_vdb_manifest_sha256": vdb_sha,
                "common_inputs": {"design_vdb": vdb["design"]["path"],
                                  "test_vdbs": [x["path"] for x in vdb["tests"]]},
            }
            yield manifest, summary, audit, audit_path

    def test_matching_vdb_and_summary_manifest_passes(self):
        for manifest, summary, audit, audit_path in self._inputs():
            _verify_dual_report_manifest(manifest, summary, summary, audit, audit_path)

    def test_stale_summary_is_rejected(self):
        for manifest, summary, audit, audit_path in self._inputs():
            summary["metrics"][0]["covered"] = 8
            with self.assertRaisesRegex(AuditError, "Raw summary does not match"):
                _verify_dual_report_manifest(manifest, summary, summary, audit, audit_path)

    def test_tampered_vdb_inventory_is_rejected(self):
        for manifest, summary, audit, audit_path in self._inputs():
            manifest["common_inputs"]["test_vdbs"] = ["/runs/other.vdb"]
            with self.assertRaisesRegex(AuditError, "test VDB list"):
                _verify_dual_report_manifest(manifest, summary, summary, audit, audit_path)

    def test_changed_vdb_bytes_are_rejected(self):
        for manifest, summary, audit, audit_path in self._inputs():
            test_vdb = Path(manifest["vdb_manifest"]["tests"][0]["path"])
            (test_vdb / "test.bin").write_bytes(b"changed")
            with self.assertRaisesRegex(AuditError, "test VDB trees"):
                _verify_dual_report_manifest(manifest, summary, summary, audit, audit_path)


if __name__ == "__main__":
    unittest.main()
