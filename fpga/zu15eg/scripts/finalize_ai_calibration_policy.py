#!/usr/bin/env python3
"""Finalize the simulation-qualified AI seed plus bounded-search policy.

The deployment policy deliberately disables one-candidate direct execution.
Strict grouped validation showed that no non-empty direct region preserves the
regret and modeled EVM constraints. AI remains useful for selecting one of six
Q2.14 seed offsets before the deterministic 14-candidate local search.
"""

from __future__ import annotations

import argparse
import csv
import json
import tempfile
from collections import defaultdict
from pathlib import Path


OFFSETS = ((0, 0, 0), (48, -32, 16), (-48, 32, -16),
           (24, 40, -24), (-24, -40, 24), (64, 16, -40))
SPLIT_FIELDS = {"profile": "profile_id", "waveform": "waveform_id",
                "seed": "simulation_seed"}
REQUIRED = {"profile_id", "waveform_id", "simulation_seed", "seed_package",
            "final_cost", "final_evm_pct", "final_aclr_db", "clip",
            "saturation", "candidate_count_local", "dsm_config_id",
            "c1_hex", "c3_hex", "c5_hex"}


def read_rows(path: Path) -> list[dict[str, object]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        raw = list(csv.DictReader(handle))
    if not raw or REQUIRED - set(raw[0]):
        raise ValueError("Benchmark is empty or missing final-policy columns")
    rows = []
    for item in raw:
        rows.append({
            "profile_id": item["profile_id"],
            "waveform_id": item["waveform_id"],
            "simulation_seed": int(float(item["simulation_seed"])),
            "seed_package": int(float(item["seed_package"])),
            "final_cost": float(item["final_cost"]),
            "final_evm_pct": float(item["final_evm_pct"]),
            "final_aclr_db": float(item["final_aclr_db"]),
            "clip": int(float(item["clip"])),
            "saturation": int(float(item["saturation"])),
            "candidate_count_local": int(float(item["candidate_count_local"])),
            "dsm_config_id": item["dsm_config_id"],
            "c1_hex": item["c1_hex"],
            "c3_hex": item["c3_hex"],
            "c5_hex": item["c5_hex"],
        })
    if {row["seed_package"] for row in rows} != set(range(6)):
        raise ValueError("Packages 0 through 5 are required")
    if any(row["candidate_count_local"] != 14 for row in rows):
        raise ValueError("Every bounded-search label must contain 14 candidates")
    if {row["dsm_config_id"] for row in rows} != {"efdsm_1bit_osr32_interp0"}:
        raise ValueError("Unexpected DSM provenance")
    return rows


def waveform_fields(waveform_id: str) -> tuple[int, int, int]:
    return (64 if "qam64" in waveform_id else 16,
            96 if "bw40" in waveform_id else 48,
            700000 if "bo070" in waveform_id else 580000)


def choose_package(training: list[dict[str, object]], waveform_id: str) -> int:
    same = [row for row in training if row["waveform_id"] == waveform_id]
    source = same if same else training
    grouped: dict[int, list[float]] = defaultdict(list)
    for row in source:
        grouped[int(row["seed_package"])].append(float(row["final_cost"]))
    return min((sum(costs) / len(costs), package)
               for package, costs in grouped.items())[1]


def evaluate_split(rows: list[dict[str, object]], split: str,
                   evm_limit: float, aclr_limit: float) -> dict[str, object]:
    field = SPLIT_FIELDS[split]
    decisions = []
    for held_value in sorted({row[field] for row in rows}, key=str):
        training = [row for row in rows if row[field] != held_value]
        held = [row for row in rows if row[field] == held_value]
        groups: dict[tuple[str, str, int], list[dict[str, object]]] = defaultdict(list)
        for row in held:
            groups[(str(row["profile_id"]), str(row["waveform_id"]),
                    int(row["simulation_seed"]))].append(row)
        for key, samples in sorted(groups.items()):
            package = choose_package(training, key[1])
            selected = next(row for row in samples if row["seed_package"] == package)
            fixed = next(row for row in samples if row["seed_package"] == 3)
            oracle = min(float(row["final_cost"]) for row in samples)
            decisions.append({
                "held_group": held_value, "profile_id": key[0],
                "waveform_id": key[1], "simulation_seed": key[2],
                "selected_package": package, "candidate_count": 14,
                "selected_final_cost": selected["final_cost"],
                "fixed3_final_cost": fixed["final_cost"],
                "oracle_final_cost": oracle,
                "selected_regret": float(selected["final_cost"]) - oracle,
                "selected_minus_fixed3": float(selected["final_cost"]) - float(fixed["final_cost"]),
                "new_evm_failure": int(float(fixed["final_evm_pct"]) <= evm_limit <
                                       float(selected["final_evm_pct"])),
                "new_aclr_failure": int(float(fixed["final_aclr_db"]) <= aclr_limit <
                                        float(selected["final_aclr_db"])),
                "clip_or_saturation": int(bool(selected["clip"] or selected["saturation"])),
            })
    count = len(decisions)
    mean_delta = sum(float(row["selected_minus_fixed3"]) for row in decisions) / count
    summary = {
        "records": count,
        "mean_candidates": 14.0,
        "mean_selected_regret": sum(float(row["selected_regret"]) for row in decisions) / count,
        "mean_selected_minus_fixed3": mean_delta,
        "selected_wins_vs_fixed3": sum(float(row["selected_minus_fixed3"]) < 0 for row in decisions),
        "new_evm_failures": sum(int(row["new_evm_failure"]) for row in decisions),
        "new_aclr_failures": sum(int(row["new_aclr_failure"]) for row in decisions),
        "clip_or_saturation": sum(int(row["clip_or_saturation"]) for row in decisions),
    }
    summary["qualified"] = bool(mean_delta < 0 and
                                summary["new_evm_failures"] == 0 and
                                summary["new_aclr_failures"] == 0 and
                                summary["clip_or_saturation"] == 0)
    return {"summary": summary, "decisions": decisions}


def signed_u16(value: int) -> int:
    return value - 65536 if value >= 32768 else value


def average_coeff_word(values: list[str]) -> int:
    words = [int(value, 0) for value in values]
    real = round(sum(signed_u16(word & 0xFFFF) for word in words) / len(words))
    imag = round(sum(signed_u16((word >> 16) & 0xFFFF) for word in words) / len(words))
    return ((imag & 0xFFFF) << 16) | (real & 0xFFFF)


def full_mapping(rows: list[dict[str, object]]) -> list[dict[str, int | str]]:
    mapping = []
    for waveform_id in sorted({str(row["waveform_id"]) for row in rows}):
        qam, subcarriers, backoff_ppm = waveform_fields(waveform_id)
        base = [row for row in rows if row["waveform_id"] == waveform_id and
                row["seed_package"] == 0]
        mapping.append({"waveform_id": waveform_id,
                        "qam": qam, "used_subcarriers": subcarriers,
                        "input_backoff_ppm": backoff_ppm,
                        "package": choose_package(rows, waveform_id),
                        "c1_word": average_coeff_word([str(row["c1_hex"]) for row in base]),
                        "c3_word": average_coeff_word([str(row["c3_hex"]) for row in base]),
                        "c5_word": average_coeff_word([str(row["c5_hex"]) for row in base])})
    return mapping


def write_header(path: Path, mapping: list[dict[str, int | str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("#ifndef DSM_DPD_AI_POLICY_H\n#define DSM_DPD_AI_POLICY_H\n\n")
        handle.write("/* Simulation-qualified AI seed selection; real RF is not certified. */\n")
        handle.write("#define DSM_DPD_AI_POLICY_AVAILABLE 1U\n")
        handle.write("#define DSM_DPD_AI_POLICY_SIMULATION_ONLY 1U\n")
        handle.write("#define DSM_DPD_AI_POLICY_DIRECT_ALLOWED 0U\n")
        handle.write("#define DSM_DPD_AI_POLICY_FORCE_LOCAL_SEARCH 1U\n")
        handle.write("#define DSM_DPD_AI_POLICY_LOCAL_CANDIDATES 14U\n")
        handle.write("#define DSM_DPD_AI_POLICY_LOCAL_ROUNDS 1U\n")
        handle.write("#define DSM_DPD_AI_POLICY_LOCAL_STEP_Q214 64\n")
        handle.write(f"#define DSM_DPD_AI_POLICY_WAVEFORM_COUNT {len(mapping)}U\n\n")
        handle.write("static const int dsm_dpd_ai_seed_offsets[6][3] = {\n")
        for index, offset in enumerate(OFFSETS):
            suffix = "," if index + 1 < len(OFFSETS) else ""
            handle.write(f"    {{{offset[0]}, {offset[1]}, {offset[2]}}}{suffix}\n")
        handle.write("};\n\n")
        handle.write("static const unsigned dsm_dpd_ai_waveform_policy[8][7] = {\n")
        for index, item in enumerate(mapping):
            suffix = "," if index + 1 < len(mapping) else ""
            handle.write(f"    {{{item['qam']}U, {item['used_subcarriers']}U, "
                         f"{item['input_backoff_ppm']}U, {item['package']}U, "
                         f"0x{int(item['c1_word']):08X}U, "
                         f"0x{int(item['c3_word']):08X}U, "
                         f"0x{int(item['c5_word']):08X}U}}{suffix}\n")
        handle.write("};\n\n#endif /* DSM_DPD_AI_POLICY_H */\n")


def write_decisions(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", newline="", encoding="ascii") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def finalize(input_path: Path, out_dir: Path, header: Path,
             evm_limit: float, aclr_limit: float) -> dict[str, object]:
    rows = read_rows(input_path)
    out_dir.mkdir(parents=True, exist_ok=True)
    results = {}
    qualified = True
    for split in ("profile", "waveform", "seed"):
        result = evaluate_split(rows, split, evm_limit, aclr_limit)
        results[split] = result["summary"]
        qualified = qualified and bool(result["summary"]["qualified"])
        write_decisions(out_dir / f"dpd_ai_final_policy_{split}.csv", result["decisions"])
    mapping = full_mapping(rows)
    report = {
        "policy": "ai_seed_plus_mandatory_14_candidate_search",
        "simulation_only": True,
        "dsm_config_id": "efdsm_1bit_osr32_interp0",
        "direct_allowed": False,
        "local_candidates": 14,
        "splits": results,
        "waveform_mapping": mapping,
        "deployment_qualified": qualified,
    }
    with (out_dir / "dpd_ai_final_policy.json").open("w", encoding="ascii", newline="\n") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    if not qualified:
        raise ValueError("Final AI seed plus bounded-search policy did not qualify")
    write_header(header, mapping)
    return report


def self_test() -> None:
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        source = root / "input.csv"
        fields = sorted(REQUIRED)
        with source.open("w", newline="", encoding="ascii") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields)
            writer.writeheader()
            for profile in ("p0", "p1"):
                for waveform in ("qam16_bw20_bo058", "qam64_bw40_bo070"):
                    for seed in (1, 2):
                        for package in range(6):
                            row = {field: 0 for field in fields}
                            row.update({"profile_id": profile, "waveform_id": waveform,
                                        "simulation_seed": seed, "seed_package": package,
                                        "final_cost": 100 + abs(package - 2),
                                        "final_evm_pct": 1, "final_aclr_db": -30,
                                        "candidate_count_local": 14,
                                        "dsm_config_id": "efdsm_1bit_osr32_interp0",
                                        "c1_hex": "0x00004000", "c3_hex": "0x00000000",
                                        "c5_hex": "0x00000000"})
                            writer.writerow(row)
        report = finalize(source, root, root / "policy.h", 8.0, -20.0)
        assert report["deployment_qualified"] and not report["direct_allowed"]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path)
    parser.add_argument("--out-dir", type=Path)
    parser.add_argument("--header", type=Path)
    parser.add_argument("--evm-limit-pct", type=float, default=8.0)
    parser.add_argument("--aclr-limit-dbc", type=float, default=-20.0)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("AI calibration finalizer self-test passed")
        return 0
    if args.input is None or args.out_dir is None or args.header is None:
        parser.error("--input, --out-dir, and --header are required")
    report = finalize(args.input, args.out_dir, args.header,
                      args.evm_limit_pct, args.aclr_limit_dbc)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
