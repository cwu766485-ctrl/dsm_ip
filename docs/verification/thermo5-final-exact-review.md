# Final exact-bin review follow-up

Product RTL remains frozen at 635be681046b3ab7d6fdda7f4e9818d7226efd66.
The existing homogeneous 586-Test baseline is retained; this task changes
review metadata and adds an isolated Formal harness, not product RTL.

## Historical root-cause metadata repair

The refreshed candidate_review_11419.csv.gz repairs precisely 2,448 empty
analysis_group values using the original semantic-ID matched candidate_batch:
2,328 EF2_PAIR_LOOKAHEAD_ZERO -> F_EF2_PAIR_LOOKAHEAD_ZERO and 120
DPD_ACTIVE_TAPS_MAX1 -> G_DPD_ACTIVE_TAPS_MAX1. Every other field is unchanged,
including all IDs, source hashes, waiver links and pending approval fields.
The original evidence file remains untouched. The 371 official Waiver IDs
are preserved. No exclusion scope change or official .el is generated.

## Native condition identity repair

The old lookup matched vector strings at the same source line without
separating whole expressions from subexpressions. At DPD line337, both
valid && (sat_i || sat_q) and sat_i || sat_q contain native vector 01.
The former is Condition1/checksum2039843616; the latter is
Condition2/checksum3126875016. The missing whole-expression vector 01 is
Invalid with saturation, not Q-only saturation. The new ledger uses semantic
expression identity and native object containment to disambiguate them.

All 24 previously ambiguous rows resolve to a unique native object/vector.
The 231-row ledger now has 223 exact vector/direction mappings and eight
unresolved native mappings. Mapping is not approval. The eight remaining
entries include two companion DPD History lines, three interpolator lines
sharing native blocks and three flattened branch vectors. They stay OPEN
for native mapping acceptance; no scope is widened to suppress them.

## Reviewer and counter scope

The user designated Preston as independent Reviewer. This records reviewer
assignment only. No per-bin decision, approval reference or approval timestamp
has been supplied. All candidate approval fields remain pending; approved
exclusions=0. Counter scope authority has not been established. The 930
legally reachable counter directions remain OPEN; the existing 32-bit block
carry/wrap/reset/stall evidence supports a separate product-owner acceptance
request, not a PROVEN_UNREACHABLE exclusion and not an automatic URG increase.

## Coverage and final decisions

No product simulation or random-seed expansion was needed for the metadata
repair. Actual URG delta=0; the retained frozen same-input reports remain:
Branch526/637, Condition664/849, Line3352/3796, Toggle92640/104480.
Official Adjusted equals Raw. Analysis-only What-if remains Branch526/529,
Condition664/741, Line3352/3363, Toggle92640/93710, with 1,161 gaps.
The 109 candidate decisions remain pending independent approval; 122
unresolved non-counter entries and all 930 counters remain OPEN unless a
subsequent exact proof record explicitly updates their technical disposition.
No new VCD witness or Exact Hit is claimed by this Formal/metadata update.
Legal assertions retain zero failures; the prior four expected-negative tests
remain separately classified. Full Linux DV and Code Coverage Signoff OPEN.

## DPD invalid-saturation proof milestone

The completed base proof independently proves eight tap-enable/valid alignment
lemmas, Invalid term zero and Invalid pair sum zero. The Tcl runner checks
those ten exact PROVEN results before promoting them. Under only those proven
facts plus initialized reset, Invalid final sum zero and Invalid no-saturation
are PROVEN non-vacuously; the target Invalid+saturation cover is UNCOVERABLE.
Normal output and valid-to-invalid covers reach depths 12/13. Coefficients,
samples, valid and downstream ready are arbitrary; this is not Identity-only.
The frozen MAX_TAPS=1/USE_EXTERNAL_TAPS=1 leaf matches all 16 lane instances.
Product boundary transfer and independent acceptance remain review obligations.

This moves 16 DPD rows from unresolved technical reachability to pending
EXCLUSION_CANDIDATE: total candidates125, unresolved106. No official bin is
closed before approval; What-if stays1161 and Counter OPEN930. The remaining
vector DPD ready/valid Condition is still OPEN. No counter deposit or product
VCD/URG hit is claimed by this proof. An initial incomplete-source blackbox
run and two session-lock failures were discarded; an uncomposed proof timed
out and remains inconclusive. Complete proof reports are under dpd_invalid_proof.
Code Coverage Signoff OPEN; Full Linux DV Signoff OPEN.
