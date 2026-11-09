#!/usr/bin/env python3.12
"""Map Round 17 exact-bin candidates to native URG analysis-only exclusions.

This tool never changes official waiver approval state. It accepts only
one-to-one mappings to a native object dumped from the same URG input set.
Candidates with stale source hashes, absent instances, ambiguous native
objects, or unsupported semantic IDs remain unmapped in the ledger.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CANDIDATES = ROOT / "docs/verification/data/thermo5-r17/static_reachability_review/thermo5_tx_unreachable_exclusion_candidates.csv"
DEFAULT_REVIEW = ROOT / "docs/verification/data/thermo5-r17/static_reachability_review/coverage_static_reachability_review.csv"
DEFAULT_COMPILE = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
DEFAULT_OUTPUT = ROOT / "docs/verification/data/thermo5-r17/analysis_only"
DEFAULT_VDB_MANIFEST = ROOT / "runs/thermo5_r17_precise_exclusion_20261109_raw_retry2/input_vdb_manifest.json"
DEFAULT_OFFICIAL_WAIVERS = ROOT / "docs/verification/thermo5_tx_waivers.csv"

GROUPS = {
    "A_DPD_PAIR1": {"DPD_PAIR1_ZERO"},
    "B_EF2_FIXED_PARAMETERS": {"EF2_PAIR_LOOKAHEAD_DISABLED", "EF2_INVALID_PARAMETER_GUARD"},
    "C_DPD_TAP_HISTORY": {"DPD_TAP_HISTORY_MAX_TAPS1"},
    "D_CDC_RESIDUAL": {"CDC_RESIDUAL_INVARIANT", "CDC_14_TO_8_END_ARITHMETIC"},
    "E_OTHER_PARAMETERS": {
        "GT_EQUAL_WIDTH_BOUNDARY", "DPD_CONFIG_MAX_TAPS_GUARD",
        "INTERPOLATOR_STAGE2_TAIL_DISABLED", "INTERPOLATOR_PARAMETER_GUARD",
        "PRODUCT_DPD_MAX_TAPS_GUARD", "FRAME_GAIN_HOLD_STATE_DEFAULT",
        "INTERPOLATOR_HOLD_STATE_PARAMETER", "INTERPOLATOR_STAGE1_TAIL_TIED_LOW",
    },
}

METRIC_FILE = {"toggle": "tgl", "line": "line", "branch": "branch", "cond": "cond"}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def line_number(row: dict[str, str]) -> int | None:
    match = re.search(r":(\d+)$", row.get("source_position", ""))
    return int(match.group(1)) if match else None


def strip_comment(line: str) -> str:
    return line[3:] if line.startswith("// ") else line


def parse_native_template(path: Path) -> list[dict]:
    """Read URG's commented native template without inventing object IDs."""
    scopes: list[dict] = []
    scope: dict | None = None
    source: str | None = None
    source_line: int | None = None
    current_object: dict | None = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = strip_comment(raw).strip()
        if line.startswith("CHECKSUM:"):
            scope = {"checksum": line, "module": "", "instance": "", "objects": []}
            scopes.append(scope)
            source = None
            source_line = None
            current_object = None
            continue
        if scope is None:
            continue
        if line.startswith('ANNOTATION: "ModuleName:'):
            scope["module"] = line
            continue
        if line.startswith("INSTANCE:"):
            scope["instance"] = line.split(":", 1)[1].strip()
            continue
        if line.startswith('ANNOTATION: "FileName:'):
            match = re.search(r'FileName: (.*), LineNumber: (\d+)', line)
            if match:
                source = match.group(1)
                source_line = int(match.group(2))
            continue

        toggle = re.fullmatch(r'Toggle\s+(\S+)\s+"(.*)"', line)
        if toggle:
            item = {"kind": "toggle", "name": toggle.group(1), "decl": toggle.group(2),
                    "line": source_line, "source": source, "vectors": []}
            scope["objects"].append(item)
            current_object = item
            continue

        block = re.fullmatch(r'Block\s+(\d+)\s+"(\d+)"\s+"(.*)"', line)
        if block:
            item = {"kind": "line", "id": block.group(1), "checksum": block.group(2),
                    "signature": block.group(3), "line": source_line, "source": source, "vectors": []}
            scope["objects"].append(item)
            current_object = item
            continue

        branch_vector = re.fullmatch(r'Branch\s+(\d+)\s+"(\d+)"\s+"(.*)"\s+\((\d+)\)\s+"(.*)"', line)
        if branch_vector:
            key = ("branch", branch_vector.group(1), branch_vector.group(2))
            parent = next((x for x in reversed(scope["objects"])
                           if (x["kind"], x.get("id"), x.get("checksum")) == key
                           and x["line"] == source_line), None)
            if parent:
                parent["vectors"].append((branch_vector.group(4), branch_vector.group(5)))
            continue
        branch = re.fullmatch(r'Branch\s+(\d+)\s+"(\d+)"\s+"(.*)"', line)
        if branch:
            item = {"kind": "branch", "id": branch.group(1), "checksum": branch.group(2),
                    "signature": branch.group(3), "line": source_line, "source": source, "vectors": []}
            scope["objects"].append(item)
            current_object = item
            continue

        condition_vector = re.fullmatch(r'Condition\s+(\d+)\s+"(\d+)"\s+"(.*)"\s+\((\d+)\s+"(.*)"\)', line)
        if condition_vector:
            key = ("cond", condition_vector.group(1), condition_vector.group(2))
            parent = next((x for x in reversed(scope["objects"])
                           if (x["kind"], x.get("id"), x.get("checksum")) == key
                           and x["line"] == source_line), None)
            if parent:
                parent["vectors"].append((condition_vector.group(4), condition_vector.group(5)))
            continue
        condition = re.fullmatch(r'Condition\s+(\d+)\s+"(\d+)"\s+"(.*)"', line)
        if condition:
            item = {"kind": "cond", "id": condition.group(1), "checksum": condition.group(2),
                    "signature": condition.group(3), "line": source_line, "source": source, "vectors": []}
            scope["objects"].append(item)
            current_object = item
    return scopes


def source_matches(native: dict, relative: str) -> bool:
    return bool(native.get("source")) and native["source"].endswith("/" + relative)


def source_line_candidate(row: dict[str, str]) -> int | None:
    # For branch rows source_position is the target decision position.
    return line_number(row)


def map_one(row: dict[str, str], review: dict[str, str], native: list[dict],
            source_root: Path, source_hashes: dict[str, str]) -> tuple[str, str, str]:
    rel = row["source_file"]
    source_path = source_root / rel
    if rel not in source_hashes or not source_path.is_file():
        return "SOURCE_NOT_IN_COMPILE_MANIFEST", "", ""
    observed_sha = sha256(source_path)
    if observed_sha != source_hashes[rel] or observed_sha != row["source_file_sha256"]:
        return "SOURCE_HASH_MISMATCH", "", ""
    if row.get("product_parameters", "") != "Centered-Cubic x2+x2; EF2 ORDER=2 STEP=5120 STATE_BITS=20; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite product; Generic FIFO":
        return "PRODUCT_PARAMETER_MISMATCH", "", ""
    scope = [s for s in native if s["instance"] == row["instance"]]
    if not scope:
        return "ELABORATED_INSTANCE_NOT_FOUND", "", ""
    metric = row["metric"]
    if metric == "toggle":
        match = re.fullmatch(r"(?:Signal|Port) Details:([^:]+):(0_to_1|1_to_0)", row["exact_urg_bin"])
        if not match:
            return "TOGGLE_BIN_PARSE_ERROR", "", ""
        name_bit, direction = match.groups()
        bit_match = re.fullmatch(r"([^\[]+)\[(\d+)\]", name_bit)
        if not bit_match:
            return "TOGGLE_BIT_PARSE_ERROR", "", ""
        name, bit_text = bit_match.groups()
        bit = int(bit_text)
        objects = [o for s in scope for o in s["objects"] if o["kind"] == "toggle" and o["name"] == name]
        if len(objects) != 1:
            return ("NATIVE_OBJECT_NOT_FOUND" if not objects else "NATIVE_MAPPING_AMBIGUOUS"), "", ""
        decl = objects[0]["decl"]
        width = re.search(r"\[(\d+):(\d+)\]$", decl)
        if width and not (min(map(int, width.groups())) <= bit <= max(map(int, width.groups()))):
            return "TOGGLE_BIT_OUT_OF_RANGE", "", ""
        transition = {"0_to_1": "0to1", "1_to_0": "1to0"}[direction]
        return "MAPPED_EXACT_NATIVE_BIN", f'Toggle {transition} {name} [{bit}] "{decl}"', objects[0]["decl"]

    line = source_line_candidate(row)
    if line is None:
        return "SOURCE_LINE_UNAVAILABLE", "", ""
    objects = [o for s in scope for o in s["objects"]
               if o["kind"] == metric and o["line"] == line and source_matches(o, rel)]

    if metric == "line":
        if len(objects) != 1:
            return ("NATIVE_OBJECT_NOT_FOUND" if not objects else "NATIVE_MAPPING_AMBIGUOUS"), "", ""
        obj = objects[0]
        return "MAPPED_EXACT_NATIVE_BIN", f'Block {obj["id"]} "{obj["checksum"]}" "{obj["signature"]}"', obj["signature"]

    if metric == "branch":
        wanted = re.fullmatch(r"\d+:([01])", row["exact_urg_bin"])
        if not wanted:
            return "NATIVE_MAPPING_COMPLEX_BRANCH_BIN", "", ""
        value = wanted.group(1)
        if len(objects) != 1:
            return ("NATIVE_OBJECT_NOT_FOUND" if not objects else "NATIVE_MAPPING_AMBIGUOUS"), "", ""
        obj = objects[0]
        vectors = []
        for vid, sig in obj["vectors"]:
            suffix = sig[len(obj["signature"]):].strip() if sig.startswith(obj["signature"]) else ""
            if suffix == value:
                vectors.append((vid, sig))
        if len(vectors) != 1:
            return ("NATIVE_VECTOR_NOT_FOUND" if not vectors else "NATIVE_VECTOR_AMBIGUOUS"), "", ""
        vid, signature = vectors[0]
        directive = f'Branch {obj["id"]} "{obj["checksum"]}" "{obj["signature"]}" ({vid}) "{signature}"'
        return "MAPPED_EXACT_NATIVE_BIN", directive, signature

    if metric == "cond":
        target = re.sub(r"[^01]", "", review.get("condition_operands", ""))
        if not target:
            return "CONDITION_VECTOR_UNAVAILABLE", "", ""
        vectors = []
        for obj in objects:
            for vid, signature in obj["vectors"]:
                if re.sub(r"[^01]", "", signature) == target:
                    vectors.append((obj, vid, signature))
        if len(vectors) != 1:
            return ("NATIVE_VECTOR_NOT_FOUND" if not vectors else "NATIVE_MAPPING_AMBIGUOUS"), "", ""
        obj, vid, signature = vectors[0]
        directive = f'Condition {obj["id"]} "{obj["checksum"]}" "{obj["signature"]}" ({vid} "{signature}")'
        return "MAPPED_EXACT_NATIVE_BIN", directive, signature
    return "UNSUPPORTED_METRIC", "", ""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-csv", type=Path, default=DEFAULT_CANDIDATES)
    parser.add_argument("--review-csv", type=Path, default=DEFAULT_REVIEW)
    parser.add_argument("--compile-manifest", type=Path, default=DEFAULT_COMPILE)
    parser.add_argument("--vdb-input-manifest", type=Path, default=DEFAULT_VDB_MANIFEST)
    parser.add_argument("--vdb-run-manifest", type=Path,
                        help="URG run manifest that binds the canonical input-manifest digest")
    parser.add_argument("--official-waivers", type=Path, default=DEFAULT_OFFICIAL_WAIVERS)
    parser.add_argument("--template-dir", type=Path, required=True,
                        help="Directory from an URG -dump full_exclusions run on the exact VDB set")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--source-root", type=Path, default=ROOT)
    args = parser.parse_args()

    candidates = read_rows(args.candidate_csv)
    review_rows = read_rows(args.review_csv)
    review_by_semantic = {r["semantic_bin_id"]: r for r in review_rows}
    if len(candidates) != 8970 or len({r["semantic_bin_id"] for r in candidates}) != len(candidates):
        raise SystemExit("Expected 8,970 unique semantic candidate bins")
    if len(review_by_semantic) != 13171:
        raise SystemExit("Review ledger must contain 13,171 unique semantic bins")
    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    source_hashes = compile_manifest["source_file_sha256"]
    vdb_manifest = json.loads(args.vdb_input_manifest.read_text(encoding="utf-8"))
    run_manifest_path = args.vdb_run_manifest or (args.vdb_input_manifest.parent / "run_manifest.json")
    if not run_manifest_path.is_file():
        raise SystemExit(f"VDB run manifest not found: {run_manifest_path}")
    vdb_run_manifest = json.loads(run_manifest_path.read_text(encoding="utf-8"))
    vdb_manifest_file_sha256 = sha256(args.vdb_input_manifest)
    canonical_vdb_manifest_sha256 = hashlib.sha256(json.dumps(
        vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if vdb_run_manifest.get("vdb_manifest_file_sha256") != vdb_manifest_file_sha256:
        raise SystemExit("VDB input manifest file fingerprint does not match its URG run manifest")
    if vdb_run_manifest.get("vdb_manifest_canonical_sha256") != canonical_vdb_manifest_sha256:
        raise SystemExit("VDB input manifest canonical fingerprint does not match its URG run manifest")
    official_waivers = read_rows(args.official_waivers)
    if len(official_waivers) != 371 or len({r["waiver_id"] for r in official_waivers}) != 371:
        raise SystemExit("Official Waiver inventory must retain its 371 unique IDs")
    official_by_native_key: dict[tuple[str, str, str, str, str], list[str]] = defaultdict(list)
    for waiver in official_waivers:
        key = (waiver["instance"], waiver["source_file"], waiver["source_line"],
               waiver["metric"], waiver["bin"])
        official_by_native_key[key].append(waiver["waiver_id"])
    template_sha = {}
    native_by_metric = {}
    for metric, name in METRIC_FILE.items():
        path = args.template_dir / f"fullexclude.{name}"
        template_sha[metric] = sha256(path)
        native_by_metric[metric] = parse_native_template(path)

    mapped: list[dict[str, str]] = []
    failures: list[dict[str, str]] = []
    directives: dict[str, dict[tuple[str, str, str], set[str]]] = defaultdict(lambda: defaultdict(set))
    for row in candidates:
        audit = review_by_semantic.get(row["semantic_bin_id"])
        if not audit:
            status, directive, native_signature = "REVIEW_ROW_NOT_FOUND", "", ""
        elif any(row[k] != audit.get(k, "") for k in ("record_id", "instance", "source_file", "metric", "exact_urg_bin", "source_file_sha256")):
            status, directive, native_signature = "CANDIDATE_REVIEW_BINDING_MISMATCH", "", ""
        else:
            status, directive, native_signature = map_one(row, audit, native_by_metric[row["metric"]], args.source_root, source_hashes)
        group = next((name for name, values in GROUPS.items() if row["evidence_group_id"] in values), "UNASSIGNED")
        source_line = line_number(row)
        official_key = (row["instance"], row["source_file"], str(source_line or ""),
                        row["metric"], row["source_bin_id"])
        official_matches = official_by_native_key.get(official_key, [])
        record = {**row, "analysis_group": group, "native_mapping_status": status,
                  "native_directive": directive, "native_signature": native_signature,
                  "official_waiver_ids": ";".join(official_matches),
                  "official_waiver_match_status": "UNIQUE_MATCH" if len(official_matches) == 1 else "NO_MATCH" if not official_matches else "AMBIGUOUS_MATCH",
                  "official_approval_status": "PENDING_INDEPENDENT_REVIEW",
                  "official_exclusion": "NO"}
        (mapped if status == "MAPPED_EXACT_NATIVE_BIN" else failures).append(record)
        if directive:
            scope = next(s for s in native_by_metric[row["metric"]] if s["instance"] == row["instance"])
            directives[group][(row["metric"], scope["checksum"], row["instance"])].add(directive)

    target_counts = Counter((r["analysis_group"], r["metric"], r["instance"], r["native_directive"])
                            for r in mapped)
    for record in mapped:
        key = (record["analysis_group"], record["metric"], record["instance"], record["native_directive"])
        if target_counts[key] > 1:
            record["native_mapping_status"] = "MAPPING_COLLISION_DUPLICATE_NATIVE_TARGET"
            record["native_directive"] = ""
            record["native_signature"] = ""
    failures.extend(r for r in mapped if r["native_mapping_status"] != "MAPPED_EXACT_NATIVE_BIN")
    mapped = [r for r in mapped if r["native_mapping_status"] == "MAPPED_EXACT_NATIVE_BIN"]
    directives = defaultdict(lambda: defaultdict(set))
    for record in mapped:
        scope = next(s for s in native_by_metric[record["metric"]] if s["instance"] == record["instance"])
        directives[record["analysis_group"]][(record["metric"], scope["checksum"], record["instance"])].add(record["native_directive"])

    args.output_dir.mkdir(parents=True, exist_ok=True)
    all_records = sorted(mapped + failures, key=lambda r: r["record_id"])
    ledger_path = args.output_dir / "round17_candidate_native_mapping.csv.gz"
    fields = list(all_records[0])
    with gzip.open(ledger_path, "wt", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader(); writer.writerows(all_records)

    group_counts = {}
    for group, group_names in GROUPS.items():
        group_rows = [r for r in candidates if r["evidence_group_id"] in group_names]
        group_mapped = [r for r in mapped if r["analysis_group"] == group]
        group_file = args.output_dir / f"{group.lower()}_analysis_only.el"
        out_lines = ["// ANALYSIS_ONLY: not an official approved exclusion."]
        for metric, checksum, instance in sorted(directives[group]):
            scope = next(s for s in native_by_metric[metric] if s["instance"] == instance and s["checksum"] == checksum)
            out_lines.extend([scope["checksum"], f'// {scope["module"]}', f"INSTANCE: {instance}"])
            out_lines.extend(sorted(directives[group][(metric, checksum, instance)]))
            out_lines.append("")
        while out_lines and not out_lines[-1]:
            out_lines.pop()
        group_file.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
        group_counts[group] = {"candidate_count": len(group_rows), "native_mapped_count": len(group_mapped),
                              "unmapped_count": len(group_rows)-len(group_mapped),
                              "el_sha256": sha256(group_file)}

    summary = {
        "schema": "thermo5_tx_round17_native_analysis_exclusion_mapping_v1",
        "analysis_only": True,
        "official_approval": "PENDING_INDEPENDENT_REVIEW",
        "candidate_count": len(candidates),
        "mapped_exact_native_bin_count": len(mapped),
        "unmapped_count": len(failures),
        "mapping_status_counts": dict(Counter(r["native_mapping_status"] for r in all_records)),
        "group_counts": group_counts,
        "candidate_csv_sha256": sha256(args.candidate_csv),
        "review_csv_sha256": sha256(args.review_csv),
        "compile_manifest_sha256": sha256(args.compile_manifest),
        "compile_fingerprint_sha256": compile_manifest.get("compile_fingerprint_sha256", ""),
        "vdb_manifest_path": str(args.vdb_input_manifest.relative_to(ROOT)) if args.vdb_input_manifest.is_relative_to(ROOT) else str(args.vdb_input_manifest),
        "vdb_manifest_file_sha256": vdb_manifest_file_sha256,
        "vdb_manifest_canonical_sha256": canonical_vdb_manifest_sha256,
        "vdb_run_manifest_path": str(run_manifest_path.relative_to(ROOT)) if run_manifest_path.is_relative_to(ROOT) else str(run_manifest_path),
        "vdb_run_manifest_sha256": sha256(run_manifest_path),
        "vdb_design_count": 1,
        "vdb_test_count": len(vdb_manifest.get("tests", [])),
        "official_waiver_csv_sha256": sha256(args.official_waivers),
        "official_waiver_id_count": len(official_waivers),
        "native_template_sha256": template_sha,
        "source_sha256_checked": len(source_hashes),
        "waiver_approval_count": 0,
        "active_official_exclusion_count": 0,
        "mapping_ledger_sha256": sha256(ledger_path),
    }
    (args.output_dir / "round17_candidate_native_mapping_manifest.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
