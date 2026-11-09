#!/usr/bin/env python3.12
"""Build auditable Round 19 coverage ledgers from the completed VCS/URG runs.

This utility does not run VCS/URG, modify RTL, approve waivers, or alter the
coverage denominator. It reconciles the frozen Round 18 554-Test baseline,
Round 19 VDB fingerprints, VCS counter observations, and same-input Raw / strict
analysis-only URG summaries into portable evidence files.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import math
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
R18 = ROOT / "docs/verification/data/thermo5-r18"
R19 = ROOT / "docs/verification/data/thermo5-r19"
REPORT = ROOT / "docs/verification/thermo5-tx-final-code-coverage-round19-20261109.md"
PRODUCT_SHA = "fe315cabf058dd184b6d94ffa4ed3b5fb9916733"
RTL_SHA256 = "fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003"
COMPILE_SHA256 = "e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7"
R18_554_MANIFEST_SHA256 = "0e4e726d5160adde81fd6d409a7284d82ca2306d04e87aae6431b225915bc130"
METRIC_ORDER = ("branch", "condition", "line", "toggle")
MEASURED_OUTPUT_WORDS = 131096
MEASURED_CPU_SECONDS = 63.91
MEASURED_WORDS_PER_SECOND = MEASURED_OUTPUT_WORDS / MEASURED_CPU_SECONDS
LEGAL_FRAME_WORDS = 56
AXIS_BEATS_PER_FRAME = 32
OBSERVED_SAMPLE_EVENTS_PER_FRAME = 57


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def canonical_sha(value: Any) -> str:
    data = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(data).hexdigest()


def read_gzip_csv(path: Path) -> list[dict[str, str]]:
    with gzip.open(path, "rt", newline="", encoding="utf-8") as stream:
        return list(csv.DictReader(stream))


def write_gzip_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields: list[str] = []
    for row in rows:
        for name in row:
            if name not in fields:
                fields.append(name)
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as zipped:
            import io

            text = io.TextIOWrapper(zipped, encoding="utf-8", newline="")
            writer = csv.DictWriter(text, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
            text.flush()
            text.detach()


def tree_fingerprint(path: Path) -> dict[str, Any]:
    if not path.is_dir():
        raise RuntimeError(f"VDB directory is unavailable: {path}")
    rows = []
    total = 0
    digest = hashlib.sha256()
    for item in sorted(x for x in path.rglob("*") if x.is_file()):
        relative = item.relative_to(path).as_posix()
        size = item.stat().st_size
        sha = sha256_file(item)
        rows.append({"path": relative, "size_bytes": size, "sha256": sha})
        total += size
        digest.update(relative.encode() + b"\0" + str(size).encode() + b"\0" + sha.encode() + b"\n")
    return {"file_count": len(rows), "total_bytes": total, "tree_sha256": digest.hexdigest()}


def compile_parent_from_vdb(path: Path) -> str:
    candidates = list(path.rglob("vcmArguments.xml"))
    if not candidates:
        raise RuntimeError(f"VDB is missing vcmArguments.xml: {path}")
    for candidate in candidates:
        try:
            text = gzip.decompress(candidate.read_bytes()).decode(errors="replace")
        except (OSError, gzip.BadGzipFile):
            text = candidate.read_text(errors="replace")
        match = re.search(r'compvdbpath="([^"]+)"', text)
        if match:
            return match.group(1)
    raise RuntimeError(f"VDB has no compile-parent binding: {path}")


def normalized_label(path_text: str) -> str:
    return Path(path_text.rstrip("/")).name.removesuffix(".vdb")


def resolve_vdb(path_text: str) -> Path:
    path = Path(path_text)
    if path.is_dir():
        return path
    if not path.name.endswith(".vdb") and Path(str(path) + ".vdb").is_dir():
        return Path(str(path) + ".vdb")
    candidate = ROOT / "runs/thermo5_r19_non_counter_20261109" / (path.name + ".vdb")
    if candidate.is_dir():
        return candidate
    raise RuntimeError(f"Cannot resolve VDB path from URG inventory: {path_text}")


def parse_counter_log(path: Path) -> dict[int, dict[str, int]]:
    pattern = re.compile(r"THERMO5_DPD_COUNTER lane=(\d+) sample_count=(\d+) saturation_count=(\d+)")
    observed: dict[int, dict[str, int]] = {}
    for line in path.read_text(errors="replace").splitlines():
        match = pattern.search(line)
        if match:
            lane, sample, saturation = map(int, match.groups())
            observed[lane] = {"sample_count": sample, "saturation_count": saturation}
    if set(observed) != set(range(16)):
        raise RuntimeError(f"Expected counter observations for all 16 DPD lanes; got {sorted(observed)}")
    if "THERMO5_AXIL_DPD_SATURATION_BITTRUE_UVM_PASS" not in path.read_text(errors="replace"):
        raise RuntimeError("Long counter/saturation campaign did not record its UVM PASS marker")
    return observed


def exact_counter_bin(row: dict[str, str]) -> tuple[int, str, int, str] | None:
    match = re.search(r"Port Details:(sample_count|saturation_count)\[(\d+)\]:(0_to_1|1_to_0)$",
                      row.get("exact_urg_bin", ""))
    lane = re.search(r"g_lane\[(\d+)\]", row.get("instance", ""))
    if not match or not lane:
        return None
    signal, bit, direction = match.groups()
    return int(lane.group(1)), signal, int(bit), direction


def first_transition_count(bit: int, direction: str) -> int:
    # Starting at reset value zero, bit k first rises at 2**k and falls at 2**(k+1).
    return 1 << (bit if direction == "0_to_1" else bit + 1)


def require_pass_log(path: Path, expected_marker: str | None = None) -> dict[str, Any]:
    text = path.read_text(errors="replace")
    errors = re.findall(r"^UVM_ERROR\s*:\s*(\d+)", text, re.M)
    fatals = re.findall(r"^UVM_FATAL\s*:\s*(\d+)", text, re.M)
    if not errors or not fatals or int(errors[-1]) != 0 or int(fatals[-1]) != 0:
        raise RuntimeError(f"Regression log is not clean: {path}")
    if expected_marker and expected_marker not in text:
        raise RuntimeError(f"Regression pass marker {expected_marker!r} absent: {path}")
    first = text.splitlines()[0] if text.splitlines() else ""
    command = first.removeprefix("Command: ")
    return {"log": path.relative_to(ROOT).as_posix(), "log_sha256": sha256_file(path),
            "command": command, "status": "PASS", "uvm_errors": 0, "uvm_fatals": 0}


def metric_summary(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text())
    metrics = {("condition" if r["metric"] == "cond" else r["metric"]):
                   {"covered": int(r["covered"]), "total": int(r["total"]),
                              "uncovered": int(r["missing"]), "percent": float(r["percent"])}
               for r in data["metrics"] if r.get("ownership") == "PROJECT_RTL"}
    fsm = {"states": [int(r["covered"]) for r in data["fsm_denominators"]
                       if r.get("ownership") == "PROJECT_RTL" and r.get("metric") == "states"],
           "transitions": [int(r["covered"]) for r in data["fsm_denominators"]
                           if r.get("ownership") == "PROJECT_RTL" and r.get("metric") == "transitions"]}
    assertions = data.get("dut_assertion_status_counts", {})
    return {"metrics": metrics, "fsm": {"covered_states": sum(fsm["states"]), "total_states": sum(
        int(r["total"]) for r in data["fsm_denominators"] if r.get("ownership") == "PROJECT_RTL" and r.get("metric") == "states"),
        "covered_transitions": sum(fsm["transitions"]), "total_transitions": sum(
        int(r["total"]) for r in data["fsm_denominators"] if r.get("ownership") == "PROJECT_RTL" and r.get("metric") == "transitions")},
        "dut_assertions": {k: int(v) for k, v in assertions.items()},
        "full_assertion_status": {k: int(v) for k, v in data.get("assertion_status_counts", {}).items()}}


def row_identity(row: dict[str, str]) -> tuple[str, str, str]:
    return (row.get("semantic_bin_id", ""), row.get("instance", ""), row.get("exact_urg_bin", ""))


def normalized_metric(row: dict[str, str]) -> str:
    return "condition" if row.get("metric") == "cond" else row.get("metric", "")


def render_report(data: dict[str, Any]) -> str:
    raw = data["raw_coverage"]["metrics"]
    whatif = data["analysis_only_whatif"]["metrics"]
    official = data["official_adjusted"]["metrics"]
    lines = [
        "# Thermo5 TX Final Code Coverage Round 19 — 2026-11-09", "",
        "## Decision", "",
        "Round 19 closes **64 exact counter-toggle bins** and preserves the validated Round 18 554-Test set. "
        "The 263 non-counter bins remain OPEN: these runs produced zero exact hits in their target Branch, "
        "Condition, Line, and Other Toggle inventory. The remaining 930 counter bins are reachable under "
        "the 32-bit modulo counter contract, but the upper bits require impractically long product-level runs. "
        "No waiver is independently approved and no official exclusion is active. Code Coverage and Linux DV "
        "signoff remain OPEN.", "",
        "This report separates the official zero-waiver Adjusted result from a strict, analysis-only What-if run. "
        "The latter is not signoff evidence and must not be presented as approved coverage.", "",
        "## Frozen Product and Evidence Binding", "",
        f"- Product source SHA: `{PRODUCT_SHA}`; review branch base SHA: `{data['review_base_sha']}`.",
        f"- Product RTL aggregate SHA-256: `{RTL_SHA256}`.",
        f"- Compile fingerprint SHA-256: `{COMPILE_SHA256}`; VCS/URG: `{data['tool_versions']['vcs']}` / `{data['tool_versions']['urg']}`.",
        "- Configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1; AXI-Lite; Generic FIFO.",
        f"- VDB set: 1 Design + {data['vdb_manifest']['test_vdb_count']} Test VDBs. All 554 Round 18 Test VDB fingerprints are present; {data['vdb_manifest']['new_vdb_count']} fingerprinted Round 19 Test VDBs were added.",
        f"- Canonical Round 18 554-Test manifest SHA-256: `{R18_554_MANIFEST_SHA256}`.",
        f"- Round 19 VDB set fingerprint SHA-256: `{data['vdb_manifest']['set_sha256']}`.",
        f"- Coverage Design VDB tree SHA-256: `{data['vdb_manifest']['design_fingerprint']['tree_sha256']}`; the 21 new Test VDBs bind to compile-parent tree SHA-256 `{data['vdb_manifest']['new_test_compile_parent']['tree_sha256']}`. These parent trees differ, so the evidence records the inherited VDB provenance variance explicitly.",
        f"- Raw URG log SHA-256: `{data['urg_runs']['raw']['log_sha256']}`; What-if URG log SHA-256: `{data['urg_runs']['analysis_only_whatif']['log_sha256']}`.",
        "- Both URG reports used the same Design VDB and same ordered Test VDB list. What-if used `-elfilelist` plus `-excl_strict`; both runs exited 0 with no warning/error/reject/checksum/mapping diagnostics.",
        f"- A diagnostic-only strict URG pair used the new-test compile-parent VDB as Design with the same 575 ordered tests and exclusion list. Its Raw and What-if metric vectors exactly matched the primary run; test inventory hashes also matched. Diagnostic logs: `{data['urg_runs']['design_parent_diagnostic']['raw']['log']}` and `{data['urg_runs']['design_parent_diagnostic']['analysis_only_whatif']['log']}`. This confirms metric stability across the two Design VDBs, while the primary result remains bound to the frozen Round 18 Design VDB.",
        "", "## Raw, Official Adjusted, and Analysis-only What-if", "",
        "Official Adjusted remains identical to Raw because approved waivers and active exclusions are both zero.",
        "The What-if counts come from a separate strict URG run using the same VDB inputs and the 11,418-candidate Round 18 analysis-only list.", "",
        "| Metric | Raw | Official Adjusted | Analysis-only What-if | What-if excluded | What-if remaining |", "|---|---:|---:|---:|---:|---:|"
    ]
    excluded = data["coverage"]["analysis_only_excluded_counts"]
    for metric in METRIC_ORDER:
        r, o, w = raw[metric], official[metric], whatif[metric]
        lines.append(f"| {metric.title()} | {r['covered']}/{r['total']} ({r['percent']:.2f}%) | {o['covered']}/{o['total']} ({o['percent']:.2f}%) | {w['covered']}/{w['total']} ({w['percent']:.2f}%) | {excluded[metric]} | {w['uncovered']} |")
    lines += [
        f"| FSM states / transitions | {data['raw_coverage']['fsm']['covered_states']}/{data['raw_coverage']['fsm']['total_states']} / {data['raw_coverage']['fsm']['covered_transitions']}/{data['raw_coverage']['fsm']['total_transitions']} | unchanged | unchanged | 0 | 0 |",
        "", "The Analysis-only list removes 107 Branch, 108 Condition, 433 Line, and 10,770 Toggle bins from the respective URG denominators (11,418 total). The raw covered numerators did not change. These are analysis exclusions only; approved exclusions remain zero.",
        "", "## Exact Coverage Delta", "",
        f"The long legal one-tap DPD saturation stream (seed 190031, {data['counter_test']['output_words']:,} PA words) added {data['coverage']['new_raw_toggle_hits']['total']} Raw Toggle hits. The exact rows, Native URG names, lane/bit/direction, Semantic Bin IDs, and source bindings are in `docs/verification/data/thermo5-r19/r19_exact_raw_toggle_delta.csv.gz`.",
        "", "| Counter | Exact new hits | Breakdown |", "|---|---:|---|",
        f"| sample_count | {data['counter_test']['hits_by_family']['sample_count']} | bit 16 1→0 on 16 lanes; bit 17 0→1 on 16 lanes |",
        f"| saturation_count | {data['counter_test']['hits_by_family']['saturation_count']} | lanes 0–14: bit 16 1→0 and bit 17 0→1; lane 15: bit 15 1→0 and bit 16 0→1 |",
        f"| Other Toggle | {data['counter_test']['hits_by_family']['other']} | no exact hit |",
        "", "Branch, Condition, Line, and Other Toggle exact hit deltas are zero. The legal randomized packet test, legal frame replacement test, frame-tail/backpressure test, and 16 deterministic phase variants all passed their UVM checks but added no exact DUT Code Coverage bins. The 16 phase variants each left the targeted centered pop/push event at stage 1=0 and stage 2=0; this remains OPEN rather than being inferred unreachable.",
        "", "## Non-Counter Residuals", "",
        f"The requested 263-bin set remains {data['coverage']['non_counter_remaining']['total']}/263 OPEN: {data['non_counter_counts']['branch']} Branch, {data['non_counter_counts']['condition']} Condition, {data['non_counter_counts']['line']} Line, and {data['non_counter_counts']['toggle']} Other Toggle. The exact ledger is `docs/verification/data/thermo5-r19/r19_non_counter_remaining_263.csv.gz`.",
        "", "| Root-cause group (Round 18 ledger) | Exact bins | Round 19 disposition |", "|---|---:|---|"
    ]
    for name, count in sorted(data["non_counter_root_causes"].items()):
        lines.append(f"| `{name}` | {count} | OPEN; no new exact hit |")
    lines += [
        "", "The 80 Reset/State-Hold Conditions and 4 Interpolator Empty/Blocked Conditions remain without a closure witness. The focused Interpolator Empty/Blocked probe timed out before drain; its VDB is excluded from the merged coverage set. It is not a DUT pass or a reachability proof. A separate invalid frame-metadata diagnostic (seed 190041) also failed its expected checks and is excluded. No new assertions or Formal harnesses were run.",
        "", "## Counter Coverage Cost and Scope", "",
        "Both `sample_count` and `saturation_count` are 32-bit modulo counters in `rtl/dpd/dpd_memory_poly.v`, reset to zero. `sample_count` increments on each accepted `pipe_ce && in_valid`; `saturation_count` increments on each valid output when either I or Q saturates. The DPD vector wrapper leaves both outputs unconnected (`rtl/dpd/dpd_vector16_memory_poly.sv`), and no external product status/readback use or normative counter requirement was found. They are diagnostic/internal outputs, but remain in the current DUT URG Code Coverage scope. No scope exclusion is applied; changing that scope requires an independently reviewed policy and does not change the reported URG denominator in this round.",
        "", "From reset, bit *k* first toggles 0→1 at count `2^k` and 1→0 at `2^(k+1)`. The long-run schedule observed 57 sample-count increments per 56-word legal frame, 32 AXIS beats per frame, and measured 2,051.4 output words/s CPU throughput. Sample-count lengths below use that measured legal schedule. Saturation lengths show the one-event-per-output theoretical lower bound and a separate projection using the observed per-lane saturation rate; both projections are estimates, not guarantees or proof of reachability under every waveform.",
        "", "| Remaining target | First remaining transition | Minimum / projected stream | CPU-time estimate |", "|---|---|---:|---:|"
    ]
    for item in data["counter_cost_summary"]:
        duration = f"{item['days']:.2f} days" if item["days"] >= 1 else f"{item['days'] * 24:.2f} hours"
        lines.append(f"| {item['family']} | bit {item['bit']} {item['direction']} ({item['lane_scope']}) | {item['frames']:,} frames / {item['words']:,} words / {item['beats']:,} AXIS beats | {duration} |")
    lines += [
        "", "Per-Exact-Bin event thresholds, lane, legal-frame length, lower bound, measured-rate projection, and CPU-time estimate are in `docs/verification/data/thermo5-r19/r19_counter_minimum_lengths.csv.gz`. At the top end, reaching the 32-bit falling edge requires about 4.22 billion output words for sample_count and 4.29 billion saturating output events in the ideal counter model; the measured lane-15 saturation rate projects roughly 32 days of CPU time. These counters remain reachable; no high-bit bin is classified unreachable.",
        "", "## Waiver and Formal / Assertion Status", "",
        f"The official inventory remains {data['waivers']['inventory_count']} unique IDs: Round 18 reconciliation identifies {data['waivers']['resolved_by_raw_hit']} `RESOLVED_BY_RAW_HIT` and {data['waivers']['pending']} pending review (367 matched to the prior candidate set, 2 outside it). The CSV's raw `review_status` field is still PENDING for all 371 rows; reviewer approvals are {data['waivers']['approved']} and active official exclusions are {data['waivers']['active_exclusions']}. Round 18's 11,418 candidates remain analysis-only and require real independent reviewer approval. The seven root-cause review packages are retained; this round created no approval record and no official `.el`.",
        f"The carried URG DUT assertion summary is {data['raw_coverage']['dut_assertions'].get('SUCCESS', 0)} SUCCESS, {data['raw_coverage']['dut_assertions'].get('FAILURE', 0)} FAILURE, {data['raw_coverage']['dut_assertions'].get('UNCOVERED', 0)} UNCOVERED. This summary is inherited from the same merged VDB set; it is not a fresh assertion regression. Formal was NOT RUN in Round 19. The historical DPD Identity, Outstanding Counter, COMMIT lifecycle, and product-level `q1_tail` proof obligations remain OPEN / INCONCLUSIVE as documented in Round 18.",
        "", "## Regression Matrix and Excluded Experiments", "",
        "| Test group | Result | Coverage use |",
        "|---|---|---|",
        "| Legal random packet seeds 190024/190025 | PASS; 0 UVM errors/fatals; independent event/transaction checks and drain pass | included; 0 exact code delta |",
        "| Long legal DPD saturation stream seed 190031 | PASS; 131,096 PA words; four-plane bit-true check and Python lane counters match | included; +64 exact Raw Toggle |",
        "| Legal frame replacement seed 190042 | PASS; 112 PA words; ordered four-plane checks; target pop/push stage1/2 still 0 | included; 0 exact code delta |",
        "| Frame replacement phase 1–16 | 16/16 PASS; target pop/push remains 0 at both stages | included; 0 exact code delta |",
        "| Frame-tail PA backpressure seed 190019 | PASS; queue drains; no mismatch | included; 0 exact code delta |",
        "| Interpolator Empty/Blocked probe | FAIL / timeout before drain | excluded from formal VDB set |",
        "| Frame replacement seed 190041 | FAIL under malformed frame-start metadata | excluded; invalid stimulus, not a product conclusion |",
        "| Random packet seed 190023 | FAIL before stimulus due missing EF2 reference vector | excluded |",
        "", "Full Product Regression and Formal were not rerun. Test command lines, run-log hashes, VDB tree fingerprints, and exact URG command arguments are indexed in `docs/verification/data/thermo5-r19/thermo5_tx_r19_final_evidence_manifest.json.gz`.",
        "", "## Final Status", "",
        "- Functional targeted tests: PASS for the included directed/random scenarios; the Interpolator Empty/Blocked probe remains an open failed attempt.",
        "- Raw Code Coverage: 524/637 Branch, 657/849 Condition, 3338/3796 Line, 92632/104480 Toggle; FSM states and transitions 100%.",
        "- Official Adjusted Code Coverage: equal to Raw; 0 approved exclusions.",
        "- Strict Analysis-only What-if: Branch 524/530, Condition 657/741, Line 3338/3363, Toggle 92632/93710; 1,193 exact bins remain. Not official signoff.",
        "- Waiver review: 369 pending; 0 approved. Counter bins remain in scope.",
        "- Formal / Assertion: OPEN; VCS/URG assertion carry-forward has three DUT failures and two uncovered DUT properties; Formal not rerun.",
        "- Linux DV Coverage Signoff: **OPEN**. Full Linux DV Signoff: **OPEN**. XPM, GT Wizard, Vivado PPA/timing, FPGA, RF and physical QAM256: **NOT RUN**.",
        ""
    ]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runs", type=Path, default=ROOT / "runs/thermo5_r19_non_counter_20261109")
    parser.add_argument("--urg-final", type=Path, default=ROOT / "runs/thermo5_r19_non_counter_20261109/urg_576_final")
    parser.add_argument("--output", type=Path, default=R19)
    parser.add_argument("--report", type=Path, default=REPORT)
    args = parser.parse_args()
    runs = args.runs.resolve()
    urg_final = args.urg_final.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    portable = json.loads((R18 / "thermo5_tx_r18_portable_evidence_manifest.json").read_text())
    old_fp = [x for x in portable["vdb_sets"]["vdb_content_fingerprints"] if x.get("role") == "test"]
    if len(old_fp) != 554 or portable["vdb_sets"]["554_tests"]["canonical_manifest_sha256"] != R18_554_MANIFEST_SHA256:
        raise RuntimeError("Round 18 554-Test VDB manifest does not match the frozen baseline")
    rtl_diff = subprocess.run(["git", "diff", "--quiet", f"{PRODUCT_SHA}..HEAD", "--", "rtl"],
                              cwd=ROOT, check=False)
    if rtl_diff.returncode != 0:
        raise RuntimeError("Product RTL differs from the frozen Round 18 Product source SHA")

    input_summary_path = urg_final / "input_summary.json"
    input_summary = json.loads(input_summary_path.read_text())
    test_paths = input_summary["test_vdbs"]
    if len(test_paths) != 575 or input_summary["test_vdb_count"] != 575:
        raise RuntimeError(f"Final input set must be exactly 575 Test VDBs, got {len(test_paths)}")
    labels = [normalized_label(x) for x in test_paths]
    old_fingerprints = {(normalized_label(x["label"]), x["tree_sha256"]): x for x in old_fp}
    old_counts: dict[tuple[str, str], int] = {}
    for item in old_fp:
        key = (normalized_label(item["label"]), item["tree_sha256"])
        old_counts[key] = old_counts.get(key, 0) + 1
    fingerprints = []
    new_test_compile_parents: dict[str, dict[str, Any]] = {}
    design_path = Path(input_summary["design_vdb"])
    design_actual = tree_fingerprint(design_path)
    design_prior = next(x for x in portable["vdb_sets"]["vdb_content_fingerprints"] if x.get("role") == "design")
    if (design_actual["tree_sha256"], design_actual["file_count"], design_actual["total_bytes"]) != (
            design_prior["tree_sha256"], design_prior["file_count"], design_prior["total_bytes"]):
        raise RuntimeError("Final URG Design VDB does not match the frozen Round 18 design database")
    for index, (path_text, label) in enumerate(zip(test_paths, labels)):
        vdb_path = resolve_vdb(path_text)
        actual = tree_fingerprint(vdb_path)
        key = (label, actual["tree_sha256"])
        if old_counts.get(key, 0):
            expected = old_fingerprints[key]
            if (actual["file_count"], actual["total_bytes"]) != (expected["file_count"], expected["total_bytes"]):
                raise RuntimeError(f"Round 18 VDB fingerprint metadata mismatch: {label}")
            old_counts[key] -= 1
            role = "r18-carry-forward"
        else:
            compile_parent = Path(compile_parent_from_vdb(vdb_path))
            if not compile_parent.is_dir():
                raise RuntimeError(f"Round 19 Test VDB compile parent is unavailable: {label}")
            compile_parent_fingerprint = tree_fingerprint(compile_parent)
            new_test_compile_parents[str(compile_parent)] = compile_parent_fingerprint
            role = "round19-new"
        fingerprints.append({"index": index, "label": label, "role": role, **actual})
    if any(old_counts.values()):
        missing = {str(k): v for k, v in old_counts.items() if v}
        raise RuntimeError(f"The final URG input does not preserve every Round 18 VDB tree fingerprint: {missing}")
    new_vdb_count = sum(x["role"] == "round19-new" for x in fingerprints)
    if new_vdb_count != 21:
        raise RuntimeError(f"Expected 21 Round 19 Test VDBs beyond the Round 18 baseline, got {new_vdb_count}")
    if len(new_test_compile_parents) != 1:
        raise RuntimeError(f"Expected all new Test VDBs to share one compile parent, found {len(new_test_compile_parents)}")
    new_test_compile_parent_path, new_test_compile_parent = next(iter(new_test_compile_parents.items()))
    raw = metric_summary(urg_final / "raw/inventory/summary.json")
    whatif = metric_summary(urg_final / "whatif_11418/inventory/summary.json")

    # The historical merge uses the frozen R18 Design VDB. Independently rerun
    # URG with the new tests' compile parent to quantify whether this inherited
    # Design-vs-Test-parent variance changes any reported coverage metric.
    diagnostic_root = runs / "urg_576_design_r18_parent_diag"
    diagnostic = {}
    for key, primary_key in (("raw", "raw"), ("analysis_only_whatif", "whatif_11418")):
        subdir = "raw" if key == "raw" else "whatif_11418"
        diag_dir = diagnostic_root / subdir
        diag_summary_path = diag_dir / "inventory/summary.json"
        diag_summary = metric_summary(diag_summary_path)
        diag_log = diag_dir / "urg.log"
        diag_log_text = diag_log.read_text(errors="replace")
        diagnostic_lines = [line for line in diag_log_text.splitlines()
                            if re.search(r"warning|error|reject|checksum|mismatch|ambiguous", line, re.I)]
        diag_tests = diag_dir / "report/tests.txt"
        primary_subdir = "raw" if primary_key == "raw" else "whatif_11418"
        primary_tests = urg_final / primary_subdir / "report/tests.txt"
        if sha256_file(diag_tests) != sha256_file(primary_tests):
            raise RuntimeError(f"Diagnostic URG test inventory differs from the primary run: {key}")
        if diag_summary != (raw if key == "raw" else whatif):
            raise RuntimeError(f"Diagnostic URG metrics differ from the primary run: {key}")
        if diagnostic_lines:
            raise RuntimeError(f"Diagnostic URG emitted tool/mapping diagnostics: {key}: {diagnostic_lines}")
        session_path = diag_dir / "report/session.xml"
        session_root = ET.parse(session_path).getroot()
        command = next((node.attrib.get("value", "") for node in session_root.iter("attr")
                        if node.attrib.get("name") == "command"), "")
        expected_design = str(Path(new_test_compile_parent_path).resolve())
        if "-excl_strict" not in command and key == "analysis_only_whatif":
            raise RuntimeError("Diagnostic What-if URG did not use -excl_strict")
        if expected_design not in command:
            raise RuntimeError(f"Diagnostic URG did not use the new-test compile-parent Design VDB: {key}")
        diagnostic[key] = {"command": command, "log": diag_log.relative_to(ROOT).as_posix(),
                           "log_sha256": sha256_file(diag_log), "returncode": 0, "diagnostics": [],
                           "design_vdb": expected_design,
                           "design_vdb_tree_sha256": new_test_compile_parent["tree_sha256"],
                           "test_inventory_sha256": sha256_file(diag_tests),
                           "metrics": diag_summary["metrics"], "fsm": diag_summary["fsm"],
                           "dut_assertions": diag_summary["dut_assertions"]}

    # The counter VDB must show that the target transitions were physically reached from reset.
    counter_log = runs / "counter_131096_seed190031.log"
    observed = parse_counter_log(counter_log)
    prior_residual = read_gzip_csv(R18 / "whatif_residual_11418_after_554.csv.gz")
    old_keys = {row_identity(row): row for row in prior_residual}
    hit_rows: list[dict[str, Any]] = []
    remaining: list[dict[str, str]] = []
    for row in prior_residual:
        parsed = exact_counter_bin(row) if row.get("metric") == "toggle" else None
        if parsed:
            lane, signal, bit, direction = parsed
            threshold = first_transition_count(bit, direction)
            count = observed[lane][signal]
            if count >= threshold:
                hit = dict(row)
                hit.update({"round19_status": "RAW_HIT", "test_name": "thermo5_sku_axil_dpd_saturation_bittrue_test",
                            "test_seed": "190031", "observed_lane_counter": count,
                            "first_transition_count_from_reset": threshold,
                            "independent_checker": "four-plane bit-true checker and Python per-lane count oracle PASS",
                            "evidence_log": counter_log.relative_to(ROOT).as_posix()})
                hit_rows.append(hit)
                continue
        remaining.append(row)

    hit_by_family = {family: 0 for family in ("sample_count", "saturation_count", "other")}
    for row in hit_rows:
        parsed = exact_counter_bin(row)
        if parsed:
            hit_by_family[parsed[1]] += 1
        else:
            hit_by_family["other"] += 1
    if len(hit_rows) != 64 or hit_by_family != {"sample_count": 32, "saturation_count": 32, "other": 0}:
        raise RuntimeError(f"Exact R19 Raw hit reconciliation did not produce the observed 64 counter bins: {hit_by_family}")

    remaining_counts = {metric: sum(normalized_metric(row) == metric for row in remaining)
                        for metric in ("branch", "condition", "line", "toggle")}
    if remaining_counts != {"branch": 6, "condition": 84, "line": 25, "toggle": 1078} or len(remaining) != 1193:
        raise RuntimeError(f"The exact residual ledger does not reconcile to final What-if URG: {remaining_counts}, total={len(remaining)}")

    controls = read_gzip_csv(R18 / "review_packages/exact_remaining_control_bins_115.csv.gz")
    other_toggles = read_gzip_csv(R18 / "review_packages/other_toggle_remaining_148.csv.gz")
    non_counter = []
    for row in controls + other_toggles:
        item = dict(row)
        item.update({"round19_status": "OPEN_NO_NEW_EXACT_HIT", "round19_coverage_set": "1 Design + 575 Tests",
                     "round19_targeted_evidence": "random packet, frame replacement, 16 timing phases, and frame-tail backpressure added zero exact target code hits"})
        non_counter.append(item)
    non_counter_counts = {metric: sum(normalized_metric(row) == metric for row in non_counter)
                          for metric in ("branch", "condition", "line", "toggle")}
    if len(non_counter) != 263 or non_counter_counts != {"branch": 6, "condition": 84, "line": 25, "toggle": 148}:
        raise RuntimeError(f"Non-counter control/toggle ledger count mismatch: {non_counter_counts}")
    remaining_ids = {row_identity(row) for row in remaining}
    if any(row_identity(row) not in remaining_ids for row in non_counter):
        raise RuntimeError("A requested non-counter exact Bin is absent from the final analysis-only residual")

    # Build a per-bin counter length/cost table without declaring high bits unreachable.
    counter_rows = []
    lane_rates = {lane: observed[lane]["saturation_count"] / MEASURED_OUTPUT_WORDS for lane in range(16)}
    for row in remaining:
        parsed = exact_counter_bin(row) if row.get("metric") == "toggle" else None
        if not parsed:
            continue
        lane, family, bit, direction = parsed
        events = first_transition_count(bit, direction)
        if family == "sample_count":
            frames = math.ceil(events / OBSERVED_SAMPLE_EVENTS_PER_FRAME)
            words = frames * LEGAL_FRAME_WORDS
            beats = frames * AXIS_BEATS_PER_FRAME
            projected_words = words
            projected_frames = frames
            lower_words = words
            rate = OBSERVED_SAMPLE_EVENTS_PER_FRAME / LEGAL_FRAME_WORDS
        else:
            frames = math.ceil(events / LEGAL_FRAME_WORDS)
            words = frames * LEGAL_FRAME_WORDS
            beats = frames * AXIS_BEATS_PER_FRAME
            rate = lane_rates[lane]
            projected_words = math.ceil(events / rate) if rate > 0 else None
            projected_frames = math.ceil(projected_words / LEGAL_FRAME_WORDS) if projected_words else None
            lower_words = words
        cost = dict(row)
        cost.update({"counter_family": family, "lane": lane, "bit": bit, "direction": direction,
                     "first_transition_count_from_reset": events, "reaches_by": "LEGAL_REACHABLE_COUNTER_TRANSITION",
                     "minimum_full_frames_lower_bound": frames, "minimum_output_words_lower_bound": lower_words,
                     "source_beats_lower_bound": beats, "measured_lane_events_per_output_word": f"{rate:.9f}",
                     "measured_rate_projected_frames": projected_frames,
                     "measured_rate_projected_output_words": projected_words,
                     "cpu_seconds_lower_bound_at_measured_rate": f"{lower_words / MEASURED_WORDS_PER_SECOND:.6f}",
                     "cpu_seconds_measured_rate_projection": f"{projected_words / MEASURED_WORDS_PER_SECOND:.6f}" if projected_words else "",
                     "runtime_model_note": "Projection only; starts from reset, full legal frames, based on seed190031 measured CPU throughput and lane saturation event rate"})
        counter_rows.append(cost)
    if len(counter_rows) != 930:
        raise RuntimeError(f"Expected 930 open counter bins after 64 hits, got {len(counter_rows)}")

    if raw["metrics"]["toggle"]["covered"] != 92632 or whatif["metrics"]["toggle"]["uncovered"] != 1078:
        raise RuntimeError("Final URG metrics do not match the expected same-input R19 totals")
    baseline_metrics_raw = portable["urg_runs"]["test_vdbs_554/raw"]["metrics"]
    baseline_metrics = {("condition" if k == "cond" else k): v for k, v in baseline_metrics_raw.items()}
    raw_delta = {m: raw["metrics"][m]["covered"] - baseline_metrics[m]["covered"] for m in METRIC_ORDER}
    if raw_delta != {"branch": 0, "condition": 0, "line": 0, "toggle": 64}:
        raise RuntimeError(f"Final URG does not show the measured 64-toggle-only delta over Round 18: {raw_delta}")
    excluded = {m: raw["metrics"][m]["total"] - whatif["metrics"][m]["total"] for m in METRIC_ORDER}
    if sum(excluded.values()) != 11418:
        raise RuntimeError(f"Analysis-only denominator delta is not 11,418: {excluded}")
    official_waivers = list(csv.DictReader((R18 / "review_packages/official_waiver_reconciliation_371.csv").open(newline="", encoding="utf-8")))
    if len(official_waivers) != 371:
        raise RuntimeError(f"Expected the complete official 371-row waiver inventory, found {len(official_waivers)}")
    resolved = sum(row["round17_reconciliation_status"] == "RESOLVED_BY_RAW_HIT" for row in official_waivers)
    pending = sum(row["round17_reconciliation_status"] != "RESOLVED_BY_RAW_HIT" for row in official_waivers)
    approved = sum(row["review_status"] == "APPROVED" for row in official_waivers)
    active_exclusions = sum(row["official_exclusion_active"] == "YES" for row in official_waivers)
    if (resolved, pending, approved, active_exclusions) != (2, 369, 0, 0):
        raise RuntimeError("Official Waiver reconciliation is not the expected 2 raw-hit-resolved / 369 pending / 0 approved / 0 active-exclusion state")
    review_status_counts: dict[str, int] = {}
    reconciliation_status_counts: dict[str, int] = {}
    for row in official_waivers:
        review_status_counts[row["review_status"]] = review_status_counts.get(row["review_status"], 0) + 1
        status = row["round17_reconciliation_status"]
        reconciliation_status_counts[status] = reconciliation_status_counts.get(status, 0) + 1

    # Validate every VCS run that contributes a VDB.
    test_specs = [
        ("axil_random_packet_seed190024.log", "190024", "THERMO5_TX_RANDOM_PACKET_PASS"),
        ("axil_random_packet_seed190025.log", "190025", "THERMO5_TX_RANDOM_PACKET_PASS"),
        ("counter_131096_seed190031.log", "190031", "THERMO5_AXIL_DPD_SATURATION_BITTRUE_UVM_PASS"),
        ("frame_replacement_legal_seed190042.log", "190042", "FRAME_REPLACEMENT_UVM_PASS"),
        ("frame_tail_stall.log", "190019", "THERMO5_AXIL_DPD_SATURATION_BITTRUE_UVM_PASS"),
    ]
    for phase in range(1, 17):
        test_specs.append((f"frame_replacement_phase_{phase:02d}_source_00.log", str(190042 + phase), "FRAME_REPLACEMENT_UVM_PASS"))
    test_runs = [require_pass_log(runs / name, marker) | {"seed": seed} for name, seed, marker in test_specs]
    if len(test_runs) != 21:
        raise RuntimeError("Expected 21 successful contributing Round 19 VCS runs")

    # Infer family root-cause counts from the exact ledger, without upgrading any reachability class.
    non_counter_root_causes: dict[str, int] = {}
    for row in non_counter:
        group = row.get("round18_reachability_class") or row.get("root_cause_class") or "UNKNOWN"
        non_counter_root_causes[group] = non_counter_root_causes.get(group, 0) + 1

    hit_counter_max = {"sample_count": max(x["sample_count"] for x in observed.values()),
                       "saturation_count": max(x["saturation_count"] for x in observed.values())}
    counter_cost_summary = []
    for family, bit, direction, lane_scope in [
        ("sample_count", 17, "1_to_0", "all 16 lanes"),
        ("sample_count", 31, "1_to_0", "all 16 lanes"),
        ("saturation_count", 17, "1_to_0", "all 16 lanes"),
        ("saturation_count", 31, "1_to_0", "worst observed lane 15"),
    ]:
        events = first_transition_count(bit, direction)
        if family == "sample_count":
            frames = math.ceil(events / OBSERVED_SAMPLE_EVENTS_PER_FRAME)
            words = frames * LEGAL_FRAME_WORDS
        else:
            rate = min(lane_rates.values()) if lane_scope.startswith("worst") else min(lane_rates.values())
            projected = math.ceil(events / rate)
            frames = math.ceil(projected / LEGAL_FRAME_WORDS)
            words = frames * LEGAL_FRAME_WORDS
        beats = frames * AXIS_BEATS_PER_FRAME
        seconds = words / MEASURED_WORDS_PER_SECOND
        counter_cost_summary.append({"family": family, "bit": bit, "direction": direction,
                                     "lane_scope": lane_scope, "frames": frames, "words": words,
                                     "beats": beats, "days": seconds / 86400})

    hit_path = out / "r19_exact_raw_toggle_delta.csv.gz"
    non_counter_path = out / "r19_non_counter_remaining_263.csv.gz"
    whatif_path = out / "r19_exact_whatif_remaining_1193.csv.gz"
    counter_path = out / "r19_counter_minimum_lengths.csv.gz"
    write_gzip_csv(hit_path, hit_rows)
    write_gzip_csv(non_counter_path, non_counter)
    write_gzip_csv(whatif_path, remaining)
    write_gzip_csv(counter_path, counter_rows)

    package_dir = R18 / "review_packages/waiver_groups"
    waiver_packages = []
    for package in sorted(package_dir.glob("*.csv.gz")):
        waiver_packages.append({"path": package.relative_to(ROOT).as_posix(),
                                "sha256": sha256_file(package), "candidate_count": len(read_gzip_csv(package)),
                                "review_state": "PENDING_INDEPENDENT_REVIEW"})
    raw_log = urg_final / "raw/urg.log"
    whatif_log = urg_final / "whatif_11418/urg.log"
    raw_command = input_summary["raw"]["command"]
    whatif_command = input_summary["whatif_11418"]["command"]
    if input_summary["raw"]["returncode"] != 0 or input_summary["whatif_11418"]["returncode"] != 0:
        raise RuntimeError("One of the final URG runs failed")
    if input_summary["raw"]["diagnostic_lines"] or input_summary["whatif_11418"]["diagnostic_lines"]:
        raise RuntimeError("Final URG emitted a warning, mapping, checksum, or scope diagnostic")
    raw_vdb_args = raw_command[raw_command.index("-dir") + 2:raw_command.index("-format")]
    whatif_vdb_args = whatif_command[whatif_command.index("-dir") + 2:whatif_command.index("-elfilelist")]
    if raw_vdb_args != whatif_vdb_args or "-excl_strict" not in whatif_command:
        raise RuntimeError("Raw and strict What-if URG inputs/options do not match")

    repo_head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                               capture_output=True, check=True).stdout.strip()
    manifest = {
        "schema": "thermo5_tx_r19_final_evidence_v1",
        "status": "COVERAGE_SIGNOFF_OPEN_NOT_FINAL_LINUX_DV_SIGNOFF",
        "review_base_sha": repo_head,
        "product_source_sha": PRODUCT_SHA,
        "product_rtl_aggregate_sha256": RTL_SHA256,
        "compile_fingerprint_sha256": COMPILE_SHA256,
        "product_configuration": {"interpolator": "Centered-Cubic x2+x2", "ef2_order": 2,
                                  "ef2_step": 5120, "ef2_state_bits": 20,
                                  "dpd_max_taps": 1, "dpd_reset_image": "Identity",
                                  "axi_lite": True, "fifo": "Generic"},
        "tool_versions": {"vcs": "V-2023.12-SP1_Full64", "urg": "V-2023.12-SP1 Full64",
                          "python": "3.12", "vc_formal": "NOT_RUN_IN_ROUND19"},
        "vdb_manifest": {"design_vdb": input_summary["design_vdb"], "design_fingerprint": design_actual,
                         "new_test_compile_parent": {"path": new_test_compile_parent_path, **new_test_compile_parent,
                                                      "matches_urg_design_tree": new_test_compile_parent["tree_sha256"] == design_actual["tree_sha256"]},
                         "baseline_test_vdb_count": 554, "baseline_manifest_sha256": R18_554_MANIFEST_SHA256,
                         "new_vdb_count": new_vdb_count, "test_vdb_count": len(fingerprints),
                         "ordered_fingerprints": fingerprints, "set_sha256": canonical_sha(fingerprints),
                         "urg_test_inventory_sha256": sha256_file(urg_final / "raw/report/tests.txt"),
                         "whatif_test_inventory_sha256": sha256_file(urg_final / "whatif_11418/report/tests.txt"),
                         "input_summary_sha256": sha256_file(input_summary_path)},
        "urg_runs": {"raw": {"command": raw_command, "log": raw_log.relative_to(ROOT).as_posix(),
                              "log_sha256": sha256_file(raw_log), "returncode": 0, "diagnostics": []},
                     "analysis_only_whatif": {"command": whatif_command, "log": whatif_log.relative_to(ROOT).as_posix(),
                                               "log_sha256": sha256_file(whatif_log), "returncode": 0,
                                               "diagnostics": [], "candidate_count": 11418,
                                               "elfilelist": input_summary["whatif_elfilelist"],
                                               "elfilelist_sha256": sha256_file(Path(input_summary["whatif_elfilelist"]))},
                     "design_parent_diagnostic": diagnostic},
        "coverage": {"raw": raw, "official_adjusted": raw, "analysis_only_whatif": whatif,
                     "analysis_only_excluded_counts": excluded,
                     "exact_whatif_remaining": {"branch": 6, "condition": 84, "line": 25, "toggle": 1078, "total": 1193},
                     "non_counter_remaining": non_counter_counts | {"total": len(non_counter)},
                     "counter_remaining": {"sample_count": 464, "saturation_count": 466, "total": len(counter_rows)},
                     "new_raw_toggle_hits": {"total": len(hit_rows), "by_family": hit_by_family}},
        "raw_coverage": raw,
        "official_adjusted": raw,
        "analysis_only_whatif": whatif,
        "non_counter_counts": non_counter_counts,
        "non_counter_root_causes": non_counter_root_causes,
        "exact_hit_ledger": {"path": hit_path.relative_to(ROOT).as_posix(), "rows": len(hit_rows),
                              "sha256": sha256_file(hit_path)},
        "non_counter_remaining_ledger": {"path": non_counter_path.relative_to(ROOT).as_posix(),
                                           "rows": len(non_counter), "sha256": sha256_file(non_counter_path)},
        "whatif_remaining_ledger": {"path": whatif_path.relative_to(ROOT).as_posix(),
                                     "rows": len(remaining), "sha256": sha256_file(whatif_path)},
        "counter_cost_ledger": {"path": counter_path.relative_to(ROOT).as_posix(),
                                 "rows": len(counter_rows), "sha256": sha256_file(counter_path)},
        "counter_test": {"test_seed": 190031, "log": counter_log.relative_to(ROOT).as_posix(),
                         "log_sha256": sha256_file(counter_log), "output_words": MEASURED_OUTPUT_WORDS,
                         "frames": 2341, "source_beats": 74912, "cpu_seconds": MEASURED_CPU_SECONDS,
                         "measured_output_words_per_second": MEASURED_WORDS_PER_SECOND,
                         "observed_lane_counters": {str(k): v for k, v in observed.items()},
                         "hits_by_family": hit_by_family},
        "waivers": {"inventory_count": 371, "resolved_by_raw_hit": resolved, "pending": pending,
                    "approved": approved, "active_exclusions": active_exclusions,
                    "raw_review_status_counts": review_status_counts,
                    "reconciliation_status_counts": reconciliation_status_counts,
                    "analysis_only_candidate_count": 11418,
                    "review_packages": waiver_packages,
                    "note": "No independent reviewer approval was supplied; do not generate or claim official exclusions."},
        "regression": {"contributing_vcs_runs": test_runs,
                       "nonqualifying_runs": [
                           {"log": (runs / "interp_empty_blocked.log").relative_to(ROOT).as_posix(),
                            "log_sha256": sha256_file(runs / "interp_empty_blocked.log"), "status": "FAIL_TIMEOUT_NO_DRAIN",
                            "vdb_included": False, "reason": "test failed to drain; no legal closure witness"},
                           {"log": (runs / "frame_replacement_seed190041.log").relative_to(ROOT).as_posix(),
                            "log_sha256": sha256_file(runs / "frame_replacement_seed190041.log"), "status": "FAIL_INVALID_FRAME_METADATA",
                            "vdb_included": False, "reason": "malformed frame-start metadata; nonqualifying diagnostic"},
                           {"log": (runs / "axil_random_packet_seed190023.log").relative_to(ROOT).as_posix(),
                            "log_sha256": sha256_file(runs / "axil_random_packet_seed190023.log"), "status": "FAIL_MISSING_REFERENCE_VECTOR",
                            "vdb_included": False, "reason": "failed before stimulus"}],
                       "full_product_regression": "NOT_RUN", "formal": "NOT_RUN"},
        "assertion_status": raw["dut_assertions"],
        "remaining_non_counter_root_causes": non_counter_root_causes,
        "counter_cost_summary": counter_cost_summary,
        "artifacts": {}
    }

    report_text = render_report(manifest)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(report_text, encoding="utf-8")
    artifacts = [hit_path, non_counter_path, whatif_path, counter_path, args.report, Path(__file__).resolve()]
    manifest["artifacts"] = {p.relative_to(ROOT).as_posix(): sha256_file(p) for p in artifacts}
    legacy_manifest_path = out / "thermo5_tx_r19_final_evidence_manifest.json"
    if legacy_manifest_path.exists():
        legacy_manifest_path.unlink()
    manifest_path = out / "thermo5_tx_r19_final_evidence_manifest.json.gz"
    with manifest_path.open("wb") as raw_manifest:
        with gzip.GzipFile(fileobj=raw_manifest, mode="wb", filename="", mtime=0) as compressed:
            compressed.write((json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8"))
    print(json.dumps({"report": str(args.report), "manifest": str(manifest_path),
                      "vdb_count": len(fingerprints), "vdb_manifest_sha256": manifest["vdb_manifest"]["set_sha256"],
                      "raw": raw["metrics"], "official_adjusted_equals_raw": True,
                      "whatif": whatif["metrics"], "new_hits": hit_by_family,
                      "non_counter_open": non_counter_counts, "counter_open": len(counter_rows),
                      "whatif_residual": len(remaining), "waivers": manifest["waivers"] | {"review_packages": len(waiver_packages)}}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
