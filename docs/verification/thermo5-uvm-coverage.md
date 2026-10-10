# Thermo5 UVM verification and coverage boundary

## Latest bit21 reachability closure (2026-10-08)

The current-source generic and real-XPM long-counter tests passed with
2,097,158 output words checked bit-true on all four PA planes and all16 DPD
counters reset afterward. Raw same-binary URG is generic87.52% / XPM80.31%.
The reviewed exact-exclusion reports are generic99.66% / XPM96.71%; these are
partial adjusted denominators, not100% closure. Both FIFOs hit both toggle
directions through `sample_count[21:0]`; bits31:22 remain320 reachable
directions/FIFO OPEN. Generic interpolation clamp bins remain open because the
bound proof is valid-payload-qualified. XPM vendor line/condition/branch/toggle
gaps, 19 unmapped vendor branch candidates, and the FWFT
`stage1_valid->invalid` transition remain open. Exact run, hashes, raw and
adjusted reports: [reachability closure](thermo5-reachability-closure-20261008.md).

## Historical same-build follow-up (2026-10-07)

The completed independent 131075-word, four-plane VCS run at
`runs/thermo5_followup_long_20261007/evidence_index.json` supersedes the
dated percentage checkpoints below. Generic/XPM each checked 74900 accepted
AXI beats, all 131075 PA words on four planes, and all 16 DPD counters before
public reset with zero UVM errors/fatals. The same-build raw URG scores are
87.49% / 80.27%; the individually scoped adjusted scores are 99.64% / 97.08%.
These are distinct denominators, not full signoff. Generic adjusted remains
4 line, 0 condition, 448 toggle directions, 4 branch; XPM adjusted remains
15 line, 32 condition, 461 toggle directions, 50 branch, 1 FWFT transition.
The 448 counter directions per FIFO are reachable high bits 31:18; formal
count correctness is not a raw URG hit. See
`thermo5-xpm-exact-followup-20261007.md` for the cost-ranked XPM rows and
their OPEN/scoped-proof boundaries. Current-source licensed CI is not yet
repeated: the historical CI PASS below applies only to its recorded commit.
On 2026-10-08 the latest-source frozen regression and 131075-word generic/XPM
closure passed at RTL/DV digest
`0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`. Raw final
scores are 87.49% generic and 80.29% XPM after same-binary core-first release;
the FWFT-target reset test on that same binary did not hit
`stage1_valid->invalid`. Previous adjusted scores were not recomputed against
this modified UVM source. Exact current-source results are at
`runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`; follow-up
reasoning is in `thermo5-xpm-exact-followup-20261007.md`.

## Fresh licensed package rerun (2026-10-08)

`runs/thermo5_current_source_dv_resume_20261008/dv_package.json` freshly passed
coverage, scoped formal and historical bug-control jobs on the same 202-file
RTL/DV digest. Its own same-binary raw URG closure is generic87.49% and
XPM80.27%; all131075 output words on four planes matched the independent
MATLAB oracle. This package result is separate from the earlier same-source
core-first/FWFT report above (XPM80.29%); no VDBs were merged across binaries.
The raw score is not adjusted. The Oct7 candidate ledger's raw denominators
match, but4,358 project disposition rows refer to a changed testbench hash and
the vendor rows are unhashed, so adjusted URG is NOT_RECOMPUTED and no
exclusions were applied. Hosted CI for the current dirty source remains OPEN.

The fresh closure hit generic interpolation line71 tuple `1/0` and CDC lines
190/220 tuple `0/1/1`; the XPM closure hit vendor line754 tuple `1/0`. Both
variants hit both directions on all162 TID bits and both directions through
DPD counter bit17 in all16 lanes. Bits31:18 remain OPEN. A single optional
bit18 experiment requested a 262150-word legal stream; its independent
MATLAB vector generation was stopped after about32minutes near the agreed
30-minute resource cap before writing any files (launcher exit
`MATLAB vector generation failed: -1`). See
`runs/thermo5_bit18_20261008/attempt.json`. No directed VCS run was made and
no bit18 hit is claimed.

## Current graduate-DV closure (2026-10-06)

License-restoration retest: actual GitHub Actions37462007850 at commit
`a9b0bc6f67f575e9bb98085b1e064f9eddc886f2` passes hosted and licensed
jobs. Latest matching-build baseline/after: **generic87.01% ->87.48%**,
**XPM79.96% ->80.26%**, no exclusions. Both illegal-frame tests now also
check public-reset sticky-error clearance. Four scoped formal jobs pass,
including expanded generic CDC7 assertions/9 covers; SpyGlass retains
39 warnings+4 synthesis warnings, zero errors. Fresh reports/ledger:
`runs/thermo5_real_ci_37462007850/`. Earlier numerical checkpoints below
are historical evidence and do not supersede this retest.

Latest follow-up: `runs/thermo5_coverage100_closure_final_20261006/` passes
fresh same-build baseline and ten additional directed tests. Raw DUT score
is **generic 87.00% -> 87.47%**, **XPM 79.96% -> 80.25%**. All sixteen
DPD counters now have both directions for bits5:14 after a 16,387-word
independent-oracle stream and public reset; bits31:15 remain reachable and
unhit. Legal signed gains close both frame-gain saturation arms. A core
enabled before its first frame closes the generic line190 `0/1/1` bin and
checks no premature underflow. All 162 TID bits remain both-direction hits.

The complete denominator audit now includes single-instance shared sections,
modules without condition sections, expanded XPM macros and split source
pages. No exclusions are applied. See
`thermo5-coverage100-assessment.md` for exact metric denominators, reasons
raw full-DUT 100% is impossible in the frozen configuration, and remaining
OPEN bins. The unbounded 32-bit production counter has 35 proven assertions
and four covers; its formal proofs do not count as URG hits. The optional
arithmetic experiment remains inconclusive. Completed generic residual proof
uses a constructed legal AXIS source and exact 7:4 clocks: four proven
assertions, nine covers, zero black boxes, non-vacuous source stability.
No URG exclusions are applied. The older
selected-gap table below records the preceding milestone.

The same-build package at `runs/thermo5_dv_package_delivery_20261006/`
supersedes the historical OPEN classifications below for the selected digital
gaps. See `thermo5-dv-portfolio.md` for the two review tables and commands.

| Selected gap | Before -> after / scoped disposition |
| --- | --- |
| Generic `u_interp_1:71` operand `1/0` | `Not Covered -> Covered`; public PA ready is driven from observed empty-stage/occupied-downstream state; 32 source beats and 56 four-plane golden words pass. |
| XPM `u_interp_1:71` operand `1/0` | Baseline already `Covered`; directed state-triggered test still hits 139 cycles and passes the oracle. |
| TID bit15, 162 individual rows per implementation | **162/162 both directions hit**, verified by expanding complete URG ranges and matching each instance/kind/bit. |
| DPD count bits5:10, all 16 lanes | Both directions hit; count11 has 0->1 only. |
| DPD count31:12 / count11 falling | Raw URG remains red. Production-RTL formal proves high-zero/count-equality under <=2072 accepted samples per reset epoch, with four accept/stall/recovery covers. Unbounded counter closure remains OPEN. |
| Reset `1/0` bins | Raw URG remains red; falling-edge runtime-reset formal proves three non-vacuous assertions, four normal covers, and collision cover uncoverable. Scope excludes same-active-edge scheduling collisions and does not prove metastability. |

Raw DUT coverage is **generic 87.00% -> 87.19%**, **XPM 79.96% -> 80.06%**.
Each delta uses one binary and its matching design VDB; generic and XPM have
different hierarchies and cannot be compared directly. No formal disposition
is converted into a coverage exclusion. GT CDC-11, real I/O timing, RX and
physical board output remain OPEN.

## Historical work below

Earlier scores and OPEN notes are retained as dated evidence, not the current
selected-gap status. The current table above and portfolio are authoritative.

## Exact frozen-SKU gap review (2026-10-06)

### Same-build long-stream follow-up

The fresh baseline at `runs/thermo5_gap_baseline_20261006_v1/manifest.json`
passes the seven frozen cases and six independent payload runs for generic
and XPM separately. A legal 2072-word `range_stress` run is merged into each
matching build's `coverage_long` URG report. Both implementations pass 1184
accepted AXI beats, 2072 independent four-plane golden words, all 16 DPD
sample/saturation count checks, and zero UVM errors/fatals. The matching URG
delta gives `sample_count[11]` a `zero_to_one=Yes` direction; grouped
`sample_count[31:12]` remains without a direction. Generic and XPM hierarchy
scores remain separate and non-comparable. The interpolation and reset bins
remain OPEN.

The current hardened generic/XPM URG merges are unchanged by the following
directed work. `HIT` requires a new same-build VDB and the exact instance/bin
row; an XSim functional pass is recorded separately.

| Gap | Current disposition | Evidence / next check |
| --- | --- | --- |
| Generic `u_interp_1` line 71, operand `1/0` | **OPEN** | Current XSim phase probes and the legal UVM schedule complete or fail the explicit hit gate without reaching the row. Trace shows the downstream elastic slots fill only after the source bubble has already drained; no exact URG hit is claimed. Retarget with a handshake-derived schedule or formally classify the state. |
| Generic `u_cdc.u_s_reset` and `u_cdc.u_c_reset` line 27, operand `1/0` | **OPEN** | Independent two-clock XSim passed asynchronous assertion and two-edge release. The missing state appears only at a reset/clock scheduling collision, not in stable reset operation; no accepted formal/URG exclusion has been applied. |
| DPD line-198 missing branch, all 16 lanes | **PROVED_UNREACHABLE in fixed DPD1 identity**, with red URG rows retained | URG HTML identifies valid saturation as the missing arm. Exhaustive signed 16-bit identity XSim plus fixed-coefficient algebra rules out saturation for valid samples. This is not a claim for programmable DPD. |
| DPD `sample_count` toggle rows | **PARTIAL / OPEN in URG** | Matching generic/XPM VCS+URG 2072-word runs pass the four-plane oracle and all counters; `sample_count[11]` gains `zero_to_one=Yes`. Grouped `sample_count[31:12]` remains directionless and high-bit closure is OPEN. |
| 162 TID input bit-15 toggle rows | **OPEN** | Signed-endpoint 56-word XSim passed; its old VCS VDB predates the current hardened compile/scoreboard and cannot be merged. Run the same vectors on the matching generic/XPM builds separately. |

Path-level GT CDC-11 and parent I/O/RX are separate integration signoff gaps,
documented in `thermo5-gt-tx-active-cdc11-audit-20261006.md` and
`docs/exec-plans/active/thermo5-gap-closure.md`. No bulk waiver was used.

## Latest licensed execution (2026-10-05)

The user's Rocky VCS run passed the generic seven-case regression and URG
merge. The generic merge at `runs/uvm_thermo5_i2_d1/coverage/`
reports overall 87.22%, line 86.85%, condition 80.21%, toggle 83.90%, FSM
100%, and branch 72.33%. Its URG command lists `simv.vdb` and seven named
test VDBs; the dashboard labels eight tests, not an extra extreme-input run.
An initial real-XPM attempt compiled the Vivado sources but exposed a
VCS `ICPD_INIT` error: declaration initializers on four reset synchronizer
registers conflicted with three `always_ff` writers. Changing only those
three keywords to ordinary clocked `always` preserved the initializers,
event controls, assignments, and reset behavior. The fresh real-XPM seven-
case regression and URG merge then passed with zero UVM errors/fatals in all
cases (the illegal-frame assertion is expected). Its report at
`runs/uvm_thermo5_i2_d1_xpm_rerun2_20261005/coverage/` gives overall
81.38%, line 76.84%, condition 70.19%, toggle 81.30%, FSM 90.91%, and
branch 62.16%. Its command also lists `simv.vdb` plus the same seven named
case VDBs, though its dashboard labels seven tests. Vendor hierarchy and
URG accounting make generic and XPM percentages non-equivalent. This does
not close remaining instance
bins or GT/board verification.

## Follow-up stimulus under test (2026-10-04)

The earlier baseline URG audit is retained below. The testbench now has an
observation for the exact still-open `u_interp_1` condition
`!s1_valid && !s2_ready`, and reset replay requests `core_enable=1` while both
resets assert, to attempt the reset-with-enable condition bins. The latest
licensed generic and XPM regressions above execute this stimulus. Whether
each target condition/reset bin was actually hit still requires a fresh
instance-level URG audit; preserve all other per-instance classifications
and do not treat intended stimulus as a coverage hit.

## Directed boundary follow-up (2026-10-03 15:39 +08:00)

The two previously unhit full-chain empty/backpressured combinations are
**reachable**. A legal phase sweep varied the AXI valid-gap beat and PA
stall duration without forcing DUT state. With seed 2, an 80-source-cycle
gap before beat 4 and no initial all-stalled PA interval, the existing
compiled generic FIFO image observed 13 `interp1 !out_valid && !out_ready`
and 39 `interp2 !s1_valid && !s2_ready` cycles; XPM observed 42 and 14.
Both runs passed the 32-beat/56-word four-plane MATLAB bit comparison with
zero UVM errors/fatals. The UVM source now defaults to this phase and makes
both observations mandatory. Licensed VCS recompiled it and both generic/XPM
seven-case regressions passed. The new URG instance view covers the exact
`u_interp_1` line-69 `!out_valid && !out_ready` and `u_interp_2` line-71
`!s1_valid && !s2_ready` bins. An additional `u_interp_1` line-71
stage-1-empty/downstream-blocked bin is still unhit and remains **open**; the
named two-bin closure must not be generalized to all interpolation conditions.

Under fixed DPD1/identity coefficients, the arithmetic cone simplifies to
`gain_re=2^14`, `gain_im=0`, and each valid I/Q term is exactly
`(sample * 2^14) >>> 14 = sample`. The signed 16-bit domain includes
`-32768`. `tools/hw/check_dpd_identity_domain.py` exhausts all 65,536
values. More importantly, XSim executed the actual 11-stage RTL for
196,608 accepted complex inputs (I sweep, Q sweep, diagonal sweep), checked
all 196,608 outputs, and observed zero valid or invalid-slot saturation and
zero `saturation_count` increments. This block stream toggles
`sample_count` through bit 17; higher counter bits and full-chain code
coverage remain open. It is a fixed-SKU proof, not evidence about
programmable DPD coefficients. The proof derivation uses the RTL's
`tap_enable`/`valid_pipe` lockstep; invalid slots contribute zero term.

The two-tap interpolator phase-1 is a convex average with coefficients
`8192+8192=16384` in Q2.14. Its rounded result cannot leave the signed
16-bit interval, so the two saturation branches are excluded for this SKU,
not for 3/4-tap variants. The existing block XSim test was rerun and
observed reset-with-enable for three cycles, four empty/blocked cycles,
five output stalls, and 12 correct words. A separate interval checker
records the coefficient/end-point proof. Full-chain reset-with-enable and
two CDC reset-release condition bins remain open.

An independent MATLAB `extreme` profile rotates `-32768`, `32767`, near-zero
and large signed inputs across all 56 words. The frozen 2-tap/DPD1 generic
and XPM VCS regressions each passed 32/56 four-plane bit-true using the
recompiled design, and their seed-404 VDBs were merged with the seven-case
baseline. Generic overall/condition/toggle coverage is now
87.20%/79.79%/84.20%; XPM is 80.16%/69.68%/81.56%, including vendor
hierarchy and not directly comparable. The generic per-instance inventory
has 216 condition bins across 30 DUT instances, 69 unhit; uncovered toggle
signal rows fell from 424 to 280. XPM has 228 bins across 36 instances,
74 unhit, and 286 uncovered toggle rows. None of those red bins is waived.
The original random generator remains numerically unchanged;
MATLAB P0 7/7 was rerun with zero mismatches. Regenerating the default
seed-20260930 profile produced eight `.mem` files whose SHA-256 hashes all
match the pre-change frozen vector directory.

The fresh generic and XPM per-instance CSVs are under
`runs/uvm_thermo5_i2_d1/integration_audit_final_20261003/` and
`runs/uvm_thermo5_i2_d1_xpm/integration_audit_final_20261003/`. They
distinguish measured hits, fixed-identity saturation proofs, and unresolved
stage-1/reset/release bins; classification is not a tool waiver.
The prior branch summary's line 100 is the illegal-tap parameter guard,
not a reset branch; line 91 is the two-tap saturation arm.

Separate XSim checks also passed PRBS/known-word BERT and the **frozen**
2-tap/DPD1 four-plane ideal serializer loopback (64 words, 4096 serial
bits per plane). These are behavioral link checks, not actual GTH Wizard,
board, CDR, eye, or 14-Gb/s pin measurements. The parent-level synchronous
`run_request`, coordinated dual-reset release, real I/O budgets, CDC/RDC,
and four-channel GT mapping are still integration-signoff items.

A 1,008-core-word extreme-vector full-chain XSim test passed with both FIFO
implementations: 576 accepted AXI beats, 1,008 MATLAB-matched words on each
of four planes, 266 generic/326 XPM PA stalls. It checks all 16 DPD lane
sample counters against 1,008 and all saturation counters against zero.
This extends functional stress; the long XSim test has no VCS VDB and does
not close high-bit full-chain URG toggle coverage. Reset-with-enable is
separately checked at interpolator block scope, not yet at system scope.

## Seven-case full-chain update before phase retargeting (2026-10-03)

The frozen 2-tap/DPD1 SKU has a seventh directed test,
`thermo5_sku_bubble_backpressure_test`. The AXI source inserts an 80-source-
cycle valid gap before beat 4. The PA sink is held not-ready for 200 core
cycles, then uses 90% randomized stalls. Observation-only probes (no DUT
forcing) count bubbles and backpressure at both x2 stages and the DPD
boundary. In the final generic run, counts were `i1=42, i2=31, dpd=1`,
`i1_stage1_hold=289, i1_stage0_hold=281, i2_stage1_hold=619`, and output
holds `344/650`. The targeted test requires the reachable valid-hold and
empty-blocked combinations, 32 accepted AXI beats, 56 MATLAB-matched words
on **each of four planes**, and no frame-protocol error. It passed with both portable generic and actual
Vivado XPM FIFO; all seven tests in each configuration have zero UVM
errors/fatals (the illegal-frame assertion is the expected negative case).
The probes for `interp1 !out_valid && !out_ready` and
`interp2 !s1_valid && !s2_ready` counted zero in this window. Their exact URG
bins therefore remain open; we have not called them unreachable. The source
gap can assert sticky underflow before all input arrives; the test still
checks all expected output data and frame protocol.

Fresh MATLAB-generated payloads with independent seeds 101, 202, and 303
have different AXI-I SHA-256 values. Each payload independently passed the
32/56 four-plane UVM comparison in both FIFO configurations (six additional
simulations). MATLAB reference and RTL numerical behavior were not changed.
The reproducible driver is `dv/uvm/sim/run_thermo5_payload_matrix.sh`;
vectors and hashes are under `runs/uvm_thermo5_payload_20261003/`.

The final seven-case generic URG merge reports overall **86.97%** (line
86.85%, condition 78.72%, toggle 83.90%, FSM 100%, branch 72.33%; functional
groups 100%). Its 216 exact condition bins across 30 DUT instances are 146
hit and 70 unhit. The separate XPM merge reports overall **80.14%** and
condition 69.83%; it includes vendor
XPM/glbl hierarchy and is not directly comparable. The XPM and generic
merges both completed after an initial concurrent URG attempt exhausted WSL
memory; sequential reruns succeeded.

The generated per-instance evidence files are
`runs/uvm_thermo5_i2_d1/integration_audit_20261003/urg_condition_bins.csv`,
`urg_uncovered_toggle_signals.csv`, and `urg_branch_instance_summary.csv`.
Each row has a hit, fixed-SKU parameter rationale, or explicit `OPEN_*`
disposition. Remaining generic condition bins are: 16 invalid-slot DPD
saturation combinations; 48 valid-saturation combinations not reached with
the frozen input/coefficient set; one interp1 empty-output/backpressured bin;
one interp2 empty-stage1/stage2-blocked bin; two reset-with-enable
interpolator bins (the block test covers that mode, full-chain scope open);
and two reset-release synchronizer bins. All are listed per instance and
operand combination in the condition CSV. Of 424 signal-level toggle-gap
rows, 112 are fixed DPD coefficient/tap inputs, 64 are eliminated by
`DPD_MAX_TAPS=1`, 32 longer-stream counter bits remain open, 48 DPD saturation
signals remain open, and 168 TID input bits remain open for wider dynamic-
range payloads. Of 30 instance/line branch-gap rows, 10 have scoped SKU
parameter proof and 20 remain open (16 DPD saturation-count arms, two
interpolator reset/enable arms, two interpolation saturation arms). The
branch CSV is a per-instance line summary, not branch-arm closure; toggle
rows are signal-level, not individual-bit closure. No bulk waiver or
coverage signoff is claimed; open rows stay in the audit.

The parent `run_request` clock, two resets, integrated CDC/RDC, and physical
GT boundary are **not** included in this UVM closure and remain later
system-signoff work.

Frozen configuration: thermo5, two-tap interpolation, one-tap identity
memory-DPD, 125-MHz 14-complex AXI ingress, 218.75-MHz core, four 64-bit
output planes. VCS UVM has separate portable-generic and real-XPM FIFO builds.

## Ownership

- `thermo5_source_sequence` reads the MATLAB vectors and issues AXI beat items.
- `thermo5_source_agent` drives valid/data and independently monitors accepted
  handshakes and source stability. Its monitor alone updates accepted-beat
  count and publishes input transactions.
- `thermo5_control_bfm` owns reset, core enable, and common-plane ready.
- `thermo5_pa_monitor` publishes accepted four-plane words and checks stalls.
- `thermo5_pa_scoreboard` compares both monitor streams to the fixed MATLAB
  input/PA vectors. A core-reset assertion starts a new comparison epoch;
  tests never rewrite scoreboard indices.

## Test-to-check closure

| Test | Required checker/event | Functional coverage |
| --- | --- | --- |
| Bit-true plus PA stalls | 32 input beats, 56 four-plane words, exact MATLAB comparison, held output under stall, no early underflow | Three frame starts, PA word and PA stall bins |
| FIFO boundary | Source stable while full/backpressured; full 32/56 replay | Full and source-stall bins |
| FIFO empty | Four beats produce seven matched words, then sticky underflow without frame error | Underflow bin |
| Midstream reset | Partial 24-beat epoch discarded; fresh 32/56 bit-true replay | Reset reassertion and scoreboard epoch |
| Residual reset sweep | Reset at CDC residuals 2/4/6/10/12; fresh 32/56 replay | Five reset epochs; CDC FSM transitions |
| Illegal frame | Misaligned frame-start RTL assertion plus sticky protocol error; no PA golden expected | Protocol-error bin |

Each positive test requires zero UVM errors/fatals and its completion marker.
The illegal-frame test requires the precise RTL assertion and UVM observation
marker; it is intentionally not a clean positive simulation.

## Historical six-case measured result and open bins

Licensed VCS six-case regression and URG merge pass. Functional covergroups:
100%; total code-coverage score: 86.59%; line 86.85%, condition 72.54%,
toggle 83.90%, branch 72.33%, FSM 100%, assertion 90.48%. The CDC
`rem_count_q` FSM has 7/7 states and 12/12 transitions after correcting the
reset edge in the control BFM. These percentages are tool scores, not a claim
that every RTL behavior is verified.

The lowest reviewed module-level condition/toggle figures include
`dpd_memory_poly` (44.44% condition, 56.31% toggle), consistent with the
identity-only DPD configuration; this is a triage lead, not an automatic
waiver. Other unhit condition/branch/toggle bins need line-level URG review
and either legal stimulus, proof of configuration exclusion, or a justified
waiver. No blanket exclusion is applied here. The VCS UVM filelist does not
elaborate XPM FIFO or physical GT/PA. Separate full-chain XSim runs with
vendor XPM FIFO and PA stalls passed seeds 7/8/9; they are not merged into
the VCS UVM coverage score.

Initial line-level URG triage (no exclusion applied):

| RTL location | Unhit event | Classification and next check |
| --- | --- | --- |
| `tid32_thermo5_axis_frontend_tx.sv:54,58` | Ingress valid/ready while low-power ingress is disabled | This SKU elaborates with low-power control disabled; confirm static parameter pruning before a configuration-specific waiver. |
| `dsm_interp_x2_polyphase_vector.sv:70` | Stage-2 invalid while stage-3 not ready | Reachable bubble/backpressure combination; add a targeted ready/bubble test before waiver. |
| `dsm_interp_x2_polyphase_vector.sv:225` | Reset low with `enable` high | Current control BFM disables core during reset. Check whether the RTL permits this combination before classifying it as illegal. |
| `dpd_memory_poly.v:140` | `out_ready=0` while the last pipeline valid is zero | Idle/backpressure combination; add targeted control stimulus if legal. |
| `dpd_memory_poly.v:336` | Saturation flags under valid output | Current identity coefficients and OFDM vectors do not hit saturation; use a separate legal stress vector and oracle rather than changing the frozen bit-true gate. |
| `dpd_memory_poly.v` input toggles | `active_taps` and coefficients do not toggle | Fixed DPD1 identity settings by SKU contract; require a separate programmable-DPD target, not artificial toggles in this test. |

The remaining URG holes must be triaged at the instance/bin level before
calling code coverage closed. Functional event closure alone does not justify
waiving all condition or branch misses.

## Targeted reachable-bin follow-up (2026-10-01)

Two separate block-level VCS/URG tests now exercise legal states without
changing the frozen 32-beat/56-word thermo5 oracle:

| Frozen-SKU URG lead | Directed evidence | Disposition |
| --- | --- | --- |
| Interpolator line 70: `!s2_valid && !s3_ready` | `tb_interp_x2_vector_reachable` reaches it four cycles; all three feasible URG condition rows for line 70 are green. Twelve 2-tap output words match an independent half-sample oracle, including five stalled cycles. | Reachable at the block boundary; tested separately. The active thermo5 frame still forbids ingress bubbles, so do not merge this block VDB into its UVM score. |
| Interpolator line 225: `!rst_n && enable` | The same test holds `enable=1` during three reset clocks; reset takes priority and the subsequent output sequence matches. | Legal at the interpolator block; the full-chain control BFM deliberately lowers core enable on reset. No full-chain claim. |
| DPD line 140: `out_ready=0 && !out_valid` | `tb_dpd_memory_reachable` reaches 15 empty-pipeline blocked cycles; URG marks all three feasible line-140 condition rows green. | Reachable and tested in an isolated one-tap DPD. |
| DPD line 336: valid saturated I/Q | Programmable Q2.14 `c1_re=32767` produces five saturated words; positive/negative I and Q limits, six output words, order, sample count, and stall behavior are checked. URG marks valid/non-saturated and valid/saturated rows green, and both I-only and Q-only saturation rows green. | Tested only with a non-identity coefficient. The frozen identity-DPD SKU still has no saturation event. |

Reproduce with `LM_LICENSE_FILE` and `VCS_HOME` supplied externally:
`bash dv/verif/block/run_reachable_coverage_vcs.sh`. The test requires both
PASS markers, rejects simulator fatal/error text, and writes separate reports
under `runs/uvm_thermo5_i2_d1/reachable_{interp,dpd}/coverage/`. Neither VDB
is combined with the six-case thermo5 UVM database; its 86.59% score is
unchanged. No RTL or MATLAB numerical behavior changed.

Configuration-limited holes are assessed individually, not bulk-waived:

| Item | Elaboration/contract evidence | Scope decision |
| --- | --- | --- |
| Top ingress lines 54/58, low-power-off branch | `thermo5_sku_uvm_tb.sv` does not override `ENABLE_LOW_POWER_CTRL`; the top parameter defaults to zero, so `!ENABLE_LOW_POWER_CTRL` is constant true and the disabled-ingress choice is not elaborated in this SKU. | Excluded by this precise SKU parameter, not by DUT-wide waiver. A separate low-power-on target must verify ingress gating and prefill/drain. |
| DPD `active_taps` and coefficient input toggles | The UVM top ties `active_taps=1`, `c1_re=16384`, and every other coefficient to zero. The compiled DPD remains present (`BYPASS_DPD=0`), but these configuration pins cannot toggle in this instance. | Excluded only from fixed-SKU toggle expectations. A programmable-control target is needed before claiming runtime coefficient/tap coverage. |
| DPD valid-output saturation in thermo5 | Unity Q2.14 one-tap gain and the frozen vectors are bit-true identity; output saturation would require a different legal coefficient or altered samples. The isolated stress test changes only that block's coefficient. | Do not claim saturation covered by the UVM frozen SKU or an RF/DPD improvement. |
| DPD line 336 `!valid_pipe[last] && (sat_i || sat_q)` | Still red in the isolated URG result. The payload arithmetic may toggle while its valid bit is low; this is not an accepted output transaction. | Remains open for line-level reachability analysis; no waiver applied. |

The directed tests close the named reachable protocol/saturation leads at
block scope, not all remaining condition, branch, toggle, XPM, or GT coverage.

Additional VCS PA-stall and FIFO-boundary tests passed seeds 11 through 20
(20 simulations). The fixed MATLAB vectors remain unchanged across those
seeds; the random ready schedule varies. Therefore this is handshake stress,
not independent OFDM payload-seed coverage.

## URG source-line inventory (2026-10-03)

The archived six-case URG report under
`runs/uvm_thermo5_i2_d1/coverage/` was re-read at module-definition scope.
These are **uncovered source lines**, not a list of all condition/toggle bins;
per-instance bin disposition and a new VCS merge are still required.

| URG module / source lines | Source-level cause | Disposition |
| --- | --- | --- |
| `dpd_memory_poly` 190-191, 209-210, 237-239, 241-242, 331-332 | Pair-1 accumulation, history, and delayed-tap code cannot execute with `MAX_TAPS=1`; the UVM top fixes that parameter to one. | Configuration-excluded **for this SKU only**; verify each corresponding URG branch/condition row before applying a precise exclusion. Keep 2/4-tap DPD as separate targets. |
| `dpd_memory_poly` 337 | Saturation counter under valid output requires a non-identity drive/coefficient. | Open in frozen identity SKU; programmable-DPD block stress has valid I/Q saturation evidence, not a full-chain identity hit. |
| `dsm_interp_x2_polyphase_vector` 77, 178-191 | Parameter error and 3/4-tap coefficient arms are outside legal `INTERP_TAPS=2`. | Configuration-excluded for the frozen 2-tap instance only; no waiver applied. |
| `dsm_interp_x2_polyphase_vector` 214-215 | History fallback requires `HISTORY>LANES_IN`; current 2-tap instantiations have `HISTORY=1`. | Parameter-excluded for these instances only; check URG instance view. |
| `dsm_interp_x2_polyphase_vector` 91-92 | Positive/negative output saturation was not reached by the fixed OFDM vectors. | Open: add extreme-input block oracle if saturation is in the supported numeric contract. |
| `dsm_axis14_to_core8_cdc` 197-198 | Default residual-state error branch did not occur in legal traffic. | Open: prove the seven-state residual invariant or inject an explicit fault in a separate test; do not waive from simulation absence. |
| `dpd_vector16_memory_poly` 56-57, 75-76 | Delayed-tap/history arms are not selected with one tap. | Parameter-excluded for this SKU only; inspect corresponding instance bins before exclusion. |
| `thermo5_sku_uvm_tb` 30 | Testbench default test-name path is not taken when UVM supplies `+UVM_TESTNAME`. | Testbench-only; do not include TB lines in DUT closure denominator. |

The next coverage artifact should enumerate every remaining red URG
condition/branch/toggle bin by instance, source expression, reachability,
test/check evidence, and a narrowly scoped exclusion rationale. The published
86.59% score is unchanged; this inventory alone is **not** coverage closure.

## XPM and static-analysis boundary (2026-10-03)

`thermo5_sku_uvm_tb.sv` now selects the real XPM branch with
`THERMO5_XPM_FIFO`. The Linux Makefile accepts
`THERMO5_FIFO_IMPL=xpm THERMO5_XPM_ROOT=<Vivado root>` and requires all four
vendor simulation sources; it uses a distinct `runs/uvm_thermo5_i2_d1_xpm/`
database. The generic six-case database cannot be reused or relabeled.
Licensed VCS V-2023.12-SP1 compiled the real vendor XPM source and passed
all six UVM cases on 2026-10-03: 32/56 four-plane bit-true, FIFO full/empty,
reset/replay, five residual resets, and the expected illegal-frame assertion.
All six have zero UVM errors/fatals; the negative case is assertion-expected.
URG independently merged the XPM cases: functional groups 100%, overall
80.60% (line 76.79%, condition 64.94%, toggle 81.29%, FSM 90.91%, branch
62.03%, assertion 88.24%). This score includes vendor XPM and `glbl`
internals and is **not directly comparable** with generic-FIFO 86.59%.
The generic six-case regression was also rerun after the compile switch and
passed. The existing XSim vendor-model full-chain test passed another
independent ready-stall seed (10, 32 source beats, 56 four-plane words,
14 PA stalls) on 2026-10-03; this is directed XSim evidence only.

For FPGA CDC review, `syn/report_thermo5_cdc.tcl` opened the actual
`thermo5_i2_d1_a1/routed.dcp` checkpoint and emitted `report_cdc`,
clock-interaction, and timing reports under
`runs/uvm_thermo5_i2_d1/cdc_audit_20261003/`. The source/core clock
interaction is classified as asynchronous; the two real clock-pair sections
show XPM Gray-pointer crossings (`CDC-6`, depth two, `ASYNC_REG`) and reset
synchronizers (`CDC-3`, depth two). The unqualified report also contains
24,512 CDC-1 and 2,578 CDC-13 critical paths, primarily from unclocked OOC
control/reset input ports (plus 32 CDC-7 reset findings). **These are not
waived or signed off.** `report_timing_summary` confirms 565 ports with no
input delay and 264 with no output delay, although the internally constrained
218.75-MHz/125-MHz timing remains WNS +0.316 ns, WHS +0.027 ns. A full
integration-level I/O clock/reset contract and path-by-path CDC/RDC review
are needed before static signoff; a large raw OOC count cannot be declared
either a silicon failure or a clean CDC result. This is not SpyGlass
CDC/RDC signoff. The XPM FIFO's common asynchronous reset is tied to
the source reset in `dsm_axis14_to_core8_cdc.sv`; the UVM control BFM asserts
source and core reset together. A core-only reset is outside this integration
contract and needs separate RDC analysis before it can be supported.

## Instance/bin inventory (2026-10-03)

`tools/hw/thermo5_audit_reports.py` parses the **generic-FIFO frozen-SKU**
URG HTML into generated CSV under
`runs/uvm_thermo5_i2_d1/integration_audit_20261003/`. It records 216
condition bins across 30 DUT instances: 128 covered, 88 uncovered. There
are also 424 instance/signal toggle rows with at least one uncovered
direction, and 30 instance/line branch summaries with a missing branch.
These counts are inventory, not exclusions or a new coverage percentage.

| Exact instance/bin family | Count | Disposition |
| --- | ---: | --- |
| `g_lane[0..15].u_dpd`, line 140, `out_ready=0 && !valid_pipe[last]` | 16 | Reachable; separate DPD block test covers the bin. Frozen full-chain UVM still misses it; keep open at full-chain scope. |
| Same 16 instances, line 336, valid saturated I/Q and I-only/Q-only sub-bins | 48 | Frozen identity coefficients do not produce saturation for these MATLAB vectors. Programmable coefficient block test covers valid saturation separately. Parameter/vector-scoped gap, **not** a claim of frozen full-chain hit. |
| Same 16 instances, line 336, invalid slot with arithmetic saturation | 16 | Open. Investigate invalid-payload observability and legality; no waiver. |
| `u_interp_1` / `u_interp_2`, lines 69-71 bubble/backpressure | 4 | Reachable at isolated two-tap block boundary; directed block test passes, but not all combinations in continuous full-chain SKU. Open at full-chain scope. |
| Both interpolation instances, line 225 reset asserted with enable high | 2 | Legal block test passes; full-chain BFM intentionally disables core during reset. Keep separate scope. |
| `u_cdc.u_s_reset` / `u_cdc.u_c_reset`, line 27 reset asserted while sync stage remains high | 2 | Requires reset-delta/recovery review. Do not infer unreachable merely from the missing URG bin. |

The 424 toggle rows include fixed DPD coefficient/`active_taps` ports at
all 16 lanes; the per-instance signal/direction CSV separates these from
data/control signals needing stimulus. Branch CSV is an **instance/line
summary**, not an enumerated branch-bin proof. Thus branch and toggle closure
remain open. Before exclusion or coverage closure: map each remaining
branch/toggle bit to its exact source expression, parameter elaboration, and
test/proof; rerun URG. The frozen six-case 86.59% score is unchanged.

## Current-source instance audit and signed-endpoint coverage (2026-10-06)

`tools/hw/thermo5_audit_reports.py` now exports ownership-scoped branch-line
and assertion inventories in addition to its prior condition/toggle CSVs.
The script was run against the 2026-10-05 generic and real-XPM URG HTML reports
into separate ignored output directories:

- Generic: `runs/uvm_thermo5_i2_d1/integration_audit_20261005_current/`
- XPM: `runs/uvm_thermo5_i2_d1_xpm_rerun2_20261005/integration_audit_20261005_current/`

The latest generic report has 216 condition bins, 67 uncovered: 64 per-lane
DPD identity-saturation bins have independent SKU-specific numeric evidence;
one `u_interp_1` line-71 empty-stage-1/blocked-stage-2 bin and the two
`u_cdc.u_s_reset` / `u_cdc.u_c_reset` reset condition bins remain OPEN. The
XPM report has 228 bins, 72 uncovered: the same 64 DPD bins have the same
scoped proof, the two project reset bins remain OPEN, and six vendor FIFO
reset condition bins remain OPEN. No URG exclusion was generated.

Toggle inventory: generic has 424 uncovered instance/signal rows, including
168 TID input-range rows and 32 longer-valid-stream DPD counter rows still
OPEN; 112 fixed DPD coefficient/active-tap rows and 64 `MAX_TAPS=1` rows are
configuration-scoped; 48 DPD saturation rows have the identity numeric
proof. XPM has 430 such rows: the same project RTL groups plus six vendor XPM
rows that remain OPEN.

Branch inventory: generic has 30 instance/source-line rows with gaps. Eighteen
project RTL rows remain OPEN: 16 instances of `dpd_memory_poly.v:198` and two
instances of `dsm_interp_x2_polyphase_vector.sv:100`. The remaining 12 rows
have instance-scoped parameter/numeric support. XPM has the same 30 project
rows plus 60 vendor-XPM rows whose missing branch direction remains OPEN.
The URG HTML gives an aggregate missing count at a source line; it does not
identify which branch arm missed, so the parser records the source statement
and leaves arm direction unresolved rather than inferring closure.

The generic URG assertion report contains zero assertion instances. This is
only a report-scope observation. The XPM report contains 15 successful
assertion records, one expected illegal-frame assertion failure, and two UVM
package properties without attempts. The expected negative test must retain
its exact RTL assertion text and observation marker.

The UVM coverage component now has named `source_cg.cp_signed_min` and
`source_cg.cp_signed_max` bins and counts accepted source beats that contain
`-32768` or `+32767`. The bit-true test accepts `+EXPECT_SIGNED_EXTREMES` to
require both endpoints. Fresh one-case runs passed with VCS V-2023.12-SP1:

| FIFO | Seed | Accepted min/max beats | Source/output checked | Result |
| --- | ---: | ---: | --- | --- |
| Generic | 606101 | 32 / 32 | 32 / 56 words, all four planes MATLAB-matched | PASS, 0 UVM errors/fatals; functional source/core group coverage 83.3% / 75.0% |
| Real XPM | 606102 | 32 / 32 | 32 / 56 words, all four planes MATLAB-matched | PASS, 0 UVM errors/fatals; functional source/core group coverage 91.7% / 75.0% |

These one-case runs write VDBs under
`runs/thermo5_dv_closure_generic_20261006/` and
`runs/thermo5_dv_closure_xpm_20261006/`. They demonstrate the endpoint
functional bins, but were not merged into the separate seven-case code
coverage reports. The plan and complete requirement mapping are in
`docs/verification/thermo5-frozen-sku-signoff-plan.md`.

Checker update: source metadata/data and PA-plane mismatches in
`thermo5_pa_scoreboard.svh` now call `uvm_fatal`, before incrementing the
checked-word count. The complete generic/XPM licensed baseline regression
passed after this checker-only change. The earlier four XSim mutants were
not rerun as VCS-UVM mutants; no VCS mutant result is inferred.

## Fresh generic/XPM full regression and URG audit (2026-10-06)

`runs/thermo5_frozen_regression_hardened_20261006/manifest.json` reports
PASS with zero launcher errors: seven UVM cases and three independent
MATLAB payload seeds per FIFO implementation, plus separate URG merges.
All ten commands exited zero. The merged DUT hierarchy scores are 87.00%
generic and 79.96% XPM. They have different hierarchy and are not
comparable or signoff percentages.

The new instance-level CSVs are under each implementation's `audit/`
directory beside its merged `coverage/` report. Generic has 216 condition
bins with 67 uncovered, 418 uncovered toggle rows, 30 branch-gap rows,
and 24 assertion report rows. XPM has 228 condition bins with 72 uncovered,
424 uncovered toggle rows, 90 branch-gap rows, and 20 assertion rows.
Of the generic condition gaps, 64 retain the scoped identity-DPD proof;
one reachable interpolation combination and two reset-release bins remain
OPEN. XPM additionally has six vendor reset condition gaps. The single
project assertion failure in each merge is the named illegal-frame negative
test; UVM package register-map properties without attempts do not prove
functional closure. No gap was bulk waived.

The installed Rocky bridge task runner's `-ArgvJson` path was also attempted
for these runs, but its Windows PowerShell 5.1 JSON parsing treated a quoted
argument array as a nested object and rejected it. The reviewed static named
tasks in `tools/rocky-bridge.tasks.json` were used instead; both check for an
unused run directory before starting and contain no credentials or license
data.
