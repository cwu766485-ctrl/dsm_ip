# Thermo5 TX Gate 1 — Waiver Candidate Audit, Round 1

**Date:** 2026-11-03 (Asia/Singapore)

**Status:** `CANDIDATE_AUDIT_PASS; REVIEW_PENDING; RAW_100_OPEN`

**Branch:** `codex/thermo5-tx-waiver-audit-round1`, based on Draft PR #30's
`codex/thermo5-tx-w1c-coverage-round2` head `08061386900e5ae2c9f692dcf7e85d849623f818`
**Product RTL source SHA:** `1236d49c72360aa62e316aea147528d93a1b3705`

This round implements Gate 1 evidence rebinding and the fail-closed audit
pipeline. It does not approve waivers, change Raw URG records, or alter the
coverage denominator. No product RTL or algorithm changed.

## Product and evidence scope

The audited elaboration is the AXI-Lite TX product: Centered-Cubic x2+x2,
EF2 ORDER=2 / STEP=5120 / 20-bit state, four 64-bit PA planes,
`DPD_MAX_TAPS=1` with Identity reset image, and Generic FIFO. The product VCS
top is `thermo5_sku_uvm_tb`.

The product compile manifest was derived from the retained VCS compile
transcript and source manifest. It records 88 parsed local sources and 90
source/flow entries, uses the expected product defines and filelist, and has
no parent-manifest source omitted from the compile transcript. The compile
transcript SHA-256 is
`5639f35f0fb0ba95b31c1a27184e9fe9e30b99fca713c0222386985dc933ff26`.
This round did not rerun VCS or VC Formal; it revalidated the retained compile,
VDB, URG, and Formal artifacts against current tracked source hashes.

Raw and Adjusted URG evidence both bind the same design VDB plus 244 test
VDBs. Their ordered VDB inventory and coverage summaries match. The inherited
W1C Round 2 product Raw baseline remains:

| Metric | Raw | Adjusted | Missing |
| --- | ---: | ---: | ---: |
| Branch | 523/637 | 523/637 | 114 |
| Condition | 656/849 | 656/849 | 193 |
| Line | 3337/3796 | 3337/3796 | 459 |
| Toggle, both directions | 84180/104480 | 84180/104480 | 20300 |
| FSM states | 13/13 | 13/13 | 0 |
| FSM transitions | 17/22 | 17/22 | 5 |

There are 21,071 uncovered code records in 475 root-cause groups. All remain
OPEN in Raw. The baseline reports 392/392 legally applicable functional bins;
this round did not rerun the functional regression.

## Candidate dispositions

All 371 CSV rows map uniquely to a current Raw bin by configuration,
instance, source file, line, metric, and exact Raw Bin ID. Every source hash
matches the current source-linked Raw ledger and repository file. The
candidate audit independently verifies the current product compile profile,
source parameter chain, VDB inventory, and Raw/Adjusted report binding.

| Disposition | Count | Evidence and scope |
| --- | ---: | --- |
| `CONFIG_UNREACHABLE` | 361 | 344 EF2 `PAIR_LOOKAHEAD` candidates plus 17 fixed-parameter branches. Parent instance parameter blocks are parsed and checked through the product hierarchy; every chain source is required in the current compile manifest and hash-checked. |
| `FORMAL_UNREACHABLE` | 10 | Exact source-bound Formal assertion is PROVEN, its matching target Cover is UNCOVERABLE, at least one activity Cover is logged as covered, and snapshots show zero black boxes with only the explicitly allowed frame-tail source-stability assumption. |
| `REACHABLE` | 0 | No candidate was classified reachable. |
| `UNRESOLVED` | 0 | Each historical candidate matched one of the exact configuration or Formal rules. Other open code bins are outside this candidate CSV and remain OPEN. |

The 17 fixed-parameter candidates cover the frame-gain HOLD setting, four GT
width comparisons, DPD tap-count guards, both centered interpolator HOLD
settings, interpolator lane and coefficient guards, and the EF2 shape guard.
The 10 Formal candidates cover three AXI-Lite decode/default records, four
interpolator frame-tail records, and three CDC residual/default records. The
10 Formal runs are archived as five exact source-bound run snapshots.

These are review candidates, not approved exclusions. In particular, the
PAIR look-ahead evidence is an elaboration argument; prior tautological
PAIR-specific Formal goals are not reused as proof. Every candidate's Raw
status and denominator are retained.

## Fail-closed pipeline result

The candidate audit and waiver generator both passed over all 371 rows.
The CSV keeps all 371 rows `PENDING`; the generated native URG file contains
only its two generator comments and no exclusion directives:

| Result | Count |
| --- | ---: |
| Pending candidates | 371 |
| Approved candidates | 0 |
| Rejected candidates | 0 |
| Active `.el` exclusions | 0 |

The pipeline re-derives configuration evidence from current source and
compile-manifest files rather than trusting the candidate JSON's parameter
claims. Formal approval checks also compare activity witnesses with the
archived console output. A stale source, candidate hash, Raw/Adjusted VDB
inventory, parameter value, or Formal snapshot fails closed. Approval fields
and a non-wildcard URG directive are required before generation; this review
round intentionally supplies neither.

## Reproduction and checks

The compile manifest, candidate audit, and `.el` file were generated with:

```bash
python3.12 tools/hw/thermo5_tx_product_compile_manifest.py \
  --compile-log runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/build/compile.log \
  --source-manifest runs/thermo5_tx_closure_current/gate2_axil_w1c_20261103/source_manifest.json \
  --product-filelist dv/uvm/sim/thermo5_sku_filelist.f \
  --coverage-hierarchy dv/uvm/sim/thermo5_product_dut_coverage.hier \
  --output docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-product-compile-manifest.json

python3.12 tools/hw/thermo5_tx_waiver_candidate_audit.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --raw-gap-ledger docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-current-raw-open-bins.csv.gz \
  --compile-manifest docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-product-compile-manifest.json \
  --report-manifest docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-current-raw-adjusted-report-manifest.json \
  --vdb-manifest docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-current-vdb-manifest.json \
  --output docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-waiver-candidate-audit.json \
  --snapshot-dir docs/verification/data/thermo5-tx-waiver-review-round1/formal_snapshots \
  --repo-root .

python3.12 tools/hw/thermo5_tx_waiver_pipeline.py \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --gap-ledger docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-current-raw-open-bins.csv.gz \
  --compile-manifest docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-product-compile-manifest.json \
  --el-output dv/uvm/sim/thermo5_tx_main.el \
  --audit-output docs/verification/data/thermo5-tx-waiver-review-round1/thermo5-tx-waiver-pipeline-audit.json

python3.12 -m unittest discover -s tools/hw/tests -v
python3.12 -m compileall -q tools/hw/thermo5_tx_waiver_pipeline.py tools/hw/thermo5_tx_waiver_candidate_audit.py tools/hw/thermo5_tx_product_compile_manifest.py
git diff --check
```

Results: compile-manifest generation PASS; 371-row candidate audit PASS;
waiver pipeline PASS (371 pending, 0 approved, 0 exclusions); hardware utility
unit tests PASS (34/34); Python compileall PASS. No RTL simulation or URG run
was repeated because no RTL, testbench, compile, or VDB input changed.

## Evidence hashes

| Artifact | SHA-256 |
| --- | --- |
| Raw open-bin ledger | `ae4875c22b7607985c50387622f6c01fd55397cf325d9648dba7a29c4340bdee` |
| Raw/Adjusted URG manifest | `1e8cb00be455be5d779cee57844af8f1f8819d6b09f2e68baa62fd953a29a6b2` |
| VDB manifest | `d01862ed692ba68511d7279c923ea511efa2e3f3cde16dd5664dec45b952fee3` |
| Product compile manifest | `885db4a5e8edbdce82b2486f2cb4523f6b4766abc73a3d83c057af64d2896654` |
| Candidate audit JSON | `ae1cfee343c534495e65e57d75d7ceefea23def8f7344b70259ea3bf429793f6` |
| Pipeline audit JSON | `f75b1cdd2d4e5fa37eb5f8d0ac3411c4ae6b391b2be5e820c935a64a70343a2a` |
| Waiver CSV | `a00e72f572a6f17ee171422052181bf86ebab3639e13d57709c4dd95735ec887` |
| Generated empty `.el` | `57d1f80c4862394d1a6e0fb0c12ed1ba57543d3b8e6d1ab8e9dfc452cc78c858` |

The candidate-level source tuples, source/context hashes, Formal properties,
assumptions, snapshots, and proof results are in
[`thermo5-tx-waiver-candidate-audit.json`](data/thermo5-tx-waiver-review-round1/thermo5-tx-waiver-candidate-audit.json).
The machine-readable fail-closed result is in
[`thermo5-tx-waiver-pipeline-audit.json`](data/thermo5-tx-waiver-review-round1/thermo5-tx-waiver-pipeline-audit.json).
Formal snapshot files are byte-preserved in Git so their recorded hashes are
not changed by line-ending normalization.

## Remaining closure work

This PR requests review of the 371 candidates; it does not approve them. A
real reviewer and approval record are still required before any row can be
marked `APPROVED`. The outstanding counter-guard and DPD Identity Formal
results remain INCONCLUSIVE; they are not part of these 10 proven candidates.
Gate 2 must still close reachable Branch/Condition bins with legal targeted
stimulus and independent checkers, followed by Line/Toggle, FSM and Assertion
work. The overall result remains `RAW_100_OPEN` and Linux signoff remains
partial. Real XPM, GT Wizard, FPGA PPA/routed timing, and physical RF/QAM256
validation remain separate signoff items.
