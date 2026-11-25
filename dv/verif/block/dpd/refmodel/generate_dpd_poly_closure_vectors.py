#!/usr/bin/env python3
"""Create signed-boundary vectors and an integer oracle for dpd_poly."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def signed(value: int, width: int) -> int:
    value &= (1 << width) - 1
    return value - (1 << width) if value & (1 << (width - 1)) else value


def sat16(value: int) -> tuple[int, bool]:
    if value > 32767:
        return 32767, True
    if value < -32768:
        return -32768, True
    return value, False


def model(i: int, q: int, enable: int, coeffs: list[int], order: int) -> tuple[int, int, bool]:
    c1r, c1i, c3r, c3i, c5r, c5i, c7r, c7i = coeffs
    if not enable:
        return i, q, False

    r2_i = signed(i * i, 32)
    r2_q = signed(q * q, 32)
    r2 = signed(signed(r2_i + r2_q, 34) >> 15, 32)
    r4 = signed(signed(r2 * r2, 64) >> 15, 32)
    r6 = signed(signed(r4 * r2, 64) >> 15, 32)

    def term(coeff: int, power: int) -> int:
        return signed(signed(coeff * power, 48) >> 15, 48)

    gain_r = signed(c1r + term(c3r, r2) + (term(c5r, r4) if order >= 5 else 0)
                    + (term(c7r, r6) if order >= 7 else 0), 48)
    gain_i = signed(c1i + term(c3i, r2) + (term(c5i, r4) if order >= 5 else 0)
                    + (term(c7i, r6) if order >= 7 else 0), 48)
    i_gr = signed(i * gain_r, 48)
    q_gi = signed(q * gain_i, 48)
    i_gi = signed(i * gain_i, 48)
    q_gr = signed(q * gain_r, 48)
    raw_i = signed(signed(i_gr - q_gi, 48) >> 14, 48)
    raw_q = signed(signed(i_gi + q_gr, 48) >> 14, 48)
    out_i, sat_i = sat16(raw_i)
    out_q, sat_q = sat16(raw_q)
    return out_i, out_q, sat_i or sat_q


def generate(order: int, output_dir: Path) -> dict:
    input_levels = [(0, 0), (1, -1), (8192, 0), (0, -8192),
                    (16384, 16384), (-16384, 8192), (32767, -32768),
                    (-32768, 32767)]
    scenarios = [
        (1, (16384, 0, 0, 0, 0, 0, 0, 0)),
        (1, (-16384, 8192, 0, 0, 0, 0, 0, 0)),
        (1, (8192, -2048, 2048, -1024, 0, 0, 0, 0)),
        (1, (4096, 2048, -1024, 512, 0, 0, 0, 0)),
        (1, (8192, 512, -1024, 256, 512, -256, 0, 0)),
        (1, (4096, -1024, 1024, -512, -256, 128, 0, 0)),
        (1, (4096, 512, 1024, -512, 256, -128, 128, -64)),
        (1, (8192, -512, -1024, 512, -256, 128, -128, 64)),
        # Disabled DPD must bypass even with adversarial coefficient values.
        (0, (32767, -32768, 32767, -32768, -32768, 32767, 32767, 32767)),
    ]
    rows = []
    saturation_count = 0
    for scenario_index, (enable, scenario_coeffs) in enumerate(scenarios):
        for level_index, (i, q) in enumerate(input_levels):
            # Rotate signs and magnitudes across terms to expose signed products.
            sign = -1 if (scenario_index + level_index) & 1 else 1
            row_coeffs = tuple(sign * value for value in scenario_coeffs)
            yi, yq, saturated = model(i, q, enable, list(row_coeffs), order)
            saturation_count += int(saturated)
            rows.append((i, q, enable, *row_coeffs, yi, yq))

    output_dir.mkdir(parents=True, exist_ok=True)
    payload = "".join(",".join(str(value) for value in row) + "\n" for row in rows)
    vector_path = output_dir / f"dpd_poly_order{order}.csv"
    vector_path.write_text(payload, encoding="ascii")
    manifest = {
        "schema": "dpd_poly_closure_vectors_v1",
        "order": order,
        "vectors": len(rows),
        "expected_output_saturations": saturation_count,
        "oracle": "independent Python integer model with RTL intermediate widths and shifts",
        "inputs": "signed 16-bit IQ; signed Q2.14 C1/C3/C5/C7",
        "sha256": hashlib.sha256(payload.encode("ascii")).hexdigest(),
    }
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--order", type=int, choices=(3, 5, 7), required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    manifest = generate(args.order, args.output_dir)
    print("DPD_POLY_VECTORS_PASS order=%d vectors=%d saturations=%d sha256=%s" % (
        manifest["order"], manifest["vectors"],
        manifest["expected_output_saturations"], manifest["sha256"]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
