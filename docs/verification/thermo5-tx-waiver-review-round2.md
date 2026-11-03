# Thermo5 TX Waiver Candidate Review — Round 2

Date: 2026-11-03 (Asia/Singapore)<br>
Product RTL source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`<br>
Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120,
20-bit state; DPD_MAX_TAPS=1, Identity reset image; AXI-Lite; Generic FIFO.

## Review result

All 371 existing waiver rows were rebound to the current source-linked Raw
OPEN-bin ledger and product compile manifest. The audit classified 361 rows as
fixed-configuration candidates and 10 as Formal candidates. This classification
is evidence for review; it does not authorize an exclusion.

| Status | Count |
|---|---:|
| Pending review | 371 |
| Approved | 0 |
| Rejected | 0 |
| Active URG exclusions | 0 |

The generated `.el` contains only its generator comments and no active
directives. Raw coverage remains unchanged by the waiver pipeline, and Adjusted
coverage is the same as Raw.

## Bound evidence

- Product compile manifest: 90 source entries, product configuration
  fingerprint `cb7edb33f8b5cf7bf82141e2995b5333714a6aadd56b5526a7f8df3cc9c434af`.
- Raw/Adjusted VDB inventory: 245 test VDBs; canonical inventory SHA-256
  `17bc56a42ec7c9dc471a513dd419f75585d6246bcd6f7c44e8238e2aceb592f9`.
- Candidate audit input report SHA-256
  `81eb9244fd3f79900961b5185234b695c249808b6197199bda15774b3431df24`.
- Final Raw/Adjusted report SHA-256
  `13ea61913a1ba2c99b77258940f1f15dc92e3c4068b8e4f9adee6ab716cb6c10`.
- The candidate audit input report and final report have the same exact 245
  VDB paths, tree hashes, and product configuration fingerprint. The first
  report breaks the evidence-generation dependency cycle; the final report is
  generated afterward using the candidate-bound zero-approval pipeline audit.
- Current code coverage remains `RAW_100_OPEN`: Branch 525/637, Condition
  658/849, Line 3351/3796, Toggle 84180/104480, FSM states 13/13 and
  transitions 17/22. Root-Cause Ledger: 21,053 OPEN records in 457 groups.

The exact candidate records and audit hashes are in
[`thermo5-tx-waiver-candidate-audit.json`](data/thermo5-tx-waiver-review-round2/thermo5-tx-waiver-candidate-audit.json).
The pipeline result is in
[`thermo5-tx-waiver-pipeline-audit.json`](data/thermo5-tx-waiver-review-round2/thermo5-tx-waiver-pipeline-audit.json).
Formal snapshots referenced by the candidates are preserved beside them.

## Checks

- Current-source candidate audit: **PASS**, 371/371 rows mapped; no approval
  or exclusion was generated.
- Waiver pipeline: **PASS**, 371 pending, zero approved/rejected, zero active
  exclusions.
- Final same-list Raw/Adjusted URG: **PASS**, 245 exact test VDBs; Raw and
  Adjusted summaries match.
- Final fail-closed Coverage Gate: **PASS**, status `RAW_100_OPEN`; legally
  applicable functional bins 392/392.

The two outstanding-counter Formal properties remain INCONCLUSIVE. They are
not included among the 10 proven Formal candidates. No waiver is approved by
this report; an independent reviewer and exact approval record are required
before an exclusion can be activated.
