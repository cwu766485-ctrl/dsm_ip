#!/usr/bin/env python3
"""Reconcile a native SpyGlass Ar_resetcross01 CSV without issuing waivers."""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
import re
from pathlib import Path


def normalize(name: str) -> str:
    name = re.sub(r"\[[^\]]+\]", "[*]", name.replace("\\", ""))
    return re.sub(r"\s+", "", name)


def parent(name: str) -> str:
    value = normalize(name)
    return value.rsplit(".", 1)[0] if "." in value else value


def bucket(source: str, destination: str) -> str:
    hierarchy = source + " " + destination
    if "u_stage1" in hierarchy or "u_mash" in hierarchy:
        return "MASH state and enable cones"
    if "u_interp_2" in hierarchy or "u_interp2_to_tid_fifo" in hierarchy:
        return "Interpolator 2 and FIFO payload"
    if "u_interp_1" in hierarchy or "u_interp_to_dpd_elastic" in hierarchy:
        return "Interpolator 1 elastic payload"
    if "u_async_fifo" in hierarchy:
        return "Generic asynchronous FIFO"
    if "u_dpd" in hierarchy or "memory_dpd" in hierarchy:
        return "DPD history and pipeline"
    if "u_cfg" in hierarchy or "cfg_" in hierarchy or "dsm_reset" in hierarchy:
        return "Configuration and reset epoch"
    if "runtime" in hierarchy or "u_backend" in hierarchy:
        return "Runtime backend and output"
    return "Other frontend/control"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="SpyGlass Ar_resetcross01.csv")
    parser.add_argument("--out", type=Path, required=True, help="new output directory; must not exist")
    args = parser.parse_args()
    if not args.input.is_file():
        raise SystemExit(f"missing input: {args.input}")
    args.out.mkdir(parents=True, exist_ok=False)

    with args.input.open(newline="", errors="replace") as stream:
        rows = list(csv.DictReader(line for line in stream if line.strip() and not line.lstrip().startswith("#")))
    signatures: collections.Counter[tuple[str, ...]] = collections.Counter()
    reasons: collections.Counter[tuple[str, str, str]] = collections.Counter()
    pairs: collections.Counter[tuple[str, str, str, str]] = collections.Counter()
    messages: collections.Counter[str] = collections.Counter()
    groups: collections.Counter[str] = collections.Counter()

    for row in rows:
        src = parent(row["SOURCE"])
        dst = parent(row["DESTINATION"])
        reason = row["REASON_CODE"]
        src_reset = row["SOURCE_RESET"].split(".")[-1]
        dst_reset = row["DESTINATION_RESET"].split(".")[-1]
        key = (reason, row["SEVERITY"], row["WAIVED"], src_reset, dst_reset,
               row["SOURCE_CLOCK_DOMAINS"], row["DESTINATION_CLOCK_DOMAINS"], src, dst)
        signatures[key] += 1
        reasons[(reason, row["SEVERITY"], row["WAIVED"])] += 1
        pairs[(src_reset, dst_reset, row["SOURCE_CLOCK_DOMAINS"], row["DESTINATION_CLOCK_DOMAINS"])] += 1
        group = bucket(row["SOURCE"], row["DESTINATION"])
        messages[group] += 1
        groups[group] += 0
    for key in signatures:
        groups[bucket(key[-2], key[-1])] += 1

    if not rows or any(value["WAIVED"].lower() not in {"no", "false", "0"} for value in rows):
        raise SystemExit("empty report or unexpected waived row; refusing to summarize as no-waiver data")
    with (args.out / "structural_signatures.csv").open("x", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["reason", "severity", "waived", "source_reset", "destination_reset",
                         "source_clock_domain", "destination_clock_domain", "source_hierarchy",
                         "destination_hierarchy", "messages", "disposition"])
        for key, count in signatures.most_common():
            writer.writerow([*key, count, "OPEN_REVIEW"])
    raw_sha = hashlib.sha256(args.input.read_bytes()).hexdigest()
    summary = {
        "input": str(args.input.resolve()),
        "input_sha256": raw_sha,
        "spyglass_rows": len(rows),
        "unique_structural_signatures": len(signatures),
        "reason_severity_waiver": [
            {"reason": key[0], "severity": key[1], "waived": key[2], "messages": count}
            for key, count in reasons.most_common()
        ],
        "hierarchy_buckets": [
            {"bucket": key, "messages": messages[key], "signatures": groups[key],
             "disposition": "OPEN_REVIEW; textual hierarchy triage only"}
            for key, _ in messages.most_common()
        ],
        "reset_domain_pairs": [
            {"source_reset": key[0], "destination_reset": key[1],
             "source_clock_domain": key[2], "destination_clock_domain": key[3], "messages": count}
            for key, count in pairs.most_common()
        ],
        "waivers_applied": 0,
        "limitations": [
            "Hierarchy signatures are not independent RTL root causes or safe dispositions.",
            "Qualifier not found does not establish an RTL defect by itself.",
            "All signatures remain OPEN_REVIEW until valid/enable/reset behavior is proved or a specific RTL defect is fixed.",
        ],
    }
    with (args.out / "summary.json").open("x") as stream:
        json.dump(summary, stream, indent=2)
        stream.write("\n")
    print(json.dumps({"rows": len(rows), "signatures": len(signatures),
                      "output": str(args.out.resolve()), "input_sha256": raw_sha}, indent=2))


if __name__ == "__main__":
    main()
