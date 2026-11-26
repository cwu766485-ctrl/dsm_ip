#!/usr/bin/env python3
"""Bind the original 106 V1.4 waiver candidates to native reports for review."""
from argparse import ArgumentParser
from collections import Counter
import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess

from run_dsm_v14_frame_replacement import ROOT


BASE = "cc97188832d5a456bfc12e4a19bdb60b72d4e4a8"
CONTEXT = (
    "dv/uvm/sim/thermo5_sku_filelist.f",
    "dv/uvm/sim/dsm_v13_product_dut_coverage.hier",
    "dv/uvm/tb/thermo5_sku_uvm_tb.sv",
    "dv/uvm/tb/dsm_v13_multi_sku_uvm_tb.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv",
    "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv",
)
COMMON = ("configuration", "instance", "source", "line")


def csv_rows(path):
    with path.open(newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def fingerprint(path):
    content = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)
    return digest(content)


def extract(report):
    properties = []
    for status, name in re.findall(r"(?m)^\s*\[\s*\d+\]\s+(.*?)\s+-\s+(\S+)\s*$",
                                    report.read_text()):
        properties.append({"name": name, "result": status})
    if not properties:
        raise ValueError(f"Missing properties in {report}")
    return properties


def formal_groups(r6, v14):
    specs = {
        "cubic_stage1": (
            r6 / "r6_cubic_formal/properties.txt", "thermo5_round6_cubic",
            "8 lanes, APPEND_TAIL_VECTOR=1, in_tail tied zero. Payload tied zero, enable, ready and other input flags free. Post-reset two-state sampling.",
            ("g_stage[1].c_nonempty", "g_stage[1].g_append.c_tail_emit"),
        ),
        "dpd_wrapper": (
            r6 / "r6_vector_ready/properties.txt", "thermo5_dpd_vector_ready",
            "One-tap 16-lane DPD wrapper with real lane ready/valid. The property is scoped after reset; invalid-cycle payload hold is outside the claimed proof.",
            ("c_input_accept", "c_output_stall", "c_output_transfer", "c_stall_release"),
        ),
        "frontend_control": (
            v14 / "v14_frontend_control_01/properties.txt", "thermo5_v14_frontend_control",
            "Generic FIFO and 14:8 gearbox; unconstrained ingress flags and core controls. Independent 18-bit and 2-bit metadata elastic FIFOs, arbitrary handshakes and flags, payload tied zero. Known-value sampling after reset.",
            ("c_gain_start_end", "c_interp_has_start", "c_read_empty", "c_read_valid"),
        ),
        "cdc_immediate_end": (
            v14 / "v14_cdc_end_branch_01/properties.txt", "thermo5_cdc_end_branch",
            "14:8 Generic FIFO, legal continuous 32-beat packets, core permanently enabled/ready. The mapped arm also has a static inequality independent of those traffic constraints.",
            ("c_completed_legal_frame", "c_product_end_branch_context"),
        ),
    }
    files = {
        "cubic_stage1": ("rtl/interp/dsm_interp_x2_centered_cubic_vector.sv",),
        "dpd_wrapper": ("rtl/dpd/dpd_memory_poly.v", "rtl/dpd/dpd_vector16_memory_poly.sv", "rtl/dpd/dpd_poly.v"),
        "frontend_control": ("rtl/axis/dsm_reset_sync.sv", "rtl/axis/dsm_async_fifo.sv",
                             "rtl/axis/dsm_axis14_to_core8_cdc.sv", CONTEXT[-1]),
        "cdc_immediate_end": ("rtl/axis/dsm_reset_sync.sv", "rtl/axis/dsm_async_fifo.sv",
                              "rtl/axis/dsm_axis14_to_core8_cdc.sv"),
    }
    groups = {}
    for group, (report, stem, assumptions, witnesses) in specs.items():
        sources = (*files[group], f"dv/uvm/formal/{stem}_harness.sv",
                   f"dv/uvm/formal/run_{stem}_fpv.tcl")
        results = extract(report)
        for witness in witnesses:
            if not any(row["name"].endswith("." + witness) and row["result"].startswith("covered")
                       for row in results):
                raise ValueError(f"Missing operational witness {witness} in {report}")
        groups[group] = dict(native_report=f"{report.parent.name}/{report.name}",
                             report_sha256=digest(report.read_bytes()), assumptions=assumptions,
                             witnesses=witnesses, reported_properties=results,
                             source_sha256={source: fingerprint(source) for source in sources})
    return groups


def evidence_group(property_name):
    if property_name.startswith("Parameter audit"):
        return "static_parameters"
    if "input_tail_never_latched" in property_name:
        return "cubic_stage1"
    if "empty_output_allows_input" in property_name:
        return "dpd_wrapper"
    if property_name == "a_immediate_end_arm_unreachable":
        return "cdc_immediate_end"
    return "frontend_control"


def key(row, metric, predicate, arm):
    return tuple(row[name] for name in COMMON) + (metric, predicate, arm)


def main():
    parser = ArgumentParser(description=__doc__)
    for name in ("round6-runs", "v14-runs", "current-run", "out"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    data = ROOT / "docs/verification/data"
    sources = [data / "dsm-v13-round6/round6_waiver_candidates.csv",
               data / "dsm-v14-coverage/additional_waiver_candidates.csv"]
    audit = args.current_run / "audit"
    groups = formal_groups(args.round6_runs, args.v14_runs)
    native = {}
    for name, predicate, arm in (("round5_focus_condition_gaps.csv", "predicate", "operand_tuple"),
                                 ("statements.csv", "code", "arm")):
        for row in csv_rows(audit / name):
            if row["status"] != "OPEN":
                continue
            identity = key(row, row.get("metric", "cond"), row[predicate], row[arm])
            native.setdefault(identity, []).append(row)
    package = []
    seen = set()
    for source in sources:
        for row in csv_rows(source):
            prop = row.get("proof") or row["property"]
            group = evidence_group(prop)
            report_hash = row.get("proof_sha256") or row["formal_sha256"]
            rtl_hash = fingerprint(row["source"])
            if digest((ROOT / row["source"]).read_bytes()) != rtl_hash:
                raise ValueError(f"RTL changed from frozen revision: {row['source']}")
            classification = "FORMAL_PROVEN_UNREACHABLE"
            if group == "static_parameters":
                classification = "STATIC_PARAMETER_UNREACHABLE"
                if report_hash != rtl_hash:
                    raise ValueError(f"Static source hash mismatch: {row}")
                assumptions = row["applicability"]
                witnesses = "Static bound or parameter substitution"
            else:
                if report_hash != groups[group]["report_sha256"]:
                    raise ValueError(f"Formal source report hash mismatch: {row}")
                property_names = prop.split("; ")
                for property_name in property_names:
                    if not any(p["name"].endswith("." + property_name) and
                               p["result"].startswith(("proven", "uncoverable"))
                               for p in groups[group]["reported_properties"]):
                        raise ValueError(f"Missing effective proof: {property_name}")
                assumptions = groups[group]["assumptions"]
                witnesses = " | ".join(groups[group]["witnesses"])
                if group == "cdc_immediate_end" or prop == "a_read_empty_complements_valid":
                    classification = "STRUCTURAL_UNREACHABLE"
            identity = key(row, row["metric"], row["predicate"], row["operand_tuple"])
            matches = native.get(identity, [])
            if (identity in seen or len(matches) != 1 or matches[0].get("missing", "1") != "1"
                    or row["applied"] != "false" or row["status"] != "APPROVAL_PENDING"):
                raise ValueError(f"Candidate is duplicate, applied, or no longer an exact open bin: {row}")
            seen.add(identity)
            match, = matches
            locator = match["evidence"]
            report_file = args.current_run / "cumulative" / row["configuration"] / locator.split("#")[0]
            if digest(report_file.read_bytes()) != match["report_sha256"]:
                raise ValueError(f"Current native report hash mismatch: {locator}")
            item = {name: row[name] for name in (*COMMON, "module", "metric", "predicate", "operand_tuple")}
            package.append(dict(review_id=f"V14-W{len(package)+1:03}", **item,
                                classification=classification, evidence_group=group,
                                expression_kind=match.get("expression_kind", ""),
                                proof_property=prop, proof_or_static_sha256=report_hash,
                                assumptions=assumptions, non_vacuity_evidence=witnesses,
                                reason=row["reason"], applicability=row["applicability"],
                                baseline_native_locator=row["evidence"],
                                baseline_native_sha256=row["report_sha256"],
                                current_native_locator=locator,
                                current_native_sha256=match["report_sha256"],
                                rtl_sha256=rtl_hash, review_status="PENDING_CLAUDE_DV_REVIEW",
                                final_approval="PENDING_OWNER_APPROVAL", applied="false"))
    if len(package) != 106:
        raise ValueError(f"Expected exactly 106 candidates, found {len(package)}")
    args.out.mkdir(parents=True, exist_ok=True)
    with (args.out / "candidates.csv").open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=list(package[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(package)
    manifest = dict(baseline_commit=BASE,
                    baseline_rtl_tree=subprocess.check_output(
                        ["git", "rev-parse", f"{BASE}:rtl"], cwd=ROOT, text=True).strip(),
                    configurations={"ef1_axil": [1, 1, 7168], "mash11_axil": [3, 2, 5120]},
                    configuration_fields=["DSM_ARCH", "TIDSM_ORDER", "STEP"],
                    common_configuration="Centered Cubic x2+x2, AXI-Lite, one DPD tap, Generic FIFO",
                    context_sha256={path: fingerprint(path) for path in CONTEXT},
                    source_ledgers_sha256={str(path.relative_to(ROOT)): digest(path.read_bytes()) for path in sources},
                    candidate_csv_sha256=digest((args.out / "candidates.csv").read_bytes()),
                    groups=groups, by_classification=dict(Counter(row["classification"] for row in package)),
                    approved=0, applied=0)
    (args.out / "proof_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    remaining = []
    for identity, matches in native.items():
        if identity in seen:
            continue
        row = matches[0]
        unexplained_control = (
            (row["module"], row["line"]) in (
                ("dsm_axis14_to_core8_cdc", "145"), ("dsm_axis14_to_core8_cdc", "151"),
                ("thermo5_dpd_axi_lite_cfg", "333"),
            ) or (row["module"] == "dsm_interp_x2_centered_cubic_vector" and
                  row["line"] in ("255", "256", "304", "309"))
        )
        if unexplained_control:
            remaining.append(dict(configuration=row["configuration"], instance=row["instance"],
                                  source=row["source"], line_or_range=row["line"], metric=identity[-3],
                                  predicate=identity[-2], operand_or_direction=identity[-1],
                                  current_native_locator=row["evidence"],
                                  current_native_sha256=row["report_sha256"],
                                  rtl_sha256=fingerprint(row["source"]),
                                  classification="INCOMPLETE_PROOF", disposition="KEEP_OPEN"))
    for row in csv_rows(audit / "round5_focus_toggle_ranges.csv"):
        if row["status"] != "OPEN" or not row["signal"].startswith(("sample_count[", "saturation_count[")):
            continue
        for field, direction in (("down_covered", "1->0"), ("up_covered", "0->1")):
            if row[field] == "No":
                remaining.append(dict(configuration=row["configuration"], instance=row["instance"],
                                      source=row["source"], line_or_range=row["signal"], metric="toggle",
                                      predicate=row["signal"], operand_or_direction=direction,
                                      current_native_locator=row["evidence"],
                                      current_native_sha256=row["report_sha256"],
                                      rtl_sha256=fingerprint(row["source"]),
                                      classification="SIMULATION_COST_ONLY", disposition="KEEP_OPEN"))
    with (args.out / "open_examples.csv").open("w", newline="", encoding="utf-8") as out:
        writer = csv.DictWriter(out, fieldnames=list(remaining[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(remaining)


if __name__ == "__main__":
    main()
