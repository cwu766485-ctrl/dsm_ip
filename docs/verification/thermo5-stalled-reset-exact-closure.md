# Stalled public reset exact coverage closure

Frozen product RTL remains635be681046b3ab7d6fdda7f4e9818d7226efd66.
Base integration a6dd883; no DUT source or parameter is modified.

## Target derivation and result

Both interpolators' line71 subexpression is can_emit_head && !tail_output &&
out_ready && enable. The missing1110 tuple cannot describe a normal enabled
handshake: enable0 suppresses pop and output-valid. A public asynchronous reset
can legally clear the parent core-active state before derived can_emit_head
propagates from reset queue state. This is event-driven combinational code
coverage, not a stable active-clock transaction or proof of datapath behavior.

The directed test accepts24 legal source beats, requests RUN with16-beat prefill,
holds public PA ready0, waits for genuine PA valid and40 falling core edges,
then asserts both public resets through the existing reset BFM. No transaction
is withdrawn mid-handshake and no internal DUT state is driven. After reset,
a complete56-word Identity epoch matches all four independent oracle planes.
UVM errors/fatals=0; product underflow/protocol flags remain clear.

At548640ps, ordered VCD changes record enable0 while both stages still have
can_emit_head1, tail_output0 and out_ready1 during reset propagation. Queues
have reset to0 in the same timestamp; the downstream combinational propagation
then clears can_emit_head. Native URG proves1110 Covered in both instances.
These are2 real product URG Condition hits; they must not be described as stable
handshake witnesses or as a structural impossibility waiver.

Exact IDs: TXB-1f1ce5bdcc2c308628e9 (Stage1),
TXB-ab53b1aadded931bc157 (Stage2). Both map to native Condition19,
checksum2474396749, vector4/1110. Source assignment/reset chain and VCD event
qualification are explicit in reset_event_witness.json.

## Zero-delta and failed attempts

A dense16-frame112-word fixture and the same fixture with an11-source-cycle
packet-boundary gap both pass the oracle and add zero exact bins; no further
seed expansion follows. The frame-count plusarg is retained so this valid
fixture remains reproducible, but no closure is attributed to it.

During unified replay, a redundant compile to the active executable directory
caused154 tool execution failures before/at simulation startup. Those results
are retained as failed_attempt evidence and are not assertion failures or PASS.
Affected scenarios are replayed only after compilation is frozen;195 otherwise
passing early jobs are also replayed because the redundant compile changed
their parent database fingerprint. No mixed-parent aggregate is accepted. The first
retry wrapper incorrectly passed prior result fields to execute and failed;
the corrected wrapper passes plan fields only. Final manifest records results.

## Approval boundary

GitHub collaborator lookup returns only the owner; PR52/53 have no independent
reviews. Preston's GitHub login/signature has not been supplied, so a genuine
review request cannot yet be addressed. All11560 candidate IDs retain pending
status; no independent approval, official .el or acceptance exception is made.
The five shared blocks need approval for every listed statement, not just the
companion line. Existing371 Waiver IDs and exact scope remain unchanged.

930 counter toggle directions remain legally reachable and OPEN. Independent
32-bit carry/wrap/reset/stall evidence remains block-only; acceptance still
requires a product-owner decision. Code Coverage and Full Linux DV signoff OPEN.

## Final validation and coverage

588/588 scenarios pass under one frozen final compile parent:584 legal and4
expected-negative.48 hardware utility tests pass; independent reference models
are unchanged from the previously passing66-test validation. The strict shell
runner passes with the real public-reset scenario and oracle checks.

| Metric | Raw = Official Approved Adjusted | Analysis-only What-if |
| --- | --- | --- |
| Branch | 526/637 | 526/529 |
| Condition | 667/849 | 667/741 |
| Line | 3352/3796 | 3352/3363 |
| Toggle | 92640/104480 | 92640/93710 |
| FSM states/transitions | 13/13;22/22 | 13/13;22/22 |

Actual new HIT2; approved exact bins0; accepted exception bins0.
Official Raw remaining12577; What-if remaining1158=228 noncounter+930counter.
231-row technical ledger:3 cumulative HIT,141 pending candidates,87 unresolved.
All228 non-hit rows remain officially OPEN. All five URG logs are free of
warning/error/mismatch diagnostics. Legal assertions13 SUCCESS,0 FAILURE;
two q1_tail checks remain without attempts. Combined3 failures belong solely
to the expected-negative tests. Full composition/stall/outstanding Formal
obligations remain OPEN. No coverage approval or100% claim is made.
