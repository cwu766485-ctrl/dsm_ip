#!/usr/bin/env python3
"""Generate deterministic full-chain vectors for UVM system testcases."""

import csv
from pathlib import Path

from dsm_refmodel import ComplexCoeff, TxBpEf2Model, interp_frontend, memory_poly


MEMORY_DPD_COEFFICIENTS = (
    ((15000, -120), (4200, -900), (1800, -400)),
    ((1200, 320), (-800, 256), (-320, 160)),
    ((-640, -192), (384, -160), (128, -64)),
    ((256, 96), (-128, 64), (-48, 24)),
)


def write_system_vectors(out_dir, vector_set, inputs, dpd_i=None, dpd_q=None):
    """Write AXI input and RF expected transactions for one system scenario."""
    source_i = [item[0] for item in inputs] if dpd_i is None else dpd_i
    source_q = [item[1] for item in inputs] if dpd_q is None else dpd_q
    with (out_dir / f"{vector_set}_input.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(("n", "i_q1_15", "q_q1_15", "last"))
        for index, (i_value, q_value) in enumerate(inputs):
            writer.writerow((index, i_value, q_value, int(index == len(inputs) - 1)))

    interp_i = interp_frontend(source_i, mode=4)
    interp_q = interp_frontend(source_q, mode=4)
    model = TxBpEf2Model()
    with (out_dir / f"{vector_set}_expected_rf.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(("n", "rf_bit", "rf_signed", "phase", "if_sample"))
        for index, (i_value, q_value) in enumerate(zip(interp_i, interp_q)):
            step = model.step(i_value, q_value)
            writer.writerow((index, step.rf_bit, step.rf_signed, step.phase, step.if_sample))


def write_memory_dpd_coefficients(out_dir):
    """Write the inactive-bank load image used by the memory-DPD UVM testcase."""
    c1 = [ComplexCoeff(*tap[0]) for tap in MEMORY_DPD_COEFFICIENTS]
    c3 = [ComplexCoeff(*tap[1]) for tap in MEMORY_DPD_COEFFICIENTS]
    c5 = [ComplexCoeff(*tap[2]) for tap in MEMORY_DPD_COEFFICIENTS]
    with (out_dir / "memory_dpd_system_coeff.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(("tap", "order_code", "real_q2_14", "imag_q2_14"))
        for tap, (c1_value, c3_value, c5_value) in enumerate(zip(c1, c3, c5)):
            for order_code, value in enumerate((c1_value, c3_value, c5_value)):
                writer.writerow((tap, order_code, value.real, value.imag))
    return c1, c3, c5


def main():
    root = Path(__file__).resolve().parents[3]
    out_dir = root / "uvm_verif" / "refmodel" / "python" / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    inputs = [(4096 if index < 12 else -4096, 2048 if index & 1 else -2048)
              for index in range(24)]
    write_system_vectors(out_dir, "performance_sku", inputs)
    c1, c3, c5 = write_memory_dpd_coefficients(out_dir)
    memory_i, memory_q, saturated = memory_poly(
        [item[0] for item in inputs], [item[1] for item in inputs], c1, c3, c5, active_taps=4,
    )
    if any(saturated):
        raise RuntimeError("memory-DPD system vector unexpectedly saturated")
    write_system_vectors(out_dir, "memory_dpd_system", inputs, dpd_i=memory_i, dpd_q=memory_q)
    print(f"PERFORMANCE_SKU_VECTORS input={len(inputs)} rf={len(inputs) * 32}")
    print(f"MEMORY_DPD_SYSTEM_VECTORS input={len(inputs)} rf={len(inputs) * 32} taps=4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
