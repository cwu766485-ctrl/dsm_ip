# Thermo5 TX DV Convergence v2 — Gate 0 baseline

2026-11-11 Asia/Singapore. Product SHA `635be681046b3ab7d6fdda7f4e9818d7226efd66`.
PR55 branch latest `7b0c59c9bac857ff780b7ef9a9da668dc945527e`; base thermo5
`02b5c95`. This document records execution status for the v2 plan; it does not
promote technical evidence to approval.

## Baseline inventory

`data/thermo5-pr55-application/v2/coverage_exact_triage_v2.csv` contains all54
current non-counter technical OPEN rows, with exact semantic ID, source/native
mapping inherited from `remaining54.csv`, RTL instance/expression, predecessor
obligation, Formal/VCS evidence state, actual URG delta and decision. All54 are
UNRESOLVED until exact legal reachability or source-bound proof is established. None are
PROVEN_UNREACHABLE, CONFIG_UNREACHABLE, APPROVED_EXCLUSION or ACCEPTED_SCOPE_EXCEPTION.
The 930 counter directions remain a separate product-scope decision.

`system_scenario_inventory_v2.csv` inventories all589 verified scenarios:
585 legal and4 expected-negative; all PASS under the single frozen compile parent.
Each row retains stimulus argv, packet/reset epoch status, checker, VDB and event
trace location. Three focused public tests are appended with VCD/oracle evidence.
This is an inventory, not a synthetic Cross hit; packet-level crosses must use
same packet and epoch IDs.

Raw = Official Approved Adjusted (zero approved `.el`): Branch526/637,
Condition667/849, Line3352/3796, Toggle92640/104480, FSM13/13 states and22/22
transitions. Existing analysis-only What-if (all174 candidates) is Branch526/528,
Condition667/713, Line3352/3352, Toggle92640/93576: 984 missing =54 non-counter
+930 counter. New Exact HIT0, approved exclusion0, accepted exception0.

## Exact root-cause status

- DPD line93 has an existing vector-ready Formal harness ; the prior AXI-Lite line93 proof concerns a different module and must
  not be transferred to this DPD bin. Existing DPD result provenance is still
  being located; no proof status is inferred. No exclusion is inferred from a test miss.
- CDC `core_data_empty` has a product-shaped Generic FIFO invariant harness
  (`thermo5_cdc_data_empty_harness.sv`). Its assertions are useful predecessor
  checks, but no fresh PASS is claimed in this sprint; a raw tuple combining
  empty and valid must be checked at the sampling/delta-cycle boundary.
- AXI-Lite line333 boundary tuple remains UNRESOLVED: prior legal
  COMMIT test hit a different tuple. A new test is justified only after exact
  mailbox request/pending/boundary predecessor reconstruction.
- Gain six tuples remain timing-context questions because registered valid
  masks metadata, while empty FIFO outputs may retain storage values.
- Interpolator 22 tuples remain grouped by q_count/q0/q1 metadata, tail and
  reset/event context. Prior ready-tail reset passed its independent oracle but
  added URG delta0; no new seed sweep is justified.
- TX/Outstanding remains open. The weighted model gives conditional real-slot
  capacity28, while full RTL refinement, DPD lockstep and STOP/reset conservation
  are unproven. Previous capacity Formal was INCONCLUSIVE at depth51; it is not
  repeated.

`remaining54.csv` and v2 triage preserve Exact IDs; no random miss is called
unreachable. Existing Formal status in `runs/formal_r21_retry/formal_summary.json`
remains explicit: proven assertions and uncoverable covers are scoped to their
harness assumptions and omitted datapath, not whole-product signoff.

## System Cross inventory boundary

The current coverage component records packet and epoch identifiers and has
same-packet crosses for source-gap/PA-stall/FIFO-full, run-prefill/source-gap,
and STOP/TLAST/drain. The 589-row inventory records actual evidence. Missing
crosses still require dedicated same-epoch stimuli and independent checkers:
COMMIT×non-identity DPD×boundary×PA stall; reset×pending COMMIT×EF2 state×stall;
long packet×STOP×drain; AW/W/B backpressure; STATUS W1C/error/read; and
RUN/STOP/restart expected-negative. No cross is marked covered from unrelated
rows.

## CI and signoff

Licensed VCS/URG evidence is available for the frozen parent and 589 scenarios.
GitHub syntax/hygiene checks are not licensed DV. No new licensed regression was
needed because this v2 execution changed only triage/inventory tooling and did
not change RTL, tests or compile inputs. Utility suite remains 49/49 PASS.

**Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.**
Formal INCONCLUSIVE/TIMEOUT/untriggered assertions remain OPEN. No official
exclusion is active; all 11,593 candidates remain PENDING and 930 Counter
Directions remain OPEN pending product owner scope decision.
