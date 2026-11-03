#!/usr/bin/env python3.12
"""Fail-closed audit for the Thermo5 one-tap DPD vector stall-hold proof."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[2]
TOP = "thermo5_dpd_payload_hold_harness"
RTL_SOURCES = (
    "rtl/dpd/dpd_poly.v",
    "rtl/dpd/dpd_memory_poly.v",
    "rtl/dpd/dpd_vector16_memory_poly.sv",
)
FORMAL_SOURCES = (
    "dv/uvm/formal/thermo5_dpd_payload_hold_harness.sv",
    "dv/uvm/formal/run_thermo5_dpd_payload_hold_fpv.tcl",
    "dv/uvm/formal/run_thermo5_dpd_payload_hold_fpv.py",
    "tools/hw/audit_thermo5_dpd_payload_hold_fpv.py",
)
EXPECTED_COVERS = {
    f"{TOP}.c_input_accept": "covered",
    f"{TOP}.c_output_stall": "covered",
    f"{TOP}.c_stall_release": "covered",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_path(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path.resolve())


def parse_rows(text: str) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line in text.splitlines():
        if " - " not in line:
            continue
        left, right = line.split(" - ", 1)
        if not re.match(r"^\s*\[\s*\d+\s*\]", left):
            continue
        m = re.search(
            r"\]\s+(proven|failed|inconclusive|undetermined|unprocessed|"
            r"covered|uncoverable|constrained)(?:\([^)]*\))?",
            left,
        )
        if not m:
            continue
        rows.append({
            "state": m.group(1),
            "non_vacuous": "(non_vacuous)" in left,
            "name": right.strip(),
        })
    return rows


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--formal-dir", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    formal_dir = args.formal_dir.resolve()
    errors: list[str] = []
    names = ("vcf.log", "run_result.json", "setup.txt", "properties.txt", "engines.txt")
    files = {name: formal_dir / name for name in names}
    for name, path in files.items():
        if not path.is_file():
            errors.append(f"missing formal artifact: {name}")

    console = files["vcf.log"].read_text(errors="replace") if files["vcf.log"].is_file() else ""
    setup = files["setup.txt"].read_text(errors="replace") if files["setup.txt"].is_file() else ""
    props = files["properties.txt"].read_text(errors="replace") if files["properties.txt"].is_file() else ""
    engines = files["engines.txt"].read_text(errors="replace") if files["engines.txt"].is_file() else ""
    run_state = json.loads(files["run_result.json"].read_text()) if files["run_result.json"].is_file() else {}
    rows = parse_rows(props)
    assertions = {str(x["name"]): x for x in rows
                  if str(x["name"]).startswith(TOP + ".") and ".a_" in str(x["name"])}
    covers = {str(x["name"]): str(x["state"]) for x in rows
              if str(x["name"]).startswith(TOP + ".") and ".c_" in str(x["name"])}
    expected_assertions = {f"{TOP}.a_meta_hold"}
    for lane in range(16):
        expected_assertions.add(f"{TOP}.g_lane_hold[{lane}].a_lane_valid_lockstep")
        expected_assertions.add(f"{TOP}.g_lane_hold[{lane}].a_lane_payload_hold")

    if set(assertions) != expected_assertions:
        errors.append(f"assertion inventory mismatch: expected {len(expected_assertions)}, got {len(assertions)}")
    for name, row in assertions.items():
        if row["state"] != "proven":
            errors.append(f"{name}: expected proven, got {row['state']}")
    non_vacuous = {name for name, row in assertions.items() if row["non_vacuous"]}
    expected_non_vacuous = {f"{TOP}.a_meta_hold"} | {
        f"{TOP}.g_lane_hold[{lane}].a_lane_payload_hold" for lane in range(16)
    }
    if non_vacuous != expected_non_vacuous:
        errors.append("metadata and all 16 lane-hold assertions must be non-vacuous")
    for name, state in EXPECTED_COVERS.items():
        if covers.get(name) != state:
            errors.append(f"{name}: expected {state}, got {covers.get(name)}")
    if len(covers) != len(EXPECTED_COVERS):
        errors.append(f"expected exactly 3 Covers, found {len(covers)}")

    constraint_rows = [x for x in rows if x["state"] == "constrained"]
    if len(constraint_rows) != 1 or "rst_n==1" not in str(constraint_rows[0]["name"]):
        errors.append("expected only the reset initialization constraint rst_n==1")
    if re.search(r"\b(?:asm|assume)_\w+", props, re.I):
        errors.append("unexpected environment assumption property")
    if re.search(r"\bassume\s+property\b", (ROOT / FORMAL_SOURCES[0]).read_text(), re.I):
        errors.append("harness contains an environment assume property")
    if "Number of Black-Box Instances = 0" not in console:
        errors.append("zero-black-box evidence is missing")
    if "No setup issues found" not in console:
        errors.append("Formal setup checker did not report clean setup")
    if re.search(r":\s*[1-9]\d*\s*$", setup, re.M):
        errors.append("selected Formal setup checks reported violations")
    for metric in ("Clock violations", "Glitch violations", "Combinational loops", "Multidriven nets"):
        if not re.search(rf"{re.escape(metric)}\s*:\s*0\b", setup):
            errors.append(f"setup report missing zero result for {metric}")
    if "SVA goal(s) have been marked trivially proven/uncoverable" in console:
        errors.append("VC Formal marked a goal tautological")
    if run_state.get("exit_code") != 0 or run_state.get("timeout"):
        errors.append("VC Formal process did not complete with exit code 0")
    if "Version V-2023.12-SP2" not in console:
        errors.append("expected VC Formal V-2023.12-SP2 banner")
    if not engines.strip():
        errors.append("engine report is empty")

    source_hashes = {path: sha256(ROOT / path) for path in RTL_SOURCES + FORMAL_SOURCES
                     if (ROOT / path).is_file()}
    if len(source_hashes) != len(RTL_SOURCES) + len(FORMAL_SOURCES):
        errors.append("one or more source files are missing")
    revision = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    git_status = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
                                capture_output=True, text=True, check=True).stdout.splitlines()
    status = "PASS_SCOPED_DPD_VECTOR_STALL_HOLD" if not errors else "OPEN"
    output = {
        "schema_version": 1,
        "status": status,
        "scope": {
            "product_configuration": {
                "module": "dpd_vector16_memory_poly",
                "lanes": 16,
                "sample_width_bits": 16,
                "max_taps": 1,
                "coefficient_image": "unconstrained runtime coefficient inputs",
                "active_taps": "unconstrained 3-bit input",
                "metadata": "unconstrained 2-bit input",
                "ready_valid_inputs": "unconstrained; zero environment assumptions",
            },
            "properties": {
                "lane_payload_hold": 16,
                "lane_valid_lockstep": 16,
                "metadata_hold": 1,
                "equivalent_to": "stable 512-bit I/Q payload, metadata, and valid under output stall",
            },
        },
        "formal": {
            "tool_banner": next((line.strip() for line in console.splitlines()
                                  if "Version V-" in line), "UNKNOWN"),
            "exit_code": run_state.get("exit_code"),
            "duration_seconds": run_state.get("duration_seconds"),
            "environment_assumptions": 0,
            "reset_initial_constraint": "rst_n==1",
            "black_box_instances": 0 if "Number of Black-Box Instances = 0" in console else None,
            "assertions": assertions,
            "covers": covers,
            "setup_violations": 0 if "No setup issues found" in console else None,
            "run_command": run_state.get("command"),
            "artifact_sha256": {name: sha256(path) for name, path in files.items() if path.is_file()},
            "formal_directory": repo_path(formal_dir),
        },
        "product_rtl": {path: source_hashes[path] for path in RTL_SOURCES},
        "formal_source_sha256": {path: source_hashes[path] for path in FORMAL_SOURCES},
        "source_state": {"git_revision": revision, "worktree_dirty": bool(git_status),
                         "git_status": git_status},
        "coverage_impact": {
            "raw_urg_rerun": False,
            "raw_code_coverage_delta": "NOT_MEASURED; Formal does not create URG hits",
            "raw_adjusted_same_list_metrics_unchanged": {
                "branch": "525/637", "condition": "658/849", "line": "3351/3796",
                "toggle": "84340/104480", "fsm_states": "13/13",
                "fsm_transitions": "17/22", "functional": "392/392",
                "raw_adjusted_equal": True, "approved_waivers": 0, "active_exclusions": 0,
                "raw_report_manifest_sha256": "89a160024a966e65f1bd7db279bc2f6acef3ae7197698bace17a8942838e4840",
                "vdb_manifest_sha256": "dd85345f197cb05f5aa60713b78269c3347ff3b786da4f501de6ef7676a77fa7",
            },
            "code_coverage_gate": "RAW_100_OPEN",
        },
        "errors": errors,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    out_path = args.output.resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": status, "errors": errors, "output": str(out_path)}, sort_keys=True))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
