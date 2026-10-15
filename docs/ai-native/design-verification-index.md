# Design and Verification Index

## Design entry points

- Single-bit algorithm cores: `rtl/dsm/singlebit/dsm_core*.sv`.
- Multi-bit algorithm core and wrappers: `rtl/dsm/multibit/dsm_core_multibit*.sv`.
- P0 regression adapters: `rtl/top/p0_top_*.v`.
- MATLAB model APIs: `p0_dsm_bittrue`, `dsm_singlebit_model`, and
  `dsm_multibit_model`.

## Verification entry points

- Single-bit P0 suite: `dv/verif/scripts/run_xsim_p0_all.ps1`.
- Multi-bit P0 suite: `dv/verif/scripts/run_xsim_p0_multibit.ps1`.
- MATLAB single-bit compare: `matlab/bittrue/p0_compare_rtl_xsim.m`.
- MATLAB multi-bit compare: `matlab/cartesian_dsm/dsm_multibit/compare_multibit_rtl_xsim.m`.
- FPGA OOC comparison: `syn/run_ooc_all_dsm.ps1`.

## Key boundaries

The regression shell includes an I/Q pair, Fs/4 merge, deterministic ROM
stimulus, and sample-count/known-value checks. It is not AXI verification,
full-system integration, UVM, CDC verification, or analog RF validation.
Historical PPA CSVs are not equivalent to a current re-run.
