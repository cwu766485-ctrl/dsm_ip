import csv
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_coverage_gate import _applicable_functional_bins


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


if __name__ == "__main__":
    unittest.main()
