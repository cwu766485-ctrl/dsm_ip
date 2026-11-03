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
from tools.hw.thermo5_tx_waiver_candidate_audit import _configuration_rule


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class WaiverPipelineTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for directory in ("rtl/tx_bandpass_if", "dv/uvm/tb", "docs", "tools/hw", "runs"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        self.source = self.root / "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv"
        lines = ["// fixture\n"] * 274
        lines[0] = "module tid32_thermo5_axi_lite_axis_frontend_tx;\n"
        lines[273] = "    if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)\n"
        self.source.write_text("".join(lines) + "endmodule\n")
        self.top_source = self.root / "dv/uvm/tb/thermo5_sku_uvm_tb.sv"
        self.top_source.write_text(
            "module thermo5_sku_uvm_tb;\n"
            "localparam int USE_DPD_MAX_TAPS = `THERMO5_DPD_MAX_TAPS;\n"
            "tid32_thermo5_axi_lite_axis_frontend_tx #(\n"
            ".DPD_MAX_TAPS(USE_DPD_MAX_TAPS)\n"
            ") dut ();\nendmodule\n"
        )
        (self.root / "tools/hw/gate.py").write_text("gate\n")
        self.ledger = self.root / "docs/gaps.csv.gz"
        self.compile_manifest = self.root / "docs/compile.json"
        self.report_manifest = self.root / "docs/report.json"
        self.vdb_manifest = self.root / "docs/vdb.json"
        self.formal_review = self.root / "docs/formal-review.json"
        self.candidate_audit = self.root / "docs/candidates.json"
        self.waivers = self.root / "docs/waivers.csv"
        self.el = self.root / "runs/main.el"
        self.audit = self.root / "runs/audit.json"
        self.parameters = "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120 STATE_BITS=20; DPD_MAX_TAPS=1 identity; Generic FIFO"
        self.product_sha = "a" * 40
        self.source_sha = digest(self.source)
        self.top_sha = digest(self.top_source)
        self.gap = {
            "bin_id": "raw-bin-01", "semantic_bin_id": "TXB-unit-01",
            "configuration": "axil", "instance": "tb.dut.u_frontend",
            "source_files": "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
            "metric": "branch", "branch_target_line": "274",
            "source_position": "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:274",
            "branch_predicate_path": "1:274 if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)=1",
            "source_file_sha256": f"rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv={self.source_sha}",
            "product_parameters": self.parameters, "product_source_sha": self.product_sha,
            "status": "OPEN",
        }
        with gzip.open(self.ledger, "wt", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=list(self.gap))
            writer.writeheader()
            writer.writerow(self.gap)
        self.manifest = {
            "base_commit": "b" * 40, "product_source_sha": self.product_sha,
            "scope": "VCS_PRODUCT_COMPILE_INPUTS",
            "source_file_sha256": {
                "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv": self.source_sha,
                "dv/uvm/tb/thermo5_sku_uvm_tb.sv": self.top_sha,
            },
            "audit_tool_sha256": {"tools/hw/gate.py": digest(self.root / "tools/hw/gate.py")},
            "compile_provenance": {
                "configuration_defines": ["+define+THERMO5_CENTERED_CUBIC", "+define+THERMO5_STEP=5120"],
                "top": "thermo5_sku_uvm_tb", "product_filelist_sha256": "c" * 64,
                "coverage_hierarchy_sha256": "d" * 64,
            },
        }
        self.compile_manifest.write_text(json.dumps(self.manifest))
        self.vdb_manifest.write_text(json.dumps({
            "design": {"path": "/fixture/design.vdb"},
            "tests": [{"path": "/fixture/test.vdb"}],
        }))
        vdbs = ["/fixture/design.vdb", "/fixture/test.vdb"]
        vdb_object = json.loads(self.vdb_manifest.read_text())
        canonical_vdb_sha = hashlib.sha256(
            json.dumps(vdb_object, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        self.report_manifest.write_text(json.dumps({
            "product_configuration_fingerprint": _configuration_fingerprint(self.manifest),
            "raw_command": ["urg", "-dir", *vdbs],
            "adjusted_command": ["urg", "-dir", *vdbs, "-elfile", "/fixture/main.el"],
            "common_inputs": {"design_vdb": vdbs[0], "test_vdbs": [vdbs[1]]},
            "vdb_manifest_sha256": canonical_vdb_sha,
            "vdb_manifest": vdb_object,
            "approved_waiver_count": 0, "adjusted_exclusions_applied": False,
            "raw_summary": {"branch": {"covered": 1, "total": 2}},
            "adjusted_summary": {"branch": {"covered": 1, "total": 2}},
        }))
        self.formal_review.write_text(json.dumps({"disposition": "PROVEN_UNREACHABLE", "bins": []}))
        self._write_candidate_audit("UNRESOLVED")
        self._write_row("PENDING")

    def tearDown(self):
        self.temporary.cleanup()

    def _row(self, status="PENDING"):
        return {
            "waiver_id": "W-1", "configuration": "axil", "instance": self.gap["instance"],
            "source_file": "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
            "source_line": "274", "metric": "branch", "bin": "raw-bin-01",
            "reason": "candidate audit fixture", "candidate_audit": "docs/candidates.json",
            "candidate_audit_sha256": digest(self.candidate_audit), "source_sha256": self.source_sha,
            "review_status": status, "reviewer": "", "approval_reference": "", "el_directive": "",
        }

    def _write_row(self, status="PENDING", row=None):
        with self.waivers.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerow(row or self._row(status))

    def _write_candidate_audit(self, disposition):
        inputs = {
            "raw_gap_ledger": ("docs/gaps.csv.gz", digest(self.ledger)),
            "product_compile_manifest": ("docs/compile.json", digest(self.compile_manifest)),
            "raw_adjusted_report_manifest": ("docs/report.json", digest(self.report_manifest)),
            "vdb_manifest": ("docs/vdb.json", digest(self.vdb_manifest)),
            "formal_review": ("docs/formal-review.json", digest(self.formal_review)),
        }
        candidate = {
            "waiver_id": "W-1", "raw_bin_id": self.gap["bin_id"],
            "semantic_bin_id": self.gap["semantic_bin_id"], "configuration": "axil",
            "instance": self.gap["instance"], "source_file": self.gap["source_files"],
            "source_line": 274, "metric": "branch", "source_sha256": self.source_sha,
            "product_source_sha": self.product_sha, "product_parameters": self.parameters,
            "raw_status": self.gap["status"], "raw_retained": True,
            "branch_predicate_path": self.gap["branch_predicate_path"],
            "disposition": disposition,
        }
        if disposition == "CONFIG_UNREACHABLE":
            candidate["proof"] = _configuration_rule(
                {"source_file": candidate["source_file"], "source_line": "274",
                 "instance": candidate["instance"], "metric": "branch"},
                self.gap, self.root, self.manifest
            )
            self.assert_config_proof = candidate["proof"]
        data = {
            "schema": "thermo5_tx_waiver_candidate_audit",
            "product_source_sha": self.product_sha,
            "product_configuration_fingerprint": _configuration_fingerprint(self.manifest),
            "candidate_count": 1,
            "disposition_counts": {disposition: 1},
            "approved_count": 0,
            "active_exclusions": 0,
            "raw_bin_denominators_changed": False,
            "raw_statuses_changed": False,
            "inputs": {k: {"path": p, "sha256": h} for k, (p, h) in inputs.items()},
            "formal_runs": {}, "candidates": [candidate],
        }
        self.candidate_audit.write_text(json.dumps(data, sort_keys=True) + "\n")

    def _run(self):
        return audit_and_generate(waivers_csv=self.waivers, gap_ledger=self.ledger,
                                  compile_manifest=self.compile_manifest, repo_root=self.root,
                                  el_output=self.el, audit_output=self.audit)

    def test_pending_candidate_never_generates_active_exclusion(self):
        result = self._run()
        self.assertEqual(result["pending_count"], 1)
        self.assertEqual(result["approved_count"], 0)
        self.assertFalse(result["exclusions_applied"])
        self.assertNotIn("exclude", self.el.read_text().lower())

    def test_pending_candidate_can_be_bound_to_open_raw_bin(self):
        self._write_candidate_audit("CONFIG_UNREACHABLE")
        self._write_row("PENDING")
        result = self._run()
        self.assertEqual(result["pending_count"], 1)
        self.assertEqual(result["approved_count"], 0)
        self.assertNotIn("exclude", self.el.read_text().lower())

    def test_exact_approved_candidate_generates_one_directive_and_raw_stays_open(self):
        self._write_candidate_audit("CONFIG_UNREACHABLE")
        directive = {
            "checksum": "// CHECKSUM: abc123",
            "module": '// ANNOTATION: "ModuleName: tid32_thermo5_axi_lite_axis_frontend_tx"',
            "entry": 'Branch 1 "if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)"',
        }
        row = self._row("APPROVED")
        row.update({
            "reviewer": "reviewer@example.org",
            "approval_reference": "https://github.com/cwu766485-ctrl/dsm_ip/pull/99#pullrequestreview-123",
            "el_directive": json.dumps(directive, sort_keys=True),
        })
        self._write_row(row=row)
        result = self._run()
        self.assertEqual(result["approved_count"], 1)
        self.assertTrue(result["exclusions_applied"])
        self.assertIn("INSTANCE: tb.dut.u_frontend", self.el.read_text())
        self.assertIn('Branch 1 "if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)"', self.el.read_text())
        self.assertEqual(self.gap["status"], "OPEN")

    def test_unresolved_candidate_cannot_be_approved(self):
        row = self._row("APPROVED")
        row.update({
            "reviewer": "reviewer@example.org",
            "approval_reference": "https://github.com/cwu766485-ctrl/dsm_ip/pull/99#pullrequestreview-123",
            "el_directive": json.dumps({
                "checksum": "// CHECKSUM: abc123",
                "module": '// ANNOTATION: "ModuleName: tid32_thermo5_axi_lite_axis_frontend_tx"',
                "entry": 'Branch 1 "if (DPD_MAX_TAPS < 1 || DPD_MAX_TAPS > 4)"',
            }),
        })
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "not an audited unreachable candidate"):
            self._run()

    def test_stale_candidate_audit_hash_fails_closed(self):
        row = self._row()
        row["candidate_audit_sha256"] = "0" * 64
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "common candidate-audit SHA differs"):
            self._run()

    def test_configuration_parameter_tamper_fails_closed(self):
        self._write_candidate_audit("CONFIG_UNREACHABLE")
        audit = json.loads(self.candidate_audit.read_text())
        audit["candidates"][0]["proof"]["actual_parameters"]["DPD_MAX_TAPS"] = 4
        self.candidate_audit.write_text(json.dumps(audit, sort_keys=True) + "\n")
        self._write_row("PENDING")
        with self.assertRaisesRegex(WaiverError, "configuration proof does not match"):
            self._run()

    def test_candidate_audit_inventory_must_match_csv(self):
        self._write_candidate_audit("UNRESOLVED")
        audit = json.loads(self.candidate_audit.read_text())
        extra = dict(audit["candidates"][0])
        extra["waiver_id"] = "W-EXTRA"
        audit["candidates"].append(extra)
        audit["candidate_count"] = 2
        audit["disposition_counts"] = {"UNRESOLVED": 2}
        self.candidate_audit.write_text(json.dumps(audit, sort_keys=True) + "\n")
        self._write_row("PENDING")
        with self.assertRaisesRegex(WaiverError, "does not exactly match"):
            self._run()

    def test_stale_compile_source_hash_fails_closed(self):
        row = self._row()
        self.source.write_text(self.source.read_text() + "// changed\n")
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "source SHA is stale"):
            self._run()

    def test_raw_adjusted_manifest_vdb_mismatch_fails_closed(self):
        report = json.loads(self.report_manifest.read_text())
        report["adjusted_command"].append("/fixture/other.vdb")
        self.report_manifest.write_text(json.dumps(report))
        self._write_candidate_audit("UNRESOLVED")
        self._write_row("PENDING")
        with self.assertRaisesRegex(WaiverError, "Raw/Adjusted reports do not use"):
            self._run()

    def test_unapproved_candidate_cannot_carry_reviewer_or_directive(self):
        row = self._row("PENDING")
        row["reviewer"] = "reviewer@example.org"
        self._write_row(row=row)
        with self.assertRaisesRegex(WaiverError, "pending waiver must not contain approval"):
            self._run()


if __name__ == "__main__":
    unittest.main()
