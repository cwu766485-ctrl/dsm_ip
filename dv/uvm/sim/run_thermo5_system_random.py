#!/usr/bin/env python3
"""Run replayable Linux-only Thermo5 TX packet random verification.

Each case gets Python bit-true vectors, a fresh UVM seed, a monitor JSONL
trace, an independent trace-oracle check, and a compact checksum manifest.
The product DPD reset image stays Identity; this runner does not change DUT RTL.
"""

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

from thermo5_urg_utils import cross_counts


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
PY_DIR = ROOT / "dv" / "uvm" / "refmodel" / "python"
GENERATOR = PY_DIR / "generate_thermo5_frontend_vectors.py"
TRACE_CHECKER = PY_DIR / "check_thermo5_monitor_trace.py"
PRODUCT_VECTORS = ROOT / "runs" / "uvm_thermo5_i2_d1" / "vectors"
PROFILES = ("random", "extreme", "range_stress", "ef2_saturation")
GAINS_Q14 = (8192, 12288, 14336, 16384, 18432, 20480)
GAIN_CLASS = {
    "low": (8192, 12288),
    "nominal": (14336, 16384),
    "high": (18432, 20480),
}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def run(command, *, cwd, env=None, log_path=None):
    completed = subprocess.run(command, cwd=cwd, env=env, text=True,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, check=False)
    if log_path is not None:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(completed.stdout, encoding="utf-8")
    if completed.returncode:
        tail = "\n".join(completed.stdout.splitlines()[-50:])
        raise RuntimeError("command failed (%d): %s\n%s" % (
            completed.returncode, shlex.join(command), tail))
    return completed.stdout


def read_trace(path):
    events = []
    with open(path, encoding="utf-8") as stream:
        for line_no, line in enumerate(stream, 1):
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise RuntimeError("invalid trace JSON at %s:%d: %s" % (
                    path, line_no, exc)) from exc
    return events


def parse_number(value):
    if isinstance(value, str) and value.lower().startswith("0x"):
        return int(value, 16)
    return int(value)


def gain_class(value):
    for label, values in GAIN_CLASS.items():
        if value in values:
            return label
    return "other"


def summarize_trace(events, profile, gains, expected_words, expected_beats):
    source = [event for event in events if event.get("type") == "source_beat"]
    pa = [event for event in events if event.get("type") == "pa_word"]
    stalls = [event for event in events if event.get("type") == "pa_stall"]
    fifo_full = [event for event in events
                 if event.get("type") == "fifo_full" and event.get("full") is True]
    run_writes = [event for event in events
                  if event.get("type") == "axil_write_fire" and
                  parse_number(event.get("addr", "0")) == 0 and
                  parse_number(event.get("data", "0")) & 1]
    stop_writes = [event for event in events
                   if event.get("type") == "axil_write_fire" and
                   parse_number(event.get("addr", "0")) == 0 and
                   not (parse_number(event.get("data", "0")) & 1)]
    status_responses = [event for event in events
                        if event.get("type") == "axil_read_response" and
                        parse_number(event.get("addr", "0")) == 4]
    drained = any(((parse_number(event.get("rdata", "0")) >> 3) & 3) == 0
                  for event in status_responses)
    gap_values = [int(event.get("source_gap_cycles", 0)) for event in source]
    pa_masks = [parse_number(event.get("ready", "0")) & 0xF for event in stalls]
    frame_gain_values = [parse_number(event.get("frame_gain", "0"))
                         for event in source if event.get("frame_start")]
    tlast_count = sum(bool(event.get("tlast")) for event in source)
    resets = [event for event in events if event.get("type") == "reset"]
    commits = [event for event in events
               if event.get("type") == "axil_write_fire" and
               parse_number(event.get("addr", "0")) == 0 and
               parse_number(event.get("data", "0")) & 2]
    pending = [event for event in events if event.get("type") == "config_pending"]
    boundaries = [event for event in events if event.get("type") == "frame_boundary"]
    time_of = lambda event: float(event.get("time_ns", 0))
    source.sort(key=time_of)
    fifo_full.sort(key=time_of)
    stalls.sort(key=time_of)
    status_responses.sort(key=time_of)
    run_writes.sort(key=time_of)
    stop_writes.sort(key=time_of)
    first_run_time = min((time_of(event) for event in run_writes),
                         default=float("inf"))
    source_prefill = sum(float(event.get("time_ns", 0)) < first_run_time
                         for event in source)
    any_gap = any(value > 0 for value in gap_values)
    gap_after_run = any(int(event.get("source_gap_cycles", 0)) > 0 and
                        time_of(event) > first_run_time for event in source)
    zero_ready = any(mask == 0 for mask in pa_masks)
    partial_ready = any(mask not in (0, 0xF) for mask in pa_masks)
    all_ready = bool(pa)
    stop_drain = False
    for stop in stop_writes:
        stop_time = time_of(stop)
        for last in (event for event in source if event.get("tlast")):
            if time_of(last) <= stop_time:
                continue
            if any(time_of(status) > time_of(last) and
                   ((parse_number(status.get("rdata", "0")) >> 3) & 3) == 0
                   for status in status_responses):
                stop_drain = True
                break
        if stop_drain:
            break

    gap_full_stall_episodes = []
    previous_source_time = None
    for event in source:
        event_time = time_of(event)
        if int(event.get("source_gap_cycles", 0)) > 0 and previous_source_time is not None:
            full_state = False
            full_during = False
            for full_event in fifo_full:
                full_time = time_of(full_event)
                if full_time <= previous_source_time:
                    full_state = bool(full_event.get("full"))
                elif full_time <= event_time and full_event.get("full"):
                    full_during = True
            full_during = full_during or full_state
            interval_stalls = [stall for stall in stalls
                               if previous_source_time <= time_of(stall) <= event_time]
            if full_during and interval_stalls:
                gap_full_stall_episodes.append(interval_stalls)
        previous_source_time = event_time

    observed = set()
    for event in source:
        if event.get("frame_start"):
            g = gain_class(parse_number(event.get("frame_gain", "0")))
            observed.add("DPD_IDENTITY x GAIN_%s x PROFILE_%s" % (
                g.upper(), profile.upper()))
    for label, active in (("PA_ALL_READY", all_ready),
                          ("PA_ZERO_READY_STALL", zero_ready),
                          ("PA_PARTIAL_READY_STALL", partial_ready),
                          ("SOURCE_GAP", any_gap),
                          ("SOURCE_NO_GAP", not any_gap),
                          ("FIFO_FULL", bool(fifo_full)),
                          ("STOP_TLAST_DRAIN", stop_drain),
                          ("RUN_PREFILL", source_prefill >= 16),
                          ("RUN_PREFILL_SOURCE_GAP",
                           source_prefill >= 16 and gap_after_run)):
        if active:
            observed.add(label)
    for episode_stalls in gap_full_stall_episodes:
        episode_masks = {parse_number(stall.get("ready", "0x0")) & 0xF
                         for stall in episode_stalls}
        if 0 in episode_masks:
            observed.add("SOURCE_GAP x PA_ZERO_READY x FIFO_FULL")
        if any(mask not in (0, 0xF) for mask in episode_masks):
            observed.add("SOURCE_GAP x PA_PARTIAL_READY x FIFO_FULL")
    if commits and pending and boundaries and stalls:
        observed.add("COMMIT x FRAME_BOUNDARY x PA_STALL")
    if resets and (commits or pending):
        observed.add("RESET x PENDING_COMMIT")
    if status_responses and commits and stop_writes:
        observed.add("STATUS x COMMIT x STOP")

    actual = {
        "accepted_axis_beats": len(source),
        "accepted_pa_words": len(pa),
        "accepted_tlast": tlast_count,
        "frame_start_gains_q14": frame_gain_values,
        "source_gap_cycles_total": sum(gap_values),
        "source_gap_beats": sum(value > 0 for value in gap_values),
        "pa_stall_cycles": len(stalls),
        "pa_stall_masks": sorted(set("0x%x" % value for value in pa_masks)),
        "fifo_full_assertions": len(fifo_full),
        "source_gap_after_run": gap_after_run,
        "source_gap_fifo_full_pa_stall_episodes": len(gap_full_stall_episodes),
        "run_before_source_beats": source_prefill,
        "status_read_responses": len(status_responses),
        "drained_status_observed": drained,
        "config_commits": len(commits),
        "config_pending_events": len(pending),
        "reset_events": len(resets),
        "observed_system_bins": sorted(observed),
        "pass": (len(source) == expected_beats and len(pa) == expected_words and
                 tlast_count == expected_beats // 32 and bool(run_writes) and
                 bool(stop_writes) and drained and len(frame_gain_values) ==
                 len(gains) and all(value == expected for value, expected in
                 zip(frame_gain_values, gains))),
    }
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=ROOT / "runs" / "thermo5_tx_system_random_phase_c")
    parser.add_argument("--random-seeds", type=int, default=100)
    parser.add_argument("--long-seeds", type=int, default=10)
    parser.add_argument("--seed-base", type=int, default=720000)
    parser.add_argument("--skip-compile", action="store_true")
    parser.add_argument("--skip-urg", action="store_true")
    args = parser.parse_args()
    if args.random_seeds < 0 or args.long_seeds < 0:
        parser.error("seed counts must be nonnegative")
    if args.random_seeds + args.long_seeds == 0:
        parser.error("at least one seed is required")

    out = args.out.resolve()
    build = out / "build"
    vectors_root = out / "vectors"
    traces_root = out / "traces"
    logs_root = out / "logs"
    vdb_root = out / "vdb"
    for directory in (vectors_root, traces_root, logs_root, vdb_root):
        directory.mkdir(parents=True, exist_ok=True)

    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                   text=True).strip()
    compile_command = ["make", "-C", str(SIM_DIR), "thermo5-vcs",
                       "THERMO5_USE_AXIL=1", "THERMO5_DPD_MAX_TAPS=1",
                       "THERMO5_CENTERED_CUBIC=1", "THERMO5_TIDSM_ORDER=2",
                       "THERMO5_STEP=5120", "THERMO5_COVERAGE=1",
                       "THERMO5_COV_HIER=" + str(SIM_DIR / "thermo5_product_dut_coverage.hier"),
                       "THERMO5_VECTORS=" + str(PRODUCT_VECTORS),
                       "THERMO5_OUT=" + str(build)]
    compile_log = logs_root / "compile.log"
    if not args.skip_compile:
        run(compile_command, cwd=ROOT, log_path=compile_log)
    simv = build / "simv"
    if not simv.is_file():
        raise SystemExit("VCS binary not found: %s" % simv)

    env = os.environ.copy()
    env["PYTHONPATH"] = str(PY_DIR) + os.pathsep + env.get("PYTHONPATH", "")
    tests = []
    all_seed_specs = [(False, args.seed_base + index)
                      for index in range(args.random_seeds)]
    all_seed_specs += [(True, args.seed_base + 100000 + index)
                       for index in range(args.long_seeds)]
    profile_counts = {profile: 0 for profile in PROFILES}
    new_bins = set()
    summary_path = out / "summary.json"

    for run_index, (is_long, seed) in enumerate(all_seed_specs):
        words = 112 if is_long else 56
        beats = words * 4 // 7
        starts = (1, 15, 36) if not is_long else (1, 15, 36, 57, 71, 92)
        rng = random.Random(seed ^ 0x544835)
        profile = PROFILES[run_index % len(PROFILES)]
        profile_counts[profile] += 1
        gains = [rng.choice(GAINS_Q14) for _ in starts]
        if profile == "range_stress":
            gains = [16384] * len(starts)
        vector_dir = vectors_root / ("seed_%d" % seed)
        trace_path = traces_root / ("seed_%d.jsonl" % seed)
        run_log = logs_root / ("seed_%d.log" % seed)
        oracle_log = logs_root / ("seed_%d_oracle.log" % seed)
        vdb = vdb_root / ("seed_%d.vdb" % seed)
        generation_command = [sys.executable, str(GENERATOR),
                              "--output-dir", str(vector_dir),
                              "--words", str(words), "--seed", str(seed),
                              "--profile", profile,
                              "--interp-mode", "centered_cubic",
                              "--dpd-profile", "identity", "--step", "5120",
                              "--tidsm-order", "2",
                              "--frame-start-words", ",".join(map(str, starts)),
                              "--frame-gains", ",".join(map(str, gains))]
        run(generation_command, cwd=ROOT, env=env)
        uvm_command = [str(simv), "+UVM_TESTNAME=thermo5_sku_axil_random_packet_test",
                       "+VEC_DIR=" + str(vector_dir),
                       "+ntb_random_seed=" + str(seed),
                       "+CORE_WORDS=" + str(words), "+PACKET_BEATS=32",
                       "+THERMO5_RANDOM_SOURCE_GAP_MAX=2",
                       "+THERMO5_RANDOM_PA_STALL_PERCENT=25",
                       "+THERMO5_TRACE_JSONL=" + str(trace_path),
                       "-cm", "line+cond+fsm+tgl+branch+assert",
                       "-cm_dir", str(vdb), "-no_save", "-l", str(run_log)]
        run_output = run(uvm_command, cwd=ROOT, env=env)
        if "THERMO5_TX_RANDOM_PACKET_PASS" not in run_log.read_text(
                encoding="utf-8", errors="replace"):
            raise RuntimeError("UVM PASS marker missing for seed %d; see %s\n%s" % (
                seed, run_log, "\n".join(run_output.splitlines()[-40:])))
        run_text = run_log.read_text(encoding="utf-8", errors="replace")
        if re.search(r"UVM_ERROR\s*:\s*[1-9]|UVM_FATAL\s*:\s*[1-9]", run_text):
            raise RuntimeError("UVM error/fatal count nonzero for seed %d" % seed)

        checker_command = [sys.executable, str(TRACE_CHECKER), str(trace_path),
                           "--step", "5120", "--tidsm-order", "2", "--max-taps", "1"]
        oracle_output = run(checker_command, cwd=ROOT, env=env,
                            log_path=oracle_log)
        if "TRACE_CLASSIFICATION=PASS_NO_UNDERFLOW" not in oracle_output:
            raise RuntimeError("trace oracle did not classify seed %d as normal PASS" % seed)
        events = read_trace(trace_path)
        actual = summarize_trace(events, profile, gains, words, beats)
        if not actual["pass"]:
            raise RuntimeError("trace transaction contract failed for seed %d: %s" % (
                seed, json.dumps(actual, sort_keys=True)))
        delta = sorted(set(actual["observed_system_bins"]) - new_bins)
        new_bins.update(actual["observed_system_bins"])
        tests.append({
            "seed": seed,
            "stream_class": "long_112_word" if is_long else "packet_56_word",
            "product": {"interp": "centered_cubic_x2_x2", "tidsm_order": 2,
                        "step": 5120, "dpd_max_taps": 1,
                        "dpd_runtime_image": "identity_reset_image",
                        "fifo": "generic", "axil": True},
            "stimulus": {"profile": profile, "frame_start_words_1based": starts,
                         "frame_gains_q14": gains,
                         "source_gap_max_cycles": 2,
                         "pa_stall_percent": 25,
                         "random_seed": seed},
            "actual": actual,
            "coverage_delta_bins": delta,
            "commands": {"generate": shlex.join(generation_command),
                         "simulate": shlex.join(uvm_command),
                         "oracle": shlex.join(checker_command)},
            "sha256": {"trace": sha256(trace_path), "uvm_log": sha256(run_log),
                       "oracle_log": sha256(oracle_log),
                       "vectors": {path.name: sha256(path)
                                   for path in sorted(vector_dir.glob("*.mem"))}},
        })
        state = {"source_head": head, "started_utc": datetime.now(timezone.utc).isoformat(),
                 "compile_command": shlex.join(compile_command),
                 "compile_log": str(compile_log), "completed_cases": len(tests),
                 "requested_random_seeds": args.random_seeds,
                 "requested_long_seeds": args.long_seeds,
                 "profile_counts": profile_counts, "observed_system_bins": sorted(new_bins),
                 "cases": tests, "status": "IN_PROGRESS"}
        summary_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print("THERMO5_RANDOM_CASE_PASS seed=%d class=%s profile=%s source=%d PA=%d gaps=%d stalls=%d new_bins=%d" % (
            seed, "long" if is_long else "packet", profile,
            actual["accepted_axis_beats"], actual["accepted_pa_words"],
            actual["source_gap_beats"], actual["pa_stall_cycles"], len(delta)),
            flush=True)

    urg_result = "NOT_RUN"
    system_crosses = {}
    if not args.skip_urg:
        vdbs = [str(vdb_root / ("seed_%d.vdb" % seed))
                for _, seed in all_seed_specs]
        urg_default = str(Path(os.environ["VCS_HOME"]) / "bin" / "urg") \
            if os.environ.get("VCS_HOME") else (shutil.which("urg") or "urg")
        urg = os.environ.get("URG", urg_default)
        report_dir = out / "urg_system_random"
        urg_command = [urg, "-full64", "-dir", str(build / "simv.vdb"),
                       *vdbs, "-report", str(report_dir), "-dbname",
                       "thermo5_tx_system_random"]
        try:
            run(urg_command, cwd=ROOT, env=env, log_path=logs_root / "urg.log")
            for name in ("x_source_gap_pa_stall_fifo_full",
                         "x_run_prefill_source_gap",
                         "x_stop_tlast_drain"):
                counts = cross_counts(report_dir, name)
                system_crosses[name] = {
                    "expected": counts[0], "uncovered": counts[1],
                    "covered": counts[2],
                }
                if counts != (1, 0, 1):
                    raise RuntimeError("system cross %s not closed: %s" % (
                        name, counts))
            urg_result = "PASS"
        except RuntimeError as exc:
            urg_result = "FAIL: " + str(exc).splitlines()[0]

    status = "PASS" if len(tests) == len(all_seed_specs) else "PARTIAL"
    state = {"source_head": head, "started_utc": datetime.now(timezone.utc).isoformat(),
             "compile_command": shlex.join(compile_command),
             "compile_log": str(compile_log), "completed_cases": len(tests),
             "requested_random_seeds": args.random_seeds,
             "requested_long_seeds": args.long_seeds,
             "profile_counts": profile_counts, "observed_system_bins": sorted(new_bins),
             "case_count": len(tests), "cases": tests,
             "urg_merge": urg_result, "system_crosses": system_crosses,
             "status": status}
    summary_path.write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
    print("THERMO5_SYSTEM_RANDOM_%s cases=%d/%d urg=%s summary=%s" % (
        status, len(tests), len(all_seed_specs), urg_result, summary_path))
    return 0 if status == "PASS" and not urg_result.startswith("FAIL") else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print("THERMO5_SYSTEM_RANDOM_FAIL: %s" % exc, file=sys.stderr)
        raise SystemExit(1)
