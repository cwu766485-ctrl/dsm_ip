#!/usr/bin/env python3
"""Run the DSM V1.3 smoke, standard, and stress campaigns per Product SKU."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shlex
import shutil
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
GENERATOR = ROOT / "dv" / "uvm" / "refmodel" / "python" / "generate_thermo5_frontend_vectors.py"
PRODUCT_COV_HIER = SIM_DIR / "dsm_v13_product_dut_coverage.hier"
SKUS = {
    "ef1": {"arch": 1, "tidsm_order": 1, "step": 7168, "dsm_mode": "tidsm"},
    "ef2": {"arch": 2, "tidsm_order": 2, "step": 5120, "dsm_mode": "tidsm"},
    "mash11": {"arch": 3, "tidsm_order": 2, "step": 5120, "dsm_mode": "mash11"},
}
PROFILES = ("random", "extreme", "range_stress", "ef2_saturation")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def working_tree_fingerprint():
    tracked_diff = subprocess.check_output(
        ["git", "diff", "--binary", "HEAD"], cwd=ROOT)
    status = subprocess.check_output(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=ROOT, text=True)
    digest = hashlib.sha256(tracked_diff)
    for line in status.splitlines():
        path_text = line[3:]
        path = ROOT / path_text
        digest.update(path_text.encode("utf-8"))
        if path.is_file():
            digest.update(bytes.fromhex(sha256(path)))
    return digest.hexdigest()


def write_state(path, state):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def execute(command, *, cwd, log_path=None):
    result = subprocess.run(command, cwd=cwd, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            check=False)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(result.stdout, encoding="utf-8")
    return result


def frame_plan(packet_count, seed):
    starts = []
    gains = []
    rng = random.Random(seed ^ 0x44534D31)
    gain_choices = (12288, 14336, 16384, 18432)
    for packet in range(packet_count):
        offset = packet * 56
        for local_word in (1, 15, 36):
            starts.append(offset + local_word)
            gains.append(rng.choice(gain_choices))
    return starts, gains


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "dsm_v13_round2" / "random")
    parser.add_argument("--only-sku", choices=tuple(SKUS))
    parser.add_argument("--smoke-seeds", type=int, default=10)
    parser.add_argument("--standard-seeds", type=int, default=50)
    parser.add_argument("--stress-seeds", type=int, default=10)
    parser.add_argument("--seed-base", type=int, default=131000)
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    parser.add_argument("--compile-only", action="store_true",
                        help="elaborate each selected SKU without running seeds")
    args = parser.parse_args()
    budgets = {"smoke": args.smoke_seeds,
               "standard": args.standard_seeds,
               "stress": args.stress_seeds}
    if any(value < 0 for value in budgets.values()):
        parser.error("seed counts must be nonnegative")
    if sum(budgets.values()) == 0 and not args.compile_only:
        parser.error("at least one seed is required")

    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    summary_path = out / "regression_summary.json"
    selected_skus = [args.only_sku] if args.only_sku else list(SKUS)
    state = {
        "schema": "dsm_v13_round2_random_regression_v1",
        "started_utc": datetime.now(timezone.utc).isoformat(),
        "source_head": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "working_tree_fingerprint_sha256": working_tree_fingerprint(),
        "requested": {
            "smoke": {"seeds": args.smoke_seeds, "accepted_axis_beats_per_seed": 1024},
            "standard": {"seeds": args.standard_seeds, "accepted_axis_beats_per_seed": 10016},
            "stress": {"seeds": args.stress_seeds, "accepted_axis_beats_per_seed": 100000},
        },
        "seed_base": args.seed_base,
        "sku_results": {},
        "status": "IN_PROGRESS",
    }
    write_state(summary_path, state)

    for sku_index, sku_name in enumerate(selected_skus):
        config = SKUS[sku_name]
        sku_out = out / sku_name
        build = sku_out / "build"
        preflight = sku_out / "preflight_vectors"
        sku_record = {"configuration": config, "campaigns": [],
                      "compile_status": "NOT_RUN", "urg_status": "NOT_RUN"}
        state["sku_results"][sku_name] = sku_record
        write_state(summary_path, state)

        preflight_command = [sys.executable, str(GENERATOR),
                             "--output-dir", str(preflight), "--words", "56",
                             "--seed", str(args.seed_base + 900000 + sku_index),
                             "--interp-mode", "centered_cubic",
                             "--dpd-profile", "identity", "--step", str(config["step"]),
                             "--tidsm-order", str(config["tidsm_order"]),
                             "--dsm-mode", config["dsm_mode"],
                             "--frame-start-words", "1,15,36",
                             "--frame-gains", "16384,14336,12288"]
        generated = execute(preflight_command, cwd=ROOT)
        if generated.returncode:
            sku_record["compile_status"] = "BLOCKED_VECTOR_GENERATION"
            sku_record["compile_log_tail"] = generated.stdout.splitlines()[-40:]
            state["status"] = "BLOCKED_VECTOR_GENERATION"
            write_state(summary_path, state)
            continue

        compile_command = ["make", "-C", str(SIM_DIR), "thermo5-vcs",
                           "THERMO5_USE_AXIL=1", "THERMO5_CENTERED_CUBIC=1",
                           "THERMO5_DPD_MAX_TAPS=1",
                           "THERMO5_TIDSM_ORDER=" + str(config["tidsm_order"]),
                           "THERMO5_STEP=" + str(config["step"]),
                           "THERMO5_OUT=" + str(build),
                           "THERMO5_VECTORS=" + str(preflight),
                           "THERMO5_TOP=dsm_v13_multi_sku_uvm_tb",
                           "THERMO5_TOP_ARGS=-pvalue+dsm_v13_multi_sku_uvm_tb.DSM_ARCH=" + str(config["arch"]),
                           "THERMO5_COV_HIER=" + str(PRODUCT_COV_HIER)]
        compile_log = sku_out / "compile.log"
        if not args.skip_compile:
            compiled = execute(compile_command, cwd=ROOT, log_path=compile_log)
            if compiled.returncode:
                license_block = ("license server" in compiled.stdout.lower() or
                                 "failed to obtain license" in compiled.stdout.lower())
                sku_record["compile_status"] = "BLOCKED_LICENSE" if license_block else "FAIL"
                sku_record["compile_log"] = str(compile_log)
                sku_record["compile_log_tail"] = compiled.stdout.splitlines()[-40:]
                state["status"] = "BLOCKED_LICENSE" if license_block else "FAIL"
                write_state(summary_path, state)
                print("DSM_V13_COMPILE_%s sku=%s log=%s" % (
                    sku_record["compile_status"], sku_name, compile_log), flush=True)
                continue
        simv = build / "simv"
        if not simv.is_file():
            sku_record["compile_status"] = "MISSING_SIMV"
            state["status"] = "MISSING_SIMV"
            write_state(summary_path, state)
            continue
        sku_record["compile_status"] = "PASS"

        if args.compile_only:
            sku_record["campaign_status"] = "NOT_RUN_COMPILE_ONLY"
            sku_record["urg_status"] = "NOT_RUN_COMPILE_ONLY"
            write_state(summary_path, state)
            print("DSM_V13_COMPILE_PASS sku=%s simv=%s" % (sku_name, simv),
                  flush=True)
            continue

        campaign_index = 0
        for campaign, seed_count in budgets.items():
            beats_per_seed = {"smoke": 1024, "standard": 10016,
                              "stress": 100000}[campaign]
            words = beats_per_seed * 7 // 4
            packet_count = beats_per_seed // 32
            if words % 56 or beats_per_seed % 32:
                raise RuntimeError("internal random budget is not packet aligned")
            for offset in range(seed_count):
                seed = args.seed_base + sku_index * 1000000 + campaign_index
                campaign_index += 1
                starts, gains = frame_plan(packet_count, seed)
                vector_dir = sku_out / "vectors" / ("seed_%d" % seed)
                log_path = sku_out / "logs" / ("seed_%d.log" % seed)
                vdb = sku_out / "vdb" / ("seed_%d.vdb" % seed)
                phases = random.Random(seed ^ 0x43505253)
                source_phase = phases.randrange(0, 8000)
                axil_phase = phases.randrange(0, 10000)
                profile = PROFILES[campaign_index % len(PROFILES)]
                generate_command = [sys.executable, str(GENERATOR),
                                    "--output-dir", str(vector_dir),
                                    "--words", str(words), "--seed", str(seed),
                                    "--profile", profile,
                                    "--interp-mode", "centered_cubic",
                                    "--dpd-profile", "identity",
                                    "--step", str(config["step"]),
                                    "--tidsm-order", str(config["tidsm_order"]),
                                    "--dsm-mode", config["dsm_mode"],
                                    "--frame-start-words", ",".join(map(str, starts)),
                                    "--frame-gains", ",".join(map(str, gains))]
                generated = execute(generate_command, cwd=ROOT)
                if generated.returncode:
                    sku_record["campaigns"].append({"campaign": campaign,
                        "seed": seed, "status": "VECTOR_GENERATION_FAIL",
                        "log_tail": generated.stdout.splitlines()[-30:]})
                    state["status"] = "FAIL"
                    write_state(summary_path, state)
                    raise SystemExit("vector generation failed: SKU=%s seed=%d" % (
                        sku_name, seed))

                run_command = [str(simv),
                               "+UVM_TESTNAME=thermo5_sku_axil_random_packet_test",
                               "+VEC_DIR=" + str(vector_dir),
                               "+ntb_random_seed=" + str(seed),
                               "+CORE_WORDS=" + str(words), "+PACKET_BEATS=32",
                               "+THERMO5_RANDOM_SOURCE_GAP_MAX=4",
                               "+THERMO5_RANDOM_PA_STALL_PERCENT=25",
                               "+SOURCE_CLOCK_PHASE_PS=" + str(source_phase),
                               "+AXIL_CLOCK_PHASE_PS=" + str(axil_phase),
                               "-cm", "line+cond+fsm+tgl+branch+assert",
                               "-cm_dir", str(vdb), "-no_save", "-l", str(log_path)]
                completed = execute(run_command, cwd=ROOT, log_path=log_path)
                text = completed.stdout
                pass_match = re.search(
                    r"THERMO5_TX_RANDOM_PACKET_PASS source=(\d+) PA=(\d+) TLAST=(\d+)",
                    text)
                if (completed.returncode or pass_match is None or
                    re.search(r"UVM_ERROR\s*:\s*[1-9]|UVM_FATAL\s*:\s*[1-9]", text)):
                    sku_record["campaigns"].append({"campaign": campaign,
                        "seed": seed, "status": "FAIL", "log": str(log_path),
                        "log_sha256": sha256(log_path),
                        "log_tail": text.splitlines()[-40:]})
                    state["status"] = "FAIL"
                    write_state(summary_path, state)
                    raise SystemExit("UVM campaign failed: SKU=%s campaign=%s seed=%d" % (
                        sku_name, campaign, seed))
                actual_source, actual_pa, actual_tlast = map(int, pass_match.groups())
                accepted = actual_source == beats_per_seed
                matched = actual_pa == words
                campaign_status = "PASS" if accepted and matched else "FAIL_COUNT"
                case = {
                    "campaign": campaign, "seed": seed, "status": campaign_status,
                    "profile": profile,
                    "target_axis_beats": beats_per_seed,
                    "attempted_axis_beats": beats_per_seed,
                    "accepted_axis_beats": actual_source,
                    "expected_pa_words": words,
                    "matched_pa_words": actual_pa,
                    "accepted_tlast": actual_tlast,
                    "packet_count": packet_count,
                    "source_clock_phase_ps": source_phase,
                    "axil_clock_phase_ps": axil_phase,
                    "source_gap_max_cycles": 4,
                    "pa_stall_percent": 25,
                    "log": str(log_path), "vdb": str(vdb),
                    "log_sha256": sha256(log_path),
                    "vectors_sha256": {
                        path.name: sha256(path)
                        for path in sorted(vector_dir.glob("*.mem"))},
                    "commands": {"generate": shlex.join(generate_command),
                                 "simulate": shlex.join(run_command)},
                }
                sku_record["campaigns"].append(case)
                if campaign_status != "PASS":
                    state["status"] = "FAIL"
                    write_state(summary_path, state)
                    raise SystemExit("transaction conservation failed: SKU=%s seed=%d" % (
                        sku_name, seed))
                write_state(summary_path, state)
                print("DSM_V13_RANDOM_PASS sku=%s campaign=%s seed=%d axis=%d pa=%d tlast=%d" % (
                    sku_name, campaign, seed, actual_source, actual_pa, actual_tlast),
                    flush=True)

        if args.skip_urg:
            sku_record["urg_status"] = "NOT_RUN_REQUESTED"
        else:
            urg_default = str(Path(os.environ["VCS_HOME"]) / "bin" / "urg") \
                if os.environ.get("VCS_HOME") else (shutil.which("urg") or "urg")
            urg = os.environ.get("URG", urg_default)
            if shutil.which(urg) is None and not Path(urg).is_file():
                sku_record["urg_status"] = "NOT_AVAILABLE"
            else:
                vdbs = [str(sku_out / "vdb" / ("seed_%d.vdb" % seed))
                        for seed in [case["seed"] for case in sku_record["campaigns"]]]
                report_dir = sku_out / "urg"
                urg_log = sku_out / "urg.log"
                command = [urg, "-full64", "-dir", str(build / "simv.vdb"),
                           *vdbs, "-report", str(report_dir), "-dbname",
                           "dsm_v13_" + sku_name]
                result = execute(command, cwd=ROOT, log_path=urg_log)
                sku_record["urg_status"] = "PASS" if result.returncode == 0 else "FAIL"
                sku_record["urg_log"] = str(urg_log)
                if result.returncode:
                    state["status"] = "FAIL_URG"
                    write_state(summary_path, state)
                    raise SystemExit("URG failed for %s" % sku_name)
        write_state(summary_path, state)

    all_sim_pass = all(
        record.get("compile_status") == "PASS" and
        all(case.get("status") == "PASS" for case in record.get("campaigns", []))
        for record in state["sku_results"].values())
    all_urg_pass = all(record.get("urg_status") == "PASS"
                       for record in state["sku_results"].values())
    compile_states = [record.get("compile_status")
                      for record in state["sku_results"].values()]
    if all_sim_pass and all_urg_pass:
        state["status"] = "PASS"
    elif all_sim_pass:
        state["status"] = "SIM_PASS_URG_OPEN"
    elif compile_states and all(status == "BLOCKED_LICENSE" for status in compile_states):
        state["status"] = "BLOCKED_LICENSE"
    elif "BLOCKED_LICENSE" in compile_states:
        state["status"] = "PARTIAL_BLOCKED_LICENSE"
    else:
        state["status"] = "PARTIAL"
    state["finished_utc"] = datetime.now(timezone.utc).isoformat()
    write_state(summary_path, state)
    print("DSM_V13_RANDOM_SUMMARY=%s" % summary_path)
    if args.compile_only:
        compile_only_pass = all(record.get("compile_status") == "PASS"
                                for record in state["sku_results"].values())
        state["status"] = "COMPILE_ONLY_PASS" if compile_only_pass else \
            ("BLOCKED_LICENSE" if "BLOCKED_LICENSE" in compile_states else "COMPILE_ONLY_OPEN")
        write_state(summary_path, state)
        return 0 if compile_only_pass else 2
    return 0 if all_sim_pass else 2


if __name__ == "__main__":
    sys.exit(main())
