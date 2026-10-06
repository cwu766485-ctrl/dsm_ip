#!/usr/bin/env python3
"""Run the frozen thermo5 generic/XPM VCS regression in an isolated directory."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[3]
SIM_DIR = ROOT / "dv" / "uvm" / "sim"
BASE_VECTORS = ROOT / "runs" / "uvm_thermo5_i2_d1" / "vectors"
DEFAULT_PAYLOAD_ROOT = ROOT / "runs" / "uvm_thermo5_payload_20261003"
PAYLOAD_SEEDS = (101, 202, 303)
CASES = (
    ("thermo5_sku_bittrue_test", 1, "+STRESS_PA_READY", "THERMO5_SKU_UVM_PASS"),
    ("thermo5_sku_bubble_backpressure_test", 2, "", "THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS"),
    ("thermo5_sku_fifo_boundary_test", 2, "", "THERMO5_FIFO_BOUNDARY_UVM_PASS"),
    ("thermo5_sku_fifo_empty_test", 5, "", "THERMO5_FIFO_EMPTY_UVM_PASS"),
    ("thermo5_sku_reset_test", 3, "", "THERMO5_RESET_UVM_PASS"),
    ("thermo5_sku_reset_sweep_test", 6, "", "THERMO5_RESET_SWEEP_UVM_PASS"),
)
NEGATIVE_CASE = ("thermo5_sku_illegal_frame_test", 4)
EXPECTED_ASSERTION = "DSM frame_start was not aligned to a 56-sample boundary"
TEST_CONTRACTS = {
    "thermo5_sku_bittrue_test": {"accepted_source_beats": 32, "four_plane_words": 56, "drain_checked_by_test": True},
    "thermo5_sku_bubble_backpressure_test": {"accepted_source_beats": 32, "four_plane_words": 56, "drain_checked_by_test": True},
    "thermo5_sku_fifo_boundary_test": {"accepted_source_beats": 32, "four_plane_words": 56, "drain_checked_by_test": True},
    "thermo5_sku_fifo_empty_test": {"accepted_source_beats": 4, "four_plane_words": 7, "drain_checked_by_test": True},
    "thermo5_sku_reset_test": {"accepted_source_beats": 32, "four_plane_words": 56, "partial_epoch_source_beats": 24, "drain_checked_by_test": True},
    "thermo5_sku_reset_sweep_test": {"accepted_source_beats": 32, "four_plane_words": 56, "partial_epochs": 5, "partial_epoch_source_beats": 24, "drain_checked_by_test": True},
}


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def source_state() -> dict:
    commit = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
    )
    status = subprocess.run(
        ["git", "status", "--porcelain=v1", "--untracked-files=normal"],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        check=False,
    )
    listing = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "--", "rtl", "dv/uvm"],
        cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        check=False,
    )
    paths = []
    for line in listing.stdout.splitlines():
        p = ROOT / line
        if p.is_file() and p.suffix.lower() in {".v", ".sv", ".vh", ".svh", ".f", ".py", ".sh", ".mk"}:
            paths.append((line.replace("\\", "/"), p))
    digest = hashlib.sha256()
    for name, path in sorted(paths):
        digest.update(name.encode())
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256(path)))
    return {
        "git_commit": commit.stdout.strip() if commit.returncode == 0 else None,
        "git_status_exit_code": status.returncode,
        "worktree_dirty": bool(status.stdout.strip()),
        "dirty_paths": [line[3:] for line in status.stdout.splitlines()],
        "rtl_dv_source_sha256": digest.hexdigest(),
        "rtl_dv_source_file_count": len(paths),
    }


def execute(argv: list[str], cwd: Path, log: Path, dry_run: bool) -> dict:
    record = {
        "argv": argv,
        "cwd": str(cwd),
        "log": str(log),
        "exit_code": None,
        "started_utc": now(),
        "completed_utc": None,
        "dry_run": dry_run,
    }
    if dry_run:
        record["exit_code"] = 0
        record["completed_utc"] = now()
        return record
    log.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    with log.open("w", encoding="utf-8", errors="replace") as stream:
        stream.write("COMMAND: " + json.dumps(argv) + "\n")
        stream.write("CWD: " + str(cwd) + "\n\n")
        stream.flush()
        proc = subprocess.run(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT, check=False)
    record["exit_code"] = proc.returncode
    record["duration_seconds"] = round(time.monotonic() - start, 3)
    record["completed_utc"] = now()
    return record


def parse_case(log: Path, expected_marker: str, test_name: str, expected_words: int | None = None) -> dict:
    if not log.is_file():
        raise RuntimeError(f"missing simulator log: {log}")
    text = log.read_text(encoding="utf-8", errors="replace")
    errors = re.search(r"UVM_ERROR\s*:\s*(\d+)", text)
    fatals = re.search(r"UVM_FATAL\s*:\s*(\d+)", text)
    if not errors or int(errors.group(1)) != 0:
        raise RuntimeError(f"UVM_ERROR absent or nonzero in {log}")
    if not fatals or int(fatals.group(1)) != 0:
        raise RuntimeError(f"UVM_FATAL absent or nonzero in {log}")
    if expected_marker not in text:
        raise RuntimeError(f"required completion/checker marker absent: {expected_marker} in {log}")
    if "TEST_DONE" not in text:
        raise RuntimeError(f"UVM test completion marker absent in {log}")
    cov = re.search(r"\[SKU_COVERAGE\].*", text)
    if not cov:
        raise RuntimeError(f"functional coverage summary absent in {log}")
    metrics = {k: int(v) for k, v in re.findall(r"(full|source_stall|frame|reset|underflow|early_underflow|illegal|pa_stall|pa_words|signed_min_beats|signed_max_beats)=(\d+)", cov.group(0))}
    metrics.update({k: float(v) for k, v in re.findall(r"(source_cg|core_cg)=([\d.]+)", cov.group(0))})
    if "source_cg" not in metrics or "core_cg" not in metrics:
        raise RuntimeError(f"functional coverage fields incomplete in {log}")
    if expected_words is not None and expected_words not in (metrics.get("pa_words"),):
        # Reset/replay tests intentionally count words observed before and after
        # reset in the event coverage; their scoreboard contract is checked by
        # the test itself and is recorded separately below.
        raise RuntimeError(f"PA event count {metrics.get('pa_words')} != expected {expected_words} in {log}")
    scoreboard_contract = TEST_CONTRACTS[test_name].copy()
    return {
        "log": str(log),
        "uvm_error_count": int(errors.group(1)),
        "uvm_fatal_count": int(fatals.group(1)),
        "completion_marker": expected_marker,
        "scoreboard_contract": scoreboard_contract,
        "functional_coverage": metrics,
    }


class TableRows(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows: list[list[str]] = []
        self.row: list[str] | None = None
        self.cell: list[str] | None = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None and self.row is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def parse_dut_code_coverage(path: Path) -> dict:
    if not path.is_file():
        raise RuntimeError(f"missing URG hierarchy report: {path}")
    parser = TableRows()
    parser.feed(path.read_text(encoding="utf-8", errors="replace"))
    headers = next((row for row in parser.rows if "SCORE" in row and "LINE" in row), None)
    dut = next((row for row in parser.rows if row and row[0] == "dut"), None)
    if not headers or not dut:
        raise RuntimeError(f"cannot find DUT coverage row/columns in {path}")
    metrics = dict(zip(headers, dut))
    return {k.lower(): metrics.get(k) for k in ("SCORE", "LINE", "COND", "TOGGLE", "FSM", "BRANCH", "ASSERT")}


def manifest_path(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root)).replace("\\", "/")
    except ValueError:
        return str(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", help="new output directory below runs/ (must not exist)")
    parser.add_argument("--payload-root", default=str(DEFAULT_PAYLOAD_ROOT), help="existing MATLAB seed payload root")
    parser.add_argument("--xpm-root", default=os.environ.get("THERMO5_XPM_ROOT", ""), help="Vivado install root containing data/ip/xpm")
    parser.add_argument("--dry-run", action="store_true", help="write command plan and manifest without invoking EDA tools")
    args = parser.parse_args()

    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = Path(args.out_dir).resolve() if args.out_dir else ROOT / "runs" / f"thermo5_frozen_regression_{stamp}"
    runs = (ROOT / "runs").resolve()
    if out == runs or runs not in out.parents:
        parser.error(f"--out-dir must be a child of {runs}")
    if out.exists() and any(out.iterdir()):
        parser.error(f"output directory must be new/empty: {out}")
    out.mkdir(parents=True, exist_ok=True)

    source = source_state()
    payload_root = Path(args.payload_root).resolve()
    tool_names = ("make", "vcs", "urg", "python3")
    tool_paths = {name: shutil.which(name) for name in tool_names}
    tool_versions = {}
    for name, probe in (("make", ["make", "--version"]), ("vcs", ["vcs", "-ID"]),
                        ("urg", ["urg", "-version"]), ("python3", ["python3", "--version"])):
        if tool_paths[name] and not args.dry_run:
            try:
                result = subprocess.run(probe, cwd=ROOT, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=20, check=False)
                tool_versions[name] = {"argv": probe, "exit_code": result.returncode,
                                       "version_output": result.stdout.strip().splitlines()[:5]}
            except Exception as exc:  # preserve diagnostic without secrets
                tool_versions[name] = {"argv": probe, "error": str(exc)}
        else:
            tool_versions[name] = {"available": bool(tool_paths[name]), "probe": probe}

    required_base = [BASE_VECTORS / f"tid32_thermo5_frontend_{suffix}.mem"
                     for suffix in ("i", "q", "frame_start", "frame_gain", "pa0", "pa1", "pa2", "pa3")]
    vector_inventory = {}
    missing_vectors = [str(path) for path in required_base if not path.is_file() or path.stat().st_size == 0]
    if not missing_vectors:
        vector_inventory["base"] = {"directory": str(BASE_VECTORS),
                                     "files_sha256": {p.name: sha256(p) for p in required_base}}
    for seed in PAYLOAD_SEEDS:
        d = payload_root / f"vectors_seed{seed}"
        files = [d / f"tid32_thermo5_frontend_{suffix}.mem"
                 for suffix in ("i", "q", "frame_start", "frame_gain", "pa0", "pa1", "pa2", "pa3")]
        if any(not p.is_file() or p.stat().st_size == 0 for p in files):
            missing_vectors.extend(str(p) for p in files if not p.is_file() or p.stat().st_size == 0)
        else:
            vector_inventory[str(seed)] = {"directory": str(d), "files_sha256": {p.name: sha256(p) for p in files}}

    commands = []
    case_results = []
    merge_results = []
    payload_results = []
    errors = []
    dry = args.dry_run
    missing_tools = [name for name in ("make", "vcs", "urg", "python3") if not tool_paths[name]]
    if not dry and missing_tools:
        errors.append("required tools unavailable: " + ", ".join(missing_tools))
    if not args.xpm_root:
        errors.append("THERMO5_XPM_ROOT is unset; real XPM flow cannot compile")
    if not dry and args.xpm_root and not (Path(args.xpm_root) / "data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv").is_file():
        errors.append("THERMO5_XPM_ROOT does not contain the required Vivado XPM simulation source")
    if missing_vectors:
        errors.extend(f"missing vector artifact: {p}" for p in missing_vectors)
    can_execute = dry or not errors

    for fifo in (("generic", "xpm") if can_execute else ()):
        fifo_out = out / fifo
        common = ["make", "-C", str(SIM_DIR)]
        vars_common = [f"THERMO5_FIFO_IMPL={fifo}", f"THERMO5_OUT={fifo_out}",
                       f"THERMO5_VECTORS={BASE_VECTORS}", f"THERMO5_XPM_ROOT={args.xpm_root}"]
        reg_cmd = common + ["thermo5-vcs-regression"] + vars_common
        commands.append(execute(reg_cmd, ROOT, out / f"{fifo}_seven_case_regression.log", dry))
        if not dry:
            if commands[-1]["exit_code"] != 0:
                errors.append(f"{fifo} seven-case regression failed; see {commands[-1]['log']}")
            for name, seed, extra, marker in CASES:
                log = fifo_out / f"{name}_seed{seed}.log"
                try:
                    expected_words = 7 if "fifo_empty" in name else (
                        56 if name in ("thermo5_sku_bittrue_test", "thermo5_sku_bubble_backpressure_test",
                                       "thermo5_sku_fifo_boundary_test") else None)
                    result = parse_case(log, marker, name, expected_words)
                    result.update({"fifo_implementation": fifo, "test": name, "uvm_seed": seed,
                                   "vectors": str(BASE_VECTORS),
                                   "vdb": str(fifo_out / f"cov_{name}_seed{seed}.vdb")})
                    if not (fifo_out / f"cov_{name}_seed{seed}.vdb").is_dir():
                        raise RuntimeError(f"missing VDB for {fifo}/{name}/seed{seed}")
                    case_results.append(result)
                except Exception as exc:
                    errors.append(str(exc))
            neg_log = fifo_out / "illegal_frame_seed4.log"
            try:
                text = neg_log.read_text(encoding="utf-8", errors="replace")
                if EXPECTED_ASSERTION not in text or "THERMO5_ILLEGAL_FRAME_OBSERVED" not in text:
                    raise RuntimeError(f"expected negative assertion/marker missing from {neg_log}")
                if "UVM_FATAL :    0" not in text or "UVM_ERROR :    0" not in text:
                    raise RuntimeError(f"negative test UVM error/fatal count is not zero: {neg_log}")
                if not (fifo_out / "cov_illegal_frame_seed4.vdb").is_dir():
                    raise RuntimeError(f"missing negative-test VDB: {fifo_out}")
                neg_coverage = parse_case(neg_log, "THERMO5_ILLEGAL_FRAME_OBSERVED", "thermo5_sku_bittrue_test")["functional_coverage"]
                case_results.append({"fifo_implementation": fifo, "test": NEGATIVE_CASE[0], "uvm_seed": 4,
                                     "expected_assertion": EXPECTED_ASSERTION,
                                     "assertion_observed": True, "completion_marker": "THERMO5_ILLEGAL_FRAME_OBSERVED",
                                     "log": str(neg_log), "vdb": str(fifo_out / "cov_illegal_frame_seed4.vdb"),
                                     "scoreboard_contract": {"four_plane_words": 0, "expected_pa_output": False,
                                                             "drain_checked_by_test": False},
                                     "functional_coverage": neg_coverage})
            except Exception as exc:
                errors.append(str(exc))
        for seed in PAYLOAD_SEEDS:
            vec = payload_root / f"vectors_seed{seed}"
            log = fifo_out / f"thermo5_sku_bittrue_test_seed{seed}.log"
            cmd = common + ["thermo5-vcs-run-only"] + [
                f"THERMO5_FIFO_IMPL={fifo}", f"THERMO5_OUT={fifo_out}", f"THERMO5_XPM_ROOT={args.xpm_root}",
                f"THERMO5_VECTORS={vec}", "THERMO5_TESTNAME=thermo5_sku_bittrue_test",
                f"UVM_SEED={seed}", "THERMO5_EXTRA_ARGS=+STRESS_PA_READY", "THERMO5_COVERAGE=1"]
            rec = execute(cmd, ROOT, out / f"{fifo}_payload_seed{seed}.log", dry)
            commands.append(rec)
            if not dry:
                try:
                    result = parse_case(log, "THERMO5_SKU_UVM_PASS", "thermo5_sku_bittrue_test", 56)
                    result.update({"fifo_implementation": fifo, "test": "thermo5_sku_bittrue_test",
                                   "payload_seed": seed, "uvm_seed": seed, "vectors": str(vec),
                                   "vdb": str(fifo_out / f"cov_thermo5_sku_bittrue_test_seed{seed}.vdb")})
                    if rec["exit_code"] != 0:
                        raise RuntimeError(f"payload simulation returned {rec['exit_code']}: {rec['log']}")
                    if not Path(result["vdb"]).is_dir():
                        raise RuntimeError(f"missing payload VDB: {result['vdb']}")
                    payload_results.append(result)
                except Exception as exc:
                    errors.append(str(exc))

        extra_vdbs = [fifo_out / f"cov_thermo5_sku_bittrue_test_seed{s}.vdb" for s in PAYLOAD_SEEDS]
        merge_cmd = common + ["thermo5-coverage-merge"] + vars_common + [
            "THERMO5_URG_EXTRA_VDBS=" + " ".join(str(p) for p in extra_vdbs)]
        merge = execute(merge_cmd, ROOT, out / f"{fifo}_urg_merge.log", dry)
        commands.append(merge)
        if not dry:
            summary = fifo_out / "coverage" / "dashboard.html"
            hierarchy = fifo_out / "coverage" / "hierarchy.html"
            log = fifo_out / "coverage_merge.log"
            if merge["exit_code"] != 0:
                errors.append(f"{fifo} URG merge failed; see {merge['log']}")
            if not summary.is_file() or not hierarchy.is_file() or not log.is_file():
                errors.append(f"{fifo} URG report artifact missing")
            if log.is_file() and re.search(r"Error-|Design Not Loaded", log.read_text(encoding="utf-8", errors="replace")):
                errors.append(f"{fifo} URG reported a design-load/merge error")
            dut_cov = None
            if hierarchy.is_file():
                try:
                    dut_cov = parse_dut_code_coverage(hierarchy)
                except Exception as exc:
                    errors.append(str(exc))
            merge_results.append({"fifo_implementation": fifo, "exit_code": merge["exit_code"],
                                  "log": str(log), "dashboard": str(summary),
                                  "hierarchy_report": str(hierarchy), "dut_hierarchy_code_coverage": dut_cov,
                                  "vdb_inputs": [str(fifo_out / f"cov_{name}_seed{seed}.vdb") for name, seed, _, _ in CASES]
                                  + [str(fifo_out / "cov_illegal_frame_seed4.vdb")] + [str(p) for p in extra_vdbs],
                                  "percentage_comparable_to_other_fifo": False})

    manifest = {
        "schema_version": 1,
        "created_utc": now(),
        "status": "DRY_RUN" if dry else ("PASS" if not errors else "FAIL"),
        "scope": "thermo5 frozen SKU; generic and real Vivado XPM FIFO, seven directed UVM cases plus three independent MATLAB payload seeds per implementation",
        "root": str(ROOT), "output_directory": str(out), "source": source,
        "tools": {"paths": tool_paths, "versions": tool_versions,
                  "license_environment_values_recorded": False},
        "configuration": {"sku": "thermo5", "INTERP_TAPS": 2, "DPD_MAX_TAPS": 1,
                          "BYPASS_DPD": 0, "DPD_coefficients": "identity c1=1; remaining coefficients zero",
                          "fifo_implementations": ["generic", "xpm"], "payload_seeds": list(PAYLOAD_SEEDS),
                          "payload_root": str(payload_root), "base_vectors": str(BASE_VECTORS),
                          "xpm_root": args.xpm_root or None,
                          "coverage": "line+cond+fsm+tgl+branch+assert; separate URG output per FIFO implementation"},
        "vectors": vector_inventory, "missing_vectors": missing_vectors,
        "commands": commands, "seven_case_results": case_results,
        "payload_results": payload_results, "urg_merges": merge_results,
        "compiled_artifacts": {fifo: {"compile_log": str(out / fifo / "compile.log"),
                                      "simulator": str(out / fifo / "simv"),
                                      "design_vdb": str(out / fifo / "simv.vdb")}
                               for fifo in ("generic", "xpm")},
        "owned_rtl_code_coverage": "URG DUT hierarchy score and line/condition/toggle/FSM/branch/assert values are captured; XPM DUT hierarchy includes vendor cells, so use the saved report and do not cross-compare FIFO implementations",
        "functional_coverage": "per-test source_cg/core_cg and event counters are stored in each case result",
        "errors": errors,
    }
    manifest_file = out / "manifest.json"
    manifest_file.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    summary = {k: manifest[k] for k in ("schema_version", "created_utc", "status", "output_directory", "source", "tools", "errors")}
    summary["counts"] = {"seven_case_results": len(case_results), "payload_results": len(payload_results),
                         "separate_urg_merges": len(merge_results)}
    (out / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "manifest": str(manifest_file),
                      "tools_missing": missing_tools, "errors": errors}, indent=2))
    return 0 if dry else (0 if not errors else 2)


if __name__ == "__main__":
    raise SystemExit(main())
