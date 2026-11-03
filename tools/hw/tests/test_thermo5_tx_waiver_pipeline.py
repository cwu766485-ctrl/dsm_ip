import csv
import gzip
import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tools.hw.thermo5_tx_waiver_pipeline import (
    FIELDS,
    WaiverError,
    _configuration_fingerprint,
    audit_and_generate,
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class WaiverPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / "rtl").mkdir()
        (self.root / "docs").mkdir()
        (self.root / "tools/hw").mkdir(parents=True)
        self.source = self.root / "rtl/mock.sv"
        self.source.write_text("module mock; endmodule\n")
        (self.root / "tools/hw/gate.py").write_text("gate\n")
        self.ledger = self.root / "docs/gaps.csv.gz"
        self.compile_manifest = self.root / "docs/compile.json"
        self.waivers = self.root / "docs/waivers.csv"
        self.proof = self.root / "docs/proof.json"
        self.proof_file = self.root / "docs/properties.txt"
        self.el = self.root / "runs/main.el"
        self.audit = self.root / "runs/audit.json"
        self.parameters = "Centered-Cubic; EF2=2/5120; DPD_MAX_TAPS=1; Generic"
        self.source_sha = digest(self.source)
        self.gap = {
            "bin_id": "raw-bin-01", "semantic_bin_id": "TXB-unit-01",
            "configuration": "axil", "instance": "tb.dut.u_mock",
            "source_files": "rtl/mock.sv", "metric": "branch",
            "branch_target_line": "7", "source_position": "rtl/mock.sv:7",
            "source_file_sha256": f"rtl/mock.sv={self.source_sha}",
            "product_parameters": self.parameters, "product_source_sha": "a" * 40,
            "status": "PROVEN_UNREACHABLE",
        }
        with gzip.open(self.ledger, "wt", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(self.gap))
            writer.writeheader()
            writer.writerow(self.gap)
        self.manifest = {
            "base_commit": "b" * 40,
            "scope": "VCS_PRODUCT_COMPILE_INPUTS",
            "source_file_sha256": {"rtl/mock.sv": self.source_sha},
            "audit_tool_sha256": {"tools/hw/gate.py": digest(self.root / "tools/hw/gate.py")},
            "compile_provenance": {
                "configuration_defines": ["+define+THERMO5_CENTERED_CUBIC", "+define+STEP=5120"],
                "top": "tb", "product_filelist_sha256": "c" * 64,
                "coverage_hierarchy_sha256": "d" * 64,
            },
        }
        self.compile_manifest.write_text(json.dumps(self.manifest))
        self._write_row("PENDING")

    def tearDown(self):
        self.temporary.cleanup()

    def _row(self, status="PENDING"):
        return {
            "waiver_id": "W-1", "configuration": "axil", "instance": "tb.dut.u_mock",
            "source_file": "rtl/mock.sv", "source_line": "7", "metric": "branch",
            "bin": "raw-bin-01", "reason": "Exact fixed-configuration branch.",
            "proof_evidence": "", "proof_evidence_sha256": "", "source_sha256": self.source_sha,
            "review_status": status, "reviewer": "", "approval_reference": "", "el_directive": "",
        }

    def _write_row(self, status="PENDING", row=None):
        with self.waivers.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerow(row or self._row(status))

    def _approved_row(self):
        config_hash = _configuration_fingerprint(self.manifest)
        self.proof_file.write_text("ASSERT exact branch unreachable; legal activity cover reached\n")
        directive = {
            "checksum": "// CHECKSUM: abc123",
            "module": '// ANNOTATION: "ModuleName: mock"',
            "entry": 'Branch 1 "if (mock_condition) 1"',
        }
        evidence = {
            "disposition": "PROVEN_UNREACHABLE",
            "native_urg_directive": directive,
            "product_source_sha": self.gap["product_source_sha"],
            "product_parameters": self.parameters, "configuration_sha256": config_hash,
            "configuration": "axil", "instance": "tb.dut.u_mock", "source_file": "rtl/mock.sv",
            "source_line": 7, "metric": "branch", "raw_bin_id": "raw-bin-01",
            "semantic_bin_id": "TXB-unit-01", "source_sha256": self.source_sha,
            "assumptions": [], "blackboxes": 0, "tautological": False,
            "non_vacuous": True, "evidence_type": "formal", "assertion_status": "proven",
            "target_cover_status": "uncoverable", "activity_covers": [{"name": "legal_input", "status": "covered"}],
            "evidence_files": {"docs/properties.txt": digest(self.proof_file)},
        }
        self.proof.write_text(json.dumps(evidence, sort_keys=True) + "\n")
        row = self._row("APPROVED")
        row.update({
            "proof_evidence": "docs/proof.json", "proof_evidence_sha256": digest(self.proof),
            "reviewer": "reviewer@example.org",
            "approval_reference": "https://github.com/cwu766485-ctrl/dsm_ip/pull/99#pullrequestreview-123",
            "el_directive": json.dumps(directive, sort_keys=True),
        })
        return row

    def _run(self):
        return audit_and_generate(waivers_csv=self.waivers, gap_ledger=self.ledger,
                                  compile_manifest=self.compile_manifest, repo_root=self.root,
                                  el_output=self.el, audit_output=self.audit)

    def test_pending_candidate_never_generates_active_exclusion(self):
        result = self._run()
        self.assertEqual(result["pending_count"], 1)
        self.assertEqual(result["approved_count"], 0)
        self.assertNotIn("exclude", self.el.read_text())

    def test_pending_candidate_can_track_an_open_raw_bin(self):
        self.gap["status"] = "OPEN"
        with gzip.open(self.ledger, "wt", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(self.gap))
            writer.writeheader()
            writer.writerow(self.gap)

        result = self._run()
        self.assertEqual(result["pending_count"], 1)
        self.assertEqual(result["approved_count"], 0)
        self.assertNotIn("exclude", self.el.read_text())

    def test_open_raw_bin_cannot_be_approved(self):
        self.gap["status"] = "OPEN"
        with gzip.open(self.ledger, "wt", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(self.gap))
            writer.writeheader()
            writer.writerow(self.gap)
        self._write_row(row=self._approved_row())

        with self.assertRaisesRegex(WaiverError, "not proven unreachable"):
            self._run()

    def test_exact_approved_formal_evidence_generates_one_directive(self):
        row = self._approved_row()
        self._write_row(row=row)
        result = self._run()
        self.assertEqual(result["approved_count"], 1)
        lines = self.el.read_text().splitlines()
        self.assertEqual(lines[-5:], [
            '// CHECKSUM: abc123', '// ANNOTATION: "ModuleName: mock"',
            'INSTANCE: tb.dut.u_mock',
            '// ANNOTATION: "Evidence: raw-bin-01; TXB-unit-01"',
            'Branch 1 "if (mock_condition) 1"',
        ])

    def test_exact_approved_configuration_evidence_generates_one_directive(self):
        row = self._approved_row()
        evidence = json.loads(self.proof.read_text())
        evidence.update({
            "evidence_type": "configuration",
            "elaboration_status": "elaborated_exactly",
            "elaborated_parameters": self.parameters,
        })
        for key in ("assertion_status", "target_cover_status", "activity_covers"):
            evidence.pop(key, None)
        self.proof.write_text(json.dumps(evidence, sort_keys=True) + "\n")
        row["proof_evidence_sha256"] = digest(self.proof)
        self._write_row(row=row)
        result = self._run()
        self.assertEqual(result["approved_count"], 1)

    def test_stale_configuration_tuple_fails_closed(self):
        row = self._approved_row()
        evidence = json.loads(self.proof.read_text())
        evidence.update({
            "evidence_type": "configuration",
            "elaboration_status": "elaborated_exactly",
            "elaborated_parameters": "DPD_MAX_TAPS=4",
        })
        for key in ("assertion_status", "target_cover_status", "activity_covers"):
            evidence.pop(key, None)
        self.proof.write_text(json.dumps(evidence, sort_keys=True) + "\n")
        row["proof_evidence_sha256"] = digest(self.proof)
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "parameter tuple is stale"):
            self._run()

    def test_stale_source_hash_fails_closed(self):
        row = self._approved_row()
        self.source.write_text("module mock; wire changed; endmodule\n")
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "source SHA is stale"):
            self._run()

    def test_inconclusive_formal_cannot_be_approved(self):
        row = self._approved_row()
        evidence = json.loads(self.proof.read_text())
        evidence["assertion_status"] = "inconclusive"
        self.proof.write_text(json.dumps(evidence) + "\n")
        row["proof_evidence_sha256"] = digest(self.proof)
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "Formal proof must prove"):
            self._run()

    def test_wildcard_or_metric_mismatched_native_urg_record_is_rejected(self):
        row = self._approved_row()
        directive = json.loads(row["el_directive"])
        directive["entry"] = 'Branch * "any branch"'
        row["el_directive"] = json.dumps(directive, sort_keys=True)
        evidence = json.loads(self.proof.read_text())
        evidence["native_urg_directive"] = directive
        self.proof.write_text(json.dumps(evidence) + "\n")
        row["proof_evidence_sha256"] = digest(self.proof)
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "non-wildcard"):
            self._run()

    def test_unknown_or_ambiguous_raw_bin_fails_closed(self):
        row = self._row()
        row["bin"] = "not-in-ledger"
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "maps to 0 current Raw bins"):
            self._run()


if __name__ == "__main__":
    unittest.main()
