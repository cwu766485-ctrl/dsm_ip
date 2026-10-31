#!/usr/bin/env python3
"""Compile clean and one-fault thermo5 UVM variants with VCS (generic FIFO)."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
FILELIST = ROOT / "dv/uvm/sim/thermo5_sku_filelist.f"
VECTORS = ROOT / "runs/uvm_thermo5_i2_d1/vectors"
MUTANTS = {
    "plane_swap": (
        "rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv",
        ".gt_ready(common_ready), .gt_data(pa_data[b])\n        );\n      end else begin : g_bad_order",
        ".gt_ready(common_ready), .gt_data(pa_data[3-b])\n        );\n      end else begin : g_bad_order",
        "UVM_FATAL.*\\[BITTRUE\\]",
    ),
    "late_gain": (
        "rtl/frontend/dsm_frame_gain_vector.sv",
        "s0_gain <= in_frame_start ? in_frame_gain : active_gain;",
        "s0_gain <= active_gain;",
        "UVM_FATAL.*\\[BITTRUE\\]",
    ),
}
PRODUCT_DEFINES = [
    "+define+THERMO5_CENTERED_CUBIC",
    "+define+THERMO5_TIDSM_ORDER=2",
    "+define+THERMO5_STEP=5120",
    "+define+THERMO5_DPD_MAX_TAPS=1",
]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def invoke(argv: list[str], cwd: Path, log: Path) -> int:
    with log.open("w", encoding="utf-8", errors="replace") as stream:
        stream.write("COMMAND: " + json.dumps(argv) + "\nCWD: " + str(cwd) + "\n\n")
        stream.flush()
        return subprocess.run(argv, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT,
                              check=False).returncode


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out-dir", required=True, type=Path)
    ap.add_argument("--mutants", nargs="*", choices=sorted(MUTANTS), default=sorted(MUTANTS))
    args = ap.parse_args()
    out = args.out_dir.resolve()
    if ROOT / "runs" not in out.parents or out.exists():
        ap.error("--out-dir must be a new directory below repository runs/")
    if shutil.which("vcs") is None:
        ap.error("VCS executable is not on PATH; run from the licensed Linux environment")
    if not VECTORS.joinpath("tid32_thermo5_frontend_pa3.mem").is_file():
        ap.error(f"MATLAB vector fixture missing: {VECTORS}")
    out.mkdir(parents=True)
    source_filelist = FILELIST.read_text(encoding="utf-8")
    source_map = {}
    cases = ["baseline", *args.mutants]
    rows = []
    manifest = {
        "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "scope": "thermo5 frozen product UVM, Centered-Cubic EF2 one-tap identity DPD, Generic FIFO; intentional single RTL mutations",
        "git_revision": subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
            text=True, check=False
        ).stdout.strip(),
        "worktree_dirty": bool(subprocess.run(
            ["git", "status", "--porcelain"], cwd=ROOT, capture_output=True,
            text=True, check=False
        ).stdout.strip()),
        "runner_sha256": sha(Path(__file__).resolve()),
        "filelist_sha256": sha(FILELIST),
        "product_defines": PRODUCT_DEFINES,
        "seed": 1,
        "test": "thermo5_sku_bittrue_test",
        "vectors": str(VECTORS),
        "mutants": [],
    }
    for name in cases:
        case = out / name
        case.mkdir()
        filelist = source_filelist
        if name != "baseline":
            rel, old, new, expected = MUTANTS[name]
            original = ROOT / rel
            content = original.read_text(encoding="utf-8")
            if content.count(old) != 1:
                raise RuntimeError(f"mutation anchor must occur once: {rel}: {old!r}")
            mutated = case / "rtl_mutant" / Path(rel).name
            mutated.parent.mkdir(parents=True)
            mutated.write_text(content.replace(old, new), encoding="utf-8", newline="\n")
            source_map[name] = {"source": rel, "source_sha256": sha(original),
                                "mutant_sha256": sha(mutated), "anchor": old,
                                "replacement": new, "expected_failure_regex": expected}
            filelist = filelist.replace(rel, str(mutated.relative_to(ROOT)).replace("\\", "/"))
        fl = case / "filelist.f"
        fl.write_text(filelist, encoding="utf-8", newline="\n")
        bin_dir = case / "csrc"
        simv = case / "simv"
        compile_log = case / "compile.log"
        compile_args = ["vcs", "-full64", "-sverilog", "-ntb_opts", "uvm",
                        "+lint=TFIPC-L", "-timescale=1ns/1ps", "-f", str(fl),
                        *PRODUCT_DEFINES,
                        "-top", "thermo5_sku_uvm_tb", "-Mdir=" + str(bin_dir),
                        "-o", str(simv), "-l", str(compile_log)]
        compile_rc = invoke(compile_args, ROOT, case / "compile_launcher.log")
        if compile_rc != 0 or not simv.is_file():
            rows.append({"case": name, "status": "COMPILE_FAIL", "compile_exit": compile_rc,
                         "compile_log": str(compile_log.relative_to(ROOT)),
                         "compile_log_sha256": sha(compile_log) if compile_log.is_file() else None})
            break
        compile_text = compile_log.read_text(encoding="utf-8", errors="replace")
        vcs_banner = next((line.strip() for line in compile_text.splitlines()
                           if "Version V-" in line), "UNKNOWN")
        run_log = case / "simulation.log"
        run_args = [str(simv), "+UVM_TESTNAME=thermo5_sku_bittrue_test",
                    "+VEC_DIR=" + str(VECTORS), "+ntb_random_seed=1",
                    "+STRESS_PA_READY", "-l", str(run_log)]
        run_rc = invoke(run_args, ROOT, case / "run_launcher.log")
        text = run_log.read_text(encoding="utf-8", errors="replace") if run_log.exists() else ""
        if name == "baseline":
            ok = (run_rc == 0 and "THERMO5_SKU_UVM_PASS" in text and
                  re.search(r"UVM_ERROR\s*:\s*0", text) and
                  re.search(r"UVM_FATAL\s*:\s*0", text))
            rows.append({"case": name, "status": "PASS" if ok else "BASELINE_FAIL",
                         "compile_exit": compile_rc, "run_exit": run_rc,
                         "pass_marker": "THERMO5_SKU_UVM_PASS" in text,
                         "vcs_banner": vcs_banner,
                         "compile_log": str(compile_log.relative_to(ROOT)),
                         "compile_log_sha256": sha(compile_log),
                         "simulation_log": str(run_log.relative_to(ROOT)),
                         "simulation_log_sha256": sha(run_log) if run_log.is_file() else None})
            if not ok:
                break
        else:
            failure_re = source_map[name]["expected_failure_regex"]
            found = re.search(failure_re, text, flags=re.MULTILINE) is not None
            unexpected_pass = "THERMO5_SKU_UVM_PASS" in text
            ok = found and not unexpected_pass
            first = next((line for line in text.splitlines()
                          if re.search(failure_re, line)), "")
            rows.append({"case": name, "status": "DETECTED" if ok else "SURVIVED_OR_WRONG_CHECKER",
                         "compile_exit": compile_rc, "run_exit": run_rc,
                         "expected_checker_seen": found, "pass_marker": unexpected_pass,
                         "first_failure": first,
                         "vcs_banner": vcs_banner,
                         "compile_log": str(compile_log.relative_to(ROOT)),
                         "compile_log_sha256": sha(compile_log),
                         "simulation_log": str(run_log.relative_to(ROOT)),
                         "simulation_log_sha256": sha(run_log) if run_log.is_file() else None})
        if name != "baseline":
            manifest["mutants"].append(source_map[name] | {"case": name})
    manifest["cases"] = rows
    manifest["status"] = "PASS" if rows and all(
        row["status"] in ("PASS", "DETECTED") for row in rows) and len(rows) == len(cases) else "FAIL"
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "manifest": str(out / "manifest.json"),
                      "cases": rows}, indent=2))
    return 0 if manifest["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
