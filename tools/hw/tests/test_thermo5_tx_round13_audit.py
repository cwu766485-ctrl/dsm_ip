import json
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_round13_audit import summarize_final_tool_status


class Round13ToolStatusTests(unittest.TestCase):
    def test_later_signoff_supersedes_initial_vcs_reader_failure(self):
        repo_root = Path(__file__).resolve().parents[3]
        manifest_path = (
            repo_root / "docs/verification/data/thermo5-r13/"
            "thermo5_tx_r13_final_coverage_manifest.json"
        )
        signoff = json.loads(manifest_path.read_text(encoding="utf-8"))

        status = summarize_final_tool_status(signoff)

        self.assertEqual(status["vcs_r13"], "PASS_TARGETED_PRODUCT_REGRESSIONS")
        self.assertEqual(status["urg_r13"], "PASS_SAME_MANIFEST_RAW_AND_ADJUSTED")
        self.assertEqual(
            status["formal_r13"],
            "PARTIAL_4_CURRENT_SOURCE_REPROOFS; 3_REQUIRED_OBLIGATIONS_OPEN",
        )

    def test_missing_current_tool_evidence_stays_open(self):
        status = summarize_final_tool_status({})

        self.assertEqual(status["vcs_r13"], "OPEN_OR_INCOMPLETE")
        self.assertEqual(status["urg_r13"], "OPEN_OR_INCOMPLETE")
        self.assertEqual(status["formal_r13"], "OPEN_NO_CURRENT_SOURCE_REPROOF_RECORDED")


if __name__ == "__main__":
    unittest.main()
