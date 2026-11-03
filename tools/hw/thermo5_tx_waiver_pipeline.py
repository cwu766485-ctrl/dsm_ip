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
from collections import Counter
import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import tempfile

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


FIELDS = (
    "waiver_id", "configuration", "instance", "source_file", "source_line",
    "metric", "bin", "reason", "candidate_audit", "candidate_audit_sha256",
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


def _repo_relative(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise WaiverError(f"audit input escapes repository: {path}") from exc


def _verify_bound_manifests(audit: dict, repo_root: Path, gap_ledger: Path,
                            compile_manifest: Path, configuration_sha256: str) -> dict:
    inputs = audit.get("inputs")
    required = {"raw_gap_ledger", "product_compile_manifest",
                "raw_adjusted_report_manifest", "vdb_manifest", "formal_review"}
    if not isinstance(inputs, dict) or not required.issubset(inputs):
        raise WaiverError("candidate audit omits one or more bound evidence manifests")
    expected_paths = {
        "raw_gap_ledger": gap_ledger,
        "product_compile_manifest": compile_manifest,
    }
    for name, expected_path in expected_paths.items():
        item = inputs[name]
        if item.get("path") != _repo_relative(expected_path, repo_root):
            raise WaiverError(f"candidate audit {name} path differs from CLI input")
        if item.get("sha256") != sha256(expected_path):
            raise WaiverError(f"candidate audit {name} SHA differs from CLI input")
    for name in required - set(expected_paths):
        item = inputs[name]
        path = _safe_repo_file(repo_root, item.get("path", ""), name)
        if item.get("sha256") != sha256(path):
            raise WaiverError(f"candidate audit {name} SHA is stale")
    if audit.get("schema") != "thermo5_tx_waiver_candidate_audit":
        raise WaiverError("unsupported candidate-audit schema")
    if audit.get("product_configuration_fingerprint") != configuration_sha256:
        raise WaiverError("candidate audit product configuration fingerprint is stale")
    manifest_path = _safe_repo_file(repo_root, inputs["product_compile_manifest"]["path"],
                                    "product compile manifest")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    _verify_audit_tools(manifest, repo_root)
    if audit.get("product_source_sha") != manifest.get("product_source_sha"):
        raise WaiverError("candidate audit product source SHA differs from compile manifest")

    report_path = _safe_repo_file(repo_root, inputs["raw_adjusted_report_manifest"]["path"],
                                  "Raw/Adjusted report manifest")
    vdb_path = _safe_repo_file(repo_root, inputs["vdb_manifest"]["path"], "VDB manifest")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    vdb = json.loads(vdb_path.read_text(encoding="utf-8"))
    raw_vdbs = [value for value in report.get("raw_command", []) if value.endswith(".vdb")]
    adjusted_vdbs = [value for value in report.get("adjusted_command", []) if value.endswith(".vdb")]
    canonical_vdb_sha = hashlib.sha256(
        json.dumps(vdb, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    inventory = [vdb.get("design", {}).get("path")]
    inventory.extend(item.get("path") for item in vdb.get("tests", []))
    common = report.get("common_inputs", {})
    if not raw_vdbs or raw_vdbs != adjusted_vdbs or raw_vdbs != inventory:
        raise WaiverError("Raw/Adjusted reports do not use the exact VDB manifest list")
    if common.get("design_vdb") != raw_vdbs[0] or common.get("test_vdbs") != raw_vdbs[1:]:
        raise WaiverError("URG common-input inventory differs from its command")
    if (report.get("vdb_manifest_sha256") != canonical_vdb_sha
            or report.get("vdb_manifest") != vdb):
        raise WaiverError("URG report manifest does not bind the supplied VDB manifest")
    if report.get("approved_waiver_count") != 0 or report.get("adjusted_exclusions_applied"):
        raise WaiverError("candidate audit baseline already has approved exclusions")
    if report.get("raw_summary") != report.get("adjusted_summary"):
        raise WaiverError("Raw and Adjusted report summaries differ in the candidate baseline")
    return {"manifest": manifest, "report": report, "vdb": vdb}


def _verify_support_files(files: dict, repo_root: Path) -> None:
    if not isinstance(files, dict) or not files:
        raise WaiverError("candidate evidence does not hash its supporting files")
    for relative, digest in files.items():
        artifact = _safe_repo_file(repo_root, relative, "candidate evidence artifact")
        if sha256(artifact) != digest:
            raise WaiverError(f"candidate evidence artifact SHA mismatch: {relative}")


def _verify_configuration_candidate(candidate: dict, gap: dict[str, str],
                                    repo_root: Path, compile_manifest: dict) -> dict:
    proof = candidate.get("proof", {})
    if proof.get("evidence_type") != "configuration" or proof.get("elaboration_status") != "elaborated_exactly":
        raise WaiverError("configuration candidate lacks an exact elaboration record")
    if proof.get("elaborated_parameters") != gap["product_parameters"]:
        raise WaiverError("configuration candidate parameter tuple is stale")
    context = proof.get("source_context", {})
    _verify_support_files(context, repo_root)
    # Re-derive the configuration proof from the current Raw tuple and source.
    # The audit utility is hash-bound by the product compile manifest, so this
    # keeps the generator fail-closed as new exact parameter rules are added.
    from tools.hw.thermo5_tx_waiver_candidate_audit import _configuration_rule

    waiver = {
        "source_file": candidate["source_file"],
        "source_line": str(candidate["source_line"]),
        "instance": candidate["instance"],
        "metric": candidate["metric"],
    }
    expected = _configuration_rule(waiver, gap, repo_root, compile_manifest)
    if expected is None or proof != expected:
        raise WaiverError("configuration proof does not match exact current-source rule")
    return {"evidence_type": "configuration", "proof_rule_id": expected["proof_rule_id"]}


def _verify_formal_candidate(candidate: dict, repo_root: Path,
                             audit: dict, bound: dict) -> dict:
    proof = candidate.get("proof", {})
    if proof.get("evidence_type") != "formal":
        raise WaiverError("Formal candidate has no Formal evidence record")
    if (proof.get("assertion_status") != "proven"
            or proof.get("target_cover_status") != "uncoverable"
            or proof.get("blackboxes") != 0
            or proof.get("tautological") is not False
            or proof.get("non_vacuous") is not True):
        raise WaiverError("Formal candidate is inconclusive, vacuous, or has unresolved black boxes")
    activity = proof.get("activity_covers")
    if not isinstance(activity, list) or not activity or any(item.get("status") != "covered" for item in activity):
        raise WaiverError("Formal candidate lacks an independent activity witness")
    allowed = {"thermo5_frame_tail_harness.asm_source_stable"}
    assumptions = proof.get("assumptions")
    if not isinstance(assumptions, list) or not set(assumptions).issubset(allowed):
        raise WaiverError("Formal candidate contains an unreviewed assumption")
    formal_record = candidate.get("formal_review_record", {})
    formal_review_path = _safe_repo_file(
        repo_root, audit["inputs"]["formal_review"]["path"], "Formal review"
    )
    formal_review = json.loads(formal_review_path.read_text(encoding="utf-8"))
    matches = [item for item in formal_review.get("bins", [])
               if item.get("semantic_bin_id") == candidate.get("semantic_bin_id")]
    if len(matches) != 1 or matches[0] != formal_record:
        raise WaiverError("Formal candidate does not match the tracked source-bound review record")
    formal_run = audit.get("formal_runs", {}).get(proof.get("formal_run_key"), {})
    if formal_run.get("blackboxes") != 0 or formal_run.get("formal_source_sha256") != formal_record.get("source_sha256"):
        raise WaiverError("Formal run inventory differs from its reviewed source hashes")
    files = formal_run.get("evidence_files", {})
    for role in ("properties", "setup", "console"):
        item = files.get(role, {})
        path = _safe_repo_file(repo_root, item.get("path", ""), f"Formal {role} snapshot")
        if sha256(path) != item.get("sha256") or item.get("sha256") != formal_record.get("evidence_sha256", {}).get(role):
            raise WaiverError(f"Formal {role} snapshot is stale")
    console = _safe_repo_file(repo_root, files["console"]["path"], "Formal console").read_text(encoding="utf-8", errors="replace")
    properties = _safe_repo_file(repo_root, files["properties"]["path"], "Formal properties").read_text(encoding="utf-8", errors="replace")
    if not re.search(r"Number of Black-Box Instances\s*=\s*0\b", console):
        raise WaiverError("Formal console lacks a zero-black-box report")
    if re.search(r"tautolog", console, re.IGNORECASE):
        raise WaiverError("Formal console reports a tautological goal")
    for name, expected in ((proof["assertion"], "proven"), (proof["target_cover"], "uncoverable")):
        result = re.search(rf"PROP_I_RESULT:\s+{re.escape(name)}\s+(proven|uncoverable|covered(?::\d+)?|inconclusive|failed)\b", console)
        if not result or result.group(1) != expected or not re.search(rf"\b{re.escape(name)}\b", properties):
            raise WaiverError(f"Formal snapshot no longer proves exact result {name}")
    activity = proof.get("activity_covers", [])
    logged_covered = set(re.findall(
        r"PROP_I_RESULT:\s+([A-Za-z0-9_.$]+)\s+covered(?::\d+)?\b", console
    ))
    activity_names = [item.get("name") for item in activity if isinstance(item, dict)]
    if (not activity_names or len(activity_names) != len(activity)
            or len(activity_names) != len(set(activity_names))
            or any(name not in logged_covered for name in activity_names)):
        raise WaiverError("Formal activity witness is absent or does not match the console")
    for relative, expected_sha in formal_record.get("source_sha256", {}).items():
        source = _safe_repo_file(repo_root, relative, "Formal source")
        if sha256(source) != expected_sha:
            raise WaiverError(f"Formal source hash changed since proof: {relative}")
    if assumptions:
        harness_path = "dv/uvm/formal/thermo5_frame_tail_harness.sv"
        harness = _safe_repo_file(repo_root, harness_path, "Formal assumption harness")
        if not re.search(r"asm_source_stable\s*:\s*assume\s+property", harness.read_text(encoding="utf-8", errors="replace")):
            raise WaiverError("allowed source-stability assumption is absent from its harness")
    return {"evidence_type": "formal", "assertion": proof["assertion"],
            "target_cover": proof["target_cover"]}


def _verify_candidate_audit(row: dict[str, str], gap: dict[str, str], gaps: list[dict[str, str]],
                            audit_path: Path, repo_root: Path,
                            configuration_sha256: str, gap_ledger_path: Path,
                            compile_manifest_path: Path) -> dict:
    if sha256(audit_path) != row["candidate_audit_sha256"]:
        raise WaiverError(f"candidate-audit SHA mismatch for {row['waiver_id']}")
    try:
        audit = json.loads(audit_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise WaiverError("candidate audit must be structured JSON") from exc
    bound = _verify_bound_manifests(audit, repo_root, gap_ledger_path,
                                    compile_manifest_path, configuration_sha256)
    matches = [item for item in audit.get("candidates", [])
               if item.get("waiver_id") == row["waiver_id"]]
    if len(matches) != 1:
        raise WaiverError(f"candidate audit has {len(matches)} entries for {row['waiver_id']}")
    candidate = matches[0]
    expected = {
        "raw_bin_id": gap["bin_id"], "semantic_bin_id": gap["semantic_bin_id"],
        "configuration": gap["configuration"], "instance": gap["instance"],
        "source_file": row["source_file"], "source_line": int(row["source_line"]),
        "metric": METRIC_ALIASES[row["metric"].strip().lower()],
        "source_sha256": row["source_sha256"],
        "product_source_sha": gap["product_source_sha"],
        "product_parameters": gap["product_parameters"], "raw_status": gap["status"],
        "raw_retained": True,
    }
    for key, value in expected.items():
        if candidate.get(key) != value:
            raise WaiverError(f"candidate audit {key} mismatch for {row['waiver_id']}")
    if not gap["status"].startswith("OPEN"):
        raise WaiverError("candidate audit must preserve an OPEN Raw bin status")
    disposition = candidate.get("disposition")
    if disposition not in {"CONFIG_UNREACHABLE", "FORMAL_UNREACHABLE", "REACHABLE", "UNRESOLVED"}:
        raise WaiverError(f"unsupported candidate disposition: {disposition}")
    if disposition == "CONFIG_UNREACHABLE":
        proof = _verify_configuration_candidate(candidate, gap, repo_root,
                                                bound["manifest"])
    elif disposition == "FORMAL_UNREACHABLE":
        proof = _verify_formal_candidate(candidate, repo_root, audit, bound)
    else:
        if candidate.get("proof") or candidate.get("evidence_files"):
            raise WaiverError("reachable/unresolved candidate cannot carry a waiver proof")
        proof = {"evidence_type": disposition.lower()}
    return {"candidate": candidate, "audit": audit, "proof": proof,
            "candidate_audit_sha256": sha256(audit_path)}


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
    audit_references = {(row.get("candidate_audit", ""),
                         row.get("candidate_audit_sha256", "")) for row in waivers}
    if len(audit_references) != 1:
        raise WaiverError("all waiver rows must bind one common structured candidate audit")
    audit_relative, audit_digest = next(iter(audit_references))
    if not audit_relative or not audit_digest:
        raise WaiverError("waiver rows have no structured candidate audit reference")
    common_audit_path = _safe_repo_file(repo_root, audit_relative, "candidate audit")
    if sha256(common_audit_path) != audit_digest:
        raise WaiverError("common candidate-audit SHA differs from the waiver inventory")
    common_audit = json.loads(common_audit_path.read_text(encoding="utf-8"))
    candidate_records = common_audit.get("candidates")
    if not isinstance(candidate_records, list):
        raise WaiverError("candidate audit has no candidate record list")
    candidate_ids = [item.get("waiver_id") for item in candidate_records if isinstance(item, dict)]
    candidate_dispositions = Counter(
        item.get("disposition") for item in candidate_records if isinstance(item, dict)
    )
    if (len(candidate_ids) != len(candidate_records)
            or len(candidate_ids) != len(set(candidate_ids))
            or common_audit.get("candidate_count") != len(candidate_records)
            or common_audit.get("disposition_counts") != dict(sorted(candidate_dispositions.items()))
            or common_audit.get("approved_count") != 0
            or common_audit.get("active_exclusions") != 0
            or common_audit.get("raw_bin_denominators_changed") is not False
            or common_audit.get("raw_statuses_changed") is not False):
        raise WaiverError("candidate-audit inventory/counts or Raw-preservation markers are inconsistent")
    for row in waivers:
        missing = [field for field in FIELDS if not row.get(field, "").strip() and
                   field not in {"candidate_audit", "candidate_audit_sha256", "reviewer",
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

        if not row["candidate_audit"].strip() or not row["candidate_audit_sha256"].strip():
            raise WaiverError(f"waiver {row['waiver_id']} has no structured candidate audit")
        candidate_path = _safe_repo_file(repo_root, row["candidate_audit"], "candidate_audit")
        verified = _verify_candidate_audit(
            row, gap, gaps, candidate_path, repo_root, config_hash, gap_ledger, compile_manifest
        )
        candidate = verified["candidate"]

        status = row["review_status"].strip().upper()
        if status == "PENDING":
            if row["reviewer"].strip() or row["approval_reference"].strip() or row["el_directive"].strip():
                raise WaiverError("pending waiver must not contain approval or active .el text")
            pending.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                            "semantic_bin_id": gap["semantic_bin_id"], "status": "PENDING",
                            "disposition": candidate["disposition"]})
            continue
        if status != "APPROVED":
            if status == "REJECTED":
                pending.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                                "semantic_bin_id": gap["semantic_bin_id"], "status": "REJECTED",
                                "disposition": candidate["disposition"]})
                if row["el_directive"].strip() or row["reviewer"].strip() or row["approval_reference"].strip():
                    raise WaiverError("rejected waiver cannot carry active approval or .el data")
                continue
            raise WaiverError(f"unsupported waiver review status: {status}")
        if candidate["disposition"] not in {"CONFIG_UNREACHABLE", "FORMAL_UNREACHABLE"}:
            raise WaiverError(f"waiver {row['waiver_id']} is not an audited unreachable candidate")
        if not row["reviewer"].strip() or not APPROVAL_RE.fullmatch(row["approval_reference"].strip()):
            raise WaiverError("approved waiver requires reviewer and GitHub PR review reference")
        if not row["el_directive"].strip():
            raise WaiverError("approved waiver requires an exact native URG .el record")
        directive = _native_urg_directive(row, repo_root)
        proof = verified["proof"]
        approved.append({"waiver_id": row["waiver_id"], "raw_bin_id": gap["bin_id"],
                         "semantic_bin_id": gap["semantic_bin_id"], "instance": gap["instance"],
                         "source_file": row["source_file"], "source_line": int(row["source_line"]),
                         "metric": METRIC_ALIASES[row["metric"].strip().lower()],
                         "reviewer": row["reviewer"], "approval_reference": row["approval_reference"],
                         "disposition": candidate["disposition"],
                         "candidate_audit_sha256": verified["candidate_audit_sha256"],
                         "proof": proof, "el_directive": directive})

    if set(candidate_ids) != seen_ids:
        raise WaiverError("candidate audit does not exactly match the CSV waiver row set")

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
        "candidate_audit_sha256": sha256(_safe_repo_file(
            repo_root, waivers[0]["candidate_audit"], "candidate_audit"
        )) if waivers else None,
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
