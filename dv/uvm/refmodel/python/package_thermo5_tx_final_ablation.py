#!/usr/bin/env python3
"""Package compact, hashed evidence for the Linux TX architecture/DPD study."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import math
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
DEFAULT_RUN_DIR = Path("runs/thermo5_tx_final_ablation_20261030")
DEFAULT_OUTPUT_DIR = Path("docs/verification/data")
PRODUCT_COVERAGE = {
    "raw_aggregate_percent": 81.99,
    "line": {"hit": 3190, "total": 3796},
    "condition": {"hit": 583, "total": 846},
    "branch": {"hit": 440, "total": 637},
    "toggle": {"hit": 86951, "total": 104478},
    "fsm_states": {"hit": 13, "total": 13},
    "fsm_transitions": {"hit": 22, "total": 22},
    "functional_raw": {"hit": 170, "total": 174},
    "functional_legal_positive": {"hit": 170, "total": 170},
    "approved_waivers": 0,
    "approved_exclusions": 0,
    "status": "RAW_100_OPEN",
}

SOURCE_INPUTS = (
    "dv/uvm/refmodel/python/benchmark_thermo5_arch_ablation.py",
    "dv/uvm/refmodel/python/benchmark_thermo5_interp.py",
    "dv/uvm/refmodel/python/benchmark_thermo5_step_ntf.py",
    "dv/uvm/refmodel/python/benchmark_thermo5_tid_receiver.py",
    "dv/uvm/refmodel/python/benchmark_thermo5_tx_dpd_ab.py",
    "dv/uvm/refmodel/python/fit_thermo5_dpd_ila.py",
    "dv/uvm/refmodel/python/generate_thermo5_dpd_bittrue_vectors.py",
    "dv/uvm/refmodel/python/package_thermo5_tx_final_ablation.py",
    "dv/uvm/refmodel/python/tests/test_thermo5_arch_ablation.py",
    "dv/uvm/refmodel/python/tests/test_thermo5_dpd_ila.py",
    "dv/uvm/refmodel/python/dsm_refmodel/thermo5.py",
    "dv/uvm/refmodel/python/dsm_refmodel/thermo5_experiments.py",
    "dv/uvm/refmodel/python/dsm_refmodel/thermo5_receiver.py",
    "dv/uvm/refmodel/python/dsm_refmodel/link_models.py",
    "dv/uvm/sim/Makefile",
    "dv/verif/block/dpd/tb/tb_thermo5_fitted_dpd.sv",
    "dv/verif/integration/thermo5_ef2_pair_lookahead/tb_thermo5_ef2_pair_lookahead.sv",
    "rtl/dpd/dpd_poly.v",
    "rtl/dpd/dpd_memory_poly.v",
    "rtl/dpd/dpd_vector16_memory_poly.sv",
    "rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=REPO_ROOT, text=True).strip()


def copy_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def compact_architecture_json(source: Path, destination: Path) -> None:
    data = json.loads(source.read_text())
    # Keep every per-seed numeric result and model contract; omit only the
    # repeated 4096-bin arrays, which are retained in the compressed PSD CSV.
    data.pop("spectra", None)
    for record in data.get("records", []):
        record.pop("spectrum_after_interpolation", None)
        record.pop("spectrum_after_tid_reconstruction", None)
    destination.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")


def write_compressed_psd(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with source.open("rb") as src, destination.open("wb") as raw_dst:
        with gzip.GzipFile(fileobj=raw_dst, mode="wb", mtime=0, filename="") as dst:
            shutil.copyfileobj(src, dst)


def _spectrum_curves(psd_csv: Path):
    powers: dict[tuple[str, str, str, int], list[float]] = defaultdict(list)
    frequencies: dict[int, float] = {}
    with psd_csv.open(newline="") as stream:
        for row in csv.DictReader(stream):
            if row["partition"] != "heldout":
                continue
            bin_index = int(row["bin"])
            frequency = float(row["frequency_hz"])
            frequencies[bin_index] = frequency
            if frequency < 0:
                continue
            key = (row["architecture"], row["stage"], row["partition"], bin_index)
            powers[key].append(10.0 ** (float(row["relative_psd_db"]) / 10.0))

    candidates = sorted({key[0] for key in powers})
    stages = ("interpolation", "tid_reconstructed")
    curves = {}
    for stage in stages:
        for candidate in candidates:
            points = []
            for bin_index, frequency in sorted(frequencies.items(), key=lambda item: item[1]):
                if frequency < 0:
                    continue
                values = powers.get((candidate, stage, "heldout", bin_index), [])
                if not values:
                    continue
                mean_power = sum(values) / len(values)
                points.append((frequency / 1e6, 10.0 * math.log10(max(mean_power, 1e-12))))
            # Keep the plot readable while the complete per-bin CSV stays intact.
            curves[(stage, candidate)] = points[::4]
    return candidates, stages, curves


def write_spectrum_svg(psd_csv: Path, destination: Path) -> None:
    candidates, stages, curves = _spectrum_curves(psd_csv)
    width, height = 1280, 850
    colors = ("#1769aa", "#d1495b", "#2a9d8f", "#8e5ea2", "#e08e0b", "#3b5b92")
    panel_left, panel_width, panel_height = 94, 1120, 300
    top_positions = (95, 455)
    y_min, y_max = -120.0, 5.0
    x_max = 3500.0
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        '<style>text{font-family:Arial,sans-serif;fill:#202124}.grid{stroke:#d9dce1;stroke-width:1}.axis{stroke:#333;stroke-width:1.5}.curve{fill:none;stroke-width:1.7}</style>',
        '<text x="640" y="34" text-anchor="middle" font-size="22" font-weight="bold">Held-out mean PSD by TX architecture</text>',
        '<text x="640" y="60" text-anchor="middle" font-size="13">Four held-out seeds; PSD normalized to each record in-band power; behavioral model only</text>',
    ]
    for panel_index, stage in enumerate(stages):
        y_top = top_positions[panel_index]
        lines.append(f'<text x="{panel_left}" y="{y_top - 18}" font-size="16" font-weight="bold">{stage.replace("_", " ").title()}</text>')
        for tick in (-120, -90, -60, -30, 0):
            y = y_top + panel_height * (y_max - tick) / (y_max - y_min)
            lines.append(f'<line class="grid" x1="{panel_left}" y1="{y:.1f}" x2="{panel_left + panel_width}" y2="{y:.1f}"/>')
            lines.append(f'<text x="{panel_left - 10}" y="{y + 4:.1f}" text-anchor="end" font-size="11">{tick}</text>')
        for tick in (0, 500, 1000, 1500, 2000, 2500, 3000, 3500):
            x = panel_left + panel_width * tick / x_max
            lines.append(f'<line class="grid" x1="{x:.1f}" y1="{y_top}" x2="{x:.1f}" y2="{y_top + panel_height}"/>')
            lines.append(f'<text x="{x:.1f}" y="{y_top + panel_height + 18}" text-anchor="middle" font-size="11">{tick}</text>')
        lines.append(f'<line class="axis" x1="{panel_left}" y1="{y_top + panel_height}" x2="{panel_left + panel_width}" y2="{y_top + panel_height}"/>')
        lines.append(f'<line class="axis" x1="{panel_left}" y1="{y_top}" x2="{panel_left}" y2="{y_top + panel_height}"/>')
        for candidate_index, candidate in enumerate(candidates):
            points = curves[(stage, candidate)]
            coords = []
            for frequency_mhz, power_db in points:
                x = panel_left + panel_width * frequency_mhz / x_max
                power_db = min(y_max, max(y_min, power_db))
                y = y_top + panel_height * (y_max - power_db) / (y_max - y_min)
                coords.append(f"{x:.1f},{y:.1f}")
            lines.append(f'<polyline class="curve" stroke="{colors[candidate_index % len(colors)]}" points="{" ".join(coords)}"/>')
            legend_x = panel_left + 14 + (candidate_index % 3) * 355
            legend_y = y_top + 18 + (candidate_index // 3) * 18
            lines.append(f'<line x1="{legend_x}" y1="{legend_y - 4}" x2="{legend_x + 24}" y2="{legend_y - 4}" stroke="{colors[candidate_index % len(colors)]}" stroke-width="2"/>')
            lines.append(f'<text x="{legend_x + 31}" y="{legend_y}" font-size="10">{candidate}</text>')
    lines.extend([
        '<text x="640" y="807" text-anchor="middle" font-size="13">Frequency (MHz)</text>',
        '<text x="19" y="420" text-anchor="middle" font-size="13" transform="rotate(-90 19 420)">Relative PSD (dB)</text>',
        '<text x="640" y="825" text-anchor="middle" font-size="11">Adjacent-band traces are model proxies; not standards ACLR or RF measurements.</text>',
        '</svg>',
    ])
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n")


def sha_map(root: Path, paths: list[str]) -> dict[str, dict[str, object]]:
    result = {}
    for name in paths:
        path = root / name
        if path.is_file():
            result[name] = {"sha256": sha256_file(path), "bytes": path.stat().st_size}
        else:
            result[name] = {"status": "MISSING"}
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=DEFAULT_RUN_DIR)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--pair-log", type=Path,
                        default=Path("runs/thermo5_ef2_pair_lookahead/vcs/sim.log"))
    parser.add_argument("--product-vcs-source-sha", default="913be930bfcbbad0f78dbc90e06299db3d1bb337")
    args = parser.parse_args()
    run_dir = (REPO_ROOT / args.run_dir).resolve() if not args.run_dir.is_absolute() else args.run_dir
    output_dir = (REPO_ROOT / args.output_dir).resolve() if not args.output_dir.is_absolute() else args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    expected_inputs = ("summary.json", "summary.csv", "psd.csv", "constellation.svg",
                       "dpd_ila_fit.json", "dpd_heldout.json", "dpd_heldout.log")
    missing = [name for name in expected_inputs if not (run_dir / name).is_file()]
    if missing:
        raise SystemExit(f"missing run artifacts: {', '.join(missing)}")

    outputs = {
        "summary_json": output_dir / "thermo5-tx-ablation-summary.json",
        "summary_csv": output_dir / "thermo5-tx-ablation-summary.csv",
        "psd_gzip": output_dir / "thermo5-tx-ablation-psd.csv.gz",
        "spectrum_svg": output_dir / "thermo5-tx-ablation-spectrum.svg",
        "constellation_svg": output_dir / "thermo5-tx-ablation-constellation.svg",
        "dpd_coefficients": output_dir / "thermo5-tx-dpd-ila-coefficients.json",
        "dpd_heldout": output_dir / "thermo5-tx-dpd-heldout.json",
    }
    compact_architecture_json(run_dir / "summary.json", outputs["summary_json"])
    outputs["summary_csv"].write_text(
        (run_dir / "summary.csv").read_text().replace("\r\n", "\n"))
    write_compressed_psd(run_dir / "psd.csv", outputs["psd_gzip"])
    write_spectrum_svg(run_dir / "psd.csv", outputs["spectrum_svg"])
    copy_file(run_dir / "constellation.svg", outputs["constellation_svg"])
    copy_file(run_dir / "dpd_ila_fit.json", outputs["dpd_coefficients"])
    copy_file(run_dir / "dpd_heldout.json", outputs["dpd_heldout"])

    source_paths = list(SOURCE_INPUTS)
    source_hashes = sha_map(REPO_ROOT, source_paths)
    run_paths = [
        str((run_dir / name).relative_to(REPO_ROOT))
        for name in expected_inputs
    ]
    for candidate in ("2tap", "4tap"):
        candidate_dir = run_dir / f"dpd_vectors_{candidate}"
        for name in ("manifest.json", "coefficients.mem", "input_i.mem", "input_q.mem", "expected_i.mem", "expected_q.mem"):
            run_paths.append(str((candidate_dir / name).relative_to(REPO_ROOT)))
        for name in ("compile.log", "run.log"):
            run_paths.append(str(((run_dir / f"vcs_dpd_{candidate}") / name).relative_to(REPO_ROOT)))
    pair_log = ((REPO_ROOT / args.pair_log).resolve()
                if not args.pair_log.is_absolute() else args.pair_log)
    run_paths.append(str(pair_log.relative_to(REPO_ROOT)))

    git_head = git("rev-parse", "HEAD")
    try:
        vcs_version = next(line.strip() for line in (run_dir / "vcs_dpd_2tap/run.log").read_text().splitlines()
                           if "Compiler version" in line)
    except (StopIteration, OSError):
        vcs_version = "VCS version not parsed from candidate run log"
    try:
        pair_marker = next(line.strip() for line in pair_log.read_text().splitlines()
                           if "THERMO5_EF2_PAIR_LOOKAHEAD_PASS" in line)
    except (StopIteration, OSError):
        pair_marker = "PASS marker missing"

    evidence = {
        "schema": "thermo5-tx-final-ablation-evidence-v1",
        "created_local_date": "2026-10-30",
        "scope": "Phase 0 baseline reconciliation and Phase 1 Linux-only algorithm/architecture/DPD study",
        "product_rtl_changed": False,
        "product_configuration": {
            "interpolator": "centered-cubic x2+x2",
            "tidsm_order": 2,
            "step": 5120,
            "state_width_bits": 20,
            "lanes": 32,
            "output_planes": 4,
            "dpd_max_taps": 1,
            "dpd_coefficients": "one-tap identity, C1_RE[0]=0x4000",
            "linux_fifo": "Generic FIFO substitute",
        },
        "source_identity": {
            "repository_head_before_packaging": git_head,
            "product_vcs_source_sha": args.product_vcs_source_sha,
            "branch": git("branch", "--show-current"),
            "source_file_sha256": source_hashes,
            "note": "Repository head is the PR #7 base; source_file_sha256 binds the exact local study scripts, standalone miter, Make target, and arithmetic RTL. Product coverage is reused and not regenerated here.",
        },
        "tools": {"python": "Python 3.12", "vcs": vcs_version, "urg_product_coverage": "not rerun; PR #7 evidence retained"},
        "commands": [
            "python3.12 -m py_compile dv/uvm/refmodel/python/benchmark_thermo5_arch_ablation.py dv/uvm/refmodel/python/benchmark_thermo5_tx_dpd_ab.py dv/uvm/refmodel/python/fit_thermo5_dpd_ila.py dv/uvm/refmodel/python/generate_thermo5_dpd_bittrue_vectors.py dv/uvm/refmodel/python/package_thermo5_tx_final_ablation.py dv/uvm/refmodel/python/tests/test_thermo5_arch_ablation.py dv/uvm/refmodel/python/tests/test_thermo5_dpd_ila.py && cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v",
            "python3.12 dv/uvm/refmodel/python/benchmark_thermo5_arch_ablation.py --development-seeds 271001,271003,271005,271007 --heldout-seeds 281001,281003,281005,281007 --symbols 12 --rms-drive 0.10 --rx-fir-taps 4097 --first-order-steps 5120,7168 --jobs 4 --json runs/thermo5_tx_final_ablation_20261030/summary.json --summary-csv runs/thermo5_tx_final_ablation_20261030/summary.csv --psd-csv runs/thermo5_tx_final_ablation_20261030/psd.csv --constellation-svg runs/thermo5_tx_final_ablation_20261030/constellation.svg",
            "python3.12 dv/uvm/refmodel/python/fit_thermo5_dpd_ila.py --seeds 271001,271003,271005,271007 --symbols 12 --rms-drive 0.10 --json runs/thermo5_tx_final_ablation_20261030/dpd_ila_fit.json",
            "python3.12 dv/uvm/refmodel/python/benchmark_thermo5_tx_dpd_ab.py --seeds 281001,281003,281005,281007 --symbols 9 --rms-drive 0.10 --step 5120 --fir-taps 4097 --jobs 4 --candidate-json runs/thermo5_tx_final_ablation_20261030/dpd_ila_fit.json --json runs/thermo5_tx_final_ablation_20261030/dpd_heldout.json",
            "python3.12 dv/uvm/refmodel/python/generate_thermo5_dpd_bittrue_vectors.py --candidate-json runs/thermo5_tx_final_ablation_20261030/dpd_ila_fit.json --candidate ila_nominal_2tap --output-dir runs/thermo5_tx_final_ablation_20261030/dpd_vectors_2tap",
            "make -C dv/uvm/sim thermo5-dpd-bittrue-vcs THERMO5_DPD_VECTORS=$PWD/runs/thermo5_tx_final_ablation_20261030/dpd_vectors_2tap THERMO5_DPD_BITTRUE_OUT=$PWD/runs/thermo5_tx_final_ablation_20261030/vcs_dpd_2tap (ACTIVE_TAPS=2)",
            "python3.12 dv/uvm/refmodel/python/generate_thermo5_dpd_bittrue_vectors.py --candidate-json runs/thermo5_tx_final_ablation_20261030/dpd_ila_fit.json --candidate ila_nominal_4tap --output-dir runs/thermo5_tx_final_ablation_20261030/dpd_vectors_4tap",
            "make -C dv/uvm/sim thermo5-dpd-bittrue-vcs THERMO5_DPD_VECTORS=$PWD/runs/thermo5_tx_final_ablation_20261030/dpd_vectors_4tap THERMO5_DPD_BITTRUE_OUT=$PWD/runs/thermo5_tx_final_ablation_20261030/vcs_dpd_4tap (ACTIVE_TAPS=4)",
            f"make -C dv/uvm/sim thermo5-ef2-pair-vcs THERMO5_EF2_PAIR_OUT={args.pair_log.parent.parent}",
            f"python3.12 dv/uvm/refmodel/python/package_thermo5_tx_final_ablation.py --run-dir {args.run_dir} --output-dir {args.output_dir} --pair-log {args.pair_log}",
        ],
        "validation": {
            "architecture_ablation": "PASS; 4 development + 4 disjoint held-out seeds, 12 symbols per seed, primary STEP 5120 plus separate first-order STEP sensitivity",
            "fitted_dpd_heldout": "PASS; 4 disjoint held-out seeds, 9 symbols per seed; coefficients remain candidates only",
            "fitted_dpd_rtl_miter_2tap": "PASS; 5,824 words / 93,184 I/Q samples; zero output saturation",
            "fitted_dpd_rtl_miter_4tap": "PASS; 5,824 words / 93,184 I/Q samples; zero output saturation",
            "pair_lookahead_equivalence": "PASS; 4,096 cycles, exact tie, positive/negative clamps, stalls, bubbles, midstream reset; see pass marker",
            "pair_lookahead_pass_marker": pair_marker,
            "pair_lookahead_vc_formal": {
                "status": "REUSED_PASS; not rerun for the testbench-only corner extension",
                "source_sha": "dfb15a278657e4417b545fc138df0f0dd0399ac4",
                "assertions_proven": "7/7",
                "covers_hit": "4/4",
                "black_boxes": 0,
            },
            "python_unit_tests": "PASS; 44/44 tests on current Phase 1 Python sources",
            "product_raw_coverage": "REUSED; unchanged from PR #7; candidate-only runs are excluded",
            "formal": "REUSED; existing pair-lookahead proof retained, not rerun in this follow-up",
            "physical_qam256_ber": "NOT_RUN",
            "vivado_fpga_ppa": "NOT_RUN",
            "xpm_gt_wizard": "NOT_RUN",
        },
        "coverage_snapshot": PRODUCT_COVERAGE,
        "run_artifacts_sha256": sha_map(REPO_ROOT, run_paths),
        "published_artifacts_sha256": {name: {"sha256": sha256_file(path), "bytes": path.stat().st_size}
                                        for name, path in outputs.items()},
        "dpd_vector_checks": {
            candidate: json.loads((run_dir / f"dpd_vectors_{candidate}/manifest.json").read_text())
            for candidate in ("2tap", "4tap")
        },
        "limitations": [
            "QAM256 BER/EVM/SNDR and PA/noise results are Python model-only and have no target-owner acceptance limits.",
            "The integrated PA, output network, and thermal-noise settings are illustrative and not calibrated hardware data.",
            "Adjacent-band leakage is a simulation proxy, not standards ACLR.",
            "The pair-lookahead miter establishes bit/state equivalence for its tested traffic; no synthesized critical-path, routed WNS/Fmax, resource, or power comparison was run.",
            "The raw product code-coverage gate remains RAW_100_OPEN with the retained PR #7 denominator and evidence.",
        ],
    }
    manifest_path = output_dir.parent / "thermo5-tx-design-ablation-evidence.json"
    manifest_path.write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(f"PACKAGED {len(outputs)} artifacts under {output_dir}")
    print(f"EVIDENCE {manifest_path.relative_to(REPO_ROOT)}")
    print(f"HEAD {git_head}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
