#!/usr/bin/env python3
"""Normalize an existing single-run DSM matrix for repeat-aware collection."""

from __future__ import annotations

import argparse
import csv
import tempfile
from pathlib import Path


DSM_COLUMNS = ("dsm_config_id", "dsm_algorithm", "dsm_quantizer_bits",
               "dsm_interp_mode", "dsm_osr")


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        raise ValueError(f"No rows to write: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def normalize(manifest: list[dict[str, str]], local: list[dict[str, str]],
              config_id: str, algorithm: int, quantizer_bits: int,
              interp_mode: int, osr: int) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    if len(manifest) != 8 or len(local) != 8:
        raise ValueError("Expected exactly eight initial full and local rows")
    by_scenario = {row["scenario_id"].strip(): row for row in manifest}
    if len(by_scenario) != 8:
        raise ValueError("Initial manifest scenario IDs must be unique")
    normalized_manifest = []
    for row in manifest:
        item = dict(row)
        item.update({"dsm_config_id": config_id, "dsm_algorithm": str(algorithm),
                     "dsm_quantizer_bits": str(quantizer_bits),
                     "dsm_interp_mode": str(interp_mode), "dsm_osr": str(osr)})
        normalized_manifest.append(item)
    normalized_local = []
    for row in local:
        scenario = by_scenario.get(row["scenario_id"].strip())
        if scenario is None:
            raise ValueError(f"Local scenario absent from manifest: {row['scenario_id']}")
        item = dict(row)
        item.update({"dsm_config_id": config_id, "dsm_algorithm": str(algorithm),
                     "dsm_quantizer_bits": str(quantizer_bits),
                     "dsm_interp_mode": str(interp_mode), "dsm_osr": str(osr),
                     "source_full_calibration_trace": scenario["trace_csv"],
                     "run_id": scenario.get("run_id", "initial")})
        normalized_local.append(item)
    return normalized_manifest, normalized_local


def self_test() -> None:
    manifest = [{"scenario_id": f"s{index}", "trace_csv": f"full{index}.csv"}
                for index in range(8)]
    local = [{"scenario_id": f"s{index}", "trace_csv": f"local{index}.csv"}
             for index in range(8)]
    full, bounded = normalize(manifest, local, "ef1", 2, 1, 0, 32)
    assert full[0]["dsm_algorithm"] == "2"
    assert bounded[0]["source_full_calibration_trace"] == "full0.csv"
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "manifest.csv"
        write_csv(path, full)
        assert len(read_csv(path)) == 8
    print("PASS repeat-manifest normalization self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest-csv", type=Path)
    parser.add_argument("--local-summary-csv", type=Path)
    parser.add_argument("--out-manifest-csv", type=Path)
    parser.add_argument("--out-local-summary-csv", type=Path)
    parser.add_argument("--dsm-config-id")
    parser.add_argument("--dsm-algorithm", type=int)
    parser.add_argument("--dsm-quantizer-bits", type=int, default=1)
    parser.add_argument("--dsm-interp-mode", type=int, default=0)
    parser.add_argument("--dsm-osr", type=int, default=32)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    required = (args.manifest_csv, args.local_summary_csv, args.out_manifest_csv,
                args.out_local_summary_csv, args.dsm_config_id, args.dsm_algorithm)
    if any(value is None for value in required):
        parser.error("All manifest, output, and DSM provenance arguments are required")
    full, bounded = normalize(read_csv(args.manifest_csv), read_csv(args.local_summary_csv),
                              args.dsm_config_id, args.dsm_algorithm,
                              args.dsm_quantizer_bits, args.dsm_interp_mode,
                              args.dsm_osr)
    write_csv(args.out_manifest_csv, full)
    write_csv(args.out_local_summary_csv, bounded)
    print(f"Wrote normalized repeat manifests: {args.out_manifest_csv.parent}")


if __name__ == "__main__":
    main()
