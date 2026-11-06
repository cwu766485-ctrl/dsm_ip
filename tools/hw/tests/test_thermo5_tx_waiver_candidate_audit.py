import hashlib
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.hw.thermo5_tx_waiver_candidate_audit import (
    CandidateAuditError,
    _classify,
    _configuration_rule,
)


class FormalCandidateStalenessTests(unittest.TestCase):
    def test_stale_formal_evidence_stays_unresolved(self):
        repo_root = Path(__file__).resolve().parents[3]
        source_file = "rtl/gt/gt_tx_user_bridge.sv"
        source_sha = hashlib.sha256((repo_root / source_file).read_bytes()).hexdigest()
        waiver = {
            "waiver_id": "W-test-stale-formal",
            "configuration": "axil",
            "instance": "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_order2.u_bridge",
            "source_file": source_file,
            "source_line": "21",
            "metric": "branch",
            "source_sha256": source_sha,
            "reason": "stale formal must never approve a waiver",
        }
        gap = {
            "bin_id": "raw-bin-current",
            "semantic_bin_id": "semantic-bin-current",
            "configuration": "axil",
            "instance": waiver["instance"],
            "source_files": source_file,
            "source_position": f"{source_file}:21",
            "metric": "branch",
            "status": "OPEN_CONFIGURATION_REVIEW",
            "product_source_sha": "a" * 40,
            "product_parameters": "frozen product parameters",
            "source_file_sha256": f"{source_file}={source_sha}",
            "rootcause": "fixed configuration",
            "rootcause_reason": "formal evidence is source stale",
            "branch_predicate_path": "module.g_order2.branch",
        }
        formal = {
            "semantic_bin_id": gap["semantic_bin_id"],
            "status": "PROVEN_UNREACHABLE",
            "source_file": source_file,
            "source_position": gap["source_position"],
            "instance": waiver["instance"],
            "metric": "branch",
        }

        with patch(
            "tools.hw.thermo5_tx_waiver_candidate_audit._formal_support",
            side_effect=CandidateAuditError("Formal source SHA is stale: proof.tcl"),
        ):
            result = _classify(
                waiver,
                gap,
                {gap["semantic_bin_id"]: formal},
                repo_root,
                repo_root / "runs" / "waiver-audit-test",
                {},
                {"source_file_sha256": {source_file: source_sha}},
            )

        self.assertEqual(result["disposition"], "UNRESOLVED")
        self.assertIn("Formal source SHA is stale", result["reason"])
        self.assertNotIn("proof", result)
        self.assertNotIn("evidence_files", result)

    def test_fixed_parameter_candidate_requires_compile_bound_parent(self):
        repo_root = Path(__file__).resolve().parents[3]
        source_file = "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
        parent_file = "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"
        source_sha = hashlib.sha256((repo_root / source_file).read_bytes()).hexdigest()
        parent_sha = hashlib.sha256((repo_root / parent_file).read_bytes()).hexdigest()
        waiver = {
            "waiver_id": "W-test-pair-lookahead",
            "source_file": source_file,
            "source_line": "136",
            "metric": "branch",
            "source_sha256": source_sha,
            "instance": "thermo5_sku_uvm_tb.dut.u_frontend.u_tid.g_branch[0].g_order2.u_tid",
        }
        gap = {
            "branch_predicate_path": "if(PAIR_LOOKAHEAD)=1",
            "product_parameters": "TIDSM_ORDER=2;PAIR_LOOKAHEAD=0",
        }

        missing_parent_binding = _configuration_rule(
            waiver, gap, repo_root,
            {"source_file_sha256": {source_file: source_sha}},
        )
        exact_compile_binding = _configuration_rule(
            waiver, gap, repo_root,
            {"source_file_sha256": {
                source_file: source_sha,
                parent_file: parent_sha,
            }},
        )

        self.assertIsNone(missing_parent_binding)
        self.assertIsNotNone(exact_compile_binding)
        self.assertEqual(exact_compile_binding["actual_parameters"]["PAIR_LOOKAHEAD"], 0)


if __name__ == "__main__":
    unittest.main()
