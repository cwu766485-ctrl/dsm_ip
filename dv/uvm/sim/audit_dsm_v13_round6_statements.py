#!/usr/bin/env python3
"""Export and reconcile remaining statement counts and branch arms from URG."""
import argparse
import csv
import html
from pathlib import Path
import re

from audit_dsm_v13_round5_instances import digest, section, write
from generate_dsm_v13_round2_evidence import fragment_rows


def flatten(markup):
    return html.unescape(re.sub(r"</?[A-Za-z][A-Za-z0-9]*(?:\s[^<>]*)?\s*/?>", "", markup))


def statement_gaps(body):
    for line, hit, total, code in re.findall(
        r"^[ \t]*(\d+)[ \t]+(\d+)/(\d+)[ \t]+(?:==>[ \t]+)?(.*)$",
        flatten(body), re.M,
    ):
        if int(hit) < int(total):
            yield line, code, "", int(total) - int(hit)


def branch_gaps(body):
    for code, table in re.findall(
        r'<pre class="code">([^<]*(?:(?!</pre>).)*?)</pre>\s*'
        r'<br clear=all>\s*<span class=repname>Branches:</span>'
        r'\s*<br clear=all>\s*(<table.*?</table>)', body, re.S,
    ):
        match = re.search(r"^\s*(\d+)[ \t]+(.+)$", flatten(code), re.M)
        for values, _ in fragment_rows(table):
            if values and values[-1] == "Not Covered":
                if not match:
                    raise ValueError("Missing branch source location")
                yield match[1], match[2], ",".join(values[:-1]), 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for argument in ("reports", "counters", "waivers", "output"):
        parser.add_argument(argument, type=Path)
    args = parser.parse_args()
    with args.waivers.open(newline="") as stream:
        scoped_waivers = {
            (row["configuration"], row["instance"], row["signal"], row["constant"])
            for row in csv.DictReader(stream)
            if row["constant"] in ("", "true arm") and ":" in row["signal"]
        }
    result = []
    with args.counters.open(newline="") as stream:
        for row in csv.DictReader(stream):
            metric = row["metric"]
            if metric not in ("line", "branch") or not int(row["raw_missing"]):
                continue
            report = args.reports / row["configuration"]
            page, body = section(report, row["evidence"])
            extract = statement_gaps if metric == "line" else branch_gaps
            open_count = missing_count = 0
            for line, code, arm, count in extract(body):
                waiver_key = (
                    row["configuration"], row["instance"], f'{row["source"]}:{line}',
                    "" if metric == "line" else "true arm",
                )
                waived = waiver_key in scoped_waivers and arm in ("", "1")
                missing_count += count
                if not waived:
                    open_count += count
                identity = {key: row[key] for key in
                            ("configuration", "module", "instance", "source", "metric", "evidence")}
                result.append(dict(**identity, line=line, code=code.strip(), arm=arm,
                                   missing=count, status="WAIVED" if waived else "OPEN",
                                   report_sha256=digest(page)))
            if missing_count != int(row["raw_missing"]) or open_count != int(row["adjusted_missing"]):
                raise ValueError(f"Gap counts differ from URG: {row}, found {missing_count}/{open_count}")
    write(args.output, result)


if __name__ == "__main__":
    main()
