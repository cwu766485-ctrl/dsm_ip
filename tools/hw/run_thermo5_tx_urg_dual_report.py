#!/usr/bin/env python3.12
"""Run Raw and waiver-adjusted URG from one immutable VDB list."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[2]


def file_sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def tree_manifest(path: Path) -> dict:
    files = []
    total_bytes = 0
    digest = hashlib.sha256()
    for child in sorted(x for x in path.rglob("*") if x.is_file()):
        relative = child.relative_to(path).as_posix()
        size = child.stat().st_size
        sha = file_sha(child)
        files.append({"path": relative, "size_bytes": size, "sha256": sha})
        total_bytes += size
        digest.update(relative.encode() + b"\0" + str(size).encode() + b"\0" + sha.encode() + b"\n")
    return {"path": str(path.resolve()), "file_count": len(files),
            "total_bytes": total_bytes, "tree_sha256": digest.hexdigest(), "files": files}


def _summary(report: Path, output: Path, python: str) -> dict:
    command = [python, str(ROOT / "tools/hw/thermo5_coverage_denominator.py"),
               str(report), str(output)]
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    if completed.returncode:
        raise RuntimeError(f"coverage denominator export failed: {completed.stderr[-2000:]}")
    summary_path = output / "summary.json"
    if not summary_path.is_file():
        raise RuntimeError("coverage denominator exporter did not write summary.json")
    return json.loads(summary_path.read_text(encoding="utf-8"))


def _run_urg(urg: str, design: Path, vdbs: list[Path], report: Path,
             dbname: str, log: Path, el_file: Path | None, strict: bool) -> list[str]:
    report.parent.mkdir(parents=True, exist_ok=True)
    command = [urg, "-full64", "-dir", str(design), *(str(vdb) for vdb in vdbs),
               "-format", "both", "-report", str(report), "-dbname", dbname,
               "-log", str(log)]
    if el_file is not None:
        command += ["-elfile", str(el_file)]
        if strict:
            command.append("-excl_strict")
    completed = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    log.write_text(completed.stdout + completed.stderr, encoding="utf-8")
    if completed.returncode:
        raise RuntimeError(f"URG failed ({completed.returncode}); inspect {log}")
    if not (report / "dashboard.html").is_file():
        raise RuntimeError(f"URG did not create a report at {report}")
    return command


def _coverage_fingerprint(summary: dict) -> dict:
    return {
        "metrics": {r["metric"]: {"covered": int(r["covered"]), "total": int(r["total"]),
                                  "missing": int(r["missing"])}
                    for r in summary.get("metrics", []) if r.get("ownership") == "PROJECT_RTL"},
        "fsm": [{"metric": r.get("metric"), "covered": int(r.get("covered", 0)),
                 "total": int(r.get("total", 0))}
                for r in summary.get("fsm_denominators", []) if r.get("ownership") == "PROJECT_RTL"],
        "dut_assertions": summary.get("dut_assertion_status_counts", {}),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--urg", default="urg")
    parser.add_argument("--design-vdb", type=Path, required=True)
    parser.add_argument("--vdb", type=Path, action="append", required=True,
                        help="repeat once per test VDB; Raw and Adjusted reuse this exact list")
    parser.add_argument("--approved-el", type=Path, required=True)
    parser.add_argument("--waiver-audit", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--python", default=sys.executable)
    args = parser.parse_args()

    design = args.design_vdb.resolve()
    vdbs = [path.resolve() for path in args.vdb]
    el_file = args.approved_el.resolve()
    audit = json.loads(args.waiver_audit.read_text(encoding="utf-8"))
    out = args.out_dir.resolve()
    if not design.is_dir() or any(not path.is_dir() for path in vdbs):
        parser.error("design VDB and every test VDB must exist")
    if not vdbs or len(set(vdbs)) != len(vdbs):
        parser.error("VDB input list must be nonempty and contain no duplicate paths")
    if not el_file.is_file() or file_sha(el_file) != audit.get("generated_el_sha256"):
        parser.error("approved .el does not match its waiver audit manifest")
    if out.exists():
        parser.error("--out-dir must be new so Raw/Adjusted evidence cannot be overwritten")
    out.mkdir(parents=True)

    def input_snapshot() -> dict:
        return {"design": tree_manifest(design),
                "tests": [tree_manifest(path) for path in vdbs]}

    # Hash the exact VDB trees before invoking URG. Verify that Raw and
    # Adjusted consumed unchanged inputs; the post-run manifest is retained
    # separately so a modified VDB cannot silently pass under a stale report.
    vdb_manifest = input_snapshot()
    vdb_manifest_sha256 = hashlib.sha256(json.dumps(
        vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    raw_report = out / "raw_urg"
    adjusted_report = out / "adjusted_urg"
    raw_log = out / "raw_urg.log"
    adjusted_log = out / "adjusted_urg.log"
    common_argv = {"design_vdb": str(design), "test_vdbs": [str(x) for x in vdbs]}
    raw_command = _run_urg(args.urg, design, vdbs, raw_report,
                           "thermo5_tx_raw", raw_log, None, False)
    adjusted_command = _run_urg(args.urg, design, vdbs, adjusted_report,
                                "thermo5_tx_adjusted", adjusted_log, el_file,
                                bool(audit.get("approved_count")))
    raw_summary = _summary(raw_report, out / "raw_inventory", args.python)
    adjusted_summary = _summary(adjusted_report, out / "adjusted_inventory", args.python)
    post_vdb_manifest = input_snapshot()
    post_vdb_manifest_sha256 = hashlib.sha256(json.dumps(
        post_vdb_manifest, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    if post_vdb_manifest_sha256 != vdb_manifest_sha256:
        raise RuntimeError("a VDB changed while generating Raw/Adjusted reports")
    adjusted_summary["exclusions_applied"] = bool(audit.get("approved_count"))
    (out / "adjusted_inventory" / "summary.json").write_text(
        json.dumps(adjusted_summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if not audit.get("approved_count") and _coverage_fingerprint(raw_summary) != _coverage_fingerprint(adjusted_summary):
        raise RuntimeError("Raw and Adjusted reports differ although no waiver was approved")

    try:
        revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                  text=True, capture_output=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        revision = "UNKNOWN"
    manifest = {
        "schema_version": 1,
        "created_unix_time": int(time.time()),
        "source_revision": revision,
        "urg_binary": shutil.which(args.urg) or args.urg,
        "urg_version": next((line.strip() for line in raw_log.read_text(errors="replace").splitlines()
                              if "URG Version" in line), "UNKNOWN"),
        "product_configuration_fingerprint": audit.get("product_configuration_fingerprint"),
        "waiver_audit_sha256": file_sha(args.waiver_audit),
        "approved_waiver_count": int(audit.get("approved_count", 0)),
        "common_inputs": common_argv,
        "vdb_manifest": vdb_manifest,
        "vdb_manifest_sha256": vdb_manifest_sha256,
        "post_vdb_manifest_sha256": post_vdb_manifest_sha256,
        "raw_command": raw_command,
        "adjusted_command": adjusted_command,
        "raw_summary": _coverage_fingerprint(raw_summary),
        "adjusted_summary": _coverage_fingerprint(adjusted_summary),
        "adjusted_exclusions_applied": bool(audit.get("approved_count")),
    }
    (out / "vdb_manifest.json").write_text(json.dumps(vdb_manifest, indent=2, sort_keys=True) + "\n")
    (out / "report_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"raw": manifest["raw_summary"], "adjusted": manifest["adjusted_summary"],
                      "approved_waivers": manifest["approved_waiver_count"],
                      "same_vdb_list": True}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
