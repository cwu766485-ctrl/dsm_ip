# Thermo5 signoff convergence v5

2026-11-12 SGT. Parent PR57 `d672040989fb51c9530737d6ded9a98796df4ae5`.
Frozen product `635be681046b3ab7d6fdda7f4e9818d7226efd66` has an empty RTL
diff. No product parameter, algorithm, official exclusion or denominator changed.

## Measured progress

Two Gain targets change from UNRESOLVED to PROVEN_UNREACHABLE pending independent
approval. The other 46 remain UNRESOLVED with root-cause-specific transition
models and blocking obligations in `data/thermo5-signoff-v5/exact_dispositions.csv`.
New licensed URG HIT=0; approved exclusion=0; accepted exception=0. Official
remaining=12,577. Existing 11,599 pending candidates remain unchanged; the two
new proof-backed Gain targets are separately submitted for approval (potential
pending union=11,601, no overlap). The 930 cumulative-counter directions remain
OPEN for product scope decision; the Outstanding capacity argument is unrelated.

## New compositional Gain proof

The prior Gain-only harness covered invalid input metadata: it did not prove the
upstream contract. The new harness instantiates the actual registered-ready
FIFO (W16/LANES8/META18) feeding actual Gain (W16/LANES8/GAIN16/FRAC14,
HOLD_STATE_ON_DISABLE=0), matching the AXI-Lite product frontend. Input data,
metadata, valid, enable and output ready are unconstrained. This is an
overapproximation of legal public traffic; no upstream assumption is required.

FIFO transition: count'=count+push-pop, push=valid&&ready, pop=out_valid&&out_ready.
Its output metadata is explicitly zero while output valid is zero. Composition
therefore prevents `!in_valid && in_frame_start/end` at the Gain procedural
sample, including empty, stall, disable and initialized reset state.

Exact bindings:

- TXB-1a46bada439ec7a2903c: Gain Condition5, checksum3847952111, vector1/01, line136.
- TXB-7b1fe74dbf7ff06539d5: Gain Condition6, checksum3518324077, vector1/01, line137.

VC Formal V-2023.12-SP2: 4 assertions PROVEN; 3 implication assertions
non-vacuous; 2 target covers UNCOVERABLE; 3 positive covers reached at depth1/2.
Zero blackboxes and zero explicit setup violations. Engine e7 proves capacity,
t1 proves masked-metadata operands, t3 proves target covers uncoverable, b8
reaches positive covers. Engine status `failed` for an unreachable cover is not
an assertion failure; the property report classifies it UNCOVERABLE.
Warnings were preliminary POTENTIAL_SETUP_ISSUES (followed by clean explicit
check) and LEARNED_DATA_NOT_FOUND for the fresh run, recorded without concealment.

Scope: reset-initialized, clock-sampled procedural RHS outside reset and disable;
VCF constrains reset released after initialization. This does not prove arbitrary
mid-run reset propagation or delta-cycle continuous-expression coverage. Those
scopes, especially Interpolator/Frontend/CDC aliases, remain OPEN. No official
`.el` is generated. Reports, source hashes, positive/negative cover results and
engine records are in `data/thermo5-signoff-v5/gain_fifo/` and `formal_results.json`.

## Remaining proof and cross obligations

Interpolator: count/metadata queue recurrence, synthetic tail and stale q1_start
must be analyzed with native event semantics. Settled-state contradictions do
not close reset-sensitive tuples. q1_tail antecedent needs upstream legal marker
composition. CDC: FIFO valid/empty alias plus residual progression does not alone
prove all-event native tuples; prior TLAST0 harness does not cover packet/STOP
scope. Frontend invalid metadata is combinational, so Gain procedural proof is
not extended to it. TX Top: separate six counter directions/two guard branches
from control tuples. Full weighted real-token/reset/STOP refinement is still
INCONCLUSIVE, and no unchanged harness was rerun.

P1 five cross cases remain OPEN. Existing P0 event/oracle evidence is retained;
no new P1 simulation was executed, and no new system cross closure is claimed.
`system_cross_matrix.json` is explicitly inherited evidence, not a v5 test result.
The packet/epoch and simultaneity gaps require actual qualified directed tests.

## Coverage and PR integration

No DUT test, compile, VDB set or analysis exclusion changed. The measured
594-test same-parent baseline is retained, not rerun. Raw=Official: Branch526/637,
Condition667/849, Line3352/3796, Toggle92640/104480; What-if: Branch526/528,
Condition667/713, Line3352/3352, Toggle92640/93576; FSM13/13+22/22. No new URG
run or delta is claimed. The new local Formal proof is not product URG coverage.

PR55/56/57 were inspected for source SHA, dependency and review state. None has
independent review approval; no integration or clean integrated regression was
performed. Existing regression PASS is evidence for the existing parent, not
an integration claim. Detailed CI/review snapshots are in `pr_dependency_review.json`.
The inherited claim of complete review is not made: pending obligations, scope
and P1 implementation still require work. No automatic merge.

Existing 11,599 IDs are preserved in `approval_batches_11599.csv.gz`, grouped by
existing evidence where available and referencing the original native/scope
records. Broad inherited classes and missing exact root-cause grouping remain
review-package limitations; they are not approvals. Native shared-block scope
must be checked at original records before approval. The two Gain IDs remain
in the separate exact disposition ledger to avoid silently extending a batch.

## Reproduction and checks

```bash
python3.12 dv/uvm/formal/run_thermo5_gain_fifo_v5.py \
  --out-dir runs/signoff_v5_fresh --execute
python3.12 -m unittest discover -s tools/hw/tests
python3.12 -m py_compile dv/uvm/formal/run_thermo5_gain_fifo_v5.py
git diff --exit-code 635be681046b3ab7d6fdda7f4e9818d7226efd66 -- rtl
```

Two fresh local proof executions agree; utility tests65/65 PASS; runner syntax
PASS; frozen RTL diff empty. No generic regression campaign or seed search.
Code Coverage Signoff: **OPEN**. Full Linux DV Signoff: **OPEN**.
