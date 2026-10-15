# Thermo3 Branch Frontier

## Current state — 2026-10-15

- This branch is a thermo3-focused source package forked from `origin/main`;
  the separate `thermo5` branch has already been pushed. `main` retains the
  complete multi-architecture repository.
- Pruned 751 tracked non-thermo3 RTL, DV, scripts, and build-flow files. Kept
  63 thermo3 dependency/verification/implementation source paths. Vendor IP,
  board collateral, archived reports, ignored `runs/`, and pre-existing
  untracked local directories were not removed.
- The focused package includes the thermo3 two-clock AXI-Stream frontend,
  exact 14:8 asynchronous FIFO/gearbox, x2/interp + memory-DPD + x2 path, two
  Fs/4 Cartesian TID planes, directed XSim, MATLAB references, ASIC/DC source
  manifest, and ZU15EG GT integration scripts. It does not include UVM or an
  AXI-Lite register interface.

## Verification evidence after pruning

- Thermo3 frontend XSim: PASS — `runs/thermo3_frontend_xsim_20261015_142811/`.
- Fs/4 dual-plane XSim: PASS —
  `runs/thermo3_fs4_multipa_xsim_20261015_142919/`.
- Generic CDC/gearbox XSim: PASS —
  `runs/thermo3_axis14_cdc_xsim_20261015_143045/`.
- XPM CDC/gearbox XSim: PASS —
  `runs/thermo3_axis14_cdc_xpm_xsim_20261015_143101/`.
- Same sparse-TDD workload produced 56 outputs from 32 accepted beats and
  matching digest `c677eb13eb65fd6a` in both modes. Baseline underflow=1 and
  LP underflow=0, as expected. SAIFs:
  `runs/lp_power_activity/thermo3_baseline_tdd_sparse_20261015_143116/` and
  `runs/lp_power_activity/thermo3_lp_tdd_sparse_20261015_143145/`.
  This is functional workload equivalence only; no power reduction number is
  claimed.

## Limits and next action

- These are directed RTL simulation results, not UVM coverage closure, board
  validation, GT serial deskew, ASIC signoff, or a fresh routed timing result.
- The latest FPGA thermo3 implementation evidence remains the archived report
  set from the full repository; this branch cleanup did not rerun OOC/route.
- Verify the focused source lists and scripts, run `git diff --check`, commit
  and push this branch, then return to `main` without disturbing local files.
