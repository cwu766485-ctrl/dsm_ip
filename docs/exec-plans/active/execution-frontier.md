Warning: truncated output (original token count: 23755)
Total output lines: 1430

# Execution frontier

## Current execution state: TX-only Linux Gates 0–3 evidence recorded; raw code closure and physical signoff remain open (2026-10-29)

Gate 0 remains **PASS for Linux Generic/behavioral scope** at verification
source `04550289e1ecb5fa0e38168869d4f2539929cb80`. Gate 1 equivalence tests
remain **PASS** at `dfb15a278657e4417b545fc138df0f0dd0399ac4`: pair-look-ahead
passed a 4,096-cycle VCS miter and VC Formal (7/7 assertions, 4/4 covers, no
black boxes); the 2/4-tap non-identity DPD cases matched all four output
planes. No candidate was promoted to the product configuration.

Gate 2 Linux model campaign is complete. The QAM256 staged sweep used four
development and four disjoint held-out seeds and reports the finite-set
winner at RMS 0.10, STEP 5120, 20-bit state, no backoff/clipping: digital
BER `9.3643e-5` (21/224,256), EVM 2.4640%, SNDR 32.1675 dB. Nominal/stress
behavioral chain BER is `1.4269e-4` / `7.7144e-4`. Fixed 2/4-tap verification
coefficient images were worse than identity; this rejects those images only.
Four-plane gain/skew/fault sensitivity is also recorded. These are synthetic
model results with no product BER/BLER target, so communication acceptance is
`TARGET_UNDEFINED`; no physical link claim is made. See
`docs/verification/thermo5-tx-worst-case.md` and
`docs/verification/thermo5-tx-gate2-evidence.json`.

Gate 3 has **100% URG score for currently sampled applicable functional
covergroups**: Generic 4/4 applicable groups; AXI-Lite 8/8 groups. Generic
STOP/Restart coverage is not applicable to that direct Generic configuration
and remains 0% there; the AXI-Lite STOP/Restart group is 100%. This does not
close every source-level feature cross. Raw project RTL code coverage is
`RAW_100_OPEN`: Generic aggregate 80.81% (line 83.15%, condition 67.79%,
toggle 82.78%, FSM 100%, branch 64.47%, assertion 86.67%); AXI-Lite aggregate
84.59% (line 90.31%, condition 75.06%, toggle 96.63%, FSM 77.27%, branch
81.63%, assertion 86.67%). Current-source non-identity 2-tap/4-tap DPD
bit-true VDBs are included in that AXI-Lite report. The refreshed source-linked
ledger has 22,720 OPEN rows (17,941 Generic and 4,779 AXI-Lite). No exclusions
or denominator changes were applied; no adjusted score is claimed. Current
per-bin CSV/manifest and negative checker mutation are in
`docs/verification/thermo5-tx-coverage-signoff.md` and
`docs/verification/thermo5-tx-gate3-evidence.json`.

Current-source Linux Generic and AXI-Lite VCS regressions, STOP/drain/restart,
2,072-word EF2 positive/negative clamp/stall/rail/reset qualification,
eight legal digital corner patterns per configuration, and scoped EF2 plus
pair-look-ahead VC Formal pass. Generic EF2 reports a post-source finite-tail
underflow diagnostic with `early_underflow=0` because its direct wrapper does
not enable `core_drain`; AXI-Lite qualification reports zero underflow. This
distinction is retained in the coverage report. No RX or AI-DPD source was
changed.

Linux closure artifacts are complete through coverage audit and final report.
The consolidated gate table and exact Gate 2/Gate 3 published revisions are in
`docs/verification/thermo5-tx-final-signoff.md`. Gate 2 PR #4 is at
`d65ac3762d344c1001552890ae81cd9d243a4910`. Gate 3 PR #5 began with
implementation commit `459c69094f3353558321075305808d9712e6f335`; the
current-source 2/4-tap VDB, URG and 22,720-row ledger refresh is published at
`7314feeea1f4810ebb360a10ab83601dea91dc2a`.
Gate 4 remains OPEN for real XPM/Vivado/XSim, current GT Wizard/TXP, CDC/RDC
integration review, FPGA PPA, and physical QAM256 BER. Do not claim raw or
eligible 100% code coverage, physical RF pass, or hardware readiness.

<!-- Gate 0 historical state retained below for traceability. -->

## Historical execution state: TX-only Gate 0 accepted (2026-10-29)

Gate 0 is **PASS for Linux Generic/behavioral scope** at verification source
`04550289e1ecb5fa0e38168869d4f2539929cb80` (clean worktree; run manifests
record the exact SHA). The audited `thermo5` source was
`eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`; the verification commit changes
documentation only relative to RTL/DV/build inputs. No RTL, RX, AI-DPD,
architecture, or coverage denominator was changed.

Exact-source checks pass: Python 36/36 and oracle vectors; Generic VCS UVM
regression and URG merge; full AXI-Lite regression and URG merge; 112-word
STOP/drain/restart; three-seed 2,072-word EF2 sustained/clamp/stall/reset
qualification; EF2 scoped VC Formal (6 assertions proven, 3 covers covered,
zero black boxes). Raw Generic URG is 76.12%: line 2,969/3,593 (82.63%),
condition 594/949 (62.59%), toggle 81,740/102,612 (79.66%), FSM 22/22
(100%), branch 336/540 (62.22%), assertion 13/17 (76.47%), functional group
69.2592% (69.26%). The exact-source inventory has 784 records and no
exclusions. The expected illegal-frame assertion failure and three
unattempted assertions remain visible. The unsupported 79.86% score remains
withdrawn.

The first VCS invocation was license-blocked before compilation; the retry at
the same source SHA completed after checkout recovered. Real XPM/XSim/Vivado,
current GT Wizard simulation, routed FPGA PPA, and physical QAM256 BER are
not available or measurable in this Linux environment; no vendor/board PASS
is claimed.

Next: execute Gate 1 algorithm A/B and Gate 2 TX worst-case benchmark as
separate reviewable PRs, then Gate 3 feature/code coverage convergence. Keep
the verified main-chain configuration frozen until candidate evidence supports
an explicit promotion. Current commands, source SHA, reports, and evidence
hashes are in `docs/verification/thermo5-tx-baseline.md` and
`docs/verification/thermo5-tx-gate0-evidence.json`.

## Historical execution state: EF2 look-ahead and uploaded Linux signoff (2026-10-28)

The thermo5 baseline remains centered-cubic x2 + EF2 TIDSM, ORDER=2,
STEP=5120, 20-bit state, chronological 32-sample order. The exact two-sample
look-ahead factoring is a separate experiment behind `PAIR_LOOKAHEAD=0`; no
product wrapper selects it. Keep the baseline unchanged until a routed
comparison exists.

The GitHub `thermo5` branch now contains the EF2 experiment, signoff runner,
coverage gates, and report updates. The current Linux package passes its
Generic EF2 UVM/URG, AXI-Lite STOP/restart, three 2,072-word qualification
scenarios, pair-look-ahead VCS/formal equivalence, EF2 safety formal, four-PA
serializer loopback, and GT-parent behavioral recovery tests. Each package is
stored under `runs/thermo5_linux_ef2_signoff_<short-sha>/`; use its manifest as
the authority for the exact source SHA and 79 evidence-file hashes. The Python
reference suite passes 36/36. The local execution after the report-only update
is rerun from the published source revision before considering this closure
current.

The hosted GitHub Actions syntax/whitespace and Python test job passed on the
uploaded revision. The licensed EDA job is still queued for its self-hosted
Synopsys runner, so no Actions evidence artifact is available yet. Raw Generic
URG remains 76.12% aggregate (82.63% line, 62.59% condition, 79.66% toggle,
100% FSM, 62.22% branch, 76.47% assertion, 69.26% group); complete code
coverage remains OPEN.

XPM FIFO sources, XSim/Vivado, and the current GT Wizard/TXP simulation model
are not installed on this Linux host. The GT-parent fault test uses a
controllable test replacement, and serializer loopback is vendor-neutral.
Actual XPM/GT Wizard qualification, routed FPGA timing/resources, and physical
QAM256 BER remain OPEN. Pair look-ahead has no measured LUT/FF/DSP/Fmax result;
keep it experimental until a routed comparison is available.

## Historical checkpoint: centered-cubic EF2 main-chain integration (2026-10-28)

The latest user instruction promotes EF2 after verification. Thermo5 wrappers,
the Python oracle, the VCS Make defaults, and the ZU15EG parent now select
centered-cubic x2 interpolation and fixed-point EF2 TIDSM at STEP=5120. The
first-order (`TIDSM_ORDER=1`, STEP=7168) and causal interpolation
(`INTERP_CENTERED_CUBIC=0`) settings remain available for comparison. EF2 keeps
its 20-bit error state and chronological 32-sample update order.

The current-source long-frame qualification and monitor-observed interaction
checks are recorded in `docs/verification/thermo5-dv-portfolio.md` and
`docs/verification/thermo5-ef2-stability.md`. The local QAM256 screen remains
model-only: the RMS 0.10 held-out run measured 23 errors in 168,192 bits
(BER 1.367e-4); a newer six-seed, 24-symbol run at RMS 0.08 measured 117 in
672,768 bits (BER 1.739e-4). The different RMS points are not a controlled
comparison and neither establishes stable physical transmission.

Current VCS V-2023.12-SP1 checks pass on the promoted EF2 defaults: generic
full regression, AXI-Lite integration regression, two-packet STOP/drain/restart,
EF2 long-frame/saturation qualification, four-path behavioral serializer
loopback, and GT-parent link-loss/reset recovery test. STOP/restart checked 112
ordered four-plane words, all six event bins, and zero underflow/protocol
errors. The GT-parent fault test checks immediate PA blanking and sticky fault
reporting across a controlled active-packet link drop, with reset-gated
recovery. Its GT Wizard substitute and generic FIFO do not qualify vendor IP.
The AXI-Lite wrapper's fresh-run
prefill gate waits for two accepted source beats after a completed STOP/drain.
Python reference tests pass 36/36. The merged generic raw URG score is
79.86% (line 88.04%, condition 70.63%, toggle 81.17%, FSM 100%, branch
73.45%, assertion 76.47%, group 69.26%); code coverage is not closed.

The earlier GT Wizard TXP scenarios passed on Windows/Vivado 2026.1 for the
configuration at those run dates. Re-run them with EF2/STEP=5120 before using
them as current main-chain vendor-model evidence. Linux VCS does pass the
vendor-neutral serializer loopback; actual RX recovery, physical link, and
board QAM256 remain open. The current 32-level EF2 recurrence has no routed
timing result. FPGA resources/timing/power remain deferred per user direction.

XSim/PowerShell and Vivado XPM/GT Wizard sources are unavailable in this Linux
environment. VC Formal is installed and licensed through
`/opt/Synopsys/vc_formal/V-2023.12-SP2/bin`; the production EF2 stability proof
passed 6/6 assertions and 3/3 covers with zero black boxes. It proves 32-lane
I/Q intermediate bounds/no-wrap and state/output handshake behavior, but is
not formal equivalence against the Python oracle and does not prove clamp-free
behavior for every legal input. Reset/counter/CDC scoped proofs and centered
interpolator accumulator bounds also passed on Linux. A separate DPD identity
arithmetic proof remains inconclusive on multiplier/saturation properties at
the configured timeout. Rerunning GT Wizard/TXP under EF2, real-XPM coverage,
and physical QAM256 BER remain open because their vendor/hardware environment
is absent. FPGA resource/timing/power analysis is deferred per user direction.
The dated candidate-only entries below are historical checkpoints and are
superseded where they describe first-order/causal as the current default or
STOP/restart VCS as unrun.

## Centered-cubic + EF2 roadmap update (2026-10-27)

The sustained centered-cubic throughput fix remains confirmed by the XSim test:
1,024 contiguous outputs, zero bubbles. The STOP/restart UVM case now has six
explicit event bins, and the `thermo5-centered-cubic-ef2-vcs-regression`
target includes the two-packet case with centered-cubic/order-2/STEP=5120
vectors and RTL parameters. `make -n` confirms the configuration is passed
consistently. A real VCS run was attempted, but VCS exited before compile with
“Cannot find license file”; the runtime and coverage bins remain OPEN.

The EF2 pipeline study is documented in
`docs/architecture/thermo5-ef2-throughput-study.md`. A direct register split
does not preserve both the loop-carried error state and one-vector-per-cycle
throughput; a reviewed exact look-ahead/parallel transformation is still
required. No EF2 datapath RTL was changed in this update. Keep the frozen
causal/first-order default and the centered-cubic/EF2 option classified as an
architecture candidate.

### Roadmap checkpoint after 2026-10-27 reruns

1. **Centered-cubic sustained throughput: PASS.** Re-ran
   `run_xsim_centered_cubic_sustained.ps1`: 1,024 contiguous ordered outputs,
   zero bubbles, 1,023 cycles first-to-last. Evidence:
   `runs/centered_cubic_sustained_xsim/xsim.log`.
2. **EF2 candidate full regression: PARTIAL / OPEN.** Existing 2026-10-26
   generic/XPM candidate regression evidence remains recorded below. Added a
   two-packet STOP/drain/restart test with six checked event bins and included
   it in `thermo5-centered-cubic-ef2-vcs-regression`. The correct candidate
   target generated 112-word centered-cubic/order-2/STEP=5120 vectors, but the
   2026-10-27 VCS attempt stopped before compilation with `Cannot find license
   file`; this test's runtime and bins remain OPEN. The make dry-run confirms
   the complete candidate suite passes ORDER=2/STEP=5120 consistently.
3. **Timing-qualified EF2 pipeline: OPEN.** No pipeline RTL has been
   implemented: a naive register split breaks either bit-true state ordering
   or II=1. A reviewed exact look-ahead transformation is still required.
4. **Longer held-out benchmark: PASS as a model experiment.** Six new seeds,
   24 QAM256 OFDM symbols/seed, 672,768 uncoded bits, STEP=5120, 20-bit state,
   and RMS drive 0.08 measured 117 bit errors (BER 1.739e-4; 95% Wilson
   interval 1.451e-4 to 2.084e-4), 2.517% mean digital EVM, and no input/state
   saturation. Result:
   `runs/thermo5_ef2_heldout_extension_20261028/ef2_heldout.json`. This is not
   physical GT BER or a production BER signoff; it uses a different RMS level
   and longer frame than the earlier held-out run.
5. **Interview/frozen configuration: keep baseline frozen.** Causal
   interpolation + first-order TIDSM remains default. Centered-cubic + EF2
   remains an optional architecture candidate until pipeline timing, the
   blocked STOP/restart run, a defined system BER/BLER target, and physical
   constraints are closed.

The VCS candidate regression dry-run and Python reference-model unit suite
(36/36) passed. The current Windows host has about 6.8 GiB free, still below
the prior 12-14 GiB timing-driven route estimate; no route was launched.

Current implementation resource headroom is insufficient for the requested
route: Windows reports about 6.8 GiB free, below the prior 12-14 GiB estimate.
Candidate ZU15EG routed timing/PPA is therefore still OPEN. The extended
24-symbol, six-held-out-seed EF2 benchmark has completed; its model-only
results are recorded above and in the candidate status document.

## Centered-cubic + EF2 candidate closure (2026-10-26)

The optional centered-cubic x2 FIR + second-order TIDSM path is integrated
through the thermo5 AXI-Stream and AXI-Lite wrapper parameters. The frozen
default remains causal + first-order (`INTERP_CENTERED_CUBIC=0`,
`TIDSM_ORDER=1`). The centered FIR's two-entry queue previously could not
accept a replacement vector on the same edge as a full-queue pop. Its ready
look-ahead now permits simultaneous pop/push. A new XSim sustained test passes
1,024 contiguous output words with zero bubbles (`runs/centered_cubic_sustained_xsim/`).

The centered-cubic + EF2 (`STEP=5120`) candidate passed full-chain XSim with
generic and XPM FIFOs (32 source words / 56 words per output plane) and passed
the full VCS/UVM candidate regression with each FIFO implementation. The
regression includes bit-true, source bubble/PA backpressure, FIFO boundary and
empty/underflow, reset/replay, five residual-reset points, and expected
illegal-frame assertion/recovery. The partial-four-plane-ready test reports
plane-atomic cross coverage 100% and 109 partial-ready stall cycles. Evidence
is under `runs/thermo5_centered_ef2_signoff_20261026/` and
`runs/uvm_thermo5_…15755 tokens truncated…get. Resume from `physopt.dcp` only with a
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
| Scoped VC Formal | Per-topic proofs PASS; full identity payload and FWFT OPEN | Fresh split-source results dated Oct19: reset3/3, bounded counter3/3, unbounded counter35/35, generic CDC7/7 with9/9 covers, interpolation16/16 with5/5 covers, XPM reset2/2, and XPM residual7/7 with9/9 covers PASS. The identity job has5 proven/13 inconclusive assertions after fixing stale s6 references. XPM FWFT proves state encoding and covers stage1/read; its reset-transition cover remains inconclusive. Fresh run manifests are under `runs/thermo5_formal_harness_split*20261019/`. |
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
