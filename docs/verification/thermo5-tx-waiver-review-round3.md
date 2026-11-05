# Thermo5 TX Waiver Candidate Audit — Round 3

Date: 2026-11-03<br>
Product source SHA: `1236d49c72360aa62e316aea147528d93a1b3705`<br>
Product configuration: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, `DPD_MAX_TAPS=1`, Identity reset image, AXI-Lite, Generic FIFO.

## Audit result

The 371 existing waiver candidates were re-evaluated against the current
product compile manifest, the 246-test Raw/Adjusted VDB inventory, and the
current Raw open-bin ledger. The mechanical candidate dispositions are 361
`CONFIG_UNREACHABLE` and 10 `FORMAL_UNREACHABLE`; these are review categories,
not approvals. Every CSV row remains `PENDING`. There are zero approved
waivers, zero rejected waivers, and zero active URG Exclusions.

No Raw bin denominator or status was changed. Raw and Adjusted reports use the
same 246 test VDBs plus one design VDB and are numerically identical. The
coverage gate remains `RAW_100_OPEN`.

## Evidence binding

The machine-readable
[`candidate audit`](data/thermo5-tx-waiver-review-round3/thermo5-tx-waiver-candidate-audit.json)
binds the audit to:

- product configuration fingerprint
  `eee9f68e23fbe0d4c18f6b43b152ba2306c11bd39b2a46637b4f33d34e4a08aa`;
- compile manifest SHA-256
  `0b076347c363c428c3ac755984fafe1b86786b721a90ed2ab4745a566ce8f39e`;
- 246-test VDB manifest SHA-256
  `6402a4570b3a56bbe8054903227936838c3afd2eb5ca6f1b708568a78a38896d`;
- open-bin ledger SHA-256
  `5af91e5eb977d8dc9a3b093c9a682e2830119448c43eb41f9e0f4e768cb6e4ff`;
- the current fixed-product formal review and its evidence snapshots.

The
[`pipeline audit`](data/thermo5-tx-waiver-review-round3/thermo5-tx-waiver-pipeline-audit.json)
confirms 371 pending rows, 0 approved rows, and an empty effective `.el`
Exclusion set. URG was then rerun using that pipeline output and the same VDB
inventory; its final report manifest is recorded in the
[`long-stream stress evidence`](data/thermo5-tx-outstanding-counter-stress-20261103.json).

The candidate and pipeline audits are ready for independent review. They do
not constitute reviewer approval. No Exclusion may be enabled until an
authorized review records a real reviewer, approval reference, exact Bin
scope, and current source/configuration evidence.
