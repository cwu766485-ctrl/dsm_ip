# Update Log

This file records project changes that affect interfaces, verification status,
timing/resource evidence, repository hygiene, or handoff documentation.

## Template

```text
Date:
Changed files:
Reason:
Checks run:
Checks not run:
Remaining limitations:
```

## 2026-07-03 19:11:35 +08:00

Reason:

- Moved the project from an algorithm cleanup state toward a reusable DSM
  communication digital IP package.
- Closed the original seven DSM paths at the 100 MHz proxy target on
  `xc7z020clg400-1`.
- Strengthened the AXI/IP wrapper with status counters, sticky error handling,
  and software reset behavior.

Changed files:

- `rtl/dsm/singlebit/*`
- `rtl/axi/dsm_ip_axi_top.v`
- `rtl/ip/*`
- `matlab/bittrue/p0_dsm_bittrue.m`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `docs/STATUS_AND_LIMITS.md`
- `docs/IP_SPEC.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1`: passed.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`: passed with zero mismatches for all seven baseline DSM modes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1`: passed for all seven baseline DSM modes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- LPDSM2 uses the P0 timing-closure accumulator width. Restoring a wider
  accumulator requires retiming and MATLAB bit-true synchronization.

## 2026-07-04 19:18:28 +08:00

Reason:

- Defined metric boundaries for native DSM/IP metrics and diagnostic
  RF-recovered metrics.
- Added MATLAB exploration flows for interpolation/filter frontend, multibit
  Cartesian DSM, and future AI-assisted communication calibration work.

Changed files:

- `docs/METRIC_DEFINITIONS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `matlab/cartesian_dsm/dsm_singlebit/*`
- `matlab/cartesian_dsm/dsm_multibit/*`
- `matlab/models/*`
- `matlab/scripts/entry_interp_frontend_*.m`
- `matlab/README.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_interp_frontend_model;"`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_interp_frontend_system_eval;"`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_interp_frontend_calibrate_system;"`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=run_dsm_multibit_smoke; disp(T);"`: passed.

Remaining limitations:

- Interpolation/filter frontend is MATLAB-only.
- RF-recovered metrics remain diagnostic until a concrete DAC/RF/PA and
  receiver recovery chain is specified.

## 2026-07-04 23:36:08 +08:00

Reason:

- Promoted the exploratory multibit Cartesian DSM work from MATLAB-only models
  to RTL with MATLAB/RTL bit-true comparison.
- Added compile-time configurable multibit quantizer resolution.

Changed files:

- `rtl/dsm/multibit/*`
- `rtl/ip/dsm_ip_core.sv`
- `rtl/ip/dsm_ip_top.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_p0_multibit_all.sv`
- `verif/scripts/run_xsim_p0_multibit.ps1`
- `matlab/cartesian_dsm/dsm_multibit/compare_multibit_rtl_xsim.m`
- `docs/IP_SPEC.md`
- `rtl/README.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_multibit.ps1`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_multibit_rtl_xsim; disp(T);"`: passed with zero mismatches for all seven multibit modes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1 -SkipSummary`: passed.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- `MB_Q_BITS`, `DSM_OUT_W`, `ACC_W_MB`, `ALGORITHM`, and `DUC_MODE` are
  compile-time parameters.
- Runtime algorithm and bit-depth switching are not implemented.

## 2026-07-05 15:35:37 +08:00

Reason:

- Ran multibit DSM timing/resource closure on `xc7z020clg400-1`.
- Reduced multibit quantizer and feedback critical paths while preserving
  MATLAB/RTL bit-true behavior.

Changed files:

- `rtl/dsm/multibit/*`
- `rtl/ip/dsm_ip_core.sv`
- `rtl/ip/dsm_ip_top.v`
- `verif/tb/tb_p0_multibit_all.sv`
- `matlab/cartesian_dsm/dsm_multibit/dsm_multibit_model.m`
- `syn/run_ooc_all_dsm.tcl`
- `syn/rtl/p0_ooc_tops.sv`
- `docs/evidence/ooc/p0_ooc_xc7z020_20260705_multibit_summary.csv`
- `docs/STATUS_AND_LIMITS.md`
- `docs/IP_SPEC.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_multibit.ps1 -SkipSummary`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_multibit_rtl_xsim; disp(T);"`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xc7z020clg400-1`: completed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1 -SkipSummary`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- On `xc7z020clg400-1`, multibit EFDSM2 and multibit MASH22 still miss the
  100 MHz target.
- Runtime algorithm/mode switching is still not implemented.

## 2026-07-05 17:48:35 +08:00

Reason:

- Added OOC timing/resource evidence for the ZU15EG target before starting
  runtime algorithm/mode switching.
- Used conservative part `xczu15eg-ffvb1156-1-i` because the exact board speed
  grade was not confirmed.

Changed files:

- `docs/evidence/ooc/p0_ooc_xczu15eg_ffvb1156_1_i_20260705_summary.csv`
- `docs/STATUS_AND_LIMITS.md`
- `docs/IP_SPEC.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_all_dsm.ps1 -Part xczu15eg-ffvb1156-1-i`: completed. All 14 single-bit/native and multibit DSM OOC tops passed the 100 MHz target.

Remaining limitations:

- The ZU15EG result is OOC module evidence only.
- It is not a complete ZU15EG Vivado block design, bitstream, board timing
  closure, or ILA validation result.
