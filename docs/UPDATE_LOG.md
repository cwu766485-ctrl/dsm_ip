# Update Log

## 2026-10-01 20:31 +08:00 - Separate UVM DUT targets and repair migrated vector paths

- Moved 47 unchanged UVM class/package files into target-specific
  `env/{axi_ip,thermo5}`, `sequences/{axi_ip,thermo5}`, and
  `tests/{axi_ip,thermo5}` directories. Reusable interface agents, formal
  files, Python model logic, and both testbench tops remain at their existing
  canonical homes. Updated both VCS filelists and role READMEs. Added
  `docs/verification/thermo5-uvm-architecture.md` with the DUT port, RTL
  hierarchy, MATLAB reference, and UVM ownership contract.
- Corrected post-migration `uvm_verif` references in the Python vector
  generator/regression controller, XSim/board helper paths, and MATLAB
  export/compare paths. The seven files accidentally generated under
  `dv/uvm_verif/` were SHA-256 identical to the canonical vectors and were
  moved, not deleted, to `runs/uvm_legacy_generated_duplicate_20261001/`.
- Checks: licensed thermo5 six-case VCS regression PASS, URG merge PASS
  (overall 86.59%), AXI-IP VCS compile plus `dsm_bp_test` PASS, corrected
  one-case Python regression PASS, regenerated Python vectors identical to
  archived copies, Python refmodel unit tests 8/8 PASS from their documented
  working directory, MATLAB P0 7/7 PASS, `git diff --check` no whitespace error.
  A targeted before/after `dv/uvm` inventory found all 47 moved source files
  unchanged and no missing source artifact; modified manifests/docs/scripts
  are intentional. No RTL arithmetic, fixed-point behavior, or UVM checker
  semantics were changed.
- Limits: the repository-wide legacy migration-map verifier cannot validate
  wildcard/historical entries against the target-scoped snapshots; this is
  not a full repository-migration signoff. The corrected older XSim/board
  helper scripts were path-checked but not all individually rerun. XPM FIFO
  UVM, physical GT/PA, and uncovered configuration modes remain outside this
  layout change.

## 2026-10-01 16:23 +08:00 - Target reachable thermo5 coverage leads

- Added independent 2-tap vector interpolator and one-tap programmable-DPD
  directed VCS tests plus a reproducible coverage runner under
  `dv/verif/block/`. Interpolator test covers a blocked output behind an empty
  stage-2 slot, reset with enable high, and checked 12-word half-sample data.
  DPD test covers empty-pipeline backpressure, positive/negative I/Q
  saturation, ordered six-word output, counts, and stalls.
- Checks: licensed VCS simulation PASS for both tests; separate URG reports
  confirm the named line-70, line-140 and valid-output I/Q saturation rows.
  Frozen thermo5 `thermo5_sku_bittrue_test` seed 1 with PA stalls reran PASS
  (32 source beats, 56 four-plane words, zero UVM errors/fatals).
  No RTL or MATLAB source changed. Fixed-SKU thermo5 UVM code coverage remains
  86.59%; block VDBs were not merged into it.
- Limits: low-power-off and identity/DPD1 configuration pins are statically
  fixed in the UVM top, not bulk-waived. DPD invalid-slot saturation and other
  unreviewed URG holes remain open. XPM, GT and RF hardware are outside these
  block-level tests.

## 2026-10-01 16:06 +08:00 - Refactor thermo5 UVM ownership and extend verification

- Added the thermo5 source item, sequencer, monitor, and active agent under
  `dv/uvm/agent/axis/`; moved vector generation into
  `dv/uvm/sequences/thermo5_source_sequence.svh`. Added a SKU configuration
  and control BFM under `dv/uvm/env/`. The scoreboard now receives source
  and four-plane monitor transactions and resets its own index per reset
  epoch. Tests no longer write DUT pins or scoreboard state. Updated the UVM
  package/filelist, Makefile, READMEs, and coverage map.
- Added an XPM-model option to the existing full-chain thermo5 XSim testbench
  and launcher. No DUT RTL, fixed-point arithmetic, MATLAB vector, or PA
  comparison result was changed.
- Checks: licensed VCS six-case thermo5 regression PASS; URG merge PASS
  (functional groups 100%, overall 86.59%, CDC FSM 7/7 states and 12/12
  transitions); 20 additional VCS simulations across seeds 11-20 PASS;
  full-chain vendor-XPM XSim with PA stalls seeds 7/8/9 PASS; generic FIFO
  full-chain XSim seed 1 PASS. Old AXI-IP `make vcs` and `dsm_bp_test` PASS
  with zero UVM errors/fatals. `git diff --check` reports no whitespace errors.
- Remaining: VCS UVM still uses generic FIFO; XPM has directed full-chain
  XSim evidence but no UVM coverage. Condition/branch/toggle holes are not
  waived or closed, physical GT/PA and hardware are outside this result.

## 2026-10-01 13:46 +08:00 - Organize UVM targets and restore AXI-IP compilation

- Moved 14 AXI-IP virtual-sequence files from `dv/uvm/env/` to
  `dv/uvm/sequences/`, and restored one stranded long-run sequence plus two
  bit-true tests from `dv/verif/uvm/` to the canonical UVM tree. Updated
  `dv/uvm/sim/uvm_filelist.f`, role READMEs, and the physical migration map.
  The moved files are Git R100 renames; no DUT RTL or numerical behavior changed.
- Reason: distinguish the old AXI-IP target from thermo5 and remove misplaced
  sequence/test files from the environment and directed-DV trees.
- Checks: both source filelists and all legacy package includes resolve;
  licensed VCS `thermo5-vcs-regression` passes six cases; `make vcs PYTHON=python3`
  compiles the AXI-IP target; `dsm_bp_test` passes with zero UVM errors/fatals.
  `git diff --check` reports no whitespace errors.
- Limits: full old AXI-IP regression was not rerun; thermo5 source and PA
  components are not yet full `uvm_agent` wrappers; generic-FIFO UVM does not
  cover XPM FIFO or physical GT behavior.

## 2026-10-01 12:14 +08:00 - Licensed thermo5 UVM regression and coverage

- The running local Synopsys license service was discovered without recording
  its path, key, or address in the repository. VCS V-2023.12-SP1 compiled the
  frozen thermo5/2-tap/DPD1 UVM testbench after a scoreboard portability fix:
  `$readmemh` now loads each plane through a one-dimensional memory.
- Clarified the finite-stream contract: downstream drain may set sticky CDC
  underflow after all 32 source beats have arrived; normal tests reject only
  earlier starvation. The reset test now interrupts after 24 source beats and
  proves a clean 32-beat/56-word replay without early underflow.
- `make -C dv/uvm/sim thermo5-vcs-regression` passed six tests (positive
  bit-true/PA stalls, FIFO full, FIFO empty, reset/replay, and expected
  illegal-frame assertion, plus reset sweep at residuals 2/4/6/10/12).
  Positive tests report zero UVM errors/fatals;
  the negative test observed the precise RTL assertion and sticky error.
- Fixed URG merge to include the compiled design VDB and fail on error text
  even when URG exits zero. The six-test merge passes: functional groups
  100%, overall 87.30%, DUT hierarchy 86.76%, CDC FSM 100%. Reports are under
  `runs/uvm_thermo5_i2_d1/coverage/`.
- Remaining: triage unhit RTL condition/branch/toggle bins and distinguish intentional
  configuration exclusions from missing stimulus; XPM FIFO UVM and physical
  GT/board checks are not covered by this generic-FIFO UVM regression.

## 2026-10-01 00:40 +08:00 - Add thermo5 UVM corner and coverage regression

- Extended the existing thermo5 UVM source driver, monitor, scoreboard, test
  package, and Makefile with FIFO full/backpressure, FIFO empty/underflow,
  midstream reset/replay, illegal-frame negative assertion, functional event
  coverage, VCS code coverage, and a guarded URG merge target. DUT RTL and
  MATLAB numerical behavior were not changed.
- Checks: `xvlog -sv -L uvm` parsed the complete updated thermo5 filelist;
  the directed full-chain XSim with seed-2 PA stalls passed 32 source beats
  and 56 four-plane words; Makefile regression dry-run resolved all targets;
  `git diff --check` passed. VCS V-2023.12-SP1 was retried on Rocky Linux but
  stopped before HDL parsing with `Cannot find license file`. No UVM runtime
  or coverage PASS is claimed. The repository login wrapper was also tried;
  it selected a `VCS_HOME` directory missing `vcs1`, so it likewise never
  reached HDL parsing.
- Remaining: obtain an authorized licensed shell, run the five-case UVM suite,
  review any errors and URG coverage, then close uncovered bins.

## 2026-09-30 21:15 +08:00 - Integrate thermo5 UVM into canonical tree

- Moved the new thermo5 UVM top, filelist, and MATLAB vector launcher from a
  parallel `dv/uvm/thermo5_sku/` subtree into the existing `agent/`, `env/`,
  `tests/`, `tb/`, and `sim/` roles. The original monolithic top was split
  into interface, driver, monitor, scoreboard, environment, test, and DUT top.
  Removed the redundant local Makefile/README; the existing UVM Makefile now
  has `thermo5-vcs` and `thermo5-vcs-run` targets. The older AXI-IP UVM target
  remains intact because it instantiates a different DUT.
- The post-stall-fix ZU15EG route produced WNS +0.346 ns, WHS +0.026 ns,
  39,512 LUT, 50,181 FF, 6.5 BRAM, and 496 DSP. Its Tcl exited nonzero after
  writing routed timing/resource reports due to an escaped-quote error in the
  power-provenance line; fixed that line. A clean end-to-end rerun remains due.
- Post-move checks: thermo5 filelist paths resolve; both old and new Make
  targets produce correct VCS commands in dry-run; `xvlog -sv -L uvm` parses
  the split RTL/UVM source; the relocated MATLAB launcher regenerates 32
  source beats/56 core words; directed full-chain XSim with seed-2 randomized
  PA stalls passes. `git diff --check` passes. The prior VCS license and
  Windows UVM DPI blockers remain unchanged, so UVM simulation is not PASS.

## 2026-09-30 20:16 +08:00 - Begin frozen thermo5 subsystem UVM

- Added `dv/uvm/thermo5_sku/` with an isolated two-clock UVM source driver,
  four-plane monitor, MATLAB-vector scoreboard, ready-stall checks, and a VCS
  filelist/Makefile. The old UVM top continues to target a different AXI IP.
- Extended `gen_tid32_thermo5_frontend_bittrue_vectors.m` with optional legal
  frame-start positions while preserving its existing defaults. Generated
  448 complex samples, 32 packed 14-lane AXI beats, and 56 four-plane output
  references with frame starts at core words 1, 15, and 36.
- Checks: MATLAB P0 7/7 PASS with 65,536 samples and zero mismatches each;
  frozen thermo5/2-tap/DPD1 frontend XSim PASS for 64 words / 2,048 samples;
  `git diff --check` PASS. Vivado xvlog parsed the UVM and RTL source. XSim
  elaboration failed while linking UVM DPI symbols, so the new UVM test has
  no simulation PASS yet. Rocky WSL VCS V-2023.12-SP1 was also attempted;
  compilation stopped before HDL parsing because no license file was
  configured. A licensed VCS run and coverage are next.
- The UVM smoke uses the generic asynchronous FIFO for simulator portability;
  XPM FIFO behavior remains separately covered by directed XSim. Full reset,
  drain/burst, negative-protocol, and coverage closure remain open.
- A new directed full-axis test exposed output corruption when the four PA
  planes stalled. `tid32_cartesian_fs4_gt_tx.sv` now holds its payload, valid,
  and recursive state when the raw-word boundary cannot advance. The CDC's
  simulation-only stability assertion now checks the cycle after a stall.
  Both continuous-ready and randomized-stall 32-beat/56-word MATLAB-to-XSim
  four-plane comparisons pass; three stall seeds exercised 8/35/20 stalled
  cycles. Required post-RTL checks: P0 XSim 7/7 PASS and
  IP smoke 5/5 PASS; frozen core XSim PASS. The first OOC retry stopped in a
  known Vivado realtime-helper crash before HDL synthesis. A fresh full route
  is running under `runs/uvm_thermo5_i2_d1/ooc_stallfix_retry1/`; routed STA
  for the revised RTL is not yet signed off.

## 2026-09-29 - 18-SKU routed OOC matrix closure and UVM target freeze

- Completed all 18 independent ZU15EG full OOC implementations spanning
  thermo3/thermo5, 2/3/4-tap interpolation, and 1/2/4-tap compile-time
  identity memory-DPD wrappers. Every row passes 218.75-MHz setup and hold.
- The 250-MHz, three-seed, fair-RMS numerical gate selects thermo5 with
  two-tap interpolation. The DPD1 identity-wrapper SKU is frozen because it
  passes with zero raw-word mismatches and the best qualified PPA:
  WNS/WHS +0.316/+0.027 ns, 39,512 LUT, 50,181 FF, 6.5 BRAM, and 496 DSP.
- Evidence: `runs/thermo_sku_matrix/ooc_20260927_111823/` and
  `runs/thermo_sku_matrix/algorithm_full_20260927_111823/`.
- Next action: implement and regress UVM on this frozen SKU, then obtain
  formal lint/CDC/RDC and mapped 28-nm DC reports before making any ASIC or
  static-signoff claim.

## 2026-09-26 - Read-only FPGA JTAG discovery

- Vivado 2024.1 Hardware Manager connected to local `hw_server` at
  `127.0.0.1:3121` and enumerated target
  `xilinx_tcf/Xilinx/15051A`.
- Opening the target reported no JTAG devices. The host-to-cable path is
  present, but the powered FPGA/JTAG chain is not detectable; no FPGA part,
  bitstream status, ILA core, GT link, or board validation conclusion exists.
- The probe used `fpga/zu15eg/scripts/vivado_list_hw_targets.tcl`; it did not
  program, reset, or otherwise change board state. Log:
  `runs/hw_scan_20260926_234032/vivado_hw_scan.log`.

## 2026-09-26 - Matched-SAIF low-power A/B closure

- Fixed the XSim launcher to use native `xelab -log`/`xsim -log`, fixed
  Windows generic/testplusarg handling with fixed top wrappers, normalized
  escaped SAIF hierarchy, and connected the real `run_request`/ingress
  strategy through the LP controller and CDC boundary.
- Added state-hold behavior for LP burst/idle gaps so recursive gain and
  interpolation history is preserved while invalid pipeline activity is
  stopped. Baseline and LP remain bit-true equivalent.
- Thermo3 and thermo5 each passed continuous, burst, and long-idle activity
  simulations with matching accepted words, output words, digest, and cycle
  count. Fresh routed baseline and LP DCPs both pass 218.75 MHz setup/hold.
- Thermo3 matched-SAIF dynamic reduction: 1.14% continuous, 5.45% burst,
  4.01% idle. Thermo5: 1.76% continuous, 6.02% burst, 4.63% idle.
- Thermo5 timing: baseline `WNS/WHS=+0.089/+0.023 ns`; LP
  `+0.139/+0.017 ns`. SAIF direct net matching is 7% for all workloads with
  zero baseline/LP coverage delta. Vivado FPGA power confidence is Medium
  (RTL-SAIF direct match plus Vivado propagation); this is not ASIC or silicon
  signoff.
- Artifacts: `runs/lp_power_ab/20260926_121341_thermo3/` and
  `runs/lp_power_ab/20260926_152500_thermo5/`, including
  `power_comparison.csv`, routed DCPs, timing logs, and per-workload reports.

## 2026-09-22 - ASIC tool/library environment audit

- Rocky-8.10 WSL contains Synopsys DC V-2023.12-SP1 at
  `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`; `dc_shell -version` runs.
- No usable 28nm standard-cell `.db` was found in the available WSL/project
  paths, and the earlier `/tmp/lumen28/std_ss.db` path is absent.  The DSM
  ASIC flow remains blocked until a licensed, readable 28nm mapping library
  with matching max/min corners is supplied.

## 2026-09-23 - Rocky TSMC28 standard-cell probe confirmation

- The active Rocky terminal successfully ran the DSM standard-cell probe with
  the TSMC28 RVT TT library.  DC loaded the library and reported 839 cells
  with 15 inverter-name matches; this is valid mapping-library evidence.
- The previously referenced SRAM macro `.db` under
  `/home/ray/ic/CIMForge/syn/out/pdk_cache/` was not found.  Full macro-aware
  synthesis remains blocked; standard-cell-only synthesis can proceed now.

## 2026-09-21 23:58 SGT - Thermo5 routed closure and CDC/serializer verification

- Completed the thermo5 full AXI/FIFO/frontend routed OOC on
  `xczu15eg-ffvb1156-2-i` at 125/218.75 MHz.  The full
  `opt_design -> place_design -> phys_opt_design -> route_design` flow passed
  with WNS/WHS `+0.308/+0.027 ns`, TNS/THS `0/0`, zero errors, and zero
  critical warnings.  Utilization is 71,869 total LUTs, 97,249 registers, 6.5
  BRAM tiles, and 2,032 DSP48E2.
- Froze the thermo3/thermo5 routed PPA, timing, pipeline-depth, and fanout
  comparison in `docs/THERMO3_THERMO5_ROUTED_PPA.md`.  Relative to thermo3,
  thermo5 adds 11,948 total LUTs, 13,452 registers, and 2 DSPs.  Both now have
  the same fixed core pipeline depth and positive 218.75 MHz timing margin.
- Added simulation-only assertions for reset release, generic-FIFO Gray-pointer
  transitions, prohibited full/empty transactions, legal gearbox residual
  counts, frame-boundary alignment, and stable backpressured output.  The CDC
  test now explicitly requires four accepted source words before core enable
  and rejects any pre-enable core output.  Generic and XPM CDC tests both pass.
- Fixed the thermo5 serializer-loopback file list to include the frontend's
  elastic-buffer dependency.  The four-path ideal behavioral serializer test
  passes 64 recovered words / 4,096 bits per path against MATLAB golden data.
  This is not a GT primitive, electrical channel, BERT, or board result.
- Required checks after the RTL/assertion changes: project P0 XSim `7/7` PASS;
  IP smoke PASS; generic CDC XSim PASS; XPM CDC XSim PASS.  The thermo5 full
  routed OOC and four-path behavioral serializer loopback also PASS.
- Added `docs/GT_VERIFICATION_WITHOUT_HARDWARE.md` to separate simulation and
  implementation evidence from measurements that require physical hardware.

## 2026-09-22 - Vendor-neutral raw-link PRBS31/BERT endpoint

- Added `rtl/gt/gt_link_bringup_bist.sv`, a synthesizable 64-bit user-word
  endpoint above the physical GT.  It provides known-word training, PRBS31
  generator/checker, ready filtering, link/reset FSM, sticky error and error
  counters, clear/retrain recovery, and deterministic error injection.
- Added executable protocol assertions for TX valid/ready state ownership,
  link-up versus enable, and error-counter/sticky-status consistency.
- Added `dv/verif/block/gt/tb_gt_link_bringup_bist.sv` and
  `dv/verif/scripts/run_xsim_gt_link_bringup_bist.ps1`.  XSim passes the clean
  PRBS31 loopback, injected-error detection, sticky status, clear/retrain, and
  known-word recovery sequence:
  `GT_LINK_BRINGUP_BIST_PASS prbs_words=49 errors_detected=0`.
- The endpoint is vendor-neutral and attaches to the existing 64-bit raw user
  boundary.  This evidence does not claim GTH PLL/CDR lock, electrical BER,
  eye/jitter, package/channel behavior, or board loopback.

## 2026-09-22 - ZU15EG GT Wizard generation probe

- Ran `fpga/zu15eg/scripts/generate_ti64_raw_gt14_ip.tcl` with Vivado 2024.1
  for part `xczu15eg-ffvb1156-2-i`.  The generated configuration is GTH
  `X1Y12`, TX/RX 14.0 Gb/s, 125 MHz refclk, 64-bit RAW user data, and both
  synthesis and simulation targets.  Vivado accepted the IP and wrote the XCI
  and generated HDL under `tmp/gt_wizard_probe_20260922/` outside the source
  RTL tree.
- This is an IP-generation/configuration PASS only.  Vendor behavioral GT
  simulation, package-constrained implementation, PLL/CDR lock, physical
  loopback, BER/BERT, eye, and jitter remain separate gates.
  Changed source/check files are `rtl/axis/dsm_reset_sync.sv`,
  `rtl/axis/dsm_async_fifo.sv`, `rtl/axis/dsm_axis14_to_core8_cdc.sv`,
  `dv/verif/block/axis/tb_dsm_axis14_to_core8_cdc.sv`, and
  `dv/verif/scripts/run_xsim_tid32_thermo5_serdes_loopback.ps1`.

## 2026-09-21 - Refresh active execution frontier

- Replaced the stale and partially encoded active execution frontier with a concise English source of truth. It records the passing full thermo3 OOC, the active AXI/FIFO/identity-DPD architecture, checked functional evidence, RF-model limits, and the thermo5/CDC/low-power/PPA next steps.
- No RTL, algorithm, constraints, or generated implementation artifact changed in this documentation-only update.

## 2026-09-21 - Close full thermo3 AXI/FIFO/frontend routed OOC

- Completed the full timing-driven implementation of `tid32_thermo3_axis_frontend_tx_ooc` on `xczu15eg-ffvb1156-2-i` at the unchanged 218.75 MHz core clock and 125 MHz AXI clock.  The result is `PASS`: WNS `+0.290 ns`, WHS `+0.027 ns`, TNS/THS zero, 0 errors, and 0 critical warnings.  This used `opt_design -> place_design -> phys_opt_design -> route_design`, not the earlier Quick diagnostic flow.
- The final core clock has 208,286 setup and hold endpoints with no failures; the AXI clock has 145 setup/hold endpoints with WNS/WHS `+4.966/+0.047 ns`.  Post-route utilization is 59,921 LUT (17.56%), 83,797 registers (12.28%), 6.5 BRAM tiles (0.87%), and 2,030 DSPs (57.54%).
- The word-atomic pre/post-DPD elastic slices remain functionally covered by targeted thermo3/thermo5 bit-true XSim (64 words / 2,048 output complex samples, zero mismatch), project P0 7/7, and IP smoke 5/5.  The full passing OOC is fabric-only: it does not prove GTH target timing, physical serializer/PA paths, board loopback, or RF performance.
- Remaining warnings include OOC `HD.CLK_SRC`/`HD.PARTPIN_LOCS` estimation warnings and synthesis trimming messages.  They are non-critical in this OOC run, but actual board/GT integration must supply real clock and boundary constraints.  Next action: run the equivalent full thermo5 OOC rather than extrapolating from thermo3.

## 2026-09-21 - Runtime identity-DPD input route isolation

- The last complete thermo3 AXI/FIFO/frontend routed OOC (`20260920_230344`) is `FAIL_SETUP`: WNS `-1.524 ns`, WHS `-0.019 ns`, with 0 errors and 0 critical warnings.  The limiting path is an inter-module route from first-x2 output to a memory-DPD DSP input: `5.809 ns`, of which `5.732 ns` is routing (fanout 173).  It is not a DSP arithmetic path.
- Added a word-atomic elastic buffer before the 16-lane runtime identity memory-DPD; the existing post-DPD buffer is retained.  The change preserves all fixed-point data and DPD-history semantics and adds only fixed latency.  Fresh targeted thermo3/thermo5 XSim both pass 64 words / 2,048 complex output samples with zero mismatch (940 ns / 970 ns respectively).  Required P0 runs 7/7 and the five IP-smoke tests complete without errors.
- Vivado 2024.1 then reproduced two optional realtime-helper failures while opening vendor `unimacro_vhdl.tcl` and `unimacro_verilog.tcl`; both files exist and are SHA-256 readable.  Updated the OOC Tcl to unset `BUILTIN_SYNTH` before `synth_design`, disabling only the helper pre-spawn path while retaining normal synth/place/route/STA.  A new thermo3 routed OOC is in progress; no new WNS/WHS is claimed until its `summary.csv` exists.
- The rerun completed routed implementation with 0 errors and 0 critical warnings but remains `FAIL_SETUP`: WNS `-1.392 ns`, WHS `-0.019 ns`.  The input elastic buffer is preserved in the netlist, but the worst setup path is still its packed-data register to a memory-DPD DSP input (`5.656 ns`, `5.578 ns` routing, fanout 173).  This is a `+0.132 ns` setup improvement over the preceding `-1.524 ns`, not closure.  Vivado reports that timing-driven physical synthesis was skipped in the current `place_design -directive Quick` flow; a full timing-driven implementation is required for a fair comparison to the earlier single-clock passing OOC.
- Added explicit `quick|full` implementation selection to the OOC scripts.  The `full` mode retains the same RTL and clock targets but runs `opt_design -> place_design -> phys_opt_design -> route_design`.  A direct environment-variable workaround did not reliably suppress Vivado's internal helper; the OOC Tcl now restores the vendor realtime database and explicitly sets `enableParallelHelperSpawn=false`.  The resulting full thermo3 run passes the previous helper-startup point and is in synthesis; no full-flow WNS/WHS is available yet.

## 2026-09-20 - OOC rerun helper failure

- The first routed-OOC retry after adding the accumulation stage did not reach HDL elaboration or STA: Vivado 2024.1 failed during `synth_design` because its realtime helper reported `retarget_vhdl.tcl` unreadable.  The referenced vendor file exists at the reported path; this is an intermittent tool/helper failure rather than RTL, DRC, or timing evidence.
- Retried the identical isolated thermo3 OOC in a new Vivado process.  The prior valid routed result remains WNS `-0.397 ns`, WHS `+0.001 ns`; no substitute timing conclusion is made from the failed retry.
- A second fresh process repeated a missing helper-Tcl error; a third passed helper startup and RTL component statistics but terminated with `EXCEPTION_BREAKPOINT` before placement.  Vendor Tcl files were independently verified present and hash-readable, and no stale Vivado process or memory exhaustion was found.  Further timing closure is blocked on a stable Vivado execution, not a reproducible RTL failure.

## 2026-09-20 - Pipeline second-interpolator accumulation

- The routed thermo3 OOC after removing the DSP clock-enable fanout completed with WNS `-0.397 ns` and WHS `+0.001 ns`.  Setup is improved by `+1.598 ns` over the preceding run and hold is now closed, but the design remains `FAIL_SETUP`.
- The worst path is now arithmetic-only: second-x2-interpolator DSP product register through four-term ACC_W addition and signed round/saturate to an output register (`4.918 ns`, 12 logic levels).  The former valid/CE route is no longer the limiting path.
- Added a third elastic stage between accumulation and round/saturate.  Its accumulator uses the exact legacy ACC_W procedural sum; valid remains word-atomic and datapath writes stay unconditional for invalid slots.  Thus the change adds one fixed core cycle only.
- Thermo3/thermo5 bit-true XSim pass after the change (64 words / 2,048 output complex samples).  Project P0 completes 7/7 PASS and IP smoke completes 5/5 PASS.  A new complete thermo3 routed OOC is running at the unchanged 218.75 MHz target.

## 2026-09-20 - Remove second-interpolator valid clock-enable fanout

- The third full thermo3 routed OOC completed at WNS `-1.995 ns`, WHS `-0.019 ns`, with 0 errors and 0 critical warnings.  It improved setup by `+0.219 ns` over the frame-gain-pipelined run but remains unclosed.
- Root cause moved to the second x2 interpolator: elastic occupancy `full_reg` drove the stage-1 multiplier DSP `CEA2` enable through a fanout-672 control net (`6.219 ns` route in a `6.386 ns` path).  It is a control-distribution path, not a multiplier arithmetic limit.
- Changed the two elastic interpolator stages to write payload datapath registers whenever their slot advances.  Invalid payload values are explicitly don't-care and remain blocked by the separately pipelined word-valid bit; history still changes only for an accepted valid input word.  This preserves coefficient, fixed-point, ordering, state, and latency contracts.
- Targeted thermo3 and thermo5 bit-true XSim pass (64 words / 2,048 output complex samples).  Project P0 completes 7/7 PASS and IP smoke completes all five tests PASS.  A new thermo3 routed OOC is running; no timing-pass claim is made before its final WNS/WHS are available.

## 2026-09-20 - Localize runtime-DPD valid control for frontend timing closure

- Replaced the thermo TID's single enable with eight registered lane-bank enables per TID plane.  A single accepted packed word is first captured in a fixed one-core-cycle input register; each bank then updates only its local four-lane state slice.  This preserves the temporal state transition, quantization, raw-bit ordering, and only adds fixed latency.
- Changed the post-DPD elastic slice so a valid DPD word controls only its one-bit occupancy state; when the slice is writable it captures the wide payload unconditionally.  This removes the `in_valid` clock-enable fanout to 512 payload registers without changing valid/ready semantics.
- Targeted thermo3/thermo5 MATLAB-to-XSim vectors pass (64 words / 2,048 output complex samples, zero raw mismatch).  The required P0 regression is 7/7 PASS and the DSM IP smoke suite is PASS.
- A fresh full ZU15EG thermo3 routed OOC after the lane-bank change completed with WNS `-3.052 ns`, WHS `-0.019 ns`, 0 errors, and 0 critical warnings.  This is an improvement from `-7.183 ns`; its new limiting net is the DPD output-valid to the elastic payload CE (fanout 513, 7.439 ns route), confirming the remaining control-fanout root cause.
- The follow-up implementation with the elastic-payload CE removal is currently running.  No 218.75 MHz timing-pass or GTH/board claim is made until that routed STA completes.

## 2026-09-20 - Move thermo3 frontend bottleneck from control to frame-gain datapath

- The routed thermo3 OOC with the elastic-payload CE removal completed at WNS `-2.214 ns`, WHS `-0.019 ns`.  This is a further `+0.838 ns` setup improvement.  The DPD-valid fanout is no longer the worst path.
- The new worst path is `dsm_frame_gain_vector`: Q2.14 gain register to output vector register through one DSP48E2 multiply, signed round/saturate logic, and 13 logic levels (`6.768 ns`, including `4.359 ns` route).  This is an arithmetic-pipeline issue, not a CDC or FIFO failure.
- Split gain multiply and round/saturate into separate elastic stages.  The change adds one fixed core-clock latency without changing Q2.14 arithmetic, frame-start gain selection, sample ordering, or backpressure behavior.  Thermo5 bit-true XSim, P0 7/7, and IP smoke all pass after the change.
- A third full ZU15EG thermo3 routed OOC is running to measure this datapath-pipeline change.  Timing remains unclosed until it produces a positive setup and hold result.

## 2026-09-19 - Close ZU15EG CDC gearbox routed STA

- Replaced the optional 14:8 CDC gearbox's dynamic residual part-select/mux network with the equivalent fixed seven-state sequence (`0, 6, 12, 4, 10, 2, 8` residual samples).  This preserves 14-complex AXI beats to 8-complex core words, lane-0-first ordering, frame/gain rules, and the exact 1.75 GS/s average rate while producing a regular synthesis network.
- The generic Gray FIFO and FPGA XPM FIFO asynchronous XSim tests both passed after the change: 112 contiguous complex samples, 14 core words, zero order/frame/gain mismatches, no bubbles, no underflow, and no protocol error.
- Routed the complete XPM CDC wrapper on `xczu15eg-ffvb1156-2-i` with 125 MHz and 218.75 MHz asynchronous clock groups.  The result passes: WNS `+1.807 ns`, WHS `+0.042 ns`, TNS/THS zero, 896 LUT, 749 FF, 6.5 BRAM tiles, and 0 DSP.  This supersedes the earlier tool-crash-only CDC status; it is fabric/CDC PPA evidence, not a thermo5 frontend or GTH target signoff.
- Re-ran required project regressions: P0 XSim 7/7 PASS and IP smoke (top, AXI, active reset, BP AXI, DPD v1.1) PASS.  The required baseline DSM OOC run on `xc7z020clg400-1` found 12/14 PASS; `p0_ooc_mb_ef2` fails 100 MHz setup by `-0.093 ns`, and `p0_ooc_mb_mash22` by `-0.688 ns`.  These two independent base-IP timing risks are recorded for follow-up and are not attributed to the CDC wrapper.
- Remaining limitation: no four-GTH target STA, board loopback/BERT, or physical PA evidence exists.  The next implementation action is the distinct DPD-free thermo5 frontend routed OOC, then the main-path PPA comparison.

## 2026-09-19 - Add FPGA XPM CDC implementation and reproduce tool failure

- Added an FPGA-only `xpm_fifo_async` implementation for the optional `125 MHz / 14-complex AXI-S -> 218.75 MHz / 8-complex` ingress, while retaining the existing Gray-pointer FIFO as the generic RTL reference.  XPM uses a common reset, so source traffic begins only after both clock domains leave reset and the FIFO prefill contract is satisfied.
- Added an XPM-specific asynchronous-clock XSim and updated the existing CDC test to prefill before enabling the recursive core.  Both generic and XPM tests pass 112 contiguous complex samples through the 14:8 gearbox with no order, frame/gain, bubble, underflow, or protocol mismatch.
- Repeated the ZU15EG CDC OOC with XPM block memory and the same `AreaOptimized_high` directive as the known-good thermo5 core.  RTL parsing and `synth_design` completed, but Vivado 2024.1 crashed with `EXCEPTION_ACCESS_VIOLATION` while loading part/timing information before checkpoint, utilization, placement, or STA.  No CDC WNS/WHS/resource result is claimed.
- Added isolated routed XPM probes to distinguish the FIFO primitive from the full wrapper.  Both pass on `xczu15eg-ffvb1156-2-i`: 32-bit FIFO WNS/WHS `+3.250/+0.041 ns`, 0.5 BRAM tile; production-width 465-bit FIFO WNS/WHS `+2.907/+0.039 ns`.  This is valid FIFO PPA evidence, but not full CDC-wrapper timing.
- Revised the FPGA XPM branch to use the AXI/system reset as its single FIFO reset; `core_aresetn` separately resets the gearbox/consumer, and integration must assert both resets together.  The XPM CDC test remains bit-true.
- Full CDC OOC remains blocked by intermittent Vivado realtime-helper failures (`rtSynthCleanup.tcl`/`unimacro_vhdl.tcl` reported absent despite existing on disk) or `EXCEPTION_ACCESS_VIOLATION`.  Checks: CDC generic XSim PASS; CDC XPM XSim PASS; project P0 XSim 7/7 PASS; DSM IP smoke (top, AXI, active reset, BP AXI, DPD v1.1) PASS.  Next action is to rerun full CDC OOC in a stable Vivado process or repaired installation before recording full PPA.

## 2026-09-19 - Make thermo5 primary path DPD-free

- Set `tid32_thermo5_frontend_tx` to `BYPASS_DPD=1` by default.  The selected generate branch directly joins the two x2 interpolators, so no memory-DPD module is instantiated or synthesized; coefficient ports remain only as a stable compatibility boundary.
- Updated the MATLAB oracle and XSim compilation list to exclude the identity-DPD stage and all DPD RTL.  The DPD-free frontend XSim passed 64 ingress words, 2,048 final complex samples, and all four raw planes with zero mismatch.
- Two fresh ZU15EG OOC attempts failed before HDL elaboration in the Vivado realtime helper (`missing realtime Tcl`, then `rt-undefined`).  No new WNS/WHS or resource result is claimed; the older identity-DPD OOC remains historical evidence only.
- Next action: repair or isolate the Vivado helper environment, rerun routed DPD-free OOC, then compare thermo3/thermo5 and interpolation choices for PPA.

## 2026-09-19 - Retire unclosed temporal BP/SMASH experiments

- Removed the CRFB-SMASH temporal8/temporal64 prototype and the TID32 MASH1-1 experiment, including their dedicated MATLAB models, vectors, XSim testbenches, and OOC scripts.  They had useful research evidence but did not constitute a deployable 64-lane streaming implementation.
- Retained scalar BP/EFDSM/MASH IP, the P0 regression set, and the thermo5 frontend.  The behavioural screening script no longer advertises the removed CRFB candidate.
- Rationale: keep the repository focused on the bit-true, routed thermo5 digital frontend and prevent unclosed experimental temporal chains from being mistaken for a 218.75-MHz implementation.
- Checks after removal: MATLAB P0 passed all seven designs at 65,536 samples with zero mismatch; XSim P0 passed 7/7; IP smoke passed top, AXI, active-reset, BP-AXI, and DPD-v1.1.
- Remaining limitation: this cleanup does not create four physical GTH or PA paths; serializer/PA evidence remains simulation-only until board resources exist.

## 2026-09-19 - Four-path raw serializer loopback contract

- Added a simulation-only four-path raw-64 serializer/receiver model and a full thermo5 frontend loopback test.  Each path serializes `TXDATA[0]` first at a 64x serial clock, and all paths share reset and word cadence.
- Corrected the initial model so the launch edge emits bit 0.  The prior version consumed 65 serial edges per word and reinterpreted a level-valid word as repeated requests; the toggle-based launch contract now consumes each user handshake exactly once.
- The full frontend serializer loopback passed: 64 ingress words recovered on all four paths, 4,096 serial bits per path, zero word mismatches.  This is functional digital evidence only; it is not a GT analog, channel, PA, or board-loopback result.
- Added `fpga/zu15eg/THERMO5_FOUR_PA_SERIALIZER_CONTRACT.md`.  The current public board mapping remains dual-SFP only, so four physical GT/PA pin assignments are deliberately left pending actual board resources.

## 2026-09-18 - Five-level streaming frontend RTL and routed OOC

- Added the Q2.14 `dsm_frame_gain_vector` streaming contract and the complete `8-lane -> x2 polyphase -> identity memory-DPD -> x2 polyphase -> thermo5` frontend wrapper.  Frame gain is accepted with its frame-start word, is applied to that word, and remains active until the next accepted frame start; reset initializes unity gain.  The deployed memory-DPD coefficients remain identity because the held-out qualification gate remains rejected.
- Added a MATLAB vector generator, a four-plane XSim testbench, and a ZU15EG OOC flow for the wrapper.  The new frontend XSim passed 64 ingress words / 2,048 final complex samples with zero mismatches on all four raw planes, including three frame-gain changes.
- Routed `xczu15eg-ffvb1156-2-i` OOC at 218.75 MHz passed: WNS `+0.178 ns`, WHS `+0.027 ns`, TNS/THS zero, 0 critical warnings, and 0 errors.  Post-route utilization is 70,233 LUT, 88,839 FF, 2,064 DSP48E2, and 0 BRAM.  The OOC timing report warns that `HD.CLK_SRC` is unset and some OOC boundary ports have no `HD.PARTPIN_LOCS`; this is a fabric result, not a board/GTH clock-skew or serializer signoff.
- Re-ran the required checks: MATLAB P0 (seven designs, 65,536 samples each, zero mismatch), project XSim P0 (7/7 pass), and IP smoke (top, AXI, active-reset, BP-AXI, and DPD-v1.1 pass).

## 2026-09-18 - Strict five-level 250-MHz fair-RMS gate

- Upgraded `entry_tid32_thermo5_fullchain_250_mild_three_seed.m` from an insufficient 2/2/3-symbol smoke to isolated 12/10/12-symbol fit/validation/held-out frames.  The fixed fair-RMS drive remains `0.095`; its worst measured PAPR over the nine fixed frames is `3.6673`, so it remains below the explicit 0.35 peak contract.
- The full two-x2-interpolator, four-branch behavioural DPA/BPF/DDC chain has zero raw-word mismatches for all three seed sets, but only the first set passes: `3.2241%` EVM / `29.8318 dB` SNDR.  The second and third are `4.5765%` / `26.7894 dB` and `4.5525%` / `26.8350 dB`.  Therefore 250 MHz is not qualified under a constant-RMS drive policy.
- Added a separate peak-normalized 12/10/12-symbol entrypoint.  It is an explicitly different, unclipped per-frame drive policy and will be reported separately from fair-RMS; it is not a replacement for the failed constant-average-power gate.

## 2026-09-18 - Peak-normalized five-level 250-MHz identity baseline

- The new full-chain peak-normalized gate uses the same mild behavioural DPA/BPF/DDC profile, two x2 interpolators, four code planes, BPF/DDC receiver, independent 12/10/12-symbol frames, and three seed sets as the strict fair-RMS run.  It scales each input frame without clipping to the fixed 0.35 peak contract; consequently the average drive is PAPR dependent and this result is intentionally not comparable as a constant-power result.
- All three identity cases pass with zero raw-word mismatches: `2.8221%` / `30.9884 dB`, `3.0846%` / `30.2161 dB`, and `3.1831%` / `29.9432 dB` (EVM / SNDR).  This is the first accepted 250-MHz **parameterized behavioural** point for the complete digital/DPA/BPF/DDC model, not a PA measurement, GTH target result, physical four-serializer result, or board result.
- Added the matching four-tap Q2.14 memory-DPD three-seed qualification entrypoint.  Its validation and held-out results must both improve before any coefficient replaces the identity RTL deployment.

## 2026-09-18 - Peak-normalized 250-MHz memory-DPD gate

- Ran the four-tap Q2.14 1/3/5 memory-polynomial indirect-learning candidate against the accepted peak-normalized identity baseline, using the identical mild four-branch DPA/BPF/DDC profile and isolated 12/10/12-symbol seed sets.  All six identity/candidate endpoints retained zero raw-word mismatches.
- The candidate is not deployable: seed 101 regressed from `2.8221%` / `30.9884 dB` to `2.9352%` / `30.6472 dB`; seed 307 regressed from `3.0846%` / `30.2161 dB` to `3.1281%` / `30.0945 dB`; only seed 503 improved marginally from `3.1830%` / `29.9432 dB` to `3.1796%` / `29.9525 dB`.  The first two validation gates also regressed, so `HeldOutDeploymentAccepted=0` and the Q2.14 RTL coefficients remain identity.
- This is a generalization decision, not a statement that DPD cannot help another PA profile.  Further DPD work must follow a demonstrated frontend/drive improvement and retain the same isolated train/validation/held-out gate.
- Re-ran `scripts/run_matlab_p0_bittrue_check.cmd`: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111, and MASH22 all passed 65,536 samples with zero mismatch.

## 2026-09-17 - Five-level full-frontend 250-MHz isolation

- Parameterized `run_tid32_thermo3_frontend_pa_dpd.m` for an explicitly selected three- or five-level thermometric TID while retaining its default three-level behavior.  The five-level wrapper reuses the same two x2 interpolators, Q2.14 memory-DPD interface, DPA/BPF, DDC, OFDM receiver, and acceptance rules; it does not fork a second, drifting behavioral chain.
- Added five-level full-chain/profile entrypoints.  Four-plane raw-word sanity at 250 MHz passed with zero mismatches; ideal RF/DDC NMSE was `1.0981e-4`.
- The complete 250-MHz frontend does not yet qualify: even ideal four-path PA/BPF returned `5.4454%` EVM / `25.2794 dB` SNDR.  Nominal DPA/BPF identity returned `3.7758%` / `28.4598 dB`; four-tap memory-polynomial DPD returned `3.8513%` / `28.2878 dB` and was rejected by validation and held-out gates.  The synthetic mild profile failed all three isolated seeds, worst case `4.1122%` / `27.7185 dB`.
- The evidence isolates the current limit to the two-stage frontend/TID working point before DPA compensation.  Next work is polyphase image-rejection and drive/threshold co-optimization, followed by the same three-seed DPA/BPF/DDC gate.  No 250-MHz full-system, GTH, PA, or board claim is made.
- A six-tap causal Lagrange x2 exploration improved ideal-PA EVM from `5.4454%` to `5.0474%` but did not meet the gate.  A 31-tap windowed-sinc exploratory mode produced `5.7814%`; its group delay is not yet represented by the OFDM crop/equalizer contract.  It is MATLAB-only and deliberately not promoted to RTL.  The default four-tap MATLAB/RTL contract is unchanged.

## 2026-09-17 - Five-level thermometric RTL milestone

- Added the conservative four-branch `tid32_thermo5_fs4_multipa_tx` RTL, its MATLAB fixed-point vector generator, bit-true XSim testbench, and a ZU15EG 218.75-MHz OOC flow.  The four branch thresholds are `{+3, +1, -1, -3} * STEP`, producing four aligned raw code planes for a five-level thermometric switching-PA architecture.
- Corrected only the testbench memory loading topology after `$readmemh` failed to load a selected row of an unpacked two-dimensional memory reliably.  The testbench now uses four one-dimensional memories; RTL arithmetic, state update order, quantization, and vector contents are unchanged.
- Checks: five-level MATLAB-to-XSim PASS for 128 continuous words / 4,096 complex samples with zero mismatches on all four raw streams.  Routed ZU15EG OOC at 218.75 MHz PASS: WNS `+2.894 ns`, WHS `+0.030 ns`, estimated Fmax `596.15 MHz`, 22,699 LUT, 21,464 FF, 0 BRAM, 0 DSP.  Required P0 regression PASS: 7/7 designs, 65,536 samples each, zero errors.  Required IP smoke completed and passed its top, AXI, active-reset, BP-AXI, and DPD-v1.1 tests.
- Limitation: the result verifies only the four-code-plane fabric.  It is not a four-GTH target STA, physical four-PA implementation, board loopback/BERT result, full DPA/BPF/DDC qualification, or a 250-MHz system claim.

## 2026-09-17 - Five-level 250-MHz digital receiver gate

- Added `entry_tid32_thermo5_250mhz_three_seed_rawddc.m` to make the five-level raw-Fs/4 acceptance reproducible.  It uses `STEP=7168`, three isolated seeds (`101/307/503`), eight OFDM symbols per seed, fair-RMS drive `0.11`, the physical raw Fs/4 DDC receiver, and a 0.35 peak-drive ceiling.
- The initial fair-RMS `0.13` trial correctly stopped at the input peak assertion: the 250-MHz OFDM waveform exceeded the configured 0.35 peak drive.  This is an explicit back-off constraint, not a timing or bit-order failure.
- At RMS `0.11`, actual occupied bandwidth `249.51171875 MHz` / OSR `28.055`, all three seeds passed with zero raw-stream mismatches.  Worst case was `3.2249%` EVM and `29.8298 dB` SNDR; maximum input peak was `0.3220`.
- This is a digital raw-TID/Fs/4/DDC receiver gate.  The current result excludes both x2 interpolators, the memory-DPD deployment path, behavioral DPA/BPF, four-GTH target STA, and board verification; it must not be presented as a full 250-MHz transmitter signoff.

## 2026-09-17 - ASIC synthesis preflight

- Added the reviewed `asic-dc-preflight` Rocky bridge task and ran it through the audited Windows-to-Rocky bridge.  Rocky 8.10 resolves `dc_shell` at `/opt/Synopsys/syn/V-2023.12-SP1/bin/dc_shell`.
- The preflight stopped before synthesis because `DSM_ASIC_STDCELL_DB` is unset.  No standard-cell `.db`, mapped netlist, PPA number, or ASIC timing claim was generated.  A permitted nominal logic-cell `.db` is required before probing the library and running the existing pre-layout DC flow.

## 2026-09-17 - Readable DPD deltas and five-level TID feasibility screen

- Updated `plot_tid32_thermo3_dpd_four_way_delta.m` to give every non-identity DPD its own `DeltaPSD` panel (negative is lower BPF-side emission).  It makes explicit that the four-tap candidate is best only on one held-out EVM/SNDR point, not on ACLR; no visual inference of deployment quality is made.
- Added a behavioral four-branch five-level thermometric TID oracle and an offset-step screen.  Every screened point had zero temporal32/scalar raw mismatch.  The original screen used an I/Q shortcut that bypassed the raw Fs/4 sequence and produced a false low-bandwidth failure.  After replacing it with direct 14-GS/s Fs/4 DDC, fixed-RMS/seed-101 smoke passes at 17.09 MHz: thermo3 `3.0637%` / `30.275 dB`, and thermo5/step-6144 `3.0613%` / `30.282 dB`; the corresponding 99.12-MHz values are `1.4275%` / `36.909 dB` and `1.2639%` / `37.966 dB`.  These are single-seed behavioral screens only; no five-level RTL, serializer, or wideband deployment claim is made.
- Re-ran the existing two-stage MASH TID XSim: PASS for 128 words / 4,096 samples on both code planes.  Its previously recorded routed OOC remains timing-clean, but the independent OFDM qualification remains failed; more MASH stages are frozen pending a corrected transfer equation.
- Added input RMS/peak reporting, fixed-RMS mode, and selectable raw-Fs/4 DDC receiver mode to the OFDM screen.  The current sweep defaults to the raw DDC path; the I/Q shortcut is retained only to reproduce legacy data.
- In the same raw-DDC, fixed-RMS, seed-101, four-symbol smoke, thermo5/step-6144 also passes 157.23/198.24/239.26/259.77/276.86 MHz occupied bandwidth (OSR `44.52/35.31/29.26/26.95/25.28`).  The 276.86-MHz edge point is `3.4209%` EVM and `29.3171 dB` SNDR.  This is a single-seed behavioral feasibility boundary, not a DPA/BPF/full-frontend or RTL/FPGA qualification.

## 2026-09-17 - Four-way thermo3 DPD stress comparison

- Added `plot_tid32_thermo3_dpd_four_way_stress.m` plus a non-interactive entrypoint.  The comparison holds the exact thermo3 frontend, two switching-PA paths, BPF/DDC, 17.09-MHz OFDM frame, seeds, and synthetic memory-stress profile constant while changing only the DPD: identity, 1/3/5 memoryless polynomial, 16-bin LUT, or four-tap 1/3/5 memory polynomial.
- Held-out results were identity `2.0065% / 33.9512 dB`, memoryless `1.9927% / 34.0111 dB`, LUT `21.8888% / 13.1956 dB`, and four-tap memory polynomial `1.9664% / 34.1266 dB` (EVM / SNDR).  The LUT candidate fails 256-QAM.  All four raw-word checks were zero mismatch.
- None of the candidates met the existing validation/held-out deployment gate, so the vector16 RTL coefficient table remains identity.  The comparison is behavioral; LUT and memoryless candidates are not current vector16 RTL integrations.
- Exported PNG, PDF, metrics CSV, PSD CSV, and profile CSV under `matlab/out/tid32_thermo3_dpd_four_way_stress/`.  Checks: MATLAB P0 bit-true PASS (7/7 designs, 65,536 samples each, zero mismatch); no RTL changed.

## 2026-09-17 - Full-seed qualification and DPD spectrum export

- Added: `matlab/tx_bandpass_if/plot_tid32_thermo3_dpd_spectra.m`; updated the endpoint result to export diagnostic identity/candidate waveforms and made the MATLAB DPD model configurable for one to four active taps.
- Full 12/10/12-symbol, three-seed identity qualification passed for all three synthetic profiles at 17.08984375 and 19.6533203125 MHz.  Worst qualified case was mild/19.6533203125 MHz: 3.4734% EVM and 29.1849 dB SNDR.
- Exported nominal 17.09-MHz ideal/identity/candidate spectra plus EVM, SNDR and model-only ACLR CSV/PDF/PNG.  The candidate is diagnostic only: held-out EVM/SNDR regress versus identity, so deployment remains rejected.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).

## 2026-09-17 - Corrected severe-profile interpretation

- Corrected: `docs/exec-plans/active/execution-frontier.md`.
- The synthetic severe profile uses `Q=60`, which is a wider (not narrower) second-order BPF than nominal `Q=100` and mild `Q=140`.  Its preliminary 99.9755859375-MHz pass is therefore retained only as a coupled-model result; no single-parameter mechanism or physical-PA inference is claimed.

## 2026-09-17 - Parameterized profile/bandwidth screen

- Added: `matlab/tx_bandpass_if/run_tid32_thermo3_profile_bandwidth_sweep.m`.
- Added a reproducible synthetic mild/nominal/severe switching-DPA/BPF profile sweep around the unchanged full digital frontend.  OSR is explicitly evaluated at the 7-GS/s complex DDC interface, consistent with the baseline.
- Identity screen (4/4/4 OFDM symbols, one isolated seed triplet) passed through 19.6533203125 MHz for mild and nominal profiles and through 99.9755859375 MHz for the synthetic severe profile.  The severe result is attributed to its narrow behavioural BPF and is not a physical-PA claim.
- Memory-DPD candidate screen (2/2/2 symbols, same isolated seed triplet) accepted no candidate on held-out data; the RTL deployment table remains identity.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch); profile sweep raw-word checks were 0 mismatch.  No RTL changed, so XSim, OOC, and GTH STA were not rerun.

## 2026-09-17 - Digital/FPGA simulation scope

- Changed: `docs/exec-plans/active/execution-frontier.md`.
- Confirmed that this project is scoped to digital IC/FPGA implementation and parameterized PA/BPF/DDC simulation.  Physical PA characterization, coupler feedback capture, and measured-RF signoff are explicitly out of scope.
- Replaced the feedback-capture dependency with reproducible mild/nominal/severe behavioral-DPA profiles, isolated train/validation/held-out OFDM datasets, robust memory-DPD acceptance gates, and a complete 20-to-200 MHz simulated bandwidth sweep.
- No RTL, fixed-point behavior, simulation result, or hardware evidence changed.  No regression was required for this documentation-only scope decision.

## 2026-09-17 - Execution-frontier consolidation

- Changed: `docs/exec-plans/active/execution-frontier.md`, `docs/exec-plans/completed/20260917-152449-completed-history.md`.
- Moved completed implementation and verification milestones out of the active execution frontier.  The active document now records only the current architecture, signed evidence, acceptance gates, active risks, and dependency-ordered next actions.
- No RTL, fixed-point behavior, simulation vector, synthesis result, or board state changed.  `docs/exec-plans/completed/20260917-152449-completed-history.md` preserves the completed-history summary.
- Checks: `git diff --check` PASS.

## 2026-09-17 - Parameterized switching-DPA model and held-out DPD decision

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Replaced the gain-mismatch/linear-FIR PA surrogate with `behavioral_switching_dpa_v1`: per-branch pulse-density AM-AM thermal memory, polarity asymmetry, finite output FIR memory, analytic-signal AM-PM, and a causal second-order RLC-equivalent BPF (`Q=100`, `0.6 dB` insertion loss).  Every profile parameter is exported as `tid32_thermo3_frontend_pa_profile.csv`; the profile is configurable, not a measured PA calibration.
- Corrected the Fs/4 receiver to search both 14-to-7-GS/s timing phases rather than hard-code a phase.  The raw-word sanity gate remains 0 mismatches; the ideal BPF/DDC numerical gate is `1.8799e-6` NMSE at phase 0.
- Ran 12/10/12-symbol fit/validation/held-out 256-QAM OFDM DPD experiment.  The Q2.14 4-tap 1/3/5-order candidate improved validation from `2.5254 %` / `31.9535 dB` to `2.5122 %` / `31.9990 dB`, but regressed held-out test from `2.3917 %` / `32.4257 dB` to `2.3980 %` / `32.4032 dB`.  Deployment is rejected and the exported deployment table remains identity; the candidate table is retained for diagnosis.
- The identity DPA endpoint remains 256-QAM-decodable at 17.08984375 MHz occupied bandwidth / OSR 409.6.  Its model-only PA-side ACLR is `-24.0769 dBc` and causal-BPF-side ACLR is `-30.6297 dBc`; neither is physical-RF signoff.
- Checks: `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).  No RTL changed, so no XSim, Vivado OOC, or GTH timing result was rerun.

## 2026-09-16 - TID32 frontend RF/DDC gate and memory-DPD hold

- Changed: `matlab/tx_bandpass_if/run_tid32_thermo3_frontend_pa_dpd.m`, `docs/exec-plans/active/execution-frontier.md`.
- Added a raw-word receiver gate. The two thermometric PA words decode to the independent scalar thermo3 reference with 0 mismatches after the fixed 1,056-sample latency. Ideal equal-weight PA combining, ideal BPF, Fs/4 DDC, LPF and the required 14-to-7-GS/s odd-phase selection reproduce that decoded reference with normalized MSE `4.6754e-7`; this finite numerical value is from floating-point FFT filters, not a bit-order error.
- Corrected the end-to-end receiver's DDC decimation order and FFT/CP parameterization. The two causal x2 interpolators introduce a deterministic per-subcarrier response, so a separately generated validation OFDM frame now estimates one pilot channel coefficient per active subcarrier. At 17.08984375 MHz occupied bandwidth (OSR 409.6), ideal equal PA paths and no DPD give held-out EVM `2.1503 %` and SNDR `33.3501 dB`; the deliberately stricter single-complex-gain diagnostic is `4.3397 %` / `27.2507 dB`.
- Exercised Q2.14, four-tap, 1/3/5-order indirect-learning memory DPD on the current gain-mismatch/linear-memory PA model. The validation candidate marginally reduced rate-MSE (`0.99008` to `0.98747`) but failed the held-out OFDM test (`8.3732 %` EVM / `21.5422 dB`) versus identity (`1.1380 %` / `38.8773 dB`). The script now writes identity as the deployment coefficient table and preserves the rejected candidate separately; no memory-DPD coefficient is authorized for RTL programming.
- Checks: frontend RF/DDC raw-word gate PASS; ideal endpoint 256-QAM pilot-EQ gate PASS; nonideal-model DPD candidate held-out gate FAIL/rejected; `scripts/run_matlab_p0_bittrue_check.cmd` PASS (7/7 designs, 65,536 samples each, 0 mismatch).
- Limitation: the present PA branches are gain-mismatched linear FIRs, not a calibrated nonlinear DPA. Their ideal brick-wall BPF drives filtered ACLR to a numerical floor, so neither the reported filtered ACLR nor the rejected DPD candidate is RF-signoff evidence. A calibrated nonlinear PA/feedback model or measured feedback capture is required before another DPD-training attempt.

## 2026-09-15 — TID32 OFDM-domain qualification correction

- Changed: `matlab/tx_bandpass_if/tid_pipelined_first_order_step.m`, `matlab/tx_bandpass_if/run_256qam_tid32_ofdm_demod.m`, `docs/exec-plans/active/execution-frontier.md`.
- Corrected TID32 EFM signed-input handling to 16-bit offset binary and restored adjacent-MSB XOR at the output.  The initial time-domain pointwise OFDM score is retained only as historical debug data: it is not a QAM demodulation EVM.
- Added an OFDM receiver qualification path with startup/tail guards, CP removal, FFT and active-carrier EVM.  At 14 GS/s and Fs/4 = 3.5 GHz, occupied BW 17.08984375 MHz (OSR 409.6), scalar EFM is 3.3545 % / 29.487 dB and TID32 is 3.3658 % / 29.458 dB (EVM / SNDR); the TID32 de-interleaved stream has zero mismatches to scalar after its fixed 1,056-sample latency.
- Checks: `run_tid_pipelined_scalar_contract` PASS (8,192 samples, 0 mismatch); TID32 16-symbol OFDM demodulation PASS for EVM/SNDR.  RTL XSim, rerun OOC and GTH payload integration remain pending.

## 2026-09-15 — TID32 RTL word-level contract

- Added: `matlab/tx_bandpass_if/gen_tid32_bittrue_vectors.m`, `dv/verif/block/bp_dsm/tb/tb_tid32_cartesian_fs4_gt_tx_bittrue.sv`, `dv/verif/scripts/run_xsim_tid32_cartesian_fs4_gt_tx.ps1`.
- Added the payload-target board top and build Tcl.  SFP0 receives the actual TID32 raw word; SFP1 retains a distinct known word.  Its local source is explicitly a board smoke pattern, not a substitution for the future 256-QAM sample feeder.
- Checks: `run_xsim_tid32_cartesian_fs4_gt_tx.ps1` PASS — 128 words / 4,096 samples, MATLAB-to-RTL 64-bit GT word 0 mismatch.

## 2026-09-15 — TID32 routed OOC closure

- Check: `syn/run_ooc_tid32_cartesian_fs4_gt_tx.ps1` PASS on `xczu15eg-ffvb1156-2-i` at 218.75 MHz: WNS +3.045 ns, WHS +0.034 ns, TNS/THS 0, estimated Fmax 655.12 MHz; implementation completed with 0 critical warnings and 0 errors.
- Limitation: This is an OOC fabric result.  It does not replace the pending payload-plus-GTH target STA or physical SFP loopback.

## 2026-09-16 — TID32 20-MHz-class qualification boundary

- Check: The OFDM-domain TID32 screen at the next 4096-point grid point, 20.5078125 MHz occupied BW / OSR 341.33, returned EVM 3.8036 % and SNDR 28.396 dB.  This fails the fixed 256-QAM gate.
- Decision: Retain 17.08984375 MHz / OSR 409.6 as the only currently verified 256-QAM operating point for the single-bit first-order TID32.  Do not characterize it as a 20-MHz-qualified transmitter.

## 2026-09-16 — GTH timing target decoupled from ILA

- The ILA-bearing payload build stalled before main synthesis because its ILA OOC child terminated without an end marker; GT Wizard synthesis did complete.  No GTH payload STA result was produced.
- Added `USE_ILA` to the payload top and a no-ILA payload STA Tcl.  This preserves the ILA build for board bring-up while preventing a debug-core failure from blocking TID32+GTH timing signoff.

## 2026-09-16 — TID32 dual-SFP GTH payload closure

- Check: The no-ILA target routed on `xczu15eg-ffvb1156-2-i` with the real TID32 SFP0 payload and independent SFP1 known word.  Post-route detailed STA: WNS +0.480 ns, WHS +0.014 ns, TNS/THS 0.  Bitstream generation completed with 0 warnings, 0 critical warnings and 0 errors.
- Artifact: `D:/TraeTemp/tid32_cartesian_gt14_dual_sfp_sta_20260916/tid32_cartesian_gt14_dual_sfp_sta.bit`.
- Limitation: The local board source is deterministic payload smoke data.  Hardware loopback/BERT and a verified board 256-QAM sample feeder remain required.

## 2026-09-16 — Regression after TID32/GTH integration

- Checks: `dv/verif/scripts/run_xsim_p0_all.ps1` PASS — 7/7 configurations, 65,536 samples each, Failed=0. `dv/verif/scripts/run_xsim_ip_smoke.ps1` PASS, including BP AXI route and DPD v1.1 smoke.

## 2026-09-15 20:55 - Seven DSM scalar reference/temporal64 contracts

- Changed files: `matlab/tx_bandpass_if/dsm_scalar_transition.m`, `matlab/tx_bandpass_if/run_all7_scalar_reference_equivalence.m`, `matlab/tx_bandpass_if/run_all7_temporal64_contract.m`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: freeze observable sample phase and PA-branch outputs against the behavioral models that generate the EVM evidence before starting temporal64 RTL.
- Checks run: `run_all7_scalar_reference_equivalence('samples',16384)` and `run_all7_temporal64_contract('words',256)`; all seven candidates reported zero mismatch, and every packed word-end state matched the serial reference.
- Remaining limitation: these are MATLAB reference contracts only; no candidate has temporal64 RTL/XSim/OOC/GTH qualification yet.

## 2026-09-15 21:15 - Dual-SFP GTH CDC correction in progress

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: the clock-port target met WNS/WHS but methodology reported TIMING-7 because an RX-clocked ILA sampled `tx_ready` directly. TX and recovered RX user clocks are asynchronous domains.
- Change: added a marked two-flop TX-to-RX status synchronizer and an explicit asynchronous clock group.
- Checks run: P0 XSim 7/7 PASS; IP smoke 5 checks PASS. The corrected physical target build is still running; no board or final GTH claim is made.

## 2026-09-15 21:30 - Dual-SFP GTH CDC target timing closure

- Changed files: `fpga/zu15eg/rtl/ti64_raw_gt14_dual_sfp_loopback_top.sv`, `fpga/zu15eg/constraints/ti64_raw_gt14_dual_sfp_loopback.xdc`, `docs/exec-plans/active/execution-frontier.md`.
- Checks run: xczu15eg-ffvb1156-2-i dual-SFP `cdcfix` target route. Detailed STA: WNS +1.355 ns, WHS +0.014 ns, TNS/THS 0; methodology has zero critical warnings.
- Remaining limitation: TIMING-28 is a non-critical warning on auto-derived clocks used by the async group. Hardware loopback/BERT remains unrun; the result qualifies only the generic serializer platform, not DSM payloads.

## 2026-09-15 21:32 - CRFB-SMASH2 exact temporal8 RTL prototype

- Changed files: `rtl/tx_bandpass_if/crfb_smash2_temporal8.sv`, `docs/exec-plans/active/execution-frontier.md`.
- Reason: start the bounded 8-step transition-composition proof before attempting 16/64 samples.
- Checks run: `xvlog -sv rtl/tx_bandpass_if/crfb_smash2_temporal8.sv` PASS.
- Remaining limitation: MATLAB-vector XSim, state/stream bit comparison, and 218.75-MHz OOC are not yet run; the design is an exact serial composition prototype, not a timing-safe lookahead implementation.

## 2026-09-14 18:37 +08:00 — Cartesian x4/TI64 timing closure

- Replaced the unpipelined x4 vector polyphase FIR with a five-stage elastic
  implementation. Fixed-point arithmetic, rounding, saturation, history and
  lane ordering are preserved; latency increased.
- The final ZU15EG `TXUSRCLK2=218.75 MHz` routed build completed with zero
  errors and zero critical warnings: WNS `+0.387 ns`, WHS `+0.010 ns`, TNS/THS
  `0`, 20,835 LUTs, 21,203 FFs, 385 DSPs and 4 BRAM tiles.
- Checks: independent x4 bit-true XSim PASS; P0 XSim 7/7 PASS, 65,536 samples
  per test; five IP-smoke tests PASS.
- Remaining boundary: timing closure does not prove an SFP0 physical link,
  serialized word order, RF quality, or a 14 GHz RF carrier.

## 2026-09-14 18:45 +08:00 — Documentation consolidation and verification-first decision

- Consolidated current x4/TI64 design and implementation facts into `SPEC.md`
  and its required verification gates into `VPLAN.md`.
- Removed obsolete prototype, interview, resume, notebook, bridge, timing and
  duplicate evidence-index documents. `docs/exec-plans/` is deliberately
  unchanged.
- The next project milestone is digital verification closure before FPGA
  loopback or ASIC implementation.

## 2026-09-14 19:00 +08:00 - Stale experiment and generated-artifact cleanup

- Removed the unreferenced BP-EFDSM2 parallel/look-ahead/map-compose experiment family, its dedicated OOC launchers, testbenches/refmodels, raw-playback experiment, and RF7G MATLAB generator.
- Retained every static EDA task and its current source dependency: P0, IP smoke, TI64 core/frontend/x4 frontend, OOC, GT generation, and ZU15EG build flows.
- Removed explicitly scoped ignored Vivado/XSim/VCS caches, generated vectors, crash dumps, logs, and temporary PDF text; `.gitignore` now prevents their reintroduction.
- Checks: P0 XSim 7/7 PASS, IP smoke PASS, and Cartesian x4/TI64 frontend XSim PASS after cleanup. Restricted `fpga/hardware/`, `ads/`, and `data/` content was intentionally left untouched.

## 2026-09-14 22:55 +08:00 - Rocky VCS and board-connectivity preflight

- Added reviewed Rocky bridge tasks for a read-only VCS installation audit and linux64 compiler-launch probe.
- The VCS compiler exists at `V-2023.12-SP1/linux64/bin/vcs1`, but it explicitly rejects the active WSL2 kernel. The QAM-OFDM UVM task therefore fails before RTL compilation; no UVM or coverage result is claimed.
- Vivado 2024.1 Hardware Manager and local hw_server start correctly, but no JTAG target is visible at `127.0.0.1:3121`; no bitstream was programmed.
- Next action: connect and power the ZU15EG USB-JTAG path (or provide a reachable remote hw_server), then repeat target discovery before programming the x4/TI64 bitstream.

## 2026-09-14 23:10 +08:00 - Correct TI64 Fs/4 translation ownership

- Confirmed and fixed a duplicate Fs/4 translation in the Cartesian x4/TI64 path. The frontend now sends `[I,Q,I,Q]` to the TI lanes; TI64 alone applies the one-bit `+,+,-,-` translation.
- The prior x4 bitstream is invalid for 3.5 GHz IF/RF metric claims because the two sign translations cancel under odd-symmetric lane quantization.
- Checks: x4 frontend bit-true XSim PASS; P0 XSim 7/7 PASS; IP smoke PASS.
- Remaining: implement the vector memory-polynomial state chain and a waveform-level RF metric oracle before rebuilding/programming the corrected board image.

## 2026-09-15 08:45 +08:00 - Experimental BP-EFDSM4 candidate and 256-QAM screen

- Added an explicitly experimental, one-bit Fs/4 BP-EFDSM4 core with
  `v=x-2e[n-2]-e[n-4]`, its Python integer golden model, direct-input XSim
  bit-true test, and MATLAB screen candidate. Its linearized NTF is
  `(1+z^-2)^2`; this does not establish a usable stability range by itself.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS for 2,048 random/boundary samples;
  P0 XSim 7/7 PASS; IP smoke PASS. At 39.31 MHz occupied bandwidth and
  drive 0.15, the idealized 256-QAM screen reports 3.725% EVM, 28.578 dB SNDR,
  and -32.888 dBc ACLR. It improves the second-order candidates but misses the
  frozen 3.5% / 29.12 dB gate and is not a board, PA, or RF result.
- Corrected the x128/x256 ingress-rate planning contract: fixed 16-sample
  words arrive once per 32/64 output clocks respectively, not through a
  superficial x4-style data interface.

## 2026-09-15 09:00 +08:00 - EFDSM4 feasibility boundary and x128 cadence contract

- Parameterized the experimental BP-EFDSM4 feedback terms and ran an integer
  coefficient plus drive sweep. The only non-divergent nearby combination was
  the original `C2=-2, C4=-1`; high-resolution 39.31-MHz results over drive
  0.08--0.20 remain 3.724--3.727% EVM and 28.573--28.579 dB SNDR. No point
  meets the frozen 256-QAM gate.
- Added `dsm_interp_word_cadence16`, a synthesizable x128/x256 ingress timing
  contract. With x128 it accepts one 16-sample source word every 32 output
  words and records underflow; it intentionally contains no FIR arithmetic.
- Checks: BP-EFDSM4 Python-to-RTL XSim PASS (2,048 samples); interpolator
  cadence XSim PASS; P0 XSim 7/7 PASS; IP smoke 5/5 PASS. The x128/x256
  polyphase FIR and SMASH multi-output implementation remain active work.

## 2026-09-15 09:10 +08:00 - MASH multi-PA interface reset correction

- Added a research-only MASH1-1 multi-PA/serializer boundary which exposes the
  two quantizer bitstreams and the uncompressed four-level combiner result.
  It is explicitly not the paper-derived CRFB-SMASH candidate.
- Fixed `dsm_core_mash11` reset state for its delayed stage-2 sign from zero to
  positive one, matching its MATLAB model and preventing an illegal initial
  combiner level of zero or plus/minus two.
- Checks: multi-PA interface XSim PASS (128 samples); P0 XSim 7/7 PASS.

## 2026-09-15 16:55 +08:00 - Packed BP2 and MASH feasibility screen

- Added the exact temporal packed-BP2 oracle and the existing BP-MASH1-1
  multilevel combiner to the identical 256-QAM IF screen. At 39.31 MHz
  occupied bandwidth and drive 0.15, packed BP2 is exactly BP-EFDSM2:
  4.409% EVM / 27.114 dB SNDR / -22.543 dBc ACLR. BP-MASH1-1 reports 4.410%
  / 27.112 dB / -22.518 dBc. Neither meets the frozen 3.5% / 29.12 dB gate.
- The initial CRFB-SMASH2 oracle reports 99.892% EVM and is declared invalid
  pending a verified state-equation derivation; it is not used to judge the
  referenced CRFB-SMASH architecture and has no RTL implementation.
- Check: `run_256qam_dsm_if_screen` completed at Fs=14 GS/s, Fc=3.5 GHz with
  identical BPF/DDC/synchronization/demodulation settings for every candidate.

## 2026-09-15 17:00 +08:00 - MASH11 reset-contract correction

- MATLAB P0 comparison reproduced one MASH11 mismatch at sample 2 after an
  attempted reset change. The source-of-truth fixed-point model initializes
  the cancellation-delay state to zero, so RTL was restored to that contract.
  The multi-PA interface test now permits only the resulting first-sample
  +/-2 transient; all later values must be normal four-level codes.
- Checks after restoration: P0 XSim 7/7 PASS; MATLAB-to-RTL P0 comparison
  7/7 with zero mismatches over 65,536 samples each; IP smoke PASS; multi-PA
  interface XSim PASS (128 samples).

## 2026-09-15 17:10 +08:00 - CRFB-SMASH paper transfer-function audit

- Added `crfb_smash2_transfer_audit.m` from Xu et al. Fig. 2 and equations
  (7), (10), and (14). It reports per-stage and two-stage NTF polynomials,
  zeros, poles, stability, Fs/4 notch depth, and the three-level PA-code
  contract without pretending to be a fixed-point state model.
- Checks: at 14 GS/s and 3.5 GHz, `g=[2,2]`, `a=[-1,-1]` is stable with the
  expected `-(1+z^-2)^2` total NTF; `a=[-0.5,-0.5]` is also stable. The
  next required artifact is the Fig. 2 state-equation derivation and its
  independent fixed-point oracle, before RTL or 256-QAM qualification.

## 2026-09-15 17:20 +08:00 - Three-level BP DSM feasibility screen

- Added fixed-point three-level BP-EFDSM2 and BP-EFDSM4 behavioral models.
  The {-1,0,+1} output maps to two one-bit PA branches with fixed gain
  normalization; it does not alter the final 14-GS/s OSR.
- At the frozen 39.31-MHz/drive-0.15 256-QAM point, three-level BP2 reports
  4.371% EVM / 27.189 dB SNDR and three-level BP4 reports 3.726% / 28.575 dB.
  Neither meets the gate; quantizer level count alone is therefore not the
  acceptance path. Check: `run_256qam_dsm_if_screen` completed.

## 2026-09-15 17:30 +08:00 - Final-rate OSR and channel-bandwidth screen

- Swept requested 5/10/20/40 MHz channels at the fixed final interleaved
  rate of 14 GS/s and Fc=3.5 GHz. OSR is therefore Fs/(2B), not a function of
  the 218.75-MHz fabric clock or an ingress interpolation factor.
- At actual 9.40 MHz (OSR 744.7) and 19.65 MHz (OSR 356.2), BPDSM2,
  BP-EFDSM2, BP-EFDSM4, packed TI64-BP2 and the existing BP-MASH1-1 pass the
  frozen EVM/SNDR gate. BP-EFDSM4 at 19.65 MHz reports 2.078% EVM, 33.649 dB
  SNDR and -34.180 dBc ACLR. No candidate passes at actual 39.31 MHz (OSR
  178.1). The 5-MHz run has too few occupied tones/BPF FFT bins and is marked
  as an oracle-resolution issue pending a longer-vector rerun.

## 2026-09-15 17:40 +08:00 - CRFB-SMASH temporal-64 architecture constraint

- Verified Xu et al. equation (15), `v1=y1-y2` for two stages, and its stated
  de-interlacing/parallel-DSM/interlacing implementation with delay-register
  state propagation. The project CRFB route is consequently constrained to an
  exact 64-step state composition per word, not 64 independent DSM lanes.
- The scalar CRFB state transition remains the required predecessor; no
  temporal-64 RTL or timing claim is made yet.

## 2026-09-15 17:55 +08:00 - Causal CRFB transition and temporal-64 oracle

- Added the causal fixed-point scalar transition derived from the audited
  CRFB transfer functions, plus a 64-step composition contract. At
  `g=[2,2]`, `a=[-1,-1]`, scalar and temporal-64 agree on y1, y2, v1 and final
  state for 256 words / 16,384 random samples with zero mismatches.
- The checked CRFB transition replaces the invalid initial CRFB candidate in
  the common screen. It passes at 19.65 MHz: 2.075% EVM / 33.659 dB SNDR /
  -34.837 dBc ACLR; it fails at 39.31 MHz: 3.725% / 28.578 dB / -33.492 dBc.
- This is behavioral evidence only. A naive 64-way unroll is a 64-deep
  data-dependent chain and cannot inherit 203.125/218.75-MHz closure from a
  single scalar core. State-map lookahead/prefix composition is now the next
  implementation gate before RTL/OOC/serializer work.

## 2026-09-15 18:05 +08:00 - 256-QAM candidate consolidation

- Consolidated all behavioral-pass candidates at the actual 19.65-MHz,
  OSR-356.2 point. The two implementation branches are BP-EFDSM4 (single
  one-bit serializer) and CRFB-SMASH2 (two one-bit serializer/PA branches);
  other passing models remain comparison baselines.
- Existing 100-MHz AXI-IP OOC matrix has reached 48/70 rows, but contains
  neither exact-temporal64 BP-EFDSM4 nor CRFB-SMASH2. It is not evidence of
  timing closure for either selected branch.

## 2026-09-15 18:15 +08:00 - Unified temporal64 qualification scope

- Clarified the active rate as 64 lanes at 218.75 MHz = 14 GS/s (3.5-GHz
  Fs/4 IF). The 203.125-MHz figure belongs only to an alternate 13-GS/s rate.
- Every behavioral-pass candidate now has the same required qualification:
  scalar fixed-point, scalar-vs-temporal64 word/state equality, temporal64
  RTL, 218.75-MHz OOC STA, and raw-serializer ordering. One-bit candidates
  need one stream; CRFB/three-level candidates need two phase-aligned streams.

## 2026-09-15 18:20 +08:00 - GT serializer is a mandatory timing gate

- Expanded the qualification contract: 218.75-MHz fabric OOC proves only the
  raw-GT user-word boundary. Each candidate must also use a real 14-Gb/s GTH
  target-routed build, pass TXUSRCLK2/reset/clock timing, and demonstrate
  serialized-loopback/BERT recovered-word and bit-order equality. Multi-PA
  candidates require every phase-aligned serializer branch to pass.

## 2026-09-15 18:30 +08:00 - Two-PA GTH collateral audit

- Confirmed that the checked board integration supports one physical 14-Gb/s
  RAW GTH stream on SFP0/X1Y12, including its GT Wizard, 218.75-MHz user clock,
  target build and recovered-word observability. No checked second GTH/SFP
  channel constraints or clock/routing data are in the repository.
- CRFB/two-PA physical serializer work is blocked on that board collateral;
  pin assignment will not be guessed. Single-stream candidate integration can
  proceed independently after temporal64 RTL closure.

## 2026-09-15 19:25 +08:00 - Seven-candidate scope and SFP1 collateral recovery

- Replaced the active frontier with the concise seven-candidate qualification
  matrix requested for BPDSM2, BP-EFDSM2, BP-EFDSM4, both three-level BP
  variants, BP-MASH1-1, and CRFB-SMASH2. All seven now require the identical
  scalar-to-temporal64-to-GTH-to-loopback acceptance chain; no branch is a
  baseline-only exception.
- Inspected the repository's restricted ZU15EG schematic and vendor UCF
  without copying board collateral into project sources. They identify SFP1
  TX `D6/D5`, RX `C4/C3`, and the same quad-230 reference clock `C8/C7` used
  by SFP0. The adjacent GT site still requires a Vivado device-site query
  before a dual-channel Wizard or XDC is generated.
- Reviewed the verified 19.65-MHz screen data from
  `crfb_smash2_verified_screen/screen.csv`; it remains behavioral evidence
  only. The older OSR-sweep CRFB rows are retained as historical invalid-model
  output and must not be used for decisions.

## 2026-09-15 19:35 +08:00 - Seven scalar temporal64 contracts

- Added the common scalar fixed-point transition and exact 64-step composition
  harness for all seven requested candidates. The BP-MASH transition explicitly
  follows its behavioral bandpass reference rather than reusing the existing
  low-pass MASH RTL under a misleading name.
- Check: `run_all7_temporal64_contract('words',256)` PASS. Every candidate
  has zero mismatches across all emitted one-bit/level streams and an equal
  word-end state after 16,384 random samples.
- This is reference-model evidence only; the temporal64 RTL, 218.75-MHz STA,
  GTH route and board loopback gates remain open for all seven candidates.

## 2026-09-15 20:05 +08:00 - Dual-SFP GTH timing-root cause

- Added the two-channel SFP0/SFP1 RAW GTH infrastructure, including the
  `X1Y12 X1Y13` Wizard configuration, dual-channel wrapper, dual-SFP known
  word ILA top, and the board-derived SFP1 pins.
- The first target-routed build produced a bitstream with WNS `+1.419 ns` and
  WHS `+0.013 ns` at the real 218.75-MHz user-clock rate. Detailed STA still
  raised TIMING-3/6/7/14 critical warnings because manually created user
  clocks duplicated the Wizard's generated clocks. This build is explicitly
  not accepted.
- Removed the duplicate primary user-clock constraints while retaining the
  primary clock at the GT reference-buffer output. The next identical build
  must show the Wizard-derived 218.75-MHz clocks and zero critical warnings.

## 2026-09-15 21:49 +08:00 - CRFB temporal8 functional baseline and timing limit

- Added MATLAB-vector generation and XSim comparison for the exact eight-step
  CRFB-SMASH2 transition. The test now compares both two one-bit output words
  and all nine word-end state registers. Check:
  `run_xsim_crfb_temporal8.ps1 -Words 256` PASS, zero mismatches across 2,048
  samples.
- During bring-up every word mismatched. The RTL implemented quantization
  error as `u-q`; the audited scalar reference uses `q-u`. Correcting that
  sign restored bit-true output and state equality. The runner now requires
  an explicit XSim PASS marker instead of trusting the simulator exit code.
- Check: routed ZU15EG OOC at 218.75 MHz FAIL, WNS `-12.088 ns`, WHS
  `+0.453 ns`; implementation completed without critical warnings or routing
  failures. The causal eight-transition combinational chain is therefore a
  functional reference baseline, not a timing-safe lookahead or a 64-lane
  implementation. A finite state-map/branch-prediction representation is now
  required before further exact temporal64 RTL expansion.

## 2026-09-15 22:24 +08:00 - Exact CRFB scalar timing boundary

- Added a `STEPS` synthesis knob to the temporal8 prototype so the routed
  OOC flow can measure causal-chain depth without changing arithmetic,
  latency, or the normal eight-step functional contract.
- Check: at 218.75 MHz on `xczu15eg-ffvb1156-2-i`, `STEPS=1` fails routed
  STA: WNS `-0.909 ns`, WHS `+0.074 ns`. Explore placement/routing plus
  pre/post-route `AggressiveExplore` physical optimization improved it only
  to WNS `-0.827 ns`, WHS `+0.084 ns`.
- The failing path is 5.461 ns from `e1d2_r` to `e2d1_r`, including 31 logic
  levels (21 CARRY8) and 2.726 ns routing. The blocker is therefore the
  exact scalar fixed-point transition, not merely its 8/64-way unroll.
- The OOC runner now fails its PowerShell invocation when `summary.csv`
  reports timing `FAIL`; `-AllowTimingFail` is an explicit measurement-only
  override. Vivado's successful implementation exit code can no longer be
  mistaken for a timing pass.
- Regression checks after the RTL update: P0 XSim 7/7 PASS, IP smoke 5/5
  PASS, and the serial MATLAB-to-RTL P0 comparison 7/7 PASS (65,536 samples
  per design, zero mismatches). A first parallel MATLAB launch correctly
  failed because its P0 dump had not yet been generated; the final serial
  result is the valid evidence. The updated default `STEPS=8` temporal test
  also passes MATLAB-vector XSim for 256 words / 2,048 samples, including all
  two-branch output bits and nine word-end state registers.

## 2026-09-15 23:10 +08:00 - 14-Gb/s 256-QAM architecture correction

- Audited the Firmansyah MASc thesis equations for the pipelined first-order
  TIDSM and the MGS serializer. At `Fc=3.5 GHz`, its DSM sample rate is
  `2Fc=7 GS/s` and its MGS line rate is `4Fc=14 Gb/s`. With this project's
  fixed `218.75 MHz` fabric and 64-bit GTH user word, the matching topology
  is `L=32` polyphase channels per I and per Q path, not 64 independent
  real-valued LP1 lanes.
- The thesis-derived pre-summation / feedback / XOR architecture has a
  one-adder critical path independent of `L`; this is architecturally distinct
  from the exact 28-bit CRFB transition that failed at 218.75 MHz. The active
  implementation path is therefore a new fixed-point-reference pipelined Cartesian TIDSM,
  followed by payload GTH integration and loopback, rather than further CRFB
  unrolling.
- Corrected the active project scope after review: this is a fully digital
  `3.5 GHz` `Fs/4` transmitter with `14 GS/s` equivalent sample rate and a
  `14 Gb/s` raw-GTH line rate. It has no external LO/mixer. The number `14`
  must not be described as a 14-GHz RF carrier.

## 2026-09-15 23:28 +08:00 - Pipelined Cartesian TIDSM routed timing

- Added `tid32_cartesian_fs4_gt_tx`, its MATLAB fixed-point transition model,
  a ZU15EG OOC wrapper and a routed OOC script. The design implements 32
  polyphase channels per I/Q path and emits a 64-bit raw-GT word.
- Check: routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS, WNS
  `+3.053 ns`, WHS `+0.032 ns`, estimated Fmax `658.58 MHz`.
- `xvlog` compiled the RTL/wrapper and a 64-word MATLAB model smoke test
  passed. MATLAB-to-XSim vectors, 256-QAM metrics, GTH payload target-route
  and physical loopback remain open; this result alone is not a bit-true or
  transmitter-system acceptance claim.

## 2026-09-15 23:35 +08:00 - First TIDSM 256-QAM screen failure

- Added a standalone 256-QAM screen that drives the new 32-channel-per-I/Q
  fixed-point TIDSM at 7 GS/s, applies its deterministic 14-GS/s Fs/4 word
  ordering, and evaluates EVM/SNDR/ACLR.
- Check: the first run requested 19.65 MHz and used the nearest 4096-point
  OFDM occupied bandwidth of 17.08984375 MHz. Its equivalent OSR was 409.6,
  yet EVM was `99.420 %`, SNDR `0.050 dB` and ACLR `-7.857 dBc` (FAIL).
- The timing-clean TIDSM is therefore not accepted for any QAM modulation.
  The next investigation is the EFM input representation, STF/NTF and I/Q
  serializer sequence; MATLAB-to-XSim bit-true verification is intentionally
  deferred until those behavioral invariants pass.
- Regression check: `scripts/run_matlab_p0_bittrue_check.cmd` PASS for all
  seven retained legacy P0 designs, each with 65,536 samples and zero
  mismatches. This guards existing IP only; it does not validate the new
  TIDSM candidate.

## 2026-09-16 09:18 +08:00 - Two-stage Cartesian TID-MASH prototype

- Added a new `tid32_mash11_fs4_multipa_tx` architecture with two cascaded
  `L=32` first-order Cartesian TIDSM stages. Stage 2 receives the aligned,
  saturated stage-1 `x-q1` residual. The two raw stage streams remain separate
  64-bit PA/serializer branches; no lossy one-bit recombination is applied.
- Added the corresponding MATLAB fixed-point oracle, deterministic vector
  generator, XSim bit-true testbench, and ZU15EG routed OOC flow. The reset
  token and registered inter-stage handoff are explicit parts of the oracle.
- Checks: MATLAB-to-XSim PASS for 128 words / 4,096 I/Q samples with zero
  mismatches on both PA branches. Routed OOC on `xczu15eg-ffvb1156-2-i` at
  218.75 MHz PASS: WNS `+1.315 ns`, WHS `+0.029 ns`, TNS/THS `0`, estimated
  Fmax `307.08 MHz`; 14,276 LUT, 13,439 FF, 0 DSP, 0 BRAM.
- Regression checks: `run_xsim_p0_all.ps1` PASS, 7/7 tests at 65,536 samples;
  `run_xsim_ip_smoke.ps1` PASS.
- Limitation: this proves only fixed-point/RTL equivalence and fabric timing.
  The two PA branches are not yet connected to the dual-SFP GTH payload top,
  and no 256-QAM OFDM EVM/SNDR/ACLR qualification has been claimed.

## 2026-09-16 09:23 +08:00 - TID-MASH OFDM qualification failure

- Added a corrected OFDM-domain screen for the two-stage TID-MASH. It models
  the required MASH cancellation `y1 + y2 - z^-1 y2` as two 1-bit PA code
  planes with ideal 1:2 analog combining; direct equal-weight stage outputs
  are explicitly rejected as an invalid MASH realization.
- At 17.08984375 MHz occupied bandwidth and OSR 409.6, drive values
  `0.05/0.10/0.20/0.35` produced EVM `32.380/32.316/32.338/32.362 %` and
  SNDR `9.794/9.812/9.806/9.799 dB`. None meets the 256-QAM gates.
- Root cause: the current aligned `x-q1` inter-stage recurrence/cancellation
  does not have the required STF. This is algorithmic; routed TID timing and
  PA backoff cannot repair it. The prototype remains a functional/timing
  research baseline and is excluded from GTH payload integration.

## 2026-09-16 09:36 +08:00 - Three-level BP behavioral OFDM gate

- Extended `run_256qam_tid32_ofdm_demod.m` with a common OFDM/DDC receiver
  path for the fixed-point three-level BP-EFDSM2 and BP-EFDSM4 feasibility
  models. This is a scalar behavioral comparison only; it is not a TID RTL
  or serializer implementation.
- At 19.6533203125 MHz occupied bandwidth (OSR `356.17`), three-level
  BP-EFDSM2 measured EVM `1.5327 %`, SNDR `36.291 dB`, ACLR `-31.627 dBc`;
  BP-EFDSM4 measured EVM `1.5261 %`, SNDR `36.328 dB`, ACLR `-32.246 dBc`.
  Both pass the project 256-QAM EVM/SNDR gate in this ideal digital model.
- At 99.9755859375 MHz (OSR `70.017`), BP-EFDSM2 measured `2.2725 %` /
  `32.870 dB`, while BP-EFDSM4 measured `0.60936 %` / `44.302 dB`; both pass
  the same ideal-digital gate. At 999.755859375 MHz (OSR `7.0017`),
  BP-EFDSM4 fails: EVM `13.527 %`, SNDR `17.376 dB`.
- Consequence: three-level output is a credible bandwidth path, but it must
  first receive a derived scalar-vs-pipelined-TID state/output contract. No
  GTH, PA, or FPGA-ready claim follows from these behavioral results.

## 2026-09-16 10:32 +08:00 - Two-PA three-level Cartesian TID prototype

- Added `tid32_thermo3_fs4_multipa_tx`: two threshold-symmetric, `L=32`
  first-order Cartesian TID branches. The branches share acceptance and output
  readiness, so their 64-bit raw-GT words remain locked for two equal-weight
  1-bit serializer/PA paths. This is a thermometer-coded three-level TID
  implementation, not BP-EFDSM2/4.
- Added a MATLAB fixed-point transition/vector source, a 128-word two-branch
  XSim test, and a ZU15EG routed OOC flow. Checks: MATLAB-to-XSim PASS for
  128 words / 4,096 I/Q samples, zero bit mismatches on both raw streams and
  no valid-alignment failure.
- Routed OOC on `xczu15eg-ffvb1156-2-i` at 218.75 MHz PASS: WNS `+2.953 ns`,
  WHS `+0.033 ns`, TNS/THS `0`, estimated Fmax `617.88 MHz`; 11,170 LUT,
  10,732 FF, 0 BRAM, 0 DSP. Standard OOC clock-source/port warnings remain
  non-signoff limitations of OOC, not errors or critical warnings.
- The same RTL’s required regressions passed: P0 `7/7` (65,536 samples each)
  and IP smoke (top, AXI, active-reset, BP AXI, DPD v1.1).
- The ideal equal-weight combined OFDM model passes 256-QAM at actual
  19.6533203125 MHz / OSR `356.17`: EVM `1.5283 %`, SNDR `36.316 dB`, ACLR
  `-32.094 dBc`; at 99.9755859375 MHz / OSR `70.017`: EVM `1.0781 %`, SNDR
  `39.347 dB`, ACLR `-26.414 dBc`. A dual-SFP GTH payload target build,
  physical PA-combiner calibration, and board loopback/BERT are still open.

## 2026-09-16 10:54 +08:00 - Dual-SFP 14-Gb/s target closure

- Added `tid32_thermo3_gt14_dual_sfp_payload_top`: the two locked 64-bit
  thermometer code planes feed GTH `X1Y12` and `X1Y13`, sharing the 125-MHz
  reference, generated 218.75-MHz TXUSRCLK2, reset, and deterministic
  lane-distinct bring-up stimulus. This is a target-STA build, not an OFDM
  sample feeder.
- The first target build reproduced five hierarchy-specific clock-group
  critical warnings and was rejected. A payload-specific XDC with identical
  physical pins/primary clocks and no nonexistent TX/RX data crossing fixed it.
- Acceptance build `D:/TraeTemp/tid32_thermo3_gt14_dual_sfp_sta_20260916_104432/`
  produced the bitstream. Post-route STA: WNS `+0.324 ns`, WHS `+0.013 ns`,
  TNS/THS `0`; link, opt, place, phys-opt, route, and bitstream all reported
  0 critical warnings and 0 errors.
- Board loopback, physical two-PA equal-gain/phase alignment, BPF/DDC and RF
  EVM/SNDR/ACLR measurement remain required.

## 2026-09-16 - Repeatable OFDM bandwidth screen for thermo3 TID

- Ran the same ideal two-PA thermo3 TID receiver contract at 14 GS/s with
  `NFFT=16384`, `NCP=2048`, eight OFDM symbols, drive `0.35`, and five
  independent seeds (`11/29/47/71/101`).  The 229.86 MHz occupied point
  (OSR `30.454`) passed all five; the 234.99 MHz point (OSR `29.789`) also
  passed all five with EVM `3.188--3.246 %` and SNDR `29.772--29.930 dB`.
- At 237.55 MHz (OSR `29.468`) every completed seed failed the 256-QAM
  EVM/SNDR gate; 240 MHz showed mixed failures and 259.77 MHz failed all five.
  The highest repeatably tested passing point is therefore about 235 MHz;
  230 MHz is the current margin-bearing digital recommendation.  This is not
  an RF signoff because PA, clock/GT jitter, board loss, and physical filtering
  are not modeled.

## 2026-09-16 - Vector x4 interpolation and memory-DPD frontend

- Added a synthesizable ingress chain: eight complex samples per 218.75-MHz
  word, causal x2 polyphase interpolation, 16-lane shared-history 4-tap
  complex memory polynomial DPD, a second causal x2 stage, and the existing
  32-lane thermometer Cartesian TID output. The DPD supports Q1.15 complex
  coefficients for orders 1/3/5 and provides explicit cross-word tap windows.
- Added a matching fixed-point MATLAB vector generator and full-chain XSim.
  With nonzero test coefficients, 64 ingress words / 2,048 final complex
  samples produced zero mismatches on both PA raw bitstreams.
- Corrected `tid32_cartesian_fs4_gt_tx` valid handling: a bubble no longer
  repeats stale raw-GT data. Continuous raw-GT transmission remains a system
  contract; an upstream feeder FIFO must detect underflow rather than insert a
  bubble into a running RF stream.
- Checks passed: full-chain frontend XSim, P0 XSim `7/7`, IP smoke, and MATLAB
  P0 bit-true check. The ZU15EG frontend OOC has completed synthesis with zero
  errors/critical warnings and 2,064 DSP48E2; routed STA is still running, so
  no timing-closure claim is made in this entry.
- The first placed OOC result was not accepted: post-placement WNS was
  `-0.850 ns`. The four-tap DPD reduction is now a registered balanced tree;
  it preserves numerical results and adds one cycle of latency. The full-chain
  bit-true test, P0 `7/7`, and IP smoke were rerun successfully. A fresh OOC
  implementation is in progress; the interrupted prior run also reproduced a
  transient Vivado realtime-helper Tcl-file failure before HDL elaboration.

## 2026-09-16 - Frontend timing closure and RF-model boundary

- The revised `tid32_thermo3_frontend_tx_ooc` routed implementation on
  `xczu15eg-ffvb1156-2-i` now passes 218.75 MHz detailed STA: WNS `+0.255 ns`,
  WHS `+0.027 ns`, TNS/THS `0`. The implementation reported 0 errors and 0
  critical warnings. This closes the fabric OOC boundary only; it does not
  include GTH payload integration or board loopback.
- Added `run_tid32_thermo3_frontend_pa_dpd.m`, a behavioral endpoint scaffold
  for the exact `8 -> x2 -> 16-lane memory DPD -> x2 -> 32-lane thermo3 TID`
  path, two switching-PA paths, equal-weight combining, BPF/DDC, and Q2.14
  indirect-learning DPD fitting. Its first RF/DDC reconstruction fails its
  mandatory sanity check even with ideal PA paths. Consequently its present
  EVM/SNDR/ACLR values are not accepted as PA/DPD results: Fs/4 receiver
  phase, latency and reconstruction must first match the established digital
  TID receiver on the same raw-word vectors. An ideal brick-wall BPF also
  makes post-filter ACLR unsuitable as an ACLR claim.
- Re-ran the required MATLAB P0 fixed-point regression after adding the
  behavioral model: LPDSM, LPDSM2, EFDSM, EFDSM2, MASH11, MASH111 and MASH22
  each passed 65,536 samples with zero mismatches. The new RF model is outside
  that P0 scope and remains blocked by its independent receiver sanity check.
- Added a separately runnable raw-word gate to the same model. It decodes both
  generated 64-bit PA words into Cartesian I/Q and compares them with an
  independently stepped scalar thermo3 reference after the known 1,056-sample
  TID latency. The gate passed with 0 mismatches, which eliminates raw-word
  order, branch polarity, and TID latency as causes of the RF-model mismatch.
# 2026-09-19 - Add optional 125-MHz AXI-stream CDC ingress

- Added `dsm_async_fifo`, per-domain reset synchronizers, and the exact 14-complex-to-8-complex CDC gearbox.
- Added the optional `tid32_thermo5_axis_frontend_tx` integration wrapper.  The existing 218.75-MHz 8-lane frontend remains unchanged.
- The ingress contract is 14 complex samples at 125 MHz and word-aligned frame starts every 56 samples.  This preserves 1.75 GS/s complex throughput and the core's frame-granular state contract.
- `run_xsim_axis14_to_core8_cdc.ps1` passed: 8 source words became 14 ordered core words without frame/gain mismatch, bubble, or underflow.
- Project RTL P0 regression passed 7/7; IP smoke passed 5/5.
- Added a two-clock CDC OOC flow.  The first Vivado run ended in `EXCEPTION_ACCESS_VIOLATION` before a timing/resource report; no CDC timing result is claimed.
- A second isolated CDC OOC reproduced the same Vivado access violation after successful `synth_design`, while loading ZU15EG timing/device information.  It also reported that the generic asynchronous-read FIFO cannot infer BRAM and is implemented in registers; this is a future PPA decision, not a functional failure.

# 2026-09-20 - Full AXI/FIFO frontend OOC baseline

- Added the thermo3 AXI/FIFO frontend wrapper and a shared ZU15EG OOC flow for thermo3 and thermo5.  Both flows include the 125-MHz AXI ingress, XPM asynchronous FIFO, 14:8 gearbox, frame gain, two x2 interpolators, and a structurally instantiated four-tap memory-polynomial DPD configured with runtime identity coefficients.
- Thermo5 identity-DPD frontend XSim passed 64 words / 2,048 complex output samples with zero raw-plane mismatches; the existing thermo3 frontend bit-true XSim also passed.  A composition XSim for the new thermo3 AXI wrapper remains pending.
- The first fully routed thermo3 AXI frontend run completed without errors or critical warnings but failed 218.75-MHz setup: WNS `-4.407 ns`, WHS `+0.001 ns`, 5,159 setup endpoints.  The worst path is the high-fanout `dpd_vector16_memory_poly` valid reduction into the second interpolator enable, with 8.416 ns of routing delay in an 8.796 ns data path.  This is a real full-chain timing failure, not a functional failure; runtime DPD coefficient ports also create OOC part-pin/clock-source warnings that must not be treated as board constraints.

# 2026-09-22 - ZU15EG GT/BERT integration entry points

- Added `ti64_raw_gt14_sfp0_bert_top.sv`, connecting the vendor GT Wizard user
  port to the PRBS31/known-word endpoint through an asynchronous RX-word FIFO.
- Added RAW RXSLIDE alignment and repeat-seed acquisition hooks, plus vendor
  behavioral simulation and implementation Tcl scripts.
- The vendor model reaches TX/RX active/done, power-good, and CDR-stable.  The
  current model still exposes variable-latency PRBS acquisition; no vendor
  BERT PASS or routed GT timing claim is made yet.
- The ZU15EG BERT top implementation then completed with 0 DRC errors and
  constrained setup/hold slack of +1.844/+0.052 ns.  This is not board BER
  evidence.

# 2026-09-22 - GT BERT training boundary and regression hardening

- Added an explicit run-arm/drain state in `gt_link_bringup_bist.sv` so the
  one-word loopback latency cannot shift the first PRBS31 word.
- Corrected the training-aware protocol assertion and hardened the XSim
  launcher to require the PASS marker and reject fatal/error diagnostics.
- Checks: GT BERT XSim PASS, P0 regression 7/7 PASS, IP smoke PASS.

# 2026-09-20 - Word-atomic DPD control and elastic timing cut

- Replaced the vector-DPD AND reductions with lane-0 word-transaction control
  and executable simulation assertions that every lane's `valid` and `ready`
  remains lockstep.  The data, history update, coefficient interface, Q2.14
  arithmetic, rounding, saturation, and temporal lane order are unchanged.
- Added `dpd_vector_elastic_buffer` between the memory-DPD and the second x2
  interpolator.  It holds one complete complex word and adds exactly one core
  clock of latency, preventing the DPD output-valid pipeline from directly
  driving the interpolator enable network.
- Replicated the second-stage interpolator's internal valid state per lane,
  with `KEEP`/`MAX_FANOUT` guidance and simulation assertions.  Lane 0 remains
  the word-level handshake, while local replicas gate their corresponding lane
  datapaths.
- Checks passed after the change: thermo3 frontend XSim and thermo5 frontend
  XSim each matched 64 input words / 2,048 final complex samples bit-for-bit;
  all new control assertions passed.  Project P0 regression passed 7/7.
- The replacement thermo3 full AXI/FIFO frontend OOC completed synthesis with
  0 errors and 0 critical warnings (2,058 DSP48E2) and is currently in
  placement/routing.  Final WNS/WHS are not yet available; the prior thermo3
  `-4.407 ns` and thermo5 `-3.968 ns` reports are explicitly pre-fix baselines.

- The replacement thermo3 routed OOC completed: 0 errors and 0 critical
  warnings, but it failed 218.75-MHz timing with WNS `-7.183 ns` and WHS
  `-0.019 ns`.  The DPD reduction path is absent from the worst path.  The new
  critical net is `u_interp_2/out_valid_reg -> u_tid/u_p/in_valid`, with
  14,294 routed loads and 11.569 ns of routing delay (zero combinational logic).
  Therefore this change is functionally correct but not a timing fix; the next
  implementation must distribute registered valid/ready at the TID plane
  boundary before rerunning thermo3 and thermo5.
2026-09-23
- Added `eda.yaml`, ASIC thermo3/thermo5 DC wrappers, source list, dual-clock SDC,
  and reproducible TSMC28 DC launcher under `syn/asic`.
- Fixed the existing 8-lane vector width declarations in the AXI thermo wrappers;
  DC elaboration had exposed the mismatch against the CDC and frame-gain ports.
- Checks: Rocky-8.10 DC V-2023.12-SP1 invoked with TSMC28 RVT TT DB; thermo3
  mapping run is active, thermo5 baseline launch previously completed only with
  the pre-fix empty/unmapped result and must be rerun after thermo3 completes.
- Limitations: no ASIC final area/timing/power claim until the current real
  mapped runs emit reports; power is vectorless without SAIF.
- Fixed `syn/asic/parse_dc_reports.py` to run on Rocky's Python 3.6 (removed
  unsupported future annotations and newer union/generic type syntax).
- Project organization pass: physically migrated `verif/` to `dv/verif/` and
  `uvm_verif/` to `dv/uvm/` with `git mv`, updated root-relative filelists,
  Makefiles, formal/Tcl/Python/PowerShell consumers, and corrected the UVM
  include path. The migration map records the completed moves.
- Post-migration GT BERT XSim reached compile/elaboration but the existing
  Vivado Windows simulator returned `-1073741790` at run time; this is recorded
  as an unavailable simulator result, not a migration PASS.
- The active thermo3 DC session ended with `Process terminated by hangup` during
  compile mapping optimization. Intermediate checks exist, but no final ASIC
  area/timing/power/netlist result is claimed.
2026-09-24
- Audited the persistent bounded TSMC28 DC runs for thermo3 and thermo5. Both
  Rocky DC processes are still in standard-cell mapping after
  analyze/elaborate/link; no area, setup/hold, power, DDC, or mapped-netlist
  artifacts exist yet. ASIC signoff remains pending.
- Confirmed the physical verification migration is complete under `dv/verif/`
  and `dv/uvm/`; updated consumers remain the canonical flow boundary.
- Added ignore rules for DC shell runtime files and run PID files. Existing
  copies are retained locally; index cleanup requires a normal writable Git
  clone because this session cannot create `.git/index.lock`.
- Implemented the stage-1 FPGA low-power experiment as an opt-in
  frame-safe activity controller (`rtl/axis/dsm_frame_power_ctrl.sv`). It uses
  native clock-enable style qualifiers, waits for four AXI words (one
  56-sample superframe), and drains accepted core words before IDLE; it never
  gates a fabric clock or pauses an active recursive frame. Added thermo3/5
  low-power OOC variants and a focused XSim controller test. Baseline wrappers
  keep `ENABLE_LOW_POWER_CTRL=0`.
- Re-audited the persistent TSMC28 DC runs: both were still alive in mapping,
  but invalid because `gt_tx_raw64_boundary` was omitted from the ASIC source
  list and remained unresolved at link. Added the missing GT RTL sources to
  `syn/asic/dc_thermo_frontend.tcl`; the existing runs must not be used and
  need a clean restart before any ASIC result is reported.
- Attempted the corrected thermo3 restart in
  `runs/20260924_123132-dc-thermo3-tsmc28/`; DC exited before analyze with
  `DCSH-1 Design Compiler is not enabled`. The Rocky FlexNet log reports a
  license TCP-port open failure. No synthesis result is claimed until the
  license service is restored and the run is restarted.
- Rechecked the Rocky FlexNet service: `lmutil lmstat -a -c 27000@localhost`
  reports the server and `snpslmd` UP with the SSS feature available. Started
  a new thermo3 bounded run with an explicit `.db` and
  `27000@127.0.0.1`; it loaded all 17 source designs including the previously
  missing GT boundary and is still processing pre-compile checks. No ASIC
  result is claimed yet.
- Thermo3 bounded DC completed successfully in
  `runs/20260924_1240-dc-thermo3-tsmc28/` after restoring the license and GT
  source list. Generated DDC, mapped Verilog, area, setup/hold, power, QoR,
  and constraint reports. TT timing has zero violating paths (clk125 slack
  7.51 ns; clk218 slack 1.45 ns). Standard-cell-only cell area is
  1,623,296.698 library units; vectorless power is 181.0777 mW dynamic plus
  1.0081 mW leakage. These numbers are pre-layout and not multi-corner or
  SAIF signoff.
- The first thermo3 LP OOC completed synthesis/implementation but failed timing
  at WNS -10.281 ns (quick implementation). A concurrent thermo5 LP attempt
  hit Vivado's private realtime-helper crash (`rt-undefined`) before synthesis;
  removed the private `rt::*` calls from the OOC Tcl so subsequent LP runs use
  only the bounded thread settings and public Vivado flow.
- LP evidence audit: the subsequent thermo5 quick OOC aborted with Vivado
  `EXCEPTION_BREAKPOINT` during iterative area optimization. Its incomplete
  vectorless report is diagnostic only (`7.033 W` total on-chip, `0.756 W`
  device static). No LP timing or power PASS is claimed.
- Retried thermo3 LP with a fresh output directory and direct `vivado.bat
  -mode batch` invocation. RTL read and synthesis licensing succeeded, but
  Vivado 2024.1 again aborted in its realtime helper with `rt-undefined` before
  timing reports. This remains a tool/runtime blocker, not a new timing result.
2026-09-24
- Revised stage-1 low-power datapath control to use registered local CE at the
  gain and thermo frontend boundaries while leaving the AXI/CDC ready/valid
  network untouched. This targets the measured routing-dominated LP failure
  without changing active-frame DSM state evolution or the baseline branch.
- Added `syn/run_lp_power_compare.ps1` and SAIF provenance support in the OOC
  Tcl. Baseline and LP now have a reproducible same-device/full-route
  comparison entry point; reduction percentages remain unreported until both
  reports are present.
2026-09-24
- Re-tested the host Vivado 2024.1 outside the GUI with a minimal batch smoke
  (`puts [version -short]; exit`) and the LP RTL read/elaboration diagnostic.
  Both terminate with Windows status `-1073741790` and produce an empty log.
  This is a Vivado runtime/install failure before RTL parsing, not a project
  synthesis or timing result.
2026-09-26
- Exposed structural interpolation and memory-DPD tap parameters through the
  thermo3/thermo5 AXI and OOC tops.  Added 2/3/4-tap unity-DC-gain
  interpolation presets while retaining the 4-tap cubic default unchanged.
  Compile-time DPD SKU mode fixes the active tap count so unused memory taps
  can be synthesized away; the default remains runtime programmable.
- Corrected migrated `dv/verif` paths in the P0 and thermo frontend XSim
  launchers.  Default thermo3 and thermo5 frontend bit-true XSim pass after
  the parameter plumbing.  Started the first full routed timing run for the
  thermo5 2-interpolation-tap / 1-memory-tap SKU; no new PPA result is
  claimed while the implementation is running.
- Added a routed-checkpoint functional-netlist export and post-route XSim/SAIF
  activity launcher.  Thermo3's 55.6-MB netlist compiles and elaborates, and
  the launcher now resolves the escaped generated DUT hierarchy correctly.
  The bounded host could not complete full activity simulation of the
  2,030-DSP netlist (about 7.7 GB during elaboration), so no post-route SAIF
  coverage or revised power reduction is claimed.
- Added and executed `run_tid32_thermo_algorithm_ppa_screen.m` at 100 MHz and
  250 MHz with three isolated seeds, raw Fs/4 DDC, and the routed default
  thermo3/thermo5 PPA points.  At 250 MHz, only thermo5 meets the 256-QAM
  gate for all three seeds; the output CSV records EVM/SNDR/ACLR, stream
  mismatches, resource, and timing provenance.  No RTL numerical behavior was
  changed.
- Corrected `matlab/bittrue/p0_compare_rtl_xsim.m` to use the canonical
  migrated `dv/verif` vector and XSim-output locations.  Check:
  `scripts/run_matlab_p0_bittrue_check.cmd` PASS, seven 65,536-sample models
  with zero mismatches.
- Rechecked the thermo3 routed-DCP/RTL-SAIF hierarchy mapping with the
  recorded strip path. Vivado reproduced `19,984/293,705` direct net matches
  (7%). The SAIF includes the full DUT hierarchy, confirming that the limit is
  RTL-to-routed-netlist name/optimization mismatch rather than a strip-path
  error. No RTL behavior, timing, or prior power number changed.
- Created independent managed Vivado OOC projects under `fpga/thermo3_lp/` and
  `fpga/thermo5_lp/` for the complete low-power two-clock AXI frontends on
  `xczu15eg-ffvb1156-2-i`. Both projects preserve wide internal interfaces as
  OOC partition ports instead of consuming package I/O.
- Completed full synthesis, placement, physical optimization, and routing at
  218.75 MHz. Thermo3 LP passes with WNS/WHS `+0.147/+0.027 ns`; thermo5 LP
  passes with `+0.103/+0.026 ns`. Both have TNS/THS 0, zero route errors, and
  zero critical warnings. Routed checkpoints and timing/utilization/power
  reports are retained in each project's `reports/` directory.
- Routed utilization: thermo3 LP uses 60,094 CLB LUTs, 84,693 registers,
  6.5 BRAM tiles, and 2,032 DSPs; thermo5 LP uses 71,713 CLB LUTs, 97,796
  registers, 6.5 BRAM tiles, and 2,032 DSPs.
- Vectorless routed power is 6.040 W for thermo3 LP and 6.540 W for thermo5 LP
  (Medium confidence). No reduction percentage is claimed: the matched
  baseline/LP SAIF workload experiment is still required, and Vivado warned
  that vectorless reset activity is unrealistic.
- Fixed the managed-run completion check to use the routed DCP as the source of
  truth when `Performance_ExplorePostRoutePhysOpt` is intentionally stopped at
  `route_design`; this avoids falsely reporting a successful route as failed
  because the optional post-route phys-opt step is not started.
- Check: `dv/verif/scripts/run_xsim_frame_power_ctrl.ps1` PASS with
  `DSM_FRAME_POWER_CTRL_PASS`. Full frontend bit-true regression after the
  local-CE change remains pending.
- Low-power evidence audit: these routed projects prove timing closure, not a
  power-reduction percentage. Their OOC wrappers tie `core_enable` high, so
  vectorless power never models a normal IDLE/DRAIN workload, and the generated
  `lp_ingress_enable` is not yet connected to AXI/FIFO acceptance. Classify the
  implementation as frame-safe local activity gating pending full integration,
  transition regression, and matched baseline/LP SAIF measurements.
- Implemented the next low-power integration revision: OOC tops now expose a
  real `run_request`; LP ingress gates AXI acceptance; the controller owns CDC
  enable through DRAIN; and CDC has an explicit `core_drain` condition so a
  legal end-of-run empty FIFO is not reported as streaming underflow.
- Added `tb_tid32_thermo_axis_lp_power.sv`, its XSim/SAIF launcher, a routed-DCP
  SAIF power reporter, and `syn/run_lp_power_ab.ps1`. The flow uses identical
  useful transactions for baseline/LP continuous, burst, and long-idle cases,
  requires output-count/digest equality before power analysis, implements each
  mode once, reopens a clean DCP per workload, and reports SAIF matched-net
  coverage and dynamic-power reduction.
- Execution is pending rather than PASS: Windows `xvlog` currently terminates
  before RTL parsing with `-1073741790`, while Rocky WSL/VCS fallback could not
  be accessed because the host escalation service failed. The XSim controller
  launcher was hardened to check every tool exit status, exposing that its
  apparent earlier rerun had reused a stale PASS log. Existing LP routed DCPs
  are explicitly pre-revision evidence and must be rebuilt.
- Hardened the matched-SAIF experiment contract: the continuous case now sends
  512 no-bubble AXI beats; every baseline/LP pair uses the same fixed
  core-clock observation window; comparison includes accepted words, output
  words, output digest, and observation cycles; and the power flow rejects
  Vivado SAIF design-net coverage below 80%. PowerShell parsing and
  `git diff --check` pass. A fresh EDA run remains blocked because the current
  Windows tool process exits before emitting version or compile output and the
  external-execution approval service did not grant a runnable session.
- Diagnosed the thermo3/thermo5 `xelab` failure from the generated logs. It was
  a launcher file-handle collision, not an RTL elaboration error: PowerShell
  occupied `xelab.log` through `*> xelab.log` while Xilinx `xelab` attempted to
  open its own default log of the same name. Updated the activity launcher to
  use native `-log xelab.log` and `-log xsim.log` arguments with no shell
  redirection. The user's normal terminal must perform the post-fix smoke run
  because EDA executables still terminate before logging in the restricted
  agent process.

2026-09-27
- Added a sparse-TDD activity workload consisting of four frame-safe short
  grants separated by deterministic idle intervals. XSim/SAIF generation
  passes for thermo3 and thermo5 baseline/LP pairs with identical accepted
  words, output words, digest, and observation cycles; only LP completes with
  no underflow, as intended by the drain protocol. Routed power reporting is
  still running and no new reduction percentage is claimed yet.
- Added `run_tid32_thermo_sku_matrix.m` and
  `run_ooc_tid32_thermo_sku_matrix.ps1` for the fair 18-SKU
  thermo/interpolation/identity-DPD matrix. A thermo5/2-tap/1-tap algorithm
  smoke passed three held-out seeds with zero raw-word mismatches. Full MATLAB
  and independent full-routed OOC matrices were launched; pending rows remain
  pending rather than inferred from default PPA.
