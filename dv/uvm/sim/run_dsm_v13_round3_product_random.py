#!/usr/bin/env python3
"""Run constrained-random regressions on the three DSM V1.3 Product tops."""

from __future__ import annotations

import argparse
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import random
import re
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
GENERATOR = ROOT / "dv" / "uvm" / "refmodel" / "python" / "generate_thermo5_frontend_vectors.py"
COVERAGE_HIER = SIM_DIR / "dsm_v13_product_dut_coverage.hier"
SKUS = {
    "ef1": {"arch": 1, "step": 7168, "order": 1, "mode": "tidsm"},
    "ef2": {"arch": 2, "step": 5120, "order": 2, "mode": "tidsm"},
    "mash11": {"arch": 3, "step": 5120, "order": 2, "mode": "mash11"},
}
CAMPAIGNS = ("smoke", "scenario", "reset", "hole_directed", "stress")
PROFILES = {
    "smoke": ("random", "extreme"),
    "scenario": ("random", "range_stress", "ef2_saturation"),
    "reset": ("extreme", "range_stress"),
    "hole_directed": ("range_stress", "ef2_saturation", "extreme"),
    "stress": ("random", "range_stress"),
}
BEATS = {"smoke": 512, "scenario": 1024, "reset": 512,
         "hole_directed": 1024, "stress": 100000}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command: list[str], *, cwd: Path, log_path: Path | None = None) -> tuple[int, str, float]:
    started = time.monotonic()
    result = subprocess.run(command, cwd=cwd, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=False)
    duration = round(time.monotonic() - started, 3)
    if log_path:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(result.stdout, encoding="utf-8")
    return result.returncode, result.stdout, duration


def packet_metadata(packet_count: int, seed: int) -> tuple[list[int], list[int]]:
    rng = random.Random(seed ^ 0x44534D33)
    starts: list[int] = []
    gains: list[int] = []
    choices = (12288, 14336, 16384, 18432)
    for packet in range(packet_count):
        base = packet * 56
        for local in (1, 15, 36):
            starts.append(base + local)
            gains.append(rng.choice(choices))
    return starts, gains


class _UrgTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag == "tr":
            self._row = []
        elif tag == "td" and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "td" and self._cell is not None and self._row is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def dut_metrics(report_dir: Path) -> dict[str, float]:
    path = report_dir / "hierarchy.html"
    if not path.is_file():
        return {}
    parser = _UrgTableParser()
    parser.feed(path.read_text(encoding="utf-8", errors="replace"))
    for row in parser.rows:
        if row and row[0].strip() == "dut" and len(row) >= 8:
            names = ("score", "line", "condition", "toggle", "fsm", "branch", "assertion")
            values: dict[str, float] = {}
            for name, value in zip(names, row[1:8]):
                try:
                    values[name] = float(value)
                except ValueError:
                    continue
            return values
    return {}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "dsm_v13_round3" / "product_random")
    parser.add_argument("--only-sku", choices=tuple(SKUS))
    parser.add_argument("--smoke-seeds", type=int, default=10)
    parser.add_argument("--scenario-seeds", type=int, default=30)
    parser.add_argument("--reset-seeds", type=int, default=20)
    parser.add_argument("--hole-directed-seeds", type=int, default=20)
    parser.add_argument("--stress-seeds", type=int, default=2)
    parser.add_argument("--seed-base", type=int, default=330000)
    parser.add_argument("--compile-only", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    parser.add_argument("--urg", default=os.environ.get("URG"))
    args = parser.parse_args()
    budgets = {"smoke": args.smoke_seeds, "scenario": args.scenario_seeds,
               "reset": args.reset_seeds, "hole_directed": args.hole_directed_seeds,
               "stress": args.stress_seeds}
    if any(value < 0 for value in budgets.values()):
        parser.error("seed counts must be nonnegative")
    if not args.compile_only and sum(budgets.values()) == 0:
        parser.error("at least one campaign seed is required")

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    selected = [args.only_sku] if args.only_sku else list(SKUS)
    summary = {
        "schema": "dsm_v13_round3_product_random_v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "source_revision": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "campaign_plan": {
            name: {"seeds": budgets[name], "beats_per_seed": BEATS[name]}
            for name in CAMPAIGNS
        },
        "sku_results": {}, "status": "IN_PROGRESS",
    }
    summary_path = out / "regression_summary.json"

    for sku_index, name in enumerate(selected):
        config = SKUS[name]
        sku_out = out / name
        build = sku_out / "build"
        preflight = sku_out / "preflight_vectors"
        record = {"configuration": config, "top_mode": "Product (AXI-Lite absent)",
                  "compile_status": "NOT_RUN", "campaigns": [],
                  "urg_batches": []}
        summary["sku_results"][name] = record
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

        preflight_command = [sys.executable, str(GENERATOR), "--output-dir", str(preflight),
            "--words", "56", "--seed", str(args.seed_base + 900000 + sku_index),
            "--interp-mode", "centered_cubic", "--dpd-profile", "identity",
            "--step", str(config["step"]), "--tidsm-order", str(config["order"]),
            "--dsm-mode", config["mode"], "--frame-start-words", "1,15,36",
            "--frame-gains", "16384,14336,12288"]
        code, output, seconds = run(preflight_command, cwd=ROOT,
                                    log_path=sku_out / "preflight_vectors.log")
        record["preflight"] = {"returncode": code, "seconds": seconds,
                               "command": shlex.join(preflight_command)}
        if code:
            record["compile_status"] = "BLOCKED_VECTOR_GENERATION"
            record["preflight_log_tail"] = output.splitlines()[-40:]
            summary["status"] = "BLOCKED_VECTOR_GENERATION"
            summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
            return 2

        compile_command = ["make", "-C", str(SIM_DIR), "thermo5-vcs",
            "THERMO5_USE_AXIL=0", "THERMO5_CENTERED_CUBIC=1", "THERMO5_DPD_MAX_TAPS=1",
            "THERMO5_TIDSM_ORDER=" + str(config["order"]),
            "THERMO5_STEP=" + str(config["step"]), "THERMO5_TOP=dsm_v13_multi_sku_uvm_tb",
            "THERMO5_TOP_ARGS=-pvalue+dsm_v13_multi_sku_uvm_tb.DSM_ARCH=" + str(config["arch"]),
            "THERMO5_OUT=" + str(build), "THERMO5_VECTORS=" + str(preflight),
            "THERMO5_COV_HIER=" + str(COVERAGE_HIER)]
        code, output, seconds = run(compile_command, cwd=ROOT,
                                    log_path=sku_out / "compile.log")
        record["compile_seconds"] = seconds
        record["compile_command"] = shlex.join(compile_command)
        simv = build / "simv"
        if code or not simv.is_file():
            record["compile_status"] = "FAIL" if code else "MISSING_SIMV"
            record["compile_log_tail"] = output.splitlines()[-50:]
            summary["status"] = "COMPILE_FAIL"
            summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
            return 2
        record["compile_status"] = "PASS"
        if args.compile_only:
            continue

        case_index = 0
        previous_metrics: dict[str, float] | None = None
        for campaign in CAMPAIGNS:
            campaign_cases: list[dict] = []
            for index in range(budgets[campaign]):
                seed = args.seed_base + sku_index * 1000000 + case_index
                case_index += 1
                beats = BEATS[campaign]
                words = beats * 7 // 4
                if beats % 32 or words % 56:
                    raise RuntimeError("Product random budget must align to 32-beat/56-word frame quanta")
                packet_count = beats // 32
                starts, gains = packet_metadata(packet_count, seed)
                phases = random.Random(seed ^ 0x43505233)
                source_phase = phases.randrange(0, 8000)
                profile = PROFILES[campaign][index % len(PROFILES[campaign])]
                vector_dir = sku_out / "vectors" / ("seed_%d" % seed)
                log_path = sku_out / "logs" / ("seed_%d.log" % seed)
                vdb = sku_out / "vdb" / ("seed_%d.vdb" % seed)
                generate_command = [sys.executable, str(GENERATOR), "--output-dir", str(vector_dir),
                    "--words", str(words), "--seed", str(seed), "--profile", profile,
                    "--interp-mode", "centered_cubic", "--dpd-profile", "identity",
                    "--step", str(config["step"]), "--tidsm-order", str(config["order"]),
                    "--dsm-mode", config["mode"], "--frame-start-words", ",".join(map(str, starts)),
                    "--frame-gains", ",".join(map(str, gains))]
                code, output, gen_seconds = run(generate_command, cwd=ROOT)
                if code:
                    raise RuntimeError("vector generation failed SKU=%s seed=%d: %s" %
                                       (name, seed, output[-2000:]))
                sim_command = [str(simv), "+UVM_TESTNAME=thermo5_sku_product_random_test",
                    "+VEC_DIR=" + str(vector_dir), "+CORE_WORDS=" + str(words),
                    "+ntb_random_seed=" + str(seed), "+THERMO5_RANDOM_SOURCE_GAP_MAX=4",
                    "+THERMO5_RANDOM_PA_STALL_PERCENT=25",
                    "+SOURCE_CLOCK_PHASE_PS=" + str(source_phase), "-cm",
                    "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(vdb),
                    "-no_save", "-l", str(log_path)]
                if campaign == "reset":
                    sim_command.insert(2, "+THERMO5_RANDOM_RESET_CASE")
                log_path.parent.mkdir(parents=True, exist_ok=True)
                code, output, sim_seconds = run(sim_command, cwd=ROOT, log_path=log_path)
                match = re.search(r"DSM_V13_PRODUCT_(?:RANDOM|RESET_RANDOM)_PASS source=(\d+) PA=(\d+) TLAST=(\d+)", output)
                if code or not match or re.search(r"UVM_ERROR\s*:\s*[1-9]|UVM_FATAL\s*:\s*[1-9]", output):
                    record["failure"] = {"campaign": campaign, "seed": seed,
                        "returncode": code, "log": str(log_path),
                        "log_sha256": sha256(log_path) if log_path.is_file() else ""}
                    summary["status"] = "SIMULATION_FAIL"
                    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
                    raise RuntimeError("Product random simulation failed SKU=%s campaign=%s seed=%d log=%s" %
                                       (name, campaign, seed, log_path))
                source_count, pa_count, tlast_count = map(int, match.groups())
                if source_count != beats or pa_count != words or tlast_count != 1:
                    raise RuntimeError("Product random conservation failed SKU=%s seed=%d source=%d/%d PA=%d/%d TLAST=%d" %
                                       (name, seed, source_count, beats, pa_count, words, tlast_count))
                case = {"campaign": campaign, "seed": seed, "profile": profile,
                    "status": "PASS", "target_axis_beats": beats,
                    "accepted_axis_beats": source_count, "expected_pa_words": words,
                    "matched_pa_words": pa_count, "accepted_tlast": tlast_count,
                    "source_clock_phase_ps": source_phase, "source_gap_max_cycles": 4,
                    "pa_stall_percent": 25, "vector_generation_seconds": gen_seconds,
                    "simulation_seconds": sim_seconds, "log": str(log_path),
                    "log_sha256": sha256(log_path), "vdb": str(vdb),
                    "vectors_sha256": {p.name: sha256(p) for p in sorted(vector_dir.glob("*.mem"))},
                    "commands": {"generate": shlex.join(generate_command),
                                 "simulate": shlex.join(sim_command)}}
                record["campaigns"].append(case)
                campaign_cases.append(case)
                print("DSM_V13_PRODUCT_RANDOM_PASS sku=%s campaign=%s seed=%d beats=%d pa=%d runtime_s=%.3f" %
                      (name, campaign, seed, source_count, pa_count, sim_seconds), flush=True)

            if campaign_cases:
                cumulative = [case for case in record["campaigns"]]
                batch = {"campaign": campaign,
                    "vdb_count": len(cumulative),
                    "new_vdb_count": len(campaign_cases),
                    "vdbs": [case["vdb"] for case in cumulative],
                    "urg_status": "NOT_RUN"}
                urg = args.urg
                if not urg and os.environ.get("VCS_HOME"):
                    candidate = Path(os.environ["VCS_HOME"]) / "bin" / "urg"
                    if candidate.is_file():
                        urg = str(candidate)
                if not urg:
                    vcs_path = shutil.which("vcs")
                    if vcs_path:
                        candidate = Path(vcs_path).resolve().parent / "urg"
                        if candidate.is_file():
                            urg = str(candidate)
                if not urg:
                    candidate = Path("/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg")
                    urg = str(candidate) if candidate.is_file() else ""
                elif "/" not in urg:
                    urg = shutil.which(urg) or ""
                if args.skip_urg:
                    batch["urg_status"] = "NOT_RUN_REQUESTED"
                elif urg:
                    report = sku_out / "urg" / campaign
                    command = [urg, "-full64", "-dir", str(build / "simv.vdb"),
                        *batch["vdbs"], "-report", str(report), "-dbname",
                        "dsm_v13_r3_product_%s_%s" % (name, campaign)]
                    code, output, seconds = run(command, cwd=ROOT,
                        log_path=sku_out / "urg" / (campaign + ".log"))
                    metrics = dut_metrics(report)
                    batch.update({"urg_status": "PASS" if code == 0 and metrics else "FAIL",
                        "urg_seconds": seconds, "urg_command": shlex.join(command),
                        "urg_report": str(report), "dut_metrics_percent": metrics,
                        "urg_log_tail": output.splitlines()[-20:]})
                    if previous_metrics is not None and metrics:
                        batch["delta_vs_previous_campaign_percent_points"] = {
                            key: round(metrics[key] - previous_metrics[key], 4)
                            for key in metrics.keys() & previous_metrics.keys()}
                    if metrics:
                        previous_metrics = metrics
                else:
                    batch["urg_status"] = "NOT_AVAILABLE"
                record["urg_batches"].append(batch)
            summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

        if record["urg_batches"]:
            statuses = [batch["urg_status"] for batch in record["urg_batches"]]
            record["urg_status"] = "PASS" if all(status == "PASS" for status in statuses) else "OPEN"
        else:
            record["urg_status"] = "NO_SEEDS_RUN"
        summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

    compile_pass = all(row.get("compile_status") == "PASS" for row in summary["sku_results"].values())
    sim_pass = compile_pass and all(all(c["status"] == "PASS" for c in row["campaigns"])
                                    for row in summary["sku_results"].values())
    urg_pass = all(row.get("urg_status") == "PASS" for row in summary["sku_results"].values())
    summary["finished_utc"] = datetime.now(timezone.utc).isoformat()
    summary["status"] = "PASS" if sim_pass and urg_pass else ("SIM_PASS_URG_OPEN" if sim_pass else "FAIL")
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print("DSM_V13_ROUND3_PRODUCT_RANDOM_SUMMARY=%s" % summary_path)
    return 0 if sim_pass else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print("DSM_V13_ROUND3_PRODUCT_RANDOM_FAIL=" + str(error), file=sys.stderr)
        raise SystemExit(2)
