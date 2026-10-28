#!/usr/bin/env python3
"""Cross-check and hash the Linux EF2 signoff evidence for one source revision."""

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


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def check_clean_log(path, marker=None):
    if not path.is_file():
        raise SystemExit("missing required regression log: " + str(path))
    text = path.read_text(encoding="utf-8", errors="replace")
    if not re.search(r"UVM_ERROR\s*:\s*0\b", text):
        raise SystemExit("missing zero UVM_ERROR summary: " + str(path))
    if not re.search(r"UVM_FATAL\s*:\s*0\b", text):
        raise SystemExit("missing zero UVM_FATAL summary: " + str(path))
    if marker and marker not in text:
        raise SystemExit("missing PASS marker in " + str(path) + ": " + marker)


def collect_evidence(paths, root):
    records = []
    for path in sorted({path.resolve() for path in paths if path.is_file()}):
        records.append({"path": relative(path, root), "sha256": sha256(path)})
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", required=True, type=Path)
    parser.add_argument("--generic-regression-dir", required=True, type=Path)
    parser.add_argument("--generic-vectors", required=True, type=Path)
    parser.add_argument("--stop-restart-dir", required=True, type=Path)
    parser.add_argument("--stop-restart-vectors", required=True, type=Path)
    parser.add_argument("--pair-lookahead-dir", required=True, type=Path)
    parser.add_argument("--serdes-dir", required=True, type=Path)
    parser.add_argument("--gt-parent-dir", required=True, type=Path)
    parser.add_argument("--qualification-manifest", required=True, type=Path)
    parser.add_argument("--formal-summary", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()

    root = args.repo_root.resolve()
    revision = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"], check=True,
        stdout=subprocess.PIPE, universal_newlines=True).stdout.strip()
    git_status = subprocess.run(
        ["git", "-C", str(root), "status", "--porcelain"], check=True,
        stdout=subprocess.PIPE, universal_newlines=True).stdout.splitlines()
    if git_status:
        raise SystemExit("signoff packaging requires a clean tracked/untracked worktree")

    generic = args.generic_regression_dir.resolve()
    generic_vectors = args.generic_vectors.resolve()
    stop_restart = args.stop_restart_dir.resolve()
    stop_restart_vectors = args.stop_restart_vectors.resolve()
    pair_dir = args.pair_lookahead_dir.resolve()
    serdes_dir = args.serdes_dir.resolve()
    gt_parent_dir = args.gt_parent_dir.resolve()
    qualification_path = args.qualification_manifest.resolve()
    formal_path = args.formal_summary.resolve()
    qualification = read_json(qualification_path)
    formal = read_json(formal_path)

    if qualification.get("source", {}).get("git_revision") != revision:
        raise SystemExit("VCS qualification source SHA differs from current HEAD")
    if qualification.get("source", {}).get("worktree_dirty"):
        raise SystemExit("VCS qualification was run with a dirty source tree")
    if formal.get("source", {}).get("git_revision") != revision:
        raise SystemExit("formal source SHA differs from VCS/current SHA")
    if formal.get("source", {}).get("worktree_dirty"):
        raise SystemExit("formal proof was run with a dirty source tree")
    if qualification.get("status") != "PASS" or formal.get("status") != "PASS":
        raise SystemExit("VCS qualification and formal summary must both be PASS")

    config = qualification.get("configuration", {})
    expected = {"tidsm_order": 2, "step": 5120, "state_width_bits": 20,
                "interpolation": "centered_cubic"}
    for key, value in expected.items():
        if config.get(key) != value:
            raise SystemExit(f"unexpected EF2 signoff configuration {key}={config.get(key)!r}")
    required_crosses = (
        "positive_candidate_x_stall", "negative_candidate_x_stall",
        "positive_x_rail", "negative_x_rail")
    for name in required_crosses:
        if qualification.get("functional_coverage", {}).get(name, {}).get("status") != "PASS":
            raise SystemExit("required EF2 functional cross did not pass: " + name)
    formal_jobs = {job.get("kind"): job.get("status") for job in formal.get("jobs", [])}
    if formal_jobs.get("ef2") != "PASS" or formal_jobs.get("ef2_pair") != "PASS":
        raise SystemExit("EF2 safety and pair-look-ahead equivalence proofs are required")

    positive_tests = (
        ("thermo5_sku_bittrue_test_seed1.log", "THERMO5_"),
        ("thermo5_sku_bubble_backpressure_test_seed2.log", "THERMO5_"),
        ("thermo5_sku_fifo_boundary_test_seed2.log", "THERMO5_"),
        ("thermo5_sku_fifo_empty_test_seed5.log", "THERMO5_"),
        ("thermo5_sku_reset_test_seed3.log", "THERMO5_"),
        ("thermo5_sku_reset_sweep_test_seed6.log", "THERMO5_"),
    )
    generic_logs = []
    for filename, marker_prefix in positive_tests:
        path = generic / filename
        text = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
        markers = [line for line in text.splitlines()
                   if line.startswith(marker_prefix) and "_UVM_PASS" in line]
        check_clean_log(path, markers[-1] if markers else "THERMO5_MISSING_UVM_PASS_MARKER")
        generic_logs.append(path)
    negative_path = generic / "illegal_frame_seed4.log"
    if not negative_path.is_file():
        raise SystemExit("missing expected-illegal-frame regression log: " + str(negative_path))
    negative_text = negative_path.read_text(encoding="utf-8", errors="replace")
    if ("THERMO5_ILLEGAL_FRAME_OBSERVED" not in negative_text or
            ("UVM_FATAL : 0" not in negative_text and "UVM_FATAL: 0" not in negative_text)):
        raise SystemExit("generic negative control did not observe the expected frame assertion")
    generic_logs.append(negative_path)
    for support in (generic / "compile.log", generic / "coverage_merge.log",
                    generic / "coverage" / "dashboard.html"):
        if not support.is_file():
            raise SystemExit("missing generic regression/URG evidence: " + str(support))

    stop_log = stop_restart / "thermo5_sku_axil_stop_restart_test_seed610215.log"
    check_clean_log(stop_log, "THERMO5_AXIL_STOP_RESTART_UVM_PASS")
    vector_sets = {
        "generic": sorted(generic_vectors.glob("*.mem")),
        "stop_restart": sorted(stop_restart_vectors.glob("*.mem")),
        "serializer_loopback": sorted(serdes_dir.glob("*.mem")),
    }
    if any(not files for files in vector_sets.values()):
        raise SystemExit("one or more required regression vector directories are empty")
    pair_log = pair_dir / "sim.log"
    pair_text = pair_log.read_text(encoding="utf-8", errors="replace") if pair_log.is_file() else ""
    if "THERMO5_EF2_PAIR_LOOKAHEAD_PASS cycles=4096 seed=20261028" not in pair_text:
        raise SystemExit("missing passing pair-look-ahead simulation log")
    serdes_log = serdes_dir / "sim.log"
    serdes_text = serdes_log.read_text(encoding="utf-8", errors="replace") if serdes_log.is_file() else ""
    if "THERMO5_FOUR_PA_SERDES_LOOPBACK_PASS words=56 bits_per_path=3584" not in serdes_text:
        raise SystemExit("missing passing four-PA serializer loopback log")
    gt_parent_log = gt_parent_dir / "run.log"
    gt_parent_text = gt_parent_log.read_text(encoding="utf-8", errors="replace") if gt_parent_log.is_file() else ""
    if "THERMO5_GT_PARENT_LINK_FAULT_PASS pa_immediate_blank=1 fault_sticky=1 reset_recovery=1" not in gt_parent_text:
        raise SystemExit("missing passing GT-parent behavioral fault/recovery log")

    evidence_paths = [qualification_path, formal_path, *generic_logs,
                      generic / "compile.log", generic / "coverage_merge.log",
                      generic / "coverage" / "dashboard.html", stop_log, pair_log,
                      serdes_dir / "compile.log", serdes_log,
                      gt_parent_dir / "compile.log", gt_parent_log]
    evidence_paths.extend(path for files in vector_sets.values() for path in files)
    evidence_paths.extend(root / record["log"]
                          for record in qualification.get("tests", []))
    evidence_paths.append(root / qualification.get("simulator", {}).get("compile_log", ""))
    evidence_paths.append(root / qualification.get("urg_artifacts", {}).get("log", ""))
    evidence_paths.append(root / qualification.get("urg_artifacts", {}).get("dashboard", ""))
    evidence_paths.append(root / qualification.get("urg_artifacts", {}).get("ef2_group_report", ""))
    evidence_paths.extend(root / file_record["path"]
                          for vector_set in qualification.get("oracle_vectors", [])
                          for file_record in vector_set.get("files", []))
    evidence_paths.extend(root / job[key] for job in formal.get("jobs", [])
                          for key in ("log", "setup", "properties"))
    evidence = collect_evidence(evidence_paths, root)

    manifest = {
        "schema": "thermo5-linux-ef2-signoff-v1",
        "status": "PASS_LINUX_DIGITAL_SCOPE",
        "source": {"git_revision": revision, "worktree_clean": True},
        "configuration": config,
        "checks": {
            "generic_ef2_uvm_regression": "PASS",
            "generic_raw_urg_artifact_generated": "PASS",
            "ef2_long_frame_and_saturation_qualification": "PASS",
            "ef2_scoped_formal_safety": "PASS",
            "pair_lookahead_formal_equivalence": "PASS",
            "pair_lookahead_vcs_directed_random": "PASS",
            "four_pa_serializer_loopback_model": "PASS",
            "gt_parent_link_loss_and_reset_recovery_behavioral": "PASS",
            "ef2_targeted_functional_crosses": "PASS",
            "complete_code_coverage": "OPEN",
            "real_xpm_and_gt_wizard": "OPEN_UNAVAILABLE_ON_LINUX_HOST",
            "fpga_timing_and_resources": "OPEN_NO_VIVADO_ROUTE",
            "behavioral_rf_model": "MODEL_ONLY",
            "physical_qam256_ber": "OPEN",
        },
        "formal": {"jobs": formal_jobs,
                   "ef2_core_configuration": formal.get("configuration")},
        "coverage": qualification.get("functional_coverage"),
        "regression_vectors": {
            label: [{"path": relative(path, root), "sha256": sha256(path)}
                    for path in files]
            for label, files in vector_sets.items()
        },
        "evidence": evidence,
        "evidence_count": len(evidence),
    }
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                      encoding="utf-8")
    print(json.dumps({"status": manifest["status"], "source_sha": revision,
                      "evidence_count": len(evidence), "manifest": relative(output, root)}))


if __name__ == "__main__":
    main()
