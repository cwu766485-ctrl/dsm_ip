#!/usr/bin/env python3
"""Emit a simulation-only fixed-point seed/regret C reference after all gates pass."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


OFFSETS = ((0, 0, 0), (48, -32, 16), (-48, 32, -16),
           (24, 40, -24), (-24, -40, 24), (64, 16, -40))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    with args.report.open(encoding="ascii") as handle:
        report = json.load(handle)
    if not report.get("simulation_only") or not report.get("export_allowed"):
        raise SystemExit("Refusing C export: all strict simulation LOSO gates must pass.")
    if report.get("dsm_config_id") != "efdsm_1bit_osr32_interp0":
        raise SystemExit("Refusing C export: unexpected DSM provenance.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="ascii", newline="\n") as handle:
        handle.write("#ifndef DSM_DPD_SEED_REGRET_SIM_REFERENCE_H\n")
        handle.write("#define DSM_DPD_SEED_REGRET_SIM_REFERENCE_H\n\n")
        handle.write("/* Generated from strict behavioral simulation LOSO; not RF evidence. */\n")
        handle.write("#define DSM_DPD_SEED_REGRET_SIM_REFERENCE_AVAILABLE 1U\n")
        handle.write("#define DSM_DPD_SEED_REGRET_SIM_REFERENCE_SIMULATION_ONLY 1U\n")
        handle.write("#define DSM_DPD_SEED_REGRET_SIM_REFERENCE_PACKAGE_COUNT 6U\n")
        handle.write("#define DSM_DPD_SEED_REGRET_SIM_REFERENCE_LOCAL_CANDIDATES 14U\n")
        handle.write("static const int dsm_dpd_seed_regret_q214_offsets[6][3] = {\n")
        for index, offset in enumerate(OFFSETS):
            suffix = "," if index + 1 < len(OFFSETS) else ""
            handle.write(f"    {{{offset[0]}, {offset[1]}, {offset[2]}}}{suffix}\n")
        handle.write("};\n\n#endif /* DSM_DPD_SEED_REGRET_SIM_REFERENCE_H */\n")
    print(f"Wrote simulation-only C reference: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
