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

## 2026-07-09 12:20:00 +08:00

Reason:

- Improve DPD datapath timing quality by splitting the polynomial complex
  multiply/add output path into deeper registered stages.
- Make the PS-side calibration policy explicitly include the fixed-bin spectral
  adjacent proxy.
- Close the RTL optimization loop with DPD bit-true simulation, integrated IP
  smoke, IP packaging, bare-metal ELF rebuild, and ZU15EG board regression.

Changed files:

- `rtl/dpd/dpd_poly.v`
- `rtl/dpd/dpd_frontend.v`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/README.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`
- `ip/ip_repo/dsm_ip_1_0/component.xml` and regenerated packaged IP sources

Implementation notes:

- `dpd_poly` now registers the final complex multiply products before the
  add/subtract, coefficient shift, and saturation stages. This reduces the
  long DSP-to-adder path while preserving the fixed-point arithmetic sequence.
- `dpd_frontend` was latency-aligned to the deeper polynomial path by extending
  the common frontend pipeline from 8 to 9 stages.
- The bare-metal calibration cost now names the hardware-feedback scaling as
  `CAL_EVM_PROXY_SHIFT`, `CAL_ACPR_PROXY_SHIFT`, and `CAL_SPEC_ADJ_SHIFT`.
  This keeps the spectral adjacent-bin contribution explicit and tunable.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1`:
  passed. MATLAB/RTL DPD comparison reported 256 compared samples, 0 mismatch,
  and 0 LSB max error.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`:
  passed. The AXI smoke reported 64 input, 64 DPD, 64 frontend samples and
  2048 RF-valid output samples under the default interpolation configuration.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`:
  passed and regenerated `ip/ip_repo/dsm_ip_1_0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed and rebuilt
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -CleanStaleHwProcesses`:
  passed. The flow rebuilt the ZU15EG bitstream, exported XSA, rebuilt the ELF,
  prechecked JTAG targets, programmed the FPGA, launched the bare-metal app,
  and passed counter readback. Log:
  `fpga/zu15eg/out/zu15eg_baremetal_regression_20260709_120449.log`.

Board evidence:

- JTAG target discovery reported `PS TAP`, `PMU`, `PL`, `PSU`, `APU`, and
  `Cortex-A53 #0`.
- Vivado implementation completed with 0 errors and 0 critical warnings, and
  reported no setup violation.
- Post-run hardware counters passed:
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`
  - `MON_EVM_PROXY=0x0C4F6878`
  - `MON_ACPR_PROXY=0x0801EFFC`
  - `MON_SPEC_BIN0=0x01C6FC72`
  - `MON_SPEC_BIN1=0x0326F9B2`
  - `MON_SPEC_BIN2=0x01C2FC7A`
  - `MON_SPEC_ADJ=0x0389F8EC`

Remaining limitations:

- LUT DPD still contains a lighter-weight combinational gain/mix datapath and
  can be deep-pipelined in a later pass if higher clock targets require it.
- `MON_SPEC_*` registers remain fixed-bin proxy metrics, not formal ACLR or
  spectrum-mask measurements.
- Real RF EVM/SNDR/ACLR still requires a defined DAC/PA/observation receiver
  chain or lab measurement setup.

## 2026-07-09 10:54:16 +08:00

Reason:

- Make the ZU15EG board regression fail early and clearly when JTAG/DAP target
  discovery is broken.
- Add lightweight spectral proxy monitors to the AXI wrapper so the PS-side
  calibration loop has a stronger adjacent-band ranking signal.

Changed files:

- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `fpga/zu15eg/scripts/xsdb_require_targets.tcl`
- `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `fpga/zu15eg/scripts/read_dsm_counters.tcl`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.tcl`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/README.md`
- `docs/IP_HANDOFF.md`
- `docs/IP_SPEC.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`
- `ip/ip_repo/dsm_ip_1_0/component.xml` and regenerated packaged IP sources

Implementation notes:

- Added `xsdb_require_targets.tcl` and wired it into
  `run_zu15eg_baremetal_regression.ps1`. The regression now checks for `PL`,
  `PSU`, and `Cortex-A53 #0` targets before programming or downloading the
  ELF.
- Added `-CleanStaleHwProcesses` to the ZU15EG regression script to terminate
  stale local `hw_server`, `xsdb`, or `xic.bat` helper processes before target
  discovery.
- Extended the DSM AXI-Lite address map from 7-bit to 8-bit addressing and
  added read-only spectral proxy registers:
  - `0x80 MON_SPEC_BIN0`: DC/leakage fixed-bin proxy
  - `0x84 MON_SPEC_BIN1`: Fs/4 carrier fixed-bin proxy
  - `0x88 MON_SPEC_BIN2`: Fs/2 fixed-bin proxy
  - `0x8C MON_SPEC_ADJ`: adjacent/out-of-band proxy, `BIN0 + BIN2`
- The spectral monitor uses multiplier-free fixed-bin accumulators on
  `rf_signed`; it is a low-cost ranking signal, not a formal FFT or ACLR
  signoff engine.
- The ZU15EG bare-metal calibration cost now includes `MON_SPEC_ADJ` in
  addition to MATLAB proxy EVM/SNDR and existing PL saturation, clipping,
  sticky error, stall, correction-magnitude, and RF-slew proxies.
- The board bitstream rebuild Tcl now forces `C_S_AXI_ADDR_WIDTH=8` so the new
  `0x80`-`0x8C` registers are accessible.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`:
  passed. The AXI smoke test reads nonzero `MON_SPEC_BIN0`,
  `MON_SPEC_BIN1`, `MON_SPEC_BIN2`, and `MON_SPEC_ADJ`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`:
  passed. Vivado regenerated `ip/ip_repo/dsm_ip_1_0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  timed out after regenerating the ELF. The generated ELF timestamp updated to
  `2026-07-09 10:50:12 +08:00`.
- `D:\Xilinx\Vitis\2024.1\tps\win64\cmake-3.24.2\bin\cmake.exe --build .\fpga\zu15eg\out\vitis_baremetal\dsm_dpd_baremetal_smoke\build --parallel 4`:
  passed with `ninja: no work to do`, confirming the current C app build tree
  is clean.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild -CleanStaleHwProcesses`:
  passed after the ZU15EG board was powered and the JTAG path was reconnected.
  The run programmed the existing bitstream, launched the fixed bare-metal ELF,
  and passed the post-run counter check. Log:
  `fpga/zu15eg/out/zu15eg_baremetal_regression_20260709_112710.log`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -CleanStaleHwProcesses`:
  passed. This rebuilt the ZU15EG bitstream, exported the XSA, built the
  bare-metal ELF, prechecked JTAG targets, programmed the board, launched the
  ELF, and passed the DSM/DPD counter readback. Log:
  `fpga/zu15eg/out/zu15eg_baremetal_regression_20260709_112803.log`.

Board evidence:

- JTAG target discovery after power-on reported `PS TAP`, `PMU`, `PL`, `PSU`,
  `APU`, and `Cortex-A53 #0`.
- Rebuilt implementation completed with 0 errors and 0 critical warnings.
  Vivado reported non-fatal DSP48 pipeline advisories in the DPD path.
- Post-run hardware counters passed:
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`
  - `MON_SPEC_BIN0=0x00000001`
  - `MON_SPEC_BIN1=0x00000011`
  - `MON_SPEC_BIN2=0x00400000`
  - `MON_SPEC_ADJ=0x00000002`

Remaining limitations:

- `MON_SPEC_*` registers are fixed-bin proxies. They improve on pure slew-based
  `MON_ACPR_PROXY`, but they are still not a formal ACLR measurement.
- Real RF EVM/SNDR/ACLR still requires a defined DAC/PA/observation receiver
  chain or lab measurement setup.
- DPD polynomial and LUT multiply paths still emit Vivado DSP48 pipeline
  advisories. This does not block the current ZU15EG smoke target, but it is
  the next RTL timing-quality cleanup item.

## 2026-07-08 22:40:32 +08:00

Reason:

- Add a fuller observation-receiver model for AI-assisted DPD evaluation.
- Upgrade the ZU15EG bare-metal calibration app from package selection to a
  small PS-side coefficient search loop.
- Ensure final board counters reflect the selected DPD configuration, not an
  intermediate search candidate.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/scripts/entry_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/README.md`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/UPDATE_LOG.md`

Generated or regenerated artifacts:

- `matlab/out/dpd/dpd_memory_pa_observation_sweep.csv`
- `matlab/out/dpd/dpd_memory_pa_observation_sweep.md`
- `matlab/out/dpd/dpd_memory_pa_observation_sweep.mat`
- `matlab/out/dpd/dpd_memory_pa_observation_coordinate_trace.csv`
- `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`
- `fpga/zu15eg/out/xsdb_baremetal_smoke_ps_search.log`
- `fpga/zu15eg/out/xsdb_counter_check_ps_search.log`
- `fpga/zu15eg/out/xsdb_list_targets_after_dap_error.log`

Implementation notes:

- The MATLAB memory-PA observation sweep now models a fuller diagnostic chain:
  memory polynomial PA, soft saturation, linear frequency response,
  gain/phase drift, observation noise, RF band-pass/downconversion/recovery,
  gain/phase/delay alignment, and native/RF-recovered metrics.
- The ZU15EG bare-metal app now evaluates exported polynomial and LUT DPD
  packages, uses the best polynomial package as a seed, perturbs the Q2.14
  `C1/C3/C5` coefficient words, runs DMA/datapath candidates, reads PL monitor
  counters, and accepts lower-cost candidates.
- After applying the final selected DPD configuration, the app re-runs the
  stream and checks counters again. This prevents stale saturation or monitor
  counters from an intermediate search candidate from being reported as the
  final board state.

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_dpd_memory_pa_observation_sweep"`:
  passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  produced an updated ELF. A later run hit a command timeout after the ELF and
  object file were regenerated, so an incremental CMake/Ninja check was run.
- `D:\Xilinx\Vitis\2024.1\tps\win64\cmake-3.24.2\bin\cmake.exe --build .\fpga\zu15eg\out\vitis_baremetal\dsm_dpd_baremetal_smoke\build --parallel 4`:
  passed with `ninja: no work to do`.
- XSDB launch of the first search-loop ELF revision: passed through bitstream
  programming, PS init, ELF download, and `con`.
- `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat .\fpga\zu15eg\scripts\read_dsm_counters.tcl`:
  caught stale `DPD_SATURATION_COUNT=0x000006D9` after the app only applied the
  selected package without re-running the selected stream. This drove the app
  fix above.

Checks not completed:

- The final fixed ELF was not board-confirmed because the later XSDB `dow`
  command failed with `Invalid DAP ACK value: 3`, and a follow-up target scan
  did not enumerate valid JTAG targets. This requires JTAG reconnect or board
  power-cycle before rerunning the board smoke.
- RTL/XSim regressions were not rerun because this step changed MATLAB DPD
  system modeling, bare-metal C, and documentation, not RTL.

Remaining limitations:

- The PS-side search loop uses PL proxy counters and MATLAB-exported proxy
  scores. It is not yet a real RF observation loop with measured EVM/SNDR/ACLR
  feedback from a PA output.
- Memory-polynomial DPD remains a MATLAB/system-model feature; RTL currently
  implements bypass, memoryless polynomial DPD, and LUT DPD.

## 2026-07-08 22:16:33 +08:00

Reason:

- Make the MATLAB PA/observation model more realistic before further
  AI-assisted DPD work.
- Re-evaluate no-DPD, initial polynomial DPD, optimized polynomial DPD, and
  LUT DPD under memory effects, drift, noise, frequency response, and
  saturation.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/scripts/entry_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/UPDATE_LOG.md`

Generated or regenerated artifacts:

- `matlab/out/dpd/dpd_memory_pa_observation_sweep.csv`
- `matlab/out/dpd/dpd_memory_pa_observation_sweep.md`
- `matlab/out/dpd/dpd_memory_pa_observation_sweep.mat`
- `matlab/out/dpd/dpd_memory_pa_observation_coordinate_trace.csv`

Implementation notes:

- The memory-PA diagnostic sweep now includes memory-polynomial PA taps, soft
  saturation, linear frequency response, gain/phase drift, observation noise,
  optimized fixed-point polynomial DPD, and 16-bin LUT DPD.
- The optimized polynomial DPD uses the same Q2.14 coordinate-search idea as
  the memoryless AI-assisted DPD sweep, but evaluates against the more
  realistic PA/observation model.
- The new results are intentionally less ideal than the memoryless PA case.
  For the nominal 16-QAM, 48-subcarrier, 0.58-backoff case, native EVM improves
  from `4.759378%` no DPD to `3.185087%` optimized polynomial DPD, and native
  SNDR improves from `26.448995 dB` to `29.937574 dB`.
- The 64-QAM, 96-subcarrier RF-recovered case remains poor because the assumed
  observation filters are too narrow for that occupied bandwidth. This is a
  system-level observation-chain limitation, not a DSM-core signoff metric.

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_dpd_memory_pa_observation_sweep"`:
  passed. The entry check confirmed optimized polynomial DPD improves native
  EVM versus no DPD, LUT DPD improves native EVM versus no DPD, and optimized
  polynomial DPD does not worsen RF-recovered EVM in the current scenarios.

Checks not run:

- RTL/XSim regressions were not run because this step only changed MATLAB
  system modeling and documentation.
- ZU15EG bitstream and board smoke were not rerun.

Remaining limitations:

- The PA and observation receiver are still behavioral MATLAB models, not
  measured board feedback from a real PA.
- Memory-polynomial DPD is not yet implemented in RTL.

## 2026-07-08 22:06:13 +08:00

Reason:

- Fix VS Code/slang-server editor diagnostics that reported
  `unknown module dsm_core_multibit` when opening a multibit wrapper file
  directly.

Changed files:

- `.slang/server.json`
- `.slang/filelist_p0.slang.f`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Added a workspace slang-server configuration that points to an editor-only
  workspace-relative filelist.
- The filelist includes `rtl/dsm/multibit/dsm_core_multibit.sv` before the
  wrapper files such as `dsm_core_multibit_ef1.sv`.
- This does not change the Vivado/XSim signoff filelists or any RTL behavior.

Checks run:

- No RTL regression was required because only editor configuration was added.

Remaining limitations:

- VS Code may need `Verilog: Restart Slang Server`, `Developer: Reload Window`,
  or closing/reopening the workspace before stale diagnostics disappear.

## 2026-07-08 22:00:20 +08:00

Reason:

- Rebuild the ZU15EG bare-metal DPD calibration application with the optimized
  DPD coefficient header.
- Re-run the board-level PS/JTAG launch and PL counter check to confirm the
  optimized package is usable by the current calibration demo.

Changed files:

- `docs/UPDATE_LOG.md`

Generated or regenerated artifacts:

- `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`
- `fpga/zu15eg/out/xsdb_baremetal_smoke_optimized_dpd.log`
- `fpga/zu15eg/out/xsdb_counter_check_optimized_dpd.log`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed. Vitis rebuilt the standalone A53 application and generated
  `dsm_dpd_baremetal_smoke.elf` using the current `dpd_coeffs.h`.
- `xsdb.bat .\fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.tcl` with
  `BIT_FILE=fpga/zu15eg/out/vitis_baremetal/dsm_zu15eg_platform/hw/sdt/dsm_dpd_zu15eg.bit`,
  `PSU_INIT_TCL=fpga/zu15eg/out/vitis_baremetal/dsm_zu15eg_platform/hw/sdt/psu_init.tcl`,
  and `PROGRAM_BIT=1`: passed. XSDB programmed the FPGA, ran PS init, selected
  Cortex-A53 #0, downloaded the ELF, and launched it.
- `xsdb.bat .\fpga\zu15eg\scripts\read_dsm_counters.tcl`:
  passed. Counter check reported `VERSION=0x00010000`,
  `INPUT_SAMPLE_COUNT=0x00001000`, `FRONTEND_SAMPLE_COUNT=0x00001000`,
  `DPD_SAMPLE_COUNT=0x00001000`, `OUTPUT_SAMPLE_COUNT=0x00001000`,
  `INPUT_STALL_COUNT=0x00000000`, `ERROR_STATUS=0x00000000`,
  `DPD_CTRL=0x00000002`, and `DPD_SATURATION_COUNT=0x00000000`.

Remaining limitations:

- XSDB confirms launch and PL register state; detailed `xil_printf` output
  still requires the PS UART terminal.
- The selected `DPD_CTRL=2` is the current LUT DPD package result from the
  board demo cost function. This is still a proxy-counter calibration demo,
  not measured RF EVM/SNDR feedback from a real PA observation receiver.

## 2026-07-08 21:23:06 +08:00

Reason:

- Upgrade the DPD calibration flow from static package generation to an
  explicit software optimization loop.
- Keep the high-speed PL DPD datapath deterministic while adding a real
  PS/MATLAB-side coefficient-search artifact for the AI-assisted calibration
  roadmap.

Changed files:

- `matlab/dpd/run_ai_assisted_dpd_sweep.m`
- `matlab/dpd/README.md`
- `matlab/out/dpd/ai_assisted_dpd_sweep.csv`
- `matlab/out/dpd/ai_assisted_dpd_sweep.md`
- `matlab/out/dpd/ai_assisted_dpd_sweep.mat`
- `matlab/out/dpd/ai_assisted_dpd_coordinate_trace.csv`
- `fpga/zu15eg/baremetal/src/dpd_coeffs.h`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `run_ai_assisted_dpd_sweep.m` now starts polynomial DPD from the
  indirect-learning least-squares solution and refines the quantized Q2.14
  `C1/C3/C5` words with coordinate search.
- The optimization loss combines EVM, SNDR, and ACLR target penalty.
- The fixed-point polynomial and LUT DPD MATLAB models were vectorized to keep
  the calibration sweep suitable for routine regression.
- The exported bare-metal header now contains optimized polynomial DPD
  coefficient packages.
- The current AI boundary remains software/optimization assisted calibration;
  no neural-network PA model, RF observation receiver, or hardware ML
  accelerator is claimed in this step.

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; [T,D]=run_ai_assisted_dpd_sweep; disp(T(:,{'Scenario','InitialPoly_EVM_percent','FixedDPD_EVM_percent','InitialPoly_SNDR_dB','FixedDPD_SNDR_dB','OptimizedPoly_Loss'})); export_dpd_coeff_header;"`:
  passed. All six scenarios showed optimized polynomial DPD EVM/SNDR better
  than the initial quantized polynomial coefficients. The nominal 16-QAM,
  48-subcarrier, 0.58-backoff case improved from `3.040391%` no-DPD EVM to
  `0.081853%` optimized-polynomial DPD EVM, with SNDR improving from
  `30.341411 dB` to `61.739314 dB`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1 -SkipMatlabPrep`:
  passed. MATLAB compare reported 256 compared samples, 0 mismatches, and
  0 LSB maximum error.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`:
  passed. LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22 all
  reported 65536 samples with 0 mismatches.

Checks not run:

- ZU15EG bitstream and board smoke were not rerun after regenerating the DPD
  coefficient header.

Remaining limitations:

- The optimization loop uses a behavioral PA model and MATLAB-computed metrics,
  not measured RF feedback from a real PA or receiver.
- The PL monitor still exposes lightweight proxy counters rather than formal
  hardware EVM/SNDR/ACLR computation.
- Neural-network PA modeling and tiny hardware ML acceleration remain future
  extensions.

## 2026-07-08 19:05:39 +08:00

Reason:

- Pipeline the DPD multiplier/add path to reduce long DSP combinational paths.
- Preserve the DPD fixed-point output sequence while improving RTL timing
  structure.
- Strengthen the DPD regression so the XSim dump is compared against the
  MATLAB fixed-point reference automatically.

Changed files:

- `rtl/dpd/dpd_poly.v`
- `rtl/dpd/dpd_frontend.v`
- `verif/scripts/run_xsim_dpd_bittrue.ps1`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `docs/IP_HANDOFF.md`
- `docs/IP_SPEC.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `dpd_poly` now uses a registered pipeline across input capture, square,
  radius, coefficient multiply, gain accumulation, complex multiply, and
  saturation/output stages.
- `dpd_frontend` now latency-aligns bypass and LUT DPD paths to the polynomial
  path and uses the final pipeline valid/data stage directly at the output.
- The AXI smoke `axis_send` task was fixed so a backpressured transfer is not
  accidentally held for an extra valid cycle after the first accepted beat.
- The DPD bit-true regression now calls the MATLAB comparison after XSim and
  fails if any output sample mismatches.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1 -SkipMatlabPrep`:
  passed. MATLAB compare reported 256 compared samples, 0 mismatches, and
  0 LSB maximum error.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`:
  passed. AXI smoke reported 64 input samples, 64 DPD samples, 64 frontend
  samples, and 2048 `rf_valid` samples.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`:
  passed. Vivado reported non-fatal IP packager warnings already seen in this
  project.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_dsm_ip_axi_matrix_synth.ps1 -Part xczu15eg-ffvb1156-1-i`:
  started but timed out after 15 minutes. A partial summary was generated for
  the first nine ZU15EG post-synthesis `dsm_ip_axi_top` combinations; all nine
  rows were `PASS` with estimated Fmax about 129.9 MHz. The run was stopped and
  is not counted as a complete synthesis matrix pass.

Remaining limitations:

- The full ZU15EG synthesis matrix and routed timing closure were not completed
  after this DPD pipeline change.
- The board bitstream was not rebuilt after this RTL change in this step.
- Memory-polynomial DPD remains a planned extension; current RTL implements
  bypass, memoryless polynomial DPD, and LUT DPD.

## 2026-07-08 01:37:45 +08:00

Reason:

- Rebuild and download the ZU15EG DSM/DPD board bitstream after the LUT
  double-buffer RTL update.
- Attempt the JTAG/XSDB DPD DMA board smoke on the new bitstream.
- Add a small PS reset/init probe because the board entered a DAP transaction
  error state during PS initialization.

Changed files:

- `.gitignore`
- `fpga/zu15eg/scripts/run_xsdb_dpd_dma_smoke.ps1`
- `fpga/zu15eg/scripts/xsdb_ps_reset_init_probe.tcl`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1`: passed; `impl_1` reached `write_bitstream Complete!`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\program_bitstream_vivado.ps1`: passed.
- Vivado hardware probe: passed; detected `xczu15_0` and `arm_dap_1`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode poly -SkipProgram`: failed in `psu_ps_pl_isolation_removal`; `psu_init.tcl` timed out polling PL power-up status.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode poly -SkipProgram -SkipPsuInit`: failed; AXI read at `0xA0010014` timed out because PS-to-PL AXI was not initialized.
- `xsdb_ps_reset_init_probe.tcl`: failed to recover the board in software; XSDB reported DAP AXI AP transaction error.

Implementation notes:

- `run_xsdb_dpd_dma_smoke.ps1` now supports `-SkipPsuInit` for cases where PS
  clocks and PS-PL isolation are already configured.
- `fpga/zu15eg/out/` is ignored because it contains board probe logs.

Remaining limitations:

- The rebuilt bitstream is valid, but the on-board smoke is blocked until the
  ZU15EG PS/DAP state is recovered, most likely by a physical PS reset or power
  cycle.
- The Vitis standalone bare-metal app was not compiled or run because only
  Vivado/XSDB tools are installed in this environment; no command-line Vitis
  application build tool is available under `D:\Xilinx`.

## 2026-07-08 11:46:10 +08:00

Reason:

- Confirm that the ZU15EG board is in PS JTAG boot mode after setting `SW1`
  to `MODE[3:0]=0000`.
- Re-run the rebuilt DSM/DPD bitstream on board and close the previous
  DAP/PS initialization blocker.

Changed files:

- `docs/UPDATE_LOG.md`

Checks run:

- XSDB target probe after power cycle: passed; detected `PS TAP`, `PMU`,
  `PL`, `PSU`, `RPU`, `APU`, and four `Cortex-A53` targets.
- Vivado hardware probe: passed; detected `xczu15_0` and `arm_dap_1`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\program_bitstream_vivado.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode poly -SkipProgram`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode lut -SkipProgram`: passed.

Board smoke evidence:

- DSM version readback: `0x00010000`.
- Interpolation mode readback: `0x00000000`.
- Polynomial DPD coefficient readback passed for `C1/C3/C5`.
- LUT DPD readback passed for LUT entry 0 and 15.
- LUT DPD active bank commit toggled successfully: `DPD_LUT_ACTIVE_BANK = 0x00000001`.
- DMA MM2S completed for 4096 packed I/Q words.
- `INPUT_SAMPLE_COUNT`, `FRONTEND_SAMPLE_COUNT`, `DPD_SAMPLE_COUNT`, and
  `OUTPUT_SAMPLE_COUNT` all read back `0x00001000`.
- `INPUT_STALL_COUNT = 0x00000000`, `ERROR_STATUS = 0x00000000`, and
  `DPD_SATURATION_COUNT = 0x00000000`.

Remaining limitations:

- The board smoke proves PS/JTAG/AXI-Lite/DMA/PL datapath operation, not
  external RF output or real PA feedback.
- Full Vitis Embedded is still not installed on this PC; only Vitis HLS and
  Vivado XSDB are available.

## 2026-07-08 01:02:48 +08:00

Reason:

- Complete the first end-to-end AI-assisted DPD prototype path around the
  available bare-metal/JTAG board workflow.
- Upgrade LUT DPD from a single mutable table to a shadow-bank plus commit
  model.
- Export complete multi-scenario DPD coefficient packages for Vitis
  standalone experiments.
- Add a result document that separates memoryless PA metrics, memory-PA
  observation metrics, RTL evidence, and remaining limits.

Changed files:

- `rtl/dpd/dpd_lut.v`
- `rtl/dpd/dpd_frontend.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_dpd_frontend.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_coeffs.h`
- `fpga/zu15eg/scripts/xsdb_dpd_dma_smoke.tcl`
- `fpga/zu15eg/ps_linux/dsm_dpd_ps_control.py`
- `matlab/dpd/run_ai_assisted_dpd_sweep.m`
- `matlab/dpd/export_dpd_coeff_header.m`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/IP_SPEC.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_export_dpd_coeff_header"`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed, 256 samples, 0 mismatches.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- `gcc -std=gnu11 -fsyntax-only` with temporary Xilinx BSP stub headers for
  `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`: passed.

Implementation notes:

- `DPD_LUT_COMMIT` was added at offset `0x60`. AXI writes update the inactive
  LUT bank; writing bit0 `1` switches the shadow bank active.
- `dpd_coeffs.h` now contains all exported calibration packages and full
  16-entry LUT tables.
- The bare-metal app now iterates polynomial and LUT DPD packages and reports
  the lowest observed saturation count.

Checks not run:

- The Vitis standalone app was not compiled or run on the board because a
  generated command-line Vitis application workspace was not available in this
  session.
- ZU15EG bitstream was not rebuilt after the LUT double-buffer RTL change.

Remaining limitations:

- Memory-polynomial DPD is still MATLAB/system-model only, not RTL.
- The board still lacks a Linux/PYNQ boot path in this setup.
- No real PA feedback path or RF measurement loop is available.

## 2026-07-07 14:20:00 +08:00

Reason:

- Start the bare-metal path for AI-assisted DPD board control because PS
  Linux/PYNQ boot was not available on the local ZU15EG setup.
- Translate the validated XSDB DPD/DMA smoke flow into a Vitis standalone C
  application skeleton.
- Add a MATLAB-to-C coefficient package export path for polynomial and LUT DPD
  experiments.

Changed files:

- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_coeffs.h`
- `matlab/dpd/export_dpd_coeff_header.m`
- `matlab/scripts/entry_export_dpd_coeff_header.m`
- `matlab/README.md`
- `matlab/dpd/README.md`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_export_dpd_coeff_header"`: passed.
- `gcc -std=gnu11 -fsyntax-only` with temporary Xilinx BSP stub headers for
  `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`: passed.

Checks not run:

- Vitis standalone compilation was not run in this shell because the Xilinx
  standalone BSP headers and generated application workspace were not
  available as a command-line build environment.

Implementation notes:

- The bare-metal app uses `Xil_In32`, `Xil_Out32`, and `XAxiDma` to configure
  DPD polynomial mode, configure LUT mode, send a generated 4096-word packed
  I/Q vector, and check DSM/DPD counters.
- The MATLAB export currently writes polynomial words plus a minimal 16-entry
  LUT package with calibrated edge entries and unity middle entries. A later
  pass should export the full trained LUT table.

Remaining limitations:

- The app is ready for Vitis integration but has not been compiled or run on
  the board yet.
- The calibration loop still runs in MATLAB on the development PC.
- No memory-polynomial DPD RTL has been added yet.

## 2026-07-07 13:35:00 +08:00

Reason:

- Add the first memory-PA and RF-observation diagnostic model for DPD system
  evaluation.
- Prepare a PS Linux SSH wrapper for running the DPD AXI-Lite control helper
  directly on the ZU15EG PS once the board IP and login are available.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/scripts/entry_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/README.md`
- `fpga/zu15eg/ps_linux/run_ps_dpd_control_over_ssh.ps1`
- `fpga/zu15eg/ps_linux/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_dpd_memory_pa_observation_sweep"`: passed.

Result summary:

- The new sweep writes:
  - `matlab/out/dpd/dpd_memory_pa_observation_sweep.csv`
  - `matlab/out/dpd/dpd_memory_pa_observation_sweep.md`
  - `matlab/out/dpd/dpd_memory_pa_observation_sweep.mat`
- The model includes:
  - memory polynomial PA taps,
  - Fs/4 real RF upconversion,
  - ideal RF band-pass reconstruction,
  - downconversion,
  - ideal baseband low-pass reconstruction,
  - gain/delay alignment,
  - native and RF-recovered EVM/SNDR/ACLR reporting.

Remaining limitations:

- The PS Linux helper was not executed on the board because no reachable board
  IP address or usable serial console was available from the development PC.
- The RF observation filters are ideal diagnostic assumptions, not measured
  board or PA responses.
- The current DPD hardware is memoryless; memory-PA compensation is still a
  system-model and future-RTL item.

## 2026-07-07 13:10:00 +08:00

Reason:

- Move the AI-assisted DPD architecture one step closer to the target MPSoC
  flow: PS software computes or selects calibration parameters, then updates
  the PL DPD block through AXI-Lite.

Changed files:

- `fpga/zu15eg/ps_linux/dsm_dpd_ps_control.py`
- `fpga/zu15eg/ps_linux/README.md`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `python -m py_compile .\fpga\zu15eg\ps_linux\dsm_dpd_ps_control.py`: passed.
- `python .\fpga\zu15eg\ps_linux\dsm_dpd_ps_control.py --dsm-base 0xA0010000 --dry-run poly --c1 0xFFFB4009 --c3 0xF1A41F6F --c5 0xDE503A39`: passed.
- `python .\fpga\zu15eg\ps_linux\dsm_dpd_ps_control.py --dsm-base 0xA0010000 --dry-run lut --lut-default 0x00004000 --lut-entry 0=0xFFF3401D --lut-entry 15=0xFAED4A4C`: passed.

Implementation notes:

- The new PS Linux helper supports `status`, `bypass`, `poly`, and `lut`
  commands.
- The helper writes DPD parameters through the same AXI-Lite register map that
  was already verified by the ZU15EG XSDB board smoke.
- This is a bring-up helper based on `/dev/mem`; production software should
  use UIO, a kernel driver, or a Vitis bare-metal application.

Remaining limitations:

- The full calibration loop still runs in MATLAB on the development PC.
- The PS helper configures DPD registers but does not yet start AXI DMA or
  compute DPD parameters on PS.
- No real PA feedback or RF observation loop is included yet.

## 2026-07-07 12:54:43 +08:00

Reason:

- Rebuild the ZU15EG board bitstream after adding the DPD frontend LUT mode.
- Confirm both polynomial DPD and LUT DPD paths through the PS/JTAG,
  AXI-Lite, AXI DMA, DPD, interpolation frontend, and DSM datapath.

Changed files:

- `fpga/zu15eg/scripts/run_xsdb_dpd_dma_smoke.ps1`
- `fpga/zu15eg/scripts/xsdb_dpd_dma_smoke.tcl`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1`: passed; Vivado reported `write_bitstream Complete` with 0 errors.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\program_bitstream_vivado.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode poly -SkipProgram`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -DpdMode lut -SkipProgram`: passed.

Board evidence:

- Polynomial DPD mode:
  - `DPD_C1=0xFFFB4009`
  - `DPD_C3=0xF1A41F6F`
  - `DPD_C5=0xDE503A39`
  - `DPD_CTRL=0x00000001`
- LUT DPD mode:
  - `DPD_LUT0=0x00004000`
  - `DPD_LUT15=0x00004000`
  - `DPD_CTRL=0x00000002`
- Both modes completed a 4096-word AXI DMA MM2S transfer:
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_SATURATION_COUNT=0x00000000`

Remaining limitations:

- Current calibration is still generated from PC/MATLAB/XSDB. A PS-side
  Linux or bare-metal coefficient writer is the next step.
- The board smoke proves the internal digital PS-DDR-to-PL datapath. It does
  not prove an external PA, DAC, or RF observation loop.
- Vivado still reports DPD DSP pipelining warnings. These are power/timing
  optimization items for a later DPD pipeline pass.

## 2026-07-07 12:27:05 +08:00

Reason:

- Upgraded the DPD block from a single polynomial kernel to a mode-selectable
  DPD frontend suitable for AI-assisted calibration experiments.
- Added RTL LUT DPD support as a hardware-friendly target for software,
  optimization, or future AI-generated calibration tables.
- Extended the MATLAB software calibration sweep so it evaluates both
  fixed-point polynomial DPD and fixed-point LUT DPD across multiple PA/input
  power/OFDM-QAM scenarios.
- Changed the DPD bit-true regression to test the integrated `dpd_frontend`
  polynomial mode, not only the standalone `dpd_poly` kernel.

Changed files:

- `rtl/dpd/dpd_lut.v`
- `rtl/dpd/dpd_frontend.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `rtl/filelist_p0.f`
- `verif/tb/tb_dpd_frontend.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `verif/scripts/run_xsim_dpd_bittrue.ps1`
- `verif/scripts/run_xsim_ip_smoke.ps1`
- `verif/scripts/filelist_p0_abs.ps1`
- `ip/package_vivado_ip.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix_synth.tcl`
- `syn/run_ooc_dsm_ip_axi_routed_subset.tcl`
- `matlab/dpd/run_ai_assisted_dpd_sweep.m`
- `matlab/dpd/README.md`
- `matlab/scripts/entry_ai_assisted_dpd_sweep.m`
- `docs/IP_SPEC.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed. AXI smoke covers DPD mode readback, LUT address/data readback, and LUT-mode streaming counters.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed with 256 compared samples, 0 mismatches, and 0 LSB max error.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_ai_assisted_dpd_sweep"`: passed. Six scenarios completed; both fixed-point polynomial DPD and fixed-point LUT DPD improved EVM and SNDR against the no-DPD PA baseline.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1`: passed. Seven P0 simulations completed with `Failed=0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Checks not run:

- ZU15EG bitstream rebuild and board smoke were not rerun after adding LUT DPD.
  The previous board smoke remains valid for polynomial DPD mode, but LUT mode
  still needs board-level confirmation.

Remaining limitations:

- LUT DPD updates are single-buffered. Software should update the LUT while the
  stream is idle or after software reset.
- Memory polynomial DPD mode is reserved but not implemented.
- The current AI-assisted loop uses deterministic fitting. A neural or Bayesian
  calibration engine can be added later using the same coefficient/LUT write
  interface.
- The DPD datapath still has unpipelined DSP multiplier paths that should be
  optimized before pushing high-frequency timing.

## 2026-07-07 05:01:02 +08:00

Reason:

- Completed the first ZU15EG DPD board smoke and the first software-side
  AI-assisted DPD calibration sweep.
- Added a multi-scenario MATLAB sweep that trains deterministic polynomial DPD
  coefficients, quantizes them to RTL Q2.14 format, and exports AXI-Lite
  coefficient words.
- Added ZU15EG helper scripts for address reporting, local bitstream rebuild,
  Vivado bitstream programming, XSDB target listing, and Vivado hardware target
  listing.
- Fixed `dsm_ip_axi_top` so the AXI-Lite word address is derived from
  `C_S_AXI_ADDR_WIDTH` instead of hard-coding `s_axi_awaddr[6:2]`.
- Updated the local ZU15EG rebuild flow to force `C_S_AXI_ADDR_WIDTH=7` on
  `dsm_ip_0`, which is required for the DPD registers at `0x40` and above.

Changed files:

- `rtl/axi/dsm_ip_axi_top.v`
- `matlab/dpd/run_ai_assisted_dpd_sweep.m`
- `matlab/dpd/README.md`
- `matlab/scripts/entry_ai_assisted_dpd_sweep.m`
- `matlab/README.md`
- `fpga/zu15eg/scripts/report_bd_addresses.tcl`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.tcl`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.ps1`
- `fpga/zu15eg/scripts/program_bitstream_vivado.tcl`
- `fpga/zu15eg/scripts/program_bitstream_vivado.ps1`
- `fpga/zu15eg/scripts/xsdb_list_targets.tcl`
- `fpga/zu15eg/scripts/vivado_list_hw_targets.tcl`
- `fpga/zu15eg/scripts/run_xsdb_dpd_dma_smoke.ps1`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_ai_assisted_dpd_sweep"`: passed. Six calibration scenarios completed; fixed-point DPD improved EVM and SNDR in all six scenarios.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\rebuild_dsm_board_bitstream.ps1`: passed. Local ZU15EG `impl_1` reached `write_bitstream Complete!`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\program_bitstream_vivado.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0010000 -DmaBase 0xA0020000 -SkipProgram`: passed.

Board smoke result:

```text
DPD_C1_READBACK        = 0xFFFB4009
DPD_C3_READBACK        = 0xF1A41F6F
DPD_C5_READBACK        = 0xDE503A39
DPD_CTRL_READBACK      = 0x00000001
DMA_MM2S_DONE          = 0x00001002
INPUT_SAMPLE_COUNT     = 0x00001000
FRONTEND_SAMPLE_COUNT  = 0x00001000
DPD_SAMPLE_COUNT       = 0x00001000
OUTPUT_SAMPLE_COUNT    = 0x00001000
INPUT_STALL_COUNT      = 0x00000000
ERROR_STATUS           = 0x00000000
DPD_SATURATION_COUNT   = 0x00000000
```

Debug notes:

- The first DPD board smoke failed because the loaded/local bitstream did not
  expose the DPD registers; `DPD_C1` read back as zero after write.
- The first local rebuild attempt failed because the BD instance still used a
  6-bit AXI-Lite address port while the RTL referenced DPD registers at
  offsets `0x40` and above.
- Vivado Hardware Manager reliably found `xczu15_0` and programmed the PL,
  while XSDB PL target filtering was not reliable in this session. The retained
  board flow therefore uses Vivado for programming and XSDB for PS init,
  AXI-Lite, and DMA.

Remaining limitations:

- The DPD board smoke validates the digital control/data path only. It does
  not validate a real PA, RF output, observation receiver, or lab EVM/ACLR.
- The DPD RTL currently uses unpipelined DSP multiplier paths. Vivado reports
  DPOP/DPREG warnings; deeper DPD pipelining is a future timing/power
  optimization.
- The AI-assisted DPD loop currently uses deterministic polynomial fitting,
  not a trained neural model.

## 2026-07-07 04:08:00 +08:00

Reason:

- Added a repeatable ZU15EG JTAG/XSDB board smoke flow for the DPD control
  path.
- The new smoke writes DPD coefficients through AXI-Lite, enables DPD, starts
  one AXI DMA MM2S transfer, and checks DSM input, frontend, DPD, output,
  stall, and error counters.
- Updated the ZU15EG bring-up notes with the exact run sequence and clarified
  that DSM/DMA base addresses must come from the local Vivado Address Editor.
- Updated the project prospective document to reflect that standalone
  MATLAB/RTL DPD bit-true comparison has been completed.

Changed files:

- `fpga/zu15eg/scripts/xsdb_dpd_dma_smoke.tcl`
- `fpga/zu15eg/scripts/run_xsdb_dpd_dma_smoke.ps1`
- `fpga/zu15eg/README.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_xsdb_dpd_dma_smoke.ps1 -DsmBase 0xA0000000 -DmaBase 0xA0010000 -PrintOnly`: passed.

Checks not run:

- The XSDB board smoke was not launched in this update because the local
  DPD-enabled bitstream and final DSM/DMA AXI base addresses must be confirmed
  from the current Vivado block design before touching the attached board.

Remaining limitations:

- This smoke validates the DPD control plane and deterministic PS-to-PL DMA
  datapath. It does not validate real RF, DAC, PA, or observation-receiver
  performance.

## 2026-07-07 03:32:30 +08:00

Reason:

- Added a dedicated DPD RTL/MATLAB bit-true regression.
- Fixed `dpd_poly` arithmetic issues found by bit-true comparison:
  insufficient `|x|^4` power-path width and unsigned interpretation of
  sign-extended coefficient concatenations.
- Added deterministic MATLAB DPD vectors with Q1.15 inputs and Q2.14
  1st/3rd/5th-order complex coefficients.
- Added an XSim DPD testbench and runner that dumps RTL output for MATLAB
  sample-by-sample comparison.

Changed files:

- `rtl/dpd/dpd_poly.v`
- `verif/tb/tb_dpd_poly.sv`
- `verif/scripts/run_xsim_dpd_bittrue.ps1`
- `matlab/dpd/prepare_dpd_bittrue_vectors.m`
- `matlab/dpd/compare_dpd_rtl_xsim.m`
- `matlab/dpd/README.md`
- `matlab/scripts/entry_dpd_bittrue_check.m`
- `matlab/README.md`
- `docs/VERIFICATION_PLAN.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_dpd_bittrue.ps1`: passed.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_dpd_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed with 256 compared samples, 0 mismatches, and 0 LSB max error.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1`: passed. Seven P0 simulations completed with `Failed=0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Remaining limitations:

- The DPD bit-true regression covers the standalone memoryless polynomial DPD
  frontend. It does not yet validate a full DPD-plus-interpolation-plus-DSM
  end-to-end bit-true chain.
- The DPD model remains memoryless and does not include PA memory effects or a
  real observation receiver.

## 2026-07-07 03:16:59 +08:00

Reason:

- Extended the AI-assisted TX path from a floating MATLAB DPD baseline to a
  fixed-point DPD model and the first configurable RTL polynomial DPD frontend.
- Inserted the DPD frontend in the AXI wrapper before the existing DSM TX
  datapath.
- Added AXI-Lite coefficient registers for 1st/3rd/5th-order complex
  polynomial DPD while keeping the default hardware state in bypass mode.
- Checked the Windows host for an attached SD-card filesystem before claiming
  PS Linux boot readiness.

Changed files:

- `matlab/dpd/run_dpd_fixed_baseline.m`
- `matlab/dpd/README.md`
- `matlab/scripts/entry_dpd_fixed_baseline.m`
- `matlab/README.md`
- `rtl/dpd/dpd_poly.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `rtl/filelist_p0.f`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `verif/scripts/run_xsim_ip_smoke.ps1`
- `verif/scripts/filelist_p0_abs.ps1`
- `ip/package_vivado_ip.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix_synth.tcl`
- `syn/run_ooc_dsm_ip_axi_routed_subset.tcl`
- `docs/IP_SPEC.md`
- `docs/IP_HANDOFF.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `Get-Volume`: completed. The Windows host currently shows only fixed
  `C:`, `D:`, and `E:` volumes; no removable SD-card partition was visible from
  this session.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=run_dpd_fixed_baseline('nsym',16); assert(height(T)==3); assert(T.EVM_percent(3) < T.EVM_percent(1)); assert(T.SNDR_dB(3) > T.SNDR_dB(1));"`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed. The AXI smoke now checks DPD coefficient readback and `DPD_SAMPLE_COUNT`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1`: passed. Seven P0 simulations completed with `Failed=0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.

Current fixed-point DPD smoke snapshot:

| Case | EVM % | SNDR dB | ACLR_avg dBc |
|---|---:|---:|---:|
| PA_only | 3.3016 | 29.626 | -25.808 |
| Float_DPD_plus_PA | 0.10351 | 59.700 | -26.132 |
| Fixed_DPD_plus_PA | 0.10393 | 59.665 | -26.132 |

Remaining limitations:

- DPD RTL is smoke-tested through the AXI wrapper, but a dedicated
  MATLAB-versus-RTL DPD vector comparison has not yet been added.
- The DPD block is currently a memoryless polynomial frontend. It does not
  model PA memory effects or a real observation receiver.
- PS Linux boot was not verified. SD-card contents and serial boot logs still
  need to be checked on the actual board setup.

## 2026-07-07 02:53:19 +08:00

Reason:

- Started the AI-assisted communication IP path with a MATLAB-only conventional
  DPD baseline.
- Added a memoryless PA model and indirect-learning 1st/3rd/5th-order
  polynomial DPD flow.
- Kept this stage out of the high-speed RTL datapath. The purpose is to define
  the calibration problem and produce a software reference before DPD RTL.

Changed files:

- `matlab/dpd/run_dpd_memoryless_baseline.m`
- `matlab/dpd/README.md`
- `matlab/scripts/entry_dpd_memoryless_baseline.m`
- `matlab/path_setup.m`
- `matlab/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=run_dpd_memoryless_baseline; assert(height(T)==2); assert(T.EVM_percent(2) < T.EVM_percent(1)); assert(T.SNDR_dB(2) > T.SNDR_dB(1));"`: passed.

Current MATLAB DPD baseline snapshot:

| Case | EVM % | SNDR dB | ACLR_avg dBc |
|---|---:|---:|---:|
| PA_only | 2.842445 | 30.926157 | -25.053849 |
| DPD_plus_PA | 0.070713 | 63.010074 | -25.212982 |

Generated outputs:

- `matlab/out/dpd/dpd_memoryless_baseline.csv`
- `matlab/out/dpd/dpd_memoryless_baseline.md`
- `matlab/out/dpd/dpd_memoryless_baseline.mat`

Remaining limitations:

- This is a MATLAB behavioral baseline only; no DPD RTL or AXI coefficient
  registers were added.
- The PA model is memoryless and synthetic. It is not calibrated to a real PA.
- ACLR improvement is small in this first baseline. Stronger ACLR work should
  add memory effects, a richer PA model, and a real or emulated observation
  path.

## 2026-07-07 00:33:39 +08:00

Reason:

- Updated the project prospective after the ZU15EG board smoke test.
- Defined the next technical route as deterministic TX datapath hardening
  followed by configurable DPD and AI-assisted calibration.
- Clarified that AI should initially assist coefficient generation and
  calibration, not replace the high-speed RTL datapath.

Changed files:

- `docs/PROJECT_PROSPECTIVE.md`
- `docs/UPDATE_LOG.md`

Checks run:

- Documentation-only update; no RTL, MATLAB, IP packaging, or synthesis checks
  were required.

Remaining limitations:

- AI-assisted DPD/calibration is a planned extension. No DPD RTL, AI model, or
  PA-model verification has been implemented in this update.

## 2026-07-06 21:31:24 +08:00

Reason:

- Prepared the project for first ZU15EG board bring-up.
- Added a PS-DMA-DSM-ILA validation plan and source-only helper scripts.
- Added a DMA input-vector packer that reuses the existing P0 bit-true I/Q
  vectors.
- Updated handoff and verification documentation for the current ZU15EG board
  validation target.

Changed files:

- `fpga/zu15eg/README.md`
- `fpga/zu15eg/scripts/create_dsm_dma_ila_bd.tcl`
- `fpga/zu15eg/scripts/pack_p0_iq_for_dma.py`
- `fpga/README.md`
- `docs/IP_HANDOFF.md`
- `docs/PROJECT_MAP.md`
- `docs/VERIFICATION_PLAN.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `python fpga\zu15eg\scripts\pack_p0_iq_for_dma.py --limit 1024`: passed and generated an ignored local DMA binary.

Checks not run:

- The ZU15EG Vivado block-design script was not run because the board-specific
  PS DDR/MIO preset must be created or imported first.
- Complete ZU15EG bitstream generation was not run.

Remaining limitations:

- `fpga/zu15eg/scripts/create_dsm_dma_ila_bd.tcl` is a bring-up template, not a
  finished board project.
- Board-specific hardware collateral remains local-only and excluded from the
  public repository.

## 2026-07-06 19:59:19 +08:00

Reason:

- Strengthened the RTL toward ZU15EG-focused IP handoff.
- Added AXI-Stream `tlast` and `tuser` handling to the AXI wrapper without
  changing DSM numerical behavior.
- Added interpolation first-output latency checks to the standalone frontend
  regression.
- Added a routed OOC subset flow and retained ZU15EG routed timing/resource
  evidence for representative compile-time configurations.

Changed files:

- `rtl/axis/axis_skid_buffer.sv`
- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_interp_frontend.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `syn/run_ooc_dsm_ip_axi_routed_subset.ps1`
- `syn/run_ooc_dsm_ip_axi_routed_subset.tcl`
- `docs/evidence/ooc/dsm_ip_axi_routed_subset_xczu15eg_ffvb1156_1_i_20260706_summary.csv`
- `.gitignore`
- `rtl/README.md`
- `ip/README.md`
- `docs/IP_SPEC.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_interp_frontend.ps1 -SkipMatlabPrep`: passed; first-output latency checks passed for `INTERP_MODE=0..4`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_all.ps1`: passed, 7 rows, 0 failures.
- `.\scripts\run_matlab_p0_bittrue_check.cmd`: passed with zero mismatches for all seven baseline DSM modes.
- `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; T=compare_interp_frontend_rtl_xsim; disp(T); assert(all(T.mismatch==0));"`: passed for all five interpolation modes.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\syn\run_ooc_dsm_ip_axi_routed_subset.ps1 -Part xczu15eg-ffvb1156-1-i`: passed for 3 routed OOC representative combinations.

Checks not run:

- Full 70-combination routed OOC matrix was not run because it is too slow for
  routine iteration.
- Complete ZU15EG board bitstream timing closure was not run.

Remaining limitations:

- The routed subset is IP-level OOC evidence and does not prove complete board
  timing closure.
- `tlast` and `tuser` are currently tracked as input metadata/status; the DSM
  output is still a sample stream rather than an AXI-Stream output interface.

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

## 2026-07-06 23:50:00 +08:00

Reason:

- Bring up the packaged DSM IP on the local XCZU15EG board using the vendor
  PS/GPIO project as the PS DDR/MIO base.
- Fix the ZU15EG block-design template based on real hardware feedback.

Changed files:

- `.gitignore`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/scripts/create_dsm_dma_ila_bd.tcl`
- `ip/package_vivado_ip.tcl`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`: passed.
- JTAG hardware check: detected `xczu15_0` and `arm_dap_1`.
- Vendor GPIO bitstream program: passed.
- Local ZU15EG DSM+AXI DMA+ILA bitstream build: passed with `write_bitstream Complete`.
- Programmed generated `top.bit` with `top.ltx`: passed.
- Ran generated `psu_init.tcl`, then refreshed Hardware Manager: one ILA core detected with 10 probes.
- AXI-Lite register smoke over JTAG:
  - `VERSION=0x00010000`
  - `ALGORITHM=2`
  - `DUC_MODE=0`
  - `INTERP_MODE=0`
- AXI DMA MM2S to DSM datapath smoke:
  - 4096 32-bit packed I/Q words transferred.
  - `INPUT_SAMPLE_COUNT=0x1000`
  - `FRONTEND_SAMPLE_COUNT=0x1000`
  - `OUTPUT_SAMPLE_COUNT=0x1000`
  - `INPUT_STALL_COUNT=0`
  - `ERROR_STATUS=0`

Implementation notes:

- The IP package no longer hard-codes `FREQ_HZ=100000000`; the board design
  now inherits the real PS `pl_clk0` frequency.
- The ZU15EG BD template now supports PS `S_AXI_HP*_FPD` or
  `S_AXI_HPC*_FPD` DMA memory ports.
- AXI DMA MM2S is connected through an explicit SmartConnect because Vivado
  automation did not reliably connect the upgraded vendor PS HP port.
- ILA is forced to native probe mode so probe widths are preserved.
- AXI DMA `c_sg_length_width` is set to 23. Older bitstreams with the default
  14-bit length field must keep simple-mode transfer lengths at or below
  `0x3FFF` bytes.

Debug lessons retained:

- The DSM chain itself was isolated from the first DMA stall by observing ILA
  AXI-Stream signals: `tready=1` while `tvalid=0`, so the selected DSM IP was
  ready and the failure was upstream in the DMA or memory path.
- The missing ILA core was caused by an uninitialized PS-generated PL clock.
  Running `psu_init`, removing PS-PL isolation, and applying the PS-PL reset
  sequence made the debug hub clock active and exposed the ILA probes.
- The upgraded vendor project did not always let block automation connect the
  AXI DMA master to the PS high-performance slave port. The working board
  script uses an explicit SmartConnect path for the DMA MM2S memory interface.
- The default AXI DMA simple-mode length width allowed small smoke transfers
  but failed at `0x4000` bytes. Increasing `c_sg_length_width` to 23 made the
  4096-word P0 transfer complete cleanly.
- Forcing the ILA monitor type to native mode avoided generated AXI monitor
  probe truncation and preserved the expected DSM, frontend, and status probe
  widths.
- The final board smoke proves the internal digital path:
  PS DDR -> AXI DMA MM2S -> AXI-Stream -> interpolation frontend -> DSM core
  -> counters/ILA. It does not prove an external DAC, RF, or analog output path.

Remaining limitations:

- The board flow is still a local bring-up flow under `fpga/zu15eg/local_hw/`;
  no vendor board collateral or generated bitstream is tracked.
- A reusable PS-side software driver has not yet been added.
- The current board smoke validates internal PS-DDR-to-PL streaming and ILA
  observation, not an external high-speed analog/RF output.

## 2026-07-08 13:59:30 +08:00

Reason:

- Move the ZU15EG AI-assisted DPD flow from PC/XSDB register pokes toward a
  PS-side bare-metal control loop.
- Validate the newly installed Vitis 2024.1 Embedded flow for generating an
  A53 standalone application.

Changed files:

- `fpga/zu15eg/scripts/export_hw_platform.ps1`
- `fpga/zu15eg/scripts/export_hw_platform.tcl`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.tcl`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/README.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `D:\Xilinx\Vitis\2024.1\bin\xsct.bat -eval "puts [version]; exit"`:
  passed, reported `xsct 2024.1.0`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\export_hw_platform.ps1`:
  passed, exported `fpga/zu15eg/out/dsm_dpd_zu15eg.xsa`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed, generated
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1`:
  blocked before ELF launch because XSDB target discovery returned no JTAG
  targets.
- `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat .\fpga\zu15eg\scripts\xsdb_list_targets.tcl`:
  ran, but listed no XSDB targets.
- Windows PnP inspection: detected FTDI USB serial interfaces on COM9, COM10,
  and COM11, but no Xilinx/Digilent JTAG target was visible to `hw_server`.
- `D:\Xilinx\Vitis\2024.1\data\xicom\cable_drivers\nt64\install_drivers_wrapper.bat`:
  blocked in the non-elevated shell with `Must have admin privileges`.

Implementation notes:

- The bare-metal C app now supports both older BSP AXI DMA device-id macros
  and Vitis 2024.1 SDT base-address macros.
- The Vitis build uses the 2024.1 Python API instead of classic XSCT app
  commands because the installed Vitis Embedded flow does not support the
  classic command path.
- The run script separates XSDB responsibilities from UART output: XSDB
  programs, initializes, downloads, and starts the ELF; `xil_printf` output is
  expected on the PS UART.

Remaining limitations:

- Bare-metal ELF execution has not yet been observed on the board because JTAG
  target discovery is currently empty.
- Xilinx cable drivers must be installed from an administrator shell, then the
  USB/JTAG cable should be replugged before rerunning the bare-metal launch.

Follow-up notes:

- After driver installation and USB/JTAG replug, Windows still enumerated only
  generic FTDI `VID_0403 PID_6011` VCP interfaces on COM9, COM10, and COM11.
- `xsdb_list_targets.tcl` and Vivado Hardware Manager target discovery still
  returned no hardware targets.
- The local schematic shows onboard USB-to-JTAG through an FT4232H and an
  external JTAG connector `J2`; vendor Vitis debug scripts expect
  `Xilinx HW-U1-VCU1525 FT4232H`.
- Remaining hardware action is to make the FT4232H appear as a supported
  Xilinx/Digilent cable using the vendor USB-JTAG setup, or to attach a
  known-good external JTAG adapter to `J2`.

## 2026-07-08 14:41:08 +08:00

Reason:

- Complete the ZU15EG bare-metal DPD smoke after moving from the Type-C path
  to the external `J2` JTAG path.
- Fix XSDB programming target selection for the current target tree, where the
  programmable logic target is named `PL` rather than `xczu*`.

Changed files:

- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.tcl`
- `fpga/zu15eg/scripts/xsdb_dpd_dma_smoke.tcl`
- `fpga/zu15eg/README.md`
- `docs/UPDATE_LOG.md`

Checks run:

- FTDI D2XX probe: passed, reported one Digilent device:
  `Digilent USB Device`, serial `D306BA2BABCD`, USB ID `0x0403:0x6014`.
- `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat .\fpga\zu15eg\scripts\xsdb_probe_connect_variants.tcl`:
  passed, detected `Digilent JTAG-SMT2 D306BA2BABCD`, `xczu15`, `arm_dap`,
  `PL`, `PMU`, `RPU`, and `APU` targets.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\run_baremetal_smoke.ps1`:
  passed, programmed `top.bit`, ran `psu_init.tcl`, selected Cortex-A53 #0,
  downloaded the bare-metal ELF, and launched it.
- Post-run XSDB counter readback:
  - `VERSION=0x00010000`
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`

Implementation notes:

- The local Type-C `J1` path lit the USB-side LED and enumerated FTDI serial
  interfaces, but Vivado/XSDB target discovery was empty through that path.
- The `J2` JTAG path exposed the correct Zynq UltraScale+ JTAG chain and
  allowed bitstream programming plus A53 bare-metal execution.
- `DPD_CTRL=0x2` after the app run is expected because the bare-metal
  calibration demo finishes in LUT DPD mode after iterating polynomial and LUT
  packages.

Remaining limitations:

- UART text output was not captured in the repository log; pass/fail evidence
  is based on ELF launch plus post-run hardware counter readback.
- This still validates the internal PS DDR -> AXI DMA -> DPD -> interpolation
  -> DSM datapath, not an external analog/RF output path.

## 2026-07-08 14:59:00 +08:00

Reason:

- Convert the ZU15EG bare-metal smoke into a repeatable board regression.
- Clarify VS Code single-file multibit DSM diagnostics versus formal
  filelist-based RTL compilation.

Changed files:

- `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `fpga/zu15eg/scripts/read_dsm_counters.tcl`
- `fpga/zu15eg/README.md`
- `docs/UPDATE_LOG.md`

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed.
- Board regression counter check:
  - `VERSION=0x00010000`
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_p0_multibit.ps1`:
  passed, 65536 samples, 0 failed rows in
  `verif/out_xsim_p0_multibit/summary.csv`.

Implementation notes:

- The board regression supports a full flow by default: bitstream rebuild,
  XSA export, bare-metal ELF build, bitstream programming, ELF launch, and
  counter check.
- Debug runs can reuse existing artifacts with `-SkipBitstreamBuild`,
  `-SkipXsaExport`, and `-SkipElfBuild`.
- The VS Code `unknown module dsm_core_multibit` report is caused by editor
  single-file parsing without `rtl/filelist_p0.f`. The Vivado/XSim filelist
  flow correctly compiles `dsm_core_multibit.sv` before its wrappers.

Remaining limitations:

- The regression pass still relies on internal hardware counters and does not
  capture PS UART text output or external analog/RF behavior.

## 2026-07-08 18:13:01 +08:00

Reason:

- Add useful PL-side observation metrics for the PS-side AI-assisted DPD
  calibration loop.
- Move the board demo beyond simple pass-through counters by exposing
  lightweight signal quality proxies that software can use during package
  search.

Changed files:

- `rtl/axi/dsm_ip_axi_top.v`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/scripts/read_dsm_counters.tcl`
- `docs/IP_HANDOFF.md`
- `docs/IP_SPEC.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `fpga/zu15eg/README.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Added read-only AXI-Lite monitor registers:
  - `0x64 MON_INPUT_POWER`
  - `0x68 MON_OUTPUT_POWER`
  - `0x6C MON_CLIP_COUNT`
  - `0x70 MON_PEAK`
  - `0x74 MON_AVG_MAG`
  - `0x78 MON_EVM_PROXY`
  - `0x7C MON_ACPR_PROXY`
- The monitor values are intentionally lightweight hardware proxies:
  accumulated input/output magnitude, clipping count, packed peak/average
  magnitudes, DPD correction magnitude, and RF slew magnitude.
- The ZU15EG bare-metal calibration loop now reads these monitor registers and
  includes saturation, clipping, sticky error, stall, correction-magnitude, and
  RF-slew penalties in the package cost.
- Documentation now describes the monitor register map and the AI-assisted DPD
  boundary: PS-side search/calibration with deterministic PL-side DPD,
  interpolation, DSM, DMA, and counters.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\verif\scripts\run_xsim_ip_smoke.ps1`:
  passed.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\ip\package_vivado_ip.ps1`:
  passed. Vivado reported non-fatal IP packager warnings.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed, built
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
- Full `run_zu15eg_baremetal_regression.ps1` was attempted. The run timed out
  after bitstream generation had completed; Vivado `write_bitstream` completed
  successfully with DRC `0 Errors, 79 Warnings`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed on the ZU15EG board.
- Board regression counter check:
  - `VERSION=0x00010000`
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`
  - `MON_INPUT_POWER=0x07F2C122`
  - `MON_OUTPUT_POWER=0x07FFF000`
  - `MON_CLIP_COUNT=0x00000002`
  - `MON_PEAK=0x7FFFFF4A`
  - `MON_AVG_MAG=0x7FF01BFD`
  - `MON_EVM_PROXY=0x0BF4A08C`
  - `MON_ACPR_PROXY=0x0801EFFC`

Remaining limitations:

- The new monitor registers are calibration/debug proxies, not formal EVM,
  ACLR, or spectrum-mask signoff metrics.
- Formal RF-recovered metrics still require an assumed or measured observation
  chain: DAC/output pulse shape, reconstruction filter, PA/channel behavior,
  downconversion, decimation, and gain/phase/delay alignment.
- Vivado reported DSP pipelining suggestions in the DPD path during bitstream
  generation. Future work should pipeline the DPD multiplier/add paths before
  pushing for higher PL clock targets.

## 2026-07-08 17:22:00 +08:00

Reason:

- Complete the first PS-side AI-assisted DPD calibration loop in the ZU15EG
  bare-metal application.
- Move package selection from a saturation-only smoke result to a repeatable
  PS-side search flow using MATLAB proxy scores plus hardware counter
  penalties.

Changed files:

- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_coeffs.h`
- `matlab/dpd/export_dpd_coeff_header.m`
- `matlab/dpd/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The bare-metal app now iterates all MATLAB-exported polynomial and LUT DPD
  packages.
- Each run records package name, proxy EVM, proxy SNDR, DPD saturation count,
  sticky error status, AXI-Stream stall count, and a combined calibration
  cost.
- The selected package is written back to the PL DPD registers at the end of
  the run.
- `export_dpd_coeff_header.m` now emits package names plus fixed-point proxy
  EVM/SNDR arrays, so future MATLAB calibration exports preserve the PS-side
  selection data.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed, built
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
- Direct A53 compile check with Vitis `aarch64-none-elf-gcc`: passed. The BSP
  emitted repeated macro warnings from generated `xparameters.h`, but the C
  source compiled successfully.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed.
- Board regression counter check:
  - `VERSION=0x00010000`
  - `INPUT_SAMPLE_COUNT=0x00001000`
  - `FRONTEND_SAMPLE_COUNT=0x00001000`
  - `DPD_SAMPLE_COUNT=0x00001000`
  - `OUTPUT_SAMPLE_COUNT=0x00001000`
  - `INPUT_STALL_COUNT=0x00000000`
  - `ERROR_STATUS=0x00000000`
  - `DPD_CTRL=0x00000002`
  - `DPD_SATURATION_COUNT=0x00000000`
- Attempted `matlab -batch "cd('E:/workspace/chip/dsm_ip/matlab'); path_setup; entry_export_dpd_coeff_header"`:
  did not complete within the local timeout and was stopped. The existing
  generated header was updated directly, and the export script was updated so
  future successful MATLAB exports include the same proxy-score fields.

Remaining limitations:

- The current PS-side calibration loop uses MATLAB proxy metrics and internal
  hardware counters. It does not yet use a real receiver/PA observation path.
- PS UART output was not captured into the repository; pass/fail evidence is
  based on ELF build/launch plus post-run hardware counter readback.
