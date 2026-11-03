#!/usr/bin/env python3.12
"""Fail-closed, exact-bin waiver review for the Thermo5 TX product.

Pending rows are retained for audit and never generate URG exclusions. An
approved row must match one current Raw bin, the current source/configuration,
and a source-bound Formal or elaboration evidence record. The script writes a
new .el file atomically and records every accepted/rejected candidate.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile


FIELDS = (
    "waiver_id", "configuration", "instance", "source_file", "source_line",
    "metric", "bin", "reason", "proof_evidence", "proof_evidence_sha256",
    "source_sha256", "review_status", "reviewer", "approval_reference",
    "el_directive",
)
METRIC_ALIASES = {"condition": "cond", "cond": "cond", "toggle": "toggle",
                  "tgl": "toggle", "line": "line", "branch": "branch",
                  "fsm": "fsm", "assert": "assert"}
APPROVAL_RE = re.compile(r"^https://github\.com/[^/]+/[^/]+/pull/[1-9][0-9]*#pullrequestreview-[1-9][0-9]*$")


class WaiverError(ValueError):
    """A waiver row, evidence record, or input manifest is stale or invalid."""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        if tuple(reader.fieldnames or ()) != FIELDS:
            raise WaiverError("waiver CSV header does not match the audited schema")
        return list(reader)


def _read_gap_ledger(path: Path) -> list[dict[str, str]]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", newline="", encoding="utf-8") as stream:
        reader = csv.DictReader(stream)
        required = {"bin_id", "semantic_bin_id", "configuration", "instance",
                    "source_files", "metric", "branch_target_line", "source_position",
                    "source_file_sha256", "product_parameters", "product_source_sha",
                    "status"}
        if not required.issubset(reader.fieldnames or ()):
            raise WaiverError("source-linked gap ledger lacks exact bin/audit columns")
        return list(reader)


def _configuration_fingerprint(manifest: dict) -> str:
    provenance = manifest.get("compile_provenance", {})
    fields = {
        "base_commit": manifest.get("base_commit"),
        "product_source_sha": manifest.get("product_source_sha"),
        "scope": manifest.get("scope"),
        "defines": provenance.get("configuration_defines"),
        "top": provenance.get("top"),
        "filelist_sha256": provenance.get("product_filelist_sha256"),
        "coverage_hierarchy_sha256": provenance.get("coverage_hierarchy_sha256"),
        "source_file_sha256": manifest.get("source_file_sha256"),
    }
    if not fields["base_commit"] or not fields["defines"] or not fields["filelist_sha256"]:
        raise WaiverError("product compile manifest does not bind the elaborated configuration")
    encoded = json.dumps(fields, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def _verify_audit_tools(manifest: dict, repo_root: Path) -> None:
    tools = manifest.get("audit_tool_sha256", {})
    if not isinstance(tools, dict) or not tools:
        raise WaiverError("product compile manifest has no audit-tool hashes")
    for relative, expected in tools.items():
        tool = _safe_repo_file(repo_root, relative, "audit tool")
        if sha256(tool) != expected:
            raise WaiverError(f"audit tool SHA is stale: {relative}")


def _source_hash_from_ledger(row: dict[str, str], source_file: str) -> str:
    for item in row["source_file_sha256"].split(";"):
        if "=" not in item:
            continue
        name, digest = item.rsplit("=", 1)
        if name == source_file:
            return digest
    raise WaiverError(f"gap ledger has no source hash for {source_file}")


def _safe_repo_file(repo_root: Path, relative: str, what: str) -> Path:
    if not relative or Path(relative).is_absolute():
        raise WaiverError(f"{what} must be a repository-relative path")
    path = (repo_root / relative).resolve()
    if not path.is_relative_to(repo_root.resolve()) or not path.is_file():
        raise WaiverError(f"{what} is missing or escapes the repository: {relative}")
    return path


def _source_line(gap: dict[str, str]) -> str:
    match = re.search(r"(?:line:|:)(\d+)(?:\b|$)", gap.get("source_position", ""))
    if match:
        return match.group(1)
    return gap.get("branch_target_line", "")


def _match_gap(row: dict[str, str], gaps: list[dict[str, str]]) -> dict[str, str]:
    metric = METRIC_ALIASES.get(row["metric"].strip().lower())
    if metric is None:
        raise WaiverError(f"unsupported coverage metric: {row['metric']}")
    matches = [gap for gap in gaps
               if gap["bin_id"] == row["bin"]
               and gap["configuration"] == row["configuration"]
               and gap["instance"] == row["instance"]
               and row["source_file"] in gap["source_files"].split(";")
               and _source_line(gap) == row["source_line"]
               and gap["metric"] == metric]
    if len(matches) != 1:
        raise WaiverError(f"waiver {row['waiver_id']} maps to {len(matches)} current Raw bins")
    return matches[0]


def _native_urg_directive(row: dict[str, str], repo_root: Path) -> dict[str, str]:
    try:
        directive = json.loads(row["el_directive"])
    except json.JSONDecodeError as exc:
        raise WaiverError("approved URG directive must be a JSON object containing native scope fields") from exc
    if not isinstance(directive, dict) or set(directive) != {"checksum", "module", "entry"}:
        raise WaiverError("native URG directive requires exactly checksum, module, and entry")
    checksum = directive["checksum"]
    module = directive["module"]
    entry = directive["entry"]
    if not isinstance(checksum, str) or not re.fullmatch(r"// CHECKSUM: [A-Za-z0-9_.:+/=-]+", checksum):
        raise WaiverError("native URG directive has an invalid checksum record")
    if not isinstance(module, str) or not re.fullmatch(r'// ANNOTATION: "ModuleName: [A-Za-z_$][A-Za-z0-9_$]*"', module):
        raise WaiverError("native URG directive has an invalid module record")
    source = _safe_repo_file(repo_root, row["source_file"], "source_file")
    source_text = source.read_text(encoding="utf-8", errors="replace")
    declared = set(re.findall(r"^\s*module\s+(?:automatic\s+)?([A-Za-z_$][A-Za-z0-9_$]*)", source_text, re.M))
    module_name = re.fullmatch(r'// ANNOTATION: "ModuleName: ([A-Za-z_$][A-Za-z0-9_$]*)"', module).group(1)
    if module_name not in declared:
        raise WaiverError("native URG module does not match a declaration in source_file")
    if not isinstance(entry, str) or "\n" in entry or "\r" in entry or any(c in entry for c in "*?"):
        raise WaiverError("native URG entry must be one explicit non-wildcard record")
    kind = re.match(r"^(Block|Condition|Branch|Toggle|Fsm|Transition)\s+\S", entry)
    expected_kinds = {"line": {"Block"}, "cond": {"Condition"}, "branch": {"Branch"},
                      "toggle": {"Toggle"}, "fsm": {"Fsm", "Transition"}, "assert": {"Assertion"}}
    metric = METRIC_ALIASES[row["metric"].strip().lower()]
    if not kind or kind.group(1) not in expected_kinds[metric]:
        raise WaiverError(f"native URG entry kind does not match metric {metric}")
    return {"checksum": checksum, "module": module, "entry": entry}


def _verify_proof(row: dict[str, str], gap: dict[str, str], repo_root: Path,
                  configuration_sha256: str) -> dict:
    evidence_path = _safe_repo_file(repo_root, row["proof_evidence"], "proof_evidence")
    observed_hash = sha256(evidence_path)
    if observed_hash != row["proof_evidence_sha256"]:
        raise WaiverError(f"proof evidence SHA mismatch for {row['waiver_id']}")
    try:
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise WaiverError("approved proof evidence must be a structured JSON record") from exc

    native_directive = _native_urg_directive(row, repo_root)
    expected = {
        "disposition": "PROVEN_UNREACHABLE",
        "native_urg_directive": native_directive,
        "product_source_sha": gap["product_source_sha"],
        "product_parameters": gap["product_parameters"],
        "configuration_sha256": configuration_sha256,
        "configuration": gap["configuration"],
        "instance": gap["instance"],
        "source_file": row["source_file"],
        "source_line": int(row["source_line"]),
        "metric": METRIC_ALIASES[row["metric"].strip().lower()],
        "raw_bin_id": gap["bin_id"],
        "semantic_bin_id": gap["semantic_bin_id"],
        "source_sha256": row["source_sha256"],
    }
    for key, value in expected.items():
        if evidence.get(key) != value:
            raise WaiverError(f"proof evidence {key} mismatch for {row['waiver_id']}")
    if evidence.get("assumptions") != [] or evidence.get("blackboxes") != 0:
        raise WaiverError("Formal evidence must have zero assumptions and zero black boxes")
    if evidence.get("tautological") is not False or evidence.get("non_vacuous") is not True:
        raise WaiverError("Formal/configuration evidence is vacuous or not audited")

    kind = evidence.get("evidence_type")
    if kind == "formal":
        if evidence.get("assertion_status") != "proven" or evidence.get("target_cover_status") != "uncoverable":
            raise WaiverError("Formal proof must prove the exact assertion and mark its target cover uncoverable")
        activity = evidence.get("activity_covers")
        if (not isinstance(activity, list) or not activity
                or any(not isinstance(item, dict) or item.get("status") != "covered"
                       for item in activity)):
            raise WaiverError("Formal proof lacks a non-vacuous legal activity cover witness")
    elif kind == "configuration":
        if evidence.get("elaboration_status") != "elaborated_exactly":
            raise WaiverError("configuration proof lacks an exact elaboration disposition")
        if evidence.get("elaborated_parameters") != gap["product_parameters"]:
            raise WaiverError("configuration proof parameter tuple is stale")
    else:
        raise WaiverError("proof evidence_type must be formal or configuration")

    proof_files = evidence.get("evidence_files")
    if not isinstance(proof_files, dict) or not proof_files:
        raise WaiverError("proof evidence does not hash its supporting reports")
    for relative, digest in proof_files.items():
        artifact = _safe_repo_file(repo_root, relative, "evidence artifact")
        if sha256(artifact) != digest:
            raise WaiverError(f"supporting evidence hash mismatch: {relative}")
    return {"path": row["proof_evidence"], "sha256": observed_hash,
            "evidence_type": kind}


def audit_and_generate(*, waivers_csv: Path, gap_ledger: Path, compile_manifest: Path,
                       repo_root: Path, el_output: Path, audit_output: Path) -> dict:
    waivers = _read_csv(waivers_csv)
    gaps = _read_gap_ledger(gap_ledger)
    manifest = json.loads(compile_manifest.read_text(encoding="utf-8"))
    _verify_audit_tools(manifest, repo_root)
    config_hash = _configuration_fingerprint(manifest)
    pending: list[dict] = []
    approved: list[dict] = []
    seen_ids: set[str] = set()
    seen_bins: set[str] = set()
    for row in waivers:
        missing = [field for field in FIELDS if not row.get(field, "").strip() and
                   field not in {"proof_evidence", "proof_evidence_sha256", "reviewer",
                                 "approval_reference", "el_directive"}]
        if missing:
            raise WaiverError(f"waiver row is missing required fields: {missing}")
        if row["waiver_id"] in seen_ids or row["bin"] in seen_bins:
            raise WaiverError("waiver IDs and exact Raw bin IDs must be unique")
        seen_ids.add(row["waiver_id"])
        seen_bins.add(row["bin"])
        gap = _match_gap(row, gaps)
        current_sha = _source_hash_from_ledger(gap, row["source_file"])
        source = _safe_repo_file(repo_root, row["source_file"], "source_file")
        actual_sha = sha256(source)
        if row["source_sha256"] != current_sha or actual_sha != current_sha:
            raise WaiverError(f"source SHA is stale for waiver {row['waiver_id']}")

        status = row["review_status"].strip().upper()
        if status == "PENDING":
            if row["reviewer"].strip() or row["approval_reference"].strip() or row["el_directive"].strip():
                raise WaiverError("pending waiver must not contain approval or active .el text")
            pending.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                            "semantic_bin_id": gap["semantic_bin_id"], "status": "PENDING"})
            continue
        if status != "APPROVED":
            if status == "REJECTED":
                pending.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                                "semantic_bin_id": gap["semantic_bin_id"], "status": "REJECTED"})
                if row["el_directive"].strip():
                    raise WaiverError("rejected waiver cannot contain active .el text")
                continue
            raise WaiverError(f"unsupported waiver review status: {status}")
        if gap["status"] != "PROVEN_UNREACHABLE":
            raise WaiverError(f"waiver {row['waiver_id']} targets a Raw bin not proven unreachable")
        if not row["reviewer"].strip() or not APPROVAL_RE.fullmatch(row["approval_reference"].strip()):
            raise WaiverError("approved waiver requires reviewer and GitHub PR review reference")
        if not row["el_directive"].strip():
            raise WaiverError("approved waiver requires an exact native URG .el record")
        directive = _native_urg_directive(row, repo_root)
        proof = _verify_proof(row, gap, repo_root, config_hash)
        approved.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                         "semantic_bin_id": gap["semantic_bin_id"], "instance": gap["instance"],
                         "source_file": row["source_file"], "source_line": int(row["source_line"]),
                         "metric": METRIC_ALIASES[row["metric"].strip().lower()],
                         "reviewer": row["reviewer"], "approval_reference": row["approval_reference"],
                         "proof": proof, "el_directive": directive})

    el_output.parent.mkdir(parents=True, exist_ok=True)
    rendered = "// Generated from approved, source-bound Thermo5 TX waiver rows.\n"
    rendered += "// Do not edit; regenerate with tools/hw/thermo5_tx_waiver_pipeline.py.\n"
    emitted_entries: set[tuple[str, str, str, str]] = set()
    for item in approved:
        directive = item["el_directive"]
        signature = (directive["checksum"], directive["module"], item["instance"], directive["entry"])
        if signature in emitted_entries:
            raise WaiverError("multiple approved bins map to one native URG exclusion entry")
        emitted_entries.add(signature)
        rendered += (directive["checksum"] + "\n" + directive["module"] + "\n"
                     + "INSTANCE: " + item["instance"] + "\n"
                     + f'// ANNOTATION: "Evidence: {item["raw_bin_id"]}; {item["semantic_bin_id"]}"\n'
                     + directive["entry"] + "\n")
    fd, temp_name = tempfile.mkstemp(prefix=el_output.name + ".", dir=el_output.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
            stream.write(rendered)
        os.replace(temp_name, el_output)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)

    result = {
        "schema_version": 1,
        "product_configuration_fingerprint": config_hash,
        "waiver_csv_sha256": sha256(waivers_csv),
        "gap_ledger_sha256": sha256(gap_ledger),
        "compile_manifest_sha256": sha256(compile_manifest),
        "generated_el_sha256": sha256(el_output),
        "approved_count": len(approved),
        "pending_count": sum(x["status"] == "PENDING" for x in pending),
        "rejected_count": sum(x["status"] == "REJECTED" for x in pending),
        "approved": approved,
        "not_approved": pending,
        "exclusions_applied": bool(approved),
    }
    audit_output.parent.mkdir(parents=True, exist_ok=True)
    audit_output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--waivers-csv", required=True, type=Path)
    parser.add_argument("--gap-ledger", required=True, type=Path)
    parser.add_argument("--compile-manifest", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--el-output", required=True, type=Path)
    parser.add_argument("--audit-output", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = audit_and_generate(waivers_csv=args.waivers_csv, gap_ledger=args.gap_ledger,
                                    compile_manifest=args.compile_manifest, repo_root=args.repo_root,
                                    el_output=args.el_output, audit_output=args.audit_output)
    except (OSError, json.JSONDecodeError, WaiverError, KeyError, TypeError, ValueError) as exc:
        parser.exit(3, f"THERMO5_TX_WAIVER_AUDIT_ERROR: {exc}\n")
    print(json.dumps({key: result[key] for key in
                      ("approved_count", "pending_count", "rejected_count",
                       "exclusions_applied", "product_configuration_fingerprint")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
