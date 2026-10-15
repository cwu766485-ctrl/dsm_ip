# Update Log

## 2026-10-15 — DSM algorithm study branch

- Scoped this branch to scalar-sample Cartesian low-pass DSM cores and their
  reference models, P0 verification carriers, and OOC comparison flow.
- Removed the unrelated system-transmitter, control-plane, DPD, interpolation,
  CDC, GT, board, and full-system DV sources from this branch. The full project
  remains on `main`.
- Rebuilt the P0 source filelist and XSim launchers to use canonical `dv/`
  paths, isolated timestamped run folders, and fail on missing or failed test
  summaries. Updated MATLAB default lookup to the new run location.
- Added branch-specific specification, verification plan, architecture guide,
  navigation, and agent instructions.
- Checks passed on 2026-10-15 with Vivado XSim 2024.1 and MATLAB R2025a:
  - `run_xsim_p0_all.ps1 -OutDir .\runs\dsm\p0_xsim_20261015_branchcheck_02`:
    7/7 algorithms, 65,536 samples each, zero errors.
  - `run_xsim_p0_multibit.ps1 -OutDir .\runs\dsm\p0_multibit_xsim_20261015_branchcheck_01`:
    1/1 carrier, 65,536 samples, zero errors.
  - `p0_compare_rtl_xsim()` and `compare_multibit_rtl_xsim()`:
    all seven single-bit and all seven 4-bit multi-bit modes matched their
    MATLAB models over 65,536 samples each, with zero mismatches.
  - `git diff --check` passed (only Git line-ending normalization warnings).
- Limits: historical OOC data is retained for comparison only; no new OOC run
  or board-level claim is included in this branch setup.
