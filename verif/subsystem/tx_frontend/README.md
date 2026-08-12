# TX Frontend Subsystem

## Scope

This subsystem verifies the connected streaming boundary:

```text
AXI-Stream-like I/Q -> DPD bypass pipeline -> x4 halfband interpolation
```

The bypass selection intentionally isolates the ten-cycle DPD transport latency,
ready/valid propagation, and interpolation sample expansion. Poly/LUT/memory
DPD arithmetic and coefficient-bank safety are separately signed off at block
level and in the IP-system UVM tests.

## DUT Boundary

- `rtl/dpd/dpd_poly.v`
- `rtl/dpd/dpd_lut.v`
- `rtl/dpd/dpd_memory_poly.v`
- `rtl/dpd/dpd_frontend.v`
- `rtl/interp/dsm_interp2_halfband.sv`
- `rtl/interp/dsm_interp_frontend.sv`

## Reference and Evidence

`uvm_verif/refmodel/python/generate_tx_frontend_vectors.py` generates signed
corner values and deterministic random I/Q traffic. The expected x4 samples
come from the Python integer interpolation model. The testbench randomizes both
input bubbles and output backpressure and compares every accepted output.

On 2026-08-12, the following XSim regression passed with zero mismatch:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_tx_frontend_bittrue.ps1 -Inputs 97
```

Evidence: 97 input I/Q samples, 388 output I/Q samples, and 140 output stall
cycles. This is not a claim that all runtime DPD modes are subsystem-signed off;
those modes remain covered by the DPD block and system UVM matrices.
