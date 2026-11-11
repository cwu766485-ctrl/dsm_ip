# RTL-grounded closure execution

2026-11-11 10:15 Asia/Singapore. Base:02b5c95. Frozen product:
635be681046b3ab7d6fdda7f4e9818d7226efd66. Product RTL unchanged.

## Actual result and execution blocker

New product Exact URG HIT: **0**. Independently approved exclusions: **0**.
Accepted exceptions: **0**. Of the requested87 officially OPEN bins, **0 closed**.
The source-bound review identifies33 additional technical candidates;54 remain
technically unresolved. All87 remain officially OPEN. Existing11560 candidates
are preserved, not regenerated. The proposed disjoint union is11593 pending
candidates, conditional on review of the new33; this is not an applied URG set.

VCS compile was attempted in isolated `runs/rtl_invariants/compile/`, using the
prior frozen-product command with only output paths changed. Exit255:
`Cannot connect to the license server` / `Failed to obtain license`.
No simulator, Formal or URG result is claimed for this execution. Do not merge
the optional DV change until compilation and target validation succeed.
A public-reset-at-ready-tail variant is prepared in the existing UVM test;
read-only `uvm_hdl_read` observes tail_output/out_ready. It never writes DUT
state. Its reset-to-target witness and coverage delta are **UNVALIDATED**.
No new seed sweep was started.

## Exact source review

`data/thermo5-rtl-invariants/open87_review.csv` retains all87 exact semantic IDs,
original native objects/vectors/directions, instance, source hash and parameters.
It adds per-row rationale, pending approval, and official_closed=false. Every
source hash was checked against current files. Existing141 candidates and3
hits are not relabeled. No official `.el` is generated.

The requested22 high-priority rows are all technical candidates:

| Root cause | Exact rows | Source assignment chain |
| --- | ---: | --- |
| Frontend constant metadata | 6 | frontend:178 APPEND_TAIL_VECTOR=0; interpolator:64/84 tail_output=0 => i2_tail=0; frontend:215 in_meta=0; FIFO:262/277 masks empty output and writes only0 |
| Stage1 tail history | 2 lines | frontend:107 in_tail=0; interpolator reset/disable/push/shift preserve q0_tail=q1_tail=0;229 guard false;230/231 share complete Block47 |
| Stage2 append-disabled | 4 lines | interpolator:64/74 tail_fire=0 =>218 unexecuted;223 APPEND_TAIL_VECTOR=0 =>224/225/226 unexecuted; all three members of Block43 reviewed together |
| Legal CDC frame residual | 10 | CDC:145-151,190-221; ordered legal32-beat-multiple frames imply final input residual2, then pending remaining8, then clear0 |

An additional11 exact Condition tuples require Stage1 q0_tail/drop_head_tail=1
or Stage2 tail_output=1 and inherit those same constant assignment chains.
Native expression versus subexpression and selected vector remain distinct.
No shared-block scope is widened; original five shared-record approvals are
still pending. The FIFO metadata memory itself is uninitialized at reset:
constant output follows from the count/pointer write-before-read invariant,
not a claim that reset clears its RAM.

The elaboration source chain is the frozen compile's AXIL/CENTERED_CUBIC,
ORDER2/STEP5120/MAX_TAPS1 defines, DUT generate paths and literal instance
parameters. The VDB `verilog.instance_parameters.txt` is empty; it supplies no
independent parameter dump. Exact instance identities/native objects and
existing VCD widths confirm selected hierarchy, but this limitation must be
reviewed before approval. Never invent a parameter report.

## Executable CDC invariant and limits

`python3.12 tools/hw/thermo5_cdc_residual_invariant.py --output runs/rtl_invariants/residual.json`
exhausts89 states/299 transitions in a reviewed control abstraction. The state
retains input-consumption phase modulo32, residual, end_pending, end_remaining
and output-valid. FIFO availability is arbitrary while order is preserved;
enable/backpressure hold, common reset is possible in every state, and drain
only affects underflow diagnostics. TLAST is optional at phase31, allowing
arbitrary positive32-beat-multiple packets. Legal end_remaining values are
exactly0,8, so bits0/1/2/4 stay0 and remaining>8 cannot execute.

An unconstrained-TLAST control run explores184 states and supplies real
abstract counterexamples: phase2/rem12/pending1/remaining12 reaches line151.
Therefore this is **product legal-scope evidence**, not intrinsic module-wide
unreachability. Existing expected-negative tests must remain separately visible.
This source-reviewed model is not an RTL equivalence proof or new VC Formal
PASS. Independent review must accept the abstraction and frame/reset contract.

## Remaining control obligations

The87-row ledger leaves54 technically OPEN. Interpolator conditions are grouped
by native expression and instance in `interpolator_condition_groups.json`.
Continuous-expression bins need event-order analysis: a stable algebraic
contradiction alone cannot exclude an asynchronous propagation event. Prior
public-reset hits demonstrated that distinction. Assertion expressions instead
need their actual sampled process context and reset/enable ordering.

Outstanding real-word capacity has a conservative29-slot structural bound:
FIFO2 +gain3 +interp1 queue2 +synthetic tail1 +elastic2 +DPD11 +elastic2
+interp2 queue2 +elastic2 +EF2 register1 +PA bridge1. This is a capacity count,
not a proven transaction invariant. Synthetic insertion/drop changes token
counts; a proof must track real-word weights and reset/STOP epochs. Prior
observed max28 and INCONCLUSIVE product Formal do not justify excluding
bits5..7 or the overflow/underflow guards. These remain OPEN.

Gain's six tuples ask for metadata1 with corresponding valid0. Pipeline
updates mask metadata with valid, but upstream FIFO outputs can retain stale
metadata while empty; full-chain proof is still needed. CDC FWFT/empty tuples,
DPD pipe_ce/not-valid tuple, source-error diagnostic tuple and request-pending
synchronizer tuple likewise remain OPEN pending exact temporal witnesses or
proof. No additional random scan is justified by this review.

## Counter options and recommendation

930 legally reachable high-bit directions stay OPEN (464 sample,466 saturation).
`dpd_memory_poly.v:335/338` increments modulo2^32 under pipe_ce; reset:201/202
clears both. The16-lane wrapper:114 leaves both public block outputs unconnected.
They are not mapped to AXI-Lite. UVM nonetheless observes/checks them, so
unconnected product ports do not by themselves authorize removing them.

| Option | Product impact | Verification and acceptance |
| --- | --- | --- |
| A: retain counters | No frozen RTL/configuration change; preserve implemented diagnostic contract | Keep existing32-bit carry/wrap/reset/stall block evidence; owner must explicitly accept system scope and independent review must reference exact930-bin ledger. Exception is separately reported and does not raise URG percentages. |
| B: proposed optional pruning | Future change: add default-enabled diagnostic-counter parameter to dpd_memory_poly, propagate through vector wrapper/frontend/AXIL wrapper; disabled generate branch drives stable public outputs while removing only counter update storage | Rework TB hierarchical taps, DSP boundary monitor, transaction events, scoreboard and counter-dependent tests; retain default-enabled arithmetic block test; add disabled-configuration bit-true/regression checks; resynthesize to verify pruning and unchanged functional timing. New product/configuration freeze and coverage denominator required. |

Recommend **A** for this frozen handoff. B is a future product ECO proposal,
not implemented here; it cannot retroactively waive frozen bins. Neither option
has a supplied signed product-owner decision. No approval is inferred.

## Independent review and final status

Preston is GitHub account `cwu766485-ctrl`, also current authentication and PR
author. A GitHub self-approval is not independent. No alternate reviewer or
signed exact-bin acceptance record was supplied. Root-cause batch review may
approve many rows, but its signed scope must enumerate exact semantic/native
IDs and complete shared-block membership. Approval counts stay0.

Latest measured evidence is inherited unchanged from the588-test unified
baseline, not rerun after the license failure:

| Metric | Raw = Official Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch |526/637|526/529|
| Condition |667/849|667/741|
| Line |3352/3796|3352/3363|
| Toggle |92640/104480|92640/93710|
| FSM states / transitions |13/13;22/22|13/13;22/22|

Official missing12577; inherited What-if missing1158=228noncounter+930counter.
The new33 candidates are not applied to that What-if. Existing parent SHA256:
fd0832dbb73e50f04f7a9f526240ee995cab4ff97ba7af40c714d5311dd852c3.
Design VDB:`runs/queue_witness/reset_compile/simv.vdb`; URG reports:
`runs/queue_witness/urg/{raw,approved_adjusted,whatif}/report`.
Prior588/588 PASS (584legal/4negative), legal assertions13success/0failure,
two q1_tail without attempts. Those are inherited results only.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**
