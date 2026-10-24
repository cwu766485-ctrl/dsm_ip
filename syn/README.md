# Thermo5 Synthesis and Implementation

`rtl/` is the canonical implementation. The frozen FPGA configuration is the
source of truth for the matching ASIC mapping wrapper and verification model.

## Frozen Configuration

The FPGA routed OOC flow uses `tid32_thermo5_axis_frontend_tx` with
`INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, `FPGA_USE_XPM_FIFO=1`, and
`ENABLE_LOW_POWER_CTRL=0`. The frozen UVM configuration uses one active tap
with unity `c1_re=0x4000` and other coefficients zero. The ASIC wrapper fixes
that identity image as constants. The FPGA routed OOC top retains runtime DPD
coefficient pins, so its resource report is not a like-for-like PPA comparison
with the constant-specialized ASIC wrapper. It runs at 125 MHz on AXI ingress
and 218.75 MHz on the core. See
[`docs/verification/thermo5-uvm-architecture.md`](../docs/verification/thermo5-uvm-architecture.md)
for the signal flow and interfaces.

The matching ASIC wrapper uses the same frozen interpolation and DPD behavior.
Its generic async FIFO replaces the FPGA XPM FIFO. Run
`python3 syn/asic/check_thermo5_frozen_config.py` to detect configuration
drift, then use [`asic/README.md`](asic/README.md) for the authorized 28 nm
standard-cell mapping flow. This flow does not establish analog or RF PDK
support.

## FPGA Routed OOC

Run the no-AXI-Lite frozen top on ZU15EG with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_tid32_thermo5_axis_frontend_tx.ps1 `
  -Part xczu15eg-ffvb1156-2-i -SourceMHz 125 -CoreMHz 218.75
```

The 2026-10-15 routed OOC evidence reports WNS +0.504 ns and WHS +0.027 ns
under modeled internal constraints. The run omits real parent I/O budgets,
system CDC/RDC, board timing, and physical RF output; it is not system or
board signoff. The AXI-Lite variant is a separate integration flow and must
not be mixed with the frozen no-AXI-Lite SKU results.

## Linux Reference and Interpolation Benchmark

MATLAB remains useful as an independent reference, but is no longer required
to generate frozen thermo5 vectors. On Linux, use the pure-Python reference:

```bash
cd dv/uvm/refmodel/python
python3 generate_thermo5_frontend_vectors.py \
  --output-dir ../../../../runs/thermo5_python_vectors \
  --interp-taps 2 --profile random
python3 benchmark_thermo5_interp.py --symbols 64 --seed 20261022
```

The vector generator produces the same `.mem` interface consumed by the
thermo5 UVM scoreboard. The benchmark is a deterministic digital OFDM screen;
its image and adjacent-band metrics are not standard ACLR and do not include
TID, DPD, PA, RF filtering, or a receiver model. See
[`asic/PPA_MATRIX.md`](asic/PPA_MATRIX.md) for comparison rows and promotion
criteria.

Historical `p0_ooc_*` low-pass/EF/MASH reports and optional AXI-Lite
experiments are separate architecture records. They do not define the frozen
thermo5 configuration.
