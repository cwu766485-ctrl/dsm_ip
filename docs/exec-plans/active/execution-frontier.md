# CDC/RDC error debugging — 2026-11-12 18:54 UTC

All10511 native Error messages preserved and grouped:5CDC source-combination,
7576elasticFIFO/2680DPD/149Gain/96asyncFIFO unreset-payload RDC,5mailbox RDC.
Actual VCS read-only prefill01->10 skew sensitivity reproduced at68.040ns;
AXIL-only reset old-pending application reproduced94.001ns OUTSIDE common epoch;
common reset recovery PASS. Focused runner2/2PASS,65utilityPASS Python3.12
(initial3.6 import failure retained). New realFIFO Formal4PROVEN/1payload
INCONCLUSIVE(depth10, then29 with fixed arbitrary bit),3positive covers both.
No physical RDC waiver/proof implied,all structural messages remainOPEN.
FrozenRTL/SGDC/VDB untouched;newHIT0/approval0. Source-register ECO and reset
contract/valid-mask composition still required;no identical proof rerun.
Evidence:docs/verification/thermo5-cdc-error-debug.md. PR60 remains unmerged.

# CDC/RDC Phase2 actual structural results — 2026-11-12

FrozenRTL unchanged;new task fromPR59. ActualAXIL/MAX_TAPS1/Generic SpyGlass setupPASS0E15W;CDC5E29W;RDC10506E15W;zero waivers,all OPEN. MissingTop fixed;Gray encoding checkdisabled/reset correlation unresolved. VCS block same-edgeDONE/W1C105nsPASS explicitcross100%,DECERR/SLVERR checked;GenericFIFO full/pendingreset/64wordrecoveryPASS independentqueue. These are block evidence,no productHIT/crossclaim,no productcompile/VDBchange. XPM actualmodels missing even /mnt/d/Xilinx/Vivado contains onlycoe.65utilityPASS. Remaining systemconcurrency/negative/staticdispositions OPEN;46technical/930counterOPEN,no approvals/merge. Evidence:docs/verification/data/thermo5-cdc-phase2/phase2_report.md.

# Final CDC/reset partial execution — 2026-11-12

ParentPR58; frozenRTL unchanged. New reset-sync component VCS PASS6epochs/18releases/25checks. Two fixed Generic source/AXIL phase pending-commit/nonzeroEF2/PAstall reset tests PASS independent oracle. Same-parent594+2 incremental596 merge,5URGviews clean,delta0,no hit loss/denominator drift.65utilityPASS. No new approvals/exceptions,46technical unresolved,8proofpending,930counterOPEN. XPM real models not located,NOT_RUN;SpyGlass setup probe failed no-top,static violation countUNKNOWN. TBAXIL single-stage release hardware-contractOPEN. Remaining concurrency/negative/full reset closure not implemented,no integration/signoff. Evidence:docs/verification/data/thermo5-final-cdc-reset/final_signoff_report.md.

# Current execution state: v5 Gain composition proven (2026-11-12)

Frozen RTL unchanged. New actual FIFO->Gain compositional Formal:4 proven,3 nonvacuous,2 target uncoverable,3 positive covers,0 blackboxes/setup violations. Gain2 now PROVEN_UNREACHABLE pending independent approval;46 technical unresolved;new HIT/approval/exception0. Existing11599 candidates preserved;2 new proof targets separate pending.930 counter scope OPEN. P1 crosses not implemented;Outstanding/q1_tail/event semantics OPEN. PR55->56->57 not merged,independent reviews absent. No VDB change/no generic rerun.65 utility PASS. Evidence:docs/verification/thermo5-signoff-v5.md.

# Current execution state: DV v4 exact triage (2026-11-12)

Frozen635be68 unchanged. Re-indexed remaining48 against v3 same-parent594 evidence: 22 Interpolator,7 CDC,2 Gain,2 Frontend,15 TX Top remain OPEN. Existing four P0 functional scenarios retain independent oracle/watchdog PASS but Exact URG delta0. No new Formal run because no new hypothesis; Outstanding/q1_tail and CDC/Gain/TX obligations remain OPEN. Added v4 disposition/matrix/formal/cross/remaining-open/signoff artifacts under docs/verification/data/thermo5-dv-v4. 11599 exclusion candidates pending, approvals0, exceptions0,930 counters OPEN. PR57 remains open; no merge. Both signoffs OPEN.
Evidence: docs/verification/data/thermo5-dv-v4/coverage_v4_signoff_report.md.

# Execution frontier

## Current execution state: DV v3 P0 execution complete (2026-11-11)

Frozen635be68 byte-identical. Four fixed P0s PASS:old40/56 output at651.510ns
boundary/pending/PA-stall conjunction;long64/96 STOP<TLAST<drain with7partial
stall edges each;reset pending/nonzero EF2/stalled PA plus postreset56words.
Independent CDC/EF2/four-plane trace oracles PASS.590inventory=>472recorded
signatures/118duplicates/47missing traces;330gap windows preserved,no seed search.
Final DV compile required;590replay+4P0=594PASS(590legal/4negative),sameparent.
Five URG views clean;Raw/Official/What-if unchanged,Exactdelta0.48technicalOPEN,
11599pending,930counterOPEN;newapproval/exception0. No new Formal hypothesis,
no inconclusive rerun;Outstanding/q1_tail fullproduct obligationsOPEN.
Two overlap scheduling failures retained and corrected at driver sampling edge.
Short task Review PR stacks on56;no automatic merge. Both signoffsOPEN.
Evidence:thermo5-dv-convergence-v3.md and data/thermo5-dv-v3/.

## Previous execution state

## Current execution state: DV v2 directed cross and exact Formal (2026-11-11)

Frozen635be68 unchanged. New non-identity COMMIT/boundary/PA-stall single-packet
window passes licensed UVM and independent56-word CDC/EF2/four-plane oracle.
Existing589 results retained +one directed=590 inventory, not a full rerun.
Fresh mailbox/gain Formal:5 nonvacuous PROVEN,5 target UNCOVERABLE,5 positive
covers,0 blackboxes/setup violations; reused source-bound DPD proof.54 targets
now6 pending proven/48 unresolved,not official closure.11599 pending candidates;
930 counter OPEN. Raw/Official/What-if rebuilt sameparent590,delta0,no diagnostics.
57utilityPASS. No seed expansion; Outstanding full refinement/q1_tail remainOPEN.
Separate stacked short-task PR for independent review; no auto merge/deletion.
Both signoffsOPEN. Evidence: thermo5-pr55-v2-execution.md and v2 manifest.

## Previous execution state

## Current execution state: DV convergence v2 Gate0 inventory (2026-11-11)

PR55 latest7b0c59c; frozen635be68 unchanged. Generated v2 exact triage for54
remaining technical rows and589-scenario inventory (585legal/4negative), with
same-packet/epoch evidence references. No bins reclassified: newHIT0, approved0,
exceptions0,54OPEN,930counter separate. Existing Raw=Official and What-if984
remain unchanged. DPD line93/CDC data_empty/Formal evidence reviewed; no duplicate
INCONCLUSIVE harness rerun. Weighted capacity28 remains conditional/UNPROVEN.
49utility checksPASS; no RTL/test/compile change, no regression needed. Code
Coverage/Full Linux DV OPEN. Evidence: thermo5-pr55-v2-execution.md.

## Previous execution state

## Current execution state: Previous141 strict analysis applied (2026-11-11)

PR55 previous141 maps139 native directives; shared DPD Block5/13 complete.
Strict delta4Line/17Cond/120Toggle,covered counts unchanged,no diagnostics.
All174 +old analysis gives What-if984=54noncounter+930counter;Line3352/3352,
Cond667/713,Branch526/528,Toggle92640/93576. Raw=Official unchanged12577OPEN.
No newHIT/approval/exception.11593candidatePENDING. No RTL/DV/executable change,
no regression/identical Formal rerun/no seeds. Weighted real-slot capacity28
conditional on unresolved RTL token/metadata/reset/STOP refinement;strict max
UNPROVEN. Empty-line-gap inventory bug fixed,49utilityPASS. BothsignoffsOPEN.
PR55 await independent review; no official.el or fabricated merge approval.
Evidence: thermo5-pr55-coverage-sprint.md and sprint_manifest.json.

## Previous execution state

## Current execution state: PR55 exact analysis application; approvalsOPEN (2026-11-11)

Input36c2839 preserved33 technical decisions. Fresh native dump from frozen589
VDB set verifies30 directives/33semanticIDs:23parameter+10legal CDC. Strict URG
exact deltas7Line/11Cond/14Toggle/1Branch,zero lost covered,zero diagnostics.
Shared Block47 covers230/231;Block43 covers224/225/226,complete membership.
Combined analysis What-if1125=195noncounter+930counter; Raw/Official unchanged
12577open. Candidate index11593unique=11419+141+33,allPENDING,no overlap.
Formal capacity29 retry INCONCLUSIVE depth51,4min;other goalsNOT_RUN,restricted
RUN harness not full STOP/reset proof.54 remain technicallyOPEN,87 officially
OPEN. NewHIT/approved/exception0;no seed expansion,no official.el. Existing589
regression/48utilityPASS;no executable/source change,no regression rerun.
Code Coverage/Full Linux DV OPEN. PR55 awaits actual independent review;
never use What-if delta as official closure. Evidence: thermo5-pr55-exact-application.md.

## Previous execution state

## Current execution state: Licensed589-test closure validation; zero exact delta (2026-11-11)

PR55 optional tail-reset target fixed: inspect HDL bit0,24-beat legal prefix.
Target347472ps, public reset,56-word four-plane oracle PASS; strict runnerPASS.
Two initial target failures retained; root cause full-width HDL vector compare.
Frozen635be68 unchanged. One frozen compile,589/589 scenarios PASS (585legal,
4negative). Raw=Official Branch526/637,Cond667/849,Line3352/3796,Toggle92640/104480;
What-if unchanged1158. Exact delta0,official approved/accepted0;87 stillOPEN.
Test native siminfo identifies same executable; Test VDB auxiliary file absent,
initial binding attempt fixed before URG. Five URG logs clean. Legal asserts
13success/0fail/two without attempts;combined3 failures only negative.48utility
checksPASS. New33 candidates pending,54 unresolved; no seed expansion.
Code Coverage/Full Linux DV OPEN. Update PR55 for external technical review;
no reviewer approval inferred, no official.el. Evidence: thermo5-rtl-grounded-closure.md.

## Previous execution state

## Current execution state: RTL invariants reviewed; licensed execution blocked (2026-11-11)

Base02b5c95; frozen635be68 unchanged. Exact87-row review adds33 pending technical
candidates (requested22 plus11 constant-dependent Conditions),54 unresolved;
all87 officially OPEN. Existing11560 candidates preserved. CDC source-reviewed
control abstraction exhausts89states/299transitions: legal end_remaining0/8;
arbitrary-TLAST counterexamples retained. Not an RTL equivalence/Formal PASS.
Prepared read-only-observed/public-reset-at-ready-tail test; isolated VCS
compile exits255, license service unreachable. No new HIT, approval, exception,
regression or URG result. Latest measured588-test baseline unchanged. Outstanding
29-slot capacity count needs real-word/tail conservation proof; guards stayOPEN.
Counter optionA retention recommended; optionB future parameter ECO only.
Preston confirmed owner/login cwu766485-ctrl, same PR author; no independent
approval. Code Coverage/Full Linux DV OPEN. Short task PR remains Draft pending
licensed compile/witness/URG and external review; do not merge unvalidated DV.
Evidence: docs/verification/thermo5-rtl-grounded-closure.md.
Next: restore authorized license service, validate prepared directed target;
obtain independent exact-scope decisions. No random-seed expansion.

## Previous execution state

## Current execution state: Two legal public-reset Condition hits (2026-11-10)

Frozen product635be68 unchanged. Stalled public-reset test gives native
Condition19 vector1110 in both interpolators, event VCD548640ps. These are
reset combinational propagation hits, not stable active-clock handshakes.
Full post-reset56-word independent four-plane oracle PASS.588/588 uniform
parent scenarios PASS (584legal/4negative);48 utility tests PASS. Raw=Official:
Branch526/637,Cond667/849,Line3352/3796,Toggle92640/104480,FSM13/13+22/22.
What-if1158=228noncounter+930counter. Actual delta+2Condition. Official
approved/accepted0; technical ledger3HIT/141pending/87unresolved. All five
URG logs clean. Legal asserts13success/0fail/two q1_tail without attempts;
combined3 failures only expected-negative. Redundant compile interrupted154
jobs and changed195 early parents; fixed by freezing compile and replaying
all affected inputs, failed attempts retained. Preston login/approvals absent.
Both signoffs OPEN. Evidence: thermo5-stalled-reset-exact-closure.md.

## Previous execution state

## Current execution state: Legal boundary COMMIT exact hit (2026-11-10)

PR52 merged c98cd519; technical review separate from independent approval;
remote task branch deleted. Frozen product635be68 unchanged. New legal
Identity COMMIT hits TXB-fe4a2292a0aa4da543b9 (cfg line333 vector101), pre-edge
VCD560070ps,112-word four-plane oracle PASS. Unified587/587 replay:583 legal,
4 expected-negative.48 hardware/66 reference tests PASS. Raw=Official:
Branch526/637,Condition665/849,Line3352/3796,Toggle92640/104480,FSM13/13+22/22.
What-if remaining1160=230 noncounter+930counter. Actual delta+1 Condition.
Eight native mappings resolved via VDB statement membership/branch shape;
five shared block entries require all-member scope approval. Historical11419
and141 new candidate IDs disjoint,union11560. Official approvals/exceptions0.
Technical231 ledger:1HIT/141pending/89unresolved. Legal asserts13success,0fail,
two q1_tail without attempts;3 combined failures confined expected-negative.
Both signoffs OPEN. Short task PR for code review; approval still separate.
Evidence: thermo5-native-and-boundary-closure.md and data/thermo5-native-closure.

## Previous execution state

## Current execution state: Final exact review; approvals pending (2026-11-10)

Frozen635be68/586-Test baseline unchanged. Repaired2448 historical root-cause
cells with source-batch ID checks; all11419 IDs/other fields and371 Waiver IDs
preserved. Fixed24 expression/subexpression native ambiguities:223 exact,
8 unresolved. Preston assigned Reviewer; no actual approval/product-owner
counter decision supplied. Official Adjusted remains Raw.

New DPD Formal:10 independent internal lemmas proven; gated promotion proves
Invalid sum zero/no-saturation; target cover uncoverable,2 positive covers hit.
16 DPD rows become pending candidates; fresh EF2 six-assertion/three-cover
proof plus width bounds adds16 more:141 candidates/90 OPEN technical rows.
No URG delta; What-if1161 and all930 counters OPEN. First blackbox/source-list
attempt discarded; monolithic timeout and session-lock failures recorded.
Code Coverage/Full Linux DV signoff OPEN. Short-term task PR for Preston;
merge/delete only after review. Evidence: thermo5-final-exact-review.md.

## Previous execution state

## Current execution state: Consolidated thermo5; final coverage OPEN (2026-11-10)

PR #49/#50/#51 merged in dependency order. Verified product SHA:
635be681046b3ab7d6fdda7f4e9818d7226efd66, tree identical to PR #51.
37 remote branches deleted after ancestry/SHA/PR checks; 18 remain (five
long-term +13 legacy diverged). All13 legacy heads have pushed archive tags;
104/164 source reverse checks pass; evolved hunks remain to review, branches
retained. No blanket merge or force push.

Fresh unified compile and 586/586 replay PASS (582 legal, four expected-negative),
one Design/Test compile parent. Raw=zero-approved Adjusted: Branch526/637,
Cond664/849, Line3352/3796, Toggle92640/104480. Same-input What-if OPEN1161
=231 non-counter+930 counter. Legal assertions13 success, zero failure, two
q1_tail without attempts; three combined failures only expected-negative.
48 hardware /66 reference-model tests PASS. No new seeds or extra exact hits.

231 dispositions:109 EXCLUSION_CANDIDATE,122 OPEN; approvals=0. Native lookup
199 unique objects needing exact-vector review,24 ambiguous,8 missing.
11,419 source/ID/link checks pass;2,448 inherited root-cause group cells empty.
All930 legally reachable counter directions remain OPEN pending scope approval.
Code Coverage and Full Linux DV signoff OPEN; no official exclusions/exceptions.

Next: review evolved legacy hunks and minimal ports; resolve122 reachability
and32 native-mapping gaps; obtain real independent approvals. Work from clean
thermo5 with disposable task branches; no new Round-N branches.
Evidence: docs/verification/thermo5-consolidation-and-coverage-20261110.md
and docs/verification/data/thermo5-consolidation-20261110/.

## Previous execution state

## Current execution state: Thermo5 Round 21 root-cause closure (2026-11-10)

GitHub integration gate completed: authenticated account verified; 8a61798
uploaded to codex/thermo5-round21-resume. Draft PR #51 targets
codex/thermo5-round20-exact-bin-closure, preserving #49 -> #50 -> #51.
https://github.com/cwu766485-ctrl/dsm_ip/pull/51
No regression rerun, merge, exclusion approval or signoff change.


Blocked-B follow-up: directed register protocol/readback PASS, actual delta 0.
Exact line93 Formal proves the missing tuple unreachable (1 non-vacuous
assertion, 2 positive covers, 1 uncoverable cover; reset constraints recorded).
Native Condition21/vector011 bound; still PENDING independent approval.
No official exclusion; What-if remains 1161. Chinese local inventory is under
runs/coverage_status_zh/. See thermo5-round21-bstall-exact-review.md.


Latest queue milestone: eleven source-clock gap cycles before packet beat 32
produce legal single-entry pop+push in BOTH stages. Strict UVM event checks,
four-plane independent oracle, counters, drain and VCD PASS. Actual URG delta
+2 Branch/+14 Line/+2 Condition. Incremental Raw 526/637 Branch, 664/849 Cond,
3352/3796 Line, 92640/104480 Toggle. What-if OPEN 1161 = 231 non-counter +930
counter. Approvals/exclusions=0. Gap12 real-underflow failure excluded; gap10
functional PASS/target miss excluded. New strict runner checked. Product RTL
unchanged; final homogeneous replay and independent approvals still required.
Evidence: docs/verification/thermo5-round21-single-replacement-closure.md.
Counts in earlier entries below are historical incremental/baseline results.


Latest follow-up: one focused AXI-Lite address-return test adds eight exact
Toggle hits, with checked DECERR/OKAY and VCD witness. Incremental Raw Toggle
92640/104480; What-if OPEN 1179 = 249 non-counter + 930 counter. Approved=0.
Product RTL hashes unchanged; DV-only compile differs from frozen aggregate.
Incremental URG has no mapping diagnostics; homogeneous replay before final
signoff remains required. Full regression/Formal not rerun. Evidence:
docs/verification/thermo5-round21-address-return-closure.md. Earlier counts
below are the preserved homogeneous 584-Test baseline.


PR #50 base 818e1de. Five exact DPD Condition bins gained legal I-only/Q-only
witnesses; Condition Raw is 662/849. Product RTL/configuration unchanged.
All inherited 580 scenarios are rebuilt with one current compile parent;
four focused scenarios complete the 584-Test baseline. Legal and four expected-
negative inputs are separated for assertion reporting. One missing old oracle
file was reconstructed independently; its first failure is retained.

Raw/zero-approved Adjusted: Branch 524/637, Condition 662/849, Line 3338/3796,
Toggle 92632/104480; FSM 13/13 states and 22/22 transitions. What-if retains
1,187 open bins: 257 non-counter and 930 Counter. Approved exclusions and
exceptions=0. The 11,419 analysis candidates remain pending independent review.
Counter arithmetic (31 carry boundaries, wrap, async reset, hold) passes at
block level; deposited registers never contribute product toggle coverage.
Two scoped q1_tail metadata/reset Formal jobs PASS; full-chain transfer remains
open. Legal assertions: 13 success, zero failures, two q1_tail without attempts.
Combined three failures are confined to expected-negative runs.

Evidence: docs/verification/thermo5-tx-root-cause-closure-round21-20261110.md
and docs/verification/data/thermo5-r21/. Review proposals cover the AXI-Lite
Branch, four MAX_TAPS=1 Lines, and counter system acceptance. No reviewer has
approved them. PR #49 -> #50 -> Round 21 review order remains required.

Integration follow-up: uploaded a98a32d verified. Current URG native dump
identifies Blocks for DPD lines 61/80, but no separate objects for 62/81;
companion-line mapping stays OPEN. Reviewer addendum includes the queue
transition table, 257-bin source grouping and assertion/Formal obligations.
No new hits or approvals from this read-only follow-up.

Next: review Draft #51 after #49/#50; obtain real independent approval and
resolve native companion-line mapping;
close the remaining queue/handshake and counter/formal obligations. Never call this final signoff. XPM/GT/FPGA/board/RF remain outside scope.

## Previous execution state

## Current execution state: Thermo5 Round 20 exact-bin closure (2026-11-09)

Review branch `codex/thermo5-round20-exact-bin-closure` starts at PR #49 base
`49b9121a860c6b85057047c7696876df7f6cd740`. Product RTL is unchanged at
`fe315cabf058dd184b6d94ffa4ed3b5fb9916733` / aggregate SHA-256
`fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.
Product configuration remains Centered-Cubic x2+x2, EF2 ORDER=2 STEP=5120,
20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 Identity reset, AXI-Lite,
Generic FIFO.

Added optional source bubble probability and 32/64/96-beat packet selection to
the existing random packet test. The default path preserves legacy uniform
random-gap behavior. Replayed 21 R19 scenarios with the R20 compile and ran
five focused scenarios; all 26 VCS tests passed. The focused interpolator
seeds used PA stall/source-bubble probability 25% and packet lengths 32/64/96;
AXI-Lite register and legal CDC frame-end/drain checks passed. The DPD
saturation replay passed where its oracle applies. The combined Raw URG exact
delta was zero for Branch, Condition, Line, and Toggle; the 263 non-counter
targets remain open.

Fresh same-input URG results: Raw = zero-approved Official Adjusted = Branch
524/637, Condition 657/849, Line 3338/3796, Toggle 92632/104480. Strict
Analysis-only What-if maps one additional exact AXI-Lite default-response
Branch, leaving 1,192 bins (5 Branch, 84 Condition, 25 Line, 1,078 Toggle).
That one-bin exclusion is supported by a source-matching, zero-assumption,
zero-black-box prior Formal result but has no independent Reviewer approval;
official approvals/exclusions remain zero. The 371 official Waiver IDs remain
present (2 semantically Raw-hit-resolved, 369 pending review).

The R20 VDB manifest records the refreshed fingerprints: all 26 standalone
VDBs share the current Design VDB parent; the frozen Round 18 aggregate still
has a Round 16 parent. Thus the URG results are diagnostic and the aggregate
must be rebuilt/replayed before homogeneous final signoff. URG logs have zero
warning/error/mapping/checksum/scope diagnostics. Inherited Assertions remain
15 success, 3 failure, 4 uncovered, 2 without attempts (overlapping groups).
Full Product Regression and Formal were not rerun. The 930 Counter bins stay
in scope, with a reviewed acceptance proposal still open. **Coverage and Linux
DV signoff remain OPEN.**

Evidence: `docs/verification/thermo5-tx-exact-bin-closure-round20-20261109.md`
and `docs/verification/data/thermo5-r20/`, including the exact 263-bin, 1,192-
bin, and 930-Counter ledgers, test matrix, VDB manifest, and URG evidence.

Next: submit as an independent review PR stacked on PR #49. Do not merge,
approve the Analysis-only candidate, or claim signoff. Before official
closure, rebuild the frozen aggregate with the current parent; obtain real
Waiver approval; close exact remaining bins, Formal/Assertion, and full
regression obligations.

## Previous execution state: Thermo5 Round 19 non-counter coverage closure (2026-11-09)

The Round 19 report remains at
`docs/verification/thermo5-tx-final-code-coverage-round19-20261109.md` and is
superseded for current status by the Round 20 report above.

## Previous execution state: Thermo5 Round 18 targeted coverage closure (2026-11-09)

Review branch `codex/thermo5-round18-final-coverage-closure` starts at PR #47 source `f9275273ef2137c5c181cb5395cdd9f706dd4b90`; Product RTL remains unchanged at aggregate SHA-256 `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`. Product compile fingerprint is `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`.

A legal AXI-Lite non-Identity one-tap DPD saturation test passed on 65,632 output words and 1,172 56-word frames. The independent Python oracle matched all 16 lane sample/saturation counters, all four PA planes were bit-true, queues drained, and early/final underflow were zero. A post-drain STATUS read checked the independently predicted lifecycle bits after the settling window. The 553→554 Test-VDB Raw delta is 430 exact Toggle hits: 80 sample-count, 350 saturation-count, zero other.

Actual Full64 URG was rerun on the same VDB manifests for Raw, zero-Waiver Official Adjusted, and strict Analysis-only What-if with 11,405 and 11,418 candidates. Official remains Raw because approvals=0 and exclusions=0: Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92568/104480. After exact mapping of 9 Branch and 4 Line candidates, Analysis-only What-if leaves 1,257 bins (Branch 6, Condition 84, Line 25, Toggle 1,142). It is not official signoff.

Review packets retain all 371 official Waiver IDs (367 matched pending, 2 pending outside the old set, 2 resolved by Raw hit) and group 11,418 candidates by seven root causes. No candidate is approved. There are 115 remaining non-toggle bins (113 UNKNOWN, 2 DEFENSIVE_NEGATIVE), 496 sample-count counter toggle directions, 498 saturation-count directions, and 148 other data toggle directions. The two 32-bit counters stay in scope; no product-lifetime bound supports excluding their high bits. No dead RTL was established or removed.

Evidence/report: `docs/verification/thermo5-tx-final-code-coverage-round18-20261109.md` and `docs/verification/data/thermo5-r18/`. Python reference suite is 66/66, hardware/coverage tool suite 47/47, and targeted VCS test PASS. Full product regression and Formal were not run; the inherited URG assertion summary still has 3 FAILURE and 2 UNCOVERED. **Coverage and Linux DV signoff remain OPEN.**

Next: publish this evidence as an independent-review PR targeting `thermo5`; do not mark final signoff or activate Waivers without real Reviewer approval. After review, target the 115 control bins and counter/data toggle groups by Exact Bin, rerun Formal/Assertion obligations, then perform a clean final product regression and official Raw/Approved Adjusted URG.

## Previous execution state: Thermo5 Round 17 final residual review (2026-11-09)

The final residual review is documented in `docs/verification/thermo5-tx-r17-final-residual-coverage-review-20261109.md`. It strictly applied all 2,448 new EF2/Active-Tap exact candidates in Analysis-only URG. On the frozen 1-Design +551-Test input, the combined What-if residual is 1,766 bins; two directed UVM Test VDBs added 66 exact Raw Toggle hits, leaving 1,700 bins on the 1-Design +553-Test incremental set. The full ledgers and input/log hashes are in `docs/verification/data/thermo5-r17/analysis_only/round17_supplemental_urg_evidence.json`.

The 1,700 remaining bins comprise Branch 15, Condition 84, Line 29, Toggle 1,572. All remain OPEN. 1,685 are still classified UNKNOWN; 10 have static-review CONFIG_UNREACHABLE labels, 3 STATIC_UNREACHABLE, and 2 DEFENSIVE_NEGATIVE_ONLY, none independently approved or excluded. Sample-count high bits remain in-scope absent a product lifetime bound; DPD saturation-count reachability is unresolved. No product RTL was removed or modified.

The official 371-row Waiver CSV is unchanged; all are pending, approved Waivers=0 and official Exclusions=0. The 2,448 new candidates are pending independent review. Official Adjusted therefore remains Raw. URG assertion counts are still 13 SUCCESS, 3 FAILURE, and 2 UNCOVERED; Formal obligations were not rerun. **Linux DV signoff remains OPEN.**

Fresh targeted UVM tests passed: long AXI-Lite-controlled stream (seed 271030, 8,232 core words) and register access (seed 271032). The long finite-source test recorded 70 post-source underflow cycles and zero early-underflow cycles; it was not reported as zero underflow. Full product regression and Formal were not rerun. PR #47 remains a review branch; this is an intermediate coverage result, not final signoff.

Next: independently review the exact 2,448 candidates and keep approvals external; then close or formally assess exact residual groups. Prioritize the 84 Conditions, 15 Branches, 29 Lines, 148 other Toggle bins, and clarify the Counter/saturation proof scope. Do not bulk-add random seeds, weaken assertions, broaden Exclusions, or claim 100% from Analysis-only output.

## Previous execution state: Thermo5 Round 17 remaining-bin review package (2026-11-09)

The historical 4,214-bin report remains `docs/verification/thermo5-tx-r17-remaining-uncovered-bin-report-20261109.md`; it records the 551-Test What-if result before the new 2,448 candidate batch. It is superseded by the final residual report above for current What-if counts. The preceding precise-exclusion report and static review remain historical evidence and are linked from the new report.

## Previous execution state: Thermo5 TX Round 17 static reachability audit (2026-11-09)

PR #47 remains Draft/Open against `thermo5` (base `7708d0eb9a2128942ff802202c0d1716c8c11f8b`). This review started from local PR commit `a33894e445df07c91899bc76104ffb39a8a656e9`; Product RTL is unchanged at aggregate SHA-256 `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`, compile fingerprint `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`, and 97/97 source hashes match the compile-parent manifest.

Static review of all 13,171 semantic exact-bin rows classifies 138 `STATIC_UNREACHABLE`, 8,832 `CONFIG_UNREACHABLE`, 2 `DEFENSIVE_NEGATIVE_ONLY`, and 4,199 `UNKNOWN`; no `TRUE_DEAD_CODE`, established `REACHABLE_UNTESTED`, or reproducible `TOOL_OR_MAPPING_ISSUE` was identified. “No reachable row established” does not resolve the UNKNOWN set. All 8,970 structural/configuration candidates remain unapproved; reviewer approvals=0 and official exclusions=0. The exact-bin CSV now carries a per-row rationale, trace references, and trace-completeness status; UNKNOWN rows remain explicitly incomplete/open. Generated ledgers and hashes are indexed by `docs/verification/thermo5-tx-static-reachability-review-20261109.md` and `docs/verification/data/thermo5-r17/static_reachability_review/thermo5_tx_static_reachability_review_manifest.json`.

Last recorded same-input Raw and zero-exclusion Adjusted URG remains Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480, FSM states 13/13 and transitions 22/22. Actual What-if URG is NOT RUN: the exact 1-Design +551-Test VDB set identified by manifest SHA `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509` is absent from available workspaces and GitHub workflow runs have no artifacts. Do not substitute another VDB set or report arithmetic projection as Adjusted Coverage.

No RTL, algorithm, product parameter, Formal harness, official Waiver, or Exclusion changed. VCS smoke failed before compile: the default launcher selected a missing `linux/bin/vcs1`; `VCS_ARCH_OVERRIDE=linux64` then reported the WSL2 kernel unsupported. No targeted test or new URG hit is claimed. Next: run this directed campaign on a supported licensed Linux host; obtain/rebuild the exact frozen VDB set; independently review the per-bin candidate package; then produce same-VDB Raw/Analysis-only What-if URG. Plan minimum witnesses only against the 4,199 UNKNOWN rows, stopping any campaign without exact new hits. Linux DV signoff remains OPEN.

## Previous execution state: Thermo5 TX Round 17 DPD Identity closure (2026-11-09)

PR #47 remains Draft/Open, based on `thermo5` `7708d0eb9a2128942ff802202c0d1716c8c11f8b`; local source tree `2e4e2f583eba13338171a024b01eca090eaf5e13` matches the remote PR tree. Product RTL hash and parameters are unchanged. The official VC Formal Identity runner (`--auto-lemmas`) reached 1/24 assertions PROVEN, 23 INCONCLUSIVE, 4/4 original Covers, zero black boxes and no SAT counterexample; the runner gate correctly returned INCONCLUSIVE/FAIL. Separate local S7–S10 proofs are not accepted as full composition because a transfer replay was inconclusive and the automatic composition did not reproduce them. New report/evidence: `docs/verification/thermo5-tx-dpd-identity-stage7-10-formal-closure-20261109.md` and `docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_stage7_to10_formal_followup_20261109.json`.

Last same-manifest coverage remains Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480, FSM 13/13 states and 22/22 transitions; 13,171 code bins remain open. Waivers: 2 resolved by Raw hit, 369 pending review, 0 approved, 0 exclusions. Full Linux DV signoff remains OPEN. Next work is reproducible staged proof binding and root-cause analysis for q-saturation/arbitrary-stall properties; no new random campaign or official URG merge is justified by this Formal-only update.

## Previous execution state: Thermo5 TX Round 17 final closure audit (2026-11-08)

Latest follow-up is based on `thermo5` HEAD `7708d0eb9a2128942ff802202c0d1716c8c11f8b`; Product RTL and product parameters are unchanged. A new Formal-only Harness change adds 14 S0–S6 I/Q alignment Lemmas. VC Formal proved all 14 non-vacuously and then proved the gain-identity Lemma through staged composition. The final arbitrary-stall payload/no-saturation/saturation-count goals remain INCONCLUSIVE (no SAT counterexample); full-chain Identity stays OPEN. A one-test AXI-Lite register-access VCS/URG smoke passed on this HEAD, but it is not a full regression or the 551-Test official URG rerun. Details: `docs/verification/thermo5-tx-final-closure-round17-20261108.md` and `docs/verification/data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_formal_followup.json`.

The PR #46 checkout `codex/thermo5-round16-coverage-closure` was reverified at source HEAD `4d92ecb8467b095b50478065e29e9646f2cff27e`, based on `thermo5` `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`. Product RTL aggregate SHA-256 remains `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`; compile fingerprint `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`; 95/95 compile input hashes match. Product remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit, DPD_MAX_TAPS=1 Identity reset, AXI-Lite, Generic FIFO.

Tool availability is **PASS** in Rocky 8.10 / WSL2. VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1` and CovDB 13.1 run in 64-bit mode. The earlier kernel blocker was a mistaken conclusion caused by URG's default 32-bit support-directory probe; use `urg -full64` and VCS `-full64`. No `VCS_ARCH_OVERRIDE` is required. VC Formal is `V-2023.12-SP2`.

Fresh checks on this source passed: Generic FIFO and AXI-Lite product UVM; DUT hierarchy AXIL coverage suite; System Random 110/110 (seeds 720000–720099 and long seeds 820000–820009); DPD/gain/profile 60/60; COMMIT-boundary/PA-stall 2/2; Reset/Pending-COMMIT 8/8; STOP/Drain/Restart (2 packets, 112 ordered PA words); Unified SV scoreboard mutations 6/6; Python oracle unit tests 64/64; reset-only Formal smoke (3 assertions proven, 4 covers reached, one modeled collision cover uncoverable, 0 black boxes). Details and reproduction commands: `docs/verification/thermo5-tx-r17-wsl-vcs-reverification-20261108.md`.

Raw and zero-exclusion Adjusted URG were regenerated from the same manifest: one current Design VDB + 551 Test VDBs (362 carry-forward, 189 freshly generated). The VDB manifest SHA-256 is `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`; all 95 compile input hashes matched. Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480; FSM states 13/13 and transitions 22/22. There are 13,171 open code bins. Fresh VDBs added zero exact DUT code hits over the 362-test baseline. Approved Waivers=0 and active Exclusions=0, so Adjusted equals Raw.

The final property audit classified the 3 DUT URG Failure rows: the CDC alignment assertion and both stage `q1_tail` assertions fire only in expected-negative illegal-frame tests whose checker/reset recovery passes. The 2 `q1_tail` URG Uncovered rows overlap those same assertions because no legal successful attempt was recorded. A scoped legal-frame metadata proof makes the antecedents uncoverable in its 56-sample schedule, but omits FIFO/DPD composition, so product obligations remain OPEN. The current-source DPD Identity monolithic runner has one PROVEN and four INCONCLUSIVE assertions with no SAT counterexample; a new 14-property S0–S6 I/Q alignment decomposition proves all 14 non-vacuously and proves the gain identity Lemma, but the final payload/arithmetic/saturation goals remain INCONCLUSIVE under arbitrary stalls. A no-stall leaf decomposition proves 5/5 but does not cover arbitrary backpressure. Outstanding Counter and COMMIT lifecycle remain OPEN. The current AXI-Lite Active-Tap runner correctly fails closed with 4/6 assertions proven and 2 inconclusive. No Waiver was approved, no `.el` exclusion applied, and no XPM/GT Wizard, Vivado timing/PPA, FPGA, RF or physical QAM256 validation ran.

The Waiver audit now compares the product compile fingerprint and Waiver-audit fingerprint according to their separate schemas, then validates product source hashes, compile manifest, VDB inventory and URG report binding. The official inventory has 371 unique IDs: 2 `RESOLVED_BY_RAW_HIT`, 369 pending (361 ELIGIBLE, 4 NEEDS_REPROOF, 4 UNRESOLVED); 0 reviewer approvals and 0 exclusions. All 369 pending rows map to one exact current Raw gap and all 371 source hashes match. A new Pair-1 ledger binds all 8,192 Toggle candidates to the 551-Test VDB manifest while retaining pending approval. The 189 fresh VDBs still add zero exact DUT code hits.

A 9-job scoped VC Formal batch also ran at docs-only HEAD `e5437af88232a743e6097f1d50734152683db933` with the same RTL hashes. The unbounded 32-bit DPD counter transition harness passed 35 assertions and 4 Covers; CDC residual/data-empty/end, EF2 pair/product-parameter, and frame-tail metadata/reset jobs passed within their harness scopes. The DPD Identity job returned only 1/5 required assertions PROVEN and failed the runner gate; its arithmetic identity claim remains OPEN. No Formal Cover was added to URG. Exact job statuses, property lists and log hashes are in the current Round 17 evidence manifest.

**Decision: full Linux DV signoff remains OPEN (`RAW_100_OPEN`).** Raw equals zero-exclusion Adjusted: Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480; 13,171 exact bins remain. The detailed root-cause, waiver and assertion audit is `docs/verification/thermo5-tx-final-closure-round17-20261108.md`; machine evidence is under `docs/verification/data/thermo5-r17/final_closure_audit/`. PR #46 was merged into `thermo5` as an intermediate evidence snapshot at `76f485d370c89493c46098b142ffad64544b2cfc`; this is not final signoff. Next work is independent review of exact candidate mappings and proof decomposition / directed stimulus against Exact Bin IDs, not broad random seeds. Do not report FPGA/physical signoff.

Machine evidence/hash inventory: `docs/verification/data/thermo5-r17/thermo5_tx_r17_wsl_vcs_reverification.json`. Run outputs remain ignored under `runs/thermo5_r16_gate1_20261108/` in the isolated worktree.

The previous snapshot below records the state before the 64-bit tool mode was corrected; its VCS/URG-blocked statement is superseded by this current execution state.

## Previous execution state: Thermo5 TX Round 16 coverage closure (2026-11-08)

PR #45 is already merged into `thermo5` at `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`. Product configuration remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit, DPD_MAX_TAPS=1 Identity reset image, AXI-Lite, Generic FIFO. Product RTL aggregate SHA-256 is `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`; the 95-source compile fingerprint is `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`.

Round 16 Raw and zero-exclusion Adjusted URG use one Design VDB + 362 Test VDBs, including all 240 Round 15 test VDB trees and 122 additional Test VDBs. VDB manifest SHA-256: `75b83f5b49a6fd180f3485f56066a7325a27825edc78284be2d83d24c6fd6fef`; path-free manifest SHA-256: `d457cd7eb89f8e607a3c18be6197d58982afe93186611dd5be9f76ccb60c4e34`. Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92072/104480; FSM states 13/13 and transitions 22/22. The 784 Round 15 Toggle hits are preserved. No new exact Raw Code Coverage bins were hit in the 122 added VDBs; 13,171 exact bins remain. No waiver is approved and no exclusion is active, so Raw equals official Adjusted.

The clean 369-row waiver set was revalidated against current exact bin IDs and current source hashes: 361 analysis candidates, four historical scoped Formal candidates, and four unresolved candidates; all remain pending. The official 371-row CSV still contains two bins already hit by Raw and needs reviewed `RESOLVED_BY_RAW_HIT` reconciliation. The malformed Round 15 refresh CSV is not used. A separate Pair-1 package maps 8,192 exact Toggle bins to 64 scoped Formal properties; it is pending independent review and excluded from official Adjusted. No `.el` exclusion was applied.

The fail-closed Coverage Gate was attempted after adding the 95-file source hash map and audit-tool hash. It exited 3 because the legacy zero-approval audit is not bound to the current official 371-row waiver CSV. This is **BLOCKED / NOT PASS**, not a coverage regression; the same-input Raw/zero-exclusion Adjusted URG figures remain unchanged. Do not claim Coverage Gate signoff until the current waiver inventory is reconciled (including two Raw-hit rows) and reprocessed by the formal waiver pipeline.

Generic FIFO and AXI-Lite product VCS, System Random 110/110, DPD/Gain/Profile 60/60, COMMIT-boundary/PA-stall 2/2, Reset/Pending-COMMIT 8/8, scoreboard mutations 6/6, and Python reference 64/64 passed. The two current-source q1_tail assertions still have zero legal attempts. AXI outstanding-counter Formal is INCONCLUSIVE; full-chain DPD Identity and COMMIT lifecycle remain OPEN. The EF2 product-parameter proof passes only its stated static-configuration scope.

**Decision: Linux DV signoff OPEN (`RAW_100_OPEN`).** Current coverage table, exact root-cause ledger, waiver review, Formal matrix, and 977-entry run-log hash manifest are in `docs/verification/thermo5-tx-round16-final-coverage-closure-20261108.md` and `docs/verification/data/thermo5-r16/`. Next: independent review of Pair-1/configuration-only candidates; targeted legal witnesses for the 25 open Branch and 192 Condition bins; then exact Line/Toggle and required Formal/Assertion closure. Keep unresolved items open. FPGA/XPM/GT/Vivado/physical QAM256 remain not run.

## Previous execution state: Thermo5 TX Round 14 targeted coverage and Linux signoff (2026-11-07)

PR #42 and PR #43 are integrated into `thermo5` as `42960c12cc381a7c58dddc501d4a851bbead13ec` and `253268f38783c37b3bbb19479654b236fff3f732`. Round 14 was run on tested product source `f22dad56f7cd56e94158cb86cdad04e3d11e489d` in `/tmp/dsm_ip_thermo5_round14`; PR #44 (`codex/thermo5-round14-coverage-closure`) is the open draft review branch. The current product compile fingerprint is `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`; RTL aggregate SHA-256 is `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`. No RTL, frozen algorithm, product parameter, VDB input set, or coverage denominator changed.

Fresh Linux runs and evidence are in `docs/verification/thermo5-tx-round14-targeted-coverage-signoff-20261107.md` and `docs/verification/data/thermo5-r14/`. Generic FIFO and AXI-Lite product regressions passed; System Random 110/110, DPD/Gain/Profile 60/60, randomized Reset/COMMIT 24+24, Python reference 64/64, hardware utilities 47/47, and direct SV Unified Scoreboard mutations 6/6 passed. The homogeneous coverage set contains one Design VDB and 232 Test VDBs, all matching the compile/configuration manifest. All 16 functional covergroups are 220/220 including two expected-negative-only bins; legal-applicable bins are 218/218 and both negative-only bins are separately hit.

Current DUT Raw and official Adjusted URG are identical because approved Waivers and active Exclusions are both zero: Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 91288/104480; FSM states 13/13 and transitions 22/22. There are 13,955 exact open Raw bins. The source-linked Round 12 bin ledger was revalidated against 11 current RTL files with zero source-hash mismatches; it is carried forward, not represented as a newly exported per-toggle ledger. The Round 14 machine summary and 21-file product RTL audit are included in the evidence package.

Focused AXI-Lite configuration Formal passed four assertions with no assumptions or black boxes; three assertion checks were non-vacuous. Scoped DPD gap-counter and EF2 product-parameter proofs passed within their stated bounds. Full-chain DPD Identity remains INCONCLUSIVE, AXI outstanding-counter guard remains OPEN/INCONCLUSIVE, and both legal product `q1_tail` properties have zero legal attempts. These remain signoff blockers; negative tests intentionally exercise the associated defensive assertions in a separate campaign. No Waiver is independently approved, and the Formal results do not automatically exclude any URG bin.

**Decision: Linux DV signoff OPEN (`RAW_100_OPEN`).** Functional legal-applicable coverage and the recorded regression set pass; code coverage, required Formal/Assertion closure, and independent waiver review are not complete. Real XPM/GT Wizard, integrated CDC/RDC, Vivado timing/PPA, board/RF and physical QAM256 validation are NOT RUN.

**Next:** review exact 113 Branch and 192 Condition bins against legal tests and current source; then handle 458 Line bins and 13,192 Toggle bins by signal/root cause. Independently review the 369 pending waiver candidates without pre-approval; resolve DPD Identity, AXI outstanding-counter, and legal `q1_tail` obligations or submit a reviewed alternative acceptance policy. Keep PR #44 open until the evidence and reviewer decisions are complete; do not merge it as final signoff.

## Previous execution state: Thermo5 TX Linux DV Final Signoff Round 13 (2026-11-07)

## Historical execution state: Thermo5 TX Linux DV Final Signoff Round 13 (2026-11-07)

Working checkout: branch `codex/thermo5-round13-closure`, HEAD
`fd65aae8fead67b736205610e59d1f706088774a`. Product compile-source commit
`a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0`, fingerprint
`9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a`.
Configuration remains Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
20-bit, DPD_MAX_TAPS=1 / Identity reset, AXI-Lite, Generic FIFO. Current
checkout revalidates all 97 compile-input hashes (0 mismatch). The same
homogeneous official coverage input is 1 Design VDB + 232 Test VDBs; all 3,040
VDB files match their manifest.

VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1, VC Formal V-2023.12-SP2, and
Python 3.12.13 are operational under Rocky 8.10 / WSL2. Fresh Generic
Centered-Cubic/EF2 and AXI-Lite product regressions passed. System random
110/110, DPD/gain/profile 60/60, COMMIT-boundary/PA-stall 2/2,
reset-pending-COMMIT 8/8, direct SV scoreboard mutations 6/6, Python model
64/64, and hardware utilities 45/45 passed. These fresh build VDBs are kept
separate from official coverage; the Round 12 232-test VDB set is same-source
carry-forward evidence, not a claim that all 232 tests were freshly rerun.

Raw and official Adjusted URG were regenerated on the same validated VDB
manifest. Raw=Adjusted because approved Waivers=0 and Exclusions=0:
Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 91288/104480;
FSM states 13/13, transitions 22/22. There are 13,955 Raw uncovered code bins.
A historical analysis-only What-if with 361 candidate exclusions leaves
13,594 open bins; it is not official Adjusted. Exact Raw inventory:
`docs/verification/data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz`.

Four stale candidate properties have fresh current-source focused Formal
results PROVEN, but exact URG mapping and independent reviewer approval remain
pending. 361 other candidates remain pending review; four interpolator
candidates remain unresolved. No exclusion is active. Outstanding-counter
Formal remains INCONCLUSIVE; full-chain DPD Identity remains INCONCLUSIVE; two
legal `q1_tail` assertions at centered interpolator stages 1 and 2 remain
without legal attempts. Legal-only assertion URG has 13 successes and zero
failures; expected-negative assertion failures are isolated.

**Decision: Linux DV / Code Coverage signoff OPEN (RAW_100_OPEN).** Strict 100%
Adjusted coverage is not achieved. No product RTL or frozen algorithm changed.
Real XPM, GT Wizard, Vivado timing/PPA, FPGA, board/RF, and physical QAM256
signoff remain NOT RUN.

Detailed report:
`docs/verification/thermo5-tx-linux-final-signoff-round13-20261107.md`.
Machine-readable source/VDB/formal/regression and log-hash index:
`docs/verification/data/thermo5-r13/thermo5_tx_r13_final_coverage_manifest.json`.
Candidate review with current-source proof hashes:
`docs/verification/data/thermo5-r13/thermo5_tx_r13_final_waiver_reproof_review.csv`.
The initial Round 13 snapshot below has been superseded where it described the
tool environment and current run status; it remains as historical context.

## Superseded execution snapshot: Thermo5 TX Final Coverage Closure Round 13 (2026-11-07)

## Previous execution state: Thermo5 TX Linux DV closure Round 12 (2026-11-06)

Latest integrated `thermo5` base is `73577475230a9c4e51273ac7071437f0a7373d48`;
the tested closure branch is `codex/thermo5-linux-dv-signoff-closure` at
`a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0`, three verification-only commits
ahead. All 21 product RTL hashes match the integrated base. Product profile:
Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit, DPD_MAX_TAPS=1 with
Identity reset image, AXI-Lite, Generic FIFO. The 97-input compile manifest
fingerprint is `9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a`.

Gate 1 Functional criteria PASS at this product SHA: 230 legal product tests
plus two separate expected-negative tests pass; Python reference tests are
64/64; legally applicable Functional Coverage is 436/436 across 16/16 groups;
the seven named system crosses pass; all 232 expected queues drain; and direct
SV Unified Scoreboard mutation detection passes 6/6. Legal assertion
regression has zero failures, with two `q1_tail` properties still uncovered
and without attempts.

Fresh same-input Raw/Adjusted URG: Branch 524/637, Condition 657/849, Line
3338/3796, Toggle 91288/104480, FSM states 13/13 and transitions 22/22.
Adjusted equals Raw because there are zero approved waivers and zero active
Exclusions. There are 13,955 open code-bin records grouped into 415 OPEN
root-cause tasks; the inherited plan says 416, so the task-ledger discrepancy
remains explicit. The fail-closed gate is `RAW_100_OPEN`.

Separate Round 12 What-if analysis (not official coverage/signoff) used the
same one Design VDB + 232 Test VDBs and a strict analysis-only `.el` containing
361 exact candidate bins (normalized SHA-256
`9a4c29b2ec8ac8392057621a0d65f43fdd9a40abdda9140623e9a94702ee7fbb`). The final
Raw/Adjusted inventories were rerun and matched. URG reports show Branch 524/536,
Condition 657/741, Line 3338/3644, Toggle 91288/104480, FSM states 13/13 and
transitions 22/22. The remaining exact OPEN set is 13,594 bins: Branch 12,
Condition 84, Line 306, Toggle 13,192. GitHub has 371 waiver rows versus 369
local; the two remote-only rows are current Raw HITs, not missing candidates.
No official waiver status or exclusion changed. Full report:
`docs/verification/thermo5-tx-round12-waiver-what-if-20261106.md`.

Waiver audit: two old candidates are archived as Raw hits; 369 remain PENDING
(361 configuration candidates, four Formal candidates, four stale-context
unresolved), 0 approved, 0 rejected. The generated `.el` has no active
directives. No independent Reviewer approval is recorded.

Formal: product AXI-Lite outstanding saturation/underflow run is
INCONCLUSIVE (all five assertions and both guard Covers unresolved at effort
limit). The separate DPD counter budget proof passes in its scoped harness.
DPD Identity arithmetic/output-under-stall proof passes in its scoped leaf
harness, but excludes config mailbox/CDC/full TX chain. COMMIT → Pending →
Apply → ACK → DONE and full-chain DPD Identity remain OPEN. Do not infer FPGA
or physical signoff: real XPM/GT Wizard, integrated CDC/RDC, Vivado PPA/timing,
board/RF and physical QAM256 were not run.

Full report and machine evidence:
`docs/verification/thermo5-tx-linux-final-closure-round12-20261106.md` and
`docs/verification/data/thermo5-r12/`. VDBs and tool logs are under ignored
`runs/thermo5_linux_dv_signoff_gate1/source_a03c2/`.

Next: review the 361 What-if candidates and the 13,594-bin root-cause ledger;
start with the 12 remaining Branch bins, then targeted Conditions and Lines.
Audit the 8,312 fixed-configuration Toggle candidates before proposing any
exact exclusions; keep the high-counter and 130 CDC residual Toggle bins
open pending stimulus or reachability evidence. Reconcile the 415/416 task
count, obtain independent exact-bin waiver approval, and split the outstanding
counter proof into product-bound lemmas without strengthening legal stimulus
assumptions. Keep full-chain Commit/DPD and the two `q1_tail` attempts open.

## Previous execution state: Thermo5 Branch Consolidation (2026-11-06)

`thermo5` now contains PR #40 and #41. PR #40 merged as
`f8b14df743eeb6facfd0378b402f1670a6cf9b0f`; PR #41 merged as
`8fddad5ba59814d9a0b95a9d94b88e7036efc16f` (tree
`76b082af1c94a1082f3c68cc64fa42c1b63c6838`). PRs #27–#39 were commented as
superseded by the integrated snapshots and closed. Their remote branch refs
remain intact and recoverable; the available GitHub connector has no branch
ref deletion operation.

The branch/patch audit and final post-merge record are in
`docs/verification/thermo5-branch-consolidation-audit-20261106.md`,
`docs/verification/thermo5-branch-consolidation-postmerge-20261106.md`, and
their adjacent JSON manifests. All 404 paths touched by PR #27–#39 are present
in the final tree; 278 blobs match exactly and 303/404 reverse-patch checks
pass. The remaining 101 files evolved and are not mechanically proven by the
original patches; their refs remain recoverable. Parallel PR #36/#37 Formal
changes were reviewed with their inconclusive/scoped limits preserved. The
independent dirty Formal worktree and stash are unchanged.

The requested post-merge Linux matrix passed from the exact product source
SHA: Generic FIFO and AXI-Lite VCS, System Random 110/110, DPD/Gain/Profile
60/60, randomized Reset 24/24 and COMMIT 24/24, and Python 64/64. All 96
compile-input file hashes and all 21 product RTL hashes match the final
merged source; the compile fingerprint is
`08e62a87420ee9a9acce7724d2cca3c909f8cb7265dac22563522ac97a74b300`.

The retained same-manifest Raw/Adjusted URG remains valid for this unchanged
source fingerprint: Branch 524/637, Condition 657/849, Line 3338/3796,
Toggle 91112/104480, FSM states 13/13 and transitions 18/22. Legal applicable
Functional Coverage is 436/436 and all seven named system crosses remain
closed. Waivers remain 371 pending, 0 approved, 0 active exclusions; the gate
is still `RAW_100_OPEN`. Counter Formal remains INCONCLUSIVE; scoped
frame-tail/DPD evidence does not close full-chain proof. Direct SV scoreboard
mutation, real XPM/GT Wizard, Vivado PPA/timing, and physical RF/QAM256 remain
open or not run. No RTL or frozen algorithm changed during consolidation.

No force push or remote branch deletion was performed. The five independent
long-lived/history branches remain preserved: `main`, `thermo5`, `thermo3`,
`dsm`, and `dv-de-portfolio-20261006`.

## Previous execution snapshot: TX Final Verification Convergence Round 11 (2026-11-06)

Working branch `codex/thermo5-final-verification-round11`; local simulation source commit `d823654cba715e9093bb8cc08e6d819e8ae1365f`; the published code commit
`cd9532a7d805f2f60250f2ef687a15711a9c485e` has the identical source tree `244b49c4daf1561806d7f02d6dfb560227757571` and is directly stacked
on PR #40 HEAD `330815a5db5a26af50de81aff0c304dea714ead3`. PR #40 remains
Draft/Open and unmerged. Its 266 changed paths include all 255 unique paths
from PRs #27–#39. Product RTL, frozen TX algorithm, RX, and AI-DPD are unchanged.

Product profile: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state;
DPD_MAX_TAPS=1 with Identity reset image; AXI-Lite; Generic FIFO. VCS
V-2023.12-SP1_Full64, URG V-2023.12-SP1, VC Formal V-2023.12-SP2_Full64,
Python 3.12.13. The 96-file compile-input fingerprint is
`08e62a87420ee9a9acce7724d2cca3c909f8cb7265dac22563522ac97a74b300`; all
listed compile files and all 21 Product RTL files match the current source.

Status:

- **Source and regression baseline: PASS for the stated package.** Fresh Generic
  FIFO and AXI-Lite product VCS suites passed. System Random passed 110/110;
  DPD/Gain/Profile 60/60; randomized Reset/COMMIT 24/24 each; Python tests
  64/64. The previous 195-path/193-test discrepancy is resolved: two inputs
  were design VDBs, not test VDBs. Current coverage uses 449 test VDBs plus one
  fresh design VDB. 231 retained test VDBs match the current compile-input
  fingerprint; 218 test VDBs are from fresh current-source campaigns.
- **Named Functional Coverage crosses: PASS.** All seven crosses are closed at
  60/60, 2/2, 4/4, 1/1, 1/1, 1/1 and 1/1. Source-gap/PA-stall/FIFO-full and
  RUN/prefill/source-gap use `(Epoch, Packet ID)` state. STOP/TLAST/Drain
  requires strict STOP < accepted TLAST < Drain. Cross-packet and TLAST-before-
  STOP negative checks passed. Legal applicable bins are 436/436; 16/16 groups
  report 100%.
- **Unified Scoreboard: PARTIAL.** Source/CDC metadata and indexing, all 32 EF2
  lanes, configuration event causality, Reset Epoch clearing, and drain checks
  are implemented/exercised. Offline Python mutation tests pass for missing,
  duplicate, reordered, wrong-Frame-ID and early-Apply traces. Direct SV
  Unified Scoreboard mutation injection remains OPEN.
- **DUT Code Coverage: OPEN.** Same-manifest Raw and Adjusted are identical:
  Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 91112/104480,
  FSM states 13/13 and transitions 18/22. 14,135 records remain OPEN across
  416 root-cause tasks. Waivers: 371 PENDING, 0 APPROVED, 0 rejected, 0 active
  exclusions. Gate remains `RAW_100_OPEN`.
- **Assertions/Formal: OPEN.** Legal-only URG: 13 successes, zero failures, two
  uncovered and two without attempts. Both no-attempt properties are the
  centered interpolator `q1_tail` assertion at line 310. Expected-negative
  URG separately records three checker-confirmed RTL assertion failures.
  Focused AXI-Lite cfg Formal passes 4/4 assertions with zero assumptions and
  black boxes; outstanding-counter assertions/target Covers remain
  INCONCLUSIVE. Scoped `q1_tail` and DPD Identity evidence does not close Raw
  bins or prove the full chain. No INCONCLUSIVE result is waived.
- **Outside Linux / NOT_RUN:** real XPM and GT Wizard simulation, Vivado routed
  timing/PPA/power, physical RF and QAM256 BER.

Round 11 report and machine-readable source, VDB, coverage, Formal, assertion,
waiver, and log-hash evidence:
`docs/verification/thermo5-tx-final-verification-round11-20261106.md` and
`docs/verification/data/thermo5-r11/thermo5-tx-final-verification-round11-20261106.json`.
Raw logs, VDBs, and full URG trees remain under ignored `runs/`.

PR #41 is open as a Draft stacked on PR #40 and is mergeable; it has not been
merged. Next, review direct SV scoreboard mutation checks, reachable code-bin
closure, counter guard Formal, full-chain DPD Identity Formal, and independent
review of any exact waiver candidate. Do not call this a final Linux, FPGA, or
physical signoff.

## Previous execution snapshot: TX final integration and staged Oracle (2026-11-04)

Working branch `codex/thermo5-final-integration` now has implementation commit
`7e1ab1930921be1b293d8c59323611ef0b3f9359`, based on integrated branch head
`d2b5a1217707514d6d48047ff66f25f7c651000a`. The local cumulative branch
contains the recent UVM event-bus/unified-scoreboard and Formal/waiver changes.
It is not merged into or pushed to `thermo5`.

The independent Python monitor-trace Oracle now checks accepted CDC samples
against source AXIS transactions, reconstructs the 32-lane EF2 input from
source/frame configuration and checks it, then checks four-plane PA output.
It does not use DUT internal DSP values to build expected data. On the retained
product-profile traces, 228/228 replays passed: 13,328 CDC words, 13,328 EF2
words and 13,328 PA words matched; zero unexpected underflows. Python tests
passed 61/61. Fresh VCS V-2023.12-SP1 Generic-FIFO core and AXI-Lite product
regressions passed at this source SHA; exact commands and log hashes are in
`thermo5-tx-final-integration-20261104.md` and its JSON evidence.

Roadmap status:

- **P0 PASS locally:** one reproducible integration SHA and fresh product
  regressions. Upstream branch integration is not performed.
- **P1 PARTIAL:** UVM has a transaction event bus, epoch/index-aware
  scoreboard and CDC source checker; the independent Python replay now checks
  CDC, EF2 and PA stages. EF2 numeric prediction is offline rather than in a
  live UVM expected queue, so the requested unified online stage checker is
  still open.
- **P2 PARTIAL:** the 110-seed system suite and separate DPD, COMMIT and reset
  campaigns pass, but do not form a complete Cartesian system-cross matrix.
  DPD is Identity in the 110-seed baseline, and the long-frame STOP plus PA
  stall pairing remains an unresolved testbench deadlock.
- **P3 OPEN:** Raw/Adjusted DUT coverage is 524/637 Branch, 657/849 Condition,
  3338/3796 Line and 91112/104480 Toggle; no waivers are approved and the
  gate remains `RAW_100_OPEN`. Two legal `q1_tail` DUT assertions remain
  unattempted. Outstanding-counter and full-chain DPD Identity Formal remain
  inconclusive/open. The current Raw URG functional audit passes 412/412
  legal-product rows (206 distinct bins, 13 groups); the new system cross
  matrix is still partial. No real XPM, GT Wizard, FPGA timing/PPA or physical
  RF signoff was run.

The detailed snapshot records Raw and Adjusted as identical, 371 pending waiver
candidates, exact assertion separation, Formal scope, mutation outcomes, and
all remaining boundaries. Do not describe this as complete FPGA or TX
signoff. Next: close the online EF2 expected queue and unresolved legal
scenario pairing, then continue exact-bin coverage/Formal/waiver review. The
source-level status and evidence index are in
`docs/verification/thermo5-tx-final-integration-20261104.md`.

## Previous execution state: TX UVM observation event bus (2026-11-04)

Started from PR #38 head `184c68b6d704998f5126a75a8f86d7577bb69a1a` on the
independent branch `codex/thermo5-tx-platform-observation`. Implementation
commit `8a70597245a7ff18fd7eabb1bda714d0974be4f5` adds passive CDC, DSP, and
EF2-input observers and a typed UVM event bus carrying accepted AXIS, AXI-Lite,
PA, and internal observation events to Functional Coverage and JSONL Trace.
The Control Agent is now referenced by the Virtual Sequencer. No product RTL,
default algorithm, RX, AI-DPD, or FPGA implementation changed.

VCS V-2023.12-SP1 product-config compile and the AXI-Lite random-packet test
passed at seed 491802: UVM errors/fatals 0, source/CDC/EF2/PA counts
32/56/56/56, Register Predictor mismatches 0. The JSONL Trace replay passed
56/56 PA words with zero underflow; the Python suite passed 60/60. Evidence:
`thermo5-tx-observation-bus-round1-20261104.md` and its JSON manifest.
The non-AXI bit-true test also passed at seed 491803 with 56/56 PA words
matched by the existing static scoreboard and matching event-bus counts.

This is a partial platform milestone. The online dynamic expected queue and
stage-by-stage independent checks are still open. The existing PA Scoreboard
still checks the static bit-true vectors; the Python model remains offline.
Legacy configuration/status Trace sampling is not yet fully routed through
the event bus. The one-test event-kind coverage is not a product coverage
signoff. Continue with a transaction/epoch manager and independent expected
queue before expanding scenario Cross Coverage.

## Previous execution state: Thermo5 TX Linux coverage/formal closure (2026-11-03)

The product remains frozen at RTL source SHA
1236d49c72360aa62e316aea147528d93a1b3705: Centered-Cubic x2+x2, EF2
ORDER=2/STEP=5120/20-bit state, DPD_MAX_TAPS=1 with Identity reset image,
AXI-Lite and Generic FIFO. No RX, AI-DPD, product RTL/algorithm or Vivado
physical implementation work is in scope.

The two focused Condition Formal dispositions are published as Draft PR #33,
`codex/thermo5-tx-focused-condition-formal-closure`, stacked on PR #32 head
`96ac24b622a1d21b344de79e4d19adc555ee6a92`. PR #33 remains unmerged.

The scoped 16-lane DPD vector output stall-hold proof (33/33 assertions, 17
non-vacuous, 3/3 Covers) is the subject of Draft PR #34,
`codex/thermo5-tx-dpd-payload-hold-formal`, stacked on PR #33 and not merged.

Draft PR #36 is a separate outstanding-counter follow-up stacked on PR #35.
Its product-bound outstanding-counter
properties and exact saturation/underflow guard Covers remain INCONCLUSIVE;
the two Raw Branch records remain OPEN and are not waived.

Draft PR #38, `codex/thermo5-tx-cdc-data-empty-formal`, is stacked on PR #37
and not merged. On
clean code SHA `dffcd94f95ed6dd455dd892b49391e102594cb4b`, VC Formal proved the
exact `0/1/1/1/1` Condition tuple at
`dsm_axis14_to_core8_cdc.sv:113` unreachable because the production Generic
FIFO defines `rd_valid = !rd_empty`. Source acceptance, nonempty FIFO data and
`core_data_empty` Covers were reached; the exact tuple Cover was uncoverable.
The Raw bin remains visible and unhit; no URG or denominator change was made.
No waiver is approved and no exclusion is active. Report and hashes are in
`thermo5-tx-cdc-data-empty-formal-20261103.md` and its JSON evidence.

Draft PR #37, `codex/thermo5-tx-frame-tail-condition-formal`, is stacked on
PR #35 and not merged. On clean verification-source SHA
`2715b7a99042b3cd261884e53a82f287fe243ec6`, VC Formal V-2023.12-SP2 passed a
composed two-stage centered-cubic metadata proof and a separate runtime-reset
proof. The two exact reset-low line-309 Condition Covers are uncoverable with
non-vacuous reset-empty assertions and queue-full/runtime-reset witnesses. The
stage-2 active line-309 Condition Cover is uncoverable in the composed
interpolator chain under the 56-sample DSP-frame / 448-sample packet contract,
with non-vacuous frame-start, packet-end, tail and output Covers. The composed
proof omits the intervening elastic FIFOs and DPD pipeline, so all three Raw
rows remain present and OPEN pending independent waiver review; no `.el`, Raw
or Adjusted change was made. Exact mapping, commands and hashes are in
`thermo5-tx-frame-tail-condition-formal-20261103.md` and its JSON evidence.
It proves the vector leaf protocol only; full-chain DPD Identity remains OPEN.

A follow-up branch `codex/thermo5-tx-dpd-identity-stall-formal` is stacked on
PR #34 and is being published as a separate Draft PR. On clean Formal-input
commit `e21c1ece205b633809e1dfd84d275936294b6378`, a composed production
`dpd_memory_poly` proof verifies the one-tap Q14 Identity datapath under
arbitrary output stalls: 41/41 internal base lemmas and 4/4 final output,
latency, and saturation assertions prove; 4/4 endpoint/stall/recovery Covers
are reached. The single legal source payload-hold assumption is non-vacuous;
there are zero black boxes and zero selected setup violations. This remains a
DPD leaf proof: AXI shadow/COMMIT, mailbox, CDC, pending/active epoch, and full
TX composition remain OPEN. Full detail and hashes are in
`thermo5-tx-dpd-identity-stall-formal-20261103.md` and its JSON evidence.

### Current Raw/Adjusted coverage

The latest same-list Raw/Adjusted URG report uses one design VDB and 247 unique
test VDB trees: 243 legal positive, two expected negative, and two additional
legal directed cases. It is retained mixed-provenance evidence, not 247 fresh
runs from one verification-source SHA. The prior STATUS-mismatched 16-point
gap sweep is excluded. Raw equals Adjusted: approved waivers=0 and active
Exclusions=0. Results are Branch 525/637, Condition 658/849, Line 3351/3796,
Toggle 84340/104480, FSM states 13/13, transitions 17/22, and legal applicable
functional bins 392/392. The gate remains RAW_100_OPEN. The 20,893-record
open-bin snapshot has two subsequent exact reachability dispositions; 20,891
other code records remain OPEN. Raw/Adjusted hits and denominators are
unchanged, and no code-coverage delta was gained over the 246-test checkpoint.

### Assertion closure update

A separate legal-positive assertion URG report over 243 positive VDBs has 13
DUT successes and zero failures. Two DUT properties have no legal attempts:
assert(q1_tail) at rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310,
one for each Centered-Cubic stage. A separate corrected illegal-frame test
(seed 420102) observed the CDC frame-alignment assertion once and each stage's
frame-tail assertion once, then checked sticky protocol-error recovery by
public reset. UVM warnings/errors/fatals were zero. The fail-closed checker
tools/hw/check_thermo5_axil_illegal_frame.py verifies exact instances/counts
and rejects unexpected RTL assertion failures; its four mutation-focused unit
tests pass. Legal and expected-negative assertion outcomes remain separate.

### Formal and waivers

The local one-tap Identity DPD leaf proof passed 5/5 assertions and 3/3 Covers,
with zero black boxes and no environment assumptions. It fixes the Q14 unity
coefficient image and ties out_ready high; it does not cover stalls or AXI
commit/epoch control. Full-chain DPD Identity remains INCONCLUSIVE/OPEN. The
continuous-source outstanding-counter proofs and exact guard Covers remain
INCONCLUSIVE. A final extended product-bound run used a 22-minute global limit
and completed in 1,364.76 seconds: saturation/underflow assertions were
INCONCLUSIVE at depths 231/122, and the exact guard Covers at depths 196/126.
The proof used zero assumptions and zero black boxes; the source/core/output
activity Covers were reached. The two Raw Branches remain OPEN. All 371 waiver
candidates remain PENDING, with zero approvals and no active `.el`
Exclusions.

The waiver inventory was rebound in Review Round 7 after the focused Formal
Review JSON was updated. The audit uses the 247-test Raw ledger and current
compile/VDB manifests; 371 candidates remain pending (361 configuration and
10 Formal candidates), with zero approvals and zero active `.el` directives.
See `docs/verification/thermo5-tx-waiver-review-round7.md`.

Two earlier exact Raw Condition roots are `PROVEN_UNREACHABLE` by focused
VC Formal runs against the same 247-test Raw report. At
`dpd_vector16_memory_poly.sv:93`, the DPD ready/valid tuple `0/1` has a proven
non-vacuous `!out_valid -> in_ready` assertion and reached input/output/stall
activity Covers; the exact bad-tuple Cover is uncoverable. At
`thermo5_dpd_axi_lite_cfg.sv:93`, the `write_fire` tuple `0/1/1` has a proven
non-vacuous BVALID exclusion assertion and reached normal write/response
Covers; its exact tuple Cover is uncoverable. Both Raw bins remain unhit and
retained, with zero waivers and no `.el` exclusions. The former monolithic DPD full-output hold proof was INCONCLUSIVE at depth 15
and a later aggregate attempt at depth 294. A scoped vector-leaf proof now
splits the 512-bit payload into 16 lane properties and proves all lane payload
holds, metadata hold and lane-valid lockstep (33/33 assertions; 17 payload/
metadata assertions non-vacuous; 3/3 Covers; no assumptions or black boxes).
This closes the vector leaf's stall-hold protocol only; full-chain DPD Identity
arithmetic and COMMIT/CDC/epoch behavior remain OPEN. Raw URG remains unchanged.
See `thermo5-tx-dpd-payload-hold-formal-20261103.md` and its evidence JSON.

A separate composed one-tap Identity DPD leaf proof now closes local arithmetic,
sample alignment, output latency, and no-saturation under arbitrary output
stalls. It proves 41 internal lemmas in the base run, then keeps the four final
output/saturation goals active; all four prove and all four endpoint/stall/
recovery Covers hit. The legal source payload-hold assumption is non-vacuous;
zero black boxes and zero selected setup violations. The AXI shadow/COMMIT,
mailbox, CDC, pending/active epoch, and full TX proof remain OPEN. See
`thermo5-tx-dpd-identity-stall-formal-20261103.md` and its evidence JSON.

A further 311.08-second VC Formal run on branch `codex/thermo5-tx-outstanding-capacity-formal` added arbitrary legal AXIS source bubbles and a candidate 29-slot pipeline bound. The generated-array EF2 hierarchical reference that previously caused a false counterexample was removed after VC Formal trace checking identified it as UNDRIVEN. The corrected full run has zero setup issues and zero black boxes; the legal source-hold assumption is non-vacuous and arbitrary source-bubble Cover reaches depth 4. However, all five assertions remain INCONCLUSIVE at depths 34-46, and both exact guard Covers remain INCONCLUSIVE at depths 34/38. The candidate slot constant is not proof evidence. Both exact Raw Branches stay OPEN; Raw URG is unchanged, all waivers remain pending, and there is no coverage delta. Evidence is indexed in `docs/verification/thermo5-tx-outstanding-capacity-formal-followup-20261103.md` and its adjacent JSON.

### Checks, evidence, and next action

Checks: targeted illegal-frame VCS test PASS with exact expected failures;
the integrated AXI-Lite negative Make target and independent log checker PASS;
hardware utility tests 42/42 PASS; Formal Identity no-stall leaf proof PASS
within scope; composed DPD Identity under-stall leaf proof PASS within scope;
focused DPD ready/valid and AXI-Lite write-fire exact-bin Formal
dispositions PASS;
same-list Raw/Adjusted URG and gate PASS (RAW_100_OPEN); extended
counter Formal completed INCONCLUSIVE; `py_compile`, JSON validation, and
`git diff --check` PASS. Full UVM regression was not rerun.
Exact logs, VDBs and tool reports remain under ignored runs/; compact hashes
and commands are in the
assertion/DPD follow-up document and current Linux system signoff evidence JSON.
The extended outstanding Formal property matrix and tool/log hashes are indexed
in `docs/verification/thermo5-tx-outstanding-formal-extended-20261103.md` and
its adjacent JSON evidence file.

Do not spend more random seeds on the unchanged coverage gaps. Next, review the
three line-309 Condition records against the exact product metadata pass-through
through both elastic FIFOs and the DPD pipeline; keep the Raw rows OPEN and all
waivers pending until that review is recorded. Then select the next exact
Reset/State-Hold root by source position. Continue to treat the outstanding
counter as INCONCLUSIVE, with both guard goals OPEN and no source-gap or
PA-stall bound. The line-93 DPD condition root is formally dispositioned; its
Raw miss remains visible. Real XPM, GT Wizard, FPGA PPA/routed timing and
physical RF/QAM256 remain outside Linux signoff. Do not merge PRs or modify
the frozen TX algorithm.

## Previous execution state: TX branch consolidation and cleanup (2026-11-02)

## Previous execution state: Thermo5 TX branch consolidation and cleanup (2026-11-02)

TX Coverage Closure Round 1 (PR #24) and System UVM Phase 0–2 (PR #25) have
both been merged into `thermo5`. PR #24 merged at
`b42986ee31a8af5dc76cf6263454838ec23ba1b6`; PR #25 merged at
`50d4455a98c18f230ffe83f4263e9b92e652e440`. PR #25's correction commit
`7345a62340af7c97e1dadbae7f3af903fc26f836` fixed the CI indentation error;
the Python reference suite passed 51/51, and the GitHub digital-verification
and repository-hygiene workflows passed.

System UVM Phase 0–2 remains **PARTIAL**. Open items include timed source-gap
behavior, reset inside a partially assembled DSP frame, Python STOP/Drain
state assertions, an independent core STATUS predictor, constrained-random
stimulus/seed replay, and Formal/Mutation checks. No DUT code coverage or
final system signoff is claimed. See the PR #25 evidence index and report.

**Workspace cleanup:** `make -C dv/uvm/sim clean` removes generated VCS/URG
VDBs, VC Formal learn/runtime directories, simulator compilation caches,
Verdi/VC Formal scratch files, and waveform dumps. It retains logs, vectors,
manifests, and reports under `runs/` for auditability. VDBs must be
regenerated with VCS before another URG merge. `.gitignore` covers recurring
tool outputs. The cleanup command and post-clean scan passed locally.

**Next:** close the listed Phase 2 verification gaps in a new reviewable
change; keep future coverage/signoff claims tied to exact source and tool
evidence.

## Previous execution state: TX System UVM Phase 0–2 (2026-11-02)

Earlier frontier snapshots and Round 1 history follow.
## Previous execution state: TX coverage closure Round 1 (2026-11-01)

Round 1 is **PARTIAL / RAW_100_OPEN** on baseline `88c9682501fd60bb14e6ea9b1f569f8eeb97e708`. Product source SHA remains `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`: Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120/20-bit state, DPD_MAX_TAPS=1 Identity DPD, Generic FIFO, AXI-Lite TX.

Current Raw and Adjusted URG used the same design VDB plus 27 test VDBs; zero exclusions are active, so Adjusted equals Raw. Coverage: Branch 525/637, Condition 610/849, Line 3351/3796, Toggle 84343/104480; FSM states 13/13, transitions 22/22; legal applicable Functional Coverage 210/210. Tracked VDB/report manifests, Raw/Adjusted summaries and gate output are under `docs/verification/data/thermo5-tx-round1-*`; the VDB payload and full tool logs remain local under `runs/thermo5_coverage_closure_round1/` and are SHA-indexed in the closure report.

The mailbox stability branch at `thermo5_dpd_axi_lite_cfg.sv:364` is hit only by a separate expected-negative fault test. It is under `ifndef SYNTHESIS`, not synthesized product logic. The outstanding saturation/underflow guard branches at `tid32_thermo5_axi_lite_axis_frontend_tx.sv:203-204` remain OPEN: legal traffic peaked at 28 outstanding; existing VC Formal assertion/cover results are INCONCLUSIVE. The legal 112-word stress test is bit-true and records 112 core accepts and 112 output accepts.

A current-Raw-URG join lists all 131 exact OPEN condition bins in 71 task groups: 127 Reset Release/State Hold and 4 Interpolator Empty/Blocked. Every joined bin remains Not Covered; Condition is unchanged at 610/849. No broad seed sweep is planned without a new exact-bin stimulus hypothesis.

The waiver pipeline is fail-closed. There are 371 PENDING candidates, zero approved/rejected, and no active `.el` Exclusions. Legal-only assertions have 13 DUT successes, zero failures, two uncovered and two without-attempt records; the latter identify the two stages of the malformed frame-end defense. Expected negative assertions are reported separately. Raw union assertions include two expected negative DUT assertion failures and must not be called a legal Assertion PASS.

**Checks:** hardware utility tests 31/31 PASS; Python `compileall` PASS; exact condition audit 71/131 PASS; existing VCS V-2023.12-SP1 compile and legal/negative runs are recorded with hashes. A new compile attempt on 2026-11-01 could not obtain a VCS license and was not counted as PASS. No new uncompiled counter-guard test was retained.

**Next:** when a VCS/VC Formal license is available, finish the two outstanding counter guard roots with either a real exact legal witness or a separate fault-injection Negative Regression plus independent checker, and do not treat it as legal coverage. Then create new exact-condition stimulus hypotheses and refresh the VDB manifests. Keep Line/Toggle specialization for a later round; RX, AI-DPD and Vivado remain out of scope.

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
    `p9_client_rpc` while reading the 2.5 GB vector set from `an external mounted drive`; it was
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
