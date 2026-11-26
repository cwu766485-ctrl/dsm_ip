#!/usr/bin/env python3
"""Run one long V1.4 counter case and audit both native toggle directions."""
from argparse import ArgumentParser
import json
from pathlib import Path
import re
import sys

from audit_dsm_v13_round5_instances import inventory, section
from generate_dsm_v13_round2_evidence import fragment_rows
from run_dsm_v14_commit_counter import checked_command
from run_dsm_v14_frame_replacement import CONFIGS, ROOT, sha256


def counter_directions(report, sku, counter, bit):
    results = {}
    for item in inventory(report, sku)[0]:
        if item["metric"] != "toggle" or item["module"] != "dpd_memory_poly":
            continue
        _, body = section(report, item["evidence"])
        rows = []
        for cells, _ in fragment_rows(body):
            if len(cells) < 4:
                continue
            match = re.fullmatch(rf"{counter}\[(\d+)(?::(\d+))?\]", cells[0])
            if match:
                high, low = sorted((int(match[1]), int(match[2] or match[1])), reverse=True)
                if low <= bit <= high:
                    rows.append(cells[2:4])
        if len(rows) != 1 or item["instance"] in results:
            raise ValueError(f"Ambiguous {counter}[{bit}] in {item['instance']}")
        results[item["instance"]] = rows[0]
    if len(results) != 16 or any(row != ["Yes", "Yes"] for row in results.values()):
        raise ValueError(f"Expected both directions in all 16 {counter}[{bit}] lanes: {results}")
    return results


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--sku", choices=CONFIGS, required=True)
    parser.add_argument("--saturation", action="store_true")
    parser.add_argument("--bit", type=int, choices=range(32), required=True)
    parser.add_argument("--frames", type=int, help="override the computed minimum packet count")
    for name in ("simv", "baseline-vdb", "out", "urg"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    out, simv, baseline, urg = (p.resolve() for p in
                                (args.out, args.simv, args.baseline_vdb, args.urg))
    if ROOT / "runs" not in out.parents or out.exists():
        parser.error("output must be a new directory below runs/")
    design = simv.with_name("simv.vdb")
    if not (simv.is_file() and design.is_dir() and urg.is_file() and baseline.is_dir()):
        parser.error("simv, its design VDB, URG, and a SKU-local baseline VDB are required")
    out.mkdir(parents=True)
    vectors = out / "vectors"
    generator = ROOT / "dv/uvm/refmodel/python/generate_dsm_v14_counter_soak_vectors.py"
    command = [sys.executable, str(generator), "--sku", args.sku.removesuffix("_axil"),
               "--out", str(vectors)]
    if args.saturation:
        command.append("--saturation")
    checked_command(command, out / "vectors.log")
    saturations = [int(value, 16) for value in
                   (vectors / "dpd_saturation_per_frame.mem").read_text().splitlines()]
    increment = min(saturations) if args.saturation else 57
    required_frames = ((1 << args.bit) + increment - 1) // increment
    frames = args.frames if args.frames is not None else required_frames
    if not required_frames <= frames <= (1 << 32):
        parser.error(f"selected target requires {required_frames} through 2^32 packets")
    print(f"{args.sku}: {frames} packets, target bit {args.bit}", flush=True)
    command = [
        str(simv), "+UVM_TESTNAME=thermo5_sku_axil_counter_soak_test", f"+VEC_DIR={vectors}",
        f"+COUNTER_SOAK_FRAMES={frames}", f"+COUNTER_SOAK_BIT={args.bit}",
        "-cm", "line+cond+fsm+tgl+branch+assert", "-cm_dir", str(out / "coverage.vdb"),
        "-l", str(out / "sim.log"),
    ]
    if args.saturation:
        command.append("+COUNTER_SOAK_SATURATION")
    checked_command(command, out / "stdout.log", cwd=out)
    log = (out / "sim.log").read_text()
    marker = (f"THERMO5_AXIL_COUNTER_SOAK_PASS frames={frames} words={frames * 56} "
              f"bit={args.bit} saturation={int(args.saturation)}")
    if marker not in log or any(not re.search(rf"(?m)^UVM_{level}\s*:\s*0\s*$", log)
                                for level in ("ERROR", "FATAL")):
        raise RuntimeError(f"Counter soak did not pass: {out / 'sim.log'}")
    counter = "saturation_count" if args.saturation else "sample_count"
    for label, parent in (("standalone", design), ("merged", baseline)):
        report = out / label
        command = [str(urg), "-full64", "-dir", str(parent), str(out / "coverage.vdb"),
                   "-report", str(report), "-dbname", f"{label}_counter_soak"]
        output = checked_command(command, out / f"urg_{label}.log", cwd=out)
        if re.search(r"Warning-|Error-|UCAPI-MAP", output):
            raise RuntimeError(f"Review URG merge diagnostics: {out / f'urg_{label}.log'}")
        directions = counter_directions(report, args.sku, counter, args.bit)
        if args.saturation:
            sample_directions = counter_directions(report, args.sku, "sample_count", args.bit)
    result = dict(configuration=args.sku, counter=counter, bit=args.bit, frames=frames,
                  backend_words=frames * 56, lanes=directions, simulation_sha256=sha256(out / "sim.log"))
    if args.saturation:
        result["sample_lanes"] = sample_directions
    (out / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"{args.sku}: {counter}[{args.bit}] hit both directions in {len(directions)} lanes")
    if args.saturation:
        print(f"{args.sku}: sample_count[{args.bit}] also hit both directions in {len(sample_directions)} lanes")


if __name__ == "__main__":
    main()
