# Execution frontier

## Verification source organization (2026-10-16)

Optional thermo5 AXI-Lite UVM tests are split by responsibility under
`dv/uvm/tests/thermo5/axil/`. The register-access test covers the map, AW/W
skew, byte strobes, error responses, coefficient readback and response stall
without stream traffic. The configuration integration test covers commit,
mailbox/frame-boundary application, PA stall, reset and bit-true output;
coefficient image, tap-4, nonlinear-image, boundary-phase, mailbox-fault and
illegal-frame cases have named tests. The full generic AXI-Lite VCS regression,
expected-negative checks, parameter guard and URG merge passed after extraction
in `runs/thermo5_axil_refactor_suite_retry_20261016/`. XPM has not been rerun
after this extraction. The nonlinear-image test only checks atomic configuration
transfer and 56 output handshakes; nonlinear arithmetic remains OPEN. The
standalone `thermo5_axil_cfg_coverage_tb.sv` checks internal reset/request/
pending overlap.

The block/subsystem scenario, intent, expected-result and limitation matrix is
maintained at `docs/verification/thermo5-test-level-matrix.md`.

Updated: 2026-10-16 SGT. Status: active; frozen thermo5 OOC routes PASS, DV tree cleanup and directed smoke validation complete, parent I/O signoff OPEN.
This is the source of truth for current execution state. Detailed next actions
and exit gates are in [the closure plan](thermo5-gap-closure.md).

## DV tree cleanup (2026-10-16)

The thermo5 directed testbench tree is now split by verification level:
`dv/verif/block/` holds focused AXIS/FIFO, DPD, interpolation, TID32, and raw64
boundary tests; `dv/verif/subsystem/tx_frontend/` holds full thermo5 frontend,
four-plane, and serializer-loopback tests. Obsolete non-thermo5 collateral and
generated vectors were removed from this focused branch (they remain on
`main`). Ignored local DV build outputs were preserved under
`runs/local_dv_artifacts_20261016/` rather than committed or discarded.

After path updates, generic/XPM AXIS CDC, frame-power, XPM FIFO reset,
reset-release audit, TID32 Cartesian bit-true, thermo5 frontend, four-plane
multi-PA, raw64 continuous TX, serializer-loopback, and frozen 56-word full-chain
XSim tests all PASS. This is a directory/runner validation milestone, not a new
UVM coverage closeout, parent-level CDC/RDC audit, or board signoff. The
AXI-Lite wrapper remains a separate integrated thermo5 variant; the default
frozen SKU flow uses the parallel DPD configuration interface.

This branch is the thermo5-only code view. Shared CDC/FIFO, DPD, interpolation,
TID, reference-model, and verification infrastructure remains where the thermo5
filelists require it; unrelated SKU source code remains on `main` and `thermo3`.

Branch cleanup verification (2026-10-15): generic and real-XPM VCS/UVM frozen
SKU runs PASSed (six positive cases plus expected illegal-frame control per
implementation, three extra MATLAB payload seeds per implementation); both
URG merges exited 0. The 56-word direct XSim full-chain test also PASSed. These
checks validate the retained file closure; they do not upgrade the existing
OOC-only timing boundary to parent/board signoff.

## Target and source of truth

- Digital DUT: `tid32_thermo5_axis_frontend_tx`, W16, INTERP_TAPS2,
  DPD_MAX_TAPS1, identity coefficients, low-power control disabled.
- DV: generic and real XPM FIFO compiled/reported separately. Filelist:
  `dv/uvm/sim/thermo5_sku_filelist.f`; MATLAB is the independent bit-true oracle.
- ASIC: `syn/rtl/thermo5_frozen_asic.sv`, generic FIFO; sources and constraints:
  `syn/asic/thermo_frontend_dc_sources.f`, `syn/asic/thermo5_frozen.sdc`.
  The default `eda.yaml` thermo3 top is a different configuration.
- Clocks: AXI125 MHz, core218.75 MHz. One32-beat frame yields56 ordered
  four-plane64-bit words. Preserve widths, signedness, reset, latency and oracle.
- Canonical paths: RTL `rtl/`, directed DV `dv/verif/`, UVM/formal `dv/uvm/`,
  ASIC flows `syn/asic/`, vendor/board boundary `fpga/`. No board is available.

## Frozen thermo5 full AXI-Stream routed OOC (2026-10-15)

- Scope: no-AXI-Lite `tid32_thermo5_axis_frontend_tx`, current branch RTL,
  ZU15EG `xczu15eg-ffvb1156-2-i`, source 125 MHz/core 218.75 MHz, XPM FIFO,
  `INTERP_TAPS=2`, `DPD_MAX_TAPS=1`, low-power control disabled. The OOC
  includes AXI ingress, async FIFO/14:8 gearbox, interpolation, identity DPD,
  Fs/4/thermo5 front end and four PA-code planes.
- Routed checkpoint/report: `runs/thermo5_full_axis_ooc_20261015_retry2/`.
  Vivado 2024.1 routed all 98,546 routable nets (zero routing errors), with
  108 ordinary warnings, 0 critical warnings, and 0 errors. Routed timing is
  WNS/TNS/WHS/THS = +0.504/0.000/+0.027/0.000 ns; all 149,172 checked
  endpoints pass the modeled setup/hold constraints. Worst setup path is
  inside the one-tap memory-DPD DSP pipeline, 3.765 ns data delay (2.686 ns
  logic, 1.079 ns route). Resources: 43,837 CLB LUTs, 53,375 registers,
  496 DSP48E2, 6.5 BRAM tiles. Router estimate and separately reopened
  routed-checkpoint timing report agree within 1 ps.
- This closes internal routed OOC timing for the frozen no-AXI-Lite thermo5
  top; it is not parent/system/board signoff. `check_timing.rpt` reports 570
  top-level input ports without input delays and 264 outputs without output
  delays. The two clock periods are constrained, but real parent I/O budgets,
  clock-source/placement metadata, system reset/CDC/RDC, and GT/board behavior
  remain outside this OOC. Inter-clock paths are intentionally cut by the
  asynchronous clock-group constraint and are not CDC signoff.
- The first combined report attempt was stopped when workstation memory became
  low after routing. The same saved `physopt.dcp` was routed into retry2; the
  flow wrote `routed.dcp` before running STA reports in a separate Vivado
  process, which exited 0. No RTL changed. Replay helpers are currently local
  untracked files under `syn/`; generated reports/checkpoints remain ignored in
  `runs/`.

## Latest thermo5 AXI-Lite timing iteration (2026-10-15)

- Scope: only `tid32_thermo5_axi_lite_axis_frontend_tx` on ZU15EG, with the
  existing 125 MHz AXIS / 218.75 MHz core / 100 MHz AXI-Lite OOC clocks and
  `INTERP_TAPS=2`, `DPD_MAX_TAPS=4`, XPM FIFO. No other SKU is in this run.
- RTL: inserted two-entry, word-atomic registered-ready queues at the CDC to
  frame-gain, interp1 to DPD, DPD to interp2, and interp2 to TID boundaries.
  Frame-start and gain metadata travel with their corresponding vectors. This
  adds two fixed cycles at the newly buffered ingress and TID boundary; the
  existing DPD/interp boundary register latency is retained. FIFO payload is
  don't-care while invalid and only control state is reset.
- Functional checks on the current RTL: required P0 XSim 7/7 and IP smoke PASS;
  thermo5 AXI-Lite generic and XPM 56-word four-plane bit-true tests with PA
  ready stress PASS (seeds 420204 and 420205). `git diff --check` PASS.
- Fresh synth checkpoint and separate reopen/report validation:
  `runs/thermo5_axil_readytree_synth_20261015/`. Mapped resources: 84,771 LUT,
  88,497 FF, 1,936 DSP48E2, 6.5 BRAM tiles. Pre-placement diagnostic WNS/WHS
  are +1.143/+0.078 ns; the worst path is now a DPD DSP/ALU datapath, not the
  former end-to-end ready path. This is not routed timing closure. The synthesis
  launcher returned nonzero on `Failed to load feature 'vivado'` after writing
  the checkpoint; the separate checkpoint validation exited 0.
- An earlier single-cut experiment remains a failed iteration in
  `runs/thermo5_axil_readycut_synth_20261015/` (pre-placement WNS=-0.339 ns),
  and is not the current candidate.
- Timing-driven ZU15EG OOC route completed from the saved `physopt.dcp` in
  `runs/thermo5_axil_readytree_route_20261015_20261015_114457/`. Router
  verification passed; all 218,958 routable nets are fully routed, with zero
  route errors. Vivado reported 103 ordinary warnings, 0 critical warnings,
  and 0 errors; warnings concern OOC clock-source/part-pin metadata. Final
  core WNS/TNS/WHS/THS are +0.198/0.000/+0.018/0.000 ns;
  AXI-Lite and AXIS clock domains also have positive setup/hold slack. There are
  zero failing endpoints under the modeled constraints. Final routed resources:
  81,576 LUTs (71,041 LUT logic and 10,535 LUTRAM), 88,407 CLB registers,
  1,936 DSP48E2, and 6.5 BRAM tiles. The worst path is now inside the memory-DPD DSP
  pipeline (4.067 ns data delay, 1.424 ns routed net delay), not the
  former long ready/CE path.
- This is an OOC internal timing PASS only. `check_timing.rpt` still reports
  527 input ports without input delay and 308 output ports without output
  delay; OOC ports also lack parent `HD.PARTPIN_LOCS`. It does report zero
  unconstrained internal endpoints. Real parent/board I/O timing, clock-source
  modeling, and system-level reset/CDC/RDC remain OPEN. Preserve these route
  reports as evidence; do not generalize this result to a board-level or full
  top-level timing signoff.

## Optional thermo5 AXI-Lite configuration extension (2026-10-11)

- Added `tid32_thermo5_axi_lite_axis_frontend_tx` and
  `thermo5_dpd_axi_lite_cfg`: shadow tap/coefficient registers, COMMIT snapshot,
  bundled-data request/ack CDC and synchronized `run_request`. Existing frozen
  parallel-config top remains available and unchanged at its public interface.
- Commit applies atomically to all 16 DPD lanes on the next accepted,
  frame-start-marked DPD input vector. The marker is carried beside data
  through frame gain, first interpolation, and the DPD elastic input buffer.
- Vivado XSim evidence on 2026-10-11: P0 regression 7/7 and IP smoke PASS;
  generic and XPM direct 56-word bit-true tests PASS; the new UVM 1.2 AXI-Lite
  configuration test also PASSes for generic and XPM with zero UVM errors or
  fatals (seed 101). The UVM test checks ID, independent AW/W skew, illegal
  commit/SLVERR, sticky ERROR/W1C, pending BUSY/no early apply, marked-frame
  application, DONE and four-plane MATLAB bit-true output.
- The XSim UVM test previously ended early because `join_any` raced the source
  sequence; this was fixed by joining source completion and configuration/check
  completion before dropping the test objection. Re-ran the corrected test.
- Licensed VCS-UVM AXI-Lite configuration test passes on generic FIFO
  (seed 420101) and real XPM FIFO (seed 420102): illegal tap rejection,
  independent AW/W skew, mailbox frame-boundary apply, and 56 four-plane
  bit-true output words; both runs have zero UVM warnings/errors/fatals. The
  earlier log's `reset=0` was the midstream `reset_reassertions` event counter,
  not the reset coverpoint (source covergroup was already 100%); its local core
  covergroup was 75% because no PA stall or bad-frame event was in that test.
  The VCS compile exposed and fixed a TB multi-driver issue on `axil_rst_n` by
  removing its declaration initializer.
- AXI-Lite exception/coverage work was rerun on 2026-10-12. Generic and XPM
  four-scenario targets pass: positive configuration/56-word bit-true,
  illegal-frame assertion, mailbox-corruption assertion/recovery, and separate
  MAX_TAPS=0/5 parameter guard. The positive test also probes the defensive
  coefficient-read default and legal AR backpressure; zero-strobe CONTROL and
  STATUS cases are covered. Both targeted URG merges show 100% functional
  groups. The AXI-Lite config module reports line99.38%, condition95.95%,
  toggle33.50%, branch97.50%; full-hierarchy three-test raw scores are generic
  74.54 and XPM74.43, and are not the complete SKU regression. Exact rows and
  evidence are in
  `docs/verification/thermo5-axil-code-coverage-closure-20261012.md`.
  Matching-source VC Formal then proved only the exact line88 tuple
  `(!bvalid, aw_pending||aw_take, w_pending||w_take)=(0,1,1)` unreachable;
  its reviewed disposition is the single entry in
  `docs/evidence/THERMO5_AXIL_COVERAGE_WAIVERS.csv`. Raw URG remains unchanged
  and no adjusted score is claimed. The line315 tuple `(0,1,1)` remains OPEN:
  the matching-source proof is inconclusive at depth10, so it is not waived.
  The write-case default also remains open pending its own proof/review.
- Follow-up legal external-stimulus search for AXI-Lite line315 tuple
  `(cfg_req_sync2,cfg_pending_valid,dpd_config_boundary)=(1,0,1)` completed on
  2026-10-12. The added legal early-BREADY plus one-cycle AW/W gap and 0..9500ps
  AXI phase sweep hit the exact public-stimulus trace in 15/20 runs; URG marks
  the tuple Covered. Together with the prior 441 legal trials, total passing
  legal matrix evidence is 461, each with zero UVM errors/fatals and 56 four-plane
  words bit-true. The earlier 16-cycle source pause triggered the expected
  early-FIFO-starvation checker and remains excluded. Replay is
  `dv/uvm/sim/run_axil_boundary_bready_gap_sweep.sh`; report is under
  `runs/thermo5_axil_boundary_bready_gap1_20261012/`.
- Coefficient payload CDC now passes legal VCS/UVM transport on generic
  (seed435509) and real XPM (seed435510): exact mailbox/pending/active images,
  reset-default checks, 56 four-plane bit-true words, and zero UVM warnings,
  errors, or fatals. The matching targeted URG reports `thermo5_dpd_axi_lite_cfg`
  toggle78.49% for both builds. For all four payload images
  (`cfg_mailbox_q`, `cfg_pending_core`, `cfg_active_core`, `cfg_for_dpd`),
  each bank's low16-bit slice remains Not Covered; high48-bit slices toggle.
  Functional bundled-data transfer passes, but complete coefficient toggle
  coverage remains OPEN. Evidence is under
  `runs/thermo5_axil_coeff_vcs_{generic,xpm}_20261012/`. VCS license setup is
  available only in the interactive Rocky shell; noninteractive launch does
  not inherit it.
- XPM/FWFT public-reset phase exploration used the exact same XPM binary for
  16 post-`stage1_valid` source phases, 400 prefetch-only reset-request points
  (all 16 source phases x 25 core delays), 48 full-prefix reset points, and
  one bit-true baseline. All 464 reset trials completed four-plane replay
  with zero UVM errors/fatals. Same-binary URG now reports
  8/9 `curr_fwft_state` transitions: `both_stages_valid->invalid` is Covered;
  only `stage1_valid->invalid` remains Not Covered and OPEN. No internal force
  or waiver was used. Reports/logs:
  `runs/thermo5_xpm_fwft_phase_sweep_20261012/coverage_all_16phase_reset_sweeps/`.
  The all-phase/all-delay legal reset search still did not hit the transition.
  A new edge-observer build sampled state/reset before and after each
  `posedge core_clk`; the isolated attempt showed `stage1_valid, rd_rst_i=0`
  transitioning to `stage2_valid`, with `rd_rst_i` rising two core edges later.
  A fresh 400-point source-phase/core-delay search sampled 5,464 stage1 edges,
  but zero stage1+reset edges and zero target transitions. This is strong search
  evidence, not a reachability proof; keep the transition OPEN. Logs and
  summary: `runs/thermo5_xpm_fwft_edge_observe_20261012/`.
- A MATLAB-fixture-validated independent oracle generated 8,388,611 words to
  cross counter bit23 (`runs/thermo5_bit23_oracle_20261012/`). Generic and XPM
  VCS/UVM runs both PASSed 8,388,611 four-plane output words, all16 counter
  reset checks, signed endpoints, and zero UVM errors/fatals. Separate
  same-binary URG deltas confirm `sample_count[23]` toggles both directions in
  all16 DPD lanes for each FIFO. Added two legal 56-word gain-extreme/toggle
  vectors to each same-binary URG set; all four replayed four-plane bit-true
  with zero UVM errors/fatals. Latest explicit-VDB raw scores are generic
  87.00% (line87.09, cond76.46, toggle85.46, FSM100, branch73.00, assert100)
  and XPM80.17% (line76.99, cond67.89, toggle82.88, FSM90.91, branch62.37,
  assert100). XPM includes vendor hierarchy; denominators differ. These remain
  raw, not100%. Bits24-31 remain reachable/open (256 directions per FIFO).
  Exact report:
  `runs/thermo5_bit23_vcs_{generic,xpm}_20261012/coverage_current_gain_reset_safe/`.
  Full records are in
  `docs/verification/thermo5-bit23-counter-closure-20261012.md`.
- Same-binary reset phase delays1-8 passed in generic and XPM and produced no
  new URG condition/branch/toggle hits. Generic delay9 triggered the test's
  early-FIFO-starvation fatal and is excluded from URG. The class currently
  permits delays through11 despite this observed boundary; clarify/fix that
  test input range before claiming a wider reset-phase sweep. Latest raw
  scores are unchanged at generic87.00% and XPM80.17%.
- Optional wrapper OOC synthesis: a fresh 2026-10-12 run generated a 56.9 MB
  `synthesized.dcp` and utilization report in
  `runs/thermo5_axil_covclose_synth_20261012/` (71,537 LUTs, 52,255 registers,
  1,936 DSPs, 334.5 BRAM tiles). Vivado reopened the DCP and successfully
  regenerated utilization (`checkpoint_validation.log`). The initial wrapper
  process returned nonzero after writing the checkpoint (`Failed to load
  feature 'vivado'`), so the source flow's exit behavior remains to diagnose.
  A second clean-output attempt in
  `runs/thermo5_axil_covclose_synth_retry_20261012/` reproduced the same
  nonzero wrapper error after writing a 56.9 MB DCP and resource report. A
  separate Vivado process reopened that DCP, restored timing/constraints,
  regenerated utilization, and exited 0. This validates the synthesis
  checkpoint, not the wrapper exit path; no routed checkpoint or WNS/WHS was
  produced.
  On 2026-10-13, fresh licensed VCS/URG full AXI-Lite regressions completed on
  the current tracked source for generic and real XPM FIFO builds. Each includes
  positive configuration and 56-word bit-true replay, legal coefficient-mailbox
  transport and 56-word replay, illegal-frame assertion/reset recovery,
  mailbox-corruption assertion/reset recovery, and MAX_TAPS parameter guards.
  Dedicated AXI-Lite monitor `write_cg`, `read_cg`, and `reset_cg` each score
  100% in both merged URG reports. The merged AXI-Lite RTL module remains at
  93.74% score (line99.38%, condition95.95%, toggle82.13%, branch97.50%); this
  is not 100% raw RTL code coverage. The exact line315 `(0,1,1)` tuple and the
  write-case default remain OPEN; only the reviewed line88 tuple is waived.
  The lower16-bit coefficient slices in the four bundled-data images also
  remain open for toggle coverage. Evidence is in
  `runs/thermo5_axil_signoff2_{generic,xpm}_20261013/` and the detailed
  closure record. A separate fresh XSim attempt still stopped in `xvlog` before
  elaboration; it is not counted as DUT failure or PASS.
  There is still no routed checkpoint, WNS/WHS result, or parent I/O budget.
  CDC/RDC, mailbox bundled-data timing review, independent reset stress, and
  calibrated nonlinear DPD oracle also remain OPEN.
- Replay UVM/XSim: `dv/uvm/sim/run_thermo5_axil_xsim.ps1` (generic and `-XpmFifo`).
  Replay direct MATLAB-oracle bit-true tests:
  `dv/verif/scripts/run_xsim_thermo5_i2_d1_axis.ps1 -AxilControl` and add
  `-XpmFifo` for the vendor FIFO build. Logs live in ignored `runs/`.

### AXI-Lite current verification result (2026-10-13)

- Current-source licensed VCS/URG passed for both generic and real XPM builds:
  `runs/thermo5_axil_signoff2_generic_20261013/` and
  `runs/thermo5_axil_signoff2_xpm_20261013/`. The target runs positive config,
  coefficient payload transport, illegal-frame and mailbox-fault recovery, and
  parameter guards. Each UVM scenario reports zero UVM warnings/errors/fatals;
  negative tests separately confirm the expected RTL assertion/`$error`.
- Merged URG confirms 100% of the newly defined AXI-Lite write/read/reset
  functional covergroups in each FIFO build. This is scoped functional coverage,
  not raw RTL coverage or whole-project coverage.
- The DUT RTL itself was not changed in this follow-up; changes add AXI-Lite
  monitor coverage, a read-only IP-ID write-protection check, and include the
  coefficient transport test in the regression/URG merge.
- Remaining AXI-Lite signoff: raw code coverage is partial; line315 tuple
  `(cfg_req_sync2,cfg_pending_valid,dpd_config_boundary)=(0,1,1)`, write-case
  default, and coefficient payload low16-bit toggle slices remain OPEN.
  Bundled-data CDC timing, integrated reset/CDC/RDC review, clean OOC synthesis
  exit and routed WNS/WHS are also not closed by these simulations.

## AXI-Lite final addendum (2026-10-13)

This addendum supersedes the AXI-Lite open-bin statements above. Current-source
VCS passes generic and real-XPM tap4 identity and nonlinear memory-DPD tests;
each checks atomic config transport and 56 four-plane MATLAB bit-true words,
with zero UVM errors/fatals. Tap4 identity passes current-source XSim for both
FIFO builds; required P0 is 7/7 and IP smoke passes. Defined AXI-Lite functional
write/read/reset covergroups are 100% in both VCS builds.

Current raw `thermo5_dpd_axi_lite_cfg` URG is 98.21% in both builds (line99.38,
condition95.95, toggle100.00, branch97.50); all coefficient-image toggle
directions are now covered. Raw 100% is not claimed. Line315 tuples `(1,0,1)`
and `(0,1,1)` have legal focused test hits (phase sweep and standalone reset
window test respectively), but the standalone VDB cannot merge into the
integration hierarchy. Line88 `(0,1,1)` and the successful-write case default
have formal unreachability evidence. The frozen `MAX_TAPS=4` invalid-parameter
guard branch is separately tested at values 0 and 5. Exact dispositions are in
`docs/evidence/THERMO5_AXIL_COVERAGE_WAIVERS.csv`; raw URG remains unchanged.

The first full OOC implementation reached routed timing analysis in
`runs/thermo5_axil_close_ooc_full_20261013/`, but fails the core setup target:
WNS=-0.630 ns (116 failing endpoints; TNS=-23.465 ns), WHS=+0.028 ns (no hold
failures). `s_axil_aclk` WNS/WHS=+6.423/+0.044 ns and `s_axis_aclk`
WNS/WHS=+4.454/+0.046 ns. The worst path is memory-DPD lane3 DSP cascade to a
RAMB18 input (4.888 ns data delay, 2.254 ns routed); the next major group is
route-dominated TID recursive-state carry paths. The report flags 527 inputs
and 308 outputs without I/O delay, so this is only a constrained OOC internal
timing result. Vivado PID18420 was stopped while blocked in the detailed
CDC-report stage; that run has no routed checkpoint, final flow summary or
completed CDC report. The result is FAIL_SETUP, not PASS. A fresh timing-driven
candidate3 using current RTL was interrupted after extended placement/CRP work
because system commit headroom fell below 400 MB. It wrote no routed checkpoint
or timing summary; its 56.9 MB current-source synthesized DCP and utilization
report are preserved in `runs/thermo5_axil_timing_candidate3_20261013/`. A
default-directive checkpoint continuation completed `opt_design` and saved
`runs/thermo5_axil_route_resume_20261014_0110/optimized.dcp` (55.0 MB), then
exited during global placement/PBP before producing `placed.dcp`. No correlated
Windows Application Error or resource-exhaustion event was found; the cause is
unknown. A second elevated run reopened the optimized checkpoint, validated
the three clocks and reached Phase 2 Global Placement. At that point Vivado
peaked at 8.73 GB and Windows reported about 591 MB available, so it was
interrupted to protect the workstation; no placed checkpoint was written.
System memory recovered to about 8.8 GB and the optimized checkpoint remains
intact. The checkpoint-resume script supports `synth`, `optimized`, `placed`,
and `physopt`. Retry placement only when more system memory is available or
with an explicitly lower-memory implementation strategy. The 10 ns
bundled-data max-delay is provisional; integrated reset/CDC/RDC remains open.
If RTL is retimed, rerun bit-true tests before accepting the new implementation.
The high-coefficient nonlinear XSim run crashed in the simulator kernel at
6.41 us; the same bit-true test passed in VCS generic and XPM.

On 2026-10-14, resumed the current-source optimized checkpoint in
`runs/thermo5_axil_route_resume_20261014_1405/`. `place_design` completed
successfully (59 Infos, 1 congestion warning, 0 critical warnings, 0 errors),
then generated `placed.dcp`; `phys_opt_design` also completed (96 Infos,
8 warnings, 0 critical warnings, 0 errors) and generated `physopt.dcp`.
Placement WNS was -0.577 ns; phys-opt estimated WNS/TNS was -0.592/-19.509 ns.
Routing passed pre-route DRC with zero errors, then reported intermediate
WNS/TNS/WHS/THS = -0.588/-13.508/-0.015/-0.060 ns. The router estimated
congestion level 6 and entered `Phase 5 Rip-up And Reroute`, Global Iteration 0.
The run was stopped when system available memory fell to about 0.60 GB; memory
recovered after exit. The placed and physopt checkpoints and log are preserved;
there is no `routed.dcp`, final timing/route report, or completed OOC PASS.
Route warnings also report missing `HD.PARTPIN_LOCS` for OOC ports, and the
OOC has no real parent I/O delay budget. Resume from `physopt.dcp` only with a
resource-safe routing plan; final setup/hold and route status remain OPEN.

Follow-up route attempts on 2026-10-14 resumed from the same `physopt.dcp`.
Timing-driven `RuntimeOptimized` and `RuntimeOptimized -no_psir` both reached
Phase 8.2 with intermediate WNS/TNS/WHS/THS = -0.630/-23.610/+0.027/0.000 ns,
then were deliberately interrupted at 0.36 GB and 0.33 GB available RAM,
respectively. Neither produced final timing reports. A completed
`Quick -no_psir` diagnostic is in
`runs/thermo5_axil_route_resume_20261014_161911_quick/`: all 209,406 routable
nets routed with zero routing errors and `routed.dcp` was written, but WNS/WHS
are -4.240/-0.019 ns (`FAIL_SETUP`). Quick is non-timing-driven and is only a
routability/report-generation check, not timing signoff. Its timing report also
shows 527 input and 308 output ports without I/O delay; parent-level I/O budget
is still absent. Thus the optional AXI-Lite wrapper has a completed quick-route
artifact but no passing timing-driven routed OOC result. Resume the timing-
driven route from the preserved `physopt.dcp` only when adequate RAM headroom is
available; timing closure and parent CDC/RDC remain OPEN.

## Shared RTL timing optimization (2026-10-14)

- Changed `rtl/dpd/dpd_memory_poly.v`: split three-term gain reduction over
  existing s5/s6 boundaries and reused the existing s7 complex-product stage;
  fixed-point arithmetic and intended total latency are unchanged. Changed
  `rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv`: added equivalent local I/Q
  feedback copies per four-row bank, with simulation invariants.
- Verification: required P0 XSim 7/7 and IP smoke PASS; current-source AXIL
  generic/XPM 56-word tests and tap4-identity tests PASS. VCS AXIL nonlinear
  memory-DPD passed with generic and real XPM FIFO; all four planes matched the
  MATLAB oracle (56 words, zero UVM warnings/errors/fatals).
- Synthesis: fresh 56.3 MB DCP and utilization report are in
  `runs/thermo5_axil_timing_opt_synth_20261014/`; separate Vivado checkpoint
  validation exited0. Mapping: 83,557 LUT, 84,847 FF, 1,936 DSP48E2, 6.5 BRAM
  tiles. The initial synth launcher returned nonzero after saving the DCP
  (`Failed to load feature 'vivado'`); do not label that invocation clean PASS.
- Physical status: unplaced diagnostic WNS=-0.734 ns; its current worst path is
  GT-valid through ready/backpressure to XPM BRAM enable, so it does not yet
  show whether DSP→RAMB18 or TID fanout improved. A fresh placement attempt
  wrote only `optimized.dcp`; it was stopped during PBP at 1.24 GB available
  memory. No placed/physopt DCP or timing-driven route for modified RTL exists.
  Previous routed baseline remains FAIL_SETUP WNS=-0.630/WHS=+0.028 ns.
- Required XC7Z020 DSM OOC suite completed: 12/14 PASS, with
  `p0_ooc_mb_ef2` FAIL_TIMING (WNS=-0.093 ns) and
  `p0_ooc_mb_mash22` FAIL_TIMING (WNS=-0.688 ns). These are separate small DSM
  tops, not the thermo5 AXIL top. Full CSV/reports:
  `syn/reports/ooc_xc7z020clg400_1_20261014_221303/summary_all.csv`.
- Parent timing remains OPEN: board XDC marks 125 MHz and its I/O delays as
  assumptions. Asked for actual clock source, producer Tco and consumer
  capture budgets, and SI5341 configuration. Resume placement from the new
  optimized DCP only with substantial headroom above the observed 10.7 GB
  placement peak; timing-driven routing must then start from a new physopt DCP.

## Current evidence

| Workstream | Actual result | Evidence / remaining limit |
| --- | --- | --- |
| Licensed DV and hosted CI | Local current-source package PASS; hosted CI OPEN | Fresh Rocky package `runs/thermo5_current_source_dv_resume_20261008/dv_package.json`: coverage, formal and bug jobs PASS for digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8` (202 RTL/DV files). GitHub Actions37462007850 applies only to commit `a9b0bc6f67f575e9bb98085b1e064f9eddc886f2`; no hosted result covers the dirty source. |
| UVM/scoreboard and code coverage | Generic and XPM bit24 long-stream simulation + separate URG + 16-lane audit PASS; raw coverage remains OPEN | Both FIFO builds passed 16,777,222 four-plane bit-true words, all16 counter resets, signed endpoints, and zero UVM errors/fatals. Same-binary URG confirms bit24 toggles both ways in all16 DPD lanes for each FIFO. Raw scores: generic87.01% (line87.09, condition76.46, toggle85.50, FSM100, branch73, assertion100); XPM80.18% (line76.99, condition67.89, toggle82.91, FSM90.91, branch62.37, assertion100). Bits25-31 remain reachable/open (224 directional misses per FIFO); raw coverage is not closed. XPM VDB used 2.5 GB oracle files staged on WSL ext4. Partial seeds610705-610708 remain excluded. |
| Exact XPM reset bins | Previous 464-trial phase grid PASS; fresh edge-observed 400-trial search PASS; target remains OPEN | New pre/post-`posedge core_clk` observation reports 5,464 stage1 edges, zero stage1+`rd_rst_i` edges, zero `stage1_valid->invalid` hits. Search is not a formal unreachability proof; no waiver. |
| Counter and other coverage gaps | Partial coverage remains OPEN | Bit23 and bit24 are closed on both FIFO models by same-binary URG and 16/16 lane-direction audits. Bits25-31 remain reachable/open. Generic interpolation clamp/condition bins and XPM vendor line/condition/branch/toggle gaps remain open. Do not waive reachable counters. |
| AXI-Lite configuration edge | Functional cases closed; raw coverage adjudicated, physical signoff OPEN | Current raw score98.21%; line315 tuples hit in separate legal tests; exact line88/write-default/parameter-guard dispositions are in the waiver ledger. OOC route and integrated CDC/RDC remain open. |
| Scoped VC Formal | Scoped milestones proven; full payload OPEN | Oct7 DPD19/20 assertions proven including no-saturation/count-zero; full identity payload inconclusive. Valid interpolation16 assertions/5 covers PASS; actual XPM residual7/9 PASS; legal XPM reset2 assertions/4 covers/2 unreachable reentries PASS. Qualified FWFT cover inconclusive. Exact matching-source manifests in convergence record. |
| Exact missing-bin audit | AUDITED_OPEN | `runs/thermo5_coverage_reasons_20261007/`: every missing code/condition/signal and reason; exact XPM FSM transitions. Not an URG exclusion/signoff report. |
| SpyGlass | Zero errors/blackboxes; review OPEN |39 warnings +4 synthesis warnings; two physical reset-use/RDC items remain. See lint review. |
| Two real bug reconstructions | Fixed/faulty controls PASS | Both XSim and VCS reproduce historical AXI-Lite commit mechanisms on isolated copies. See bug walkthrough. |
| Fault injection | Four XSim mutants detected; VCS-UVM mutation status OPEN | Fresh XSim evidence `runs/thermo5_fault_detection_xsim_20261009/summary.txt`: PA-plane swap, stall corruption, late gain and stale FIFO reset all detected. New runner `dv/uvm/sim/run_thermo5_fault_detection_vcs.py`; the focused AXI-Lite VCS test now passes, but the separate VCS mutation suite has not been rerun. |
| Clean local CI syntax | PASS; hosted current-source CI OPEN | New clean scratch-copy syntax check `runs/thermo5_clean_ci_syntax_20261009/`; it is not a clean licensed regression nor a GitHub Actions result. Workflow syntax list includes the new runner/helper. |
| ASIC DC mapping | PASS | `runs/thermo5_asic_retest_20261006_2016/`: mapped Verilog/DDC/SDC/SVF, zero unmapped cells,544463 cells,170605 sequential; area507779.648216 library units. |
| ASIC pre-layout timing | Partial; constraints OPEN | Setup slack clk125 +6.79ns / clk218 +1.76ns; minimum reported hold0.00ns. Max-capacitance and zero leakage-target violations remain. TT/ideal clocks/assumed I/O budgets are not physical signoff. |
| RTL/netlist Formality LEC | PASS | `runs/thermo5_fm_restored_20261007_retry1/`:170869 matched compare points,0 unmatched,26148 SVF commands accepted/0 rejected. No DUT hierarchy blackbox paths. All170869 compare points equivalent, zero failing/aborted; PASS manifest and unchanged mapped artifacts. |
| Required Windows checks | Existing P0/IP smoke PASS; OOC12/14 | P0 XSim7/7 and IP smoke recorded PASS. Fresh Oct7 OOC reproduces mb_ef2 -0.093ns / mb_mash22 -0.688ns FAIL_TIMING; `syn/reports/ooc_xc7z020clg400_1_20261007_112340/summary_all.csv`. |
| FPGA parent/GT/board | OPEN | Direct route WNS +0.264ns / WHS +0.011ns under provisional budgets; two GT CDC-11 paths, real I/O, RX recovery, serial deskew and board/RF output remain OPEN. |

## Current-source package and exact remaining ledger

The Oct8 Rocky licensed package completed on its then-current dirty source with
digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`
(202 RTL/DV source files). Coverage, scoped formal and historical bug controls
all PASS. Its same-binary 131075-word closure measured generic87.49% and
XPM80.27%. Bit18/19/20/21/22 long streams passed on generic and real XPM.
Latest bit22 raw URG scores are generic87.16% and XPM80.12%; reviewed adjusted
views are bit21-only at99.66%/96.71%, not100%. `sample_count[22:0]` toggles
both ways in all16 counters/FIFO. Later bit23 evidence is recorded separately;
bits31:24 remain reachable/open (256 directions/FIFO). The 4,194,309-word
integer oracle first matched all eight
files of its MATLAB-validated fixture. Seeds610078/610079 then passed
4,194,309 four-plane output words with zero UVM errors/fatals and the public
reset/all-counter check. Same-binary URG confirms bit22 in 16/16 instances for
both FIFO builds. Logs and raw reports are under
`runs/thermo5_frozen_regression_fwftmon_20261008/` and
`runs/thermo5_bit22_urg_20261008/`. Hosted current-source CI remains OPEN.
An initial optional bit18 MATLAB vector attempt stopped after about32minutes
near the30-minute resource cap before writing vectors; its record remains at
`runs/thermo5_bit18_20261008/attempt.json`. A later MATLAB process also ran
for about four hours without output and was stopped after its exact command
and empty target were verified. The independent NumPy integer oracle matched
all eight outputs of a MATLAB fixture and generated 262150 words. Same-source
generic and XPM VCS tests passed; exact same-binary URG confirms bit21 in both
directions for all16 DPD counters/FIFO. The bit21 logs show 2,097,158 output
words checked and all16 lane counters cleared. Full details:
`docs/verification/thermo5-reachability-closure-20261008.md`.

## Remaining priority

1. Current generic/XPM raw counter remainder:224 reachable directions across
   bits31:25 in all16 DPD counters; later high bits remain OPEN until hit.
   Generic retains four interpolation
   clamp lines and four branch arms; valid-payload proof does not cover invalid
   startup payload evaluation.
2. Current XPM adjusted view still has vendor line/condition/branch/toggle
   bins and one FWFT transition OPEN. Nineteen exact vendor candidates did not
   map to native signatures and are not excluded. Current manifests/reports:
   `runs/thermo5_bit21_reviewed_exclusions_20261008/`.
3. Historical Oct7 XPM candidate counts (15 lines,32 conditions,461 toggle
   directions,50 branches,one FWFT transition) are superseded by the bit21
   exact raw/adjusted inventory. Do not reuse those old counts as current.
   Historical CSVs remain under
   `runs/thermo5_followup_long_20261007/remaining_final/`; current vendor
   signature mappings and unreviewed records remain OPEN.
4. Keep the XPM FWFT `stage1_valid->invalid` transition OPEN. A same-source
   16-phase post-state sweep, 100 prefetch-only reset-request points and48
   full-prefix phase points left that transition uncovered; the latter did
   close `both_stages_valid->invalid`. Do not force internal pins or exclude
   the remaining bin; refine the public-reset arrival window and trace
   `rd_rst_i`/FWFT state at each core edge.
5. The parent drives both public reset requests in one epoch. A source-only or
   core-only **full-chain** reset is outside that parent contract. The legal
   common-assert/core-first-release test now hits line52 tuple `1/0`; remaining
   line57/59 rows stay OPEN as listed in the exact delta report.
6. Generic and real-XPM bit23 streams PASSed seeds610080/610081: 8,388,611
   four-plane output words each, all16 counter resets, zero UVM errors/fatals,
   and separate same-binary URG deltas showing both bit23 directions in all16
   lanes. The chunked bit24 oracle completed 16,777,222 words and passed its
   MATLAB fixture, record-count and SHA-256 checks. Generic seed610704 now
   PASSes four-plane bit-true replay, all16 counter reset checks, signed
    endpoints and zero UVM errors/fatals (CPU11512.180s). Generic URG has now
    completed with exit0; `bit24_delta_audit/summary.json` reports 16/16
    `.u_dpd` lane counters toggling bit24 in both directions. The merged raw
    generic score is87.01% (line87.09, condition76.46, toggle85.50, FSM100,
    branch73, assertion100); this is not full code-coverage closure. A fresh
    XPM 56-word bit-true license smoke seed610709 PASSed with zero UVM errors/
    fatals. Initial detached seed610708 spent most wall time blocked in WSL
    `p9_client_rpc` while reading the 2.5 GB vector set from `/mnt/e`; it was
    stopped after 47 CPU seconds with exit255 and its partial VDB is excluded.
     All eight oracle `.mem` files were staged under
     `/tmp/thermo5_bit24_xpm_610710/vectors`. XPM seed610710 has now PASSed
     16,777,222 four-plane words; its fresh VDB completed XPM-only URG with
     exit0 and the 16-lane audit confirms both bit24 directions in all16
     counters. Raw XPM score after that VDB is80.18%; bits25-31 remain open.
    The first concurrent XPM seed610705 was stopped under memory pressure,
    seed610706 received SIGHUP, and seed610707 exited255 before UVM start due
    license-server connection failure; those VDBs remain excluded. Bits25-31
   remain reachable/open; bit31 is a multi-day estimate, not an unreachable
   proof. Evidence: `runs/thermo5_bit24_oracle_20261012/` and
   `docs/verification/thermo5-bit24-counter-closure-20261012.md`.
7. Coefficient transport VCS/URG was rerun in the interactive licensed shell.
   Functional transfer is PASS, but low16-bit tap0 toggle slices across the
   four payload images remain open. Design legal stimulus that toggles those
   fields without changing the frozen identity output oracle, then rerun both
   builds. VCS-UVM fault-injection suite and clean licensed CI remain separate
   work.
8. Review physical lint/RDC, ASIC cap/leakage constraints and measured stalled
   throughput; actual mapped LEC is already PASS and needs no repeated run until
   implementation changes.
9. Board clocks/pins/parent I/O/RX/serial deskew/RF output remain independent OPEN
   work. No board is available; digital coverage does not imply board signoff.

Never rename partial adjusted scores or analytical disposition accounting100%.
The source of truth is actual URG plus exact remaining bins and proof contracts.

## Evidence navigation and maintenance

- [Coverage reasons](../../verification/thermo5-coverage-reasons-20261007.md)
- [DV/DE delivery](../../verification/thermo5-dv-de-delivery.md)
- [SpyGlass review](../../verification/thermo5-spyglass-review.md)
- [Two bug walkthroughs](../../verification/commit-bug-case-studies.md)
- [Oct 9 coverage/fault/CI resume](../../verification/thermo5-coverage-resume-20261009.md)
- [Reset/CDC evidence](../../verification/thermo5-reset-cdc-evidence.md)
- Tool commands: `dv/uvm/sim/README.md`, `dv/uvm/formal/README.md`,
  `docs/ai-native/commands.md`. Use unique run directories and source hashes.

Update this frontier and `docs/UPDATE_LOG.md` after a material result or next-action
change. Keep generated reports, vendor/PDK files and licenses out of commits.
Historical plans are under `../inactive/`; their scores/blockers are historical.
