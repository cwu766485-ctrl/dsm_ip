#!/usr/bin/env python3
"""Write a reproducibility manifest for the fixed-seed thermo5 EF2 VCS run."""

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def relative(path, root):
    try:
        return str(path.resolve().relative_to(root.resolve()))
    except ValueError:
        return str(path.resolve())


def git_text(root, *args):
    result = subprocess.run(
        ["git", "-C", str(root)] + list(args),
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--run-dir", required=True, type=Path)
    parser.add_argument("--vectors", required=True, nargs=3, type=Path,
                        help="sustained, random-backpressure, saturation vector roots")
    args = parser.parse_args()
    root = args.repo_root.resolve()
    run_dir = args.run_dir.resolve()
    coverage_dir = run_dir / "ef2_qualification_coverage"
    test_specs = [
        ("thermo5_sku_sustained_test_seed271027.log", 1),
        ("thermo5_sku_ef2_corner_test_seed271028.log", 1),
        ("thermo5_sku_long_counter_test_seed271029.log", 2),
    ]
    test_records = []
    vcs_version = "unknown"
    for filename, minimum_markers in test_specs:
        path = run_dir / filename
        if not path.is_file():
            raise SystemExit("missing VCS test log: " + str(path))
        content = path.read_text(encoding="utf-8", errors="replace")
        version_match = re.search(
            r"Compiler version ([^;]+); Runtime version ([^;]+)", content)
        if version_match:
            vcs_version = version_match.group(1).strip()
        errors = [int(value) for value in re.findall(r"UVM_ERROR\s*:\s*(\d+)", content)]
        fatals = [int(value) for value in re.findall(r"UVM_FATAL\s*:\s*(\d+)", content)]
        markers = len(re.findall(r"\[SKU_PASS\]", content))
        passed = markers >= minimum_markers and errors and fatals \
            and all(value == 0 for value in errors + fatals)
        test_records.append({
            "log": relative(path, root),
            "log_sha256": sha256(path),
            "pass_markers": markers,
            "uvm_error_summaries": errors,
            "uvm_fatal_summaries": fatals,
            "status": "PASS" if passed else "FAIL",
        })
    if any(record["status"] != "PASS" for record in test_records):
        raise SystemExit("one or more VCS qualification logs failed their gate")

    vector_records = []
    for label, vector_root in zip(("sustained", "random_backpressure", "saturation"), args.vectors):
        files = sorted(vector_root.glob("*.mem"))
        if not files:
            raise SystemExit("missing oracle vectors: " + str(vector_root))
        vector_records.append({
            "scenario": label,
            "directory": relative(vector_root, root),
            "files": [{"path": relative(path, root), "sha256": sha256(path)}
                      for path in files],
        })

    coverage_log = run_dir / "ef2_qualification_coverage.log"
    dashboard = coverage_dir / "dashboard.html"
    group_report = coverage_dir / "grp0.html"
    compile_log = run_dir / "compile.log"
    for path in (coverage_log, dashboard, group_report, compile_log):
        if not path.is_file():
            raise SystemExit("missing qualification artifact: " + str(path))
    coverage_html = group_report.read_text(encoding="utf-8", errors="replace")
    required_crosses = (
        "positive_candidate_x_stall", "negative_candidate_x_stall",
        "positive_x_rail", "negative_x_rail",
    )
    cross_status = {}
    for name in required_crosses:
        match = re.search(
            r"<td><a href=\"#[^\"]*" + re.escape(name) + r"\"[^>]*>" +
            re.escape(name) + r"</a></td>\s*<td class=\"rt\">(\d+)</td>" +
            r"\s*<td class=\"rt\">(\d+)</td>\s*<td class=\"rt\">(\d+)</td>",
            coverage_html,
        )
        if not match:
            cross_status[name] = {"status": "NOT_FOUND"}
        else:
            expected, uncovered, covered = [int(value) for value in match.groups()]
            cross_status[name] = {
                "expected": expected,
                "uncovered": uncovered,
                "covered": covered,
                "status": "PASS" if expected == covered and uncovered == 0 else "FAIL",
            }
    if any(item.get("status") != "PASS" for item in cross_status.values()):
        raise SystemExit("required EF2 URG cross bins are not fully covered")

    git_status = git_text(root, "status", "--porcelain")
    changed_files = []
    for line in git_status.splitlines():
        relative_path = line[3:].strip()
        source_path = root / relative_path
        if source_path.is_file():
            changed_files.append({
                "path": relative(source_path, root),
                "sha256": sha256(source_path),
            })
    diff = subprocess.run(
        ["git", "-C", str(root), "diff", "HEAD", "--binary"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    ).stdout
    revision = git_text(root, "rev-parse", "HEAD").strip()
    manifest = {
        "schema": "thermo5-ef2-qualification-v1",
        "source": {
            "git_revision": revision,
            "worktree_dirty": bool(git_status.strip()),
            "git_status": [line for line in git_status.splitlines() if line.strip()],
            "diff_from_head_sha256": hashlib.sha256(diff).hexdigest(),
            "changed_file_sha256": changed_files,
        },
        "simulator": {
            "vcs_version": vcs_version,
            "compile_log": relative(compile_log, root),
            "compile_log_sha256": sha256(compile_log),
        },
        "configuration": {
            "tidsm_order": 2,
            "step": 5120,
            "input_width_bits": 16,
            "state_width_bits": 20,
            "interpolation": "centered_cubic",
            "word_count": 2072,
            "seeds": [271027, 271028, 271029],
        },
        "tests": test_records,
        "oracle_vectors": vector_records,
        "functional_coverage": cross_status,
        "urg_artifacts": {
            "log": relative(coverage_log, root),
            "log_sha256": sha256(coverage_log),
            "dashboard": relative(dashboard, root),
            "dashboard_sha256": sha256(dashboard),
            "ef2_group_report": relative(group_report, root),
            "ef2_group_report_sha256": sha256(group_report),
        },
        "limitations": [
            "The manifest records functional qualification and targeted URG bins, not full code-coverage closure.",
            "XPM, formal, GT Wizard/TXP, XSim, FPGA PPA/timing, and physical QAM256 BER are outside this run.",
        ],
    }
    output = run_dir / "qualification_manifest.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                      encoding="utf-8")
    print("THERMO5_EF2_MANIFEST_PASS=" + relative(output, root))


if __name__ == "__main__":
    main()
