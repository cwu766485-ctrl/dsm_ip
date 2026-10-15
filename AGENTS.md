# Thermo3 Branch Instructions

## Scope and source priority

This branch contains the thermo3 Cartesian TID transmitter only. Do not add
thermo5, alternate DSM families, generic portfolio experiments, or their
verification code here. `main` remains the full repository and `thermo5` is a
separate focused branch.

Read `docs/exec-plans/active/execution-frontier.md` and the relevant RTL,
MATLAB reference, testbench, and source list before changing behavior. Resolve
conflicts in this order: current user instruction, this file, executable
filelists/scripts, MATLAB bit-true model, RTL, then prose/comments.

## Core rules

- Keep public project files in English.
- Preserve MATLAB/RTL bit-true arithmetic, signedness, widths, scaling,
  rounding, saturation, latency, reset, update order, and sample ordering.
- Keep RTL synthesizable and interfaces stable unless explicitly requested.
- Never claim a check passed unless the command completed and its PASS marker
  was observed.
- Do not commit credentials, licenses, PDK collateral, restricted board data,
  tool caches, waveforms, generated logs, or run outputs.
- Preserve existing generated/vendor collateral, reports, and untracked local
  files. Put new disposable runs under the ignored `runs/` directory.

## Thermo3 design boundary

- Main two-clock top: `rtl/tx_bandpass_if/tid32_thermo3_axis_frontend_tx.sv`.
- AXI ingress/CDC/gearbox: `rtl/axis/dsm_axis14_to_core8_cdc.sv` and FIFO,
  reset, frame-gain, and frame-power dependencies listed in
  `syn/asic/thermo_frontend_dc_sources.f`.
- Core datapath: `rtl/tx_bandpass_if/tid32_thermo3_frontend_tx.sv` and
  `tid32_thermo3_fs4_multipa_tx.sv` plus their DPD, interpolation, GT-boundary,
  and Cartesian-TID dependencies.
- Bit-true source: `matlab/tx_bandpass_if/tid_thermo3_pipelined_step.m` and
  the thermo3 vector generators in the same directory.
- Directed tests: `dv/verif/`; this branch does not contain UVM.
- OOC/ASIC/GT implementation entry points are under `syn/` and
  `fpga/zu15eg/` / `fpga/thermo3_lp/`.

## Required verification

After RTL changes, run all four directed thermo3 flows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_tid32_thermo3_fs4_multipa_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_axis14_to_core8_cdc_xpm.ps1
```

For changes to low-power control, also run baseline and LP sparse-TDD tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode baseline -Workload tdd_sparse
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_lp_power_activity.ps1 -Mode lp -Workload tdd_sparse
```

For synthesis/timing changes, use the thermo3-specific scripts and preserve
unique run directories:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_tid32_thermo3_frontend_tx.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_tid32_thermo3_fs4_multipa_tx.ps1
```

## Documentation and handoff

Update `docs/UPDATE_LOG.md` and the concise execution frontier when status,
evidence, or next steps materially change. Historical documentation is kept
for provenance and may describe source that is intentionally absent from this
focused branch. Treat board/GT integration evidence separately from RTL
simulation and OOC timing.
