#!/usr/bin/env python3
"""Build the per-bin Thermo5 static reachability review from frozen R16 data.

This script classifies only source/configuration paths supported by explicit
current RTL structure. Everything else remains UNKNOWN. It never approves or
applies an URG exclusion.
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
DEFAULT_LEDGER = ROOT / "docs/verification/data/thermo5-r16/thermo5_tx_r16_exact_remaining_bins.csv.gz"
DEFAULT_COMPILE = ROOT / "docs/verification/data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json"
DEFAULT_PAIR1 = ROOT / "docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review.csv.gz"
DEFAULT_COVERAGE = ROOT / "docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_final_closure_evidence_manifest.json"
DEFAULT_OUT = ROOT / "docs/verification/data/thermo5-r17/static_reachability_review"

REVIEW_FIELDS = [
    "record_id", "source_bin_id", "semantic_bin_id", "bin_id",
    "legacy_bin_id_collision", "instance", "source_file", "metric",
    "exact_urg_bin", "source_location", "source_position", "source_code_text",
    "branch_decision_path", "branch_predicate_path", "condition_operands",
    "product_parameters", "source_file_sha256", "product_source_sha",
    "root_cause_class", "review_class", "review_confidence",
    "classification_rationale", "trace_reference", "dataflow_trace_status",
    "evidence_group_id", "reason_code", "next_action_code",
    "exclusion_candidate", "reviewer_status",
]

CANDIDATE_FIELDS = [
    "record_id", "source_bin_id", "semantic_bin_id", "bin_id",
    "legacy_bin_id_collision", "review_class", "root_cause_class",
    "instance", "source_file", "metric", "exact_urg_bin",
    "source_location", "source_position", "product_parameters",
    "source_file_sha256", "product_source_sha", "evidence_group_id",
    "classification_rationale", "trace_reference", "dataflow_trace_status",
    "candidate_status", "reviewer_status", "approval_reference",
    "official_exclusion",
]


def read_csv_gz(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_path(row: dict[str, str]) -> str:
    return row["source_files"].split(",", 1)[0].strip()


def source_file_hash(row: dict[str, str]) -> str:
    value = row.get("source_file_sha256", "")
    prefix = source_path(row) + "="
    return value[len(prefix):] if value.startswith(prefix) else value


def toggle_signal_and_direction(bin_text: str) -> tuple[str, str]:
    match = re.search(r"(?:Signal|Port) Details:([^:]+):([01]_to_[01])$", bin_text)
    if not match:
        return "", ""
    return match.group(1), match.group(2)


def line_number(row: dict[str, str]) -> int | None:
    # For branch bins source_location can name the enclosing procedural block
    # while source_position names the actual decision line. Prefer the latter.
    match = re.search(r":(\d+)$", row.get("source_position", ""))
    if not match:
        match = re.match(r"line:(\d+)(?:$|:)", row.get("source_location", ""))
    return int(match.group(1)) if match else None


def classify(row: dict[str, str]) -> tuple[str, str, str, str, str]:
    """Return class, confidence, evidence, reason, next action."""
    path = source_path(row)
    metric = row["metric"].lower()
    line = line_number(row)
    sig, direction = toggle_signal_and_direction(row.get("bin", ""))
    sem = row["semantic_bin_id"]

    if path == "rtl/dpd/dpd_memory_poly.v":
        if metric == "toggle" and re.fullmatch(r"sum_[iq]_pair1_(?:comb|s8)\[\d+\]", sig):
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dpd_memory_poly.v:180-195,198-230; dpd_vector16_memory_poly.sv:96-112",
                "MAX_TAPS=1 gives one loop iteration (comb_tap=0); the pair-1 else arm is not selected. Pair-1 combinational sums initialize to zero; their registered sums reset to zero, update only from those zeros when pipe_ce is true, and otherwise hold. Current hierarchy uses USE_EXTERNAL_TAPS=1.",
                "Independent reviewer must verify exact URG native-bin mapping and proof scope; no exclusion is approved.",
            )
        if metric == "line" and line in {191, 192, 210, 211, 238, 239, 240, 242, 243, 332, 333}:
            if line in {191, 192}:
                reason = "MAX_TAPS=1 makes the pair-1 accumulation loop arm unreachable; pair-1 remains initialized to zero."
            elif line in {210, 211}:
                reason = "The history reset loop bound is tap < MAX_TAPS-1, which is zero iterations at MAX_TAPS=1."
            elif line in {238, 239, 240}:
                reason = "The product wrapper instantiates dpd_memory_poly with USE_EXTERNAL_TAPS=1, so the internal-input tap-0 fallback arm is not selected."
            elif line in {242, 243}:
                reason = "The internal-history tap arm requires tap>0; the current MAX_TAPS=1 loop only elaborates tap=0."
            else:
                reason = "The history shift loop starts at tap=1 and has upper bound MAX_TAPS-1=0 in the current product."
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dpd_memory_poly.v:166-195,197-245,325-335; dpd_vector16_memory_poly.sv:96-112",
                reason,
                "Keep reusable RTL; independent reviewer may assess an exact current-product exclusion.",
            )

    if path == "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv":
        if metric in {"line", "branch", "cond"}:
            if metric == "line" and line == 97:
                reason = "The error statement is guarded by invalid W/CHANNELS parameters; the four product instances use W=16 and CHANNELS=32."
            elif metric == "branch" and line == 96:
                reason = "W=16 and CHANNELS=32 satisfy W>=2, CHANNELS>=2, and even CHANNELS; the invalid-parameter guard is false."
            else:
                reason = "The pair-lookahead helper is called only in the PAIR_LOOKAHEAD arm; product instances inherit the explicit default PAIR_LOOKAHEAD=0 and the parent does not override it."
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "tid32_cartesian_ef2_fs4_gt_tx.sv:15-20,95-98,117-193,231-258; tid32_thermo5_fs4_multipa_tx.sv:77-85",
                reason,
                "Keep the experimental helper and parameter guard for supported candidate configurations; review exact native URG mapping before any exclusion.",
            )

    if path == "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv":
        if metric == "branch" and line == 348:
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "thermo5_dpd_axi_lite_cfg.sv:8-9,347-350; product u_cfg parameter MAX_TAPS=1",
                "The initial parameter guard is true only outside MAX_TAPS in [1,4]. The elaborated product sets MAX_TAPS=DPD_MAX_TAPS=1, so the error arm cannot execute. This is a current-product configuration result; the guard remains valid reusable-IP protection.",
                "Keep the guard; independent review must confirm the exact native URG branch mapping before any exclusion.",
            )
        if metric == "line" and line == 349:
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "thermo5_dpd_axi_lite_cfg.sv:8-9,347-350; product u_cfg parameter MAX_TAPS=1",
                "This $error line is inside the MAX_TAPS outside-[1,4] initial guard. The product instance uses MAX_TAPS=1, so the line is not executed; preserve it for unsupported configurations.",
                "Keep the guard; reviewer must confirm exact native URG line mapping.",
            )

    if path == "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv":
        if metric == "branch" and line == 274:
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "tid32_thermo5_axi_lite_axis_frontend_tx.sv:42-49,273-276; product DPD_MAX_TAPS=1",
                "The parameter guard is true only when DPD_MAX_TAPS is outside [1,4]. The product configuration elaborates DPD_MAX_TAPS=1, so the error arm is false. Keep the check for other configurations.",
                "Keep the guard; independent review must confirm exact native URG branch mapping.",
            )
        if metric == "line" and line == 275:
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "tid32_thermo5_axi_lite_axis_frontend_tx.sv:42-49,273-276; product DPD_MAX_TAPS=1",
                "This $error line is inside the parameter guard; the elaborated product value is 1 and does not enter it.",
                "Keep the guard; reviewer must confirm exact native URG line mapping.",
            )

    if path == "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv":
        instance = row.get("instance", "")
        is_stage1 = "g_interp1_centered.u_interp_1" in instance
        is_stage2 = "g_interp2_centered.u_interp_2" in instance
        if metric == "branch" and line in {294, 295}:
            param = "LANES=8" if is_stage1 else "LANES=16" if is_stage2 else "product LANES"
            if line == 295:
                param = "COEFF_FRAC=14"
            check = "LANES < 2" if line == 294 else "COEFF_FRAC != 14"
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:23-28,291-296; tid32_thermo5_frontend_tx.sv:98-104,174-180",
                f"The uncovered initial error arm requires {check}. The product instance has {param}, so the check is false; retain the guard for unsupported configurations.",
                "Keep the parameter guard; reviewer must confirm exact native URG branch mapping.",
            )
        if metric == "line" and line in {294, 295}:
            param = "LANES=8" if is_stage1 else "LANES=16" if is_stage2 else "product LANES"
            if line == 295:
                param = "COEFF_FRAC=14"
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:23-28,291-296; tid32_thermo5_frontend_tx.sv:98-104,174-180",
                f"This $error line is guarded by the initial parameter check; the product instance uses {param}, so the error line is not executed.",
                "Keep the parameter guard; reviewer must confirm exact native URG line mapping.",
            )
        if metric == "branch" and line == 210 and (is_stage1 or is_stage2):
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:27-28,201-215; tid32_thermo5_frontend_tx.sv:29,87-90,98-104,174-180",
                "The uncovered false arm requires HOLD_STATE_ON_DISABLE=1. Both product interpolator instances inherit the frontend default 0; when disabled, the reset-on-disable arm is selected. Keep the alternate hold behavior for configurations that enable it.",
                "Keep the reusable option; reviewer must confirm exact instance/branch mapping.",
            )
        if metric == "branch" and is_stage2 and line in {129, 217, 223}:
            detail = {
                129: "The uncovered true arm requires tail_output=1, but tail_output is APPEND_TAIL_VECTOR && tail_pending_q and stage 2 has APPEND_TAIL_VECTOR=0.",
                217: "The uncovered true arm requires tail_fire=1, but tail_fire depends on tail_output and stage 2 has APPEND_TAIL_VECTOR=0.",
                223: "The uncovered true arm requires APPEND_TAIL_VECTOR=1, but stage 2 is instantiated with APPEND_TAIL_VECTOR=0.",
            }[line]
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:65,73-75,129-134,201-228; tid32_thermo5_frontend_tx.sv:174-180",
                detail + " Stage 1 still implements the synthetic-tail behavior; this does not classify the shared RTL as dead code.",
                "Keep the shared tail logic; reviewer must confirm the exact stage-2 native URG bin.",
            )
        if metric == "line" and is_stage2 and line in {132, 133}:
            return (
                "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:65,124-134; tid32_thermo5_frontend_tx.sv:174-180",
                "This output assignment is guarded by tail_output; stage 2 has APPEND_TAIL_VECTOR=0, making tail_output constant zero. Stage 1 retains the tail-output path.",
                "Keep the shared tail logic; reviewer must confirm exact stage-2 native URG line mapping.",
            )
        if metric == "branch" and is_stage1 and line == 229:
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_interp_x2_centered_cubic_vector.sv:182-188,229-232,255-263; tid32_thermo5_frontend_tx.sv:98-108",
                "The product stage-1 input ties in_tail to 1'b0. q0_tail resets to zero and every queue load copies that constant into q0_tail, so pop_head && q0_tail is false in this product topology. Stage 2 receives stage-1 tail metadata and is not covered by this tie-off claim.",
                "Retain the defensive tail-drop behavior; independent review must validate exact stage-1 bin mapping.",
            )

    if path == "rtl/gt/gt_tx_user_bridge.sv" and metric in {"line", "branch"}:
        return (
            "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
            "gt_tx_user_bridge.sv:6-8,20-22; gt_tx_raw64_boundary.sv:10-25; tid32_cartesian_ef2_fs4_gt_tx.sv:351",
            "The product boundary sets PARALLEL_W and GT_USER_W from the same DATA_W=2*CHANNELS=64 expression, so the mismatch guard is false. The guard remains required for other configurations.",
            "Keep the reusable guard; independent reviewer must validate exact native URG mappings.",
        )

    if path == "rtl/frontend/dsm_frame_gain_vector.sv" and metric == "branch" and line == 97:
        return (
            "CONFIG_UNREACHABLE", "HIGH_STRUCTURAL",
            "tid32_thermo5_axi_lite_axis_frontend_tx.sv:256-267; tid32_thermo5_frontend_tx.sv:15-31,84-90; dsm_frame_gain_vector.sv:17,97",
            "The AXI-Lite product parent does not override HOLD_STATE_ON_DISABLE; the frontend default is zero, making !HOLD_STATE_ON_DISABLE constant true whenever this branch is evaluated. The uncovered false arm is not a dead-code claim across configurations.",
            "Keep the alternate state-hold behavior; independent reviewer must validate the exact native URG mapping.",
        )

    if path == "rtl/axis/dsm_axis14_to_core8_cdc.sv":
        if metric == "toggle" and sig == "rem_count_q[0]":
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:121-125,154-209,235-240",
                "Reset sets rem_count_q=0; every explicit assignment in the residual case writes only 0,2,4,6,8,10,12; stalls hold state. No external writer exists, so bit 0 stays zero for all input and backpressure sequences.",
                "Independent reviewer must validate exact native URG mapping; do not infer approval from the invariant alone.",
            )
        match = re.fullmatch(r"rem_[iq]_q\[(\d+)\]", sig)
        if metric == "toggle" and match and 192 <= int(match.group(1)) <= 223:
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:121-136,154-209",
                "With W=16, SRC_LANES=14, CORE_LANES=8, source shifts are 128/96/64/32 bits for residual counts 0/2/4/6, leaving at most 12 residual samples (bits 0..191). Counts 8/10/12 drain by clear or right shift; reset clears the vector and stalls hold it. Bits 223:192 remain zero.",
                "Independent reviewer must validate exact native URG mapping; no CDC module-wide exclusion is proposed.",
            )
        if metric == "branch" and line == 215 and "if (rem_count_q + SRC_LANES <= CORE_LANES) begin=1" in row.get("branch_predicate_path", ""):
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:14-17,154-223",
                "The uncovered true arm is impossible for nonnegative rem_count_q and SRC_LANES=14, CORE_LANES=8; SystemVerilog expression sizing is at least the 32-bit int parameter width, so this comparison does not wrap at four bits.",
                "Independent reviewer must verify URG branch polarity and exact native-bin mapping.",
            )
        if metric == "branch" and "case (rem_count_q)=default" in row.get("branch_predicate_path", ""):
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:121-125,154-209,235-240",
                "The default arm requires an odd or out-of-set residual value. Reset and every explicit residual assignment preserve the enumerated even set {0,2,4,6,8,10,12}; input, frame-end, reset recovery, and stalls do not write an alternate residual value.",
                "Retain defensive RTL; independent reviewer may assess only the exact default-case bin.",
            )
        if metric == "line" and line in {216, 217, 218}:
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:154-223",
                "These assignments are inside the true arm of rem_count_q + 14 <= 8, which is false for all legal residual values and cannot wrap because SRC_LANES is a 32-bit parameter.",
                "Independent reviewer must validate exact native URG line mapping.",
            )
        if metric == "line" and line in {238, 239}:
            return (
                "STATIC_UNREACHABLE", "HIGH_STRUCTURAL",
                "dsm_axis14_to_core8_cdc.sv:121-125,154-209,235-240",
                "These statements are in the case default used only for illegal residual values; the reset/assignment invariant keeps rem_count_q in the explicit even set.",
                "Retain the defensive response; independent reviewer may assess only these exact line bins.",
            )
        if metric == "branch" and line == 146 and "if (end_remaining_q <= CORE_LANES) begin=0" in row.get("branch_predicate_path", ""):
            return (
                "DEFENSIVE_NEGATIVE_ONLY", "HIGH_CONTRACT_DERIVED",
                "tid32_thermo5_axi_lite_axis_frontend_tx.sv:81-84,135-147,173-177; dsm_axis14_to_core8_cdc.sv:214-223",
                "The false arm requires end_remaining_q>8. A legal packet terminates on a 32-beat quantum; with 14:8 packing the final accepted beat has residual count 2 and creates end_remaining=8, so the false arm is only available after a misaligned/early TLAST that the parent sticky-diagnoses as a source-frame error.",
                "Keep the defensive path and test only in the separate expected-negative suite; do not waive as a legal-path exclusion.",
            )
        if metric == "line" and line == 151:
            return (
                "DEFENSIVE_NEGATIVE_ONLY", "HIGH_CONTRACT_DERIVED",
                "tid32_thermo5_axi_lite_axis_frontend_tx.sv:81-84,135-147,173-177; dsm_axis14_to_core8_cdc.sv:145-152,214-223",
                "This subtract-by-eight arm is selected only when end_remaining_q>8; the legal 32-beat packet contract produces end_remaining=8 at TLAST. Misaligned early TLAST can exercise the defensive drain path and is separately diagnosed.",
                "Retain RTL; use a separate negative test if an exact assertion/checker obligation requires this path.",
            )

    return (
        "UNKNOWN", "UNREVIEWED",
        "R16 exact uncovered ledger; current source hash verified against the Round 17 compile-parent manifest",
        "No complete per-bin driver/reset/consumer or legal-reachability proof was established in this static pass. A simulation miss is not evidence of unreachability.",
        "Keep OPEN. Group by exact instance/signal/state, derive a legal witness or an independently reviewable invariant, then validate against the matching VDB.",
    )


def evidence_group(row: dict[str, str], review_class: str, evidence: str) -> str:
    if review_class == "UNKNOWN":
        return "UNKNOWN_REMAINDER"
    path = source_path(row)
    metric = row["metric"].lower()
    line = line_number(row)
    sig, _ = toggle_signal_and_direction(row.get("bin", ""))
    if path == "rtl/dpd/dpd_memory_poly.v":
        return "DPD_PAIR1_ZERO" if "pair1" in sig else "DPD_TAP_HISTORY_MAX_TAPS1"
    if path == "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv":
        return "EF2_INVALID_PARAMETER_GUARD" if line in {96, 97} else "EF2_PAIR_LOOKAHEAD_DISABLED"
    if path == "rtl/gt/gt_tx_user_bridge.sv":
        return "GT_EQUAL_WIDTH_BOUNDARY"
    if path == "rtl/frontend/dsm_frame_gain_vector.sv":
        return "FRAME_GAIN_HOLD_STATE_DEFAULT"
    if path == "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv":
        return "DPD_CONFIG_MAX_TAPS_GUARD"
    if path == "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv":
        return "PRODUCT_DPD_MAX_TAPS_GUARD"
    if path == "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv":
        if line in {294, 295}:
            return "INTERPOLATOR_PARAMETER_GUARD"
        if line == 210:
            return "INTERPOLATOR_HOLD_STATE_PARAMETER"
        if line in {129, 132, 133, 217, 223}:
            return "INTERPOLATOR_STAGE2_TAIL_DISABLED"
        if line == 229:
            return "INTERPOLATOR_STAGE1_TAIL_TIED_LOW"
    if path == "rtl/axis/dsm_axis14_to_core8_cdc.sv":
        if review_class == "DEFENSIVE_NEGATIVE_ONLY":
            return "CDC_EARLY_TLAST_NEGATIVE_ONLY"
        if line == 215 or line in {216, 217, 218}:
            return "CDC_14_TO_8_END_ARITHMETIC"
        return "CDC_RESIDUAL_INVARIANT"
    return "UNKNOWN_REMAINDER"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--compile-manifest", type=Path, default=DEFAULT_COMPILE)
    parser.add_argument("--pair1-ledger", type=Path, default=DEFAULT_PAIR1)
    parser.add_argument("--coverage-evidence", type=Path, default=DEFAULT_COVERAGE)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    compile_manifest = json.loads(args.compile_manifest.read_text(encoding="utf-8"))
    coverage_evidence = json.loads(args.coverage_evidence.read_text(encoding="utf-8"))
    mismatches = []
    for relpath, expected in compile_manifest["source_file_sha256"].items():
        source = ROOT / relpath
        if not source.exists() or sha256(source) != expected:
            mismatches.append(relpath)
    if mismatches:
        raise SystemExit("Compile-parent source hash mismatch: " + ", ".join(mismatches[:8]))

    rows = read_csv_gz(args.ledger)
    if len(rows) != 13171:
        raise SystemExit("Expected 13,171 exact bins; found %d" % len(rows))
    if len({row["semantic_bin_id"] for row in rows}) != len(rows):
        raise SystemExit("semantic_bin_id is not unique")
    ledger_source_mismatches = []
    for row in rows:
        path = source_path(row)
        if path not in compile_manifest["source_file_sha256"] or source_file_hash(row) != compile_manifest["source_file_sha256"].get(path):
            ledger_source_mismatches.append(row.get("record_id", row.get("semantic_bin_id", "")))
    if ledger_source_mismatches:
        raise SystemExit("Exact-bin ledger source hash mismatch: " + ", ".join(ledger_source_mismatches[:8]))

    pair1_rows = read_csv_gz(args.pair1_ledger)
    pair1_ids = {row["semantic_bin_id"] for row in pair1_rows}
    if len(pair1_rows) != 8192 or len(pair1_ids) != 8192:
        raise SystemExit("Expected 8,192 unique current-Raw Pair-1 rows")

    duplicate_bins = Counter(row["bin_id"] for row in rows)
    classified = []
    for row in rows:
        review_class, confidence, evidence, reason, action = classify(row)
        result = {
            "record_id": row.get("record_id", ""),
            "source_bin_id": row.get("source_bin_id", ""),
            "semantic_bin_id": row.get("semantic_bin_id", ""),
            "bin_id": row.get("bin_id", ""),
            "legacy_bin_id_collision": "DUPLICATE_SHORT_BIN_ID" if duplicate_bins[row["bin_id"]] > 1 else "",
            "instance": row.get("instance", ""),
            "source_file": source_path(row),
            "metric": row.get("metric", ""),
            "exact_urg_bin": row.get("bin", ""),
            "source_location": row.get("source_location", ""),
            "source_position": row.get("source_position", ""),
            "source_code_text": row.get("source_code_text", ""),
            "branch_decision_path": row.get("branch_decision_path", ""),
            "branch_predicate_path": row.get("branch_predicate_path", ""),
            "condition_operands": row.get("condition_operands", ""),
            "product_parameters": row.get("product_parameters", ""),
            "source_file_sha256": source_file_hash(row),
            "product_source_sha": row.get("product_source_sha", ""),
            "root_cause_class": row.get("root_cause_class", ""),
            "classification_rationale": reason,
            "trace_reference": evidence,
            "dataflow_trace_status": (
                "INCOMPLETE_OPEN" if review_class == "UNKNOWN"
                else "CONTRACT_DERIVED" if review_class == "DEFENSIVE_NEGATIVE_ONLY"
                else "GROUPED_SOURCE_PARAMETER_RESET_USE_REVIEW"
            ),
        }
        result.update({
            "review_class": review_class,
            "review_confidence": confidence,
            "evidence_group_id": evidence_group(row, review_class, evidence),
            "reason_code": evidence_group(row, review_class, evidence),
            "next_action_code": "INDEPENDENT_REVIEW_EXACT_MAPPING" if review_class in {"STATIC_UNREACHABLE", "CONFIG_UNREACHABLE"} else "KEEP_OPEN_TRACE_OR_WITNESS",
            "exclusion_candidate": "PENDING_TECHNICAL_AND_INDEPENDENT_REVIEW" if review_class in {"STATIC_UNREACHABLE", "CONFIG_UNREACHABLE"} else "NO",
            "reviewer_status": "NO_INDEPENDENT_APPROVAL",
        })
        if review_class in {"STATIC_UNREACHABLE", "CONFIG_UNREACHABLE"} and row["semantic_bin_id"] not in pair1_ids and "sum_[iq]_pair1_" in row.get("bin", ""):
            raise SystemExit("Pair-1 exact bin is missing from the current-Raw candidate mapping")
        classified.append(result)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    review_path = args.output_dir / "coverage_static_reachability_review.csv"
    candidate_path = args.output_dir / "thermo5_tx_unreachable_exclusion_candidates.csv"
    open_path = args.output_dir / "thermo5_tx_remaining_open_bins.csv"
    with review_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=REVIEW_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(classified)
    candidates = [row for row in classified if row["review_class"] in {"STATIC_UNREACHABLE", "CONFIG_UNREACHABLE"}]
    with candidate_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=CANDIDATE_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows({
            "record_id": row["record_id"],
            "source_bin_id": row["source_bin_id"],
            "semantic_bin_id": row["semantic_bin_id"],
            "bin_id": row["bin_id"],
            "legacy_bin_id_collision": row["legacy_bin_id_collision"],
            "review_class": row["review_class"],
            "root_cause_class": row["root_cause_class"],
            "instance": row["instance"],
            "source_file": row["source_file"],
            "metric": row["metric"],
            "exact_urg_bin": row["exact_urg_bin"],
            "source_location": row["source_location"],
            "source_position": row["source_position"],
            "product_parameters": row["product_parameters"],
            "source_file_sha256": row["source_file_sha256"],
            "product_source_sha": row["product_source_sha"],
            "evidence_group_id": row["evidence_group_id"],
            "classification_rationale": row["classification_rationale"],
            "trace_reference": row["trace_reference"],
            "dataflow_trace_status": row["dataflow_trace_status"],
            "candidate_status": "PENDING_INDEPENDENT_REVIEW",
            "reviewer_status": "NONE",
            "approval_reference": "",
            "official_exclusion": "NO",
        } for row in candidates)

    remaining_open = [row for row in classified if row["review_class"] in {"UNKNOWN", "DEFENSIVE_NEGATIVE_ONLY"}]
    with open_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=REVIEW_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(remaining_open)

    class_counts = Counter(row["review_class"] for row in classified)
    pair1_candidate_ids = {
        row["semantic_bin_id"] for row in classified
        if row["evidence_group_id"] == "DPD_PAIR1_ZERO"
    }
    if pair1_candidate_ids != pair1_ids:
        raise SystemExit(
            "Pair-1 mapping mismatch: current exact candidate rows=%d, Pair-1 review rows=%d"
            % (len(pair1_candidate_ids), len(pair1_ids))
        )
    metric_class_counts = defaultdict(Counter)
    for row in classified:
        metric_class_counts[row["metric"].lower()][row["review_class"]] += 1
    summary = {
        "schema": "thermo5_static_reachability_review_v1",
        "generator_sha256": sha256(Path(__file__).resolve()),
        "source_ledger": str(args.ledger.relative_to(ROOT)),
        "source_ledger_sha256": sha256(args.ledger),
        "compile_manifest": str(args.compile_manifest.relative_to(ROOT)),
        "compile_manifest_sha256": sha256(args.compile_manifest),
        "coverage_evidence": str(args.coverage_evidence.relative_to(ROOT)),
        "coverage_evidence_sha256": sha256(args.coverage_evidence),
        "compiled_product_source_sha": compile_manifest["product_source_sha"],
        "current_product_rtl_aggregate_sha256": compile_manifest["product_rtl_aggregate_sha256"],
        "compile_fingerprint_sha256": compile_manifest["compile_fingerprint_sha256"],
        "compile_source_hashes_checked": len(compile_manifest["source_file_sha256"]),
        "compile_source_hash_mismatches": 0,
        "ledger_to_compile_source_hash_mismatches": 0,
        "source_bin_rows": len(rows),
        "unique_semantic_bin_ids": len({row["semantic_bin_id"] for row in rows}),
        "legacy_short_bin_id_unique_count": len({row["bin_id"] for row in rows}),
        "legacy_short_bin_id_collision_rows": sum(1 for row in classified if row["legacy_bin_id_collision"]),
        "review_class_counts": dict(class_counts),
        "metric_review_class_counts": {metric: dict(counts) for metric, counts in metric_class_counts.items()},
        "configuration_unreachable_candidate_rows": class_counts["CONFIG_UNREACHABLE"],
        "static_unreachable_candidate_rows": class_counts["STATIC_UNREACHABLE"],
        "review_group_counts": dict(Counter(row["evidence_group_id"] for row in classified)),
        "pair1_review_ledger_exact_id_match_count": len(pair1_candidate_ids),
        "review_csv_sha256": sha256(review_path),
        "candidate_csv_sha256": sha256(candidate_path),
        "remaining_open_csv_sha256": sha256(open_path),
        "vdb_manifest_sha256": coverage_evidence["coverage"].get("vdb_manifest_sha256")
            or coverage_evidence["coverage"].get("vdb_manifest_canonical_sha256", ""),
        "urg_report_manifest_sha256": coverage_evidence["coverage"].get("urg_report_manifest_sha256")
            or coverage_evidence["coverage"].get("report_manifest_sha256", ""),
        "test_vdb_count": coverage_evidence["coverage"]["test_vdb_count"],
        "design_vdb_count": coverage_evidence["coverage"]["design_vdb_count"],
        "approved_waivers": 0,
        "official_exclusions_applied": 0,
        "what_if_urg_status": "NOT_RUN_EXACT_VDB_SET_UNAVAILABLE",
        "exact_manifest_bound_vdb_files_found": False,
        "remaining_open_rows_without_candidate_exclusion": len(remaining_open),
    }
    summary_path = args.output_dir / "thermo5_tx_static_reachability_review_manifest.json"
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "review_csv": str(review_path.relative_to(ROOT)),
        "candidate_csv": str(candidate_path.relative_to(ROOT)),
        "rows": len(classified),
        "classes": dict(class_counts),
        "metric_classes": {metric: dict(counts) for metric, counts in metric_class_counts.items()},
        "review_sha256": summary["review_csv_sha256"],
        "candidate_sha256": summary["candidate_csv_sha256"],
        "remaining_open_rows": len(remaining_open),
        "remaining_open_sha256": summary["remaining_open_csv_sha256"],
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
