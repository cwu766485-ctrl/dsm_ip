# Thermo3 Cartesian TID Transmitter

This branch is the focused source and verification package for the thermo3
digital transmitter. The complete multi-architecture repository remains on
`main`; the thermo5-focused source branch is `thermo5`.

## Datapath

```text
AXI-Stream: 14 complex samples/beat @ 125 MHz
  -> asynchronous FIFO + exact 14:8 lane gearbox
  -> 8 complex samples/word @ 218.75 MHz
  -> frame-gain stage
  -> x2 polyphase interpolation (8 -> 16 lanes)
  -> 16-lane memory-polynomial DPD
  -> x2 polyphase interpolation (16 -> 32 lanes)
  -> two offset Cartesian TIDSM branches
  -> two aligned 64-bit PA code planes
```

The two PA planes are intended for equal-weight external combination into
three normalized levels. This RTL does not model the analog PA combiner or
claim measured RF performance. Input samples are signed 16-bit I/Q; lane 0 is
earliest. The stream rate is 1.75 Gcomplex/s at both the AXI and core
boundaries. Each 64-bit output plane at 218.75 MHz represents a 14.0-Gb/s raw
serial lane when connected to the configured GT boundary.

The thermo3 top has an AXI-Stream data interface, two clock/reset domains,
run/DPD coefficient controls, and two PA-plane ready/valid interfaces. There
is no AXI-Lite register block in this branch.

## RTL and reference model

- `rtl/tx_bandpass_if/tid32_thermo3_axis_frontend_tx.sv`: two-clock top.
- `rtl/axis/dsm_axis14_to_core8_cdc.sv`: FIFO and 14:8 gearbox.
- `rtl/tx_bandpass_if/tid32_thermo3_frontend_tx.sv`: frame gain, x2/DPD/x2.
- `rtl/tx_bandpass_if/tid32_thermo3_fs4_multipa_tx.sv`: paired TIDSM planes.
- `matlab/tx_bandpass_if/tid_thermo3_pipelined_step.m`: bit-true TID oracle.
- `syn/asic/thermo_frontend_dc_sources.f`: thermo3 ASIC/DC source manifest.

## Verification

Windows/Vivado XSim commands from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_fs4_multipa_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc_xpm.ps1
```

The full AXI ingress low-power activity test can compare the same sparse-TDD
payload under baseline and frame-safe enable control:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode baseline -Workload tdd_sparse
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode lp -Workload tdd_sparse
```

These are directed XSim tests, not UVM closure. The branch retains a
thermo3-only Design Compiler flow, ZU15EG dual-SFP GT build flow, and OOC
implementation scripts. A passing RTL simulation is not routed timing,
board-level CDC/RDC, serial deskew, or measured RF signoff. Historical project
evidence under `docs/` is retained for traceability; some records describe the
full upstream repository rather than this branch's source contents.
