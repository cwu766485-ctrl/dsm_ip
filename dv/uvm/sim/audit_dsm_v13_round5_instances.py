#!/usr/bin/env python3
"""Reconcile URG instance counters and account for config-specific waivers."""
import argparse
from collections import defaultdict
import csv
import hashlib
import html
from functools import cache
import json
from pathlib import Path
import re

from generate_dsm_v13_round2_evidence import fragment_rows, parse_dut_code, read_rows, text_cells

METRICS = {"line": (2, "TOTAL", 2), "cond": (3, "Conditions", 1),
           "toggle": (4, "Total Bits", 1), "branch": (6, "Branches", 2)}
DUT = "dsm_v13_multi_sku_uvm_tb.g_product.selected_product_sku.dut"
TIED = {"active_taps[2:0]": "3'h1",
        **{f"c{term}_{part}[15:0]": "16'h4000" if (term, part) == (1, "re") else "16'h0"
           for term in (1, 3, 5) for part in ("re", "im")}}
STATIC_LINES = {
    191: "MAX_TAPS=1 gives comb_tap=0, so only the first accumulator pair executes",
    192: "MAX_TAPS=1 gives comb_tap=0, so only the first accumulator pair executes",
    210: "MAX_TAPS=1 makes the history reset loop empty",
    211: "MAX_TAPS=1 makes the history reset loop empty",
    **dict.fromkeys((238, 239, 240, 242, 243), "USE_EXTERNAL_TAPS=1 always selects external tap data"),
}
EF2_SOURCE = "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv"
EF2_PARENT = "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv"
GUARDS = {
    "gt_tx_user_bridge": (
        (20, "PARALLEL_W != GT_USER_W", "Both bridge widths are connected to the same DATA_W"),
    ),
    "tid32_cartesian_fs4_gt_tx": (
        (71, "CHANNELS < 2", "CHANNELS=32 is even and divisible by VALID_BANKS=8"),
    ),
    "tid32_mash11_weighted_pa_tx": (
        (243, "W < 2 || ACC_W < W", "W=16, ACC_W=18 and CHANNELS=32 satisfy the guard"),
        (245, "IN_SHIFT < 0 || IN_SHIFT >= W", "IN_SHIFT=0 is within the W=16 range"),
    ),
}
WIRING = {
    "rtl/frontend/dsm_frame_gain_vector.sv": (
        "s1_valid <= s0_valid", "s0_valid <= in_valid",
        "s1_frame_start <= s0_valid && s0_frame_start",
        "s1_frame_end <= s0_valid && s0_frame_end",
        "s0_frame_start <= in_valid && in_frame_start",
        "s0_frame_end <= in_valid && in_frame_end",
    ),
    "rtl/interp/dsm_interp_x2_centered_cubic_vector.sv": (
        "tail_output = APPEND_TAIL_VECTOR && tail_pending_q",
        "have_head = (q_count != 0)",
        "out_valid = enable && (tail_output || can_emit_head)",
        "drop_head_tail = have_head && q0_tail && !APPEND_TAIL_VECTOR",
    ),
    "rtl/gt/gt_tx_raw64_boundary.sv": (".PARALLEL_W(DATA_W)", ".GT_USER_W(DATA_W)"),
    "rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv": ("parameter int VALID_BANKS = 8",),
    "rtl/tx_bandpass_if/tid32_mash11_weighted_pa_tx.sv": ("parameter int IN_SHIFT = 0",),
    EF2_SOURCE: ("parameter bit PAIR_LOOKAHEAD = 1'b0", "if (PAIR_LOOKAHEAD) begin"),
    EF2_PARENT: ("tid32_cartesian_ef2_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_tid",),
    "dv/uvm/tb/thermo5_sku_uvm_tb.sv": (".dpd_active_taps(3'd1),.c1_re({48'd0,identity_c1}),.c1_im(64'd0)",
                                       "identity_c1 = 16'd16384", ".DPD_MAX_TAPS(1)", "`THERMO5_DPD_MAX_TAPS", ".c3_re(64'd0),.c3_im(64'd0),.c5_re(64'd0),.c5_im(64'd0)"),
    "rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv": (".dpd_active_taps(dpd_active_taps)",),
    "rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv": (".active_taps(dpd_active_taps)", ".APPEND_TAIL_VECTOR(1'b0)", ".APPEND_TAIL_VECTOR(1'b1)"),
    "rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv": (".MAX_TAPS(DPD_MAX_TAPS)",),
    "rtl/dpd/dpd_memory_poly.v": ("comb_tap < MAX_TAPS", "comb_tap < ((MAX_TAPS + 1) / 2)",
                                 "tap < MAX_TAPS-1", "if (USE_EXTERNAL_TAPS != 0)"),
    "rtl/dpd/dpd_vector16_memory_poly.sv": (".MAX_TAPS(MAX_TAPS), .USE_EXTERNAL_TAPS(1)", ".active_taps(active_taps)", ".c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im)", ".c5_re(c5_re), .c5_im(c5_im)"),
}


@cache
def read_page(path):
    return path.read_text(encoding="utf-8")


@cache
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def section(report, link):
    filename, anchor = link.split("#", 1)
    page = report / filename
    source = read_page(page)
    anchor_text = f'<a name="{anchor}"></a>'
    if source.count(anchor_text) != 1:
        raise ValueError(f"missing or ambiguous metric anchor: {page}#{anchor}")
    body = source.split(anchor_text, 1)[1]
    return page, re.split(r'<a name="(?:inst_tag_\d+_)?(?:Line|Cond|Toggle|Branch|FSM|Assert)"', body, maxsplit=1)[0]


SINGLE_TAP_PAIR = {f"sum_{iq}_pair1_{stage}[63:0]"
                   for iq in ("i", "q") for stage in ("comb", "s8")}


def condition_gaps(body):
    for pre, table in re.findall(r'<pre class="code">(.*?)</pre>\s*(<table.*?</table>)',
                                 body, re.S):
        heading = html.unescape(re.sub(r"<[^>]+>", "", pre))
        expression = re.match(r"\s*LINE\s+(\d+)\s+((?:SUB-)?EXPRESSION) (.+)",
                              heading, re.S)
        if not expression:
            continue
        line, kind, text = expression.groups()
        predicate = " ".join(text.split()).split(" --", 1)[0]
        for row, _ in fragment_rows(table):
            if row and row[-1] == "Not Covered":
                yield int(line), kind, predicate, tuple(row[:-1])


def interp_constant_reason(instance, line, kind, predicate, operand):
    if line == 68 and kind == "EXPRESSION" and operand == ("1", "0", "1") and "&& have_head" in predicate:
        return "A count of one or two implies have_head"
    if line == 300 and kind == "EXPRESSION" and operand == ("0", "1", "1") and predicate.startswith("(enable && out_valid"):
        return "out_valid implies enable by its continuous assignment"
    if ".g_interp1_centered.u_interp_1" in instance:
        if line == 71 and kind == "EXPRESSION" and operand == ("1", "0") and predicate.startswith("(drop_head_tail ||"):
            return "APPEND_TAIL_VECTOR=1 disables drop_head_tail"
    if ".g_interp2_centered.u_interp_2" not in instance:
        return None
    disabled_tail = {
        (71, "SUB-EXPRESSION", ("1", "0", "1", "1")),
        (74, "EXPRESSION", ("1", "0", "1")),
        (74, "EXPRESSION", ("1", "1", "0")),
        (74, "EXPRESSION", ("1", "1", "1")),
        (83, "SUB-EXPRESSION", ("1", "0")),
        (84, "EXPRESSION", ("0", "1")),
        (84, "EXPRESSION", ("1", "1")),
        (85, "EXPRESSION", ("1", "0", "1")),
        (86, "SUB-EXPRESSION", ("1", "0")),
    }
    if (line, kind, operand) in disabled_tail and "tail_output" in predicate:
        return "APPEND_TAIL_VECTOR=0 makes tail_output constant zero"
    return None


def static_condition_reason(module, instance, line, kind, predicate, operand, axil_write_proven):
    if module == "dsm_interp_x2_centered_cubic_vector":
        return interp_constant_reason(instance, line, kind, predicate, operand)
    if module == "dsm_frame_gain_vector" and kind == "EXPRESSION" and operand == ("0", "1"):
        flags = {112: "(s1_valid && s1_frame_start)", 113: "(s1_valid && s1_frame_end)",
                 123: "(s0_valid && s0_frame_start)", 124: "(s0_valid && s0_frame_end)"}
        if flags.get(line) == predicate:
            return "Same-stage frame flag is registered only with valid and holds or clears with valid"
    if (axil_write_proven and module == "thermo5_dpd_axi_lite_cfg" and line == 93
            and kind == "EXPRESSION" and operand == ("0", "1", "1")
            and predicate == "(((!s_axil_bvalid)) && (aw_pending || aw_take) && (w_pending || w_take))"):
        return "BVALID excludes both accepted/buffered terms (a_bvalid_excludes_line93_tuple)"
    return None


def inventory(report, config, ef2_proven=False, single_tap_proofs=(),
              focus_static=False, axil_write_proven=False):
    rows, waivers = [], []
    instances = set()
    for page in sorted(report.glob("mod*.html")):
        if not re.fullmatch(r"mod\d+\.html", page.name):
            continue
        source = read_page(page)
        title = re.search(r"<title>Unified Coverage Report :: Module :: ([^<]+)</title>", source)
        if not title:
            raise ValueError(f"missing module title: {page}")
        module = title[1]
        sources = re.findall(r"openSrcFile\('[^']*/(rtl/[^']+)'\)", source)
        for cells in read_rows(page):
            if len(cells) != 8:
                continue
            names = text_cells(cells)
            instance = names[0]
            if (instance != DUT and not instance.startswith(DUT + ".")) or not any(
                    re.fullmatch(r"mod\d+(?:_\d+)?\.html#inst_tag_\d+", link) for link in cells[0]["links"]):
                continue
            if instance in instances:
                raise ValueError(f"duplicate instance: {instance}")
            instances.add(instance)
            for metric, (column, label, start) in METRICS.items():
                if not names[column]:
                    continue
                link, = cells[column]["links"]
                detail, body = section(report, link)
                summary = next(values for values, _ in fragment_rows(body) if values and values[0] == label)
                total, hits = map(int, summary[start:start + 2])
                if not total or abs(100 * hits / total - float(names[column])) > 0.011:
                    raise ValueError(f"counter disagrees with instance score: {instance}/{metric}")
                count = 0
                if (config.endswith("_product") and metric == "toggle"
                        and module in {"dpd_memory_poly", "dpd_vector16_memory_poly"}
                        and ".g_memory_dpd.u_memory_dpd" in instance):
                    table = re.search(r"<caption><b>Port Details</b></caption>(.*?)</table>", body, re.S)
                    if not table:
                        raise ValueError(f"missing port details: {instance}")
                    for values, _ in fragment_rows("<table>" + table[1] + "</table>"):
                        if not values or values[0] not in TIED:
                            continue
                        signal, _, down, up, *direction = values
                        if direction != ["INPUT"] or (down, up) != ("No", "No"):
                            raise ValueError(f"tie-off has unexpected URG status: {instance}/{signal}")
                        width = int(signal.split("[")[1].split(":")[0]) + 1
                        for bit in range(width):
                            for edge in ("0->1", "1->0"):
                                waivers.append(dict(configuration=config, module=module, instance=instance,
                                                    signal=signal.split("[")[0], bit=bit, direction=edge,
                                                    constant=TIED[signal], status="APPLIED_FIXTURE_ONLY",
                                                    reason="Direct constant connection in frozen Product UVM elaboration",
                                                    urg_anchor=link, report_sha256=digest(detail)))
                        count += 2 * width
                one_tap_lane = (module == "dpd_memory_poly" and
                                ".g_memory_dpd.u_memory_dpd.g_lane[" in instance)
                if one_tap_lane and metric == "toggle" and "a_second_pair_zero" in single_tap_proofs:
                    found = set()
                    for values, _ in fragment_rows(body):
                        if not values or values[0] not in SINGLE_TAP_PAIR:
                            continue
                        signal = values[0]
                        if signal in found or values[1:] != ["No", "No", "No"]:
                            raise ValueError(f"unexpected second pair Toggle: {instance}/{values}")
                        found.add(signal)
                        for bit in range(64):
                            for edge in ("0->1", "1->0"):
                                waivers.append(dict(configuration=config, module=module, instance=instance,
                                                    signal=signal.split("[")[0], bit=bit, direction=edge,
                                                    constant="0", status="APPLIED_FORMAL",
                                                    reason="One-tap second accumulator pair is zero (a_second_pair_zero)",
                                                    urg_anchor=link, report_sha256=digest(detail)))
                                count += 1
                    if found != SINGLE_TAP_PAIR:
                        raise ValueError(f"missing second pair report rows: {instance}")
                if one_tap_lane and metric == "cond" and "a_invalid_output_no_saturation" in single_tap_proofs:
                    for line, kind, predicate, operand in condition_gaps(body):
                        if line == 337 and kind == "EXPRESSION" and operand == ("0", "1") and predicate == (
                            "(valid_pipe[(PIPE_STAGES - 1)] && (sat_i || sat_q))"
                        ):
                            waivers.append(dict(configuration=config, module=module, instance=instance,
                                                signal=f"{sources[0]}:{line}", bit="", direction="",
                                                constant="0,1", status="APPLIED_FORMAL",
                                                reason="No saturation with invalid output (a_invalid_output_no_saturation)",
                                                urg_anchor=link, report_sha256=digest(detail)))
                            count += 1
                if focus_static and metric == "cond":
                    for line, kind, predicate, operand in condition_gaps(body):
                        reason = static_condition_reason(module, instance, line, kind, predicate, operand, axil_write_proven)
                        if reason:
                            waivers.append(dict(configuration=config, module=module, instance=instance,
                                                signal=f"{sources[0]}:{line}", bit="", direction="",
                                                constant=",".join(operand), status="APPLIED_STATIC_ELABORATION",
                                                reason=reason, urg_anchor=link, report_sha256=digest(detail)))
                            count += 1
                static_lines = {}
                if metric == "line" and module == "dpd_memory_poly":
                    static_lines = STATIC_LINES
                if (metric == "line" and ef2_proven and config.startswith("ef2_")
                        and module == "tid32_cartesian_ef2_fs4_gt_tx"
                        and instance.endswith(".g_order2.u_tid")):
                    static_lines = dict.fromkeys(
                        (232, 233, 236, 239, 240, 241, 242, 243, 244, 245, 246, *range(249, 257)),
                        "EF2 PAIR_LOOKAHEAD=0, checked by VC Formal and the parent instance wiring")
                if static_lines:
                    local = html.unescape(re.sub(r"<[^>]+>", "", body))
                    for line, reason in static_lines.items():
                        matches = re.findall(rf"(?m)^\s*{line} +0/1 +==> +(.+)$", local)
                        if len(matches) != 1:
                            raise ValueError(f"static line does not map to one missing bin: {instance}:{line}")
                        waivers.append(dict(configuration=config, module=module, instance=instance,
                                            signal=f"{sources[0]}:{line}", bit="", direction="",
                                            constant="", status="APPLIED_STATIC_ELABORATION", reason=reason,
                                            urg_anchor=link, report_sha256=digest(detail)))
                        count += 1
                if metric == "branch" and module in GUARDS:
                    for line, predicate, reason in GUARDS[module]:
                        guard_pattern = (
                            rf'<pre class="code">[^\n]*\n\s*{line}\s+if \('
                            rf'{re.escape(predicate)}.*?</pre>'
                            r'\s*<br clear=all>\s*<span class=repname>Branches:</span>'
                            r'\s*<br clear=all>\s*(<table.*?</table>)'
                        )
                        tables = re.findall(guard_pattern, html.unescape(body), re.S)
                        if len(tables) != 1 or [
                            values for values, _ in fragment_rows(tables[0])
                            if values and values[-1] == "Not Covered"
                        ] != [["1", "Not Covered"]]:
                            raise ValueError(f"static guard does not map to one missing arm: {instance}:{line}")
                        waivers.append(dict(configuration=config, module=module, instance=instance,
                                            signal=f"{sources[0]}:{line}", bit="", direction="",
                                            constant="true arm", status="APPLIED_STATIC_ELABORATION",
                                            reason=reason, urg_anchor=link, report_sha256=digest(detail)))
                        count += 1
                if count > total - hits:
                    raise ValueError(f"waivers exceed missing bins: {instance}")
                rows.append(dict(configuration=config, module=module, instance=instance,
                                 source=sources[0] if sources else "", metric=metric, raw_total=total,
                                 raw_hits=hits, waived=count, raw_missing=total-hits,
                                 adjusted_missing=total-hits-count, evidence=link))
    if not rows:
        raise ValueError(f"no DUT instance counters: {report}")
    return rows, waivers


def write(path, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reports", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--build-run", type=Path, required=True)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--ef2-properties", type=Path)
    parser.add_argument("--single-tap-properties", type=Path)
    parser.add_argument("--axil-write-properties", type=Path)
    parser.add_argument("--config", choices=("ef1_axil", "mash11_axil"), action="append")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    hashes = {}
    for source, fragments in WIRING.items():
        path = root / source
        if not all(fragment in path.read_text() for fragment in fragments):
            raise ValueError(f"fixture tie-off path changed: {source}")
        hashes[source] = digest(path)
    ef2_proven = False
    if args.ef2_properties:
        proof = args.ef2_properties.read_text()
        for state, name in (("proven", "a_product_pair_lookahead_disabled"),
                            ("uncoverable", "c_pair_lookahead_arm_enabled")):
            if not re.search(rf"(?m)^.*\] {state}\s+.*\.{name}\s*$", proof):
                raise ValueError(f"EF2 proof missing {state} {name}")
        ef2_proven = True
    single_tap_proofs = set()
    if args.single_tap_properties:
        proof = args.single_tap_properties.read_text()
        for name in ("a_second_pair_zero", "a_invalid_output_no_saturation"):
            if re.search(rf"(?m)^.*\] proven\s+.*thermo5_single_tap_coverage_harness\.{name}\s*$", proof):
                single_tap_proofs.add(name)
        for name in ("c_valid", "c_stalled", "c_accept_bubble"):
            if not re.search(rf"(?m)^.*\] covered\b.*thermo5_single_tap_coverage_harness\.{name}\s*$", proof):
                raise ValueError(f"missing one-tap operational witness {name}")
        for source in ("dv/uvm/formal/thermo5_single_tap_coverage_harness.sv",
                       "dv/uvm/formal/run_thermo5_single_tap_coverage.tcl", "rtl/dpd/dpd_poly.v"):
            hashes[source] = digest(root / source)
    axil_write_proven = False
    if args.axil_write_properties:
        proof = args.axil_write_properties.read_text()
        expected = (("proven", "a_bvalid_excludes_line93_tuple"),
                    ("uncoverable", "c_line93_uncovered_tuple"),
                    ("covered", "c_write_response_active"), ("covered", "c_write_fire"))
        for status, name in expected:
            if not re.search(rf"(?m)^.*\] {status}\b.*thermo5_axil_cfg_line93_harness\.{name}\s*$", proof):
                raise ValueError(f"AXI-Lite write proof missing {status} {name}")
        axil_write_proven = True
        for source in ("dv/uvm/formal/thermo5_axil_cfg_line93_harness.sv",
                       "dv/uvm/formal/run_thermo5_axil_cfg_line93_fpv.tcl",
                       "rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv"):
            hashes[source] = digest(root / source)
    args.output.mkdir(parents=True, exist_ok=True)
    all_rows, all_waivers, scores = [], [], []
    for sku in ("ef1", "ef2", "mash11"):
        for interface in ("product", "axil"):
            config = f"{sku}_{interface}"
            if args.config and config not in args.config:
                continue
            build = args.build_run / config
            if interface == "axil":
                compile_record = build / "simv.daidir/vcs_rebuild"
                if not re.search(r"\+define\+THERMO5_DPD_MAX_TAPS=1(?![0-9])",
                                 compile_record.read_text(errors="replace")):
                    raise ValueError(f"unverified one-tap build: {config}")
            report = args.reports / config
            rows, waivers = inventory(report, config, ef2_proven, single_tap_proofs, bool(args.config), axil_write_proven)
            all_rows.extend(rows)
            all_waivers.extend(waivers)
            before = {}
            if args.baseline:
                previous, _ = inventory(args.baseline / config, config)
                before = {(row["instance"], row["metric"]): row for row in previous}
                after_keys = {(row["instance"], row["metric"]) for row in rows}
                if after_keys != before.keys():
                    raise ValueError(f"instance inventory changed: {config}")
                for row in rows:
                    prior = before[row["instance"], row["metric"]]
                    if (prior["raw_total"] != row["raw_total"] or
                            prior["raw_hits"] > row["raw_hits"]):
                        raise ValueError(f"instance denominator or hit count regressed: {row}")
            hierarchy = parse_dut_code(report / "hierarchy.html")
            for metric in METRICS:
                matching = [row for row in rows if row["metric"] == metric]
                hits = sum(row["raw_hits"] for row in matching)
                total = sum(row["raw_total"] for row in matching)
                waived = sum(row["waived"] for row in matching)
                raw = 100 * hits / total
                if abs(raw - float(hierarchy[metric])) > 0.011:
                    raise ValueError(f"{config}/{metric}: instance {raw:.4f} != URG {hierarchy[metric]}")
                adjusted = 100 * hits / (total - waived)
                prior_hits = sum(before[row["instance"], metric]["raw_hits"] for row in matching) if before else None
                scores.append(dict(configuration=config, metric=metric, raw_hits=hits,
                                   new_raw_hits=hits-prior_hits if prior_hits is not None else "",
                                   raw_total=total, waived=waived, adjusted_total=total-waived,
                                   raw_percent=f"{raw:.2f}", adjusted_percent=f"{adjusted:.2f}",
                                   remaining_open=total-hits-waived, status="PASS" if adjusted >= 95 else "OPEN"))
    if args.config:
        gaps = []
        toggle = []
        waived = {(w["configuration"], w["instance"], w["signal"], w["constant"])
                  for w in all_waivers if ":" in w["signal"]}
        for row in all_rows:
            if row["metric"] not in ("cond", "toggle") or not row["raw_missing"]:
                continue
            report = args.reports / row["configuration"]
            detail, body = section(report, row["evidence"])
            common = {key: row[key] for key in ("configuration", "module", "instance", "source", "evidence")}
            common["report_sha256"] = digest(detail)
            if row["metric"] == "cond":
                bins = list(condition_gaps(body))
                if len(bins) != row["raw_missing"]:
                    raise ValueError(f"Condition detail does not reconcile: {row}")
                for line, kind, predicate, operand in bins:
                    vector = ",".join(operand)
                    key = (row["configuration"], row["instance"], f'{row["source"]}:{line}', vector)
                    gaps.append(dict(**common, line=line, expression_kind=kind, predicate=predicate,
                                     operand_tuple=vector, status="WAIVED" if key in waived else "OPEN"))
            else:
                for values, _ in fragment_rows(body):
                    if len(values) < 4 or values[2] not in ("Yes", "No") or values[3] not in ("Yes", "No"):
                        continue
                    if "No" not in values[2:4]:
                        continue
                    proven = "a_second_pair_zero" in single_tap_proofs and row["module"] == "dpd_memory_poly" and values[0] in SINGLE_TAP_PAIR
                    toggle.append(dict(**common, signal=values[0], down_covered=values[2], up_covered=values[3],
                                       status="WAIVED" if proven else "OPEN"))
        write(args.output / "round5_focus_condition_gaps.csv", gaps)
        write(args.output / "round5_focus_toggle_ranges.csv", toggle)
    write(args.output / "round5_instance_counters.csv", all_rows)
    write(args.output / "round5_code_waivers.csv", all_waivers)
    write(args.output / "round5_code_coverage_adjusted.csv", scores)
    top_gaps = defaultdict(int)
    for row in all_rows:
        top_gaps[row["metric"], row["module"]] += row["adjusted_missing"]
    leaders = sorted(top_gaps.items(), key=lambda item: (-item[1], item[0]))
    result = dict(status="PASS" if all(s["status"] == "PASS" for s in scores) else "OPEN",
                  scope="Selected fixed DUTs. Adjusted arithmetic uses audited URG counters.",
                  single_tap_proofs=sorted(single_tap_proofs),
                  axil_write_properties_sha256=digest(args.axil_write_properties) if axil_write_proven else None,
                  single_tap_properties_sha256=digest(args.single_tap_properties) if args.single_tap_properties else None,
                  applied_waivers=len(all_waivers), source_sha256=hashes,
                  ef2_properties_sha256=digest(args.ef2_properties) if ef2_proven else None,
                  leading_gaps=[dict(metric=m, module=n, missing=v) for (m, n), v in leaders[:20]])
    (args.output / "round5_instance_audit.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
