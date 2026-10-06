"""Inventory frozen thermo5 Vivado CDC rows and URG instance condition bins.

Usage: python tools/hw/thermo5_audit_reports.py CDC_RPT URG_DIR OUTPUT_DIR
Only generated CSV files are written to OUTPUT_DIR; no coverage is waived.
"""

import csv
import html
import re
import sys
from collections import Counter
from pathlib import Path


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def ownership(instance):
    return "VENDOR_XPM" if "xpm_fifo" in instance.lower() else "PROJECT_RTL"


def project_source_line(instance, line_no):
    root = Path(__file__).resolve().parents[2]
    if "u_bridge" in instance:
        source = root / "rtl/gt/gt_tx_user_bridge.sv"
    elif "u_interp_" in instance:
        source = root / "rtl/interp/dsm_interp_x2_polyphase_vector.sv"
    elif "u_dpd" in instance:
        source = root / "rtl/dpd/dpd_memory_poly.v"
    elif ".u_tid" in instance:
        source = root / "rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv"
    else:
        return ""
    try:
        lines = source.read_text(encoding="utf-8", errors="replace").splitlines()
        return lines[int(line_no) - 1].strip()
    except (OSError, IndexError, ValueError):
        return ""


def cdc_rows(path):
    rows = []
    src_clock = dst_clock = ""
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("Source Clock:"):
            src_clock = line.split(":", 1)[1].strip()
        elif line.startswith("Destination Clock:"):
            dst_clock = line.split(":", 1)[1].strip()
        match = re.match(
            r"^\s*\d+\s+(CDC-\d+)\s+(Critical|Warning|Info)\s+.+?\s+\d+\s+"
            r"(?:False Path|Asynch Clock Groups)\s+(\S+)\s+(\S+)\s*$", line
        )
        if match:
            source = match[3]
            if source == "run_request":
                disposition = "OPEN_CORE_SYNCHRONOUS_SOURCE_AND_TIMING"
            elif source in {"rst125_n", "rst218_n"}:
                disposition = "OPEN_RESET_RDC_AND_RELEASE_TIMING"
            else:
                disposition = "REVIEW_XPM_SYNCHRONIZER"
            rows.append(dict(source_clock=src_clock, destination_clock=dst_clock,
                             rule=match[1], severity=match[2], source=source,
                             destination=match[4], disposition=disposition))
    return rows


def condition_rows(directory, include_covered_toggles=False):
    rows = []
    toggle_rows = []
    branch_rows = []
    branch_gap_rows = []
    condition_re = re.compile(
        r'<pre class="code">\s*LINE\s+(\d+)\s+(.*?)</pre>\s*<table.*?</table>', re.S
    )
    bin_re = re.compile(r'<tr class="(uRed|uGreen)">(.*?)</tr>', re.S)
    # URG sensitive-expression rows omit </td> before the next cell.
    cell_re = re.compile(r"<td[^>]*>(.*?)(?:</td>|(?=<td|</tr>|$))", re.S)
    for file in sorted(directory.glob("mod*.html")):
        page = file.read_text(encoding="utf-8", errors="replace")
        for tag_name, block, single in instance_blocks(page):
            name = re.search(r"(?:Module Instance|Line Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>", block, re.S)
            if not name or not name[1].startswith("thermo5_sku_uvm_tb.dut"):
                continue
            prefix='' if single else tag_name+'_'
            anchor = re.search(r'<a name="%sCond"></a>' % re.escape(prefix), block)
            section = ''
            if anchor:
                end = re.search(r'<a name="%s(?:Toggle|Branch)"></a>' % re.escape(prefix), block[anchor.end():])
                section = block[anchor.end():anchor.end() + end.start()] if end else block[anchor.end():]
            for condition in condition_re.finditer(section):
                expression = html.unescape(re.sub(r"<[^>]+>", "", condition[2])).strip()
                for covered, bin_html in bin_re.findall(condition[0]):
                    cells = [html.unescape(re.sub(r"<[^>]+>", "", cell)).strip()
                             for cell in cell_re.findall(bin_html)]
                    if cells and cells[-1] in {"Covered", "Not Covered"}:
                        disposition = "MERGED_TEST_HIT"
                        if cells[-1] == "Not Covered":
                            if "u_dpd" in name[1] and condition[1] == "140":
                                disposition = "OPEN_FULL_CHAIN_BLOCK_TEST_COVERS"
                            elif "u_dpd" in name[1] and condition[1] == "336":
                                disposition = ("PROOF_IDENTITY_INVALID_SLOT_SAT_UNREACHABLE_XSIM" if cells[0] == "0"
                                               and "EXPRESSION" in expression and "SUB" not in expression
                                               else "PROOF_IDENTITY_VALID_SAT_UNREACHABLE_XSIM")
                            elif "u_interp_" in name[1]:
                                disposition = ("OPEN_REACHABLE_STAGE1_EMPTY_BLOCKED" if condition[1] == "71"
                                               else "OPEN_REACHABLE_STAGE0_HOLD" if condition[1] == "72"
                                               else "OPEN_RESET_WITH_ENABLE_BLOCK_ONLY")
                            elif name[1]=='thermo5_sku_uvm_tb.dut' and condition[1] in ('54','58'):
                                disposition='FIXED_LOW_POWER_DISABLED_CONSTANT_OPERAND'
                            elif name[1].endswith('.u_cdc') and condition[1]=='190' and cells[:-1]==['1','1','0']:
                                disposition='FIXED_CORE_DRAIN0_CONSTANT_OPERAND'
                            else:
                                disposition = "OPEN_RESET_RELEASE_REVIEW"
                        rows.append(dict(module_file=file.name, instance=name[1],
                                         line=condition[1], expression=" ".join(expression.split()),
                                         operand_bin="/".join(cells[:-1]), status=cells[-1],
                                         disposition=disposition, ownership=ownership(name[1])))
            toggle_anchor = re.search(r'<a name="%sToggle"></a>' % re.escape(prefix), block)
            branch_anchor = re.search(r'<a name="%sBranch"></a>' % re.escape(prefix), block)
            if toggle_anchor:
                toggle_section = block[toggle_anchor.end():branch_anchor.start() if branch_anchor else len(block)]
                for detail in re.finditer(r'<caption><b>(Port Details|Signal Details)</b></caption>(.*?)(?=<caption>|<hr>|$)', toggle_section, re.S):
                    for raw_row in re.findall(r'<tr>(.*?)</tr>', detail[2], re.S):
                        cells = [html.unescape(re.sub(r"<[^>]+>", "", cell)).strip()
                                 for cell in cell_re.findall(raw_row)]
                        if len(cells) >= 4 and (include_covered_toggles or "No" in cells[1:4]):
                            signal = cells[0]
                            if "u_dpd" in name[1] and re.match(r"(?:active_taps|c[135]_(?:re|im))\[", signal):
                                disposition = "SKU_FIXED_DPD1_IDENTITY_PORT_PROOF_TB"
                            elif "u_dpd" in name[1] and "pair1" in signal:
                                disposition = "SKU_MAX_TAPS1_PARAMETER_PROOF"
                            elif "u_dpd" in name[1] and signal.startswith("sample_count["):
                                disposition = "OPEN_LONGER_VALID_STREAM_COUNTER_WRAP"
                            elif "u_dpd" in name[1] and (signal.startswith("saturation_count[") or signal in {"sat_i", "sat_q"}):
                                disposition = "PROOF_IDENTITY_NO_SATURATION_XSIM"
                            elif ".u_tid" in name[1]:
                                disposition = "OPEN_TID_INPUT_RANGE_STRESS"
                            else:
                                disposition = "OPEN_TOGGLE_BIT_REVIEW"
                            toggle_rows.append(dict(module_file=file.name, instance=name[1],
                                                    kind=detail[1], signal=signal,
                                                    toggle=cells[1], one_to_zero=cells[2], zero_to_one=cells[3],
                                                    disposition=disposition, ownership=ownership(name[1])))
            if branch_anchor:
                branch_section = block[branch_anchor.end():]
                source_text = ""
                source = re.search(r'<pre class="code">(.*?)</pre>', branch_section, re.S)
                if source:
                    clean_source = re.sub(r"<font[^>]*>.*?</font>", "", source[1], flags=re.S)
                    source_text = html.unescape(re.sub(r"<[^>]+>", "", clean_source))
                source_lines = {}
                for source_line in source_text.splitlines():
                    match = re.match(r"^\s*(\d+)\s+(.*)$", source_line)
                    if match:
                        source_lines[match[1]] = " ".join(match[2].split())
                for line_no, total, covered in re.findall(
                    r'<td>IF</td>\s*<td class="rt">(\d+)</td>\s*<td class="rt">(\d+)</td>\s*<td class="rt">(\d+)</td>',
                    branch_section, re.S):
                    if int(covered) < int(total):
                        statement = source_lines.get(line_no, "")
                        project_statement = project_source_line(name[1], line_no)
                        if project_statement:
                            statement = project_statement
                        if "u_bridge" in name[1] and "PARALLEL_W != GT_USER_W" in statement:
                            disposition = "SKU_PARALLEL_WIDTH_EQUALS_GT_WIDTH_PROOF"
                        elif ".u_tid" in name[1] and "CHANNELS < 2" in statement:
                            disposition = "SKU_TID_CHANNELS_VALID_PARAMETER_PROOF"
                        elif "u_interp_" in name[1] and "INTERP_TAPS < 2" in statement:
                            disposition = "SKU_INTERP_TAPS2_LEGAL_PARAMETER_PROOF"
                        elif "u_interp_" in name[1] and "INTERP_TAPS == 2" in statement:
                            disposition = "SKU_INTERP_TAPS2_PARAMETER_GUARD_PROOF"
                        elif "u_interp_" in name[1] and "rounded > maxv" in statement:
                            disposition = "PROOF_INTERP2_CONVEX_AVERAGE_NO_SATURATION"
                        elif "u_interp_" in name[1] and "rounded < minv" in statement:
                            disposition = "PROOF_INTERP2_CONVEX_AVERAGE_NO_SATURATION"
                        else:
                            disposition = "OPEN_BRANCH_ARM_DIRECTION_UNRESOLVED"
                        branch_rows.append(dict(module_file=file.name, instance=name[1], line=line_no,
                                                total=total, covered=covered, missing=str(int(total)-int(covered)),
                                                disposition=disposition, ownership=ownership(name[1])))
                        branch_gap_rows.append(dict(
                            module_file=file.name, instance=name[1], line=line_no,
                            branch_kind="IF", source_statement=statement,
                            total=total, covered=covered, missing=str(int(total)-int(covered)),
                            disposition=disposition, ownership=ownership(name[1])))
    return rows, toggle_rows, branch_rows, branch_gap_rows


def instance_blocks(page):
    """URG shares module metric sections for a single self-instance."""
    tags=list(re.finditer(r"<div name='(inst_tag_\d+)'>",page))
    if tags:
        for index,tag in enumerate(tags):
            yield tag[1],page[tag.end():tags[index+1].start() if index+1<len(tags) else len(page)],False
    else:
        tag=re.search(r'<a name="(inst_tag_\d+)"></a>',page)
        if tag and 'Module Instance' in page:
            yield tag[1],page,True


def assertion_rows(path):
    """Export assertion records from URG's assertion report without waivers."""
    page = path.read_text(encoding="utf-8", errors="replace")
    anchors = list(re.finditer(r'<a name="tag_ast_(no_covr|succ|fail|no_attp)"></a>', page))
    rows = []
    for index, anchor in enumerate(anchors):
        end = anchors[index + 1].start() if index + 1 < len(anchors) else len(page)
        section = page[anchor.end():end]
        status = {
            "no_covr": "UNCOVERED",
            "succ": "SUCCESS",
            "fail": "FAILURE",
            "no_attp": "WITHOUT_ATTEMPTS",
        }[anchor[1]]
        for raw_row in re.findall(r'<tr class="wht">(.*?)</tr>', section, re.S):
            cells = [html.unescape(re.sub(r"<[^>]+>", "", cell)).strip()
                     for cell in re.findall(r"<td[^>]*>(.*?)</td>", raw_row, re.S)]
            if len(cells) < 7 or not cells[0]:
                continue
            assertion = " ".join(cells[0].split())
            source = re.search(r'onclick="openSrcFile\(\'(.*?)\'\)"', raw_row)
            instance = assertion.rsplit(".unnamed$$_", 1)[0]
            rows.append(dict(
                assertion=assertion,
                instance=instance,
                category=cells[1],
                severity=cells[2],
                attempts=cells[3],
                successes=cells[4],
                failures=cells[5],
                incomplete=cells[6],
                status=status,
                source_file=source[1] if source else "",
                ownership="VENDOR_XPM" if "xpm_fifo" in assertion.lower() else "PROJECT_RTL_OR_UVM",
            ))
    return rows


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    cdc_path, urg_dir, out_dir = map(Path, sys.argv[1:])
    out_dir.mkdir(parents=True, exist_ok=True)
    cdc = cdc_rows(cdc_path)
    conditions, toggles, branches, branch_gaps = condition_rows(urg_dir)
    assertions = assertion_rows(urg_dir / "asserts.html")
    write_csv(out_dir / "cdc_paths.csv",
              ["source_clock", "destination_clock", "rule", "severity", "source", "destination", "disposition"], cdc)
    write_csv(out_dir / "urg_condition_bins.csv",
              ["module_file", "instance", "line", "expression", "operand_bin", "status", "disposition", "ownership"], conditions)
    write_csv(out_dir / "urg_uncovered_toggle_signals.csv",
              ["module_file", "instance", "kind", "signal", "toggle", "one_to_zero", "zero_to_one", "disposition", "ownership"], toggles)
    write_csv(out_dir / "urg_branch_instance_summary.csv",
              ["module_file", "instance", "line", "total", "covered", "missing", "disposition", "ownership"], branches)
    write_csv(out_dir / "urg_uncovered_branch_lines.csv",
              ["module_file", "instance", "line", "branch_kind", "source_statement",
               "total", "covered", "missing", "disposition", "ownership"], branch_gaps)
    write_csv(out_dir / "urg_assertions.csv",
              ["assertion", "instance", "category", "severity", "attempts", "successes",
               "failures", "incomplete", "status", "source_file", "ownership"], assertions)
    print(f"CDC_PATHS={len(cdc)} CDC_BY_SOURCE={dict(Counter(row['source'] for row in cdc if row['source'] in {'rst125_n', 'rst218_n', 'run_request'}))}")
    print(f"URG_CONDITION_BINS={len(conditions)} UNCOVERED={sum(row['status'] == 'Not Covered' for row in conditions)} INSTANCES={len({row['instance'] for row in conditions})}")
    print(f"URG_UNCOVERED_TOGGLE_SIGNALS={len(toggles)} BRANCH_LINES_WITH_GAPS={len(branch_gaps)} ASSERTION_ROWS={len(assertions)}")


if __name__ == "__main__":
    main()
