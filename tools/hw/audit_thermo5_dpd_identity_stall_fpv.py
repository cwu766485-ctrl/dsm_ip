#!/usr/bin/env python3.12
"""Fail-closed audit for the composed Thermo5 one-tap Identity DPD proof."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
TOP = "thermo5_dpd_identity_stall_harness"
RTL = ["rtl/dpd/dpd_poly.v", "rtl/dpd/dpd_memory_poly.v"]
FORMAL = [
    "dv/uvm/formal/thermo5_dpd_identity_stall_harness.sv",
    "dv/uvm/formal/run_thermo5_dpd_identity_stall_fpv.tcl",
    "dv/uvm/formal/run_thermo5_dpd_identity_stall_fpv.py",
    "tools/hw/audit_thermo5_dpd_identity_stall_fpv.py",
]
INTERNAL = {
    *(f"a_coeff{i}" for i in range(5)),
    "a_cross_i7", "a_cross_q7", "a_gain5", "a_gain6", "a_gain_c5_zero5",
    *(f"a_i{i}" for i in range(7)),
    *(f"a_q{i}" for i in range(7)),
    "a_pair_i9", "a_pair_q9", "a_prod_i7", "a_prod_q7",
    "a_sum_i10", "a_sum_q10", "a_term_i8", "a_term_q8",
    *(f"a_v{i}" for i in range(8)), "a_valid_latency",
}
FINAL = {"a_no_saturation", "a_output_i", "a_output_q", "a_saturation_count_zero"}
COVERS = {"c_max_endpoint", "c_min_endpoint", "c_recovery", "c_stall"}
ROW_RE = re.compile(
    r"^\s*\[\s*\d+\]\s+(?P<state>[A-Za-z_]+(?:\(depth=\d+\))?)"
    r"(?P<qualifier>\s+\([^)]*\))?\s+-\s+(?P<name>\S+(?:\s+-\s+.*)?)$", re.M
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def section_rows(text: str, section: str) -> dict[str, dict[str, str]]:
    marker = f"> {section}\n"
    property_list = text.find("Property List:")
    start = text.find(marker, property_list)
    if property_list < 0 or start < 0:
        return {}
    start += len(marker)
    end = re.search(r"\n\s*>\s+[A-Za-z]+\s*\n", text[start:])
    block = text[start:] if end is None else text[start:start + end.start()]
    rows: dict[str, dict[str, str]] = {}
    for match in ROW_RE.finditer(block):
        rows[match.group("name")] = {
            "state": match.group("state"),
            "qualifier": (match.group("qualifier") or "").strip(),
        }
    return rows


def row_state(rows: dict[str, dict[str, str]], name: str) -> str | None:
    row = rows.get(f"{TOP}.{name}")
    return None if row is None else row["state"]


def digest_map(paths: list[str]) -> dict[str, str | None]:
    return {path: sha256(ROOT / path) if (ROOT / path).is_file() else None for path in paths}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--formal-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    formal_dir = args.formal_dir.resolve()
    required = ["properties_base.txt", "properties_composed.txt", "setup.txt",
                "engines.txt", "vcf.log", "run_result.json", "promoted_lemmas.txt"]
    errors: list[str] = []
    for name in required:
        if not (formal_dir / name).is_file():
            errors.append(f"missing formal artifact: {name}")
    if errors:
        print(json.dumps({"status": "OPEN", "errors": errors}, indent=2))
        return 1

    base_text = (formal_dir / "properties_base.txt").read_text(errors="replace")
    composed_text = (formal_dir / "properties_composed.txt").read_text(errors="replace")
    setup_text = (formal_dir / "setup.txt").read_text(errors="replace")
    log_text = (formal_dir / "vcf.log").read_text(errors="replace")
    run_result = json.loads((formal_dir / "run_result.json").read_text())
    base_assertions = section_rows(base_text, "Assertion")
    base_covers = section_rows(base_text, "Cover")
    base_constraints = section_rows(base_text, "Constraint")
    final_assertions = section_rows(composed_text, "Assertion")
    final_covers = section_rows(composed_text, "Cover")
    final_constraints = section_rows(composed_text, "Constraint")

    expected_base_names = {f"{TOP}.{name}" for name in INTERNAL | FINAL}
    if set(base_assertions) != expected_base_names:
        errors.append("base run assertion inventory differs from the 45-property harness")
    for name in INTERNAL:
        if row_state(base_assertions, name) != "proven":
            errors.append(f"base lemma was not proven: {name} ({row_state(base_assertions, name)})")
    for name in FINAL:
        state = row_state(base_assertions, name)
        if state != "proven" and not (state or "").startswith("inconclusive"):
            errors.append(f"unexpected base result for final goal {name}: {row_state(base_assertions, name)}")
    if set(base_covers) != {f"{TOP}.{name}" for name in COVERS}:
        errors.append("base run Cover inventory differs from harness")
    if any(row["state"] != "covered" for row in base_covers.values()):
        errors.append("one or more base Covers were not reached")

    if set(final_assertions) != {f"{TOP}.{name}" for name in FINAL}:
        errors.append("composed proof must leave exactly the four end-to-end goals asserted")
    for name in FINAL:
        if row_state(final_assertions, name) != "proven":
            errors.append(f"composed end-to-end goal not proven: {name} ({row_state(final_assertions, name)})")
    for name in ("a_output_i", "a_output_q"):
        row = final_assertions.get(f"{TOP}.{name}", {})
        if "non_vacuous" not in row.get("qualifier", ""):
            errors.append(f"output equivalence was not reported non-vacuous: {name}")
    if set(final_covers) != {f"{TOP}.{name}" for name in COVERS} or any(
        row["state"] != "covered" for row in final_covers.values()
    ):
        errors.append("composed run Cover set incomplete")

    promoted = {line.strip() for line in (formal_dir / "promoted_lemmas.txt").read_text().splitlines()
                if line.strip()}
    expected_promoted = {f"{TOP}.{name}" for name in INTERNAL}
    if promoted != expected_promoted:
        errors.append("compositional promotion list differs from the 41 base-proven internal lemmas")
    if len(final_constraints) != len(INTERNAL) + 2:
        errors.append("expected 41 proved lemmas plus payload contract and reset constraint")
    if f"{TOP}.asm_payload_stable" not in final_constraints:
        errors.append("source ready/valid payload stability assumption missing")
    if not any("rst_n==1" in name for name in final_constraints):
        errors.append("reset initialization constraint missing")
    if not expected_promoted.issubset(final_constraints):
        errors.append("composed report does not show all 41 lemmas as constraints")
    if len([name for name in final_constraints if name.startswith(f"{TOP}.asm_")]) != 1:
        errors.append("unexpected environment assumptions in composed report")
    harness = (ROOT / FORMAL[0]).read_text()
    if len(re.findall(r"\bassume\s+property\b", harness, re.I)) != 1:
        errors.append("expected exactly one legal source payload-hold assumption")
    if "Number of Black-Box Instances = 0" not in log_text:
        errors.append("zero-black-box check missing or failed")
    if "No setup issues found" not in log_text:
        errors.append("VC Formal setup check did not report clean setup")
    for metric in ("Clock violations", "Glitch violations", "Combinational loops", "Multidriven nets"):
        if not re.search(rf"{re.escape(metric)}\s*:\s*0\b", setup_text):
            errors.append(f"setup report missing zero result: {metric}")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in log_text:
        errors.append("a goal was marked tautological")
    if run_result.get("exit_code") != 0 or run_result.get("timeout"):
        errors.append("VC Formal did not complete successfully")
    if "Version V-2023.12-SP2" not in log_text:
        errors.append("expected VC Formal V-2023.12-SP2")

    source_paths = RTL + FORMAL
    source_sha = digest_map(source_paths)
    if any(value is None for value in source_sha.values()):
        errors.append("a proof source is missing")
    git_rev = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                             capture_output=True, text=True, check=True).stdout.strip()
    git_status = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
                                capture_output=True, text=True, check=True).stdout.splitlines()
    if git_status:
        errors.append("source worktree must be clean when this proof is run")
    if run_result.get("source_git_revision") != git_rev:
        errors.append("Formal run revision does not match the current source commit")
    if run_result.get("source_worktree_clean_at_start") is not True:
        errors.append("Formal run did not start from a clean source worktree")

    artifacts = {name: formal_dir / name for name in required}
    status = "PASS_SCOPED_DPD_IDENTITY_OUTPUT_UNDER_STALL" if not errors else "OPEN"
    report = {
        "schema_version": 1,
        "status": status,
        "scope": {
            "dut": "rtl/dpd/dpd_memory_poly.v / dpd_memory_poly",
            "configuration": "MAX_TAPS=1, USE_EXTERNAL_TAPS=1, active_taps=1, Q14 c1 unity, c3/c5 zero",
            "interface_model": "valid pipeline with output backpressure; source holds in_valid and I/Q while blocked",
            "claim": "local one-tap Identity DPD I/Q output equals accepted input at 11-cycle pipeline latency, with no output saturation or nonzero saturation counter",
            "exclusions": ["AXI shadow/commit", "mailbox transfer", "CDC", "pending/active epoch", "full TX chain", "physical RF"],
        },
        "formal": {
            "tool": next((line.strip() for line in log_text.splitlines() if "Version V-" in line), "UNKNOWN"),
            "exit_code": run_result.get("exit_code"),
            "duration_seconds": run_result.get("duration_seconds"),
            "black_box_instances": 0 if "Number of Black-Box Instances = 0" in log_text else None,
            "setup_violations": 0 if "No setup issues found" in log_text else None,
            "environment_assumptions": ["in_valid and I/Q stable after a cycle where in_valid && !in_ready"],
            "compositional_lemmas": sorted(INTERNAL),
            "base_assertions": base_assertions,
            "composed_assertions": final_assertions,
            "base_covers": base_covers,
            "composed_covers": final_covers,
            "commands": run_result.get("command"),
            "run_source_git_revision": run_result.get("source_git_revision"),
            "formal_directory": str(formal_dir),
            "artifact_sha256": {name: sha256(path) for name, path in artifacts.items() if path.is_file()},
        },
        "sources": {"git_revision": git_rev, "clean_worktree": not git_status,
                    "sha256": source_sha},
        "coverage_impact": {
            "urg_rerun": False,
            "code_coverage_delta": "NOT_MEASURED; Formal does not create URG hits",
            "raw_and_adjusted": {"branch": "525/637", "condition": "658/849",
                                 "line": "3351/3796", "toggle": "84340/104480",
                                 "fsm_state": "13/13", "fsm_transition": "17/22",
                                 "legal_functional": "392/392", "approved_waivers": 0,
                                 "active_exclusions": 0, "gate": "RAW_100_OPEN"},
        },
        "errors": errors,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    output = args.output.resolve() if args.output else formal_dir / "thermo5_dpd_identity_stall_audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, "errors": errors, "output": str(output)}, sort_keys=True))
    return 0 if status != "OPEN" else 1


if __name__ == "__main__":
    raise SystemExit(main())
