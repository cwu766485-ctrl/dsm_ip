#!/usr/bin/env python3.12
"""Derive the product compile-source manifest from a VCS compile transcript.

The broad run manifest may contain Formal-only and integration files that are
not inputs to the product VCS executable. This tool narrows source checking to
the local files VCS actually parsed, while retaining and hashing the filelist
and coverage hierarchy that controlled the compilation.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXPECTED_DEFINES = (
    "+define+THERMO5_AXIL_CONTROL",
    "+define+THERMO5_CENTERED_CUBIC",
    "+define+THERMO5_TIDSM_ORDER=2",
    "+define+THERMO5_STEP=5120",
    "+define+THERMO5_DPD_MAX_TAPS=1",
)


class ManifestError(Exception):
    """The compile transcript and source manifest do not form a valid proof."""


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def local_repo_path(value: str, known_paths: set[str]) -> str | None:
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    resolved = path.resolve().as_posix()
    try:
        return Path(resolved).relative_to(ROOT).as_posix()
    except ValueError:
        # Existing licensed VDBs can be produced in a sibling checkout and
        # reviewed from an isolated worktree. Map only a suffix already named
        # in the parent manifest; its content hash is checked below.
        matches = [relative for relative in known_paths
                   if resolved.endswith("/" + relative)]
        return max(matches, key=len) if matches else None


def derive(args: argparse.Namespace) -> dict:
    compile_text = args.compile_log.read_text(encoding="utf-8", errors="replace")
    source_manifest = json.loads(args.source_manifest.read_text(encoding="utf-8"))
    source_hashes = source_manifest.get("source_file_sha256")
    if not isinstance(source_hashes, dict) or not source_hashes:
        raise ManifestError("parent source manifest has no source_file_sha256 map")

    command_match = re.search(
        r"(?ms)^Command:\s*(.*?)(?=\n\s*\n)", compile_text
    )
    if not command_match:
        raise ManifestError("VCS compile command is absent from the transcript")
    command = command_match.group(1).replace("\\\n", " ").replace("\n", " ")
    required_tokens = (
        "-top thermo5_sku_uvm_tb",
        "-cm line+cond+fsm+tgl+branch+assert",
    ) + EXPECTED_DEFINES
    for token in required_tokens:
        if token not in command:
            raise ManifestError(f"compile command does not match product profile: {token}")

    filelist = args.product_filelist.resolve()
    hierarchy = args.coverage_hierarchy.resolve()
    for flag, expected in (("-f", filelist), ("-cm_hier", hierarchy)):
        found = re.search(rf"(?:^|\s){re.escape(flag)}\s+(\S+)", command)
        relative = expected.relative_to(ROOT).as_posix()
        if not found:
            raise ManifestError(f"compile command does not use the requested {flag} input")
        compiled_path = Path(found.group(1)).resolve()
        if compiled_path != expected and not compiled_path.as_posix().endswith("/" + relative):
            raise ManifestError(f"compile command does not use the requested {flag} input")

    compiled_local: set[str] = set()
    for match in re.finditer(
        r"Parsing (?:design|included) file '([^']+)'", compile_text
    ):
        relative = local_repo_path(match.group(1), set(source_hashes))
        if relative is not None:
            compiled_local.add(relative)
    if len(compiled_local) < 40:
        raise ManifestError(
            f"only {len(compiled_local)} local files were recovered from VCS parsing log"
        )

    controlled_inputs = {
        args.product_filelist.resolve().relative_to(ROOT).as_posix(): sha(filelist),
        args.coverage_hierarchy.resolve().relative_to(ROOT).as_posix(): sha(hierarchy),
    }
    selected = set(compiled_local) | set(controlled_inputs)
    mismatches: list[dict[str, str]] = []
    for relative in sorted(selected):
        expected = source_hashes.get(relative)
        if expected is None:
            mismatches.append({"path": relative, "reason": "missing_from_parent_manifest"})
            continue
        observed = sha(ROOT / relative)
        if observed != expected:
            mismatches.append({
                "path": relative,
                "reason": "current_source_sha_mismatch",
                "expected": expected,
                "observed": observed,
            })
    if mismatches:
        raise ManifestError(
            "product compile input hashes do not match the captured source manifest: "
            + json.dumps(mismatches, sort_keys=True)
        )

    audit_tools = (
        "tools/hw/thermo5_tx_product_compile_manifest.py",
        "tools/hw/thermo5_tx_coverage_gate.py",
        "tools/hw/thermo5_tx_waiver_pipeline.py",
        "tools/hw/thermo5_tx_waiver_candidate_audit.py",
        "tools/hw/run_thermo5_tx_urg_dual_report.py",
    )
    unused = sorted(set(source_hashes) - selected)
    return {
        "schema_version": 1,
        "scope": "VCS_PRODUCT_COMPILE_INPUTS",
        "base_commit": source_manifest.get("base_commit"),
        "product_source_sha": source_manifest.get("product_source_sha"),
        "source_file_sha256": {
            relative: source_hashes[relative] for relative in sorted(selected)
        },
        "audit_tool_sha256": {relative: sha(ROOT / relative) for relative in audit_tools},
        "compile_provenance": {
            "compile_log": str(args.compile_log),
            "compile_log_sha256": sha(args.compile_log),
            "parent_source_manifest": str(args.source_manifest),
            "parent_source_manifest_sha256": sha(args.source_manifest),
            "vcs_command": command.strip(),
            "product_filelist": str(args.product_filelist),
            "product_filelist_sha256": sha(filelist),
            "coverage_hierarchy": str(args.coverage_hierarchy),
            "coverage_hierarchy_sha256": sha(hierarchy),
            "top": "thermo5_sku_uvm_tb",
            "configuration_defines": list(EXPECTED_DEFINES),
            "parsed_local_source_count": len(compiled_local),
            "controlled_input_count": len(controlled_inputs),
            "unparsed_parent_manifest_entries": unused,
            "unparsed_parent_manifest_entry_count": len(unused),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compile-log", required=True, type=Path)
    parser.add_argument("--source-manifest", required=True, type=Path)
    parser.add_argument("--product-filelist", required=True, type=Path)
    parser.add_argument("--coverage-hierarchy", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = derive(args)
    except (ManifestError, OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"PRODUCT_MANIFEST_ERROR: {exc}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps({
        "status": "PASS",
        "scope": result["scope"],
        "compiled_local_sources": result["compile_provenance"]["parsed_local_source_count"],
        "manifest_entries": len(result["source_file_sha256"]),
        "parent_manifest_entries_not_compiled": result["compile_provenance"]["unparsed_parent_manifest_entry_count"],
        "compile_log_sha256": result["compile_provenance"]["compile_log_sha256"],
        "output": str(args.output),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
