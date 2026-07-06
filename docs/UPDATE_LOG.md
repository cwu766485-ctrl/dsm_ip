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

## 2026-07-05 22:00:00 +08:00

Reason:

- Promote the interpolation/filter frontend from MATLAB-only exploration to RTL
  and connect it ahead of `dsm_ip_core` in `dsm_ip_top`.
- Add AXI-Stream backpressure support through a one-entry skid buffer and
  expose frontend/stall counters in the AXI register map.
- Reduce interpolation FIR arithmetic cost with symmetric-coefficient pre-adds
  and zero-coefficient pruning while preserving the existing latency and
  bit-true contract.
- Keep runtime interpolation switching out of the first RTL step so valid/ready,
  latency, fixed-point rounding, and coefficient behavior can be verified
  cleanly.

Changed files:

- `rtl/axis/axis_skid_buffer.sv`
- `rtl/interp/dsm_interp2_halfband.sv`
- `rtl/interp/dsm_interp_fir_fixed.sv`
- `rtl/interp/dsm_interp_frontend.sv`
- `rtl/filelist_p0.f`
- `ip/filelist_dsm_ip.f`
- `ip/package_vivado_ip.tcl`
- `rtl/ip/dsm_ip_top.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `verif/scripts/filelist_p0_abs.ps1`
- `verif/scripts/run_xsim_ip_smoke.ps1`
- `verif/scripts/run_xsim_interp_frontend.ps1`
- `verif/tb/tb_interp_frontend.sv`
- `verif/tb/tb_dsm_ip_top_smoke.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `matlab/models/prepare_interp_frontend_bittrue_vectors.m`
- `matlab/models/compare_interp_frontend_rtl_xsim.m`
- `matlab/models/README.md`
- `rtl/README.md`
- `docs/IP_SPEC.md`
- `docs/IP_HANDOFF.md`
- `docs/STATUS_AND_LIMITS.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; prepare_interp_frontend_bittrue_vectors('n_input',128);"`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1 -SkipMatlabPrep`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_interp_frontend_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed. Modes 0 through 4 reported zero mismatches.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1 -SkipMatlabPrep`: passed after FIR arithmetic optimization.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_interp_frontend_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed after FIR arithmetic optimization. Modes 0 through 4 reported zero mismatches.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1 -SkipSummary`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed. The top smoke includes an `INTERP_MODE=4` `dsm_ip_top` instance and reported `interp_valid=256`; the AXI smoke drives `INTERP_MODE=4` with backpressure and reported `rf_valid=2048`.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`: passed. Existing seven P0 modes reported zero mismatches over 65536 samples.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Current interpolation bit-true snapshot:

| INTERP_MODE | Function | Compared samples | Mismatch |
|---:|---|---:|---:|
| 0 | bypass | 128 | 0 |
| 1 | x4 halfband FIR cascade | 512 | 0 |
| 2 | x8 halfband FIR cascade | 1024 | 0 |
| 3 | x16 halfband FIR cascade | 2048 | 0 |
| 4 | x32 halfband + CIC-equivalent FIR + compensation FIR | 4096 | 0 |

Remaining limitations:

- `INTERP_MODE` is compile-time configurable and is now connected into
  `dsm_ip_top`.
- Runtime interpolation mode switching is not implemented.
- The interpolation frontend is arithmetic-optimized but not yet deeply
  pipelined for maximum clock frequency. A latency-changing pipeline stage
  should be added only with updated MATLAB/RTL alignment checks.

## 2026-07-06 00:00:00 +08:00

Reason:

- Clarify that DSM algorithm selection and interpolation selection are
  compile-time hardware generation parameters rather than runtime mux controls.
- Expose the compiled interpolation mode through the AXI-Lite register map so
  software can identify the selected hardware build.

Changed files:

- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `README.md`
- `ip/README.md`
- `docs/IP_SPEC.md`
- `docs/IP_HANDOFF.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed. AXI smoke checks `INTERP_MODE=4` readback at `0x30`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- Runtime DSM/interpolation mode switching is still intentionally not
  implemented.

## 2026-07-06 14:35:00 +08:00

Reason:

- Convert the interpolation FIR helper arithmetic from a single-cycle
  multiply/accumulate path into a registered compute pipeline.
- Preserve the existing valid/ready interface, compile-time `INTERP_MODE`
  selection, and MATLAB/RTL bit-true output sequence.

Changed files:

- `rtl/interp/dsm_interp2_halfband.sv`
- `rtl/interp/dsm_interp_fir_fixed.sv`
- `rtl/README.md`
- `docs/IP_SPEC.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1 -SkipMatlabPrep`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_interp_frontend_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed. Modes 0 through 4 reported zero mismatches after pipelining.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1 -SkipSummary`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed. The `INTERP_MODE=4` top smoke reported `interp_valid=256`, and the AXI smoke reported `rf_valid=2048`.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`: passed. Existing seven P0 modes reported zero mismatches over 65536 samples.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- Dedicated OOC timing/resource evidence for each pipelined interpolation mode
  has not yet been generated.
- Runtime interpolation mode switching remains intentionally unsupported.

## 2026-07-06 18:45:00 +08:00

Reason:

- Generate a ZU15EG post-synthesis OOC matrix for all compile-time DSM and
  interpolation combinations in the packaged AXI/IP wrapper.
- Clarify the `INTERP_MODE=4` naming as x32 halfband plus CIC-equivalent FIR
  plus compensation FIR.

Changed files:

- `syn/run_ooc_dsm_ip_axi_matrix.ps1`
- `syn/run_ooc_dsm_ip_axi_matrix.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix_synth.ps1`
- `syn/run_ooc_dsm_ip_axi_matrix_synth.tcl`
- `docs/evidence/ooc/dsm_ip_axi_matrix_xczu15eg_ffvb1156_1_i_20260706_post_synth_summary.csv`
- `docs/STATUS_AND_LIMITS.md`
- `.gitignore`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_dsm_ip_axi_matrix_synth.ps1 -Part xczu15eg-ffvb1156-1-i`: completed. All 70 `ALGORITHM=0..13`, `INTERP_MODE=0..4`, `DUC_MODE=0` post-synthesis OOC combinations passed the 100 MHz target.

Checks not completed:

- Full placed/routed OOC matrix was started but stopped because runtime was too
  long for the full 70-combination matrix.

Remaining limitations:

- The retained 70-combination matrix is post-synthesis OOC evidence only.
  It is not routed timing closure or board-level timing closure.
