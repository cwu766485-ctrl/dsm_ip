#!/usr/bin/env python3.12
"""Export every product Functional Coverage bin from a fixed URG HTML report.

The exporter retains both covergroup-type and instance views, marks the URG
model's already-excluded/illegal bins explicitly, and cross-checks all
scoreable records against the fixed product totals. It applies only the
reviewed malformed-frame applicability labels; it does not infer applicability
from hit counts or edit URG data.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import html
import re
from pathlib import Path


GROUP_LINK = re.compile(
    r'href=["\'](grp\d+\.html)["\'][^>]*>\s*([^<]+)', re.IGNORECASE
)
NAMED_SECTION = re.compile(r"<div\s+name=['\"]([^'\"]+)['\"]\s*>", re.I)
BIN_POINT = re.compile(
    r"<span\s+class=['\"]?repname['\"]?\s*>\s*(User Defined Bins for|Automatically Generated Cross Bins for)\s+([^<]+)</span>",
    re.I,
)
BUCKET = re.compile(
    r"<span\s+class=['\"]?repname['\"]?\s*>(Bins|Covered bins|Uncovered bins|Excluded/Illegal bins)</span>"
    r".*?<table\b[^>]*>(.*?)</table>",
    re.I | re.S,
)
ROW = re.compile(r"<tr\b[^>]*>(.*?)</tr>", re.I | re.S)
CELL = re.compile(r"<t[dh]\b[^>]*>(.*?)</t[dh]>", re.I | re.S)
GROUP_SUMMARY = re.compile(r"Summary for Group(?: Instance)?\s+([^<]+)", re.I)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def cell_text(value: str) -> str:
    value = re.sub(r"<[^>]+>", " ", value)
    return " ".join(html.unescape(value).split())


def parse_table_rows(table_html: str) -> tuple[list[str], list[dict[str, str]]]:
    parsed = [[cell_text(cell) for cell in CELL.findall(row)] for row in ROW.findall(table_html)]
    parsed = [row for row in parsed if row]
    if not parsed:
        return [], []
    headers = [header.strip().upper() for header in parsed[0]]
    records = []
    for values in parsed[1:]:
        if len(values) != len(headers):
            raise ValueError(f"URG table row has {len(values)} values for {len(headers)} headers")
        records.append(dict(zip(headers, values)))
    return headers, records


def parse_group_summaries(source: str, path: Path) -> dict[str, tuple[int, int, int]]:
    summaries: dict[str, tuple[int, int, int]] = {}
    for match in GROUP_SUMMARY.finditer(source):
        scope = " ".join(match.group(1).split())
        table_start = source.find("<table", match.end())
        table_end = source.find("</table>", table_start)
        if table_start < 0 or table_end < 0:
            raise ValueError(f"missing Group summary table for {scope} in {path}")
        _, records = parse_table_rows(source[table_start:table_end + len("</table>")])
        expected = sum(int(row["EXPECTED"]) for row in records)
        uncovered = sum(int(row["UNCOVERED"]) for row in records)
        covered = sum(int(row["COVERED"]) for row in records)
        if expected != covered + uncovered or scope in summaries:
            raise ValueError(f"duplicate or inconsistent Group summary for {scope} in {path}")
        summaries[scope] = (covered, expected, uncovered)
    return summaries


def parse_group_page(path: Path, type_scope: str, negative: dict[str, int],
                     product_sha: str) -> list[dict[str, str]]:
    source = path.read_text(encoding="utf-8", errors="replace")
    sections = list(NAMED_SECTION.finditer(source))
    if not sections:
        raise ValueError(f"no named covergroup sections in {path}")
    summaries = parse_group_summaries(source, path)
    if type_scope not in summaries:
        raise ValueError(f"missing type Group summary for {type_scope} in {path}")
    digest = sha256(path)
    rows: list[dict[str, str]] = []
    for index, section in enumerate(sections):
        scope = section.group(1)
        section_end = sections[index + 1].start() if index + 1 < len(sections) else len(source)
        body = source[section.end():section_end]
        if not BIN_POINT.search(body):
            continue
        section_rows: list[dict[str, str]] = []
        points = list(BIN_POINT.finditer(body))
        for point_index, point in enumerate(points):
            point_end = points[point_index + 1].start() if point_index + 1 < len(points) else len(body)
            chunk = body[point.end():point_end]
            for bucket_match in BUCKET.finditer(chunk):
                bucket = bucket_match.group(1)
                headers, bins = parse_table_rows(bucket_match.group(2))
                point_kind = "cross" if point.group(1).lower().startswith("automatically") else "coverpoint"
                point_name = point.group(2).strip()
                for item in bins:
                    if point_kind == "cross":
                        axes = [header for header in headers if header not in {"COUNT", "AT LEAST", "NUMBER", "STATUS"}]
                        name = "&".join(f"{axis.lower()}={item[axis]}" for axis in axes)
                    else:
                        name = item.get("NAME", "")
                    if not name:
                        continue
                    count = int(item.get("COUNT", "0"))
                    minimum = int(item.get("AT LEAST", "1")) if "AT LEAST" in headers else 1
                    excluded = bucket.lower() == "excluded/illegal bins" or item.get("STATUS", "").lower() == "excluded"
                    semantic_key = f"{scope}.{point_name}.{name}"
                    if excluded:
                        legal = "URG_MODEL_ILLEGAL_OR_EXCLUDED"
                    elif point_kind == "coverpoint" and point_name == "cp_packet_quanta" and name == "malformed_early":
                        legal = "ILLEGAL_TEST_ONLY"
                    elif point_kind == "coverpoint" and point_name == "cp_illegal" and name == "bad_frame":
                        legal = "ILLEGAL_TEST_ONLY"
                    else:
                        legal = "LEGAL_PRODUCT"
                    row = {
                        "product_source_sha": product_sha,
                        "urg_report_group": path.name,
                        "urg_report_group_sha256": digest,
                        "report_scope": "covergroup_type" if scope == type_scope else "monitor_instance",
                        "urg_scope": scope,
                        "group": scope.rsplit("::", 1)[-1].split(".")[-1],
                        "point_kind": point_kind,
                        "coverpoint": point_name,
                        "bin": name,
                        "raw_hits": str(count),
                        "at_least": str(minimum),
                        "urg_bucket": bucket,
                        "raw_status": "EXCLUDED_BY_URG_MODEL" if excluded else ("COVERED" if count >= minimum else "UNCOVERED"),
                        "raw_denominator_applicable": "false" if excluded else "true",
                        "legal_applicability": legal,
                        "separate_negative_report_hits": str(negative.get(semantic_key, 0)),
                    }
                    rows.append(row)
                    section_rows.append(row)
    for scope, (expected_covered, expected_total, expected_uncovered) in summaries.items():
        scoreable = [row for row in rows if row["urg_scope"] == scope and row["raw_denominator_applicable"] == "true"]
        covered = sum(row["raw_status"] == "COVERED" for row in scoreable)
        uncovered = sum(row["raw_status"] == "UNCOVERED" for row in scoreable)
        if (covered, len(scoreable), uncovered) != (expected_covered, expected_total, expected_uncovered):
            raise ValueError(
                f"bin detail differs from URG Group summary for {scope}: "
                f"bins={(covered, len(scoreable), uncovered)} "
                f"summary={(expected_covered, expected_total, expected_uncovered)}"
            )
    if not rows:
        raise ValueError(f"no functional bins parsed from {path}")
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--raw-report", type=Path, required=True)
    parser.add_argument("--negative-audit", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--product-source-sha", required=True,
                        help="full Git SHA of the product RTL/DV inputs used for the VCS database")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-fA-F]{40}", args.product_source_sha):
        parser.error("--product-source-sha must be a full 40-character Git SHA")
    raw = args.raw_report.resolve()
    if not (raw / "groups.html").is_file():
        parser.error("--raw-report must point at a URG report containing groups.html")

    negative: dict[str, int] = {}
    with args.negative_audit.open(encoding="utf-8", newline="") as stream:
        for item in csv.DictReader(stream):
            negative[item["urg_scope"]] = int(item["negative_report_hits"])

    group_html = (raw / "groups.html").read_text(encoding="utf-8", errors="replace")
    group_links = GROUP_LINK.findall(group_html)
    if len(group_links) != 8:
        raise ValueError(f"expected eight product functional groups, found {len(group_links)}")
    all_rows: list[dict[str, str]] = []
    for filename, type_scope in group_links:
        all_rows.extend(parse_group_page(raw / filename, type_scope.strip(), negative,
                                         args.product_source_sha.lower()))

    scoreable = [row for row in all_rows if row["raw_denominator_applicable"] == "true"]
    hit = [row for row in scoreable if row["raw_status"] == "COVERED"]
    miss = [row for row in scoreable if row["raw_status"] == "UNCOVERED"]
    expected_missing = {
        "thermo5_sku_uvm_pkg::thermo5_sku_coverage::source_cg.cp_packet_quanta.malformed_early",
        "thermo5_sku_uvm_tb.me.obj.source_cg.cp_packet_quanta.malformed_early",
        "thermo5_sku_uvm_pkg::thermo5_sku_coverage::core_cg.cp_illegal.bad_frame",
        "thermo5_sku_uvm_tb.me.obj.core_cg.cp_illegal.bad_frame",
    }
    observed_missing = {f"{row['urg_scope']}.{row['coverpoint']}.{row['bin']}" for row in miss}
    if (len(scoreable), len(hit), len(miss)) != (214, 210, 4):
        raise ValueError(f"URG totals mismatch: scoreable={len(scoreable)}, covered={len(hit)}, uncovered={len(miss)}")
    if observed_missing != expected_missing:
        raise ValueError(f"unexpected uncovered functional bins: {sorted(observed_missing)}")
    if len({(row["urg_scope"], row["coverpoint"], row["bin"]) for row in all_rows}) != len(all_rows):
        raise ValueError("duplicate functional bin rows were parsed")

    fields = list(all_rows[0])
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(sorted(all_rows, key=lambda row: (row["group"], row["report_scope"], row["coverpoint"], row["bin"])))
    print(f"functional_rows={len(all_rows)} scoreable={len(scoreable)} covered={len(hit)} uncovered={len(miss)}")
    print(f"excluded_by_urg_model={len(all_rows) - len(scoreable)} output={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
