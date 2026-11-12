#!/usr/bin/env python3
"""Deduplicate exact SpyGlass RDC/CDC messages into review groups.

Usage: python3 tools/hw/thermo5_rdc_rootcause_audit.py \
  docs/verification/data/thermo5-cdc-phase2/static_messages.csv.gz \
  --out-dir runs/thermo5_rdc_rootcause
No waiver, reset equivalence, or product RTL changes are applied.
"""
import argparse
import csv
import gzip
import json
import re
from collections import Counter
from pathlib import Path

TOP = "tid32_thermo5_axi_lite_axis_frontend_tx."
INDEX = re.compile(r"\[(?:\d+)(?::\d+)?\]")
RESET = re.compile(r"\(Reset: '([^']+)'\)")


def normalize(endpoint):
    return INDEX.sub("[*]", endpoint.replace(TOP, "").replace("\\", "").replace(" ", ""))


def classify(row):
    if row["goal"] == "cdc":
        return "CDC_GLITCH_SOURCE_NEEDS_REVIEW"
    source_file = row["source_file"]
    endpoint = row["destination"]
    if source_file.endswith("dsm_async_fifo.sv"):
        return "RDC_UNRESET_ASYNC_FIFO_MEMORY_OR_CONTROL"
    if "data_i_mem[" in endpoint or "data_q_mem[" in endpoint or "meta_mem[" in endpoint:
        return "RDC_UNRESET_ELASTIC_BUFFER_STORAGE"
    if source_file.endswith("dpd_memory_poly.v"):
        return "RDC_DPD_PIPELINE_OR_HISTORY"
    if source_file.endswith("dsm_frame_gain_vector.sv"):
        return "RDC_FRAME_GAIN"
    return "RDC_CONTROL_OR_OTHER"


def load(path):
    op = gzip.open if str(path).endswith(".gz") else open
    with op(path, "rt", encoding="utf-8", newline="") as stream:
        yield from csv.DictReader(stream)


def audit(path):
    counts, categories, source_files = Counter(), Counter(), Counter()
    groups, glitches = {}, []
    for row in load(path):
        goal, rule = row.get("goal", ""), row.get("rule", "")
        counts[(goal, rule, row.get("severity", ""))] += 1
        if (goal, rule) not in {("rdc", "Ar_resetcross01"), ("cdc", "Ac_glitch03")}:
            continue
        cat = classify(row)
        categories[cat] += 1
        source_files[(goal, row.get("source_file", ""))] += 1
        reset_pair = " -> ".join(RESET.findall(row.get("message", ""))) or "unknown"
        dst = normalize(row.get("destination", ""))
        key = (goal, rule, cat, row.get("source_file", ""), dst, reset_pair)
        if key not in groups:
            groups[key] = dict(
                goal=goal, rule=rule, category=cat, source_file=row.get("source_file", ""),
                normalized_destination=dst, reset_pair=reset_pair, count=0,
                example_message_id=row.get("message_id", ""),
                example_source=row.get("source", ""),
                example_destination=row.get("destination", ""),
                example_native_message=row.get("message", ""),
                status="OPEN_REVIEW_REQUIRED", approved_waiver=False,
            )
        groups[key]["count"] += 1
        if goal == "cdc":
            glitches.append(dict(
                message_id=row.get("message_id", ""),
                destination=row.get("destination", ""),
                message=row.get("message", ""), status="OPEN_REVIEW_REQUIRED",
            ))
    return dict(
        source_inventory=str(path),
        rule_counts=[dict(goal=g, rule=r, severity=s, count=n)
                     for (g, r, s), n in sorted(counts.items())],
        root_category_counts=dict(categories),
        file_counts=[dict(goal=g, file=f, count=n)
                     for (g, f), n in source_files.most_common()],
        glitch_targets=glitches,
        root_groups=sorted(groups.values(), key=lambda g: -g["count"]),
        policy="DIAGNOSTIC_ONLY: 0 waivers; no reset-equivalence assumptions",
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("messages", type=Path)
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()
    result = audit(args.messages)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "rootcause_summary.json").write_text(json.dumps(result, indent=2) + "\n")
    with (args.out_dir / "review_groups.csv").open("w", newline="") as handle:
        fields = ["goal", "rule", "category", "source_file", "normalized_destination",
                  "reset_pair", "count", "example_message_id", "example_source",
                  "example_destination", "status", "approved_waiver"]
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(result["root_groups"])
    print("CDC glitch errors:", len(result["glitch_targets"]))
    print("RDC messages:", sum(n for (g, r, s), n in
          ((k, v) for k, v in ((x["goal"], x["rule"], x["severity"]), x["count"]) for x in result["rule_counts"])
          if g == "rdc" and r == "Ar_resetcross01"))
    for category, count in sorted(result["root_category_counts"].items()):
        print(category, count)


if __name__ == "__main__":
    main()
