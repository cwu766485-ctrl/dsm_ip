# MATLAB

This directory contains the MATLAB reference and analysis code used by the DSM
IP handoff.

## Directory Layout

| Path | Purpose |
|---|---|
| `bittrue/` | Fixed-point DSM reference models and RTL/XSim dump comparison |
| `scripts/` | Entry scripts for vector export, metric evaluation, and plots |
| `cartesian_dsm/` | Retained Cartesian I/Q DSM simulation pipeline and helper functions |
| `board_validation/` | Scope-capture recovery and board-output comparison scripts |
| `out/` | Generated CSV, MAT, PDF, and PNG result files |
| `path_setup.m` | Adds the retained MATLAB source folders to the MATLAB path |

There are no `golden/` or `models/` folders in the cleaned handoff. Fixed-point
reference behavior lives under `bittrue/`; the retained waveform-generation and
metric helpers live under `cartesian_dsm/DSM_2nd/lp/core/`.

## Setup

From MATLAB:

```matlab
cd matlab
path_setup
```

## Bit-True RTL Comparison

Run after XSim has produced `verif/out_xsim_p0/`:

```matlab
T = p0_compare_rtl_xsim();
```

This compares LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22
sample-for-sample against the RTL dumps.

## Vector Export and Metrics

Common entry scripts:

```matlab
entry_p0_export
entry_p0_eval
entry_p0_eval_seven
entry_p0_bittrue_check
entry_plot_qam16_64_256
```

Wrapper scripts in the repository root call these entry points through
`scripts/run_matlab_*.cmd`.

## Board Validation

Board-validation scripts use the retained capture data in:

```text
data/board_validation/cartesian_dsm
```

Main entry points:

```matlab
recover_scope_rf_bits('DSM000')
plot_dsm000_scope_vs_rtl_single
plot_exact_69bit_anchor_overlay
compute_recovered_bits_evm_sndr
```
