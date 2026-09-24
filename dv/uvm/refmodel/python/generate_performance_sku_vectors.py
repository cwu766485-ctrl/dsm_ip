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

LONGRUN_PRBS_INPUTS = 4096


def _xorshift32(state):
    """Return the next deterministic 32-bit state without host RNG dependence."""
    state ^= (state << 13) & 0xFFFF_FFFF
    state ^= state >> 17
    state ^= (state << 5) & 0xFFFF_FFFF
    return state & 0xFFFF_FFFF


def longrun_prbs_inputs(count=LONGRUN_PRBS_INPUTS):
    """Build a long Q1.15 stress vector with random and directed segments."""
    state = 0x6D2B_79F5
    inputs = []
    for index in range(count):
        segment = index % 1024
        state = _xorshift32(state)
        i_value = (state & 0xFFFF) % 49153 - 24576
        state = _xorshift32(state)
        q_value = (state & 0xFFFF) % 49153 - 24576
        if segment < 64:
            i_value, q_value = 0, 0
        elif segment == 64:
            i_value, q_value = 32760, -32760
        elif segment == 65:
            i_value, q_value = -32760, 32760
        elif segment == 66:
            i_value, q_value = -32768, 32767
        inputs.append((i_value, q_value))
    return inputs


def write_system_vectors(out_dir, vector_set, inputs, dpd_i=None, dpd_q=None, write_input=True):
    """Write AXI input and RF expected transactions for one system scenario."""
    source_i = [item[0] for item in inputs] if dpd_i is None else dpd_i
    source_q = [item[1] for item in inputs] if dpd_q is None else dpd_q
    if write_input:
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


def load_q1_15_input_csv(path):
    """Read a MATLAB-owned Q1.15 vector and validate its UVM CSV contract."""
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        required = {"n", "i_q1_15", "q_q1_15", "last"}
        if set(reader.fieldnames or ()) != required:
            raise RuntimeError(f"Unexpected CSV header in {path}: {reader.fieldnames}")
        rows = list(reader)
    if not rows:
        raise RuntimeError(f"QAM-OFDM input vector is empty: {path}")
    inputs = []
    for expected_index, row in enumerate(rows):
        index = int(row["n"])
        i_value = int(row["i_q1_15"])
        q_value = int(row["q_q1_15"])
        last = int(row["last"])
        if index != expected_index:
            raise RuntimeError(f"Non-contiguous vector index {index} at CSV row {expected_index}")
        if not (-32768 <= i_value <= 32767 and -32768 <= q_value <= 32767):
            raise RuntimeError(f"Out-of-range Q1.15 sample at index {index}")
        if last != int(expected_index == len(rows) - 1):
            raise RuntimeError(f"Invalid TLAST placement at input index {index}")
        inputs.append((i_value, q_value))
    return inputs


def write_qam_ofdm_expected_vectors(out_dir):
    """Generate RF golden values from the MATLAB-generated baseband CSV."""
    input_path = out_dir / "qam_ofdm_input.csv"
    if not input_path.exists():
        print("QAM_OFDM_VECTORS input=NOT_GENERATED")
        return 0
    inputs = load_q1_15_input_csv(input_path)
    write_system_vectors(out_dir, "qam_ofdm", inputs, write_input=False)
    print(f"QAM_OFDM_VECTORS input={len(inputs)} rf={len(inputs) * 32}")
    return len(inputs)


def main():
    root = Path(__file__).resolve().parents[3]
    out_dir = root / "uvm_verif" / "refmodel" / "python" / "out"
    out_dir.mkdir(parents=True, exist_ok=True)
    inputs = [(4096 if index < 12 else -4096, 2048 if index & 1 else -2048)
              for index in range(24)]
    write_system_vectors(out_dir, "performance_sku", inputs)
    write_system_vectors(out_dir, "longrun_prbs", longrun_prbs_inputs())
    write_qam_ofdm_expected_vectors(out_dir)
    c1, c3, c5 = write_memory_dpd_coefficients(out_dir)
    memory_i, memory_q, saturated = memory_poly(
        [item[0] for item in inputs], [item[1] for item in inputs], c1, c3, c5, active_taps=4,
    )
    if any(saturated):
        raise RuntimeError("memory-DPD system vector unexpectedly saturated")
    write_system_vectors(out_dir, "memory_dpd_system", inputs, dpd_i=memory_i, dpd_q=memory_q)
    print(f"PERFORMANCE_SKU_VECTORS input={len(inputs)} rf={len(inputs) * 32}")
    print(f"LONGRUN_PRBS_VECTORS input={LONGRUN_PRBS_INPUTS} rf={LONGRUN_PRBS_INPUTS * 32}")
    print(f"MEMORY_DPD_SYSTEM_VECTORS input={len(inputs)} rf={len(inputs) * 32} taps=4")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
