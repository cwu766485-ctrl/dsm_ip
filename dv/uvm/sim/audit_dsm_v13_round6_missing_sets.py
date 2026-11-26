#!/usr/bin/env python3
"""Reject missing-bin regressions in compatible Round 5 and Round 6 URG exports."""
from argparse import ArgumentParser
from collections import Counter, defaultdict
import csv
import json
from pathlib import Path
import re


def statement_bins(path):
    bins = defaultdict(Counter)
    with path.open(newline="") as stream:
        for row in csv.DictReader(stream):
            key = tuple(row[field] for field in
                        ("instance", "module", "source", "line", "code", "arm"))
            bins[row["configuration"], row["metric"]][key] += int(row["missing"])
    return bins


def directional_bins(path):
    bins = defaultdict(Counter)
    with path.open(newline="") as stream:
        for row in csv.DictReader(stream):
            bits = re.fullmatch(r"(.*)\[(\d+):(\d+)\]", row["signal"])
            if bits:
                low, high = sorted((int(bits[2]), int(bits[3])))
                signals = [f"{bits[1]}[{i}]" for i in range(low, high + 1)]
            else:
                signals = [row["signal"]]
            identity = tuple(row[field] for field in ("instance", "module", "source"))
            for field, direction in (("down_covered", "1->0"), ("up_covered", "0->1")):
                if row[field] == "No":
                    bins[row["configuration"], "toggle"].update(
                        identity + (signal, direction) for signal in signals
                    )
    if any(count > 1 for scope in bins.values() for count in scope.values()):
        raise ValueError("Ambiguous Toggle direction")
    return bins


def main():
    parser = ArgumentParser(description=__doc__)
    for name in ("old_statements", "new_statements", "old_toggle", "new_toggle"):
        parser.add_argument(name, type=Path)
    args = parser.parse_args()
    before = statement_bins(args.old_statements) | directional_bins(args.old_toggle)
    after = statement_bins(args.new_statements) | directional_bins(args.new_toggle)
    expected = {(sku, metric) for sku in ("ef1_axil", "mash11_axil")
                for metric in ("line", "branch", "toggle")}
    if set(before) != expected or not after.keys() <= expected:
        raise ValueError("Unexpected configurations or metrics in URG exports")
    result = defaultdict(dict)
    for (sku, metric), old in sorted(before.items()):
        new = after.get((sku, metric), Counter())
        if new_missing := new - old:
            raise ValueError(f"New missing bins for {sku}/{metric}: {new_missing}")
        result[sku][metric] = dict(round5_raw_missing=old.total(),
                                   round6_raw_missing=new.total(),
                                   added_hits=(old - new).total(), new_raw_missing=0)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
