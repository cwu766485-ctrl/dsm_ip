# Interpolation Block

## DUT

- `rtl/interp/dsm_interp_frontend.sv` and its instantiated halfband FIR, CIC,
  compensation FIR, and pipeline support RTL.

## Testbenches

`tb/` verifies bypass, x4, x8, x16, x32, phase, latency, reset, valid gaps,
backpressure, signed extrema, and randomized stalls. The 2026-08-12 regression
passed modes 0 to 4 and x32 I0/I1/I2/I3 with 4096 samples per output and zero
mismatches; the random protocol test observed 97 inputs and 1084 stalls. Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1
```

## Reference and Vectors

- MATLAB fixed model: `matlab/models/interp_frontend_fixed.m`.
- Python integer reference: `uvm_verif/refmodel/python/dsm_refmodel/interp.py`.
- MATLAB vector generator: `matlab/models/prepare_interp_frontend_bittrue_vectors.m`.
- Generated vectors: `matlab/out/interp_frontend/bittrue/`.
- Per-run copies and RTL dumps: `verif/out_xsim_interp_frontend/`.
