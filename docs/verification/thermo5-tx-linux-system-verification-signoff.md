# Thermo5 TX Linux System Verification Closure

Date: 2026-11-03 (Asia/Singapore)  
VCS execution branch: `codex/thermo5-tx-system-random`
Waiver audit branch: `codex/thermo5-tx-waiver-audit-round1` (Draft PR #31, stacked on PR #30)
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`
Coverage audit utility fix: `52892f66b4fc80ac41557272a1434ac216ddd073`
Current Formal increments: Draft PR #33, `codex/thermo5-tx-focused-condition-formal-closure`; scoped DPD output-hold Draft PR #34, `codex/thermo5-tx-dpd-payload-hold-formal`; and the one-tap Identity under-stall follow-up on `codex/thermo5-tx-dpd-identity-stall-formal`, stacked on PR #34. None is merged.
Product: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state,
four 64-bit PA planes, `DPD_MAX_TAPS=1`, Identity reset image, AXI-Lite,
Generic FIFO.

## Signoff status

**Linux TX functional coverage is closed for the declared legal product bins;
DUT code coverage and Formal closure remain open.** The fail-closed gate result
is `RAW_100_OPEN`. Raw and Adjusted code coverage are identical because there
are no approved waivers and no active URG exclusions. This is not a complete
TX, FPGA, or physical signoff.

**Gate 1 waiver-candidate audit update (2026-11-03):** Round 7 rebinds all 371
review candidates after the current Formal Review JSON changed. It uses the
current product compile manifest, exact 247-test VDB inventory, and latest
source-linked Raw gap ledger. It classifies 361 as
`CONFIG_UNREACHABLE` candidates and 10 as `FORMAL_UNREACHABLE` candidates.
These are review dispositions, not approvals. All 371 remain `PENDING`; zero
are approved and no `.el` exclusions are active. See
[`waiver review round 7`](thermo5-tx-waiver-review-round7.md) and its
machine-readable audit package.

**Current Linux closure refresh (2026-11-03):** The 11-cycle interframe-gap VCS
run hit the centered-cubic pop/push Branch in both stages; the independent
four-plane checker passed 112/112 words with zero underflow, STATUS mismatch,
protocol error, or UVM error. A subsequent 2,072-word / 37-packet legal
outstanding-counter stress run passed the independent PA checker and raised
Toggle coverage by 160 hits, but did not hit either outstanding-counter guard
Branch. The latest same-list Raw/Adjusted URG report uses 247 unique test VDBs
plus one design VDB and reports Branch 525/637,
Condition 658/849, Line 3351/3796, Toggle 84340/104480, FSM 13/13 states and
17/22 transitions; legal applicable functional coverage is 392/392. The open
ledger at that refresh contained 20,893 records in 457 groups. A later focused
Formal addendum below reclassifies two exact condition roots; their Raw bins
stay unhit. Raw equals
Adjusted because there are no approved waivers and no active exclusions. The
gate remains `RAW_100_OPEN`. See the
[`interframe source-gap evidence`](thermo5-tx-interframe-stop-gap-20261103.md),
[`outstanding-counter stress evidence`](thermo5-tx-outstanding-counter-stress-20261103.md),
and [`waiver review round 3`](thermo5-tx-waiver-review-round3.md).

## Focused Formal Condition closure — DPD ready/valid and AXI-Lite write fire

The exact Raw Condition bin `TXB-33613a1855fcc02e8ef4` at
`rtl/dpd/dpd_vector16_memory_poly.sv:93` remains Not Covered in the latest
247-test same-list URG report (`0/1` operands). A focused VC Formal run on the
same 16-lane, 16-bit, one-tap implementation proved `!out_valid -> in_ready`
non-vacuously, reached legal input acceptance, output transfer, output stall
and stall-release Covers, and found the exact `!in_ready && !out_valid` Cover
uncoverable. There were no environment assumptions, black boxes, or selected
setup violations. This resolves one root cause as `PROVEN_UNREACHABLE`; it does
not create a coverage hit or remove the bin from Raw.

The second exact bin, `TXB-872eb98e51c3229e4c86` (`13d6754bf69d80bac0ac`), is at
`rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:93`, operands `0/1/1`. In the
same 247-test Raw URG report this tuple is Not Covered. VC Formal proved the
non-vacuous BVALID exclusion assertion, reached normal `write_fire` and
response-active Covers, and found the exact `0/1/1` tuple Cover uncoverable.
The proof used no environment assumptions, had zero black boxes, and no
selected setup violations. This exact root is also `PROVEN_UNREACHABLE`; the
Raw bin remains unhit and retained.

The earlier monolithic DPD full-output hold property was INCONCLUSIVE at depth
15; a later 512-bit aggregate attempt also remained INCONCLUSIVE at depth 294.
A source-bound lane-decomposed proof now proves the equivalent 16-lane vector
leaf hold contract: 33/33 assertions, including all 16 I/Q lane payload holds,
metadata hold and lane-valid lockstep; all 17 payload/metadata properties are
non-vacuous and all 3 Covers are reached. The vector leaf uses MAX_TAPS=1 and
unconstrained runtime coefficients, active tap count, payload, metadata and
ready/valid inputs, with no environment assumptions and zero black boxes. This
closes output payload/control stability for the DPD vector leaf. A later
composed proof also proves the local one-tap Identity DPD output, 11-cycle
alignment, and no-saturation contract under arbitrary output stalls; see the
dedicated report below. AXI COMMIT/CDC/epoch composition remains OPEN. Raw
Condition remains 658/849, Raw equals Adjusted, approved waivers and active
`.el` exclusions are both
zero, and the gate remains `RAW_100_OPEN`. Of the 20,893 records in the prior
open-bin snapshot, two exact Condition roots are `PROVEN_UNREACHABLE`; all
other records remain OPEN. Full proof scope, hashes and reproduction commands
are in the [DPD vector payload-hold Formal report](thermo5-tx-dpd-payload-hold-formal-20261103.md)
and [machine-readable evidence](data/thermo5-tx-dpd-payload-hold-formal-20261103.json).
The two exact Condition dispositions are detailed in the [DPD ready/valid Formal evidence](thermo5-tx-dpd-ready-condition-closure-20261103.md)
and [machine-readable audit](data/thermo5-tx-dpd-ready-condition-formal-20261103.json),
and the [AXI-Lite line-93 Formal evidence](thermo5-tx-axil-line93-condition-closure-20261103.md)
and [machine-readable audit](data/thermo5-tx-axil-line93-condition-formal-20261103.json).

## One-tap Identity DPD under-stall Formal closure

A fresh, source-clean VC Formal V-2023.12-SP2 run on commit
`e21c1ece205b633809e1dfd84d275936294b6378` proves all 41 internal arithmetic,
coefficient, valid-alignment, and sample-order lemmas in the base model. It then
uses only those individually proven lemmas as compositional assumptions; four
end goals remain active and prove: I/Q output equals the 11-cycle reference,
neither output saturates while valid, and the saturation counter stays zero.
The endpoint, stall, and stall-recovery Covers are all reached. The single
environment assumption is the source contract to hold valid/data while
blocked. VC Formal reports zero black boxes and zero selected setup issues.

This closes local one-tap Identity arithmetic and output latency under
backpressure, not AXI Shadow/COMMIT, mailbox, CDC, pending/active epoch, or the
full TX chain. Those system subproblems and overall TX signoff remain OPEN.
Formal does not create URG hits: Raw/Adjusted metrics and waiver counts are
unchanged, with `RAW_100_OPEN`. See the
[scoped Formal report](thermo5-tx-dpd-identity-stall-formal-20261103.md) and
its [machine-readable evidence](data/thermo5-tx-dpd-identity-stall-formal-20261103.json).

The extended product-bound counter Formal run used the 22-minute global
effort limit and completed after 1,364.76 seconds. Both guard assertions and
both exact guard Covers remained INCONCLUSIVE (assertion depths 231/122; Cover
depths 196/126). Source/core/output activity Covers were reached, with zero
environment assumptions, zero black boxes, and two non-vacuous assertions.
The Raw Branches remain OPEN. See the
[`extended counter Formal report`](thermo5-tx-outstanding-formal-extended-20261103.md)
and its hash-bound machine-readable evidence.

A follow-up source-bubble/capacity experiment completed in 311.08 seconds. It
removed an undriven generated-array hierarchy reference from the candidate
slot expression and retained arbitrary source bubbles and PA stalls. Four
activity/bubble Covers hit, setup issues and black boxes are zero, but the five
assertions and both exact guard Covers are still INCONCLUSIVE. This run closes
no Branch and does not support a waiver; Raw URG is unchanged. See the
[`capacity Formal follow-up`](thermo5-tx-outstanding-capacity-formal-followup-20261103.md)
and its evidence JSON.

The previously open Phase C stimulus dimensions now have separate evidence:
the original packet/long-stream random campaign, a 60-case runtime DPD matrix,
48 randomized reset/COMMIT trials, directed reset/commit boundary tests, and
the exact legal functional-bin audit. They are separate test campaigns; they
do not represent one exhaustive Cartesian product of every system dimension.

## Phase C — System-level tests

| Campaign | Result | Scope and checker |
|---|---:|---|
| Packet and long-stream random | PASS, 110/110 | 100 packet seeds plus 10 two-packet streams; VCS UVM and independent Python trace replay; zero PA mismatch, STATUS predictor mismatch, protocol error, unexpected underflow, lost/duplicate/reordered transaction, UVM error, or fatal. |
| Runtime DPD × gain × input profile | PASS, 60/60 | Identity and legal non-Identity 1-tap coefficient tuples; independent four-plane Python integer oracle. Product reset/default remains Identity. |
| Random reset / pending COMMIT | PASS, 48/48 | 24 reset and 24 COMMIT trials, scheduler seed `20261103`; exact reset-prefix × pending-coefficient, commit-boundary × PA-stall, and STATUS × COMMIT × STOP crosses hit 4/4, 2/2, and 1/1. |
| Directed reset / commit tests | PASS, 8/8 | Reset-prefix × pending-coefficient classes; source-gap / PA-stall / FIFO-full targeted matrix is separately recorded as 12/12. |
| Expected-starvation test | PASS, separate | 32 source beats, one TLAST, 56 bit-true PA words, zero protocol errors; one reported underflow after the packet. This is a starvation/error-class test, not a normal-stream zero-underflow result. |
| Mutation checks | PASS | Independent PA scoreboard detected both `late_gain` and `plane_swap` mutants; baseline passed. This covers these two mutations only. |

## Latest coverage follow-up — outstanding-counter long stream

The focused AXI-Lite test now runs 2,072 source words through 37 legal
32-beat packets under source and PA backpressure. Seed `930901` reached an
observed maximum outstanding count of 28, accepted and emitted 2,072 words,
and passed the independent four-plane bit-true checker. There were zero
underflow, STATUS/predictor mismatch, protocol error, or UVM warning/error/fatal.
The test uses only public inputs; it does not force internal state.

Neither target guard Branch was hit. The saturation guard target
`TXB-e99262dd92665c3b9ea8` at line 203 and underflow guard target
`TXB-c16debdf7d9cbab220ac` at line 204 remain OPEN. The product-bound Formal
assertions and exact guard Covers remain INCONCLUSIVE, so the legal stress run
does not close those roots or justify an Exclusion.

Raw and Adjusted URG now use the same 246 test VDBs plus one design VDB. The
245 earlier VDBs are retained mixed-provenance evidence; this is not a claim
that all 246 tests were freshly simulated from one verification-source SHA.
The additional VDB adds 160 Toggle hits in DPD `sample_count` high bits across
the 16 lanes. Branch, Condition, Line, FSM, and functional-bin counts did not
change. Details, commands, tool versions, and hashes are in the
[`stress report`](thermo5-tx-outstanding-counter-stress-20261103.md) and its
[machine-readable evidence](data/thermo5-tx-outstanding-counter-stress-20261103.json).

The baseline random campaign keeps DPD at Identity. Non-Identity coefficients
were verified in the separate 60-case matrix, so the product default was not
changed. The randomized control, DPD, reset/commit, and original 110-seed
campaigns were compiled from the same product RTL. The 243-VDB coverage merge
contains 240 earlier positive VDBs and two earlier expected-negative VDBs from
source SHA `732a64ab...`, plus the additive starvation VDB compiled at
`1236d49...`. The diff from `732a64ab...` to `1236d49...` has no RTL changes;
the UVM package change only registers the added starvation test and the older
test classes/drivers/checkers are unchanged. Raw and Adjusted URG were rerun
from the same exact 243-VDB list and current design VDB. This provenance is
recorded explicitly; it is not represented as 243 fresh simulations from one
full-tree SHA. The latest coverage refresh adds one targeted VCS VDB to that
retained list; the new VDB was compiled from the verification worktree based on
`ad3211b98677055646975e35924a5809c8d29bac`, with current compile inputs
hash-bound in its manifest. Product RTL remained unchanged.

## Coverage closure round 2 — AXI-Lite STATUS W1C

The targeted legal one-tap DPD test now checks the externally visible STATUS
completion lifecycle: COMMIT completes, STATUS reads DONE=`1`, a legal W1C
write clears DONE, and the next STATUS read returns zero. The AXI-Lite
register predictor independently checks sampled STATUS and transaction
responses. A same-cycle `commit_done`/STATUS-read observer-ordering issue in
the Python trace oracle was corrected and covered by a mutation test that
rejects a corrupted STATUS value.

The test ran with seed `930000`, `C1_RE_Q14=15000`, `C3_RE_Q14=C5_RE_Q14=0`,
and 56 input words. VCS reported zero UVM errors/fatals, zero predictor
mismatches, 17 checked write responses, four STATUS/register reads, and 56
four-plane words matched against the Python bit-true oracle. Trace replay
reported zero underflows.

The added VDB closed seven exact Raw DUT bins, with no waiver or denominator
change:

| Metric | Exact source bin | Result |
|---|---|---|
| Branch | `94c317079c444447221e`, `thermo5_sku_uvm_tb.dut.u_cfg`, `thermo5_dpd_axi_lite_cfg.sv:264` | Hit; legal DONE clear through `REG_STATUS` |
| Line | `51e1eab855e96c50a4fd`, same instance, line 264 | Hit |
| Condition | `de2c421694e6e9174223`, line 264, operands `1/1` | Hit |
| Condition | `87c647010ed34a0a7091`, line 265, operands `1/0` | Hit; legal W1C write leaves ERROR bit clear |
| Toggle | `d209311686c25596f406`, `u_cfg.cfg_done`, `1→0` | Hit |
| Toggle | `fdf1c5a010c986e614fc`, `u_cfg.cfg_done_q`, `1→0` | Hit |
| Toggle | `64f234d6e5984d7c570e`, DUT `cfg_done`, `1→0` | Hit |

The initial W1C aggregate contained 244 test VDBs; the positive-only assertion and
functional view contains 242. The 243-test baseline was 522/637 Branch,
654/849 Condition, 3336/3796 Line, and 84177/104480 Toggle. The refreshed Raw
and Adjusted reports use the same 244-VDB list and the same DUT hierarchy;
coverage is now 523/637 Branch, 656/849 Condition, 3337/3796 Line, and
84180/104480 Toggle. FSM remains 13/13 states and 17/22 transitions. There are
21,071 uncovered code records across 475 root-cause groups; all remain OPEN.
The 371 waiver candidates remain pending, with zero approved waivers and zero
active exclusions. `RAW_100_OPEN` remains the correct gate result.

The latest exact VDB lists, URG reports, gate output, waiver audit, and
root-cause artifacts are recorded in
[`thermo5-tx-coverage-w1c-round2-20261103.json`](data/thermo5-tx-coverage-w1c-round2-20261103.json).

## Coverage follow-up — interframe source gap and STOP/drain

The frame-replacement test now clears RUN after the final complete source
packet is accepted, then checks the output drain. This exposed and corrected a
test sequencing problem: its earlier stop-after-output order could starve the
core after a source bubble, while the checker only counted underflow before the
last source beat. The updated test checks all underflow cycles. No RTL or
algorithm changed.

VCS seeds 930811 and 930832 passed with a one-cycle source gap before beats 31
and 32, respectively; seed 930812 passed without a gap. These diagnostics
checked 112/112 four-plane words with zero underflow and zero STATUS predictor
mismatches, but did not hit the target interpolator Branches. A derived
11-cycle gap before source beat 32 then hit the exact single-entry pop/push
decision in both interpolator stages. The formal product-hierarchy run
(coverage compiled with `thermo5_product_dut_coverage.hier`) accepted 64 source
beats and two TLASTs, checked 112/112 four-plane words against the independent
bit-true checker, and reported zero underflow, STATUS mismatch, protocol
error, UVM warning, error, or fatal. Its UVM event counters recorded
`stage1=1 stage2=1`.

At this checkpoint, the 245-test Raw/Adjusted URG refresh used the exact previous 244-test
VDB set plus this properly hierarchical 11-cycle-gap VDB. Compared with the
244-test Raw baseline, the merge adds two Branches, two Conditions, and 14
Lines; Toggle is unchanged. Both exact interpolator Branch records are absent
from the refreshed Raw open-bin ledger. Code coverage is now Branch 525/637,
Condition 658/849, Line 3351/3796, Toggle 84180/104480, FSM states 13/13 and
transitions 17/22. Legal applicable functional coverage remains 392/392.
The outstanding-counter Formal run used continuous legal 32-beat packets;
both assertions and both target Covers remain INCONCLUSIVE. Only the two
counter guard Branches remain open from this four-Branch priority set.

The earlier 16-point gap sweep used the old stop-after-output test order. All
16 runs reported an AXI-Lite STATUS predictor mismatch and are excluded from
Raw/Adjusted URG. The updated runs above are the valid evidence for the new
test ordering. See the
[`interframe gap and STOP/drain follow-up`](thermo5-tx-interframe-stop-gap-20261103.md)
and its [machine-readable evidence](data/thermo5-tx-interframe-stop-gap-20261103.json).

## Functional coverage

The source-linked bin audit reports **392/392 (100%) legally applicable
product bins** across 12 functional groups. The matrix covers runtime DPD
classes, gain and input profiles, COMMIT timing, PA stalls, reset epochs,
source gaps, FIFO-full observations, STOP/TLAST/Drain, and STATUS ordering.

Two semantic bins are illegal-test-only (`malformed_early` and `bad_frame`),
each shown in covergroup-type and monitor-instance views. The separate negative
regression hits them and checks public `protocol_error` plus reset recovery.
All four report rows remain visible; the 24 URG-model-excluded records are
also retained in the detail CSV. No denominator was edited and no bin was
removed.

The all-test Raw URG view includes expected negative-test assertion failures.
The separate positive assertion inventory has zero failures. Expected-negative
results are not counted as legal assertion failures.

## DUT Raw and Adjusted code coverage

The DUT-only URG hierarchy selects the elaborated TX product path. The latest
Raw and Adjusted reports use the same 246 test VDBs plus one design VDB;
Adjusted applies zero exclusions and therefore exactly matches Raw.

| Metric | Raw | Adjusted | Missing |
|---|---:|---:|---:|
| Branch | 525/637 (82.4176%) | 525/637 (82.4176%) | 112 |
| Condition | 658/849 (77.5029%) | 658/849 (77.5029%) | 191 |
| Line | 3351/3796 (88.2771%) | 3351/3796 (88.2771%) | 445 |
| Toggle, both directions | 84340/104480 (80.7236%) | 84340/104480 (80.7236%) | 20140 |
| FSM states | 13/13 (100%) | 13/13 (100%) | 0 |
| FSM transitions | 17/22 (77.2727%) | 17/22 (77.2727%) | 5 |

At the 245-test checkpoint there were 21,053 open code records. The current
246-test ledger has **20,893 open code records** in 457 root-cause task groups. Every
remaining record is `OPEN`; root-cause labels are triage hypotheses, not
reachability decisions. The 245-test checkpoint had 18 fewer open records
than the preceding 244-test set. The 246th VDB then closed 160 Toggle
directions; it did not close a Branch, Condition, Line, or FSM bin. Priority
gaps include 112 Branches, 191 Conditions,
and five exact `rem_count_q` transitions at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:125`:
`'h2->'h0`, `'h4->'h0`, `'h6->'h0`, `'ha->'h0`, and `'hc->'h0`.

The 371 existing waiver candidates remain **PENDING**. There are zero approved
waivers and zero active `.el` exclusions. The refreshed pipeline audit is
bound to the current compile manifest and source-linked open-bin ledger; only
an independently approved exact waiver can generate an exclusion.

## Assertions and Formal

The positive assertion inventory reports 13 successful DUT properties, zero
failures, two uncovered properties, and two properties without attempts. The
two exact no-attempt properties are the centered-cubic frame-end assertion
`assert (q1_tail)` at `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309-310`,
one per interpolator instance. They remain OPEN; no-attempt is not proof of
unreachability. The positive regression has zero unexpected assertion
failures. The all-test aggregate separately contains two expected failures
from the negative tests.

The outstanding-counter Formal harness ran with zero assumptions and zero
black boxes. Source/core/output activity covers were witnessed, and the two
assertions were non-vacuous. The first runs returned `INCONCLUSIVE` for both
guard assertions and both target guard covers. The later 1,364.76-second,
22-minute-effort run remained `INCONCLUSIVE`: assertion depths 231/122 and
guard Cover depths 196/126. No proof or counterexample was produced. Both Raw
Branch bins remain OPEN; no waiver was created. The exact latest result,
command, tool version, source hashes, and report hashes are in the
[`extended counter Formal report`](thermo5-tx-outstanding-formal-extended-20261103.md).

The DPD Identity equivalence attempt remains inconclusive: one assertion
proven, 12 inconclusive, five constrained, and four of four activity covers
witnessed; zero black boxes. This does not sign off Identity DPD arithmetic.
The existing EF2 stability and pair-lookahead equivalence PASS evidence is
retained, but pair-lookahead remains a disabled candidate and is not part of
the product code denominator.

## 2026-11-03 assertion and DPD leaf-proof update

The later 247-test Raw/Adjusted refresh is the latest product code report. Its
247 unique test VDBs consist of 243 legal positive VDBs, two expected-negative
VDBs, and two additional legal directed VDBs. They are retained
mixed-provenance evidence, not 247 fresh simulations from one full-tree SHA.
The old 16-point gap sweep with STATUS-predictor mismatches is not included.
The 247-test Raw/Adjusted metrics and 20,893 OPEN records are unchanged from
the previous checkpoint; the gate remains `RAW_100_OPEN`, with 371 pending
waiver candidates, zero approvals, and zero active Exclusions.

The legal-only 243-VDB assertion report has 13 successful DUT properties, zero
failures, and two no-attempt DUT properties: `assert(q1_tail)` at line 310 of
`dsm_interp_x2_centered_cubic_vector.sv`, once in each interpolator stage. A
separate corrected expected-negative AXI-Lite test (seed 420102) observed
exactly one CDC frame-alignment assertion and one frame-tail assertion in each
stage. The test checked sticky protocol-error observation and public-reset
recovery; UVM warning/error/fatal counts were zero. A fail-closed log checker
now verifies the exact three RTL assertion sites and rejects additional RTL
assertion Error lines. Keep the negative assertion failures separate from
legal-run status.

A new local DPD Identity VC Formal leaf proof completed with 5/5 assertions
proven, 3/3 Covers reached, zero black boxes, and no environment assumptions.
It fixes the one-tap coefficient image to Q14 unity and ties `out_ready` high.
It proves local arithmetic, fixed latency, ready behavior, and no saturation
for that datapath case. It does not cover stalls, AXI commit/epoch semantics,
or full-chain Identity configuration. The full product DPD Identity proof
remains INCONCLUSIVE/OPEN; this leaf proof does not close URG bins or approve a
waiver. Exact logs, URG reports, hashes and commands are in the
[`assertion and DPD leaf-proof evidence`](thermo5-tx-assertion-dpd-local-formal-20261103.md).

## Commands and evidence

The current coverage refresh is under the ignored local directory
`runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/`. Its manifests
record exact commands, tool versions, VDB fingerprints, and log hashes. Key
artifacts:

- `logs/seed_930000.log` and `traces/seed_930000.jsonl` — targeted W1C UVM run and captured monitor trace.
- `coverage_247_round6_dual_urg/report_manifest.json` — latest same-list 247-test-VDB Raw/Adjusted URG manifest.
- `coverage_247_round6_dual_urg/coverage_gate_round6.json` — `RAW_100_OPEN`, 392/392 legal applicable bins, 371 pending waivers, zero exclusions.
- `coverage_247_round6_rootcause_final/thermo5-tx-coverage-root-cause-summary.json` — 20,893 OPEN records in 457 tasks.
- `coverage_247_round6_dual_urg/vdb_manifest.json` — exact design-plus-247-test VDB input inventory.
- `docs/verification/data/thermo5-tx-waiver-review-round3/` — 371-row candidate audit and zero-approval pipeline audit.
- `docs/verification/data/thermo5-tx-waiver-review-round7/` — current 371-row candidate audit and fail-closed zero-exclusion pipeline audit; supersedes round 3.
- `legal_positive_dual_urg_bound/report_manifest.json` — 242-VDB positive-only assertion/functional report.
- `product_hier_gap11_ledger/` — historical 245-test checkpoint, superseded by `coverage_246/` above.
- `docs/verification/data/thermo5-tx-waiver-review-round2/` — historical candidate audit, superseded by round 3 above.

The retained 243-VDB baseline and earlier Phase C artifacts remain under
`runs/thermo5_tx_closure_current/source_1236d49/` and
`source_732a64/`; no full regression was repeated.

- `coverage_243/final_dual_urg/report_manifest.json` — same-list Raw/Adjusted URG manifest.
- `coverage_243/coverage_gate_final.json` — `RAW_100_OPEN` gate output.
- `coverage_243/rootcause_final/thermo5-tx-coverage-root-cause-summary.json` — exact open-bin totals and legal functional audit.
- `coverage_243/waiver_audit.json` and `coverage_243/thermo5_tx_main.el` — 371 pending, zero approved, zero active exclusions.
- `formal/outstanding_final/formal_manifest.json` — current counter-guard proof result.
- `formal_outstanding_continuous_source/formal_manifest.json` — continuous-packet counter-guard recheck; INCONCLUSIVE.
- `formal_outstanding_extended_20261103/formal_manifest.json` — 22-minute-effort counter-guard run; INCONCLUSIVE.
- `starvation/summary.json` — directed starvation UVM, oracle, and coverage evidence.
- `verification/tools_hw_tests.log` and `verification/python_reference_tests.log` — latest utility and reference tests.
- Earlier Phase C evidence is under `source_732a64/{system_random,dpd_matrix,randomized_control_final,reset_pending,mutation,formal_identity_lemmas}/`.

Reproduction commands for the latest closure inputs:

```bash
python3.12 -m unittest discover -s tools/hw/tests -v
(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)
python3.12 dv/uvm/sim/run_thermo5_axil_starvation.py \
  --out-dir runs/thermo5_tx_closure_current/source_1236d49/starvation_replay
python3.12 tools/hw/thermo5_tx_product_compile_manifest.py \
  --compile-log runs/thermo5_tx_closure_current/source_1236d49/starvation/build/compile.log \
  --source-manifest runs/thermo5_tx_closure_current/source_1236d49/starvation/source_manifest.json \
  --product-filelist dv/uvm/sim/thermo5_sku_filelist.f \
  --coverage-hierarchy dv/uvm/sim/thermo5_product_dut_coverage.hier \
  --output runs/thermo5_tx_closure_current/source_1236d49/product_compile_manifest.json
PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_axil_outstanding_fpv.py \
  --out-dir runs/thermo5_tx_closure_current/source_1236d49/formal/outstanding_replay
```

Latest checks: formal-hierarchy VCS compile and targeted 11-cycle source-gap
run PASS; both target Branch event counters were 1, the independent 112-word
four-plane checker passed, and Underflow/STATUS/protocol/UVM errors were zero.
The 2,072-word counter stress test passed with 2,072/2,072 bit-true words and
zero UVM warnings/errors/fatals. Same-list 246-test Raw/Adjusted URG,
refreshed source-linked ledger, 371-row round-3 candidate audit,
zero-exclusion pipeline, and final fail-closed Gate all PASS. Hardware utility
tests passed 38/38; Python reference tests passed 59/59; `py_compile` and
`git diff --check` passed. The continuous-packet counter Formal result remains
**INCONCLUSIVE**, not PASS. No full regression was run.

## Remaining signoff items

- Close or formally disposition all 20,893 open DUT code records without
  changing the valid denominator; first investigate reachable Branch and
  Condition records, then Lines, Toggle, and the five FSM transitions.
- Resolve the two interpolator assertions with legal witnesses or exact
  non-vacuous reachability proof.
- Improve EF2 DPD Identity Formal convergence and the outstanding-counter
  proofs; Formal inconclusive remains OPEN.
- Preserve the current separate expected-starvation classification and settle
  the source-gap contract for the system interface.
- Run real XPM FIFO and GT Wizard simulation, FPGA PPA/routed timing, and
  physical RF/QAM256 BER on their required vendor/platform flows.

No RX, AI-DPD, Vivado physical implementation, product RTL, default DPD image,
or frozen TX algorithm was modified in this closure round. No PR was merged.
