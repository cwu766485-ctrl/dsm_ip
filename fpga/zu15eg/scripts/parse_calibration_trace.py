#!/usr/bin/env python3
"""Parse bare-metal calibration trace logs into CSV and Markdown.

The bare-metal app emits CSV-style lines:

  CAL_TRACE,...
  CAL_SELECTED_REPLAY ...

This parser accepts UART logs, XSDB logs, or transcript files and extracts the
machine-readable calibration history. It intentionally works with partial logs:
if no UART trace is present, it still writes an empty CSV plus a Markdown note.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


TRACE_COLUMNS = [
    "candidate_id",
    "round",
    "stage",
    "mode",
    "package",
    "searched",
    "c1",
    "c3",
    "c5",
    "proxy_evm_ppm",
    "proxy_sndr_mdB",
    "input_power",
    "output_power",
    "saturation",
    "clip",
    "error",
    "stall",
    "evm_proxy",
    "acpr_proxy",
    "spec_bin0",
    "spec_bin1",
    "spec_bin2",
    "spec_adj",
    "cost",
    "decision",
    "reason",
]

SELECTED_RE = re.compile(r"\bCAL_SELECTED_REPLAY\s+(?P<body>.*)$")


def parse_key_values(body: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in body.strip().split():
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        out[key.strip()] = value.strip().rstrip(",")
    return out


def parse_trace_line(line: str) -> dict[str, str] | None:
    line = line.strip()
    if not line.startswith("CAL_TRACE,"):
        return None
    parts = [p.strip() for p in line.split(",")]
    if len(parts) < 1 + len(TRACE_COLUMNS):
        return None
    return dict(zip(TRACE_COLUMNS, parts[1 : 1 + len(TRACE_COLUMNS)]))


def read_logs(paths: list[Path]) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    traces: list[dict[str, str]] = []
    selected: list[dict[str, str]] = []
    for path in paths:
        text = path.read_text(errors="replace")
        for line in text.splitlines():
            row = parse_trace_line(line)
            if row is not None:
                row["source"] = str(path)
                traces.append(row)
                continue
            match = SELECTED_RE.search(line)
            if match:
                row = parse_key_values(match.group("body"))
                row["source"] = str(path)
                selected.append(row)
    return traces, selected


def to_number(value: str, default: float = 0.0) -> float:
    try:
        if value.lower().startswith("0x"):
            return float(int(value, 16))
        return float(value)
    except Exception:
        return default


def write_trace_csv(path: Path, traces: list[dict[str, str]]) -> None:
    fields = TRACE_COLUMNS + ["source"]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(traces)


def write_selected_csv(path: Path, selected: list[dict[str, str]]) -> None:
    fields = [
        "mode",
        "package",
        "searched",
        "c1",
        "c3",
        "c5",
        "cost",
        "input",
        "frontend",
        "dpd",
        "output",
        "stall",
        "error",
        "sat",
        "evm_proxy",
        "acpr_proxy",
        "spec_adj",
        "source",
    ]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(selected)


def write_markdown(path: Path, traces: list[dict[str, str]], selected: list[dict[str, str]]) -> None:
    accepted = [r for r in traces if r.get("decision") == "accept"]
    rejected = [r for r in traces if r.get("decision") == "reject"]
    best = min(traces, key=lambda r: to_number(r.get("cost", "")), default=None)
    final = selected[-1] if selected else None

    with path.open("w", encoding="utf-8") as f:
        f.write("# Calibration Trace Summary\n\n")
        f.write(f"- Trace candidates: {len(traces)}\n")
        f.write(f"- Accepted candidates: {len(accepted)}\n")
        f.write(f"- Rejected candidates: {len(rejected)}\n")
        f.write(f"- Selected replay records: {len(selected)}\n\n")

        if best is None:
            f.write("No `CAL_TRACE` lines were found. Capture the PS UART output during the bare-metal run to populate candidate-level history.\n\n")
        else:
            f.write("## Best Candidate\n\n")
            f.write(f"- Candidate id: `{best.get('candidate_id', '')}`\n")
            f.write(f"- Stage: `{best.get('stage', '')}`\n")
            f.write(f"- Mode/package: `{best.get('mode', '')}` / `{best.get('package', '')}`\n")
            f.write(f"- C1/C3/C5: `{best.get('c1', '')}`, `{best.get('c3', '')}`, `{best.get('c5', '')}`\n")
            f.write(f"- Cost: `{best.get('cost', '')}`\n")
            f.write(f"- Decision: `{best.get('decision', '')}` ({best.get('reason', '')})\n\n")

        if final is not None:
            f.write("## Final Replay\n\n")
            f.write(f"- Mode/package: `{final.get('mode', '')}` / `{final.get('package', '')}`\n")
            f.write(f"- Searched: `{final.get('searched', '')}`\n")
            f.write(f"- C1/C3/C5: `{final.get('c1', '')}`, `{final.get('c3', '')}`, `{final.get('c5', '')}`\n")
            f.write(f"- Cost: `{final.get('cost', '')}`\n")
            f.write(f"- Counts input/frontend/DPD/output: `{final.get('input', '')}` / `{final.get('frontend', '')}` / `{final.get('dpd', '')}` / `{final.get('output', '')}`\n")
            f.write(f"- Stall/error/saturation: `{final.get('stall', '')}` / `{final.get('error', '')}` / `{final.get('sat', '')}`\n")
            f.write(f"- EVM/ACPR/spec-adj proxies: `{final.get('evm_proxy', '')}` / `{final.get('acpr_proxy', '')}` / `{final.get('spec_adj', '')}`\n\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("logs", nargs="+", type=Path, help="UART/XSDB log files to parse")
    parser.add_argument("--out-dir", type=Path, default=Path("fpga/zu15eg/out"))
    parser.add_argument("--prefix", default="calibration_trace")
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    traces, selected = read_logs(args.logs)

    trace_csv = args.out_dir / f"{args.prefix}.csv"
    selected_csv = args.out_dir / f"{args.prefix}_selected.csv"
    markdown = args.out_dir / f"{args.prefix}.md"
    write_trace_csv(trace_csv, traces)
    write_selected_csv(selected_csv, selected)
    write_markdown(markdown, traces, selected)

    print(f"Trace rows: {len(traces)}")
    print(f"Selected replay rows: {len(selected)}")
    print(f"Wrote: {trace_csv}")
    print(f"Wrote: {selected_csv}")
    print(f"Wrote: {markdown}")


if __name__ == "__main__":
    main()
