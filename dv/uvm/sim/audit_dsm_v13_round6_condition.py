#!/usr/bin/env python3
"""Compare exact Condition hit tuples for the two Round 6 DUTs."""
from argparse import ArgumentParser
from collections import Counter
import json
from pathlib import Path

from audit_dsm_v13_round5_instances import condition_gaps, inventory, section
from run_dsm_v13_round6_product import CONFIGS


def bins(report, config):
    counts = Counter()
    hits = Counter()
    for row in inventory(report, config)[0]:
        if row["metric"] != "cond":
            continue
        _, body = section(report, row["evidence"])
        identity = (row["instance"], row["module"], row["source"])
        present = [identity + item for item in condition_gaps(body, "Covered")]
        absent = [identity + item for item in condition_gaps(body)]
        if len(present) != row["raw_hits"] or len(present + absent) != row["raw_total"]:
            raise ValueError(f"Condition details do not reconcile: {row}")
        hits.update(present)
        counts.update(present + absent)
    return counts, hits


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    args = parser.parse_args()
    result = {}
    for config in CONFIGS:
        old, old_hits = bins(args.baseline / config, config)
        new, new_hits = bins(args.candidate / config, config)
        if old != new:
            raise SystemExit(f"Condition bin universe changed: {config}")
        if old_hits - new_hits:
            raise SystemExit(f"Previously hit Condition tuples lost: {config}")
        # Duplicate rendered URG keys are indistinguishable when their hit
        # count is partial. Refuse to call this an exact audit in that case.
        for key, count in old.items():
            if count > 1 and (0 < old_hits[key] < count or 0 < new_hits[key] < count):
                raise SystemExit(f"Ambiguous partial Condition key: {config}: {key}")
        gains = new_hits - old_hits
        result[config] = dict(total=old.total(), previous_hits=old_hits.total(),
                              current_hits=new_hits.total(), new_hits=list(gains.elements()))
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
