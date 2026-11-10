# Round 21 queue analysis and independent-review packet

Date: 2026-11-10 (Asia/Singapore). Approval status: PENDING.

## Queue and handshake transitions

Read `dsm_interp_x2_centered_cubic_vector.sv:64-87,218-285`. At a legal
active edge q_count is 0, 1 or 2. push_input = in_valid && in_ready;
in_ready = enable && (q_count<2 || pop_head). pop_head is either a consumed
real head or a dropped tail in stage 2. With no pop/push occupancy holds;
push only increments; pop only decrements; pop+push preserves occupancy.
Reset/disable empties the queue (history retention is a separate parameter).

For q_count=2, a pop moves q1 to q0 and a simultaneous push replaces q1.
The captured product witness contains 110 stage-1 and 112 stage-2 full-queue
replacement edges. These cannot close the two single-entry replacement bins.
For q_count=1, pop+push loads the incoming vector directly into q0. Stage 1
needs a frame-ending real head, ready high, no synthetic output pending and
incoming valid on the same edge. Stage 2 can also pop a tail head. The
witness has one single-entry pop without push in each stage. The missing
simultaneous edge remains OPEN; no cadence/random-miss inference is made.

Stage 1 never accepts in_tail: it is tied low in the frontend. Synthetic
lookahead tails are generated at output, separately from queued real input.
Stage 2 consumes this metadata, but APPEND_TAIL_VECTOR=0 prevents generating
its own output tail. q0/q1 metadata can remain stale when occupancy=0; those
bits are not evidence of a valid empty-queue head. A blocked valid head and
its output data must remain stable. Existing legal queue replay checks the
four-plane output; VCD extraction samples pre-edge state, before NBA updates.

The scoped Formal legal-metadata composition proves both q1_tail assertion
antecedents unreachable in that harness, with packet-end/tail/transfer covers.
It omits elastic FIFOs and DPD, and uses an eight-frame packet schedule.
The reset proof covers runtime reset with nonempty queues and proves reset
empties them. Neither proof is silently promoted to full-chain signoff or an
official exclusion. Legal product q1_tail assertions still have no attempts.

## Priority independent decisions

1. AXI-Lite candidate TXB-3df5f13a8d51ee9bdea5: the exact default-response
   false arm at line 246. Prior current-source zero-assumption/zero-black-box
   proof and native strict URG directive are in the R20 package. Approve only
   that exact vector after reviewing the source/hash/proof; no approval exists.
2. DPD vector-history Lines TXB-2630d236b14544679aef,
   TXB-85e4dc08ceaaa6cb3089, TXB-a26f239c3d988ed66b21,
   TXB-ba031f7f15eab43758d9: MAX_TAPS=1 means tap=0<=lane, so the history
   read else arm cannot execute. HISTORY=1 and LANES=16 mean h=0<LANES, so
   the history-shift else arm cannot execute. This is static parameter evidence;
   they are not yet in the 11,419 What-if population and need exact native
   mapping and independent approval before any exclusion.
3. Counter acceptance is a distinct decision in the counter proposal.

The 11,419 existing analysis candidates retain unique semantic IDs and are
partitioned by the original seven root causes plus the one AXI-Lite candidate.
The 371 official Waiver IDs are copied verbatim with their prior exact links:
2 Raw-hit-resolved, 369 pending. Candidate rows without an old Waiver ID stay
unlinked; no ID or approval is invented. Configuration evidence in a group
must be checked against each native directive; applying What-if is not proof.
The full CSV includes unresolved preconditions explicitly. UNKNOWN remains OPEN.

Approval must identify the independent reviewer and reference, exact semantic
ID/native directive, source SHA, configuration, proof and evidence hashes.
No Reviewer identity was supplied. Official .el remains unchanged and empty.

## Integration review addendum (2026-11-10 06:40 UTC)

The uploaded source commit is a98a32dd50c86d0005b12b09b1a4f54d7a808cbc.
A read-only URG `-full64 -dir runs/final_urg/raw/urg.vdb -dump full_exclusions`
completed successfully; no simulation or coverage merge was rerun.
`data/thermo5-r21/integration_review/dpd_history_native_review.json` binds
four source-SHA-checked History lines to the current merged VDB and native
template hash. Only lines 61 and 80 have individually identified native Blocks
(5 and 13). Lines 62 and 81 have no separate native object in this dump.
Do not infer that a Block directive independently excludes each companion Q
line; that mapping/acceptance remains OPEN. No directive was activated.

| Pre-edge occupancy | pop | push | Next occupancy | Queue action |
| --- | --- | --- | --- | --- |
| 0 | 0 | 0 | 0 | Hold stale metadata; no valid head |
| 0 | 0 | 1 | 1 | Load input into q0 |
| 1 | 0 | 0 | 1 | Hold q0 |
| 1 | 0 | 1 | 2 | Load input into q1 |
| 1 | 1 | 0 | 0 | Retire q0 |
| 1 | 1 | 1 | 1 | Replace q0 directly; exact witness OPEN |
| 2 | 0 | 0 | 2 | Hold queue; in_ready=0 |
| 2 | 1 | 0 | 1 | Shift q1 into q0 |
| 2 | 1 | 1 | 2 | Shift q1; load input into q1 |

Table applies in the active enabled branch. Empty pop and full push without
pop are prohibited by the combinational equations. Reset/disable overrides
these updates. Stage 2 can retire a tail without out_ready; distinguish
`drop_head_tail` from a consumed output handshake. Synthetic tail output
blocks real-head consumption. Do not require all metadata registers to clear
when occupancy becomes zero.

`remaining_257_by_source.csv` preserves the exact ID, file, instance, bit or
truth tuple and current precondition for every OPEN non-counter bin.
`remaining_groups.json` partitions 138 interpolator and 119 other bins.
This grouping adds zero exact hits and changes no coverage totals.

| Obligation | Evidence and limitation | Decision |
| --- | --- | --- |
| Legal simulation assertions | 13 success, zero failures; q1_tail has no legal attempts | Scoped PASS; q1_tail OPEN |
| Negative CDC / both q1_tail failures | Confined to four expected-negative scenarios | Expected-negative only |
| Metadata/reset Formal | Two scoped jobs PASS; FIFO/DPD composition omitted | Product transfer OPEN |
| DPD Identity arbitrary stalls | Earlier composition incomplete | Full-chain OPEN |
| Outstanding counter / COMMIT lifecycle | Earlier Formal obligations unresolved | OPEN |
| Counter arithmetic | Carry/wrap/reset/hold block PASS; deposits block-only | 930 system bins OPEN |
| Waiver / exception acceptance | No independent reviewer approval | Zero approved exclusions/exceptions |
| Code Coverage Signoff | 1,187 What-if gaps; Raw gaps 12,606 | OPEN |
| Full Linux DV Signoff | Requires remaining Formal/assertion scope closure | OPEN |

GitHub CLI device authorization remains pending. #49 and #50 are Draft/Open;
the Round 21 Draft must target `codex/thermo5-round20-exact-bin-closure`.
No merge is authorized by the current incomplete signoff evidence.
