# Execution frontier

## Current execution state: product-bound counter proof is inconclusive; final closure remains open (2026-10-31)

The current follow-up branch is `codex/thermo5-tx-outstanding-counter-formal`, draft PR #12 head `cdf187556aeceac3dfde19448dedea990adad379`, stacked on draft PR #11 head `402d62a3948848146e775a917b19bd0c9c8efff6` and PR #10. PRs #10–#12 and their ancestors remain unmerged. The audited product RTL SHA remains `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`; product configuration is unchanged: Centered-Cubic x2+x2, EF2 ORDER=2 STEP=5120, 20-bit state, 32 chronological lanes, `DPD_MAX_TAPS=1` identity, AXI-Lite parent and Generic FIFO. No TX algorithm, RX, AI-DPD, Raw URG, or denominator changes were made.

A fresh VC Formal V-2023.12-SP2 run passed the committed AXI-Lite configuration harness at `runs/thermo5_axil_cfg_final_closure_20261031/`. It proved 4/4 assertions, reached the legal coefficient-read Cover, marked three exact path Covers uncoverable, used zero assumptions, reported three non-vacuous assertions, zero black boxes, and zero setup violations. The fail-closed disposition updater validates the current RTL/DV hashes and Raw evidence, closing `TXB-65f3dfeee7bc0b854f52` (coefficient-read function default Branch at line 135). The same exact predicate supports the existing line-142 default Line bin. Both stay in Raw. Six exact bins are now `PROVEN_UNREACHABLE`; 18,587 of 18,593 code-gap rows remain OPEN. Raw remains line 3,190/3,796 (84.0358%), condition 583/846 (68.9125%), branch 440/637 (69.0738%), toggle 86,951/104,478 (83.2242%), FSM state/transition 13/13 and 22/22. Approved waivers and active `.el` exclusions are zero; status remains `RAW_100_OPEN`. A current-worktree recheck of the retained Raw source manifest failed closed (exit 3) on exactly three UVM compile-input hash differences; all product RTL hashes match. It is not an exact-current-worktree compile PASS, and the retained Raw report was not altered.

After VCS license recovery, a current-source negative-only AXI-Lite early-TLAST test passed at seed 420102: both expected protocol assertion messages were observed, the independent checker saw the sticky error, and public reset cleared it (UVM warning/error/fatal counts 0/0/0). A separate URG report hit the RTL line-141 Branch `TXB-646dd03c99766d877d30`. Its VDB is not merged into legal-product Raw; that Raw ledger row stays OPEN, with no denominator or metric change. Full evidence is in `docs/verification/data/thermo5-tx-negative-assertion-evidence.json`.

A product-bound Formal run targeted the two line-203/204 `outstanding_words_q` guard bins with a legal 32-beat source driver, arbitrary per-plane PA backpressure, Generic FIFO, and 35:28:16 AXI/source/core clock periods. It used no external SVA assumptions; source/core/output Covers were reached and both assertions were non-vacuous. VC Formal V-2023.12-SP2 returned INCONCLUSIVE at depth 142 (saturation) and depth 102 (underflow); both guard Covers were also inconclusive. The bins remain OPEN and no disposition was added. Evidence and exact hashes are in `docs/verification/data/thermo5-tx-outstanding-counter-formal-evidence.json`.

After VCS license recovery, the existing causal-FIR `thermo5_sku_interp1_empty_blocked_test` was exercised with the Centered-Cubic product defines as a scope probe. Compile passed; UVM timed out at 10,000 core cycles because the centered-cubic UVM branch ties the test's `interp1_stall_window` and `interp1_stage1_empty_blocked` probes low. This is not a DUT failure and yields no coverage credit; its VDB was not merged. The test README and a machine-readable run record now mark it causal-only. The prior exact product frame-replacement sweep remains the relevant centered-cubic experiment: 26 legal timing placements passed their stream checker but produced zero Raw branch/condition/line/toggle delta. Next, select another exact product-bin hypothesis with a predicted coverage delta before running VCS; do not repeat causal tests or unproductive phase/seed sweeps.

Functional Coverage remains 210/214 scoreable records hit; the four zero-hit records are two negative-only illegal-frame bins duplicated across URG views. All 210/210 legal applicable positive records are hit. No Group Report, VDB, or denominator was altered in this follow-up.

The VCS license was restored. A focused AXI-Lite configuration UVM run (seed 610931) passed with zero warnings, errors, or fatals and checked a legal identity-equivalent two-tap commit at a DPD frame boundary. A separate experimental mailbox-stability Formal property remained inconclusive. Its selected-property depth-4 trace did not run the AW/W stability assumptions, so it is not accepted as legal-protocol evidence. The temporary harness edits were reverted; mailbox stability remains OPEN and no disposition was added. Local diagnostics are under `runs/thermo5_axil_cfg_mailbox_formal_20261031/`, `runs/thermo5_axil_cfg_mailbox_trace_20261031/`, and `runs/thermo5_axil_mailbox_vcs_20261031/`.

Identity-DPD arithmetic Formal remains inconclusive. The 16-cycle source-gap case still reports 54 underflows with RUN asserted; its legal interface/service-rate contract is unresolved. The two centered-cubic product pop/push Branch bins remain OPEN after the fixed 26-phase legal sweep, which had zero Raw coverage delta. Next: review the product-bound counter proof for useful queue-conservation lemmas or tighter exact abstractions; do not convert depth-limited Inconclusive into a disposition. Then inspect remaining Branch tasks and add legal directed tests only where a predicted Raw bin delta and independent checker exist. Continue Condition, Line, and Toggle closure. Do not repeat prior phase sweeps or alter frozen algorithms. Real XPM, GT Wizard, FPGA PPA/timing, and physical QAM256 BER remain outside Linux signoff.

## Previous execution state: Phase 0 and Phase 1 Linux complete (2026-10-30)

The working branch `codex/thermo5-tx-final-closure` started at exact PR #7
head `f5394c3eaa6d283caf91c5c64b08a7d83c714a57`; PR #2–#7 ancestry is
continuous, and none were merged. Phase 0 source/evidence reconciliation and
Phase 1 Linux architecture studies are complete. PR #8 is open as a draft
stacked on PR #7 and is not merged; do not merge it.

The product contract is unchanged: Centered-Cubic x2+x2, EF2 ORDER=2,
STEP=5120, 20-bit state, 32 chronological lanes, four planes, one-tap identity
DPD, Generic FIFO for Linux. No product algorithm/default, RX, AI-DPD, or
candidate parameter was changed. PR #7 product Raw remains 81.99%:
line 3,190/3,796, condition 583/846, branch 440/637, toggle 86,951/104,478,
FSM 13/13 states and 22/22 transitions; the then-reported functional tally was
170/174 raw and 170/170 applicable positive bins. A later complete Group
Report extraction found 40 omitted EF2 cross-bin records and corrected the
active count to 210/214, without changing URG data or the denominator. Raw
equals adjusted; there are zero waivers and zero
exclusions; status stays `RAW_100_OPEN`. No product VDB was regenerated or
merged during this study.

The common QAM256 benchmark used four development and four disjoint held-out
seeds, 12 symbols per seed, RMS 0.10, 4096 FFT, 512 CP, 584 active tones,
250 MHz bandwidth, 4097-tap receiver, and STEP=5120 for all four primary
architecture cells. Held-out EF2 + centered-cubic measured BER 21/224,256,
EVM 2.464%, SNDR 32.168 dB; causal interpolation measured about 20.8% EVM and
0.215 BER. First-order STEP=7168 remains a separate sensitivity point. These
are model-only rankings with no accepted product BER/BLER target.

The DPD ILA used development data to produce signed Q2.14 two-/four-tap images,
then tested four held-out seeds. The fitted 2-tap and 4-tap BER were
4.756e-5 and 7.135e-5 versus identity 4.162e-5; the BER confidence intervals
overlap. The fitted images passed 93,184-sample VCS bit-true RTL/oracle miters
with zero digital output saturation, but neither was promoted. Their PA/output
power and adjacent-band proxy results are in the ablation report/data; proxy
metrics are not standard ACLR or calibrated RF results.

The PAIR_LOOKAHEAD miter passed 4,096 cycles including directed exact negative
tie, positive and negative clamp, stalls, bubbles, and a drained midstream
reset; handshake/data and four EF2 states matched. Existing scoped Formal
equivalence is retained, but same-device synthesis timing/PPA was not run.

Checks for this follow-up: Python 3.12 unittest 44/44 PASS; fitted 2-tap and
4-tap DPD VCS miters PASS; PAIR_LOOKAHEAD VCS miter PASS; ablation and DPD
held-out model runs PASS; compact CSV/JSON/PSD/SVG package and SHA-256 evidence
manifest generated. Full product coverage/regression was intentionally not
repeated because its simulation inputs are unchanged from the source-linked
PR #7 evidence.

**Next:** review PR #8. Phase 2–6 TX coverage/formal closure, DPD identity
proof convergence, real XPM/GT Wizard, FPGA PPA/routed timing, and physical
QAM256 BER remain later OPEN work. Vivado is not available in this Linux flow.

The Gate 0–3 notes immediately below preserve the earlier closure checkpoints
for traceability; their source/configuration scopes do not change here.

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
`d65ac3762d344c1001552890ae81cd9d243a4910`; Gate 3 PR #5 code is at
`459c69094f3353558321075305808d9712e6f335`.
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
`runs/uvm_thermo5_i2_d1/` (ignored local run output).

The optional EF2 is **not timing-qualified**: 32 serial nonlinear recurrence
steps remain in one combinational path. Candidate ZU15EG synthesis generated a
62,597,295-byte `synthesized.dcp`, clock report, and utilization report (88,880
LUTs, 58,909 FFs, 2,108 DSP48E2, 6.5 BRAM tiles), but Vivado did not return its
clean PASS marker and reported failure to load feature `fpga_compiler`. Core,
AXI-Lite, and AXI-Stream modeled periods are 4.571, 10, and 8 ns. No routed
timing result exists; placement/routing needs the license issue resolved and
12-14 GiB implementation memory headroom (last recheck: Windows host 1.9 GiB
free; WSL 11 GiB available). The 20-bit saturating state proves
bounded arithmetic/no wrap, not no-clamp behavior for arbitrary signed-16
inputs; tested OFDM frames did not clamp, but high/constant input can. The new
stop-drain-restart scenario is present, but runtime was blocked by VCS vendor
daemon unavailability; its three-minute license queue expired before test
execution. The
project-level BER/BLER acceptance target is unspecified. See
`docs/verification/thermo5-centered-cubic-ef2-status.md`.

Next: restore VCS/Vivado license-server access; run the stop-drain-restart UVM
case; obtain enough memory for timing-driven ZU15EG implementation; and either
produce a timing-qualified EF2 microarchitecture or keep this path exploratory.
Do not promote the candidate to the frozen SKU or claim physical GT/BER signoff.

## P0 GT-parent stress, special-pattern, and negative-frame closure (2026-10-25)

The Vivado 2026.1 four-GTH GT Wizard XSim flow now has separately selectable
baseline, stress-pattern, and bad-frame scenarios. Four seeded full-chain tests
(ramp, zero I/Q, alternating signed extrema, and impulse) each accepted 32 AXIS
beats and passed 56 words per lane against sampled TXP pins at a modeled
14.0-Gb/s line rate. The seed `0x5eed0000` produces eight source-valid gaps
during the first eight prefill beats; the source has no injected bubbles after
the AXI-Lite RUN write completes.

The negative-frame scenario passed early-TLAST protocol detection, 16-beat
partial-frame serializer fault/PA blanking, common-reset clearing, and two
legal serial replays. Full evidence and exact commands are recorded in
`docs/GT_PARENT_STRESS_AND_ERROR_TESTS.md`, with logs under
`runs/thermo5_gt14_stress_20261025_224631/`.

The generic-FIFO VCS full-IP regression passed nominal bit-true,
valid-gap/backpressure, FIFO-full/empty, active reset/replay, five residual
reset points, and expected misaligned-frame assertion/recovery. Evidence is
under `runs/thermo5_stress_dv_regression_20261025/`.

These are digital simulation results only; RX recovery/compare, analog
link/BER/eye, board I/O constraints, and physical GT timing remain open.
Next: close RX-clock/data recovery and gather the concrete parent board clock
and I/O constraints before any RX, routed GT, or hardware signoff claim.

## P0 Four-lane GT serial TX full-chain XSim (2026-10-25)

Added a standalone, one-command XSim setup for the ZU15EG four-channel
GTHE4/GT Wizard parent. It generates the 14.0-Gb/s RAW, 64-bit GT Wizard
behavioral model without requiring a prior synthesized project. The test
drives two AXIS frames through the AXI-Lite-configured thermo5 frontend and
captures the actual modeled serial TXP pins at the configured 71.428571-ps UI.

PASS evidence: `runs/thermo5_gt14_e2e_clean_20261025_222945/`. XSim accepted 64
AXI beats and observed 112 transmitted 256-bit user words. Both frames matched
all 56 serialized words per lane bit-true (3,584 bits/lane/frame, four lanes);
the alternating idle pattern matched 128 sampled bits/lane at 14.0 Gb/s with
P/N differential polarity. GT RX comparison was deliberately skipped because
RX user-clock/data recovery remains open. This is a vendor behavioral-model
digital TX result, not analog eye/jitter/BER, physical deskew, board output, or
GT-PMA timing signoff.

The previous parent `synth_design` invocation remained in constraint/timing
initialization for several minutes and was stopped to avoid blocking the
simulation task; it produced no synth completion marker and is not a PASS.
The new simulation runner creates the GT simulation project without invoking
that synthesis step. Next: separately debug GT RX recovery and provide actual
parent/board clock and I/O constraints before routed GT or hardware claims.

## P0 VCU118 frozen thermo5 synthesis mapping (2026-10-25)

Added a synthesis-only Vivado runner for the frozen no-AXI-Lite thermo5
AXI-Stream top and mapped it to the VCU118 device `xcvu9p-flga2104-2L-e`.
Vivado 2026.1 completed `synth_design`, wrote a checkpoint and reports, and
returned the runner PASS marker. Evidence is in
`runs/thermo5_vcu118_synth_retry2_20261025_2132/`.

Post-synthesis estimate: 44,444 LUTs (3.76%), 53,517 FFs (2.26%), 496 DSP48E2
(7.25%), 6 RAMB36E2 + 1 RAMB18E2 (6.5 BRAM tiles, 0.30%), and 0 URAM. The
synthesized timing estimate at 125/218.75 MHz is WNS +1.140 ns and WHS +0.039
ns, with no failing setup/hold endpoints in that report; it is not placed or
routed timing closure. `check_timing` reports 570 top-level inputs without
input delays and 264 outputs without output delays, as expected for this OOC
mapping.

The run reported 201 synthesis warnings, 0 critical warnings, and 0 errors.
Review the repeated `dpd_memory_poly` set/reset-priority warning (Synth 8-7137)
and the two-entry metadata/data arrays mapped to registers because of
asynchronous-reset coding (Synth 8-4767). The ZU15EG-specific GT parent and
VCU118 package I/O/GT constraints are not part of this top or run. Next: audit
those warnings, then create a VCU118-specific GT parent/constraints before any
board-level place-and-route claim.

## P0 EF2 long-frame QAM256 BER, state-width, and PAPR/backoff screen (2026-10-25)

Added `benchmark_thermo5_ef2_robust.py`. It retains the existing fixed-point
EF2 recurrence (`u=x+2e1-e2`, bipolar sign quantizer, Q1.15 input) and the
chronological sample-state update; only STEP, input waveform level, optional
state saturation rails, source-rate PAPR clipping, and whole-waveform backoff
vary. The scan uses 12 OFDM symbols per seed, 4096 FFT, 512 CP, 584 carriers,
three development seeds (701/709/719), and disjoint held-out seeds
(809/811/821). BER is the primary rank key; current mapper labels are
natural-binary and uncoded.

The 45-point development STEP/RMS sweep selected STEP=5120 at RMS=0.10 with
4/168,192 bit errors (BER 2.378e-5) and 2.459% mean EVM. On the independent
held-out set it measured 23/168,192 digital errors (BER 1.367e-4), worst-seed
BER 1.962e-4, 2.461% mean EVM, and no DSM input/state saturation. The 19-bit
state matched 20-bit output and BER with zero clipping across all six tested
12-symbol QAM waveforms; maximum state was 5.132 against its approximately
8-unit rail. The 18-bit candidate clipped 54 times across its six frames.
This is evidence for the tested OFDM envelope only: a constant high signed
input also saturates the 19-bit model, so no universal no-clipping claim is
made and the 20-bit RTL is unchanged.

The nine-point 0/3/6-dB-backoff × no/7/9-dB-PAPR-limit development sweep
selected no clipping and 0-dB backoff by worst nominal/stress output-chain
BER. The development baseline's nominal/stress BER was 1.249e-4/6.778e-4.
At 6-dB backoff with no clipping, stress BER rose to 2.699e-3 and modeled
nominal output power fell from -30 to about -36 dBm. The held-out baseline
measured 33 nominal and 129 stress bit errors (168,192 bits per profile).
The output-chain result is sensitivity modeling, with output power scaled by
measured DPA RMS relative to the per-seed baseline; it is not calibrated PA or
board data. Because baseline won development, it is the only CFR/backoff point
retested on held-out seeds.

Evidence: `runs/thermo5_ef2_robust_20261025/summary.json`. Thirty-six Python
unit tests and `py_compile` pass. A 2-symbol smoke run completed. No RTL,
feedback coefficient, quantizer, or sample-time behavior changed. The
existing optional EF2 RTL remains a 20-bit state, and the frozen first-order
default remains unchanged. Regenerated the 56-word centered-cubic EF2 oracle
and ran `thermo5-vcs-run` with `TIDSM_ORDER=2`, STEP=5120: VCS compile and
focused UVM bit-true test PASS, 32 source words / 56 output words, four planes
bit-matched, zero UVM_ERROR/FATAL. Logs and vectors are under
`runs/thermo5_ef2_robust_20261025/`. The full VCS regression, XSim, and FPGA
resource/timing were not run. Next: select the required system BER target and
operating input envelope; then run the full EF2 VCS regression before any RTL
width/default change.

## P0 EF2 fixed-point boundedness and RTL candidate (2026-10-24)

Added optional `TIDSM_ORDER=2` through the thermo5 wrappers, with first-order
remaining the default. `tid32_cartesian_ef2_fs4_gt_tx.sv` implements
`u=x+2e1-e2`, a sign quantizer, and signed-20-bit saturated error feedback.
Inputs are signed Q1.15; state is signed Q4.15; temporary arithmetic is signed
Q6.15. `docs/verification/thermo5-ef2-stability.md` proves inductively that
state is bounded and arithmetic cannot wrap for any signed-16 input. This is
not a proof that the unclamped loop never saturates.

The Python word oracle and independent integer sample-stream model agree on
the four output planes. All 33 Python tests pass. A fixed-point 256-QAM
confirmation at STEP=5120, centered cubic, 4096 FFT, 512 CP, 584 active
carriers, eight symbols, and seeds 101/307/503 measures 2.4724% mean /
2.4890% worst-seed digital EVM, 32.138-dB mean SNDR, 4 symbol errors, and 5
natural-binary bit errors in 14,016 decisions. Input/state saturation counts
are zero; largest observed state/input are 4.9763/5.9763. The illustrative
nominal/stress output-chain EVM is 2.6023%/3.0036%, with 11/46 symbol errors.

Evidence: `runs/thermo5_step_ntf_sweep_20261024/ef2_step5120_fixed_analog_8sym.json`
and `runs/thermo5_ef2_centered_vectors_20261024/`. The candidate is included
in UVM, XSim, OOC, and FPGA source manifests. The focused VCS UVM bit-true test
passed on 2026-10-25 at STEP=5120 and `TIDSM_ORDER=2`; the full regression and
formal proof remain open. No formal engine is available here. FPGA
resource/timing is deferred per user direction; XSim was not run on this Linux
host. Retain the frozen first-order STEP=7168 SKU until the full candidate
regression and system link acceptance complete.

## P0 Thermometric STEP and DSM NTF/order screen (2026-10-24)

Implemented `benchmark_thermo5_step_ntf.py` and software-only TIDSM alternatives
in `dsm_refmodel/thermo5_experiments.py`. The experiment measures 256-QAM after
the actual four-plane reconstruction and OFDM receiver, recording EVM, SNDR,
symbol errors, natural-binary uncoded BER, branch clipping, and finite-frame
error-feedback state/input headroom. The frozen first-order path is checked
against the scalar RTL recurrence. EF order 1/2/3 are floating-point prototypes,
not RTL or fixed-point-equivalent implementations.

The 2-symbol, three-seed STEP sweep selected the existing STEP=7168 for the
current RTL first-order structure; the confirming eight-symbol run measured
3.273/3.310% mean/worst-seed EVM and 198 symbol errors among 14,016 decisions.
At STEP=8192 branch-offset clipping appeared and EVM exceeded the 3.5% screen.
The full EF2 comparison selected STEP=5120: 2.472/2.489% mean/worst-seed EVM,
32.138-dB mean SNDR, 4 symbol errors and 5 natural-binary bit errors among
14,016 decisions. Its largest observed error-state / quantizer-input values
were 4.976 / 5.976, below the finite-frame Q4.15 headroom check of 8. EF2
STEP=6144 was slightly worse at 2.513% mean EVM with 13 symbol errors; EF2
STEP=7168 exceeded the observed headroom bound, and EF3 diverged on this
workload. Under the same nominal/stress output-chain assumptions, EF2 STEP=5120
measured 2.602% / 3.004% mean EVM after DPA, output FIR, and kTB/NF; worst
seed was 2.620% / 3.028%. It had 11 / 46 hard-decision symbol errors (18 / 72
natural-binary bit errors) across 14,016 decisions. The matched current RTL
first-order STEP=7168 measured 3.370% / 3.685% EVM and 234 / 359 symbol errors;
the stress EVM exceeded the 3.5% screen. EF2 is the strongest tested software
candidate for the 256-QAM objective, but it still has finite-frame errors and
is not RTL or fixed-point qualified. Do not promote it before fixed-point
stability, bit-true, and implementation qualification.

Evidence: `runs/thermo5_step_ntf_sweep_20261024/step_sweep_2sym.json`,
`ntf_order_sweep_2sym.json`, `ntf_finalists_8sym.json`,
`ef2_step5120_analog_8sym.json`, and
`rtl_first_order_step7168_analog_8sym.json`, with CSV companions. The screen
uses 4096-point FFT, 512-sample CP, 584 active carriers, 0.10 RMS/0.35 maximum
drive, and the centered-cubic interpolation candidate. Natural-binary BER and
finite-frame zero-error counts are exploratory metrics, not a production BER
guarantee.
This initial screen preceded the fixed-point model and RTL candidate; see the
current EF2 section above for its boundedness proof and outstanding VCS check.
No FPGA PPA/timing work is in scope on Linux.

## P0 nonlinear DPD, packet-tail, and low-power verification (2026-10-24)

Closed the three previously open centered-cubic verification gaps. The Python
oracle now models the RTL's signed-Q2.14 memory-polynomial DPD, including
temporal taps, arithmetic shifts, and signed-16 saturation. A directed AXI-Lite
test commits a two-tap image with nonzero cubic terms before the first frame
boundary and checks all four PA planes bit-true. Both a one-quantum packet
(32 AXI beats, 56 words) and two consecutive one-quantum packets (64 beats,
112 words) pass; each packet closes its own centered-FIR frame tail.

The centered-cubic low-power test requests STOP after 20 accepted beats. The
AXIS wrapper continues admitting that open packet through its accepted TLAST,
then closes ingress. VCS verifies all 56 four-plane words, no underflow or
protocol error, zero outstanding work, and return to IDLE. This test found and
closed the prior premature-ingress-close condition.

Evidence: `runs/thermo5_gap_closure_axil_vcs/` (56- and 112-word nonlinear
bit-true cases), `runs/thermo5_gap_closure_lowpower_vcs/`, and
`runs/thermo5_gap_closure_baseline_vcs/` (seven-test causal generic-FIFO VCS
regression). Twenty-four Python unit tests also pass. XSim is unavailable on
the Linux host; FPGA resource/timing remains deferred per user direction.

Current Python benchmark status remains: centered cubic ranked first across
all 18 held-out FIR/normalization/PAPR/backoff combinations in the 450-case
sweep. The three-seed raw-TID receiver screen gives 3.273% digital EVM /
29.702 dB SNDR, 3.370% / 29.447 dB for the illustrative nominal chain, and
3.685% / 28.671 dB for its stress profile. The analog-chain settings are
sensitivity assumptions. The STEP and DSM NTF/order screens, including the
full-length analog sensitivity comparison, are captured in the active section
above; implementation qualification remains open. The frozen default SKU has
not changed.

## P0 centered-cubic streaming RTL (2026-10-24)

Implemented the optional Q14 centered-cubic path using
`dsm_interp_x2_centered_cubic_vector.sv`. `INTERP_CENTERED_CUBIC=0` keeps the
existing causal path as the default; selecting `1` enables both centered x2
stages. The module uses `[-1,9,9,-1]/16`, the Python oracle's round-away-from-
zero and W-bit saturation, and elastic valid/ready handshakes. Frame starts
provide zero history. At frame end, stage 1 processes a synthetic zero-source
vector and tags its interpolated output as lookahead; stage 2 uses it for the
final real output and drops the tagged tail, preserving the output word count.
The ZU15EG GT parent exposes the same parameter and keeps it disabled by
default.

The AXI `TLAST` marker crosses the 14:8 CDC/gearbox and is carried with data
through ingress metadata, frame gain, DPD metadata, and both interpolation
stages. Carrying it with the frame-gain pipeline fixed the first VCS timeout,
where a direct, un-delayed frame-end wire never reached the matching sample.
Valid frame ends must align to a complete 56-sample gearbox group (four
14-lane beats); the existing 32-beat UVM packet satisfies this rule.

The centered-cubic VCS bit-true test passes with stressed PA backpressure:
32 accepted AXI beats produce 56 four-plane output words matching the Python
oracle; three internal frame starts and one accepted `TLAST` are observed, with
zero UVM errors/fatals. The default causal generic-FIFO regression also passes
all seven tests, including reset/backpressure and the expected illegal-frame
assertion. Evidence is under
`runs/thermo5_centered_cubic_final2_20261024/`,
`runs/thermo5_centered_cubic_baseline_regression_fix1_20261024/`, and
`runs/thermo5_centered_cubic_axil_final_20261024/`. The AXI-Lite centered
configuration test also passes with the tagged frame tail and DPD frame-boundary
commit active.

XSim was not run on this Linux host. Per user direction, FPGA resource and
timing analysis remain for the FPGA environment. The short/long/consecutive
packet and low-power checks were added in the newer P0 closure entry above.
Still open: XSim regressions and FPGA mapping/timing of the optional centered
path. Do not change the default SKU until those implementation checks and the
system integration decision are complete.

## P0 raw TID receiver and centered-FIR contract (2026-10-24)

Audited the frozen RTL2 time labels: each x2 stage emits exact `x[n]`, then
`(x[n]+x[n-1])/2` on the odd phase. Under the declared `n+0.5` timestamp,
that odd value estimates the previous midpoint. The front-end drops the first
32-sample TID result; the independently checked effective alignment is 1,024
7-GHz complex samples (2,048 raw bits/samples) from the actual four planes.

Added `benchmark_thermo5_tid_receiver.py` and receiver helpers. The model
checks all four branches against scalar EFM, combines the serialized planes,
performs 3.5-GHz Fs/4 DDC, applies 14-GHz and 7-GHz receive FIRs, and reports
256-QAM EVM/SNDR. Three 8-symbol seeds at 0.10 RMS / <=0.35 peak each had zero
EFM mismatches over 1,335,296 samples per candidate. Centered cubic averaged
3.273% / 29.702 dB digital, 3.370% / 29.447 dB under the illustrative nominal
output model, and 3.685% / 28.671 dB under stress. Frozen RTL2 averaged
20.827% / 13.628 dB digital. Full results:
`runs/thermo5_tid_receiver_20261024/summary.json`.

The two centered stages have a 2.25-source-sample future dependency, rounded
to three source samples for a causal stream. The parallel-config wrapper now
exposes `s_axis_tlast` for the optional centered path. Existing causal behavior
remains the default. Python unit tests pass and matching oracle vectors are in
`runs/thermo5_centered_cubic_vectors_20261024/`. The initial centered VCS run
timed out because `TLAST` was not delayed with frame-gain data; the sideband
pipeline fix and successful reruns are recorded above. The earlier generic
regression retry is in `runs/thermo5_tid_receiver_vcs_retry_20261024/`.

## P0 Python FIR and input-drive A/B sweep (2026-10-24)

The corrected-EVM FIR candidate is now explicitly selected for Python
architecture experiments: centered cubic `[-1,9,9,-1]/16` in both x2 stages.
The FPGA RTL remains on its causal two-tap preset. Added
`benchmark_thermo5_architecture.py`, comparing five FIR candidates with a
256-QAM / 250-MHz occupied-bandwidth, 1-GHz complex-baseband workload. Each
candidate sees identical input symbols, behavioral DPA, output FIR, and
kTB/NF noise. The sweep uses fixed-average-power and peak-normalized modes,
no/7/9-dB radial PAPR limits, 0/6/12-dB input backoff, two development seeds,
and three held-out seeds. JSON and representative PSD are under
`runs/thermo5_architecture_ab_20261024/`.

Across 450 candidate/configuration/seed cases, centered cubic ranked first in
corrected EVM for all 18 held-out normalization/PAPR/backoff combinations and
for each held-out seed scored separately. For fixed-average power with no PAPR
limit, its three-seed corrected EVM means were 4.853% / 0.802% / 0.871% at
0/6/12-dB backoff; assumed output power was -30.00/-35.66/-41.63 dBm, and
in-band SNDR proxy was 27.75/44.31/47.35 dB. Six dB improved EVM with about a
5.66-dB assumed output-power cost; 12 dB gave little extra EVM improvement and
lost another 5.97 dB. At 6 dB, the 7-dB radial PAPR limit raised held-out mean
corrected EVM from 0.802% to 2.233% and worsened the adjacent-band proxy from
-49.00 to -37.41 dBc. This makes 6-dB backoff/no clipping a promising point in
this model, not a universal optimum.

The aligned causal RTL 2-tap baseline measured about 36.8% corrected EVM at
6-dB backoff in this exact waveform comparison. That unusually large gap makes
the RTL preset's even/odd sample-time convention an audit item before using
the difference as a hardware performance prediction. Centered cubic is adopted
as the preferred Python FIR candidate, not yet as a frozen RTL setting. This is
the prioritized P0 FIR/Drive/PAPR screen, not a complete thermo5/TIDSM EVM
result: it uses illustrative DPA/output/noise settings, periodic symbol edges,
and does not decode the actual four TID planes or report FPGA LUT/FF/DSP/WNS/
power. Only eight OFDM symbols per seed were used. The later raw-TID receiver
and STEP/NTF screens now measure decoded four-plane performance; fixed-point
DSM stability, measured analog calibration, and FPGA implementation signoff
remain open.

## Digital GT errors and analog output-chain sensitivity (2026-10-23)

Reworked `dsm_refmodel/link_models.py` and split the screens. The GT injector
now flips independent data bits in the four 64-bit TID output planes produced
by the Python bit-true thermo5 model; it reports bit and affected-word counts.
It models discrete digital corruption, not additive noise, timing jitter,
line coding, CDR, or the electrical GT eye. The 56-word BER=1e-3 sanity run
observed 14 flips/14,336 bits and 13 affected words; this short run is not a
low-BER estimate (`runs/thermo5_gt_bit_errors_20261023/summary.json`).

The link screen reports interpolation error, deterministic DPA
AM/AM/AM/PM/envelope-memory and complex output-network response, then thermal
noise added at the declared observation plane. Thermal noise is computed with
kTB+NF and scaled from normalized waveforms using declared output power. The
64-symbol seed-20261023 report is
`runs/thermo5_link_benchmark_20261023/summary.json`. Centered cubic corrected
EVM was 0.966% ideal, 1.699% under the illustrative nominal chain, and 3.404%
under stress; forward-linear was 4.939%, 5.039%, and 5.692%. Stress raw EVM was
6.337% cubic versus 6.216% forward-linear, so gain/phase-corrected EVM and raw
EVM rank the candidates differently. The stress thermal-noise contribution
was about 1.3% EVM at 37.95 dB calculated SNR.

Centered cubic remains the preferred FPGA algorithm candidate, not a direct
coefficient setting for the frozen causal interpolator. Its future-sample
lookahead adds latency and its final samples cannot be drained with the
current frontend's frame-start-only contract. A frame-end/flush contract,
throughput/resource/timing mapping, and receiver metric decision remain open;
the FPGA frozen 2-tap SKU was not changed. DPA/output assumptions are not
calibrated to a circuit or board; the noise-plane signal power, bandwidth and
NF are illustrative. EVM remains sample-domain with a per-symbol scalar fit,
and the adjacent-band figure is not standard ACLR.

## Python thermo5 reference and interpolation benchmark (2026-10-22)

Added a pure-standard-library Python reference for the frozen identity-DPD
thermo5 chain and a vector generator that emits the existing four-plane UVM
`.mem` contract. The Python-generated 56-word, two-tap vectors passed the full
generic-FIFO `thermo5-vcs-regression`: bit-true, bubble/backpressure, FIFO
boundary/empty, reset/reset-sweep, and expected illegal-frame checks all
completed with zero UVM errors/fatals. Evidence:
`runs/thermo5_python_vectors_20261022/` and
`runs/thermo5_python_vcs_retry_20261022/`.

An initial 64-word vector attempt did not match the UVM contract (which is 56
core words/32 source beats); it also used non-boundary frame markers. The
generator defaults now match the Linux/UVM contract: 56 words and frame starts
1, 15, and 36. The corrected run passes. Python seed generation is deterministic
but intentionally does not reproduce MATLAB's PRNG sequence; `--input-dir`
accepts MATLAB source vectors for direct comparison.

The first interpolation screen used 64 deterministic 64-QAM OFDM symbols,
256-point FFT, 100 active subcarriers, and two cascaded x2 stages. Results at
seed 20261022: RTL 2/3/4-tap presets measured 72.01/86.25/97.02% raw EVM
(70.11/79.58/84.32% after per-symbol common gain/phase correction); forward
midpoint linear measured 6.23% (4.96% corrected); centered cubic Lagrange
measured 1.12% (0.97% corrected). First-image rejection was 5.73/3.22/1.38
dBc for RTL 2/3/4 taps, 29.76 dBc for forward linear, and 43.72 dBc for
centered cubic. Adjacent-band leakage proxies were -46.03/-39.94/-35.62/
-91.76/-91.31 dBc, respectively.
Raw JSON is at `runs/thermo5_interp_benchmark_20261022/summary.json`.

This result is an interpolation-only digital screen; its adjacent-band value
is not standard ACLR and it omits DPD, TID, PA, RF filtering, and receiver
recovery. The current RTL emits each exact sample before a causal phase-1
estimate built from current/past samples, while the centered candidates use
future samples. The large EVM delta makes phase/time ordering a design review
item; no RTL behavior has changed. The corrected complex least-squares EVM
values above supersede the initial screening values; raw EVM, image rejection,
and adjacent-band proxies are unchanged. Confirm the intended interpolation time
convention before selecting a new candidate. MATLAB, XSim/Vivado, and the
Windows PowerShell bridge are unavailable in this Linux environment, so no
independent MATLAB or XSim run was made.

ASIC notes now follow the FPGA frozen behavior (`INTERP_TAPS=2`,
`DPD_MAX_TAPS=1`, DPD enabled with the identity image in UVM, low-power
control off), with a guard that checks these settings. The FPGA OOC top retains
runtime coefficient inputs, while the ASIC wrapper ties identity constants;
their PPA results are not controlled for both coefficient-interface and FIFO
differences. A fixed-image FPGA OOC wrapper and Vivado rerun would be needed
for a like-for-like comparison. No 28 nm standard-cell DB, analog/RF PDK views,
`dc_shell`, or `fm_shell` is configured or present in the visible workspace,
so AMS support cannot yet be verified.

## Current packet framing, GT-parent simulation, and ZU15EG OOC status (2026-10-21)

The optional AXI-Lite wrapper now exposes AXI-Stream `s_axis_tlast`; the
four-GTH ZU15EG parent carries the signal through to the wrapper and its XDC
input-delay group. A legal packet is one or more 32-beat quanta (32/64/96...)
so each quantum maps to 56 core/output words and preserves gearbox and
GT-user-frame alignment. Early `TLAST` is sticky-diagnosed and does not change
alignment. The frozen parallel-config SKU remains unchanged and has no
`TLAST` port.

The reproducible two-quantum test passed using the new
`thermo5-axil-long-frame-vcs-run` target: 64 accepted source beats, one legal
`TLAST`, 112 bit-true output words per plane, zero UVM errors/fatals and no
underflow. Generic and real-XPM 112-word runs are preserved under
`runs/thermo5_longframe_make_20261021/` and
`runs/thermo5_tlast_axil_xpm_20261021/`. The dedicated parent reset-only XSim
also passes with `TLAST` connected, using an isolated copy of the prior parent
project at `runs/thermo5_gt_parent_tlast_sim_20261021/`; RX data comparison is
skipped by design in this run.

The current-source ZU15EG parent synthesis attempt at
`runs/thermo5_parent_current_synth_20261021/` was interrupted after system
available memory fell to about 0.7 GiB. Vivado had parsed the 125-MHz
AXI-Stream, 100-MHz AXI-Lite, 200-MHz free-run and assumed 125-MHz GT-reference
clocks and emitted partial post-synth reports, but it did not produce a
checkpoint or clean exit. Those clock-interaction/timing reports are not used
for signoff because their first run preceded the asynchronous clock-group and
RX diagnostic output-delay commands. The parent Tcl report ordering has now
been fixed so a retry reports only after all clocks, provisional I/O budgets
and asynchronous groups are applied. Rerun synthesis/route only after memory
is available; the known route requirement is 12..14 GiB. The XDC values remain
provisional 0.20..2.00 ns input and 0..1.50 ns output assumptions, not real
SoC/board budgets. Actual producer/consumer min/max delays, board clock-source
validation, CDC/RDC review, RX alignment, and physical GT output remain open.

The 2026-10-19 graceful-stop entry below records the pre-`TLAST` fixed-frame
implementation and is historical; use this section for current framing scope.

## AXI-Lite graceful RUN stop (2026-10-19)

Replaced the AXI-Lite wrapper's hardwired `core_drain=0` with a graceful-stop
sequence. RUN low closes AXI ingress at the configured fixed 32-beat source
frame boundary (the AXI-Stream interface has no `TLAST`), keeps core and GT-user
consumption active, and waits for the FIFO/14:8 gearbox/frontend/four-plane
output to empty before clearing RUN_ACTIVE. STATUS bits 3/4 report RUN_ACTIVE
and DRAINING. Real starvation while RUN remains high still reports underflow.

Generic and real-XPM AXI-Lite UVM/URG regressions pass, including the new
mid-frame stop case: each checks all 56 four-plane words, no underflow or
protocol error, and status clearing after the final output. The generic frozen
SKU regression and directed I2/D1 XSim also pass. Parent XSim passes stop/drain,
idle and common-reset recovery with 112 TX words; RX comparison is explicitly
skipped. Evidence is under `runs/thermo5_axil_graceful_stop_regression_20261019/`,
`runs/thermo5_axil_graceful_stop_xpm_20261019/`,
`runs/thermo5_graceful_stop_base_final_20261019/`,
`runs/thermo5_graceful_stop_sim2_20261019/`, and
`runs/thermo5_graceful_stop_ooc_synth_20261019/`.

ZU15EG AXI-Lite OOC synthesis produced `synthesized.dcp` and resource/clock
reports: 84,804 LUTs, 88,520 registers, 1,936 DSPs, 6 RAMB36 and 1 RAMB18.
The repository checkpoint validator reopened the DCP and regenerated resource
report successfully (`THERMO5_AXIL_CHECKPOINT_VALIDATED=checkpoint_synthesized`).
The original PowerShell launcher nevertheless returned nonzero with Vivado
`[Common 17-217] Failed to load feature 'vivado'`; record the checkpoint as
independently validated, not as a clean launcher PASS. No routed timing run was
performed. This does not close parent routed STA/CDC/RDC, real I/O budgets, RX
recovery, serializer/board output, or arbitrary-length frame termination. The
behavior assumes software/source honors the fixed 32-beat frame contract.

## GT-parent global-reset integration with AXI-Lite (2026-10-19)

Added the 100-MHz AXI-Lite clock/slave interface to the four-GTH thermo5
parent. One reset-controller release request now fans out to independent
asynchronous-assert/two-local-edge-release synchronizers for AXI-Stream
125 MHz, AXI-Lite 100 MHz, and the 218.75-MHz GT-derived core. Release waits
for `fabric_clocks_stable` and qualified GT TX health; RUN is now written over
AXI-Lite and synchronized into core, with the frozen parent retained at
`DPD_MAX_TAPS=1`.

Parent XSim reset-only run PASS in
`runs/thermo5_gt_parent_axil_reset_20261019_121300/`: reset defaults/ID,
local release sequencing, fabric-clock-stability loss, pending COMMIT
cancellation on GT-health loss, power-good/TX-active recovery, common reset,
and 112 TX words across two epochs. RX comparison was explicitly skipped.
The full RX-comparison attempt remains OPEN/failed: the behavioral GT model
reported `rx_user_clk=0`, `rxdata=0x55...`, and no RX frame before timeout.
This is not evidence of serial/board behavior.

Thermo5 generic VCS regression PASS (7 scenarios) at
`runs/thermo5_verify_20261019_axil_parent_1245/`; AXI-Lite VCS regression PASS
(register access, commit/config, coefficient transport, nonlinear-image
transport, tap-4 identity, boundary phase, negative/fault/parameter checks and
URG merge) at `runs/thermo5_axil_vcs_20261019_parent_1245/`. Directed frozen
I2/D1 XSim PASS at `runs/uvm_thermo5_i2_d1/axis_xsim_parallel_generic_seed1_words56/`.
The UVM split exposed and fixed a missing `(name,parent)` constructor in the
bit-true test base.

ZU15EG parent synthesis emitted `synthesized.dcp`, `synth_utilization.rpt`, and
`synth_clocks.rpt` under the parent run directory, including the AXI-Lite
100-MHz clock. The Vivado launcher exited nonzero with `Failed to load feature
'vivado'`; treat this as generated synthesis artifacts, not a clean synth
PASS. No placed/routed parent run was attempted (only 8.9 GiB free, below the
known 12–14 GiB requirement). Routed CDC/RDC and real SoC I/O budgets remain
OPEN; no physical signoff claim.

## Formal harness topic split (2026-10-19)

Split the formerly combined thermo5 proof sources into reset, DPD counter,
generic CDC/gearbox, DPD identity, identity intermediate lemmas, interpolation
bounds, and XPM FIFO harness files. Tcl runners now select the topic file(s)
for the chosen top, Python manifests hash the split sources, and
coverage-reason references point to the corresponding topic. The first new
identity run found two stale hierarchical references: the DPD product moved
from s6 to s7 in the Oct15 timing optimization, but its old lemma still read
s6. The lemma now checks current s7 product signals; obsolete product-delay
checks were removed because that pipeline stage no longer exists. RTL is
unchanged. Fresh reset/counter/generic-CDC/interpolation/XPM-reset/XPM-residual
jobs PASS. Identity has 5 proven and 13 inconclusive assertions (no remaining
falsified property); full identity payload remains OPEN. XPM FWFT proves the
state-encoding assertion and covers stage1/read, but reset-transition coverage
is inconclusive. See fresh manifests under `runs/`.

## Full-IP UVM scenario file split (2026-10-18)

Split the common test setup into `thermo5_sku_base_test.svh`, kept the nominal
bit-true scenario in `thermo5_sku_bittrue_test.svh`, and moved the ten corner
scenario classes into one source file each under
`dv/uvm/tests/thermo5/full_ip/`. `thermo5_sku_corner_tests.svh` remains the
include hub; public UVM test names and Makefile targets are unchanged. Added a
scenario map README. Structural checks (10 scenario files/10 matching includes,
one class per file, base included before derived classes) and `git diff
--check` PASS. No RTL, vectors, or scenario behavior changed. VCS compile was
attempted in Rocky WSL, but this run could not obtain the Synopsys license
server; it is not a PASS or a DUT failure. Re-run generic/XPM UVM regressions
in a licensed environment before treating this package change as
simulator-validated.

## Subsystem test scenario split (2026-10-18)

The frontend and four-plane backend subsystem benches now have separate
bit-true baseline and flow-control scenarios. The new frontend test injects
source bubbles and partial `pa_ready` windows while retaining MATLAB
four-plane comparison; the backend test independently stalls each plane and
checks quartet alignment/stability plus MATLAB output equality. XSim PASS:
64 frontend words, 16 bubble cycles, 28 observed stalls; 128 backend vectors,
32 bubble cycles, 86 observed stalls. Latest logs are under
`runs/thermo5_frontend_flow_control_xsim_20261018_021853/` and
`runs/thermo5_fs4_multipa_backpressure_xsim_20261018_021939/`.

The original baseline benches also passed: frontend parameterized runner used
the inherited 4-tap/DPD_MAX_TAPS=4 environment; backend checked 128 vectors.
The new frontend flow-control runner is the frozen 2-tap/DPD1 configuration.
No RTL/UVM logic changed, and this does not replace full-IP reset/replay, CDC,
generic/XPM regression, or physical GT signoff.

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
standalone `dv/verif/block/axil/tb/thermo5_axil_cfg_coverage_tb.sv` checks
internal reset/request/pending overlap; the parameter-guard harness is colocated
there as well. The two signal-processing subsystem folders remain the frontend
(AXIS/AFIFO/gearbox + gain/interpolation/DPD) and backend (four-plane TID/Fs4).
The raw GT-user policy is an adjacent block test; behavioral serializer
loopback is a separate integration test.

The AXI-Lite block harness and parameter-guard files were moved from the UVM
top-level `tb/` into `dv/verif/block/axil/tb/`. Both canonical VCS targets now
pass from the new paths: `thermo5-axil-cfg-unit-vcs` and
`thermo5-axil-vcs-parameter-guard`; evidence is under
`runs/thermo5_axil_block_reorg_20261016/`. This was a verification-source
organization change; no RTL or test behavior changed.

The 14:8 ingress gearbox is core-clocked after the FIFO; default FIFO depth is
16 source beats (`FIFO_ADDR_W=4`). At equal nominal rates, this depth absorbs
bounded startup/stall skew; it does not permit accepting a full 32-beat frame
while the consumer is stopped. See `docs/architecture/thermo5-datapath.md` for
the width, capacity and sizing assumptions.

The block/subsystem scenario, intent, expected-result and limitation matrix is
maintained at `docs/verification/thermo5-test-level-matrix.md`.

## Directed runner locality (2026-10-16)

Moved 11 focused XSim runners beside their matching block, subsystem, or
integration testbenches. Existing dv/verif/scripts command paths remain as
thin compatibility shims. PowerShell parsing plus repository-root and literal
RTL/DV/MATLAB source-path resolution passed for 12 canonical runners and 11
shims. Isolated XSim checks passed for the raw64 GT-user block, frontend
subsystem (64 vectors, INTERP_TAPS=2, DPD_MAX_TAPS=1), and four-plane backend
(128 MATLAB vectors). Logs are preserved under
runs/dv_layout_verify_20261016/. The full-chain run was not repeated because
its default output directory already contains prior artifacts; its runner path
and source references passed static resolution checks.

Updated: 2026-10-18 SGT. Status: active; frozen thermo5 OOC routes PASS, subsystem flow-control scenarios added and XSim-checked, parent I/O signoff OPEN.
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
  includes AXI ingress, async FIFO/14:8 gearbox, interpolation, a one-tap
  programmable memory-DPD path, Fs/4/thermo5 front end and four PA-code planes.
  The UVM frozen test ties the DPD identity image; the direct OOC top leaves
  those coefficient inputs programmable.
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
  `dv/verif/subsystem/tx_frontend/run_xsim_thermo5_i2_d1_axis.ps1 -AxilControl` and add
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
