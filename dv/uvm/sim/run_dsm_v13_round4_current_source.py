#!/usr/bin/env python3
"""Rebuild the Round 4 SKU matrix and replay its saved directed test commands."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shlex
import subprocess
import sys

import run_dsm_v13_round4_urg as r4


ROOT = Path(__file__).resolve().parents[3]
CONFIG = {
    "ef1_product": (1, 1, 7168, 0),
    "ef2_product": (2, 2, 5120, 0),
    "mash11_product": (3, 2, 5120, 0),
    "ef1_axil": (1, 1, 7168, 1),
    "ef2_axil": (2, 2, 5120, 1),
    "mash11_axil": (3, 2, 5120, 1),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(path: Path) -> dict:
    files = sorted(item for item in path.rglob("*") if item.is_file())
    digest_state = hashlib.sha256()
    byte_count = 0
    for item in files:
        item_hash = digest(item)
        digest_state.update(item.relative_to(path).as_posix().encode("utf-8"))
        digest_state.update(b"\0")
        digest_state.update(item_hash.encode("ascii"))
        digest_state.update(b"\n")
        byte_count += item.stat().st_size
    return {"tree_sha256": digest_state.hexdigest(), "files": len(files),
            "bytes": byte_count}


def command_from_log(path: Path) -> list[str]:
    first = path.read_text(encoding="utf-8", errors="replace").splitlines()[0]
    if not first.startswith("Command: "):
        raise RuntimeError(f"missing saved simulator command in {path}")
    return shlex.split(first.removeprefix("Command: "))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-run-dir", type=Path, default=ROOT / "runs/dsm_v13_round4")
    parser.add_argument("--out-dir", type=Path, default=ROOT / "runs/dsm_v13_round4_current_source")
    args = parser.parse_args()
    source_run = args.source_run_dir.resolve()
    out_dir = args.out_dir.resolve()
    if not source_run.is_dir():
        parser.error("--source-run-dir must contain the saved Round 4 VCS logs")
    if ROOT / "runs" not in out_dir.parents or out_dir.exists():
        parser.error("--out-dir must be a new directory below runs/")
    out_dir.mkdir(parents=True)
    records: list[dict] = []

    for name, (arch, order, step, axil) in CONFIG.items():
        source_build = source_run / name
        build = out_dir / name
        build.mkdir(parents=True)
        case = r4.CASES[name]
        first_log = source_build / case["positive_logs"][0]
        saved_command = command_from_log(first_log)
        vector_arg = next((arg for arg in saved_command if arg.startswith("+VEC_DIR=")), None)
        if not vector_arg:
            raise RuntimeError(f"{first_log} has no +VEC_DIR argument")
        vectors = Path(vector_arg.split("=", 1)[1])
        if not (vectors / "tid32_thermo5_frontend_pa3.mem").is_file():
            raise RuntimeError(f"Round 4 vector set is missing: {vectors}")

        top = "dsm_v13_multi_sku_uvm_tb"
        hier = ROOT / "dv/uvm/sim/dsm_v13_product_dut_coverage.hier"
        make_command = [
            "make", "-C", str(ROOT / "dv/uvm/sim"), "thermo5-vcs",
            f"THERMO5_OUT={build}", f"THERMO5_VECTORS={vectors}",
            f"THERMO5_TOP={top}", f"THERMO5_TOP_ARGS=-pvalue+{top}.DSM_ARCH={arch}",
            f"THERMO5_USE_AXIL={axil}", "THERMO5_CENTERED_CUBIC=1",
            f"THERMO5_TIDSM_ORDER={order}", f"THERMO5_STEP={step}",
            "THERMO5_DPD_MAX_TAPS=1", f"THERMO5_COV_HIER={hier}",
        ]
        compile_result = subprocess.run(make_command, cwd=ROOT, text=True,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        check=False)
        (build / "rebuild.log").write_text(compile_result.stdout, encoding="utf-8")
        if compile_result.returncode != 0 or not (build / "simv").is_file():
            raise RuntimeError(f"{name}: current-source VCS build failed; see {build / 'compile.log'}")

        replay = list(zip(case["vdbs"], case["positive_logs"]))
        if case.get("negative_log"):
            replay.append((case["vdbs"][-1], case["negative_log"]))
        if len(replay) != len(case["vdbs"]):
            raise RuntimeError(f"{name}: saved VDB/log cases do not pair one-to-one")
        for vdb_name, log_name in replay:
            command = command_from_log(source_build / log_name)
            command[0] = str(build / "simv")
            if "-cm_dir" not in command or "-l" not in command:
                raise RuntimeError(f"{source_build / log_name}: missing coverage or log output argument")
            command[command.index("-cm_dir") + 1] = str(build / vdb_name)
            command[command.index("-l") + 1] = str(build / log_name)
            result = subprocess.run(command, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    check=False)
            if result.returncode != 0 or not (build / vdb_name).is_dir():
                raise RuntimeError(f"{name}/{log_name}: replay failed; see {build / log_name}")
            records.append({"configuration": name, "vdb": str(build / vdb_name),
                            "log": str(build / log_name), "command": command,
                            "returncode": result.returncode,
                            **tree_digest(build / vdb_name),
                            "log_sha256": digest(build / log_name)})
        print(f"DSM_V13_R4_CURRENT_SOURCE_{name.upper()}=PASS tests={len(replay)}")

    core_source = source_run / "mash11_core"
    if not core_source.is_dir():
        raise RuntimeError("legacy MASH wrapper/core evidence is missing")
    (out_dir / "mash11_core").symlink_to(core_source, target_is_directory=True)
    manifest = {
        "schema": "dsm_v13_round4_current_source_replay_v1",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "source_run_directory": str(source_run),
        "out_directory": str(out_dir),
        "current_source_sha256": {
            rel: digest(ROOT / rel) for rel in (
                "dv/uvm/env/thermo5/thermo5_sku_coverage.svh",
                "dv/uvm/tests/thermo5/axil/thermo5_sku_axil_stop_restart_test.svh",
                "dv/uvm/sim/run_dsm_v13_round4_current_source.py",
                "dv/uvm/sim/run_dsm_v13_round4_urg.py",
                "dv/uvm/formal/dsm_v13_mash11_reachability_harness.sv",
                "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.py",
                "dv/uvm/formal/run_dsm_v13_mash11_reachability_fpv.tcl",
                "rtl/tx_bandpass_if/tid32_mash11_weighted_pa_tx.sv",
            )
        },
        "legacy_mash_wrapper_core_reused": str(core_source),
        "replays": records,
    }
    (out_dir / "current_source_replay_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"DSM_V13_R4_CURRENT_SOURCE_REPLAY=PASS tests={len(records)} output={out_dir}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as error:
        raise SystemExit(str(error))
