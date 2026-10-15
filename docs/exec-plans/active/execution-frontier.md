# DSM Branch Execution Frontier

## Objective

Maintain a compact algorithm-study branch for scalar-sample Cartesian
low-pass DSM cores, with reproducible MATLAB/XSim comparisons and an optional
FPGA OOC sweep.

## Current source scope

- Single-bit LP1/LP2/EF1/EF2/MASH11/MASH111/MASH22 RTL cores.
- Parameterized multi-bit DSM core and seven algorithm wrappers.
- P0 I/Q tops retained as simulation/OOC carriers, not as the design target.
- MATLAB model files, deterministic vectors, XSim launchers, and P0 OOC flow.
- Full transmitter, DPD, interpolation, AXI/FIFO, GT, board, and full-system
  UVM sources are not part of this branch.

## Current status

- Branch `dsm` was created from `origin/main`.
- P0 source filelist and Windows XSim launchers have been localized to the
  retained tree; default outputs are isolated under `runs/dsm/`.
- Documentation has been rewritten for the scalar DSM scope.
- Fresh post-prune XSim passed: single-bit 7/7 and multi-bit 1/1, each with
  65,536 samples and zero reported errors.
- MATLAB/RTL sample-by-sample comparison passed for all seven single-bit
  algorithms and all seven 4-bit multi-bit modes: 65,536 samples per mode,
  zero mismatches.
- The retained CSV evidence is historical (2026-07-05), not a fresh run.

## Next actions

1. If fresh PPA comparison is needed, run the 14-top P0 OOC flow and review
   every routed timing/utilization report; the checked-in data remains
   historical.
2. Keep extensions limited to scalar DSM algorithms, bit-true models,
   reproducible verification, and their PPA comparison.

## Local data handling

Keep generated vectors, reports, checkpoints, and logs under ignored run
directories. Do not clean or commit user-local untracked data.
