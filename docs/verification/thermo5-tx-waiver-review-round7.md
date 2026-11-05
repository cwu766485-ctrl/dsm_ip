# Thermo5 TX Waiver Candidate Rebind — Round 7

Date: 2026-11-03<br>
Product RTL SHA: `1236d49c72360aa62e316aea147528d93a1b3705`<br>
Product configuration: Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 /
20-bit state, `DPD_MAX_TAPS=1`, Identity reset image, AXI-Lite, Generic FIFO.

## Audit result

All 371 candidate rows were rebound after the focused Formal Review JSON
changed to include the latest extended counter result. The current review is
bound to the 247-test Raw/Adjusted report, the exact product compile manifest,
and the 20,893-record Raw open-bin ledger. The audit classifies 361 rows as
`CONFIG_UNREACHABLE` candidates and 10 as `FORMAL_UNREACHABLE` candidates.
These categories are audit evidence for independent review; they are not
approvals or automatic bin exclusions.

The fail-closed pipeline result is:

| Status | Count |
|---|---:|
| PENDING | 371 |
| Approved | 0 |
| Rejected | 0 |
| Active Exclusions | 0 |

The generated `.el` file contains only its generator header and no directives.
Raw and Adjusted remain equal. The candidate audit made no Raw status or
denominator changes. The outstanding-counter guards remain OPEN after the
extended Inconclusive Formal run; that result is not used to disposition any
candidate.

## Input binding and hashes

| Input | SHA-256 |
|---|---|
| Focused product Formal Review JSON | `029324fcb2f3d06ab5b66fc70af01d942584bd1753e842bac0224b7ece09f004` |
| Product compile manifest | `555df0d679b8f3711aa2c345cd46b8801c0d48a58bf6d1eaeba6bf043c7012f9` |
| 247-test Raw/Adjusted report manifest | `89a160024a966e65f1bd7db279bc2f6acef3ae7197698bace17a8942838e4840` |
| 247-test VDB manifest | `dd85345f197cb05f5aa60713b78269c3347ff3b786da4f501de6ef7676a77fa7` |
| Raw open-bin ledger | `5af91e5eb977d8dc9a3b093c9a682e2830119448c43eb41f9e0f4e768cb6e4ff` |
| Candidate audit | `53e1f26dc2cf6f78aba437815b65a141ab266f6d183a57a1f4b089572202519b` |
| Pipeline audit | `6f90202261f45003ff89399e4bee1376301a88dafb499c0b9f098ec1e91b3a03` |
| Waiver CSV | `8856e9c88d443df7379a070f4da1dc53e214c2dd09183bab4a3c322d304979bd` |
| Generated inactive `.el` | `57d1f80c4862394d1a6e0fb0c12ed1ba57543d3b8e6d1ab8e9dfc452cc78c858` |

Machine-readable results and the per-row audit are in
[`thermo5-tx-waiver-review-round7/`](data/thermo5-tx-waiver-review-round7/).
The candidate audit records all 371 exact Raw Bin IDs, instances, source
positions, reasons, source hashes, product configuration, and evidence links.

## Reproduction

```bash
python3.12 tools/hw/thermo5_tx_waiver_candidate_audit.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --raw-gap-ledger runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_rootcause_final/thermo5-tx-coverage-open-bins.csv.gz \
  --compile-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/frame_replace_sourcefresh_20261103/product_compile_manifest.json \
  --report-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_dual_urg/report_manifest.json \
  --vdb-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_dual_urg/vdb_manifest.json \
  --formal-review docs/verification/data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json \
  --output docs/verification/data/thermo5-tx-waiver-review-round7/thermo5-tx-waiver-candidate-audit.json \
  --snapshot-dir docs/verification/data/thermo5-tx-waiver-review-round7/formal_snapshots \
  --repo-root .

python3.12 tools/hw/thermo5_tx_waiver_pipeline.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --gap-ledger runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/coverage_247_round6_rootcause_final/thermo5-tx-coverage-open-bins.csv.gz \
  --compile-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/frame_replace_sourcefresh_20261103/product_compile_manifest.json \
  --repo-root . \
  --el-output runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/waiver_round7/thermo5_tx_main.el \
  --audit-output docs/verification/data/thermo5-tx-waiver-review-round7/thermo5-tx-waiver-pipeline-audit.json
```

No independent reviewer approval was recorded. Do not enable exclusions or
claim Adjusted coverage beyond Raw until each precise waiver receives a real,
source-bound approval.
