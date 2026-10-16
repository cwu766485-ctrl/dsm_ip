# Directed Verification

`dv/verif/` contains lightweight SystemVerilog block and subsystem tests for the
thermo5 transmitter. The full reusable IP-system environment is under
`dv/uvm/`; it owns the AXI-Stream/AXI-Lite agents, four-plane monitor,
scoreboard, functional coverage, and full-chain regressions.

## Layout

- `block/<block>/tb/`: isolated unit tests for FIFO/CDC, interpolation, DPD,
  the TID32 modulator, and the GT-user raw-word boundary.
- `subsystem/tx_frontend/` and `subsystem/tx_backend/`: the two thermo5
  signal-processing subsystem groups (frontend chain and four-plane TID/Fs4
  output backend).
- `integration/`: behavioral serializer loopback and optional GT-parent tests;
  these are integration-boundary checks, not additional subsystem categories.
- `scripts/`: XSim smoke runners. VCS focused block runners may live beside the
  block they test.
- `models/`: behavioral verification-only models, not synthesizable RTL.
- MATLAB golden vectors and simulator outputs are stored under MATLAB's output
  area or ignored `runs/`, not duplicated in the test source tree.

There is no separate top-level `tb/` directory: each testbench lives with its
block or subsystem. Simulator output is directed to ignored `runs/` directories
and is not source collateral.

## Thermo5 smoke entry points

Generate the MATLAB oracle vectors first, then run the full AXI/CDC/frontend
test:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\uvm\sim\generate_thermo5_sku_vectors.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_thermo5_i2_d1_axis.ps1 -VectorDir .\runs\uvm_thermo5_i2_d1\vectors
```

Focused block and subsystem runners are indexed in
[`RUN_REGRESSION.md`](RUN_REGRESSION.md). None of these behavioral tests alone
proves metastability, parent-level CDC/RDC closure, physical GT serialization,
or board/RF output.
