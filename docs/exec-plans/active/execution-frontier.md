# Execution frontier

## Current execution state: fixed-product parameter Branch audit (2026-10-31)

PRs #17–#22 are open, draft, and unmerged. PR #20 is on `codex/thermo5-cdc-frame-start-alignment`, stacked on PR #19 at `cc32661a576d30634375f61552621e49f351c541`. Draft PR #21 ([CDC final-word threshold Formal](https://github.com/cwu766485-ctrl/dsm_ip/pull/21)) is stacked on PR #20. Its latest verified remote HEAD is `5657e6629ebd28762160210ce3d15dc0a648beb3`. Draft PR #22 ([fixed-product parameter Branch audit](https://github.com/cwu766485-ctrl/dsm_ip/pull/22)) is open, mergeable, and stacked on PR #21. Its initial GitHub commit is `9bcbe5c829c4bd8d957949865da1009073fc7da6` with tree `0af067229fa54f6ce2e3ab887e05bcb50afb170f`, matching local submission tree `0af067229fa54f6ce2e3ab887e05bcb50afb170f` (local commit `90be89937ca4110385c3d37d6e592ea45ddb6449`). Do not merge PRs or delete refs.

The new standalone VC Formal V-2023.12-SP2 job instantiates the production CDC and Generic FIFO with explicit `SRC_LANES=14`, `CORE_LANES=8` and sends two legal consecutive 32-beat packets. Three assertions are proven; the frame-end tail-drain property is non-vacuous. Four of six Covers are reached, including the second frame-end pop at depth 119; the exact short-final-word Branch target and misaligned-frame-start target Covers are uncoverable. The final run is `runs/thermo5_tx_cdc_frame_end_threshold_20261031_pr21_retry3/`; an ignored initial assertion from the superseded first attempt was removed, and the runner now rejects ignored assertions. SVA environment assumptions=0, selected setup violations=0, black boxes=0, no tautology warnings or ignored assertions.

Exactly Raw Branch `TXB-7ea7a7506f13f31ca4a9` at `rtl/axis/dsm_axis14_to_core8_cdc.sv:215` remains `PROVEN_UNREACHABLE` in the source-bound ledger. This audit adds 17 exact fixed-product parameter Branch dispositions (frame-gain/centered Hold, centered Lane/Q14 guards, EF2 shape guard, DPD tap guards, and GT bridge width guard). They are static elaboration findings, not Formal proofs or exclusions. No Raw hit, URG/VDB, or denominator changed. The ledger has 21,732 records: 372 proven-unreachable (11 Formal + 344 EF2 static + 17 fixed-parameter) and 21,360 OPEN across 362 of 470 tasks. Raw remains Branch 520/637, Condition 601/849, Line 3334/3796, Toggle 83575/104480; legal Functional Coverage 210/210; waivers/exclusions=0; gate `RAW_100_OPEN`.

Checks for this static audit: fixed-parameter source-chain and exact-ledger/evidence tests PASS; full hardware utility tests 17/17 PASS; disposition updater PASS; static Raw/Adjusted gate recheck `RAW_100_OPEN`. The exact current-source VCS/URG evidence was reused because no product RTL, compile input, or Raw VDB changed; full VCS/UVM was not rerun.

The tracked product compile manifest still binds 75 parsed HDL/UVM files and 77 source/control entries to the existing 13-test product compile. Product configuration remains Centered-Cubic, EF2 ORDER=2/STEP=5120, DPD_MAX_TAPS=1, AXI-Lite, Generic FIFO. RX, AI-DPD, product algorithms, and physical implementation remain outside this TX-only Linux work.

**Next:** close the highest-value legally reachable Branch/Condition using legal stimulus, an independent checker, and a DUT event. The outstanding-counter Formal, DPD identity Formal, and source-gap/service-rate contract remain OPEN. If a round produces no valid Raw hit, stop seed expansion and revisit reachability or bin mapping. Keep the Raw denominator and all OPEN statuses intact.

## Previous execution state: 13-test TX coverage refresh and audited closure queue (2026-10-31)

The frozen product RTL is at SHA `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`: Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120, 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1, identity reset image, AXI-Lite product frontend, and Generic FIFO for Linux. No product algorithm, RX, or AI-DPD RTL changed. Verification files and documentation are worktree changes; their exact compile inputs are hash-bound in the current VCS source manifest.

A fresh VCS V-2023.12-SP1 compile and 13 focused positive UVM tests passed, including the new legal AXI-Lite one-tap DPD saturation test (seed 620131). The test writes a legal non-identity coefficient image, checks all four output planes against generated Python bit-true vectors, observes 56 words/one TLAST, and exercises I/Q positive and negative saturation on all 16 DPD lanes (873 saturated samples in the model). Existing 12 tests were replayed on the same fresh compile. Their merge-to-13 delta is +80 Branch, +16 Condition, +144 Line, +654 Toggle. Full UVM regression was not repeated.

The current AXI-Lite frontend Raw URG has 210/214 scoreable functional records covered; all 210 legal positive records are hit. Four zero-hit Raw records are two illegal-only bins duplicated in type/monitor views; the separate negative regression hits them (49 bad-frame and 1 malformed-early hit). Twelve pre-existing URG-model Illegal/Excluded records remain visible. No functional bin or denominator was removed.

Raw DUT code coverage and adjusted coverage are identical, with zero approved waivers and zero active `.el` exclusions. The fail-closed gate is `RAW_100_OPEN`:

| Metric | Raw covered / total | Unhit |
|---|---:|---:|
| Branch | 520/637 (81.6327%) | 117 |
| Condition | 601/849 (70.7892%) | 248 |
| Line | 3,334/3,796 (87.8293%) | 462 |
| Toggle | 83,575/104,480 (79.9914%) | 20,905 |
| FSM states / transitions | 13/13; 22/22 | 0 |
| DUT assertions | 13 success / 15 attempted | 2 uncovered; 2 without attempts |

The current-source ledger retains all 21,732 unhit Raw records in 470 grouped tasks: 48 Branch, 107 Condition, 114 Line, 201 Toggle. Five exact records are `PROVEN_UNREACHABLE` under their reviewed source-bound Formal evidence; all remain in Raw. They are the aligned 32-beat CDC end false arm, CDC outer-case default, AXI-Lite write-case default Branch, coefficient-read default Branch, and the matching default Line. The other 21,727 records and 465 tasks remain OPEN. Root-cause labels are triage only. Current review artifacts and checksums are linked from `docs/verification/data/thermo5-tx-coverage-closure-index.json`.

Formal status is deliberately limited. The full identity-DPD payload equivalence property remains INCONCLUSIVE at depth 252. A new identity-only DPD saturation harness proves four no-clamp assertions and finds the four clamp Covers uncoverable under the reset-loaded unity coefficient, but AXI-Lite permits runtime coefficient writes; therefore this result does not disposition product Raw bins. The legal AXI-Lite stress test now hits those clamp paths. The PAIR_LOOKAHEAD exact-parameter run reported two proven assertions and two uncoverable Covers, but VC Formal explicitly marked both goals tautological; all four corresponding Raw branch bins remain OPEN. The source-bound Formal review closes five exact records; the AXI-Lite tuple condition assertion lacks a non-vacuous witness and stays OPEN.

Mutation verification passed at VCS V-2023.12-SP1: baseline bit-true test PASS; `late_gain` and EF2 `plane_swap` mutants were both detected by the independent `[BITTRUE]` scoreboard. This demonstrates those checker paths only, not all fault classes. A 16-cycle AXI source gap still fails the independent checker with 54 underflows (112 output words, no protocol errors); the interface has no maximum-gap contract, so this remains OPEN.

Scope remains focused frontend coverage, not full-system TX signoff. The separate one-test behavioral GT Parent report has no payload checker. Real XPM and GT Wizard simulation, full parent TX payload checking, EF2 identity Formal convergence, remaining reachable Branch/Condition/Line/Toggle closure, FPGA PPA, and physical QAM256 BER remain OPEN. Do not claim final signoff or 100% Raw/adjusted code coverage.

**Next:** use the source-position task table to target the highest-value legal Branch/Condition gap with an independent checker and DUT event. If a round produces no new valid Raw hits, stop seed sweeping and investigate reachability or monitor/bin mapping. Keep all candidate branches OPEN until exact evidence closes them.

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
remain **PASS**…20636 tokens truncated…oreboard and code coverage | Generic and XPM bit24 long-stream simulation + separate URG + 16-lane audit PASS; raw coverage remains OPEN | Both FIFO builds passed 16,777,222 four-plane bit-true words, all16 counter resets, signed endpoints, and zero UVM errors/fatals. Same-binary URG confirms bit24 toggles both ways in all16 DPD lanes for each FIFO. Raw scores: generic87.01% (line87.09, condition76.46, toggle85.50, FSM100, branch73, assertion100); XPM80.18% (line76.99, condition67.89, toggle82.91, FSM90.91, branch62.37, assertion100). Bits25-31 remain reachable/open (224 directional misses per FIFO); raw coverage is not closed. XPM VDB used 2.5 GB oracle files staged on WSL ext4. Partial seeds610705-610708 remain excluded. |
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
