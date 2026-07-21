#!/usr/bin/env python3
"""Build a provenance-preserving DSM-aware DPD calibration data set.

The builder joins retained full-calibration JTAG traces with measured
one-policy-plus-local-search traces. It intentionally reports unavailable DSM
variation instead of manufacturing labels for joint DSM/DPD optimization.
"""

from __future__ import annotations

import argparse
import csv
import math
import statistics
import tempfile
from pathlib import Path


MONITOR_FIELDS = (
    "input_power", "output_power", "peak", "avg_mag", "evm_proxy",
    "acpr_proxy", "spec_bin0", "spec_bin1", "spec_bin2", "spec_adj",
    "clip", "saturation",
)
REQUIRED_MANIFEST_COLUMNS = {
    "scenario_id", "pa_profile", "pa_strength_db", "qam", "bandwidth_mhz",
    "used_subcarriers", "input_backoff", "waveform_id", "calibration_profile",
    "trace_csv",
}
DSM_MANIFEST_COLUMNS = {
    "dsm_config_id", "dsm_algorithm", "dsm_quantizer_bits",
    "dsm_interp_mode", "dsm_osr",
}
REQUIRED_LOCAL_COLUMNS = {
    "scenario_id", "records", "policy_records", "search_records", "final_records",
    "policy_cost", "final_cost", "trace_csv",
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def parse_int(value: str) -> int:
    return int(value, 0)


def resolve_path(owner: Path, value: str) -> Path:
    candidate = Path(value)
    return candidate if candidate.is_absolute() else owner.parent / candidate


def final_cost(path: Path) -> int:
    rows = read_csv(path)
    values = [parse_int(row["cost"]) for row in rows
              if row.get("stage") == "final" and row.get("cost")]
    if not values:
        raise ValueError(f"Full calibration trace has no final cost: {path}")
    return values[-1]


def policy_observation(path: Path) -> dict[str, str]:
    rows = read_csv(path)
    policy = [row for row in rows if row.get("stage") == "policy"]
    search = [row for row in rows if row.get("stage") == "search"]
    final = [row for row in rows if row.get("stage") == "final"]
    if len(rows) != 14 or len(policy) != 1 or len(search) != 12 or len(final) != 1:
        raise ValueError(f"Expected 14-record policy-local-search trace: {path}")
    if any(parse_int(row[field]) != 0 for row in rows
           for field in ("stall", "error", "clip", "saturation")):
        raise ValueError(f"Policy-local-search trace has nonzero safety counter: {path}")
    return policy[0]


def dsm_name(algorithm: int) -> str:
    names = {
        0: "lpdsm", 1: "lpdsm2", 2: "efdsm", 3: "efdsm2",
        4: "mash11", 5: "mash111", 6: "mash22",
    }
    return names.get(algorithm, "unknown")


def build_rows(manifest_path: Path, local_summary_path: Path, algorithm: int,
               quantizer_bits: int, interp_mode: int, osr: int) -> list[dict[str, object]]:
    manifest = read_csv(manifest_path)
    local = read_csv(local_summary_path)
    if not manifest or REQUIRED_MANIFEST_COLUMNS - set(manifest[0]):
        raise ValueError("Manifest lacks required scenario columns")
    if not local or REQUIRED_LOCAL_COLUMNS - set(local[0]):
        raise ValueError("Local-search summary lacks required columns")
    manifest_by_id: dict[str, list[dict[str, str]]] = {}
    manifest_by_trace: dict[str, dict[str, str]] = {}
    for manifest_row in manifest:
        scenario_id = manifest_row["scenario_id"].strip()
        manifest_by_id.setdefault(scenario_id, []).append(manifest_row)
        trace_key = str(resolve_path(manifest_path, manifest_row["trace_csv"])).lower()
        manifest_by_trace[trace_key] = manifest_row
    manifest_has_dsm = DSM_MANIFEST_COLUMNS <= set(manifest[0])
    local_has_dsm = DSM_MANIFEST_COLUMNS <= set(local[0])
    rows = []
    for item in local:
        scenario_id = item["scenario_id"].strip()
        if scenario_id not in manifest_by_id:
            raise ValueError(f"Local-search scenario is absent from manifest: {scenario_id}")
        source_full = item.get("source_full_calibration_trace", "").strip()
        if source_full:
            source_key = str(resolve_path(local_summary_path, source_full)).lower()
            scenario = manifest_by_trace.get(source_key)
            if scenario is None:
                raise ValueError(f"Local-search full-trace source is absent from manifest: {source_full}")
        elif len(manifest_by_id[scenario_id]) == 1:
            scenario = manifest_by_id[scenario_id][0]
        else:
            raise ValueError(f"Repeated scenario requires source_full_calibration_trace: {scenario_id}")
        row_algorithm = parse_int(scenario["dsm_algorithm"]) if manifest_has_dsm else algorithm
        row_quantizer_bits = (parse_int(scenario["dsm_quantizer_bits"])
                              if manifest_has_dsm else quantizer_bits)
        row_interp_mode = parse_int(scenario["dsm_interp_mode"]) if manifest_has_dsm else interp_mode
        row_osr = parse_int(scenario["dsm_osr"]) if manifest_has_dsm else osr
        row_config_id = (scenario["dsm_config_id"].strip() if manifest_has_dsm
                         else "legacy_default_not_swept")
        if local_has_dsm:
            local_config = item["dsm_config_id"].strip()
            if local_config != row_config_id:
                raise ValueError(f"DSM configuration mismatch for {scenario_id}: {local_config} != {row_config_id}")
        trace = resolve_path(local_summary_path, item["trace_csv"])
        full_trace = resolve_path(manifest_path, scenario["trace_csv"])
        policy = policy_observation(trace)
        policy_cost = parse_int(item["policy_cost"])
        local_cost = parse_int(item["final_cost"])
        if policy_cost != parse_int(policy["cost"]):
            raise ValueError(f"Policy cost mismatch in {trace}")
        if parse_int(item["records"]) != 14 or parse_int(item["policy_records"]) != 1 or \
                parse_int(item["search_records"]) != 12 or parse_int(item["final_records"]) != 1:
            raise ValueError(f"Summary does not describe a 14-candidate trace: {trace}")
        row: dict[str, object] = {
            "scenario_id": scenario_id,
            "run_id": scenario.get("run_id", ""),
            "pa_profile": scenario["pa_profile"],
            "pa_strength_db": float(scenario["pa_strength_db"]),
            "qam": int(float(scenario["qam"])),
            "bandwidth_mhz": float(scenario["bandwidth_mhz"]),
            "used_subcarriers": int(float(scenario["used_subcarriers"])),
            "input_backoff": float(scenario["input_backoff"]),
            "waveform_id": scenario["waveform_id"],
            "calibration_profile": scenario["calibration_profile"],
            "dsm_config_id": row_config_id,
            "dsm_algorithm": row_algorithm,
            "dsm_algorithm_name": dsm_name(row_algorithm),
            "dsm_quantizer_bits": row_quantizer_bits,
            "dsm_interp_mode": row_interp_mode,
            "dsm_osr": row_osr,
            "dsm_config_provenance": ("manifest_board_build" if manifest_has_dsm
                                      else "legacy_board_build_default_not_swept"),
            "dpd_mode": parse_int(policy["mode"]),
            "dpd_package": parse_int(policy["package"]),
            "dpd_c1": policy["c1"],
            "dpd_c3": policy["c3"],
            "dpd_c5": policy["c5"],
            "policy_cost": policy_cost,
            "local_search_final_cost": local_cost,
            "full_search_final_cost": final_cost(full_trace),
            "search_benefit": policy_cost - local_cost,
            "local_search_gap_to_full": local_cost - final_cost(full_trace),
            "policy_candidates": 1,
            "local_search_candidates": 14,
            "full_search_candidates": 49,
            "policy_local_trace_csv": str(trace),
            "full_calibration_trace_csv": str(full_trace),
        }
        for field in MONITOR_FIELDS:
            row[f"mon_{field}"] = parse_int(policy[field])
        rows.append(row)
    return sorted(rows, key=lambda row: str(row["scenario_id"]))


def pearson(left: list[float], right: list[float]) -> float | None:
    if len(left) < 3 or len(set(left)) < 2 or len(set(right)) < 2:
        return None
    left_mean = statistics.fmean(left)
    right_mean = statistics.fmean(right)
    numerator = sum((a - left_mean) * (b - right_mean) for a, b in zip(left, right))
    denominator = math.sqrt(sum((a - left_mean) ** 2 for a in left) *
                            sum((b - right_mean) ** 2 for b in right))
    return numerator / denominator if denominator else None


def feature_report(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    targets = [float(row["search_benefit"]) for row in rows]
    features = (
        "qam", "bandwidth_mhz", "used_subcarriers", "input_backoff",
        "dsm_algorithm", "dsm_quantizer_bits", "dsm_interp_mode", "dsm_osr",
        "dpd_mode", "dpd_package",
        *(f"mon_{field}" for field in MONITOR_FIELDS),
    )
    report = []
    for feature in features:
        values = [float(row[feature]) for row in rows]
        correlation = pearson(values, targets)
        report.append({
            "feature": feature,
            "samples": len(rows),
            "distinct_values": len(set(values)),
            "pearson_to_search_benefit": "" if correlation is None else f"{correlation:.6f}",
            "analysis_status": "not_ranked_constant" if correlation is None else "exploratory_small_sample",
        })
    return sorted(report, key=lambda row: abs(float(row["pearson_to_search_benefit"]))
                  if row["pearson_to_search_benefit"] else -1.0, reverse=True)


def write_csv(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        raise ValueError(f"No rows to write: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def write_markdown(path: Path, rows: list[dict[str, object]],
                   report: list[dict[str, object]]) -> None:
    dsm_configs = {(row["dsm_algorithm"], row["dsm_quantizer_bits"],
                    row["dsm_interp_mode"], row["dsm_osr"]) for row in rows}
    benefits = [int(row["search_benefit"]) for row in rows]
    lines = [
        "# DSM-Aware DPD Dataset Report", "",
        "This data set joins actual board policy/local-search traces to retained ",
        "full-calibration traces. Costs are PL monitor proxy costs, not measured RF EVM/ACLR.",
        "",
        f"- Rows: `{len(rows)}`",
        f"- Distinct DSM configurations: `{len(dsm_configs)}`",
        f"- Search-benefit range: `{min(benefits)}` to `{max(benefits)}`",
        f"- Mean search benefit: `{statistics.fmean(benefits):.2f}`", "",
        "## Question A: Worth Searching?", "",
        "The feature CSV ranks only nonconstant features by exploratory Pearson ",
        "correlation to measured `policy_cost - local_search_final_cost`. ",
        f"{len(rows)} rows ",
        "are insufficient for a deployable predictor; use this report to select the ",
        "next collection axes, not to generate policy constants.", "",
        "## Question B: Joint DSM and DPD Choice", "",
    ]
    if len(dsm_configs) == 1:
        lines += [
            "Not answerable from this data set. All retained board rows use one ",
            "DSM build configuration, so DSM features are constant and cannot be ",
            "ranked or jointly optimized with DPD.",
        ]
    else:
        config_names = sorted({str(row["dsm_config_id"]) for row in rows},
                              key=lambda value: (not value.startswith("legacy_"), value))
        first, second = config_names[:2]
        keys = ("pa_profile", "pa_strength_db", "qam", "bandwidth_mhz",
                "used_subcarriers", "input_backoff", "waveform_id")
        first_rows = {tuple(row[key] for key in keys): row
                      for row in rows if row["dsm_config_id"] == first}
        second_rows = {tuple(row[key] for key in keys): row
                       for row in rows if row["dsm_config_id"] == second}
        matched = sorted(set(first_rows) & set(second_rows))
        local_deltas = [int(second_rows[key]["local_search_final_cost"]) -
                        int(first_rows[key]["local_search_final_cost"])
                        for key in matched]
        full_deltas = [int(second_rows[key]["full_search_final_cost"]) -
                       int(first_rows[key]["full_search_final_cost"])
                       for key in matched]
        lines += [
            "DSM configuration varies. The first paired comparison uses ",
            f"`{first}` versus `{second}` with `{len(matched)}` matched waveform/PA rows.",
        ]
        if matched:
            lines += [
                f"The `{second}` minus `{first}` mean local-search final-cost delta is ",
                f"`{statistics.fmean(local_deltas):.2f}`; the matching full-search delta is ",
                f"`{statistics.fmean(full_deltas):.2f}`. Negative means `{second}` has lower ",
                "PL proxy cost. This is an exploratory paired result, not an RF-quality claim ",
                "or a deployable joint policy.",
            ]
    lines += ["", "## Next Collection Matrix", "",
              "Hold waveform and PA metadata fixed while varying at least two DSM ",
              "build configurations, then collect the same policy/local/full labels. ",
              "Add a third DSM configuration and repeated captures before fitting a joint ",
              "model. A native multibit configuration is a reasonable next axis only after ",
              "its output interpretation and comparable monitor semantics are documented. ",
              "Interpolation mode is compile-time today and must also be recorded.", ""]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def self_test() -> None:
    assert dsm_name(2) == "efdsm"
    assert pearson([1.0, 2.0, 3.0], [2.0, 4.0, 6.0]) == 1.0
    assert pearson([1.0, 1.0, 1.0], [1.0, 2.0, 3.0]) is None
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "rows.csv"
        write_csv(path, [{"value": 1}])
        assert read_csv(path)[0]["value"] == "1"
        report = Path(directory) / "report.md"
        rows = [
            {"dsm_config_id": "a", "pa_profile": "nominal", "pa_strength_db": 0.0,
             "qam": 16, "bandwidth_mhz": 20.0, "used_subcarriers": 48,
             "input_backoff": 0.58, "waveform_id": "w", "search_benefit": 10,
             "local_search_final_cost": 100, "full_search_final_cost": 90,
             "dsm_algorithm": 2, "dsm_quantizer_bits": 1, "dsm_interp_mode": 0,
             "dsm_osr": 32},
            {"dsm_config_id": "b", "pa_profile": "nominal", "pa_strength_db": 0.0,
             "qam": 16, "bandwidth_mhz": 20.0, "used_subcarriers": 48,
             "input_backoff": 0.58, "waveform_id": "w", "search_benefit": 20,
             "local_search_final_cost": 80, "full_search_final_cost": 70,
             "dsm_algorithm": 3, "dsm_quantizer_bits": 1, "dsm_interp_mode": 0,
             "dsm_osr": 32},
        ]
        write_markdown(report, rows, [])
        assert "mean local-search final-cost delta" in report.read_text(encoding="ascii")
    print("PASS DSM-aware DPD dataset self-test")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest-csv", action="append", type=Path)
    parser.add_argument("--local-search-summary-csv", action="append", type=Path)
    parser.add_argument("--out-dir", type=Path,
                        default=Path("fpga/zu15eg/out/dsm_aware_dataset"))
    parser.add_argument("--dsm-algorithm", type=int, default=2)
    parser.add_argument("--dsm-quantizer-bits", type=int, default=1)
    parser.add_argument("--dsm-interp-mode", type=int, default=0)
    parser.add_argument("--dsm-osr", type=int, default=32)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.manifest_csv or not args.local_search_summary_csv:
        parser.error("--manifest-csv and --local-search-summary-csv are required")
    if len(args.manifest_csv) != len(args.local_search_summary_csv):
        parser.error("Supply the same number of --manifest-csv and --local-search-summary-csv arguments")
    rows = []
    for manifest_csv, local_search_summary_csv in zip(args.manifest_csv,
                                                       args.local_search_summary_csv):
        rows.extend(build_rows(manifest_csv, local_search_summary_csv,
                               args.dsm_algorithm, args.dsm_quantizer_bits,
                               args.dsm_interp_mode, args.dsm_osr))
    scenario_keys = [(str(row["dsm_config_id"]), str(row["scenario_id"]),
                      str(row["full_calibration_trace_csv"])) for row in rows]
    if len(set(scenario_keys)) != len(scenario_keys):
        raise ValueError("Duplicate (dsm_config_id, scenario_id, full trace) dataset row")
    rows.sort(key=lambda row: (str(row["dsm_config_id"]), str(row["scenario_id"]),
                               str(row["run_id"])))
    report = feature_report(rows)
    write_csv(args.out_dir / "dsm_aware_dpd_dataset.csv", rows)
    write_csv(args.out_dir / "dsm_aware_feature_report.csv", report)
    write_markdown(args.out_dir / "dsm_aware_dpd_dataset_report.md", rows, report)
    print(f"Wrote {len(rows)} DSM-aware DPD rows: {args.out_dir}")
    print(f"DSM configurations present: {len({(row['dsm_algorithm'], row['dsm_quantizer_bits'], row['dsm_interp_mode'], row['dsm_osr']) for row in rows})}")


if __name__ == "__main__":
    main()
