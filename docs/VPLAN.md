# Single-Lane DSM Verification Plan

## Verification goals

1. Confirm reset initializes every tested algorithm to its documented output
   and state.
2. Exercise a fixed, reproducible signed I/Q sample corpus and verify that each
   testbench completes exactly 65,536 accepted samples with no unknown output
   or configured-range error.
3. Compare the captured output streams to the matching MATLAB model sample by
   sample. Record mismatches and the first divergent sample.
4. Run separate algorithm-level metric sweeps only with their model settings,
   input scale, and pass thresholds recorded.
5. Keep synthesis/resource/timing comparison separate from functional claims.

## Existing tests

| Suite | Algorithms | Main checks | Limit |
|---|---|---|---|
| `run_xsim_p0_all.ps1` | LP1, LP2, EF1, EF2, MASH11, MASH111, MASH22 single-bit/P0 variants | Reset, deterministic I/Q playback, known-value checks, sample count and summary | P0 compatibility shell instantiates an I/Q pair of scalar cores |
| `run_xsim_p0_multibit.ps1` | LP1, LP2, EF1, EF2, MASH11, MASH111, MASH22 with the generic multi-bit core | Deterministic I/Q playback, output dump, sample count, summary | A model comparison is needed for bit-true claims |
| MATLAB comparison functions | P0 single-bit and multi-bit outputs | Sample-by-sample model comparison | Model-specific; exploratory metrics are not product signoff |

## Commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_all.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_p0_multibit.ps1
```

Runs are isolated under `runs/dsm/`. The MATLAB entry points are
`matlab/scripts/entry_p0_bittrue_check.m` and the multibit comparison function
`matlab/cartesian_dsm/dsm_multibit/compare_multibit_rtl_xsim.m`.

## Closure limits

Passing these local tests does not establish formal proof, full code coverage,
physical signoff, analog performance, or board operation. The retained OOC
flow is a proxy algorithm comparison at a specified FPGA part and clock.
