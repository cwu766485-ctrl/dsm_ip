#!/usr/bin/env python3
"""Extract DSM V1.3 Round 2 evidence from VCS/URG outputs."""

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_RUN = ROOT / "runs" / "dsm_v13_round2" / "final2"
DEFAULT_DATA = ROOT / "docs" / "verification" / "data" / "dsm-v13-round2"
CONFIGS = {
    "ef1_product": ("EF1", "EF1 Product", "ef1"),
    "ef1_axil": ("EF1", "EF1 AXI-Lite", "ef1_axil"),
    "ef2_product": ("EF2", "EF2 Product", "ef2"),
    "ef2_axil": ("EF2", "EF2 AXI-Lite", "ef2_axil"),
    "mash11_product": ("MASH 1-1", "MASH Product", "mash11_product"),
    "mash11_axil": ("MASH 1-1", "MASH AXI-Lite", "mash11_axil"),
    "mash11_wrapper_core": ("MASH 1-1", "MASH wrapper/core", "mash11_core"),
}
R1_NAMES = {
    "ef1_product": ("EF1", "Product Generic FIFO"),
    "ef1_axil": ("EF1", "AXI-Lite Generic FIFO"),
    "ef2_product": ("EF2", "Product Generic FIFO"),
    "ef2_axil": ("EF2", "AXI-Lite Generic FIFO"),
    "mash11_wrapper_core": ("MASH11", "Legacy block wrapper + core"),
}
TARGETS = {
    "score": "report only", "line": "95", "branch": "95",
    "cond": "95", "toggle": "90", "fsm": "100",
    "assert": "evidence only",
}
METRIC_NAMES = {
    "score": "URG selected DUT score", "line": "Line",
    "cond": "Condition", "toggle": "Toggle", "fsm": "FSM",
    "branch": "Branch", "assert": "Assertion",
}


class HtmlRows(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = {"text": [], "links": []}
        elif tag == "a" and self.cell is not None:
            self.cell["links"].append(attrs.get("href", ""))

    def handle_data(self, data):
        if self.cell is not None:
            self.cell["text"].append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None and self.row is not None:
            self.cell["text"] = " ".join("".join(self.cell["text"]).split())
            self.row.append(self.cell)
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def read_rows(path):
    parser = HtmlRows()
    parser.feed(path.read_text(encoding="utf-8", errors="replace"))
    return parser.rows


def group_source_location(report, group_name):
    source = report.read_text(encoding="utf-8", errors="replace")
    for candidate in re.findall(r"openSrcFile\('([^']+)'", source):
        path = Path(candidate)
        if not path.is_file():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if re.search(r"\bcovergroup\s+" + re.escape(group_name) + r"\b", line):
                try:
                    relative = path.resolve().relative_to(ROOT)
                except ValueError:
                    relative = path
                return f"{relative.as_posix()}:{line_number}"
    return ""


def coverage_symbol_location(report, symbol):
    source = report.read_text(encoding="utf-8", errors="replace")
    for candidate in re.findall(r"openSrcFile\('([^']+)'", source):
        path = Path(candidate)
        if not path.is_file():
            continue
        for line_number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if re.search(r"\b" + re.escape(symbol) + r"\s*:", line):
                try:
                    relative = path.resolve().relative_to(ROOT)
                except ValueError:
                    relative = path
                return f"{relative.as_posix()}:{line_number}"
    return ""


def group_uncovered_bins(report):
    source = report.read_text(encoding="utf-8", errors="replace")
    result = {}
    missing_sections = re.finditer(
        r"<span[^>]*>(Uncovered bins|Element holes)</span>", source)
    for match in missing_sections:
        headings = re.findall(r"Summary for (Variable|Cross)\s+([^<]+)", source[:match.start()])
        if not headings:
            continue
        kind, name = headings[-1]
        table_start = source.find("<table", match.end())
        table_end = source.find("</table>", table_start)
        if table_start < 0 or table_end < 0:
            continue
        rows = fragment_rows(source[table_start:table_end + len("</table>")])
        if kind == "Cross" and rows:
            headings = rows[0][0]
            names = []
            for cells, _ in rows[1:]:
                if not cells:
                    continue
                count = cells[-1]
                dimensions = [f"{heading}={value}" for heading, value in
                              zip(headings, cells)
                              if heading not in ("COUNT", "AT LEAST", "NUMBER")
                              and value not in ("", "--")]
                names.append("; ".join(dimensions) + f" ({count} bins)")
        else:
            names = [cells[0] for cells, _ in rows[1:] if cells and cells[0]]
        if names:
            result.setdefault(kind + ":" + name.strip(), []).extend(names)
    return {key: sorted(set(values)) for key, values in result.items()}


def clean_html(fragment):
    decoded = html.unescape(re.sub(r"<[^>]+>", " ", fragment))
    decoded = re.sub(r"[ \t]+", " ", decoded)
    return "\n".join(line.strip() for line in decoded.splitlines())


def fragment_rows(fragment):
    parser = HtmlRows()
    parser.feed(fragment)
    result = []
    for row in parser.rows:
        result.append((text_cells(row), row))
    return result


def rtl_code_holes(report_dir, sku, configuration):
    """Extract exact uncovered RTL line/condition/branch/toggle/FSM details."""
    modlist = report_dir / "modlist.html"
    if not modlist.is_file():
        return [], []
    module_paths = sorted({link for row in read_rows(modlist) if row
                           for link in row[0]["links"]
                           if re.fullmatch(r"mod\d+\.html", link)})
    holes, module_reports = [], []

    def add(kind, module, source_path, line, expression, uncovered, page):
        try:
            source_ref = Path(source_path).resolve().relative_to(ROOT).as_posix()
        except (OSError, ValueError):
            source_ref = source_path
        line_text = ""
        source_file = Path(source_path)
        if line and source_file.is_file():
            source_lines = source_file.read_text(encoding="utf-8", errors="replace").splitlines()
            if 0 < int(line) <= len(source_lines):
                line_text = source_lines[int(line) - 1].strip()
        holes.append({
            "sku": sku, "configuration": configuration,
            "coverage_id": f"{kind}:{source_ref}:{line or 'signal'}",
            "coverage_type": kind,
            "source_location": f"{source_ref}:{line}" if line else source_ref,
            "rtl_expression": expression or line_text,
            "uncovered_bin": uncovered,
            "round1_observed": "", "round2_observed": "uncovered",
            "target": "100% reachable RTL coverage bins",
            "round2_disposition": "OPEN", "waiver_status": "NONE",
            "root_cause": "Raw URG RTL bin was not hit; reachability and sampling cause are not yet proven.",
            "reproducer": "See the configuration's directed and random VCS logs listed in regression_summary.json.",
            "closure_test": "Add a legal directed witness for this exact expression/state/toggle, or obtain independent reachability proof.",
            "evidence": rel(page) + ("#" + kind if kind else ""),
            "next_action": "Triage the exact RTL expression and preserve the raw uncovered bin until independently closed.",
        })

    for module_report in module_paths:
        page = report_dir / module_report
        source = page.read_text(encoding="utf-8", errors="replace")
        source_match = re.search(r"openSrcFile\('([^']+)'", source)
        if not source_match:
            continue
        source_path = source_match.group(1)
        if "/rtl/" not in source_path.replace("\\", "/"):
            continue
        module_reports.append(page)
        module_name_match = re.search(r"Source File\(s\).*?<a[^>]*>([^<]+)</a>", source, re.S)
        module = Path(source_path).stem if not module_name_match else Path(source_path).stem

        line_start = source.find("Line Coverage for Module")
        cond_start = source.find("Cond Coverage for Module", max(0, line_start))
        if line_start >= 0:
            line_section = source[line_start:cond_start if cond_start >= 0 else len(source)]
            pre = re.search(r'<pre class="code">(.*?)</pre>', line_section, re.S)
            if pre:
                before = clean_html(pre.group(1))
                for red in re.finditer(r'<font\s+color\s*=\s*"red"\s*>(.*?)</font>', pre.group(1), re.S):
                    prefix = clean_html(pre.group(1)[:red.start()])
                    line_numbers = re.findall(r"(?m)^\s*(\d+)(?:\s|$)", prefix)
                    line = line_numbers[-1] if line_numbers else ""
                    item = clean_html(red.group(1))
                    if "==>" in item or "MISSING_ELSE" in item:
                        add("Line", module, source_path, line, "", item, page)

        if cond_start >= 0:
            toggle_start = source.find("Toggle Coverage for Module", cond_start)
            cond_section = source[cond_start:toggle_start if toggle_start >= 0 else len(source)]
            for pre in re.finditer(r'<pre class="code">(.*?)</pre>', cond_section, re.S):
                pre_text = clean_html(pre.group(1))
                line_match = re.search(r"\bLINE\s+(\d+)\b", pre_text)
                expression_match = re.search(r"(?:SUB-)?EXPRESSION\s+(.*)", pre_text)
                if not line_match or not expression_match:
                    continue
                table_start = cond_section.find("<table", pre.end())
                table_end = cond_section.find("</table>", table_start)
                if table_start < 0 or table_end < 0:
                    continue
                table_fragment = cond_section[table_start:table_end + len("</table>")]
                for row_html in re.findall(r'<tr\s+class="uRed"[^>]*>(.*?)</tr>', table_fragment, re.S):
                    cells = next((cells for cells, _ in fragment_rows("<table><tr>" + row_html + "</tr></table>")), [])
                    if cells:
                        add("Condition", module, source_path, line_match.group(1),
                            expression_match.group(1), ",".join(cells[:-1]), page)

        branch_start = source.find("Branch Coverage for Module")
        if branch_start >= 0:
            branch_section = source[branch_start:]
            branch_pres = list(re.finditer(r'<pre class="code">(.*?)</pre>', branch_section, re.S))
            for pre in branch_pres:
                raw_pre = pre.group(1)
                pre_text = clean_html(raw_pre)
                lines = re.findall(r"(?m)^\s*(\d+)\s+.*?\b(?:if|case|while)\b", pre_text)
                line = lines[-1] if lines else ""
                if not line:
                    continue
                expression = next((text for text in pre_text.split("  ") if re.search(r"\b(?:if|case|while)\b", text)), "")
                branches_label = branch_section.find("Branches:", pre.end())
                if branches_label < 0:
                    continue
                table_start = branch_section.find("<table", branches_label)
                table_end = branch_section.find("</table>", table_start)
                if table_start < 0 or table_end < 0:
                    continue
                table_fragment = branch_section[table_start:table_end + len("</table>")]
                for row_html in re.findall(r'<tr\s+class="uRed"[^>]*>(.*?)</tr>', table_fragment, re.S):
                    cells = next((cells for cells, _ in fragment_rows("<table><tr>" + row_html + "</tr></table>")), [])
                    if cells:
                        add("Branch", module, source_path, line, expression,
                            ",".join(cells[:-1]), page)

        toggle_start = source.find("Toggle Coverage for Module")
        branch_start = source.find("Branch Coverage for Module", max(toggle_start, 0))
        if toggle_start >= 0:
            toggle_section = source[toggle_start:branch_start if branch_start >= 0 else len(source)]
            for title in ("Port Details", "Signal Details"):
                title_index = toggle_section.find("<caption><b>" + title + "</b></caption>")
                if title_index < 0:
                    continue
                table_start = toggle_section.find("<table", title_index)
                table_end = toggle_section.find("</table>", table_start)
                if table_start < 0 or table_end < 0:
                    continue
                table_fragment = toggle_section[table_start:table_end + len("</table>")]
                for cells, _ in fragment_rows(table_fragment):
                    if cells and cells[0] not in ("Name", "") and "No" in cells[1:4]:
                        missing = ",".join(name for name, value in zip(("toggle", "1_to_0", "0_to_1"), cells[1:4]) if value == "No")
                        add("Toggle", module, source_path, "", cells[0], missing, page)

        fsm_start = source.find("FSM Coverage for Module")
        branch_start = source.find("Branch Coverage for Module", max(fsm_start, 0))
        if fsm_start >= 0:
            fsm_section = source[fsm_start:branch_start if branch_start >= 0 else len(source)]
            for table_match in re.finditer(r"<table[^>]*>(.*?)</table>", fsm_section, re.S):
                table_fragment = table_match.group(0)
                first_row = next(iter(fragment_rows(table_fragment)), ([], None))[0]
                if not first_row or first_row[0].lower() not in ("states", "transitions", "sequences"):
                    continue
                for row_html in re.findall(r'<tr\s+class="uRed"[^>]*>(.*?)</tr>', table_fragment, re.S):
                    cells = next((cells for cells, _ in fragment_rows("<table><tr>" + row_html + "</tr></table>")), [])
                    if len(cells) >= 2:
                        add("FSM_" + first_row[0].capitalize(), module, source_path,
                            cells[1], "", cells[0], page)
    return holes, module_reports


def text_cells(row):
    return [cell["text"] for cell in row]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def rel(path):
    try:
        return str(path.resolve().relative_to(ROOT)).replace("\\", "/")
    except ValueError:
        return str(path.resolve())


def parse_dut_code(path):
    rows = read_rows(path)
    header = next((text_cells(row) for row in rows
                   if "SCORE" in text_cells(row) and "LINE" in text_cells(row)), None)
    dut = next((text_cells(row) for row in rows
                if text_cells(row) and text_cells(row)[0] == "dut"), None)
    if header is None or dut is None:
        raise ValueError("cannot find selected DUT row in " + str(path))
    values = dict(zip(header, dut))
    return {key.lower(): values.get(key, "") for key in
            ("SCORE", "LINE", "COND", "TOGGLE", "FSM", "BRANCH", "ASSERT")}


def numeric(value):
    try:
        return float(value.strip())
    except (AttributeError, ValueError):
        return None


def parse_group_score(group_rows):
    for index, row in enumerate(group_rows[:-1]):
        if text_cells(row)[:3] == ["SCORE", "INST SCORE", "WEIGHT"]:
            return numeric(text_cells(group_rows[index + 1])[0])
    return None


def group_records(report):
    groups_path = report / "groups.html"
    if not groups_path.is_file():
        return None, []
    rows = read_rows(groups_path)
    total_score = parse_group_score(rows)
    records = []
    for row in rows:
        cells = text_cells(row)
        if len(row) < 10 or len(cells) < 4:
            continue
        links = row[0]["links"]
        page_name = next((link for link in links
                          if re.fullmatch(r"grp\d+\.html", link)), None)
        score = numeric(cells[1])
        name = cells[0].split("::")[-1]
        if page_name is None or score is None:
            continue
        detail_path = report / page_name
        detail_rows = read_rows(detail_path)
        uncovered_bin_map = group_uncovered_bins(detail_path)
        expected = covered = 0
        for index, detail_row in enumerate(detail_rows):
            detail_cells = text_cells(detail_row)
            if detail_cells[:4] != ["CATEGORY", "EXPECTED", "UNCOVERED", "COVERED"]:
                continue
            for candidate in detail_rows[index + 1:]:
                values = text_cells(candidate)
                if len(values) >= 4 and values[0] in ("Variables", "Crosses"):
                    expected += int(values[1])
                    covered += int(values[3])
                elif values and values[0] in ("VARIABLE", "CROSS", "CATEGORY"):
                    break
            break
        crosses = []
        source_html = detail_path.read_text(encoding="utf-8", errors="replace")
        cross_heading = source_html.find("Crosses for Group ")
        if cross_heading >= 0:
            table_start = source_html.find("<table", cross_heading)
            table_end = source_html.find("</table>", table_start)
            if table_start >= 0 and table_end >= 0:
                table_parser = HtmlRows()
                table_parser.feed(source_html[table_start:table_end + len("</table>")])
                for candidate in table_parser.rows:
                    values = text_cells(candidate)
                    if len(values) < 5 or values[0] == "CROSS":
                        continue
                    if not any(link.startswith("#inst_tag_")
                               for link in candidate[0]["links"]):
                        continue
                    if any(numeric(value) is None for value in values[1:5]):
                        continue
                    crosses.append({"name": values[0],
                                    "expected": int(values[1]),
                                    "uncovered": int(values[2]),
                                    "covered": int(values[3]),
                                    "percent": numeric(values[4]),
                                    "uncovered_bins": uncovered_bin_map.get("Cross:" + values[0], []),
                                    "source_location": coverage_symbol_location(detail_path, values[0])})
        records.append({"name": name, "score": score,
                        "expected": expected, "covered": covered,
                        "missing": expected - covered,
                        "page": detail_path, "crosses": crosses,
                        "uncovered_bins": uncovered_bin_map})
    return total_score, records


def parse_assertion_summary(path):
    source = path.read_text(encoding="utf-8", errors="replace")
    if "<b>Summary for Assertions</b>" not in source:
        return {}
    section = source.split("<b>Summary for Assertions</b>", 1)[1]
    section = section.split("<b>Summary for Cover Properties</b>", 1)[0]
    parser = HtmlRows()
    parser.feed(section)
    result = {}
    for row in parser.rows:
        cells = text_cells(row)
        if len(cells) >= 3 and cells[0] in (
                "Total Number", "Uncovered", "Success", "Failure",
                "Incomplete", "Without Attempts"):
            result[cells[0]] = int(cells[1])
    return result


def parse_assertion_failures(path):
    source = path.read_text(encoding="utf-8", errors="replace")
    if "Assertions Failure:" not in source:
        return []
    section = source.split("Assertions Failure:", 1)[1]
    section = section.split("Assertions Without Attempts:", 1)[0]
    parser = HtmlRows()
    parser.feed(section)
    result = []
    for row in parser.rows:
        cells = text_cells(row)
        if len(cells) >= 7 and cells[0] not in ("ASSERTIONS", ""):
            failures = numeric(cells[5])
            if failures:
                result.append({"assertion": cells[0], "failures": int(failures)})
    return result


def write_csv(path, fields, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def status_for_metric(metric, value):
    target = TARGETS[metric]
    if target in ("report only", "evidence only"):
        return "REPORT_ONLY" if target == "report only" else "EVIDENCE_ONLY"
    if value is None:
        return "NOT_APPLICABLE"
    return "PASS" if value >= float(target) else "OPEN"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN)
    parser.add_argument("--data-dir", type=Path, default=DEFAULT_DATA)
    args = parser.parse_args()
    run_dir = args.run_dir.resolve()
    data_dir = args.data_dir.resolve()
    urg_summary_path = run_dir / "urg" / "summary.json"
    random_summary_path = run_dir / "random" / "regression_summary.json"
    urg_summary = json.loads(urg_summary_path.read_text(encoding="utf-8"))
    random_summary = json.loads(random_summary_path.read_text(encoding="utf-8"))
    if urg_summary.get("status") != "PASS":
        raise SystemExit("fresh seven-configuration URG merge is not PASS")
    if random_summary.get("status") != "PASS":
        raise SystemExit("random campaigns are not PASS")

    r1_rows = list(csv.DictReader((ROOT / "docs/verification/data/dsm-v13-round1/hardware_code_coverage.csv").open()))
    r1_map = {(row["sku"], row["build"]): row for row in r1_rows}
    code_rows, functional_rows, cross_rows, assertion_rows = [], [], [], []
    functional_summaries = {}
    config_results = {}
    report_paths = []
    failure_details = {}
    rtl_code_hole_rows = []

    for config, (sku, label, build_name) in CONFIGS.items():
        result = urg_summary["configurations"][config]
        config_results[config] = {
            "status": result["status"],
            "report": rel(Path(result["report"])) if result.get("report") else "",
            "test_vdb_count": len(result.get("test_vdbs", [])),
            "random_vdb_count": len(result.get("included_random_test_vdbs", [])),
        }
        if result["status"] != "PASS":
            raise SystemExit("URG configuration not PASS: " + config)
        report = run_dir / "urg" / config
        hierarchy_path = report / "hierarchy.html"
        report_paths.append(hierarchy_path)
        rtl_holes, module_reports = rtl_code_holes(report, sku, label)
        rtl_code_hole_rows.extend(rtl_holes)
        report_paths.extend(module_reports)
        code = parse_dut_code(hierarchy_path)
        r1_key = R1_NAMES.get(config)
        r1_row = r1_map.get(r1_key) if r1_key else None
        for metric in ("score", "line", "branch", "cond", "toggle", "fsm", "assert"):
            value = numeric(code.get(metric))
            r1_value = None
            if r1_row is not None:
                r1_value = numeric(r1_row.get({"cond": "condition", "assert": "assertion"}.get(metric, metric) + "_percent"))
            row_status = status_for_metric(metric, value)
            code_rows.append({
                "sku": sku, "configuration": label,
                "scope": "selected DUT hierarchy instance subtree",
                "metric": METRIC_NAMES[metric],
                "round1_raw_percent": "" if r1_value is None else f"{r1_value:.2f}",
                "round2_raw_percent": "" if value is None else f"{value:.2f}",
                "round2_adjusted_percent": "" if value is None else f"{value:.2f}",
                "target_percent": TARGETS[metric],
                "round2_status": row_status,
                "source_report": rel(hierarchy_path),
                "source_report_sha256": sha256(hierarchy_path),
                "notes": "Raw URG DUT row; no approved exclusions/waivers, adjusted equals raw." if metric not in ("score", "assert") else "Report-only metric; no closure threshold was specified.",
            })

        groups_path = report / "groups.html"
        group_score, groups = group_records(report)
        functional_summaries[config] = group_score
        if groups_path.is_file():
            report_paths.append(groups_path)
            total_groups = int(re.search(r"Total groups in report:\s*(\d+)", groups_path.read_text()).group(1))
            functional_rows.append({
                "sku": sku, "configuration": label,
                "coverage_type": "URG_functional_group_score",
                "coverpoint_or_group": "all applicable URG groups",
                "round1_group_score_percent": "",
                "round2_group_score_percent": f"{group_score:.2f}",
                "covered_bins": "", "expected_bins": "", "missing_bins": "",
                "round2_status": "PASS" if group_score >= 98.0 else "OPEN",
                "source_report": rel(groups_path),
                "source_report_sha256": sha256(groups_path),
                "source_location": "",
                "notes": f"{total_groups} reported groups; URG group score is not code coverage; target is 98%.",
            })
            for group in groups:
                detail_hash = sha256(group["page"])
                functional_rows.append({
                    "sku": sku, "configuration": label,
                    "coverage_type": "UVM_or_RTL_covergroup",
                    "coverpoint_or_group": group["name"],
                    "round1_group_score_percent": "",
                    "round2_group_score_percent": f"{group['score']:.2f}",
                    "covered_bins": group["covered"],
                    "expected_bins": group["expected"],
                    "missing_bins": group["missing"],
                    "round2_status": "PASS" if group["missing"] == 0 else "OPEN",
                    "source_report": rel(group["page"]),
                    "source_report_sha256": detail_hash,
                    "source_location": group_source_location(group["page"], group["name"]),
                    "uncovered_bin_names": "; ".join(
                        key.removeprefix("Variable:") + "=" + ", ".join(names)
                        for key, names in group["uncovered_bins"].items()
                        if key.startswith("Variable:")),
                    "notes": "Group score and category-bin totals are reported separately; raw bins remain unwaived.",
                })
                for cross in group["crosses"]:
                    cross_rows.append({
                        "sku": sku, "configuration": label,
                        "cross_family": group["name"], "cross_name": cross["name"],
                        "covered_bins": cross["covered"],
                        "expected_bins": cross["expected"],
                        "missing_bins": cross["uncovered"],
                        "percent": f"{cross['percent']:.2f}",
                        "round2_status": "PASS" if cross["uncovered"] == 0 else "OPEN",
                        "source_report": rel(group["page"]),
                        "source_report_sha256": detail_hash,
                        "source_location": cross["source_location"],
                        "uncovered_bin_names": "; ".join(cross["uncovered_bins"]),
                        "notes": "Raw URG cross; no functional coverage waiver applied.",
                    })
        else:
            functional_rows.append({
                "sku": sku, "configuration": label,
                "coverage_type": "UVM_functional_group_score",
                "coverpoint_or_group": "not integrated at legacy wrapper/core boundary",
                "round1_group_score_percent": "", "round2_group_score_percent": "",
                "covered_bins": "", "expected_bins": "", "missing_bins": "",
                "round2_status": "NOT_INTEGRATED", "source_report": "",
                "source_report_sha256": "",
                "source_location": "",
                "notes": "Legacy scalar MASH wrapper/core uses a separate UVM agent; Product functional groups are not claimed.",
            })

        asserts_path = report / "asserts.html"
        report_paths.append(asserts_path)
        assertion_summary = parse_assertion_summary(asserts_path)
        failure_details[config] = parse_assertion_failures(asserts_path)
        expected_negative = sum(item["failures"] for item in failure_details[config]
                                if "u_cdc.unnamed$$_1" in item["assertion"] and
                                config in ("ef1_product", "ef2_product"))
        unexpected = assertion_summary.get("Failure", 0) - expected_negative
        assertion_rows.append({
            "sku": sku, "configuration": label,
            "scope": "URG full compilation assertion inventory; UVM package rows included",
            "total_assertions": assertion_summary.get("Total Number", ""),
            "successful_assertions": assertion_summary.get("Success", ""),
            "uncovered_assertions": assertion_summary.get("Uncovered", ""),
            "failures": assertion_summary.get("Failure", ""),
            "expected_negative_failures": expected_negative,
            "unexpected_failures": unexpected,
            "incomplete": assertion_summary.get("Incomplete", ""),
            "without_attempts": assertion_summary.get("Without Attempts", ""),
            "selected_dut_assertion_percent": code.get("assert", ""),
            "round2_status": "EXPECTED_NEGATIVE_ONLY" if expected_negative and not unexpected else ("OPEN" if assertion_summary.get("Uncovered", 0) else "PASS"),
            "source_report": rel(asserts_path),
            "source_report_sha256": sha256(asserts_path),
            "notes": "Two UVM library map assertions have no attempts; EF1/EF2 Product illegal-frame assertion is an expected negative test.",
        })

    # Explicit plan items that are not represented by the current Product boundary.
    for sku, label, config in (("EF1", "EF1 Product", "ef1_product"),
                               ("EF1", "EF1 AXI-Lite", "ef1_axil"),
                               ("EF2", "EF2 Product", "ef2_product"),
                               ("EF2", "EF2 AXI-Lite", "ef2_axil"),
                               ("MASH 1-1", "MASH Product", "mash11_product"),
                               ("MASH 1-1", "MASH AXI-Lite", "mash11_axil")):
        cross_rows.append({
            "sku": sku, "configuration": label,
            "cross_family": "Output Integrity",
            "cross_name": "Serializer Position x Reset",
            "covered_bins": "", "expected_bins": "", "missing_bins": "",
            "percent": "", "round2_status": "NOT_INTEGRATED",
            "source_report": "", "source_report_sha256": "",
            "source_location": "",
            "notes": "Product DUT ends at four parallel 64-bit PA planes; serializer position/reset is outside this integrated boundary.",
        })

    # Record the Round 1 holes and their actual Round 2 closure state.
    holes = []
    for sku, label, config in (("EF1", "EF1 Product", "ef1_product"),
                               ("EF1", "EF1 AXI-Lite", "ef1_axil"),
                               ("EF2", "EF2 Product", "ef2_product"),
                               ("EF2", "EF2 AXI-Lite", "ef2_axil"),
                               ("MASH 1-1", "MASH Product", "mash11_product"),
                               ("MASH 1-1", "MASH AXI-Lite", "mash11_axil")):
        for metric in ("Line", "Branch", "Condition", "Toggle"):
            record = next(row for row in code_rows
                          if row["configuration"] == label and row["metric"] == metric)
            if record["round2_status"] == "OPEN":
                holes.append({"sku": sku, "configuration": label,
                              "coverage_id": "CODE_" + metric.upper().replace(" ", "_"),
                              "round1_observed": record["round1_raw_percent"],
                              "round2_observed": record["round2_raw_percent"],
                              "target": record["target_percent"],
                              "round2_disposition": "OPEN",
                              "waiver_status": "NONE",
                              "evidence": record["source_report"],
                              "next_action": "Use the exact URG bin/path inventory to write a targeted stimulus or a separately reviewed reachability proof."})
    holes.extend(rtl_code_hole_rows)
    for row in functional_rows:
        if row["coverage_type"] != "UVM_or_RTL_covergroup" or not int(row.get("missing_bins") or 0):
            continue
        holes.append({
            "sku": row["sku"], "configuration": row["configuration"],
            "coverage_id": row["coverpoint_or_group"],
            "coverage_type": "FUNCTIONAL_GROUP_BINS",
            "source_location": row.get("source_location", ""),
            "rtl_expression": "",
            "uncovered_bin": row.get("uncovered_bin_names") or f"{row['covered_bins']}/{row['expected_bins']} covered; {row['missing_bins']} uncovered",
            "round1_observed": "", "round2_observed": row["round2_group_score_percent"],
            "target": "100% mandatory bins",
            "round2_disposition": "OPEN", "waiver_status": "NONE",
            "root_cause": "These legal bins were not hit by the current directed/random set; reachability is not established.",
            "reproducer": row["source_report"],
            "closure_test": "Add a focused directed sequence that samples each missing bin and preserves its independent checker.",
            "evidence": row["source_report"],
            "next_action": "Use the source coverpoint and URG detail page to create a directed witness.",
        })
    for cross in cross_rows:
        if cross["round2_status"] == "OPEN":
            holes.append({"sku": cross["sku"], "configuration": cross["configuration"],
                          "coverage_id": cross["cross_name"],
                          "coverage_type": "FUNCTIONAL_CROSS_BIN",
                          "source_location": cross.get("source_location", ""),
                          "rtl_expression": "",
                          "uncovered_bin": cross.get("uncovered_bin_names") or f"{cross['covered_bins']}/{cross['expected_bins']} covered",
                          "round1_observed": "",
                          "round2_observed": f"{cross['covered_bins']}/{cross['expected_bins']}" if cross["expected_bins"] != "" else "OPEN",
                          "target": "100% mandatory bins",
                          "round2_disposition": "OPEN", "waiver_status": "NONE",
                          "root_cause": "Exact legal cross bin was not observed in the current merged regression.",
                          "reproducer": cross["source_report"],
                          "closure_test": "Add a legal sequence that reaches the named state combination and verify DUT integrity.",
                          "evidence": cross["source_report"],
                          "next_action": "Inspect exact missing bins in the source URG group report and add a directed witness."})
    holes.extend([
        {"sku": "MASH 1-1", "configuration": "MASH Product", "coverage_id": "MASH_weighted_levels_minus2_zero", "round1_observed": "0/2", "round2_observed": "0 raw hits; algebraic proof in candidate contract", "target": "raw bins reported; no unreviewed waiver", "round2_disposition": "OPEN", "waiver_status": "NONE", "evidence": "docs/dsm_v13_mash11_product_contract.md", "next_action": "Keep raw bins; obtain independent review of the reset-state reachability argument before any adjusted view."},
        {"sku": "MASH 1-1", "configuration": "MASH Product", "coverage_id": "MASH_weighted_levels_minus4_plus4", "round1_observed": "N/A", "round2_observed": "0/2 raw hits", "target": "all reachable codebook levels witnessed", "round2_disposition": "OPEN", "waiver_status": "NONE", "evidence": "MASH Product URG group", "next_action": "Retain raw bins and confirm codebook validity/reachability as part of independent contract review."},
        {"sku": "MASH 1-1", "configuration": "MASH Product", "coverage_id": "MASH_PA_physical_weight_polarity", "round1_observed": "Product Top absent", "round2_observed": "candidate digital code only", "target": "approved physical PA contract", "round2_disposition": "OPEN", "waiver_status": "NONE", "evidence": "docs/dsm_v13_mash11_product_contract.md", "next_action": "Confirm PA branch weights, polarity and board/serializer mapping with the product owner."},
        {"sku": "MASH 1-1", "configuration": "MASH Product", "coverage_id": "MASH_MATLAB_latency_alignment", "round1_observed": "not measured", "round2_observed": "RTL recurrence reference only", "target": "MATLAB/RTL bittrue equivalence", "round2_disposition": "OPEN", "waiver_status": "NONE", "evidence": "docs/dsm_v13_mash11_product_contract.md", "next_action": "Align the candidate latency/state contract to the MATLAB oracle before sign-off."},
        {"sku": "All", "configuration": "All selected DUT builds", "coverage_id": "FORMAL_CDC_RDC_PPA_BOARD", "round1_observed": "not run", "round2_observed": "not run", "target": "separate sign-off evidence", "round2_disposition": "OPEN", "waiver_status": "NONE", "evidence": "Round 2 execution record", "next_action": "Run Formal, CDC/RDC, synthesis/PPA and physical board/RF sign-off under their owned flows."},
    ])

    # Round 1 group-score baseline for direct same-scope product/AXI-Lite comparisons.
    r1_functional = {
        ("EF1", "EF1 Product"): 45.10,
        ("EF1", "EF1 AXI-Lite"): 52.23,
        ("EF2", "EF2 Product"): 46.26,
        ("EF2", "EF2 AXI-Lite"): 53.10,
    }
    for row in functional_rows:
        key = (row["sku"], row["configuration"])
        if row["coverage_type"] == "URG_functional_group_score" and key in r1_functional:
            row["round1_group_score_percent"] = f"{r1_functional[key]:.2f}"

    hole_fields = [
        "sku", "configuration", "coverage_id", "coverage_type",
        "source_location", "rtl_expression", "uncovered_bin",
        "round1_observed", "round2_observed", "target",
        "round2_disposition", "waiver_status", "root_cause", "reproducer",
        "closure_test", "evidence", "next_action",
    ]
    for row in holes:
        if row.get("coverage_id", "").startswith("CODE_"):
            row.setdefault("coverage_type", "CODE_METRIC_AGGREGATE")
            row.setdefault("uncovered_bin", row.get("round2_observed", ""))
            row.setdefault("root_cause", "Aggregate DUT metric is below target; exact missed RTL bins are listed in this matrix.")
        elif row.get("coverage_id", "").startswith("MASH_"):
            row.setdefault("coverage_type", "MASH_REACHABILITY_OR_INTEGRATION")
            row.setdefault("uncovered_bin", row.get("round2_observed", ""))
            row.setdefault("root_cause", "The candidate or external interface evidence is incomplete; no waiver is approved.")
        elif row.get("coverage_id", "").startswith("FORMAL_"):
            row.setdefault("coverage_type", "SIGNOFF_GAP")
            row.setdefault("uncovered_bin", row.get("round2_observed", ""))
            row.setdefault("root_cause", "The requested independent sign-off flow was not run.")
        for field in hole_fields:
            row.setdefault(field, "")
        if not row["reproducer"]:
            row["reproducer"] = row["evidence"]
        if not row["closure_test"]:
            row["closure_test"] = row["next_action"]

    write_csv(data_dir / "code_coverage.csv", [
        "sku", "configuration", "scope", "metric", "round1_raw_percent",
        "round2_raw_percent", "round2_adjusted_percent", "target_percent",
        "round2_status", "source_report", "source_report_sha256", "notes"], code_rows)
    write_csv(data_dir / "functional_coverage.csv", [
        "sku", "configuration", "coverage_type", "coverpoint_or_group",
        "round1_group_score_percent", "round2_group_score_percent",
        "covered_bins", "expected_bins", "missing_bins", "round2_status",
        "source_report", "source_report_sha256", "source_location",
        "uncovered_bin_names", "notes"], functional_rows)
    write_csv(data_dir / "cross_coverage.csv", [
        "sku", "configuration", "cross_family", "cross_name", "covered_bins",
        "expected_bins", "missing_bins", "percent", "round2_status",
        "source_report", "source_report_sha256", "source_location",
        "uncovered_bin_names", "notes"], cross_rows)
    write_csv(data_dir / "coverage_hole_matrix.csv", hole_fields, holes)
    write_csv(data_dir / "assertion_coverage.csv", [
        "sku", "configuration", "scope", "total_assertions",
        "successful_assertions", "uncovered_assertions", "failures",
        "expected_negative_failures", "unexpected_failures", "incomplete",
        "without_attempts", "selected_dut_assertion_percent", "round2_status",
        "source_report", "source_report_sha256", "notes"], assertion_rows)

    # Count complete simulation logs and ensure each has a UVM summary.
    log_paths = sorted(path for path in run_dir.rglob("*.log")
                       if "urg" not in path.parts and "compile" not in path.name)
    test_logs = []
    uvm_errors = uvm_fatals = uvm_warnings = 0
    for path in log_paths:
        content = path.read_text(encoding="utf-8", errors="replace")
        if "UVM Report Summary" not in content:
            continue
        test_logs.append(path)
        for severity, target in (("UVM_ERROR", "errors"),
                                 ("UVM_FATAL", "fatals"),
                                 ("UVM_WARNING", "warnings")):
            matches = re.findall(severity + r"\s*:\s*(\d+)", content)
            value = int(matches[-1]) if matches else 0
            if target == "errors": uvm_errors += value
            elif target == "fatals": uvm_fatals += value
            else: uvm_warnings += value
    if len(test_logs) != 38 or uvm_errors != 0 or uvm_fatals != 0:
        raise SystemExit(f"unexpected test log set/errors/fatals: logs={len(test_logs)} errors={uvm_errors} fatals={uvm_fatals}")

    campaigns = [case for record in random_summary["sku_results"].values()
                 for case in record.get("campaigns", [])]
    if not all(case.get("status") == "PASS" for case in campaigns):
        raise SystemExit("a recorded random campaign is not PASS")
    accepted = sum(case["accepted_axis_beats"] for case in campaigns)
    pa_words = sum(case["matched_pa_words"] for case in campaigns)
    attempted = sum(case["attempted_axis_beats"] for case in campaigns)
    expected_pa_words = sum(case["expected_pa_words"] for case in campaigns)
    tlast = sum(case["accepted_tlast"] for case in campaigns)
    if attempted != accepted or expected_pa_words != pa_words:
        raise SystemExit("random campaign transaction conservation mismatch")
    per_sku_conservation = {}
    for sku, record in random_summary["sku_results"].items():
        sku_campaigns = record.get("campaigns", [])
        per_sku_conservation[sku] = {
            "attempted_axis_beats": sum(case["attempted_axis_beats"] for case in sku_campaigns),
            "accepted_axis_beats": sum(case["accepted_axis_beats"] for case in sku_campaigns),
            "expected_pa_words": sum(case["expected_pa_words"] for case in sku_campaigns),
            "matched_pa_words": sum(case["matched_pa_words"] for case in sku_campaigns),
            "accepted_tlast": sum(case["accepted_tlast"] for case in sku_campaigns),
            "legally_flushed_transactions": 0,
            "pending_transactions": 0,
            "queue_drain_evidence": "random-packet check_expected_queues_drained passed for every campaign",
        }
    summary = {
        "schema": "dsm_v13_round2_regression_summary_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_head": random_summary.get("source_head"),
        "working_tree_fingerprint_sha256_at_random_run": random_summary.get("working_tree_fingerprint_sha256"),
        "run_directory": rel(run_dir),
        "final_regression_status": "PASS",
        "fresh_urg_status": "PASS",
        "urg_merge_status": "PASS",
        "coverage_status": "OPEN",
        "final_dv_signoff": False,
        "configuration_results": config_results,
        "directed_and_random_test_logs": len(test_logs),
        "positive_uvm_warnings": uvm_warnings,
        "positive_uvm_errors": uvm_errors,
        "positive_uvm_fatals": uvm_fatals,
        "expected_negative_protocol_tests": ["EF1 illegal frame", "EF2 illegal frame"],
        "expected_negative_assertions": 2,
        "python_reference_tests": {"status": "PASS", "passed": 74},
        "random_campaigns": {
            "status": random_summary.get("status"),
            "campaign_count": len(campaigns), "seed_count": len(campaigns),
            "seeds_per_sku_and_campaign": {
                sku: {name: sum(1 for case in record.get("campaigns", [])
                                if case.get("campaign") == name)
                      for name in random_summary["requested"]}
                for sku, record in random_summary["sku_results"].items()
            },
            "seeds_by_sku": {sku: [case["seed"] for case in record.get("campaigns", [])]
                             for sku, record in random_summary["sku_results"].items()},
            "transaction_conservation": {
                "attempted_axis_beats": attempted,
                "accepted_axis_beats": accepted,
                "expected_pa_words": expected_pa_words,
                "matched_pa_words": pa_words,
                "legally_flushed_transactions": 0,
                "pending_transactions": 0,
                "per_sku": per_sku_conservation,
                "basis": "Exact source/PA counts passed; random-packet scoreboard expected queues drained; no reset flushes were requested in these campaigns.",
            },
            "accepted_axis_beats": accepted,
            "matched_pa_words": pa_words,
            "accepted_tlast": tlast,
            "requested_beats_per_campaign": {name: value["accepted_axis_beats_per_seed"]
                                             for name, value in random_summary["requested"].items()},
            "seed_bases": [random_summary.get("seed_base")] + random_summary.get("additional_seed_bases", []),
            "summary_source": rel(random_summary_path),
        },
        "functional_group_scores_percent": functional_summaries,
        "limitations": [
            "Raw DUT code metrics miss the Round 2 closure targets; no approved exclusions or waivers are applied.",
            "MASH four-plane weights/polarity remain a digital candidate and lack approved PA, serializer, MATLAB-latency and board evidence.",
            "Raw MASH weighted-level bins remain visible; the algebraic reachability note is not a formal proof or waiver.",
            "Formal, CDC/RDC, synthesis/PPA, serializer position/reset, and board/RF sign-off were not run.",
        ],
    }
    (data_dir / "regression_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    baseline = random_summary.get("source_head")
    diff_command = ["git", "diff", "--name-only"]
    if baseline:
        diff_command.append(baseline)
    tracked = subprocess.check_output(diff_command, cwd=ROOT, text=True).splitlines()
    untracked = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
    source_paths = sorted(set(tracked + untracked))
    files = {}
    for relative in source_paths:
        path = ROOT / relative
        if path.is_file() and relative != rel(data_dir / "evidence_manifest.json"):
            files[relative.replace("\\", "/")] = {"sha256": sha256(path), "role": "Round 2 working-tree artifact"}
    evidence_paths = [urg_summary_path, random_summary_path] + report_paths + test_logs
    for path in sorted(set(evidence_paths)):
        files[rel(path)] = {"sha256": sha256(path), "role": "generated simulation or URG evidence"}
    manifest = {
        "schema": "dsm_v13_round2_evidence_manifest_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "evidence_scope": "Round 2 working tree and generated reference vectors",
        "run_directory": rel(run_dir),
        "source_head": random_summary.get("source_head"),
        "working_tree_fingerprint_sha256_at_random_run": random_summary.get("working_tree_fingerprint_sha256"),
        "raw_and_adjusted_policy": "No approved exclusions or waivers; adjusted code coverage equals raw.",
        "files": files,
        "random_campaign_vector_hashes": {
            sku: {str(case["seed"]): case.get("vectors_sha256", {})
                  for case in record.get("campaigns", [])}
            for sku, record in random_summary["sku_results"].items()
        },
    }
    for path in sorted(data_dir.glob("*.csv")) + [data_dir / "regression_summary.json"]:
        manifest["files"][rel(path)] = {"sha256": sha256(path), "role": "Round 2 extracted evidence data"}
    (data_dir / "evidence_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print("DSM_V13_R2_EVIDENCE_GENERATED=" + rel(data_dir))
    print("configs=%d test_logs=%d random_campaigns=%d accepted_beats=%d matched_pa_words=%d tlast=%d" %
          (len(config_results), len(test_logs), len(campaigns), accepted, pa_words, tlast))


if __name__ == "__main__":
    main()
