"""Small, fail-closed helpers for extracting exact URG covergroup crosses."""

from __future__ import annotations

from pathlib import Path
import re


def cross_counts(report_dir: Path, cross_name: str) -> tuple[int, int, int]:
    """Return (expected, uncovered, covered) for a named URG cross.

    URG emits one group-type and one instance view. Either carries the same
    bin totals; this helper requires at least one exact named view and rejects
    reports whose cross summary cannot be parsed.
    """
    marker = "Summary for Cross " + cross_name
    number_pattern = re.compile(r'<td class="rt">(\d+)</td>')
    for report in sorted(report_dir.glob("grp*.html")):
        page = report.read_text(encoding="utf-8", errors="replace")
        start = page.find(marker)
        if start < 0:
            continue
        table_end = page.find("</table>", start)
        if table_end < 0:
            continue
        counts = number_pattern.findall(page, start, table_end)
        if len(counts) >= 3:
            return tuple(int(value) for value in counts[:3])
    raise RuntimeError("URG cross not found or malformed: %s in %s" %
                       (cross_name, report_dir))
