# Update Log

This file records project changes that affect interfaces, verification status,
timing/resource evidence, repository hygiene, or handoff documentation.

## 2026-07-22 20:17:52 +08:00

Reason:

- Complete the pending ZU15EG board replay for the PS-side AI-seed DPD
  calibration loop after the JTAG/DAP target tree was restored.

Changed files:

- `fpga/zu15eg/scripts/xsdb_probe_dsm_version.tcl`
- `docs/evidence/dpd/zu15eg_ai_seed_search_20260722/README.md`
- `docs/evidence/dpd/zu15eg_ai_seed_search_20260722/counter_readback.txt`
- `docs/evidence/dpd/zu15eg_ai_seed_search_20260722/calibration_trace.csv`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Checks run:

- XSDB target precheck: passed with PL, PSU, and Cortex-A53 #0 visible.
- The read-only DSM version probe correctly rejected the uninitialized PL map
  before programming; post-run register access then returned version
  `0x00010000`.
- Direct A53 build: passed; generated a 118,776-byte ELF for the 16-QAM,
  48-subcarrier, 0.58-backoff, seed-1 waveform and `CAL_AI_POLICY_ONLY=1`.
- Board launch: passed bitstream programming, `psu_init`, A53 reset, ELF
  download, and execution start.
- Post-run AXI-Lite counter check: passed with four 4096-sample counters,
  polynomial DPD active, and zero stall, sticky error, clipping, or DPD
  saturation.
- JTAG calibration trace: passed with `complete=1`, `count=14`, and no
  overflow. Search reduced PL proxy cost from `316604` to `313959`.

Result and remaining limitations:

- The deterministic PS policy-seed -> DMA/PL measurement -> bounded-search ->
  final-register-update loop is now demonstrated on ZU15EG.
- UART was unavailable through the active JTAG-only connection, so acceptance
  uses the versioned memory trace and AXI-Lite counter readback.
- The tiny MLP remains offline and deployment-disabled. Physical PA feedback
  and measured RF EVM/SNDR/ACLR still require an external PA and observation
  receiver.

## 2026-07-22 00:01:00 +08:00

Reason:

- Consolidate every AI-assisted DPD check that does not require ZU15EG, JTAG,
  PS/DMA execution, or physical RF equipment into one reproducible signoff.

Changed files:

- `scripts/run_ai_dpd_offline_signoff.ps1`
- `fpga/zu15eg/scripts/evaluate_seed_mlp_loso.py`
- `matlab/dpd/README.md`
- `docs/evidence/dpd/offline_signoff_20260721/`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Checks run:

- Strict seed/regret LOSO: passed as a conservative gate; direct one-candidate
  execution was correctly blocked in profile, waveform, and random-seed
  holdouts.
- Safety-first policy Python/C equivalence: 552 decisions, zero mismatches.
- Observer-v2 feedback replay: 288 traces, zero monitor mismatches.
- TinyML Python/C/RTL equivalence: 329 decisions, zero mismatches.
- DPD MATLAB/RTL bit-true: polynomial and four-tap memory-polynomial paths each
  compared 256 samples with zero mismatches and zero maximum LSB error.
- Observation receiver MATLAB/RTL equivalence: 63 aligned pairs, one expected
  drop, and exact counters.
- Tiny MLP strict LOSO: passed as an offline seed candidate. Mean final-cost
  change versus fixed package 3 was `-94.01`, `-89.48`, and `-86.40` for held
  profile, waveform, and random-seed splits, with zero new modeled constraint
  failures. Deployment remains disabled.
- Full command:
  `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ai_dpd_offline_signoff.ps1`.

Result and remaining limitations:

- Offline behavioral modeling, holdout evaluation, fixed-point software, and
  RTL equivalence are signed off.
- The qualified policy remains seed selection plus mandatory 14-candidate
  bounded search. The MLP may propose the seed, but a direct one-candidate AI
  path is not qualified.
- ZU15EG PS/DMA replay and physical PA/observation-receiver EVM/SNDR/ACLR
  measurement remain board and laboratory tasks.

## 2026-07-18 01:25:00 +08:00

Reason:

- Retry the platform-matched PL configuration after a user power cycle before
  the test-only safety-seed ELF replay.

Board results:

- After power-up, J1 scan again found PL, PSU, and Cortex-A53 #0.
- Vivado accepted programming of the platform-exported
  `dsm_dpd_zu15eg.bit`; afterwards XSDB still showed PL, PSU, and A53, but a
  read of `DSM_VERSION` at `0xA0010014` returned an AXI AP transaction timeout.
- Running the matching `psu_init`, PL isolation removal, and PL reset sequence
  made the DAP enter AXI AP error state (`0x30000021`) and removed PSU/A53
  targets. No ELF was downloaded after this second configuration attempt.

Remaining board action:

- The currently exported PL bitstream/XSA/PS-init combination cannot yet prove
  a live DSM AXI-Lite path on this board. Do not retry the ELF until the board
  is power-cycled and the board integration/bitstream flow is checked for the
  correct PS-to-PL clock, reset, AXI interconnect, and address-map settings.
- The test-only selector and its 14-record replay logic remain host-verified;
  no board safety-seed trace has been captured.

## 2026-07-18 01:15:00 +08:00

Reason:

- Retry the J1 test-only safety-seed replay after the board interface became
  visible.

Board results:

- J1 scan passed: XSDB found PL, PSU, and Cortex-A53 #0; Windows enumerated
  COM9/COM10/COM11, and UART0 capture on COM11 received application output.
- The test ELF was downloaded without intentionally programming a bitstream.
  UART stopped after DMA setup and the JTAG trace header remained valid but
  empty (`complete=0`, `count=0`), so no calibration trace was claimed.
- Read-only access to `DSM_VERSION` at `0xA0010014` returned an AXI AP timeout,
  proving that the then-programmed PL did not expose the DSM/DMA map required
  by the ELF. The platform-exported DSM bitstream programming was started to
  restore map consistency; afterwards PL debug became visible but the DAP
  reported an AXI AP transaction error and PSU/A53 targets disappeared.

Remaining board action:

- Power-cycle the board with J1 connected and J2 disconnected. Re-establish
  PSU/A53 visibility before any further ELF download. Then verify DSM register
  access first, run the test ELF, and accept a trace only if it completes with
  one policy, 12 search, and one final record.

## 2026-07-18 01:05:00 +08:00

Reason:

- Attempt the first J1-board replay of the test-only safety-first seed ELF.

Board precheck:

- XSDB launched `hw_server` but found no PL, PSU, or Cortex-A53 target.
- Vivado Hardware Manager independently found no hardware target or `xczu15`
  device.
- Read-only Windows device enumeration found no present Xilinx, FTDI, Digilent,
  or USB Serial interface attributable to J1; only existing `COM3` and `COM4`
  ports were present.
- The ELF was not downloaded and no calibration trace was read. This is a J1
  USB enumeration/JTAG visibility block, not a selector, ELF, or trace failure.

Next board action:

- Reconnect J1 directly to a known-good data-capable USB port and verify that
  Windows enumerates both the Xilinx/FTDI JTAG interface and a new UART port.
  Keep J2 disconnected. Once Vivado sees `xczu15`, rerun the test-only ELF and
  capture the completed 14-record trace.

## 2026-07-18 00:05:00 +08:00

Reason:

- Make the safety-first PS selector available for a controlled, test-only
  bare-metal replay while preserving fail-closed observer and bounded-search
  behavior before requesting board access.

Changed files:

- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_direct.ps1`
- `fpga/zu15eg/baremetal/README.md`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation:

- Added `CAL_SAFETY_SEED_POLICY_ONLY=1`. This explicit test-only mode reads a
  completed `aligned_complex_pa_monitor_v2` record, builds existing Q12.20
  features, invokes `dpd_safety_seed_policy_predict`, and rejects an
  unqualified or fallback result. It does not call the blocked tree/LUT policy.
- A qualified package runs one policy replay, all 12 signed memory-polynomial
  perturbations, and a final replay. The trace is exactly 14 records and direct
  execution remains prohibited.
- The direct A53 builder now compiles and links `dpd_safety_seed_policy.c`.
  The built test ELF is
  `fpga/zu15eg/out/vitis_baremetal_safety_seed_policy/dsm_dpd_baremetal_smoke.elf`.

Checks run:

- Direct A53 ELF build with `CAL_SAFETY_SEED_POLICY_ONLY=1` and
  `CAL_USE_SOFTWARE_SEED=0`: passed. ELF size is `123533/4436/47395`
  text/data/BSS bytes. Existing generated-BSP macro redefinition warnings
  remain; no new selector compile or link error occurred.
- Vitis standard application build was attempted with the same defines. It is
  blocked before app creation because Vitis 2024.1 `create_client()` reports a
  host UTF-8 decode exception. No board action was attempted.

Remaining limitations:

- Do not download this ELF until J1 JTAG/UART is connected and the programmed
  PL image can complete an `aligned_complex_pa_monitor_v2` feedback window.
- The app intentionally fails if that observer condition or a qualified seed
  is absent. Post-DSM monitor counters cannot stand in for the required input.

## 2026-07-17 20:42:00 +08:00

Reason:

- Execute the next AI-assisted DPD validation and integration gates: create an
  isolated blind behavioral-PA matrix, evaluate the frozen observer-v2 model,
  add a PS-only tree -> LUT -> memory-polynomial-search interface, and generate
  one report separating DPD linearization from calibration-policy evidence.

Changed files:

- `matlab/dpd/run_dpd_memory_tinyml_dataset.m`
- `matlab/scripts/entry_dpd_memory_tinyml_blind_dataset.m`
- `scripts/run_matlab_dpd_memory_tinyml_blind_dataset.cmd`
- `scripts/run_memory_tinyml_blind_eval.cmd`
- `fpga/zu15eg/scripts/evaluate_memory_tinyml_blind.py`
- `fpga/zu15eg/scripts/finalize_memory_tinyml_hierarchy_policy.py`
- `fpga/zu15eg/scripts/generate_memory_tinyml_lut_header.py`
- `fpga/zu15eg/scripts/generate_ai_calibration_report.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_packages_v2.h`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_lut_v2.h`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_hierarchy_policy.h`
- `docs/evidence/dpd/memory_tinyml_blind_v2_20260717.csv`
- `docs/evidence/dpd/memory_tinyml_blind_v2_20260717.json`
- `docs/evidence/dpd/memory_tinyml_blind_v2_20260717.md`
- `docs/evidence/dpd/ai_calibration_comparison_20260717.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `matlab/dpd/README.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- The data generator now supports explicit `training` and `blind` profile sets.
  The training run regenerates the six 4-tap memory-polynomial Q2.14 packages
  into a PS header; blind generation cannot overwrite that package header.
- The blind set contains three profiles that jointly vary gain, compression,
  memory, observation noise, and thermal gain/phase drift. It is excluded from
  fitting, fixed-point threshold selection, LUT construction, and model choice.
- The frozen tree and training-waveform LUT are evaluated only as initial seed
  selectors. Every deployment action remains `fallback_14`; package-stage
  safety failures are not hidden by the later local-search label.
- The 72 blind conditions reveal 19 unsafe seed packages: 5/24 in
  `blind_compression_noise`, 5/24 in `blind_gain_memory`, and 9/24 in
  `blind_thermal_memory`. The hierarchy fails promotion.
- A PS-only observer-v2 hierarchy interface was added. It can read completed
  aligned complex-feedback registers, use the same C Q12.20 feature builder and
  tree, fall back to a generated waveform LUT, write the selected 4-tap
  memory-polynomial package through the shadow/commit interface, and record
  one seed, 12 local coefficient perturbations, and one final replay. It does
  not instantiate any TinyML RTL in AXI. The finalizer converts the blind result
  into `DPD_TINYML_HIERARCHY_POLICY_AVAILABLE=0`, so this interface is blocked
  from board enablement until a future policy passes a blind safety gate.
- `ai_calibration_comparison_20260717.md` reports no-DPD/memoryless/
  memory-polynomial EVM/ACLR results separately from fixed/LUT/tree seed and
  14-candidate policy evidence.

Checks run:

- `scripts/run_matlab_dpd_memory_tinyml_dataset.cmd`: passed outside the
  restricted sandbox; 1728 rows and 288 training conditions.
- `scripts/run_matlab_dpd_memory_tinyml_blind_dataset.cmd`: passed outside the
  restricted sandbox; 432 rows and 72 blind conditions.
- `scripts/run_memory_tinyml_blind_eval.cmd`: passed as a completed negative
  safety evaluation; generated blocked policy header with 19 violations.
- `python -m py_compile` for all added blind-evaluation/report generators:
  passed.
- Host C frozen-tree comparison: passed, 329/329 decisions.
- Host Vivado/XSim frozen-tree equivalence: passed, 329/329 Python/C/RTL
  decisions. The restricted sandbox did not launch Vivado and therefore could
  not create `xvlog.log`; the required host rerun completed successfully.
- A53 direct build with `CAL_TINYML_HIERARCHY_ONLY=1`: passed while the
  evidence-generated header keeps the hierarchy unavailable. Existing BSP macro
  redefinition warnings remain.
- A53 direct build with the hierarchy implementation temporarily compiled in:
  passed; it was not run or downloaded to the board. The blind-report finalizer
  immediately restored `DPD_TINYML_HIERARCHY_POLICY_AVAILABLE=0`.
- `scripts/run_matlab_p0_bittrue_check.cmd`: passed outside the restricted
  sandbox; all seven 65,536-sample DSM paths have zero mismatches.
- `git diff --check`: passed with existing line-ending notices only.

Remaining limitations:

- The blind result blocks the observer-v2 tree/LUT seed hierarchy. Do not force
  its generated header to `AVAILABLE=1`, connect it to AXI, or run it on board.
- The PS interface requires a completed aligned complex-feedback observation
  window. Board post-DSM monitor counters remain a distinct feature schema and
  cannot be substituted for the observer-v2 model input.
- The 14-candidate local search still needs a physical PA/receiver or an
  independently replayed complex-feedback loop to establish RF behavior. The
  current blind evidence remains behavioral simulation.

## 2026-07-15 16:47:36 +08:00

Reason:

- Regenerate the behavioral PA/TinyML path with the exact finite-width
  `aligned_complex_pa_monitor_v2` contract, retrain strict quantized PA-profile
  LOSO, regenerate the frozen Python/C/RTL model, and replay retained raw
  complex-feedback traces without changing the deployed safety policy.

Changed files:

- `matlab/dpd/run_dpd_memory_tinyml_dataset.m`
- `fpga/zu15eg/scripts/evaluate_memory_tinyml_loso.py`
- `fpga/zu15eg/scripts/evaluate_quantized_memory_tinyml_tree_loso.py`
- `fpga/zu15eg/scripts/export_memory_tinyml_tree.py`
- `fpga/zu15eg/scripts/export_memory_tinyml_feature_vectors.py`
- `fpga/zu15eg/scripts/generate_memory_tinyml_tree_sources.py`
- `fpga/zu15eg/scripts/replay_memory_tinyml_complex_feedback.py`
- `scripts/run_memory_tinyml_preboard.ps1`
- `scripts/run_memory_tinyml_complex_feedback_replay.cmd`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_tree.h`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_tree.c`
- `rtl/dpd/dpd_tinyml_tree.v`
- `verif/vectors/dpd/memory_tinyml_tree_q20_v2.txt`
- `verif/vectors/dpd/memory_tinyml_features_raw_v2.txt`
- `docs/evidence/dpd/memory_tinyml_tree_q20_v2_20260715.json`
- `docs/evidence/dpd/memory_tinyml_tree_q20_loso_v2_20260715.json`
- `docs/evidence/dpd/memory_tinyml_complex_feedback_replay_v2_20260715.json`
- `docs/evidence/dpd/memory_tinyml_complex_feedback_replay_v2_20260715.csv`
- `docs/DPD_TINYML_TREE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `matlab/dpd/README.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- The generator now applies exact Q2.14 complex-gain alignment, arithmetic
  shift, Q1.15 saturation, signed absolute-value corner handling, 32-bit
  accumulator wrap, complex slew, and DC/Fs/4/Fs/2 fixed-bin statistics. It
  emits 1728 package rows for 288 conditions and retains 288 raw feedback
  traces with 497,664 complex samples. The schema is uniquely
  `aligned_complex_pa_monitor_v2`.
- Strict quantized PA-profile LOSO gives the standalone tree 121 direct and 167
  fallback decisions, zero safety violations, zero mean regret, mean candidate
  count `8.538`, and only 2/12 folds non-worse than LUT. The standalone tree is
  rejected. The hierarchical tree-then-LUT policy gives 186 direct suggestions
  and 102 fallbacks, zero safety violations, mean regret `408.861`, mean
  candidate count `5.604`, 12/12 non-worse folds, and 5/12 strictly better
  folds. It is qualified only as a software hierarchy.
- Frozen full-data model version `0x00020000` has 154 direct suggestions and
  134 fallbacks with zero training safety violations, regret, or path mismatch.
  Python, host C, and RTL agree on all 329 condition/boundary decisions; the C
  raw-feature builder agrees with Python on all 288 conditions.
- Independent raw complex-feedback replay reconstructs 288/288 MATLAB monitor
  records exactly. The 154 direct suggestions have zero labeled safety
  violations and zero mean/maximum regret; 134 inputs request tree fallback.
- The standalone RTL remains absent from `dsm_ip_axi_top.v`. Replay deployment
  action remains `fallback_14`, and bare-metal policy output remains
  `direct=0 local_candidates=14`.

Checks run:

- `scripts/run_memory_tinyml_preboard.ps1`: passed; strict quantized LOSO,
  source generation, 329/329 Python/C/RTL decisions, and 288/288 C raw-feature
  decisions.
- `scripts/run_memory_tinyml_complex_feedback_replay.cmd`: passed; 288/288 raw
  monitor reconstructions and zero direct-suggestion safety/regret failures.
- `verif/scripts/run_xsim_p0_all.ps1`: passed; seven DSM paths, 65,536 samples
  each.
- `scripts/run_matlab_p0_bittrue_check.cmd`: passed; zero mismatches on all
  seven DSM paths.
- `verif/scripts/run_xsim_ip_smoke.ps1`: passed.

Remaining limitations:

- The full-data model and raw replay reuse the behavioral generation domain;
  they prove arithmetic and implementation consistency, not unseen-PA
  generalization or physical RF performance.
- Modeled clip and saturation features are both zero in the current matrix;
  no artificial variation was introduced, and those safety dimensions remain
  unqualified for direct execution.
- TinyML remains disconnected from AXI. Integrating the qualified software
  hierarchy requires independent complex-feedback evidence and must retain the
  14-candidate fallback; no one-candidate board action is enabled.

## 2026-07-15 16:02:00 +08:00

Reason:

- Restore local Vivado execution, rerun the frozen TinyML and IP delivery
  checks, then close the PA-aware feature-source gap by extending
  `dpd_observer` with complex aligned feedback statistics and temperature.

Changed files:

- `rtl/dpd/dpd_observer.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `matlab/dpd/prepare_dpd_observer_behavioral_vectors.m`
- `verif/tb/tb_dpd_observer_behavioral.sv`
- `verif/tb/tb_dpd_v11.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `verif/scripts/run_xsim_dpd_observer_behavioral.ps1`
- `ip/ip_repo/dsm_ip_1_0/component.xml`
- `docs/IP_HANDOFF.md`
- `docs/DPD_TINYML_TREE.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- Vivado 2024.1 executes normally outside the restricted sandbox. The frozen
  Q12.20 tree again matches Python, host C, and RTL on all 330 decisions.
- Wrapper version `0x00010002` defines `aligned_complex_pa_monitor_v2` at
  `0xD8..0xFC`. Temperature is latched from `CONDITION_ENV` on observation
  start. Valid aligned pairs accumulate reference/observation magnitude,
  observation peak, clip/saturation, complex slew, and complex DC/Fs/4/Fs/2
  fixed-bin proxies. Existing pair/drop and wide L1-error semantics are
  preserved.
- MATLAB now exports exact expected monitor statistics with its behavioral PA
  vectors. XSim compares all 18 metadata fields. Directed unit smoke separately
  forces aligned Q1.15 saturation and checks clip, saturation, and temperature
  latching. AXI smoke reads and checks every new register.
- The behavioral-observer driver now rejects `Fatal:` in the XSim log and
  requires an explicit PASS marker. This exposed and fixed a testbench CSV
  header-buffer truncation that the old driver had incorrectly reported as a
  successful process exit.
- Fresh ZU15EG OOC evidence is
  `syn/reports/axi_v11_20260715_155606/summary.csv`: 8,975 LUTs, 7,562
  flip-flops, 154 DSPs, and `+2.302 ns` WNS at 100 MHz. Compared with
  `syn/reports/axi_v11_20260715_154022/summary.csv`, the monitor adds 1,399
  LUTs and 387 flip-flops, no DSPs, and no timing regression.

Checks run:

- `verif/scripts/run_xsim_dpd_observer_behavioral.ps1`: passed; MATLAB/RTL
  observer statistics are exact.
- `verif/scripts/run_tinyml_tree_equivalence.ps1`: passed; 330/330
  Python/C/RTL decisions agree.
- `verif/scripts/run_xsim_p0_all.ps1`: passed; seven 65,536-sample DSM
  simulations completed with zero failed rows.
- `scripts/run_matlab_p0_bittrue_check.cmd`: passed; all seven DSM paths have
  zero mismatches. One earlier invocation raced the parallel XSim producer and
  failed on a missing dump; the required serial rerun passed.
- `verif/scripts/run_xsim_ip_smoke.ps1`: passed after the extension and again
  after adding explicit clip/saturation boundary coverage.
- `ip/package_vivado_ip.ps1`: passed; packaged IP regenerated. The unconnected
  TinyML tree remains intentionally excluded by Vivado.
- `syn/run_ooc_dsm_ip_axi_v11.ps1 -Part xczu15eg-ffvb1156-1-i`: passed with
  positive 100 MHz WNS.

Remaining limitations:

- The frozen tree uses `behavioral_pa_observation_v1`; it is not numerically
  interchangeable with the new finite-width `aligned_complex_pa_monitor_v2`.
  Keep the RTL tree uninstantiated and mandatory local search enabled.
- Regenerate the behavioral matrix with exact v2 arithmetic, retrain strict
  quantized PA-profile LOSO, repeat Python/C/RTL equivalence, and replay real or
  simulated complex-feedback traces before enabling any direct TinyML action.
- The proxy accumulators are finite-width window statistics, not formal RF
  EVM/ACLR measurements or RF safety limits.

## 2026-07-15 13:27:50 +08:00

Reason:

- Freeze the qualified software decision-tree candidate into an auditable
  fixed-point contract and prepare exact Python/C/RTL decision equivalence
  before requesting board access.

Changed files:

- `.gitignore`
- `fpga/zu15eg/scripts/export_memory_tinyml_tree.py`
- `fpga/zu15eg/scripts/generate_memory_tinyml_tree_sources.py`
- `fpga/zu15eg/scripts/evaluate_quantized_memory_tinyml_tree_loso.py`
- `fpga/zu15eg/scripts/replay_memory_tinyml_tree_board.py`
- `fpga/zu15eg/scripts/export_memory_tinyml_feature_vectors.py`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_tree.h`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_tree.c`
- `fpga/zu15eg/baremetal/src/dpd_tinyml_features.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_direct.ps1`
- `rtl/dpd/dpd_tinyml_tree.v`
- `verif/c/test_dpd_tinyml_tree.c`
- `verif/c/test_dpd_tinyml_features.c`
- `verif/tb/tb_dpd_tinyml_tree.sv`
- `verif/vectors/dpd/memory_tinyml_tree_q20.txt`
- `verif/vectors/dpd/memory_tinyml_features_raw.txt`
- `verif/vectors/dpd/memory_tinyml_board_replay_q20.txt`
- `verif/scripts/run_tinyml_tree_equivalence.ps1`
- `verif/scripts/run_xsim_p0_all.ps1`
- `verif/scripts/run_xsim_ip_smoke.ps1`
- `verif/scripts/filelist_p0_abs.ps1`
- `ip/filelist_dsm_ip.f`
- `ip/package_vivado_ip.tcl`
- `ip/package_vivado_ip.ps1`
- `scripts/run_memory_tinyml_quantized_loso.cmd`
- `scripts/run_memory_tinyml_board_replay.cmd`
- `scripts/run_memory_tinyml_preboard.ps1`
- `docs/evidence/dpd/memory_tinyml_tree_q20_20260715.json`
- `docs/evidence/dpd/memory_tinyml_tree_q20_loso_20260715.csv`
- `docs/evidence/dpd/memory_tinyml_tree_q20_loso_20260715.json`
- `docs/evidence/dpd/memory_tinyml_board_replay_20260715.csv`
- `docs/evidence/dpd/memory_tinyml_board_replay_20260715.json`
- `docs/DPD_TINYML_TREE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `matlab/dpd/README.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- The depth-4 tree is retrained deterministically on all 288 behavioral
  conditions. Training-space split thresholds are transformed back to the 13
  engineered feature units and quantized to signed Q12.20. Inclusive per-feature
  training-domain bounds force out-of-distribution input to fallback.
- Conservative leaf promotion releases a package only when every retained leaf
  sample is safe and has the same oracle package. The frozen fit has 202 direct
  decisions, 86 mandatory-search fallbacks, zero training safety violations,
  zero training regret, and zero float/fixed path mismatches. These are fitting
  results, not LOSO or physical-PA evidence.
- Golden vectors cover all 288 conditions, both sides of each tree threshold,
  both sides of all 13 domain bounds, three path-preserving leaf-envelope exits,
  and invalid input: 330 decisions total. Python and host C match package,
  direct/fallback action, path, path length, and OOD status on all decisions.
- Standalone synthesizable RTL and a vector-driven XSim testbench implement the
  same interface. The RTL is included in project source lists but is not
  instantiated by the AXI wrapper, so current board behavior remains unchanged
  and mandatory local search remains enabled.

Checks run:

- `python -m py_compile ...evaluate_memory_tinyml_loso.py ...export_memory_tinyml_tree.py`: passed.
- `gcc -std=c99 -Wall -Wextra -Werror ...`: passed.
- Host C against Python vectors: passed; initially 327/327 decisions and then
  330/330 after adding path-preserving leaf-envelope boundary vectors.
- `git diff --check`: passed with existing line-ending notices only.
- XSim tree equivalence: not completed. The restricted process returned success
  without launching Vivado or producing logs; the required external execution
  request was rejected by the approval service. No RTL PASS is claimed.
- `scripts/run_matlab_p0_bittrue_check.cmd`: not completed. MATLAB stopped at
  startup with `System Error: File system inconsistency`; no model check ran.

Remaining limitations:

- Run the 330-vector XSim test, required DSM/IP regressions, IP packaging, and
  OOC synthesis in a working Vivado execution context.
- Convert retained board monitor traces to the exact Q12.20 feature contract,
  run Python/C host replay, and inspect every released package against the
  measured 14-candidate result before connecting the tree to AXI or enabling
  direct execution.
- Behavioral PA fitting and monitor proxy evidence do not establish real RF
  EVM/ACLR improvement or safety certification.

Follow-up retained-trace audit:

- Added `fpga/zu15eg/scripts/replay_memory_tinyml_tree_board.py`,
  `scripts/run_memory_tinyml_board_replay.cmd`, retained replay CSV/JSON, and a
  16-row C vector set.
- Python/C replay passes 16/16 decisions and conservatively selects fallback
  for all rows. Every row lacks temperature and observer L1 error. Every row's
  gain, peak/average, EVM, and ACPR ratios is outside the behavioral domain;
  seven also miss the spectral-ratio range and one misses both spectral ranges.
- Root cause is feature schema, not threshold quantization: behavioral output
  statistics describe complex PA feedback, while current PL output statistics
  describe the post-DSM one-bit stream. Model metadata now names
  `behavioral_pa_observation_v1`; retained trace replay names
  `pl_dsm_monitor_v1`. Direct deployment remains blocked.
- Added per-fold retrain/freeze/quantize evaluation and conservative direct-leaf
  min/max envelopes. The pure fixed tree has zero violations but is non-worse
  than LUT in only 7/12 folds, so it fails promotion. The hierarchical policy
  uses a direct tree result when qualified, otherwise delegates to the existing
  LUT safety gate and then 14-candidate search. It has zero violations, is
  non-worse than LUT in 12/12 folds, strictly better in 11/12, and reduces mean
  candidates to `5.649` with mean regret `59.681`.
- Added deterministic JSON-to-C/RTL source generation and leaf-envelope edge
  vectors. The generated host C reference passes all 330 full-model decisions.
  RTL XSim remains unclaimed until Vivado can execute and emit its PASS log.
- Added the raw-monitor PS feature builder and a 288-condition end-to-end
  Python/C test. All 13 Q12.20 features and all final tree decisions match
  exactly. The C files are included in both Vitis application build paths but
  are not called by the current board policy, so runtime behavior is unchanged.
- Direct Vitis A53 cross-compile and link passed with the existing XSA-derived
  BSP. The ELF contains text/data/BSS sizes `72425/4436/47403` bytes. Only the
  pre-existing generated-BSP address-macro redefinition warnings were emitted;
  no TinyML source warning or error occurred. No ELF was downloaded to a board.
- Hardened P0 XSim, IP smoke, and IP packaging wrappers against stale-output
  false positives. They now require a fresh tool log; P0 also removes stale
  testbench summaries and requires each new summary/vector, while packaging
  requires a newly updated `component.xml` and Tcl success marker without
  deleting a previous valid package before launch.
- The hardened wrappers expose the current environment limitation correctly:
  P0 and IP smoke stop because no Vivado log is produced, and IP packaging
  returns failure. An earlier P0 invocation had rewritten `summary.csv` from
  stale testbench summaries and was not a valid 7/7 run; it is explicitly not
  claimed. The failed packaging attempt removed the ignored generated
  `component.xml` before the preservation fix, so regenerate the package when
  Vivado execution is restored.

## 2026-07-15 04:32:44 +08:00

Reason:

- Complete the four pre-TinyML upgrades: joint EVM/ACLR/safety coefficient
  training, behavioral-PA observation-loop XSim, expanded memory-DPD PA data,
  and strict software-model competition against the LUT baseline.

Changed files:

- `.gitignore`
- `matlab/dpd/run_dpd_memory_poly_training_comparison.m`
- `matlab/dpd/prepare_dpd_observer_behavioral_vectors.m`
- `matlab/dpd/run_dpd_memory_tinyml_dataset.m`
- `matlab/scripts/entry_dpd_memory_poly_training_comparison.m`
- `matlab/scripts/entry_dpd_memory_tinyml_dataset.m`
- `scripts/run_matlab_dpd_memory_tinyml_dataset.cmd`
- `scripts/run_memory_tinyml_loso.cmd`
- `verif/tb/tb_dpd_observer_behavioral.sv`
- `verif/scripts/run_xsim_dpd_observer_behavioral.ps1`
- `fpga/zu15eg/scripts/evaluate_memory_tinyml_loso.py`
- `docs/evidence/dpd/memory_poly_q214_20260715.csv`
- `docs/evidence/dpd/memory_tinyml_loso_20260715.csv`
- `matlab/dpd/README.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- The memory-polynomial trainer now searches signed-Q2.14 ridge/blend
  candidates with a hard memoryless-ACLR-plus-0.05-dB boundary and rejects
  fixed-point saturation, drive limiting, or peak-limit violations. Held-out
  mean EVM is `2.827825%` versus `3.117541%` memoryless and `4.305013%` no DPD;
  mean ACLR is `-32.507411 dBc` versus `-32.557627 dBc` memoryless. All three
  held seeds remain saturation- and limiting-free.
- MATLAB exports a 64-sample behavioral-PA feedback window. The dedicated
  XSim observer test passes with delay 3, gain `(18239,-381)`, 63 pairs, one
  deliberate invalid/drop, exact L1 error `92046`, window completion, and
  `tlast` detection.
- The memory-DPD data set contains 1728 candidate rows: 12 PA gain/saturation/
  memory/noise/thermal profiles, QAM16/QAM64, 20/40 MHz, 0.58/0.70 backoff,
  three random seeds, and six clamped signed-Q2.14 package strengths. It yields
  288 condition-level labels including explicit all-unsafe fallback cases.
- Dependency-free PA-profile LOSO compares LUT, ridge-linear, depth-4 decision
  tree, weighted k-NN, and an eight-hidden-unit MLP using waveform metadata,
  monitor ratios, and observation error. Tree and k-NN each produce 148 direct
  and 140 fallback decisions, zero safety violations, zero mean regret, and
  `7.319` mean candidates versus LUT's 140/148, zero violations, `127.521`
  mean regret, and `7.681` mean candidates. Both are non-worse in 12/12 folds
  and strictly better in 9/12. Zero violation refers to safety-gated direct
  decisions; rejected, unknown, or all-unsafe conditions retain the 14-candidate
  fallback action.
- The small decision tree is preferred over k-NN for the next fixed-point/RTL
  evaluation because its inference maps to comparators and thresholds. No
  TinyML RTL or deployment constants are generated in this change.

Checks run:

- Joint memory-DPD MATLAB comparison: passed all paired EVM, validation ACLR
  boundary, saturation, and drive-limit assertions.
- Behavioral PA observer XSim: passed exact pair/drop/error/window checks.
- Memory TinyML data generator: passed 1728-row, 288-condition, 12-profile,
  six-package completeness checks after explicit signed-16 coefficient clamp.
- Python LOSO evaluator: passed; tree and k-NN meet the strict per-fold LUT
  promotion rule with zero safety violations.
- Required MATLAB P0 bit-true: seven designs, 65,536 samples each, zero
  mismatches.
- DPD XSim bit-true: memoryless and memory-polynomial each 256/256 samples,
  zero mismatch, zero maximum LSB error.

Remaining limitations:

- TinyML qualification is behavioral simulation evidence. The selected tree
  still needs fixed-point quantization/equivalence and board trace replay before
  RTL is justified.
- The observation flow proves the digital AXI-stream observer with modeled PA
  vectors; it is not a physical PA or calibrated RF receiver measurement.
- The safety limits (`10%` EVM, `-20 dBc` ACLR, zero saturation/limiting) are
  simulation qualification limits, not RF certification thresholds.

## 2026-07-15 03:28:19 +08:00

Reason:

- Train fixed-point memory-polynomial DPD coefficients and compare no DPD,
  memoryless DPD, and memory-polynomial DPD under the same behavioral PA using
  held-out OFDM waveforms.

Changed files:

- `matlab/dpd/run_dpd_memory_poly_training_comparison.m`
- `matlab/scripts/entry_dpd_memory_poly_training_comparison.m`
- `scripts/run_matlab_dpd_memory_poly_comparison.cmd`
- `matlab/dpd/README.md`
- `docs/evidence/dpd/memory_poly_q214_20260715.csv`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The benchmark fixes one nominal behavioral PA for every path: three
  nonlinear memory-polynomial taps, soft saturation, a three-tap linear FIR,
  gain/phase drift, and 43 dB observation SNR. The waveform is 64-QAM with
  96/512 occupied subcarriers and 0.58 normalized input backoff.
- Indirect learning fits a three-coefficient memoryless postdistorter and a
  12-coefficient, four-tap memory-polynomial postdistorter. Ridge strength is
  selected on validation seed 137 after fitting seed 101; test seeds
  211/223/239 are never used for fitting or selection.
- Coefficients are quantized to the implemented Q2.14 complex format and
  evaluated with Q1.15 arithmetic matching the RTL operation order. Every mode
  shares the same PA parameters and per-seed observation-noise realization.
- The run exports per-seed metrics, aggregate metrics, floating and quantized
  coefficients, packed AXI words, and a MATLAB snapshot under
  `matlab/out/dpd/`. These outputs are generated evidence and remain ignored.

Checks run:

- `run_matlab_dpd_memory_poly_comparison.cmd`: passed. Across three held-out
  test seeds, mean EVM was `4.305013%` without DPD, `3.117541%` with
  memoryless DPD, and `1.897744%` with four-tap memory-polynomial DPD. The
  4-tap model reduced EVM by 55.92% versus no DPD and 39.13% versus memoryless
  DPD, and won the paired EVM comparison on all 3/3 test seeds.
- Mean NMSE/SNDR moved from `-27.3263/+27.3263 dB` without DPD to
  `-30.1239/+30.1239 dB` with memoryless DPD and `-34.4354/+34.4354 dB` with
  memory-polynomial DPD. Both DPD paths had zero fixed-point saturation and
  zero drive-limited samples.
- Required `run_matlab_p0_bittrue_check.cmd`: passed all seven DSM designs,
  each with 65,536 samples and zero mismatches.
- `run_xsim_dpd_bittrue.ps1`: passed both memoryless and memory-polynomial DPD
  comparisons, each 256/256 samples with zero mismatch and zero maximum LSB
  error.

Remaining limitations:

- Ridge selection minimizes held-out EVM only. Mean ACLR was `-32.1599 dBc`
  without DPD, `-32.5576 dBc` with memoryless DPD, and `-32.1922 dBc` with
  memory-polynomial DPD. The 4-tap result is therefore 0.03 dB better than no
  DPD but 0.37 dB worse than memoryless DPD; joint EVM/ACLR optimization is the
  next algorithm task.
- Results cover one modeled PA profile, waveform class, bandwidth, backoff,
  and temperature/drift configuration. They demonstrate held-out generalization
  across random waveform seeds, not across unseen PA conditions.
- The PA and observation receiver are behavioral models. No measured RF EVM,
  ACLR, PA linearization, or certification claim is authorized.

## 2026-07-15 00:50:00 +08:00

Reason:

- Complete the three TX frontend v1.1 upgrades: memory-polynomial DPD RTL, an
  aligned observation/training stream, and runtime-condition-driven seed
  prediction, while preserving all existing DPD modes and the qualified safety
  policy.

Changed files:

- `.gitignore`
- `rtl/dpd/dpd_memory_poly.v`
- `rtl/dpd/dpd_observer.v`
- `rtl/dpd/dpd_seed_predictor.v`
- `rtl/dpd/dpd_frontend.v`
- `rtl/axi/dsm_ip_axi_top.v`
- `matlab/dpd/prepare_dpd_memory_poly_bittrue_vectors.m`
- `matlab/dpd/compare_dpd_memory_poly_rtl_xsim.m`
- `matlab/scripts/entry_dpd_bittrue_check.m`
- `verif/tb/tb_dpd_memory_poly_bittrue.sv`
- `verif/tb/tb_dpd_v11.sv`
- `verif/tb/tb_dpd_frontend.sv`
- `verif/tb/tb_dsm_ip_axi_smoke.sv`
- `verif/scripts/run_xsim_dpd_bittrue.ps1`
- `verif/scripts/run_xsim_ip_smoke.ps1`
- `verif/scripts/filelist_p0_abs.ps1`
- `ip/filelist_dsm_ip.f`
- `ip/package_vivado_ip.tcl`
- `syn/run_ooc_dsm_ip_axi_v11.ps1`
- `syn/run_ooc_dsm_ip_axi_v11.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix.tcl`
- `syn/run_ooc_dsm_ip_axi_matrix_synth.tcl`
- `syn/run_ooc_dsm_ip_axi_routed_subset.tcl`
- `fpga/zu15eg/scripts/create_dsm_dma_ila_bd.tcl`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `docs/IP_HANDOFF.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- DPD mode 3 now implements a 9-stage, 2-to-4-tap complex memory polynomial:
  `sum_m x[n-m]*(C1[m]+C3[m]|x[n-m]|^2+C5[m]|x[n-m]|^4)`. Samples remain
  Q1.15 and coefficients remain Q2.14. Four-tap coefficient shadow banks allow
  an atomic AXI-Lite commit. Bypass, memoryless polynomial, and LUT modes retain
  their prior arithmetic and externally aligned latency.
- The new optional `s_axis_obs` input pairs observation samples with a 32-entry
  TX-reference ring using programmed delay and Q2.14 complex gain. Explicit
  start/clear/window controls expose active/done status, valid pair/drop counts,
  and a 64-bit aligned L1 error. Observation traffic never stalls TX.
- Runtime QAM, bandwidth, backoff, Q8.8 power/temperature, and monitor-state
  registers feed a conservative hardware seed selector. Known 0.58/0.70
  backoff anchors select package 2/5; unknown, version-mismatched, or faulted
  states request fallback. `local-search-required` remains asserted, so this
  upgrade does not enable the rejected one-candidate direct policy.
- The AXI core version is `0x00010001`; registers `0x90` through `0xD4` expose
  memory-polynomial programming, observer control/status, runtime conditions,
  and seed status. Vivado packaging infers `s_axis_obs` as AXI-Stream and
  associates `s_axi:s_axis:s_axis_obs` with `aclk`.
- The ZU15EG OOC script uses top-level `report_utilization` values rather than
  recursive hierarchy cell counts and applies I/O false paths only to ports of
  the correct direction.
- v1.1 XSim compile outputs and timestamped OOC report directories are ignored
  as generated artifacts; the commands and summarized evidence remain tracked.

Checks run:

- Memoryless DPD MATLAB/RTL bit-true comparison: passed 256/256 samples with
  zero mismatches and zero maximum LSB error.
- Memory-polynomial DPD MATLAB/RTL bit-true comparison: passed 256/256 samples
  with zero mismatches and zero maximum LSB error.
- `run_xsim_ip_smoke.ps1`: passed DSM top, AXI top, and DPD v1.1 unit tests;
  the observation test completed with two aligned pairs.
- `run_xsim_p0_all.ps1`: passed all 7/7 simulation tests.
- `run_matlab_p0_bittrue_check.cmd`: passed all seven DSM designs with 65,536
  samples per design and zero mismatches.
- `package_vivado_ip.ps1`: passed; Vivado inferred `s_axi`, `s_axis`, and
  `s_axis_obs` bus interfaces.
- Direct ZU15EG A53 bare-metal build: passed; ELF size was 124,264 bytes. The
  generated BSP still emits its existing duplicate-macro warnings.
- Required `run_ooc_all_dsm.ps1 -Part xc7z020clg400-1`: 12/14 variants passed
  100 MHz. Existing exploratory `p0_ooc_mb_ef2` and `p0_ooc_mb_mash22` missed
  timing at `-0.093 ns` and `-0.688 ns`, respectively.
- Full v1.1 `dsm_ip_axi_top` OOC on `xczu15eg-ffvb1156-1-i`, EFDSM,
  interpolation bypass: passed 100 MHz with 7,576 CLB LUTs (2.22%), 7,175
  flip-flops (1.05%), 154 DSPs (4.37%), and `+2.299 ns` WNS.
- `git diff --check`: passed; only existing line-ending conversion notices
  were reported.

Remaining limitations:

- No physical PA or calibrated observation receiver is available. This change
  proves deterministic fixed-point behavior and integration readiness, not
  measured RF EVM/ACLR improvement or RF safety certification.
- Delay and complex gain alignment are software-programmed; automatic alignment
  estimation, formal EVM/ACLR calculation, and coefficient adaptation remain
  control-loop work.
- The current board block design ties the unused observation stream low until a
  modeled or physical feedback source is integrated.
- The hardware predictor is a conservative anchor selector, not TinyML
  inference. The qualified software policy still performs the mandatory
  14-candidate bounded search.

## 2026-07-14 14:16:32 +08:00

Reason:

- Complete the software AI portion of the communication IP in one bounded,
  evidence-backed policy instead of continuing to tune unsafe direct-path
  thresholds.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_seed_regret_benchmark.m`
- `matlab/scripts/entry_dpd_seed_regret_benchmark.m`
- `scripts/run_matlab_dpd_seed_regret_benchmark.cmd`
- `fpga/zu15eg/scripts/evaluate_seed_regret_loso.py`
- `fpga/zu15eg/scripts/finalize_ai_calibration_policy.py`
- `fpga/zu15eg/scripts/run_seed_regret_j1_replay.ps1`
- `fpga/zu15eg/baremetal/src/dpd_ai_policy.h`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_direct.ps1`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The completed behavioral data set has 1728 records: 12 PA/observation
  profiles, eight QAM/bandwidth/backoff waveforms, random seeds 41/53/67, and
  six deterministic Q2.14 polynomial seed packages. Every package row has an
  actual one-round, 14-candidate bounded-search result. Baseline waveform/seed
  coefficients are reused across PA profiles to avoid held-profile fit leakage.
- Strict leave-one-profile, leave-one-waveform, and leave-one-random-seed tests
  reject one-candidate direct execution. A regret-only direct gate and a more
  conservative five-safe-neighbor gate both retain held regret or modeled-EVM
  violations. The final generated policy therefore fixes
  `DIRECT_ALLOWED=0` and `FORCE_LOCAL_SEARCH=1`.
- The qualified AI function selects a waveform-conditioned base coefficient
  set and one of six Q2.14 seed offsets, then runs the deterministic
  1-policy + 12-perturbation + 1-final bounded search. Relative to fixed
  package-3 bounded search, mean final-cost deltas are `-89.69`, `-53.51`, and
  `-89.69` in profile/waveform/random-seed holdouts. It wins 250/288,
  160/288, and 250/288 decisions with no new modeled EVM/ACLR failure and no
  clip/saturation.
- `finalize_ai_calibration_policy.py` fail-closes unless all grouped splits
  improve mean cost and preserve the modeled constraints. It emits the final
  eight-waveform C LUT only after qualification.
- The A53 application now has `CAL_AI_POLICY_ONLY`: it looks up the embedded
  waveform, applies the AI-selected coefficient offset, forbids direct
  execution, and performs the bounded search. The direct linker now supports
  Vitis BSPs where the standalone runtime archive remains under the same
  platform's FSBL BSP rather than the application BSP `lib` directory.

Checks run:

- Full MATLAB seed/regret benchmark: passed with 1728 rows and the expected
  12 profiles, eight waveforms, three seeds, six packages, and 14-candidate
  labels.
- MATLAB P0 bit-true regression: passed for LPDSM, LPDSM2, EFDSM, EFDSM2,
  MASH11, MASH111, and MASH22; each has 65536 samples and zero mismatches.
- Python compile and finalizer self-test: passed.
- Final profile/waveform/random-seed grouped validation: passed with
  `deployment_qualified=true` for AI seed plus mandatory bounded search.
- Direct A53 build: passed; ELF size was 119264 bytes.
- J1 board replay for QAM16, 96 subcarriers, backoff 0.58: passed. The AI
  selected package 2, the trace contains exactly 14 complete records, PL proxy
  cost improved from `321062` to `311350`, and all stall/error/clip/saturation
  counters are zero.

Remaining limitations:

- This completes the software AI calibration loop, not TinyML RTL. Hardware
  inference is optional and has no current latency/area justification because
  the eight-entry software LUT is sufficient.
- Behavioral EVM/ACLR and J1 PL monitor cost are separate evidence domains.
  No physical PA, observation receiver, calibrated RF EVM, or ACLR measurement
  exists, so no real-RF linearization or certification claim is authorized.
- The one-candidate direct path remains intentionally disabled. Re-enable it
  only after new grouped evidence demonstrates a non-empty zero-violation
  region; do not relax thresholds merely to reduce candidate count.

## 2026-07-14 11:10:00 +08:00

Reason:

- Start the next AI-assisted DPD phase with package-aware seed selection and
  regret labels, while keeping the completed non-beneficial joint DSM+DPD
  selector out of deployment.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_seed_regret_benchmark.m`
- `matlab/scripts/entry_dpd_seed_regret_benchmark.m`
- `scripts/run_matlab_dpd_seed_regret_benchmark.cmd`
- `fpga/zu15eg/scripts/evaluate_seed_regret_loso.py`
- `fpga/zu15eg/scripts/generate_seed_regret_c_reference.py`
- `fpga/zu15eg/scripts/run_seed_regret_j1_replay.ps1`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/project_prospective.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The behavioral benchmark adds six deterministic Q2.14 polynomial seed
  packages without changing the fixed-point DPD datapath. A waveform/random-
  seed baseline fit supplies the shared reference seed for every PA profile,
  preventing held-PA seed-fit leakage. It is configured for
  EFDSM 1-bit (`ALGORITHM=2`), OSR 32, bypass interpolation and will generate
  1728 intended records: 12 PA/observation profiles, eight waveform conditions,
  three random seeds, and six packages. Each row captures the package's initial
  and actual one-round 14-candidate local-search cost, true best seed, regret,
  modeled RF-recovered EVM/ACLR, and first-candidate monitor state.
- The host evaluator performs independent leave-one-profile, leave-one-
  waveform, and leave-one-random-seed comparisons of fixed package 3, weighted
  k-NN seed, regret-gated direct, and unconditional local search. C-reference
  generation and the J1 replay wrapper reject execution unless all three
  simulation gates reduce candidates and retain actual direct regret plus
  modeled EVM/ACLR/clip/saturation limits. Any replay remains PL-monitor-proxy
  evidence only.

Checks run:

- Python compile and `evaluate_seed_regret_loso.py --self-test`: passed.
- PowerShell parser check for `run_seed_regret_j1_replay.ps1`: passed.
- MATLAB memory-PA smoke, full benchmark, and required P0 bit-true check:
  blocked before MATLAB script execution. `D:\MATLAB\R2025a\bin\matlab.exe`
  exits with `System Error: File system inconsistency`, including with isolated
  repository preferences and temporary directories.

Remaining limitations:

- The MATLAB behavioral results, LOSO report, C reference, and J1 replay do
  not yet exist because MATLAB cannot start. No candidate-reduction result,
  PA/RF result, board policy change, or TinyML decision is claimed.

## 2026-07-14 10:25:00 +08:00

Reason:

- Resolve the final seed-mismatch evidence gap in the joint DSM-plus-DPD LOSO
  evaluation before deciding whether to continue joint-policy optimization.

Changed files:

- `fpga/zu15eg/scripts/run_joint_seed_replay.ps1`
- `fpga/zu15eg/scripts/evaluate_joint_dsm_dpd_loso.py`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The only unvalidated held condition was EFDSM2 QAM16/BW40/backoff-0.58.
  LOSO selected polynomial mode/package `1/0`, while retained local-search
  traces used package `1/3`. A dedicated wrapper temporarily applies the
  requested package, forces bounded local search, validates the trace shape
  and safety counters, then restores the normal policy header.
- The J1 board replay produced a complete 14-record trace: policy mode/package
  `1/0`, C1/C3/C5 `0xFFF93FCD`/`0xF21A1EC1`/`0xDD023CA8`, final proxy cost
  `308660`, and zero stall/error/clip/saturation. It is stored separately from
  the paired repeat matrix under `fpga/zu15eg/out/dsm_repeat_matrix/joint_seed_replays/`.
- The LOSO evaluator now accepts explicitly supplied replay evidence and
  normalizes numeric CSV fields in its evidence key. This prevents `40` versus
  `40.0` formatting from discarding a valid board replay.
- With the replay included, all 8/8 joint actions are validated. The replay is
  `2887` proxy-cost units above the held best fixed DSM; mean joint-minus-best-
  fixed cost is `1057.25`. The current joint selector is not beneficial.

Checks run:

- Python compile and joint DSM-plus-DPD LOSO self-test: passed.
- PowerShell parser check for `run_joint_seed_replay.ps1`: passed.
- J1 XSDB target check: passed for PL, PSU, and A53.
- Board replay: passed with 14 records, mode/package `1/0`, and zero
  stall/error/clip/saturation counters.
- Joint LOSO with replay evidence: passed; 8/8 validated and 0 remaining
  board replays required.

Remaining limitations:

- This is still a nominal no-external-feedback PL monitor proxy experiment,
  not a measured PA/RF EVM/ACLR result.
- Do not optimize the current joint k-NN action selection further in isolation,
  generate deployment constants, or begin TinyML RTL. A new action formulation
  or expanded waveform/PA/DSM evidence matrix is required first.

## 2026-07-14 00:51:02 +08:00

Reason:

- Complete the planned three-repeat EFDSM and EFDSM2 board evidence matrix
  through the J1 combined JTAG/UART connection before considering a third DSM.

Changed files:

- `fpga/zu15eg/scripts/run_trace_matrix.ps1`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.ps1`
- `fpga/zu15eg/scripts/export_hw_platform.ps1`
- `fpga/zu15eg/scripts/run_repeat_policy_local_search_matrix.ps1`
- `fpga/zu15eg/scripts/build_dsm_aware_dpd_dataset.py`
- `fpga/zu15eg/scripts/analyze_dsm_dpd_repeats.py`
- `fpga/zu15eg/scripts/evaluate_joint_dsm_dpd_loso.py`
- `fpga/zu15eg/scripts/run_dsm_lp2_repeat_matrix.ps1`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- J1 was validated as the sole combined connection: its FTDI channels A-D were
  present, its UART virtual ports were COM9/COM10/COM11, and XSDB consistently
  exposed PL, PSU, and Cortex-A53 #0. J2 was not used.
- The EFDSM 1-bit (`ALGORITHM=2`) and EFDSM2 1-bit (`ALGORITHM=3`) matrices
  each contain eight QAM/bandwidth/backoff conditions with three complete
  49-candidate full-calibration traces per condition. EFDSM2 was rebuilt and
  implemented before collection; Vivado completed bitstream generation with
  0 errors and 0 critical warnings, and its generated XCI reads `ALGORITHM=3`.
- Each configuration also has 24 matching bounded-search traces. Every trace
  has exactly one policy record, 12 search records, and one final record;
  all recorded stall, error, clip, and saturation counters are zero.
- The repeat-aware builder produced 48 DSM-aware DPD rows. EFDSM2 minus
  EFDSM mean bounded-local PL proxy cost is `-969.33`, but the 95% paired CI
  is `-3457.07` to `1518.40` and EFDSM2 wins only 3/8 matched conditions.
  LPDSM2 collection remains blocked by the explicit third-DSM evidence gate.
- Joint DSM-plus-DPD LOSO now validates 7/8 held waveform conditions and
  requires one seed-specific board replay. Its validated actions average
  `795.86` proxy-cost units above the best fixed DSM choice, so no joint-policy
  C constants or TinyML RTL are generated.

Checks run:

- J1 FTDI enumeration and XSDB target checks: passed for PL, PSU, and A53.
- EFDSM and EFDSM2 manifests: 24 full-calibration rows each, three rows for
  every one of eight conditions.
- EFDSM and EFDSM2 bounded-search summaries: 24 rows each; all 48 traces pass
  14-record structure and zero stall/error/clip/saturation checks.
- EFDSM2 board implementation and hardware-platform export: passed; generated
  XCI confirms `ALGORITHM=3` and the new XSA was written at 00:32:21.
- `build_dsm_aware_dpd_dataset.py`, `analyze_dsm_dpd_repeats.py`, and
  `evaluate_joint_dsm_dpd_loso.py` against the repeated board data: passed.

Remaining limitations:

- Costs remain internal PL monitor proxies, not external PA/RF EVM, ACLR, or
  spectrum-mask measurements. The common nominal no-external-feedback profile
  does not establish unknown-PA generalization.
- The candidate DSM does not satisfy the configured paired stability gate, and
  joint LOSO is not better than the best fixed DSM. Retain policy selection in
  Python/PS and do not begin TinyML RTL or third-DSM collection from this data.

## 2026-07-13 23:26:00 +08:00

Reason:

- Resume repeat collection through the intended J1 combined JTAG/UART path
  after a board power cycle, and correct a recovery-path programming error.

Changed files:

- `fpga/zu15eg/scripts/run_trace_matrix.ps1`
- `docs/UPDATE_LOG.md`

Implementation notes:

- A completed manifest entry no longer sets the in-memory `programmed` flag.
  After a board reset or power cycle, the first missing trace must explicitly
  program the PL bitstream; only a bitstream programmed during the current
  collector invocation permits subsequent `-SkipProgram` launches.
- J1 was re-enumerated as FTDI `VID_0403&PID_6011` with USB Serial Converter
  channels A-D and COM9/COM10/COM11. XSDB initially recovered PL, PSU, and
  Cortex-A53 #0 targets. The EFDSM `qam16/bw20/backoff-0.58` condition reached
  three registered full-calibration repeats; `qam16/bw20/backoff-0.70` remains
  at two registered repeats.

Checks run:

- PowerShell parser check for `run_trace_matrix.ps1`: passed.
- J1 XSDB target check after power cycle: passed for PL, PSU, and A53 #0.
- The first missing-configuration invocation reported `PROGRAM_BIT=1`,
  confirming that the corrected recovery path reprograms the PL.

Remaining limitations:

- The current continuation did not complete another trace. One launch found
  an empty trace buffer after a former no-program recovery attempt; after the
  PL was reprogrammed, a later A53 download failed with `EDITR timeout`.
  The JTAG target tree remains visible, but the processor debug transport is
  not currently reliable enough for safe trace collection.
- No incomplete trace was appended to the manifest. Recover the A53 debug
  transport with a clean board power cycle before resuming the repeat matrix.

## 2026-07-13 20:14:02 +08:00

Reason:

- Complete the repeat-aware evidence path required before evaluating a joint
  DSM-plus-DPD selector or collecting a third DSM configuration.

Changed files:

- `fpga/zu15eg/scripts/prepare_dsm_repeat_manifest.py`
- `fpga/zu15eg/scripts/run_repeat_policy_local_search_matrix.ps1`
- `fpga/zu15eg/scripts/build_dsm_aware_dpd_dataset.py`
- `fpga/zu15eg/scripts/analyze_dsm_dpd_repeats.py`
- `fpga/zu15eg/scripts/evaluate_joint_dsm_dpd_loso.py`
- `fpga/zu15eg/scripts/run_dsm_lp2_repeat_matrix.ps1`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The retained EFDSM and EFDSM2 first-capture data are normalized into
  repeat-aware manifests. Each full/local pair is linked by its exact
  full-calibration trace path; repeat rows retain an independent `run_id`.
- The repeat collector resumes without duplicating existing full traces and
  records only complete 14-record bounded-search traces: one policy record,
  12 local-search records, and one final record. It rejects nonzero stall,
  error, clip, or saturation counters.
- Paired statistics report condition means, sample standard deviations, 95%
  paired confidence intervals, and paired win rate. The initial one-repeat
  data report EFDSM2-minus-EFDSM mean local proxy cost `-998.38`, CI
  `-3437.97` to `1441.22`, and EFDSM2 win rate `0.375`; the third-DSM gate is
  therefore correctly `0`.
- The joint waveform LOSO evaluator selects DSM configuration, polynomial DPD
  seed, and direct versus 14-candidate bounded search from waveform metadata
  plus first-candidate PL monitor state. It validates a held local-search cost
  only when the selected seed exactly matches the measured held trace. Initial
  replay validates 5/8 conditions, requires 3 seed-specific board replays,
  and is not better than the best fixed DSM result (`363.6` mean cost gap).
- LPDSM2 1-bit (`ALGORITHM=1`, OSR 32, bypass interpolation) is the prepared
  third DSM configuration. Its collection entry point refuses to build or
  collect until all repeat-stability criteria pass; no multibit MASH result is
  substituted for this controlled comparison.

Checks run:

- Python compile and self-tests for repeat-manifest preparation, repeat
  statistics, and joint DSM-plus-DPD LOSO: passed.
- PowerShell parser checks for the repeat bounded-search collector and LPDSM2
  collection wrapper: passed.
- `run_dsm_lp2_repeat_matrix.ps1 -SkipBitstreamBuild -SkipXsaExport
  -SkipProgram`: correctly blocked by the failed repeat-stability gate.
- `D:\\Xilinx\\Vitis\\2024.1\\bin\\xsdb.bat
  .\\fpga\\zu15eg\\scripts\\xsdb_require_targets.tcl`: blocked; `hw_server`
  starts but detects no usable ZU15EG PL, PSU, or A53 JTAG target.
- `git diff --check`: no diff-content errors; pre-existing line-ending
  warnings remain.

Remaining limitations:

- The required second and third repeats for each of the eight EFDSM and
  EFDSM2 conditions were not captured because the JTAG target is currently
  invisible to XSDB and Vivado Hardware Manager. No incomplete trace row was
  added and no simulated data replaced the missing board evidence.
- These data remain internal PL monitor proxy costs, not PA/RF EVM, ACLR, or
  spectrum-mask measurements. Do not generate joint-policy C constants or
  TinyML RTL until repeat evidence and seed-specific held-condition replays
  establish a real decision benefit.

## 2026-07-13 17:05:00 +08:00

Reason:

- Collect the first matched second DSM configuration so the AI-assisted DPD
  data set can compare DSM-plus-DPD conditions instead of holding DSM constant.

Changed files:

- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.ps1`
- `fpga/zu15eg/scripts/rebuild_dsm_board_bitstream.tcl`
- `fpga/zu15eg/scripts/capture_calibration_trace.ps1`
- `fpga/zu15eg/scripts/run_trace_matrix.ps1`
- `fpga/zu15eg/scripts/run_policy_local_search_matrix.ps1`
- `fpga/zu15eg/scripts/run_dsm_ef2_matrix.ps1`
- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/scripts/build_dsm_aware_dpd_dataset.py`
- `fpga/zu15eg/trace_sets/manifest_template.csv`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Selected EFDSM2 1-bit (`ALGORITHM=3`) as the controlled second build. It
  preserves OSR 32, bypass interpolation, fixed Fs/4 DUC, waveform generation,
  DPD frontend, and board cost flow, changing only the DSM loop order from the
  EFDSM 1-bit baseline.
- Board rebuild now accepts explicit `ALGORITHM` and `INTERP_MODE` parameters.
  Trace manifests carry DSM configuration ID, algorithm, quantizer bits,
  interpolation mode, and OSR. The dataset builder can join multiple manifest/
  local-search-summary pairs and rejects duplicate configuration/scenario rows.
- The EFDSM2 run contains eight full 49-candidate calibration traces plus eight
  measured policy/local-search traces. Each bounded trace has 14 rows (one
  policy, 12 search, one final) with zero stall/error/clip/saturation.
- The bounded 14-candidate experiment is polynomial-only because its local
  perturbation implementation operates on C1/C3/C5. A LOSO policy selects the
  best available polynomial seed from the other seven same-DSM traces. LUT
  packages remain in the corresponding 49-candidate full-search labels.
- The combined data set now has 16 rows and two DSM configurations. Across the
  eight matched waveform rows, EFDSM2 minus EFDSM mean bounded-final proxy-cost
  delta is `-998.38`; full-search-final delta is `-1093.00`. EFDSM2 is lower on
  4/8 bounded rows. This is exploratory internal PL monitor-cost evidence only.

Checks run:

- PowerShell parser checks for the changed board/collection scripts: passed.
- `python -m py_compile fpga/zu15eg/scripts/train_dpd_trace_policy.py`
  and `build_dsm_aware_dpd_dataset.py`: passed.
- `python fpga/zu15eg/scripts/train_dpd_trace_policy.py --self-test` and
  `build_dsm_aware_dpd_dataset.py --self-test`: passed.
- EFDSM2 IP packaging and full ZU15EG implementation: passed. Synthesis had
  0 errors/0 critical warnings; routed estimate `WNS=2.113 ns`; bitstream
  generation completed with 0 errors.
- JTAG target scan: passed. The rebuilt board IP instance and generated XCI
  read `ALGORITHM=3`.
- Eight EFDSM2 full-calibration and eight bounded local-search board runs:
  passed with complete JTAG trace buffers.
- Multi-manifest DSM-aware builder: passed; wrote 16 local ignored rows with
  two DSM configurations under `fpga/zu15eg/out/dsm_aware_dataset/`.

Remaining limitations:

- This experiment uses one nominal no-external-feedback board profile, one
  capture per condition, and PL monitor proxy costs. It does not measure PA,
  RF EVM, ACLR, spectral mask, or unknown-condition generalization.
- Two DSM configurations and eight matched waveforms are not sufficient for a
  deployable joint DSM/DPD predictor. Do not generate C policy constants or
  TinyML RTL from this result; add repeated captures and a third documented
  DSM configuration before held-condition evaluation.

## 2026-07-13 16:00:49 +08:00

Reason:

- Establish a reproducible DSM-aware data contract before attempting a learned
  search-benefit model or any joint DSM-plus-DPD policy.

Changed files:

- `fpga/zu15eg/scripts/build_dsm_aware_dpd_dataset.py`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The host builder joins each retained 49-candidate calibration trace with its
  measured 14-record policy/local-search trace. It rejects traces without one
  policy row, 12 search rows, one final row, or with nonzero stall, error,
  clip, or saturation counters.
- Dataset rows preserve waveform/PA and DSM build provenance, first-policy DPD
  package/coefficient words, all 12 policy monitor fields, and the labels
  `policy_cost`, `local_search_final_cost`, `full_search_final_cost`,
  `search_benefit`, and `local_search_gap_to_full`.
- The generated local dataset contains eight valid rows. Bounded local search
  improves PL proxy cost by 822 to 1473 (mean 1213.25) relative to the measured
  first policy candidate. It uses 14 rather than 49 candidates. These numbers
  are not external RF EVM/ACLR measurements.
- All rows carry the same board-build DSM provenance: EFDSM 1-bit
  (`ALGORITHM=2`), interpolation mode 0, OSR 32. The feature report correctly
  marks DSM fields as constants and reports nonconstant correlations only as
  exploratory small-sample results.

Checks run:

- `python .\fpga\zu15eg\scripts\build_dsm_aware_dpd_dataset.py --self-test`:
  passed.
- `python -m py_compile .\fpga\zu15eg\scripts\build_dsm_aware_dpd_dataset.py`:
  passed.
- DSM-aware builder against the retained manifest and policy-local-search
  summary: passed; wrote eight ignored local rows under
  `fpga/zu15eg/out/dsm_aware_dataset/`.

Remaining limitations:

- Eight rows are insufficient for a deployable search-benefit predictor.
- One DSM configuration cannot answer whether joint DSM-plus-DPD selection
  beats DPD-only selection. Collect matched waveform/PA conditions across at
  least one additional DSM configuration before fitting a joint model.
- No regret-predictor C constants, board-policy update, RTL, MATLAB algorithm,
  or RF-quality claim is generated by this host-only evidence step.

## 2026-07-13 15:18:46 +08:00

Reason:

- Measure the actual board cost of the 14-candidate bounded local-search branch
  for all retained waveform conditions after the behavioral regret replay
  requested fallback for every trace.

Changed files:

- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/scripts/run_policy_local_search_matrix.ps1`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `CAL_FORCE_POLICY_LOCAL_SEARCH=1` is a compile-time test-only override for
  `CAL_TRACE_POLICY_ONLY=1`. It preserves the existing generated static
  polynomial policy mode/package as candidate one, labels the guard reason
  `forced_local_search`, and executes the existing one-round 12-perturbation
  local search plus final replay.
- The matrix runner rebuilds the deterministic Q1.15 waveform for each of the
  eight retained QAM/bandwidth/backoff conditions, captures JTAG trace buffers,
  and accepts only 14-record traces (one policy, 12 search, one final). It
  neither reads nor creates a regret-predictor header or C constants.

Checks run:

- PowerShell parser check for `run_policy_local_search_matrix.ps1`: passed.
- XSDB target scan: passed; PL, PSU, and Cortex-A53 #0 were present.
- Direct A53 build with `CAL_TRACE_POLICY_ONLY=1`,
  `CAL_FORCE_POLICY_LOCAL_SEARCH=1`, and `CAL_USE_SOFTWARE_SEED=0`: passed,
  with existing BSP duplicate-macro warnings.
- Eight actual JTAG policy-local-search runs completed. Each trace has exactly
  14 records and every trace record has zero stall, sticky error, clip, and
  saturation.
- Measured policy-to-local-search cost improvement is 822 to 1473 (mean
  `1213.25`). Each bounded run uses 14 rather than 49 candidates, reducing
  candidates by 35. The mean bounded-final to retained full-calibration-final
  cost gap is `957.12`; the QAM64/BW40/backoff-0.58 result is `77` above full
  search. Evidence CSVs are local ignored artifacts under
  `fpga/zu15eg/out/policy_local_search_matrix/`.
- `git diff --check`: passed, apart from pre-existing line-ending warnings.

Remaining limitations:

- The 14-candidate measurement validates bounded fallback from the existing
  static board trace policy, not a direct decision made by the behavioral
  regret predictor. All eight regret replay inputs remained out of its modeled
  feature distribution.
- This remains PL proxy-cost evidence. There is no external PA/receiver EVM or
  ACLR measurement, no PA-profile variation, and no authorization to generate
  or deploy regret-predictor C constants.

## 2026-07-13 15:02:00 +08:00

Reason:

- Replay the behavioral first-candidate regret policy against retained JTAG
  traces using a C-friendly fixed-point implementation before considering any
  board policy constants.

Changed files:

- `fpga/zu15eg/scripts/replay_sim_regret_policy.py`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The offline replay uses Q20 feature ratios, median/IQR normalization,
  integer Euclidean distance, inverse-distance weighted five-neighbor regret,
  and integer standard deviation. It consumes first-candidate package monitor
  values from each held JTAG full-calibration trace.
- It reproduces the behavioral operating rule: upper regret at most 100,
  nearest feature distance at most 100000 ppm, and zero
  stall/error/clip/saturation. The output always sets
  `header_update_allowed=0`.
- A direct decision has a retained one-candidate cost available for comparison
  to the trace's full-search final cost. A local-search decision is explicitly
  marked `board_replay_required=1`: a historical 49-candidate calibration does
  not measure the planned 14-candidate policy branch.

Checks run:

- `python fpga/zu15eg/scripts/replay_sim_regret_policy.py --self-test`:
  passed.
- `python -m py_compile fpga/zu15eg/scripts/replay_sim_regret_policy.py`:
  passed.
- Eight-trace offline replay with regret budget 100, feature-distance limit
  100000 ppm, and five neighbors: 0 direct, 8 local-search, 112 modeled
  candidates, and 8 required future policy-only board replays. Nearest feature
  distances span 69688870 to 97544953 ppm; no header update is permitted.
- Distance-limit diagnostic: with the distance limit removed, only one trace
  becomes direct. Its retained one-candidate cost is 2577 above its recorded
  full-search final cost, so the diagnostic does not justify relaxing the
  in-distribution rejection.

Remaining limitations:

- The behavior-level and board monitor distributions differ materially. The
  predictor correctly falls back but has no validated board direct path yet.
- The Q20 Python calculation is a deployment-design reference, not a generated
  C implementation or board measurement. Do not add its constants to
  `dpd_trace_policy.h` until new policy-only 14-candidate replays and repeated
  multi-condition board data exist.

## 2026-07-13 14:49:06 +08:00

Reason:

- Change behavioral AI policy evaluation from static monitor similarity to a
  first-candidate cost-regret decision: skip local search only when its
  predicted benefit is within a documented cost budget.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_pa_robustness_sweep.m`
- `matlab/scripts/entry_dpd_pa_robustness_sweep.m`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The memory-PA observation sweep now retains the first polynomial candidate's
  12 monitor fields in addition to the optimized candidate fields.
- The robustness sweep labels each sample with `initial_cost`, optimized
  local-search cost, and nonnegative `local_search_regret`; first-candidate
  monitor state is the predictor input, so it is available before choosing to
  run local search.
- A five-neighbor predictor normalizes QAM, bandwidth, subcarriers, backoff,
  and eight scale-robust monitor ratios by training-set median/IQR. Its direct
  upper estimate is prediction plus weighted-neighbor standard deviation.
- The documented operating point requires upper regret at most `100` cost
  units, nearest normalized feature distance at most `100000 ppm`, and zero
  clip/saturation. Board stall/error/clip/saturation checks remain mandatory
  independent fallback conditions; no generated board policy header changed.

Checks run:

- `scripts/run_matlab_dpd_pa_robustness_sweep.cmd`: passed.
- Generated 288 samples, 12 held PA-profile summaries, and 288 individual
  regret decisions. Regression assertions verify all direct decisions use one
  candidate or local search uses 14, and every direct decision's actual regret
  is within both its 100-cost budget and 100000-ppm distance bound.
- Held-profile result: 36 direct and 252 local-search decisions; 3564 modeled
  candidate evaluations versus 4032 with unconditional local search, saving
  468 (11.6%). Direct actual regret averages `26.61` and reaches `98`.
- `git diff --check`: passed, apart from pre-existing line-ending warnings.

Remaining limitations:

- This is behavioral MATLAB evidence using a one-round coordinate search as
  the 14-candidate local-search analogue. It does not estimate a physical PA,
  calibrated receiver EVM/ACLR, or a multi-round board search outcome.
- Some low-regret direct samples still fail the modeled RF feedback condition.
  Regret controls computational cost only; external RF feedback and hard board
  faults remain separate constraints.
- Do not move the 100-cost or 100000-ppm values into `dpd_trace_policy.h`
  without retained multi-condition board traces and a board-side implementation
  of the same normalized predictor.

## 2026-07-13 13:58:42 +08:00

Reason:

- Expand the behavioral PA/observation evidence matrix, evaluate a
  feature-weighted monitor gate, and test its compatibility with retained JTAG
  traces without conflating simulated and board evidence.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_pa_robustness_sweep.m`
- `matlab/scripts/entry_dpd_pa_robustness_sweep.m`
- `fpga/zu15eg/scripts/replay_sim_monitor_gate.py`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The behavioral sweep now covers QAM16/QAM64, 20/40 MHz occupancy, and
  0.58/0.70 input backoff. Its receiver bandwidth is derived per occupancy so
  the 40 MHz scenarios are not evaluated through the former fixed 24 MHz
  receive filter.
- The robustness matrix uses 12 PA/observation profiles: gain, saturation,
  memory depth, observation noise, gain/phase drift, and combined stress.
- The monitor gate now uses scale-robust, feature-weighted ratios for gain,
  peak/average shape, correction, spectral shape, clip, and saturation,
  instead of an equal average of raw monitor magnitudes.
- `replay_sim_monitor_gate.py` replays candidate simulation thresholds against
  a manifest of retained full-calibration JTAG traces. It always writes
  `header_update_allowed=0` and never creates or changes
  `dpd_trace_policy.h`.

Checks run:

- `scripts/run_matlab_dpd_pa_robustness_sweep.cmd`: passed.
- Generated `288` behavioral records: 12 profiles, 8 waveform conditions,
  and seeds `41`, `53`, and `67`; `198` meet and `90` fail the modeled EVM/ACLR
  limits. Each leave-one-profile split trains on 264 records and holds 24.
- Legacy and weighted-monitor gates each directly accept zero held modeled
  failures and two held modeled passes. This is safe but too selective to
  claim a useful deployment tolerance.
- `python fpga/zu15eg/scripts/replay_sim_monitor_gate.py --self-test`:
  passed.
- `python fpga/zu15eg/scripts/calibrate_dpd_policy_thresholds.py --self-test`:
  passed.
- `python -m py_compile fpga/zu15eg/scripts/replay_sim_monitor_gate.py
  fpga/zu15eg/scripts/calibrate_dpd_policy_thresholds.py`: passed.
- `scripts/run_matlab_p0_bittrue_check.cmd`: passed. LPDSM, LPDSM2, EFDSM,
  EFDSM2, MASH11, MASH111, and MASH22 each compared 65536 samples with zero
  mismatches.
- Offline JTAG replay with the minimum (`3740883 ppm`), median (`40286636
  ppm`), and maximum (`57943174 ppm`) behavioral tolerances: all eight nominal
  board traces take the one-candidate direct branch. For each strategy, their
  mean recorded policy-to-full-search cost delta is `2170.38` and maximum is
  `3113`; no header update is allowed.
- `git diff --check`: passed, apart from pre-existing line-ending warnings.

Remaining limitations:

- The behavioral monitor proxies are not a physical PA or calibrated receiver.
  The retained board traces use one nominal no-external-feedback profile, so
  they cannot validate PA-profile generalization.
- The tested simulation tolerances are compatible with the retained traces but
  do not improve their recorded full-search cost. The existing board policy
  header remains unchanged.
- Real PA/receiver feedback remains optional hardware evidence. When available,
  use `rf_feedback_manifest_template.csv`,
  `rf_feedback_measurement_template.csv`, and
  `calibrate_dpd_policy_thresholds.py`; do not manufacture measurement rows.

## 2026-07-13 12:45:00 +08:00

Reason:

- Map the behavioral memory-PA study onto the monitor-state inputs already
  consumed by the runtime DPD policy, then evaluate the gate with seven-profile
  leave-one-profile splits.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_pa_robustness_sweep.m`
- `matlab/scripts/entry_dpd_pa_robustness_sweep.m`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The behavioral PA sweep now emits input/output power, packed peak/average
  magnitude, EVM/ACPR, three fixed-bin/adjacent spectral, clip, and saturation
  proxies for the optimized polynomial DPD path.
- Input-side proxy operations mirror the PL Q1.15 L1 magnitude, clipping, and
  correction definitions. Saturation is the Q1.15 DPD output-limit event, not
  a PA soft-saturation counter. Output-related proxies use the post-PA complex
  behavioral observation and are explicitly not RTL DSM bit-true values.
- The robustness sweep writes `dpd_pa_monitor_gate_loso.csv`; for each held PA
  profile it fits the legacy three-factor gate on the other six profiles,
  derives a passing-state monitor center/tolerance, and reports legacy versus
  monitor-gated false/true direct decisions.
- The Q1.15 proxy keeps I/Q as an integer struct. The output monitor now reads
  its integer I field directly; applying `real()` to that struct was corrected
  before the final regression run.
- Gate fitting now requires at least one training passing direct decision when
  comparing useful direct-policy behavior, rather than treating an always-search
  gate as a successful zero-false-direct solution.

Static checks:

- `git diff --check`: passed (only existing line-ending warnings).
- Static MATLAB structure count: balanced `function`/`end` lines in both
  modified MATLAB functions.

Checks run:

- `scripts/run_matlab_dpd_pa_robustness_sweep.cmd`: passed after correcting a
  monitor-proxy type error.
- Generated `63` behavioral records: seven PA profiles, three waveform
  sources, and seeds `41`, `53`, and `67`.
- Seven leave-one-PA-profile splits each trained on `54` rows and evaluated
  `9` held rows. The legacy gate directly accepted `23` simulated failures and
  one held passing row; the monitor-state gate directly accepted zero failures
  and retained the same one held passing row.
- Output artifacts: `matlab/out/dpd/dpd_pa_robustness_simulation.csv`,
  `matlab/out/dpd/dpd_pa_monitor_gate_loso.csv`, and
  `matlab/out/dpd/dpd_pa_robustness_simulation.md`.

Remaining limitations:

- The monitor gate is conservative and currently preserves too few direct
  paths to replace the board policy tolerance. It remains behavioral
  simulation evidence, is not RTL DSM bit-true or RF feedback evidence, and
  is not copied into the generated board header.

## 2026-07-13 00:15:00 +08:00

Reason:

- Upgrade policy confidence from scenario/cost-only gating to include existing
  PL monitor-state observations.

Changed files:

- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_trace_policy.h`
- `fpga/zu15eg/baremetal/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Host policy generation now builds a weighted selected-package monitor center
  from input/output power, peak, average magnitude, EVM/ACPR proxies, three
  fixed bins, adjacent proxy, clip, and saturation. It derives the default
  mean-relative-distance tolerance from retained observations plus `50000 ppm`.
- The bare-metal first replay computes the same integer-only 12-feature
  distance. Distance above the generated limit produces
  `CAL_POLICY_RUNTIME_GUARD ... reason=monitor_distance` and runs the bounded
  polynomial fallback. Clip was added to the immediate monitor-fault path.

Checks run:

- Python syntax and monitor-aware policy self-test: passed.
- A53 monitor-aware policy ELF build: passed, with existing generated-BSP
  duplicate-macro warnings.
- J1 JTAG policy replay: passed. One complete trace record at cost `296375`;
  offline recomputation gives monitor distance `252573 ppm` below the generated
  `792666 ppm` limit; stall/error/clip/saturation were zero.

Remaining limitation:

- The monitor center and tolerance use only the nominal board trace matrix.
  The behavioral PA robustness matrix has not yet emitted matching PL-proxy
  features, so this proves state-feature plumbing and safe fallback behavior,
  not unknown-PA separation or RF safety certification.

## 2026-07-12 23:55:00 +08:00

Reason:

- Stress-test policy-gate stability over a broader behavioral PA and
  observation-model space.

Changed files:

- `matlab/dpd/run_dpd_memory_pa_observation_sweep.m`
- `matlab/dpd/run_dpd_pa_robustness_sweep.m`
- `matlab/scripts/entry_dpd_pa_robustness_sweep.m`
- `scripts/run_matlab_dpd_pa_robustness_sweep.cmd`
- `fpga/zu15eg/scripts/calibrate_dpd_policy_thresholds.py`
- `fpga/zu15eg/trace_sets/README.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The seven named profiles vary PA gain, saturation point, memory taps,
  observation SNR, and gain/phase drift. Each profile runs nominal and strong
  16-QAM sources plus a 64-QAM wideband source for seeds `41`, `53`, and `67`.
- The predictor intentionally excludes hidden PA profile fields. The evaluator
  now reports a usable strict gate separately from an explicitly non-separable
  least-risk tradeoff, and supports leave-one-PA-profile evaluation.

Checks run:

- MATLAB robustness sweep: passed; `63` records, `21` scenarios, `7` PA
  profiles, `3` repeats each, `43` simulated failures.
- Python calibration self-test: passed.
- Full matrix and every leave-one-profile fit: `simulation_gate_not_separable`.
  The best nonempty tradeoff accepted `2` passing and `22` failing runs; do not
  deploy its ppm values.

Remaining limitation and next action:

- The current three gate features cannot distinguish all simulated PA changes.
  Keep the board's existing `15%` engineering residual guard. Add the already
  available PL monitor state (power, peak/average magnitude, EVM/ACPR, and
  spectral proxies) to the confidence predictor before another threshold fit.

## 2026-07-12 23:13:00 +08:00

Reason:

- Replace unavailable physical second-PA and receiver collection with a
  repeatable memory-PA/observation simulation for policy-gate calibration.

Changed files:

- `matlab/dpd/run_dpd_policy_threshold_simulation.m`
- `matlab/scripts/entry_dpd_policy_threshold_simulation.m`
- `scripts/run_matlab_dpd_policy_threshold_simulation.cmd`
- `fpga/zu15eg/scripts/calibrate_dpd_policy_thresholds.py`
- `fpga/zu15eg/trace_sets/README.md`
- `fpga/zu15eg/README.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The MATLAB flow reuses `run_dpd_memory_pa_observation_sweep` for nominal and
  strong PA profiles plus a 64-QAM wideband diagnostic condition. It runs seeds
  `41`, `53`, and `67`, then performs leave-one-scenario prediction to emit
  predicted cost, measured simulated cost, distance, dispersion, residual, and
  RF-recovered EVM/ACLR pass/fail records.
- The Python calibrator now accepts this simulation-feedback CSV and labels
  its output `simulation_calibrated_not_rf_certified`. It does not modify
  `dpd_trace_policy.h`.

Checks run:

- MATLAB simulation generator: passed; 9 records, 3 scenarios, 2 PA strengths,
  and 3 repeats per scenario.
- Simulation gate calibration: passed with 4 simulated failures and no false
  acceptance. Suggested simulation-only limits are distance `1000000 ppm`,
  dispersion `941856 ppm`, and residual `746780 ppm`.

Remaining limitation:

- This is behavioral MATLAB evidence, not board feedback or RF measurement.
  The broad simulated limits are retained for analysis only. The generated
  bare-metal policy continues to use its existing `15%` runtime engineering
  default and is not RF safety certified.

## 2026-07-12 22:35:00 +08:00

Reason:

- Prepare repeatable second-PA and true-feedback collection for calibration of
  policy distance, dispersion, and runtime-residual gates.

Changed files:

- `fpga/zu15eg/scripts/calibrate_dpd_policy_thresholds.py`
- `fpga/zu15eg/scripts/run_trace_matrix.ps1`
- `fpga/zu15eg/trace_sets/rf_feedback_manifest_template.csv`
- `fpga/zu15eg/trace_sets/rf_feedback_measurement_template.csv`
- `fpga/zu15eg/trace_sets/README.md`
- `fpga/zu15eg/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The new calibrator joins policy prediction CSVs, JTAG policy traces, and
  independent receiver measurements by scenario/run ID. It selects ppm limits
  that avoid accepting recorded feedback failures while retaining measured-good
  runs, and never rewrites a generated policy header.
- The workflow requires two PA strengths, at least two repeats per scenario,
  receiver identity/calibration provenance, and numeric EVM, ACLR, receive
  power, timestamp, and pass/fail fields. Missing coverage or incomplete
  feedback data is rejected.
- The trace-matrix script now gives non-nominal PA profiles/strengths unique
  scenario IDs and supports repeated full-calibration runs.

Checks run:

- Python syntax and RF-feedback threshold-calibration self-test: passed.
- PowerShell parser validation for `run_trace_matrix.ps1`: passed.
- `git diff --check`: passed.

Remaining limitation:

- No second controlled PA setting or external feedback receiver is currently
  connected: the host exposes only Bluetooth serial ports, not the prior board
  UART. No RF trace was fabricated or registered. The existing `15%` runtime
  residual limit remains an engineering default, not an RF safety-certified
  threshold.

## 2026-07-12 22:24:00 +08:00

Reason:

- Add post-measurement runtime safety fallback to the confidence-gated DPD
  policy.

Changed files:

- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_trace_policy.h`
- `fpga/zu15eg/baremetal/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The generated policy now carries a maximum runtime cost-residual threshold;
  the default is `150000 ppm` (`15%`). Bare-metal code computes absolute
  measured/predicted residual with 64-bit integer arithmetic.
- The first policy measurement keeps DMA and sample-count checks strict but
  captures stall, sticky error, and saturation for the runtime decision. Any
  nonzero safety counter or excessive residual forces bounded local search.
  Existing smoke and full-calibration paths retain strict counter checks.
- A safety-triggered non-polynomial policy fails explicitly because the current
  bounded fallback supports polynomial coefficients only.

Checks run:

- Python syntax and confidence/runtime-gate self-test: passed.
- LOSO evaluator self-test and MATLAB P0 bit-true check: passed.
- Direct A53 build with the default residual threshold: passed with existing
  generated-BSP duplicate-macro warnings.
- J1 default-threshold run: passed. Static gate was direct; measured cost was
  `296375`; residual was `110439 ppm` against `150000 ppm`; stall, error, and
  saturation were zero. JTAG trace had one complete record and no overflow.
- J1 runtime-fallback run with only the residual threshold changed to
  `100000 ppm`: passed. UART reported `reason=cost_residual`; JTAG trace had
  14 complete records and no overflow; final cost was `294902`; all safety
  counters were zero.

Interpretation and remaining limitations:

- Both runtime residual branches are measured on the board. The monitor-fault
  branch is implemented but was not fault-injected because the healthy board
  produced zero stall/error/saturation.
- Policy reports distinguish the nominal candidate count from the maximum
  runtime-guarded count; a statically trusted polynomial policy is nominally
  one candidate but can expand to 14 records after its first measurement.
- The `15%` default is an engineering guard, not a calibrated RF safety limit.
  Repeated captures under a second controlled PA strength and real feedback
  condition are required to calibrate residual, distance, and dispersion
  thresholds.

## 2026-07-12 22:15:00 +08:00

Reason:

- Add confidence/uncertainty gating to the held-out DPD policy and bound the
  cost of fallback search in line with `docs/PROJECT_PROSPECTIVE.md` Phase 3.

Changed files:

- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/README.md`
- `docs/PROJECT_PROSPECTIVE.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The predictor now computes nearest scenario distance, weighted selected-action
  cost standard deviation, and relative standard deviation. Generated headers
  store all gate metrics and thresholds as integer ppm values.
- Default thresholds are distance `0.20` and relative cost dispersion `0.10`.
  Trusted conditions execute one package candidate. Untrusted polynomial
  conditions execute one policy candidate, one 12-perturbation coordinate
  round, and one final replay.
- Full calibration retains its existing three-round coarse-to-fine search. The
  new bounded search is used only by the policy fallback path.

Checks run:

- Python syntax and policy confidence-gate self-test: passed.
- Manifest-held-out generation with default thresholds: `direct`, nearest
  distance `171429 ppm`, relative cost standard deviation `53282 ppm`, one
  planned candidate, and candidate reduction 48.
- The same held-out condition with distance limit `100000 ppm`:
  `local_search`, 14 planned records, and candidate reduction 35.
- Direct A53 build and J1 board run: passed. UART reported
  `CAL_POLICY_GATE decision=direct`; JTAG trace contained one policy record at
  cost `296375`, with no search/final records and no overflow.
- Fallback A53 build and J1 board run: passed. JTAG trace contained 1 policy,
  12 search, and 1 final record (`count=14`, `complete=1`, `overflow=0`). The
  fallback improved cost from `296375` to `294902`; stall, error, clipping, and
  saturation remained zero.

Interpretation and remaining limitations:

- The bounded fallback closes most of the gap to the retained 49-candidate
  final cost `294825` while evaluating 35 fewer candidates.
- Current thresholds are engineering defaults derived from one nominal PA
  waveform matrix. A second controlled PA strength and feedback receiver are
  still required before treating the gate as RF confidence.
- The next safety increment is a run-time fallback trigger for monitor faults
  and large measured-versus-predicted residuals.

## 2026-07-12 22:00:00 +08:00

Reason:

- Move the eight-condition AI/DPD policy from offline LOSO evaluation to a
  measured held-out board replay.
- Prevent scenario leakage when generating a policy header from a trace-set
  manifest.

Changed files:

- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_direct.ps1`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `fpga/zu15eg/README.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `train_dpd_trace_policy.py` now accepts a scenario manifest and a held-out
  scenario ID. It preserves each training trace's PA/QAM/bandwidth/subcarrier/
  backoff metadata, excludes every row for the held scenario, and filters by
  calibration profile before fitting.
- `build_baremetal_direct.ps1` now accepts explicit compile definitions so the
  reliable direct A53 build can generate `CAL_TRACE_POLICY_ONLY=1` ELFs.
- The selected test was the matrix's highest-regret LOSO condition:
  `board_nominal_qam64_bw40_bo58`. The generated policy used 84 package rows
  from the other seven scenarios and selected polynomial mode/package 3 with
  predicted cost `333170`.

Checks run:

- Python syntax check for policy/LOSO scripts: passed.
- LOSO evaluator self-test: passed.
- Manifest-aware policy generation matched the retained LOSO row exactly:
  mode/package `1/3`, predicted cost `333170`, nearest distance `0.171428571`,
  and 84 training observations.
- Direct A53 policy-only build for QAM64, 96 used subcarriers, 0.58 backoff,
  FFT256, seed101: passed with existing generated-BSP duplicate macro warnings.
- J1 JTAG launch plus COM11 capture: passed. The app evaluated one policy
  candidate, reported cost `296375`, and finished with zero stall, error,
  clipping, and saturation counters.
- JTAG memory trace export: passed with `count=1`, `complete=1`, and
  `overflow=0`. UART and JTAG both reported mode/package `1/3` and cost
  `296375`.

Interpretation and remaining limitations:

- The measured action cost exactly matches mode/package `1/3` in the original
  held trace, confirming a 49-to-1 candidate reduction on a newly executed
  held-out waveform policy path.
- Cost `296375` is `1064` above the held trace's best package and `1550` above
  its full coordinate-search final cost. The predictor overestimated measured
  cost by `36795`; future work should add calibrated uncertainty/confidence and
  fall back to a short local search for distant conditions.
- This remains one PA profile with internal PL monitor proxies. It does not
  validate unknown PA strength or RF EVM/ACLR generalization.

## 2026-07-12 21:18:00 +08:00

Reason:

- Restore the intended single-cable J1 JTAG plus UART workflow and verify the
  AI/DPD bare-metal calibration over both interfaces.

Changed files:

- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/scripts/report_ps_uart_config.tcl`
- `fpga/zu15eg/scripts/xsdb_uart0_tx_probe.tcl`
- `docs/UPDATE_LOG.md`

Checks run:

- Enabled J1 `USB Serial Converter A` through an elevated Windows device
  operation. Vivado detected `Xilinx/15051A`, `xczu15_0`, and `arm_dap_1`;
  XSDB detected PL, PSU, and Cortex-A53 #0.
- Programmed the existing DSM bitstream and launched the QAM16, 20 MHz,
  0.58-backoff full-calibration ELF through J1 JTAG.
- A direct UART0 FIFO probe identified J1 `COM11` as PS UART0 at 115200 8N1.
- Captured and parsed 49 UART calibration records plus one selected replay in
  `fpga/zu15eg/out/j1_only_uart_calibration_20260712_211633.csv`.
- Captured the completed 49-record trace through J1 JTAG in
  `fpga/zu15eg/out/j1_only_jtag_trace_20260712_211716.csv`; metadata reported
  `complete=1` and `overflow=0`.
- Final replay selected polynomial mode/package 3 with zero stall, error, and
  saturation counters. The application printed its final PASS over UART.

Debug chronology and root cause:

- With J1 and J2 attached together, Windows enumerated J1 serial ports while
  Vivado still saw the external Digilent cable, but no ZU15EG devices were
  detected behind it. Restarting `hw_server`, resetting the board, and
  disabling J1's A interface did not restore the shared JTAG chain.
- Schematic page 26 showed that J1 FTDI ADBUS0..3 and external J2 ultimately
  connect to the same Zynq TCK/TDI/TDO/TMS nets. The J2 path uses TXB0102
  translators and there is no software-controlled mux or output-enable signal,
  so using both adapters concurrently is not a supported arbitration scheme.
- With J2 removed, J1 FTDI A was found in `CM_PROB_DISABLED`. Normal device
  enable attempts failed with `Access is denied`; an elevated `pnputil`
  operation enabled it without changing the FTDI EEPROM.
- After enable, J1 appeared to Vivado as `Xilinx/15051A` and exposed the full
  ZU15EG chain. This proved that neither the FTDI EEPROM nor Xilinx cable driver
  required reprogramming.
- The schematic and both vendor/local PS configurations agree that UART0 uses
  MIO 38/39 at 115200 baud. COM-letter assumptions were nevertheless wrong: a
  direct UART0 FIFO probe sent to all three VCPs showed that this host routes
  PS UART0 to `COM11`, not `COM10`.
- The final J1-only run captured 49 UART rows and 49 memory/JTAG rows with the
  same final mode, package, and cost, closing both the JTAG and UART paths.

Remaining limitations:

- J1 and external J2 must not be used concurrently because the schematic
  connects both paths to the same Zynq JTAG nets without software-controlled
  isolation.
- COM numbering can change after driver reinstall or USB topology changes;
  rerun `xsdb_uart0_tx_probe.tcl` to identify PS UART0 when needed.

## 2026-07-12 19:48:20 +08:00

Reason:

- Collect actual ZU15EG JTAG full-calibration traces for multiple deterministic
  QAM/occupied-bandwidth/backoff waveform conditions and run a strict held-out
  policy evaluation.
- Work around a local Vitis Python application-component creation failure while
  retaining the generated XSA standalone BSP as the software source of truth.

Changed files:

- `fpga/zu15eg/baremetal/scripts/build_baremetal_direct.ps1`
- `fpga/zu15eg/scripts/run_trace_matrix.ps1`
- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/run_baremetal_smoke.tcl`
- `fpga/zu15eg/scripts/capture_calibration_trace.ps1`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `build_baremetal_direct.ps1` uses the current XSA-generated A53 standalone
  BSP, Vitis A53 GCC, and standard AMD startup objects to build a DDR-loaded
  ELF without relying on the failing Vitis application-component API. It
  generates the declared deterministic Q1.15 QAM-OFDM waveform before each
  build and disables the stale software-seed header for matrix collection.
- The collection helper executes a full calibration, waits for completion,
  exports its JTAG trace, requires package/final records before manifest
  registration, skips registered scenarios on resume, and retries a transient
  JTAG/DAP link failure after restarting local hardware services.
- Retained local evidence is under ignored
  `fpga/zu15eg/out/trace_matrix/`: eight 49-record full traces plus the clean
  eight-scenario manifest and LOSO CSV/JSON/Markdown outputs.

Checks run:

- J2 scan after terminating stale `hw_server`/`xsdb` processes: passed.
  Detected `xczu15`, PL, PSU, and Cortex-A53 #0 through `Digilent JTAG-SMT2
  D306BA2BABCD`.
- Direct A53 ELF link with the XSA-generated BSP: passed. The ELF retained
  `g_cal_trace_buffer`; compiler emitted existing duplicate `xparameters.h`
  macro warnings.
- Eight full board calibration runs: passed with trace buffer `complete=1`,
  `count=49`, and `overflow=0` per run. Each trace has 12 package rows and one
  final row.
- `evaluate_dpd_trace_loso.py` over the clean eight-scenario manifest: passed.
  Coverage: QAM `16/64`, bandwidth `20/40 MHz`, backoff `0.58/0.70`.
  Exact held-package optimum: `6/8`; mean package regret: `181.5`; mean
  candidate reduction: `48`.

Remaining limitations:

- All runs use `nominal_no_external_feedback`; no controlled second PA
  strength, PA device, RF feedback receiver, or calibrated RF metric is part
  of this evidence. It does not satisfy PA-axis generalization.
- The LOSO results are offline comparisons against full-trace package costs.
  Representative held-out one-candidate policy-only board replays still need
  to be run before claiming measured convergence reduction.
- The legacy counter checker expects `DPD_CTRL=2`; waveform full calibrations
  legitimately selected polynomial mode `DPD_CTRL=1`, so that fixed LUT-only
  expectation was not used as a pass/fail condition.

## Template

```text
Date:
Changed files:
Reason:
Checks run:
Checks not run:
Remaining limitations:
```

## 2026-07-12 16:18:31 +08:00

Reason:

- Fit a trace-aware DPD policy from retained J2 calibration history and measure
  its candidate-count, cost, and convergence behavior on ZU15EG.

Changed files:

- `fpga/zu15eg/scripts/train_dpd_trace_policy.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/scripts/capture_calibration_trace.tcl`
- `fpga/zu15eg/scripts/capture_calibration_trace.ps1`
- `fpga/zu15eg/baremetal/src/dpd_trace_policy.h`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Added a deterministic weighted k-NN policy over comparable board
  package-evaluation costs. It does not use coordinate-search rows as labels;
  when board observations are absent it falls back to MATLAB nearest neighbor.
- `CAL_TRACE_POLICY_ONLY=1` runs one generated mode/package, measures it with
  the normal DMA/PL monitor path, and publishes a `policy` trace record through
  J2. It is not a blind AXI-Lite register write.

Checks run:

- `python -m py_compile .\fpga\zu15eg\scripts\train_dpd_trace_policy.py`:
  passed.
- Direct A53 source compile with the generated standalone BSP: passed with the
  BSP's existing duplicate `xparameters.h` macro warnings.
- PowerShell parser checks for the updated build and trace-capture scripts:
  passed.
- Full-calibration training evidence:
  `fpga/zu15eg/out/calibration_trace_jtag_20260712_160349.csv`.
- The trainer selected mode 2, package 3, predicted cost `3003709`, from 12
  package-stage observations at zero scenario distance.
- Vitis policy build completed with `.buildstatus` `hw=SUCCESS` and generated
  the policy-only ELF at `2026-07-12 16:15:58 +08:00`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed through J2 only, including policy replay, counter checks, replay
  capture, and one-record JTAG trace export.
- Policy replay evidence:
  `fpga/zu15eg/out/calibration_trace_jtag_20260712_161732.csv`.
- Measured comparison: full calibration used 50 candidates and converged at
  candidate 50 with final cost `3003709`; policy replay used one candidate,
  converged at candidate 1, and measured cost `3003709` (prediction error 0).
  Final input/frontend/DPD/output counters were each `0x00001000`; stall,
  error, and DPD saturation were zero.

Remaining limitations:

- This is a same-scenario reproduction: the policy trained on the retained
  16-QAM, 48-subcarrier, 0.58-backoff trace and replayed that scenario. It is
  not a held-out generalization result or a learned PA model.
- Collect full traces across PA strength, QAM, bandwidth, backoff, and board
  conditions, then score the policy on traces excluded from training.

## 2026-07-12 10:00:00 +08:00

Reason:

- Upgrade the PS-side AI-assisted DPD control path from a host-only seed
  report to an adaptive seed that can participate in the next bare-metal
  calibration run.

Changed files:

- `fpga/zu15eg/scripts/generate_dpd_seed_table.py`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/src/dpd_seed.h`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The seed generator now accepts `--header` and produces `dpd_seed.h` with a
  selected exported package index and Q2.14 C1/C3/C5 coefficient words.
- The bare-metal build accepts `-SeedQam`, `-SeedUsedSubcarriers`, and
  `-SeedInputBackoff`; it generates and imports that header automatically.
- When enabled, the app first runs the selected seed through DMA/PL, emits a
  `CAL_TRACE` row with stage `software_seed`, and uses its measured cost as an
  initial candidate. Full polynomial/LUT package evaluation and coordinate
  search still run, so the seed is never trusted without hardware feedback.
- The checked target `16-QAM`, `48` used subcarriers, `0.58` backoff selected
  package 3, `pa_weak_16qam_48sc_bo058`, with words `0x00A24002`,
  `0xF68216A1`, and `0xF36517D0`.

Checks run:

- `python -m py_compile .\fpga\zu15eg\scripts\generate_dpd_seed_table.py .\fpga\zu15eg\scripts\parse_calibration_trace.py`:
  passed.
- `python .\fpga\zu15eg\scripts\generate_dpd_seed_table.py --qam 16 --used-subcarriers 48 --input-backoff 0.58 --header .\fpga\zu15eg\baremetal\src\dpd_seed.h`:
  passed; generated the header above.
- PowerShell parser check for `build_baremetal_smoke.ps1`: passed.
- Direct `aarch64-none-elf-gcc` compile of
  `dsm_dpd_baremetal_smoke.c` with the generated standalone BSP and seed
  header: passed. The generated BSP emitted pre-existing duplicate-macro
  warnings from `xparameters.h`.
- `git diff --check`: passed with pre-existing line-ending warnings only.

Checks not run:

- The full Vitis Python build was started with the seed arguments but did not
  produce an ELF: its local log stopped during platform creation without an
  application compiler diagnostic. It is therefore not recorded as passed.
- Board download/run and UART trace capture remain blocked because XSDB still
  detects no JTAG target.

Remaining limitations:

- This is a deterministic nearest-neighbor control seed, not a trained neural
  PA model, and its latest behavior has not yet been measured on the board.
- The adaptive policy still relies on MATLAB proxy data and PL monitor proxies;
  real RF EVM/SNDR/ACLR feedback requires an observation receiver.

## 2026-07-12 15:31:21 +08:00

Reason:

- Restore a stable external J2 JTAG path and run the newly generated adaptive
  DPD seed ELF on the ZU15EG board.

Changed files:

- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation and hardware notes:

- With J1 disconnected, J2 enumerated as `Digilent JTAG-SMT2 D306BA2BABCD`
  and exposed PS TAP, PMU, PL, PSU, RPU, APU, and all four Cortex-A53 targets.
- The build generated package-3 seed words for the 16-QAM, 48-subcarrier,
  0.58-backoff target: C1 `0x00A24002`, C3 `0xF68216A1`, and C5
  `0xF36517D0`.
- The resulting ELF timestamp was `2026-07-12 15:28:35 +08:00`; binary string
  inspection confirmed `CAL_SEED_CONFIG`, `software_seed`, and
  `CAL_USE_SOFTWARE_SEED 1U` were included.
- The completed calibration retained LUT mode (`DPD_CTRL=0x00000002`). The
  polynomial coefficient registers contain the last searched polynomial state
  and are not the active LUT configuration.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1 -SeedQam 16 -SeedUsedSubcarriers 48 -SeedInputBackoff 0.58`:
  generated the seed and built
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
  The Vitis launcher returned before printing its final wrapper message, so
  ELF timestamp and binary contents were checked explicitly.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed. It programmed PL, initialized PS, downloaded and started the adaptive
  ELF, checked counters, and captured replay CSV.
- Final replay evidence:
  `fpga/zu15eg/out/dsm_replay_counters_20260712_153045.csv`.
- Counter result: input/frontend/DPD/output all `0x00001000`, input stall
  `0x00000000`, error status `0x00000000`, DPD saturation `0x00000000`, and
  final `DPD_CTRL=0x00000002`.

Checks not run:

- Candidate-level UART `CAL_TRACE` was not captured because the board's J1
  USB/UART connection destabilized the JTAG chain while external J2 JTAG was
  attached. The run therefore proves completion and final register state, but
  not the candidate-by-candidate seed cost trajectory.

Remaining limitations:

- A separate electrically independent 3.3 V USB-UART connection is needed to
  capture `software_seed` and search trace text while J2 performs JTAG launch.
- No external PA/observation-receiver RF metrics were measured.

## 2026-07-12 16:04:28 +08:00

Reason:

- Remove PS UART as a blocker for candidate-level AI-assisted calibration
  evidence by exporting a structured A53 memory trace over the existing J2
  JTAG connection.

Changed files:

- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/scripts/capture_calibration_trace.ps1`
- `fpga/zu15eg/scripts/capture_calibration_trace.tcl`
- `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Added a 64-record `g_cal_trace_buffer` with magic `0x43414C54`, version
  `0x00010000`, fixed 112-byte records, count, completion, and overflow fields.
- The A53 app records software-seed, package, search, replay, and final events
  using fixed 32-bit fields and flushes each published record from data cache.
- The host wrapper obtains the buffer address from `aarch64-none-elf-nm` on
  the exact downloaded ELF. XSDB validates the header and completion state,
  then exports all records to CSV; PowerShell generates the Markdown summary.
- The board regression now treats trace export as a required post-run check.

Checks run:

- Direct A53 compile against the generated standalone BSP: passed. The BSP
  emitted its existing duplicate `xparameters.h` macro warnings.
- PowerShell parser checks for `capture_calibration_trace.ps1` and
  `run_zu15eg_baremetal_regression.ps1`: passed.
- `git diff --check`: passed with existing line-ending warnings only.
- Vitis adaptive-seed build: passed; `.buildstatus` reported `hw=SUCCESS` and
  produced the ELF at `2026-07-12 16:03:35 +08:00`.
- ELF symbol check: `g_cal_trace_buffer` at `0x00011180`, size `0x1C20`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  passed through J2 only, including PL programming, PS initialization, ELF
  launch, counter checks, replay capture, and JTAG trace export.
- Final regression log:
  `fpga/zu15eg/out/zu15eg_baremetal_regression_20260712_160349.log`.
- Trace evidence:
  `fpga/zu15eg/out/calibration_trace_jtag_20260712_160349.csv` and
  `fpga/zu15eg/out/calibration_trace_jtag_20260712_160349.md`.
- Trace result: 50 records, 3 accepted, 46 rejected, one final selection, and
  no overflow. Software seed package 3 was accepted as the best polynomial
  start with cost `1756105795`; LUT package 3 won with cost `3003709` and was
  retained as final mode 2.
- Final counters: input/frontend/DPD/output each `0x00001000`, stall/error/DPD
  saturation all zero, and `DPD_CTRL=0x00000002`.

Remaining limitations:

- The current cost uses MATLAB proxy scores plus digital PL monitor proxies;
  it is not measured RF EVM/ACLR from an observation receiver.
- The trace buffer is bounded to 64 records. The exporter fails on incomplete
  headers and reports overflow; larger future searches must raise capacity or
  use a streaming/ring-buffer policy.

## 2026-07-10 20:27:41 +08:00

Reason:

- Add a host-side PS UART capture helper so bare-metal `xil_printf`
  calibration traces can be saved while JTAG/XSDB is used to download and
  launch the ELF.
- Attempt a live JTAG plus UART calibration-trace capture after connecting
  both cables.

Changed files:

- `fpga/zu15eg/scripts/capture_uart_log.ps1`
- `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- `capture_uart_log.ps1` uses .NET `System.IO.Ports.SerialPort`, so it does not
  depend on `pyserial`. It captures one COM port at a configurable baud rate
  and duration, writes the UART text under `fpga/zu15eg/out/`, and can feed
  `parse_calibration_trace.py`.
- The documented flow is now explicit that JTAG/XSDB launches the ELF, while
  PS UART carries `xil_printf` output such as `CAL_TRACE`.
- `run_zu15eg_baremetal_regression.ps1 -CleanStaleHwProcesses` now warns and
  continues if the current shell cannot enumerate processes through WMI/CIM.
  This keeps a low-privilege shell from failing before the actual JTAG target
  scan.

Checks run:

- PowerShell parser check passed for
  `fpga/zu15eg/scripts/capture_uart_log.ps1`.
- `[System.IO.Ports.SerialPort]::GetPortNames()` listed
  `COM3`, `COM4`, `COM9`, `COM10`, and `COM11`; the registry serial map showed
  `COM9`, `COM10`, and `COM11` as VCP ports.
- Started concurrent 300-second UART captures on `COM9`, `COM10`, and `COM11`.
  The logs were written to `fpga/zu15eg/out/uart_COM9_live.log`,
  `fpga/zu15eg/out/uart_COM10_live.log`, and
  `fpga/zu15eg/out/uart_COM11_live.log`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild -CleanStaleHwProcesses`:
  failed before hardware launch because the current shell was denied access to
  `Get-CimInstance Win32_Process`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild`:
  failed at `xsdb_require_targets.tcl`. XSDB reported only an unstable scan
  chain and no usable ZU15EG JTAG target.
- `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat .\fpga\zu15eg\scripts\xsdb_list_targets.tcl`:
  ran, but listed no XSDB targets.
- `python .\fpga\zu15eg\scripts\parse_calibration_trace.py .\fpga\zu15eg\out\uart_COM9_live.log .\fpga\zu15eg\out\uart_COM10_live.log .\fpga\zu15eg\out\uart_COM11_live.log --prefix calibration_trace_uart_live`:
  passed and wrote empty trace outputs. No `CAL_TRACE` was expected because the
  ELF was not launched.
- After reconnecting JTAG and UART, `[System.IO.Ports.SerialPort]::GetPortNames()`
  still listed `COM3`, `COM4`, `COM9`, `COM10`, and `COM11`, with `COM9`,
  `COM10`, and `COM11` mapped as VCP ports.
- After reconnecting JTAG and UART,
  `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat .\fpga\zu15eg\scripts\xsdb_list_targets.tcl`
  still listed no XSDB targets.
- After reconnecting JTAG and UART,
  `D:\Xilinx\Vitis\2024.1\bin\xsdb.bat -eval "connect -url tcp:127.0.0.1:3121; jtag targets; targets"`
  listed no low-level JTAG targets and no XSDB processor/PL targets.

Checks not run:

- The bare-metal app did not launch in this attempt, so no live
  candidate-level UART `CAL_TRACE` was captured.
- No RTL, MATLAB algorithm, IP packaging, synthesis, or timing checks were run
  because this update only adds a host-side UART capture helper and
  documentation.

Remaining limitations:

- The current JTAG path must be restored before a live UART `CAL_TRACE` capture
  can complete. XSDB is presently seeing no low-level JTAG target, rather than
  PS TAP, PMU, and PL targets.
- The correct PS UART COM port still needs confirmation during a successful ELF
  launch. The VCP candidates observed in this session were `COM9`, `COM10`,
  and `COM11`.

## 2026-07-09 23:40:51 +08:00

Reason:

- Complete the two host-side Phase 3 follow-up tasks: calibration trace parsing
  and a software lookup seed predictor for AI-assisted DPD calibration.
- Record the successful short ZU15EG board regression that reused the bitstream,
  XSA, and ELF artifacts generated by the earlier full run.

Changed files:

- `fpga/zu15eg/scripts/parse_calibration_trace.py`
- `fpga/zu15eg/scripts/generate_dpd_seed_table.py`
- `fpga/zu15eg/README.md`
- `fpga/zu15eg/baremetal/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- Added a host-side parser that extracts `CAL_TRACE` and
  `CAL_SELECTED_REPLAY` lines from UART/XSDB transcripts and writes trace CSV,
  selected-replay CSV, and Markdown summaries. It intentionally writes empty
  but valid outputs when a board log does not include captured UART trace text.
- Added a deterministic DPD seed-table generator that combines MATLAB
  AI-assisted DPD sweep rows with board replay counter CSV rows. It can choose
  a nearest-neighbor software seed for a target QAM/subcarrier/backoff setting
  and records board monitor proxies beside the seed data.
- The seed predictor is a software lookup/tiny-ML-ready artifact, not a trained
  neural PA model and not a hardware ML accelerator.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -SkipBitstreamBuild -SkipXsaExport -SkipElfBuild -CleanStaleHwProcesses`:
  passed. The run found PS TAP, PMU, and PL JTAG targets, programmed the FPGA,
  ran PS init, launched the bare-metal ELF, and completed the post-run counter
  check with `VERSION=0x00010000`, `INPUT_SAMPLE_COUNT=0x00001000`,
  `FRONTEND_SAMPLE_COUNT=0x00001000`, `DPD_SAMPLE_COUNT=0x00001000`,
  `OUTPUT_SAMPLE_COUNT=0x00001000`, `INPUT_STALL_COUNT=0x00000000`,
  `ERROR_STATUS=0x00000000`, `DPD_CTRL=0x00000002`, and
  `DPD_SATURATION_COUNT=0x00000000`. Replay counters were captured to
  `fpga/zu15eg/out/dsm_replay_counters_20260709_233402.csv`; the regression log
  is `fpga/zu15eg/out/zu15eg_baremetal_regression_20260709_233402.log`.
- `python -m py_compile .\fpga\zu15eg\scripts\parse_calibration_trace.py .\fpga\zu15eg\scripts\generate_dpd_seed_table.py`:
  passed.
- `python .\fpga\zu15eg\scripts\parse_calibration_trace.py .\fpga\zu15eg\out\zu15eg_baremetal_regression_20260709_233402.log --prefix calibration_trace_20260709_233402`:
  passed and wrote empty trace/selected CSVs plus a Markdown note because the
  regression log did not include UART `CAL_TRACE` lines.
- `python .\fpga\zu15eg\scripts\generate_dpd_seed_table.py --qam 16 --used-subcarriers 48 --input-backoff 0.58 --prefix dpd_seed_table_20260709_233402`:
  passed. It generated seven seed rows from six MATLAB sweep rows plus one
  board replay row and recommended `pa_weak_16qam_48sc_bo058` as the software
  seed for the requested target.

Checks not run:

- No new RTL, IP wrapper, MATLAB algorithm, synthesis, or timing change was
  made in this update, so XSim, MATLAB bit-true checks, IP packaging, and OOC
  synthesis were not rerun for the parser/seed-table scripts.
- The successful board rerun reused existing bitstream, XSA, and ELF artifacts;
  the earlier same-evening full run already rebuilt those artifacts before
  JTAG discovery blocked the launch stage.

Remaining limitations:

- The latest regression log did not capture candidate-level UART `CAL_TRACE`
  lines, so the parser was validated for no-trace handling but not yet against
  a full UART transcript containing all candidate records.
- The seed predictor uses MATLAB scenario metrics plus board replay monitor
  proxies. It does not train a neural model and does not use measured RF
  EVM/SNDR/ACLR feedback from an external observation receiver.

## 2026-07-09 23:00:00 +08:00

Reason:

- Implement the Phase 3 v2 PS-side calibration policy proposed in
  `docs/PROJECT_PROSPECTIVE.md`.
- Add a replayable final board-state capture path so selected DPD packages can
  be checked without relying only on UART text.

Changed files:

- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/scripts/capture_dsm_replay_counters.ps1`
- `fpga/zu15eg/scripts/capture_dsm_replay_counters.tcl`
- `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The bare-metal calibration cost now has build-time configurable weights and
  proxy shifts through generated `cal_config.h` overrides.
- The polynomial search now uses a multi-round coarse-to-fine coordinate
  search with configurable initial/minimum Q2.14 step size.
- Package evaluation and search candidates emit CSV-style `CAL_TRACE` lines
  including candidate id, round, mode/package, `C1/C3/C5`, proxy scores,
  hardware monitor counters, cost, decision, and reason.
- A replay-only bare-metal mode can be built with `CAL_REPLAY_ONLY=1` and
  fixed package or coefficient defines.
- Added an XSDB replay counter capture script that writes
  `fpga/zu15eg/out/dsm_replay_counters_<timestamp>.csv` during the one-command
  board regression.

Checks run:

- PowerShell parser checks passed for:
  - `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
  - `fpga/zu15eg/scripts/capture_dsm_replay_counters.ps1`
  - `fpga/zu15eg/scripts/run_zu15eg_baremetal_regression.ps1`
- `python -m py_compile fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.py`:
  passed.
- `gcc -std=gnu11 -fsyntax-only` with local stub Xilinx headers:
  passed for `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`.
- `git diff --check`: passed with line-ending normalization warnings only.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\baremetal\scripts\build_baremetal_smoke.ps1`:
  passed. Vitis 2024.1 rebuilt
  `fpga/zu15eg/out/vitis_baremetal/dsm_dpd_baremetal_smoke/build/dsm_dpd_baremetal_smoke.elf`.
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\fpga\zu15eg\scripts\run_zu15eg_baremetal_regression.ps1 -CleanStaleHwProcesses`:
  partially completed. The flow rebuilt the ZU15EG bitstream, exported XSA,
  and rebuilt the bare-metal ELF. Vivado implementation completed
  `write_bitstream Complete!` with 0 errors and 0 critical warnings, and the
  router reported estimated `WNS=2.156 ns`, `TNS=0.000`, `WHS=0.012 ns`, and
  `THS=0.000`.

Checks not run:

- The ZU15EG bare-metal app launch, post-run counter check, and replay counter
  CSV capture did not run because `xsdb_require_targets.tcl` found no usable
  ZU15EG JTAG target. The regression log is
  `fpga/zu15eg/out/zu15eg_baremetal_regression_20260709_230749.log`.
- `tclsh` was not available in the current shell, so the XSDB Tcl scripts were
  not syntax-checked outside XSDB.
- RTL/XSim regressions were not required because this change only updates
  PS-side bare-metal C, board helper scripts, and documentation.

Remaining limitations:

- The v2 calibration loop still uses MATLAB proxy scores plus PL monitor
  counters, not measured RF EVM/SNDR/ACLR from an observation receiver.
- The new replay CSV captures final PL register/counter state; detailed
  candidate trace still comes from the bare-metal app `xil_printf` stream.
- Board confirmation requires reconnecting or power-cycling the JTAG path, then
  rerunning the board regression, preferably with `-SkipBitstreamBuild`,
  `-SkipXsaExport`, and `-SkipElfBuild` to reuse the artifacts generated in
  this run.

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
## 2026-07-12 16:43:07 +08:00

Reason:

- Make the software AI-assisted DPD policy testable across PA strength, QAM,
  occupied bandwidth, and input-backoff conditions without treating a
  same-scenario replay as an unseen-condition result.
- Preserve enough waveform and calibration provenance to archive full JTAG
  traces and reproduce a strict leave-one-scenario-out policy evaluation.

Changed files:

- `fpga/zu15eg/scripts/evaluate_dpd_trace_loso.py`
- `fpga/zu15eg/scripts/generate_dpd_tx_waveform.py`
- `fpga/zu15eg/scripts/capture_calibration_trace.ps1`
- `fpga/zu15eg/trace_sets/manifest_template.csv`
- `fpga/zu15eg/trace_sets/README.md`
- `fpga/zu15eg/baremetal/src/dsm_dpd_baremetal_smoke.c`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `fpga/zu15eg/baremetal/README.md`
- `fpga/zu15eg/README.md`
- `docs/AI_COMMUNICATION_IP_ROADMAP.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/UPDATE_LOG.md`

Implementation notes:

- The bare-metal build can generate and embed 4096 deterministic Q1.15
  QAM-OFDM DMA words from QAM order, used-subcarrier count, input backoff,
  FFT size, and seed. Builds without a complete waveform configuration remove
  the generated header and restore the synthetic smoke vector.
- JTAG trace capture can append only complete full-calibration traces to a
  manifest that records PA profile/strength, waveform configuration ID, and
  calibration profile. It rejects policy-only or incomplete traces.
- The offline evaluator excludes all replicates of each held `scenario_id`,
  uses package-stage costs only, isolates cost profiles, and reports policy
  action availability, package regret, convergence/candidate reduction, and
  coverage. No training trace produces an explicit `insufficient_training`
  result.

Checks run:

- `python .\fpga\zu15eg\scripts\evaluate_dpd_trace_loso.py --self-test`:
  passed.
- `python -m py_compile .\fpga\zu15eg\scripts\evaluate_dpd_trace_loso.py .\fpga\zu15eg\scripts\generate_dpd_tx_waveform.py`:
  passed.
- `python .\fpga\zu15eg\scripts\generate_dpd_tx_waveform.py --qam 16 --used-subcarriers 48 --input-backoff 0.58 --header .\fpga\zu15eg\out\dpd_tx_waveform_test.h`:
  passed; generated 4096 Q1.15 packed I/Q words.
- `capture_calibration_trace.ps1` and `build_baremetal_smoke.ps1` PowerShell
  parser checks: passed.
- Single existing full board trace through the leave-one-scenario-out tool:
  passed and reported `insufficient_training`, as expected.
- `git diff --check`: passed.

Remaining limitations:

- No multi-condition PA/QAM/bandwidth/backoff board data has been captured
  yet, so leave-one-scenario-out accuracy/regret results are intentionally not
  available.
- A waveform-enabled Vitis application build was attempted but the local
  Vitis 2024.1 Python API stopped after platform/application creation without
  producing an ELF. The generated header and C source were instead compiled
  directly with the Vitis A53 cross-compiler and the current XSA-derived BSP;
  that compile passed with pre-existing BSP macro redefinition warnings.
- No ZU15EG board regression was run for this software update. The new
  generated waveform header and bare-metal source must be built into an ELF
  and run for each archived board condition.
- The current PL monitor costs remain debug/calibration proxies, not measured
  RF EVM, ACLR, or PA behavior.
## 2026-07-17 23:00:00 +08:00

Reason:

- Redesign memory-DPD seed selection so unknown-PA seed safety is the primary
  prediction target, while preserving the three existing blind PA profiles as
  permanently untouched final-test data.

Changed files:

- `matlab/dpd/run_dpd_memory_tinyml_dataset.m`
- `matlab/scripts/entry_dpd_memory_tinyml_development_dataset.m`
- `scripts/run_matlab_dpd_memory_tinyml_development_dataset.cmd`
- `fpga/zu15eg/scripts/evaluate_memory_tinyml_safety_seed_policy.py`
- `scripts/run_memory_tinyml_safety_seed_policy.cmd`
- `docs/evidence/dpd/safety_seed_policy_20260717/`
- `matlab/dpd/README.md`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- Added eight `dev_*` behavioral PA profiles that vary gain, soft compression,
  memory, observation noise, gain/phase drift, and temperature without sharing
  any `blind_*` profile identifier. Development generation cannot export the
  package header.
- Added a deterministic safety-first nearest-evidence policy. A package is
  considered only when its seven nearest same-waveform nonblind observations
  are all labeled safe and the nearest feature distance is inside a finite
  selected in-distribution bound. Expected cost ranks only those
  safety-qualified packages; no qualified package produces `fallback_14`.
- Hyperparameters were selected using only development PA LOSO. The winner is
  `k=7` with a finite normalized-distance cap of `4.0`: 129
  safety-qualified seeds, 63 fallbacks, and zero unsafe seeds over 192
  development conditions.
- The three frozen blind profiles were evaluated once only after selection:
  49 safety-qualified seeds, 23 fallbacks, and zero unsafe selected seeds over
  72 conditions. The report explicitly records that blind data was not used for
  selection.
- Every result retains `mandatory_search_candidates=14`, direct execution is
  false, and AXI TinyML integration is false. The old tree/LUT PS header stays
  `AVAILABLE=0` because it is a distinct policy with 19 blind violations.

Checks run:

- `D:\MATLAB\R2025a\bin\matlab.exe -batch "run('E:/workspace/chip/dsm_ip/matlab/scripts/entry_dpd_memory_tinyml_development_dataset.m')"`:
  passed outside the restricted sandbox; 1,152 package rows, 192 conditions,
  and eight development profiles.
- `python -m py_compile fpga/zu15eg/scripts/evaluate_memory_tinyml_safety_seed_policy.py`:
  passed.
- `python fpga/zu15eg/scripts/evaluate_memory_tinyml_safety_seed_policy.py ...`:
  passed; generated development LOSO and frozen blind evidence with zero unsafe
  selected seeds in both sets.

Remaining limitations:

- The qualified policy exists only in Python. Generate development-only PS-C
  constants, prove Python/C decision equivalence, and replay completed observer
  traces before changing a board policy header.
- The PA profiles and safety labels are behavioral simulation evidence, not
  calibrated physical PA, EVM, ACLR, or RF safety certification.
## 2026-07-17 23:15:00 +08:00

Reason:

- Convert the frozen safety-first behavioral PA seed policy into auditable PS-C
  constants and prove fixed-point Python/C decision equivalence before any
  board trace replay.

Changed files:

- `fpga/zu15eg/scripts/generate_memory_tinyml_safety_seed_policy.py`
- `fpga/zu15eg/baremetal/src/dpd_safety_seed_policy.h`
- `fpga/zu15eg/baremetal/src/dpd_safety_seed_policy.c`
- `verif/c/test_dpd_safety_seed_policy.c`
- `verif/vectors/dpd/memory_tinyml_safety_seed_policy_q20.txt`
- `scripts/run_memory_tinyml_safety_seed_equivalence.ps1`
- `fpga/zu15eg/baremetal/scripts/build_baremetal_smoke.py`
- `docs/evidence/dpd/safety_seed_policy_20260717/memory_tinyml_safety_seed_policy_c_constants.json`
- `docs/project_prospective.md`
- `docs/STATUS_AND_LIMITS.md`
- `docs/AI_ASSISTED_DPD_RESULTS.md`
- `docs/UPDATE_LOG.md`

Implementation and evidence:

- The generator accepts only the frozen report contract: finite `k=7`, no
  direct path, and the exact three excluded `blind_*` IDs. It emits 480
  base/development-only evidence rows, Q12.20 normalization constants, eight
  waveform keys, safety labels, and package costs. Unsafe package costs use
  `uint64_t` because their intentional penalty exceeds 32 bits.
- The PS selector uses the existing observer-v2 Q12.20 feature structure,
  filters by exact waveform key, requires seven nearest safety observations,
  applies the finite distance gate, then ranks only unanimously safe packages.
  Every result retains 14 local candidates. Generated policy flags keep board
  enable and direct execution at zero.
- Quantized constants reproduce all 72 frozen blind decisions before the C
  test is run; the generator fails if any blind ID, set membership, or decision
  changes.

Checks run:

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_memory_tinyml_safety_seed_equivalence.ps1`:
  passed; generated constants and host C matched Python on 552 decisions.
- `aarch64-none-elf-gcc -std=c99 -Wall -Wextra -Werror ... dpd_safety_seed_policy.c`:
  passed; A53 object compiled with no warnings.
- `git diff --check`: pending final workspace check.

Remaining limitations:

- The new selector is intentionally not called by the bare-metal application
  yet. Integrate it behind an explicit test-only calibration mode, build the
  ELF, then request a board connection to collect completed observer-v2 traces.
- This remains behavioral PA evidence; zero blind simulated seed violations do
  not prove RF or physical-PA safety.
