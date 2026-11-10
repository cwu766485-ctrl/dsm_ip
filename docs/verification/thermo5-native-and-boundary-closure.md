# Native mapping and boundary COMMIT exact closure

## Product and integration

PR #52 was technically reviewed and merged as c98cd5199cc07ba10e30c4b6c9a31307ffd9795c.
The merged technical evidence is separate from independent Waiver approval.
The task/thermo5-exact-review remote branch was deleted after ancestry/integration.
Frozen product RTL remains 635be681046b3ab7d6fdda7f4e9818d7226efd66.
All four product metric shape files match the previous compiled baseline byte-for-byte.

## Actual new hit

TXB-fe4a2292a0aa4da543b9 is Condition12/checksum650566998/vector101,
thermo5_sku_uvm_tb.dut.u_cfg, thermo5_dpd_axi_lite_cfg.sv:333.
A legal Identity COMMIT is issued after32 accepted source beats,29 core cycles
later, with AXI clock phase5000ps. Two complete32-beat packets produce112 words;
all four output planes match the independent reference. UVM errors/fatals=0.
The VCD pre-edge snapshot at560070ps shows request1/pending0/boundary1/reset1.
Native standalone product URG confirms Covered. The checked shell runner also
requires the existing read-only phase trace to observe the tuple before PASS.
No force/deposit, changed product parameter or altered arithmetic is used.

Earlier source-gap11 with PA stress had zero URG increment and was stopped.
COMMIT delays0/27/29 with original phase missed the target; phase5000ps/delay29
hits it. The first auxiliary-worker prototype prematurely ended join_any and
is discarded (no SKU_PASS); the worker now persists until the parent completes.
An initial compile from the simulation subdirectory failed relative file paths;
compilation from repository root succeeds. These attempts never enter final URG.

## Native mapping closure

Five companion lines are linestmt members of exact shared basic blocks in the
same Design VDB. DPD62 shares Block5 with61; DPD81 shares Block13 with80.
Interpolator231 shares Block47 with230. Interpolator225/226 share Block43 with224.
All companion statements exist in the231-row ledger. Activating a shared Block
requires independent approval of every member; the mapping does not authorize
excluding a wider block on a single-line approval.

Flattened vectors map to CDC Branch0/checksum1959897721/vector4;
TX Branch3/checksum2439108191/vector4 (decrement-at-zero), and vector2
(increment-at-all-ones). Shape records include exact expression tree and encoded
vector. Eight object mappings resolved, zero unknown object IDs; five shared
block records still require all-member scope acceptance. No .el is activated.

## Approval and scope

Historical11419 and new141 candidates have unique semantic IDs and zero overlap;
the union is11560. The2448 group repairs and371 waiver references are retained.
Preston is assigned, with no independent per-bin approval supplied. The owner's
instruction to exercise technical judgment is not a signed independent review.
Approved exclusions=0; accepted exceptions=0. Counter930 directions remain OPEN:
legally reachable diagnostics, with retained independent carry/wrap/reset/stall
block evidence. Product-owner scope acceptance remains pending.

Technical231-row dispositions:1 HIT,141 pending candidates,89 unresolved.
The four official dispositions treat all230 other rows as OPEN until approved;
EXCLUSION_CANDIDATE is evidence metadata, not an official closure state.
Code Coverage Signoff: OPEN. Full Linux DV Signoff: OPEN.

## Final same-input URG

The necessary unified replay passes586/586 inherited scenarios plus the new
legal test:583 legal and4 expected-negative. No random seeds were added.
48 hardware utility tests and66 independent reference-model tests pass.
All587 Test VDBs match one fresh Design VDB parent. Product RTL is unchanged;
the DV-only compile changes the optional scenario path, not DUT metric shapes.

| Metric | Raw / Official Approved Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch | 526/637 | 526/529 |
| Condition | 665/849 | 665/741 |
| Line | 3352/3796 | 3352/3363 |
| Toggle | 92640/104480 | 92640/93710 |
| FSM states | 13/13 | 13/13 |
| FSM transitions | 22/22 | 22/22 |

Actual delta: +1 Condition, all other metrics unchanged. What-if missing1160
=230 non-counter+930 counter; Raw/Official missing12579. Code-bin hits excluding
FSM=97183, approved exclusions0, accepted exceptions0, officially OPEN12579.
FSM adds13 hit states and22 hit transitions; no FSM gaps. Historical and new
candidate metadata does not change official counts or activate exclusions.

All five URG logs have zero warning/error/mismatch diagnostics, using the same
frozen input list. Legal-only assertions:13 SUCCESS, zero FAILURE, two q1_tail
checks UNCOVERED/without attempts. Combined3 failures occur only in the four
expected-negative tests. Full FIFO/DPD composition, arbitrary-stall DPD and
outstanding/COMMIT obligations remain OPEN; Code Coverage OPEN does not mask
Full Linux DV OPEN. Source, compile/VDB parent, witness and manifest fingerprints
are retained in closure_manifest.json. No Windows XSim was run: this is a
Linux DV-only test change with no RTL/MATLAB/algorithm modification.
