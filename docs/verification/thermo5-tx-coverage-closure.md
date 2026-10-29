# Thermo5 TX product coverage closure — Linux baseline

**Date:** 2026-10-30 (Asia/Singapore)
**Disposition:** `PRODUCT_RAW_100_OPEN; FUNCTIONAL_COVERAGE_OPEN; NOT_SIGNED_OFF`
**Base:** PR #5 head `0c974aa45b8875794d33195530242320b419c249`
**Machine-readable evidence:** [`thermo5-tx-product-coverage-evidence.json`](thermo5-tx-product-coverage-evidence.json)

This report establishes the first product-only URG denominator for the actual
Thermo5 GT-parent TX configuration. It preserves PR #5's historical Gate 3
evidence unchanged. PR #5's AXI-Lite merge includes nonidentity 2/4-tap DPD
candidate VDBs, so its 84.59% aggregate remains valid for that combined
campaign but is not the one-tap product score. The current product run uses
the true one-tap identity configuration and excludes all candidate VDBs.

## Task 1 — dependency and evidence audit

The four pull requests are stacked, currently open, and mergeable. Each PR
uses the previous PR branch as its base; none has been merged into `thermo5`.

| PR | Gate | Base → head | Head SHA |
| --- | --- | --- | --- |
| [#2](https://github.com/cwu766485-ctrl/dsm_ip/pull/2) | Gate 0 baseline | `thermo5` → `codex/thermo5-tx-gate0-baseline` | `494fb2c3cbb9aa964a589bf0b5aa545cdabf6fe6` |
| [#3](https://github.com/cwu766485-ctrl/dsm_ip/pull/3) | Gate 1 algorithm A/B | #2 head → `codex/thermo5-tx-gate1-algorithm-ab` | `813db9c9a488b033dc4686553cbe3a06856acc0b` |
| [#4](https://github.com/cwu766485-ctrl/dsm_ip/pull/4) | Gate 2 worst-case model | #3 head → `codex/thermo5-tx-gate2-worst-case` | `d65ac3762d344c1001552890ae81cd9d243a4910` |
| [#5](https://github.com/cwu766485-ctrl/dsm_ip/pull/5) | Gate 3 coverage closure | #4 head → `codex/thermo5-tx-gate3-coverage` | `0c974aa45b8875794d33195530242320b419c249` |

The Gate 3 evidence manifest's 84 source-file hashes match the PR #5 tree;
all 22 individually listed artifact hashes match the local artifacts. Its
gzip ledger has 22,720 open records and no exclusions or denominator edits.
The manifest also records 12 directory-tree digests. Seven reproduce exactly
using its stated algorithm; five do not. Their file counts and total byte
counts match, but the recomputed tree SHA-256 values differ:

| Historical tree | Published SHA-256 | Recomputed SHA-256 |
| --- | --- | --- |
| `generic_vcs` | `93d3904642874c07c4cf7c5d058bfbfcba7a26108e4156269c496c28de119794` | `2b46560f0a9f60129e320e20d01b171193734d4daaf2bbf9d7c70fa11cc7428a` |
| `axil_vcs` | `275ddd31695388c5f3ce4c8f5a3a87ccd5b1b44b35435bd224c45fef9d2b5d09` | `1f22510ac847b915673dcf10730c93ee66d6fd3bbfde0273c8f0ef7618319ea5` |
| `ef2_qualification` | `80d0a2780ccaf0fbc9640bdc86a8dc77c2389410e177f7390f3cde1e30846803` | `333bbc6dc9ff1590386339bb5af0a8cbe8ca09972aace24ce6fbf3f84ed80242` |
| `axil_ef2_qualification` | `de29a13010cff4f1439252c29d89c1655b9ad0c830ca7fe5549225730c923fd1` | `e4cd57f2a46e2d3ce1da78a683cfcda5f7a0ee7efaf96d533d8fd03ef1b7be7d` |
| `formal` | `c0c658d9faf8646203d868743f3ea8d7e8b987020eb19534bf0d6ef17cfd6e8b` | `4ac536db8af2c018d50a3736c8d022738cfe08ac540fee3398a90813fdf7a34b` |

This reproducibility discrepancy remains open. We did not rerun the complete
regressions or replace the published historical hashes. The individually
hashed logs, summaries, and reports match. Separately, the scope correction
here is that the previous AXI-Lite aggregate included 2/4-tap candidate VDBs,
while the GT parent instantiates one tap with identity coefficients.

## Task 2 — current GT-parent product configuration

The source of truth is
[`thermo5_qsfp_gt14_parent.sv`](../../fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv):
centered-cubic interpolation, `TIDSM_ORDER=2`, `STEP=5120`,
`DPD_MAX_TAPS=1`; its reset coefficient image is identity. The VCS DUT is the
actual AXI-Lite TX frontend interface with that same one-tap identity image.
The Linux run selects the Generic async FIFO in place of the parent's default
XPM FIFO, as required for this host. The external GT Wizard and raw64 wrapper
are not elaborated in this UVM testbench.

VCS code coverage is restricted to `thermo5_sku_uvm_tb.dut` using
[`thermo5_tx_product_coverage.hier`](../../dv/uvm/sim/thermo5_tx_product_coverage.hier).
The testbench/UVM functional groups are reported separately. The hierarchy
does not include uninstantiated PAIR_LOOKAHEAD or nonidentity 2/4-tap candidate
configurations. No RTL behavior, frozen algorithm, denominator, or VDB was
modified to improve the score.

Five selected product-config tests passed: AXI-Lite register access, one-tap
identity configuration with four-plane bit-true checking, EF2 positive and
negative clamp/stall/reset, graceful STOP/drain, and STOP/restart. Each run
reported zero UVM errors and fatals. The existing full regression, formal,
mutation and Gate 0–3 PASS results from PR #5 were retained and not repeated.
The literal VCS compile line is preserved in
`runs/thermo5_tx_product_axil_cov_20261030/compile.log`. These Makefile
settings recreate that compile and selected test set:

```bash
export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
RUN_DIR="$PWD/runs/thermo5_tx_product_axil_cov_20261030"
VECTOR_DIR="$PWD/runs/uvm_thermo5_i2_d1/vectors"
make -C dv/uvm/sim thermo5-vcs \
  THERMO5_OUT="$RUN_DIR" THERMO5_VECTORS="$VECTOR_DIR" \
  THERMO5_FIFO_IMPL=generic THERMO5_USE_AXIL=1 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_tx_product_coverage.hier"

make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_OUT="$RUN_DIR" \
  THERMO5_VECTORS="$VECTOR_DIR" THERMO5_USE_AXIL=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_register_access_test UVM_SEED=420100
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_OUT="$RUN_DIR" \
  THERMO5_VECTORS="$VECTOR_DIR" THERMO5_USE_AXIL=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_product_identity_test UVM_SEED=610801
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_OUT="$RUN_DIR" \
  THERMO5_VECTORS="$VECTOR_DIR" THERMO5_USE_AXIL=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_ef2_corner_test UVM_SEED=271030
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_OUT="$RUN_DIR" \
  THERMO5_VECTORS="$VECTOR_DIR" THERMO5_USE_AXIL=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_graceful_stop_test UVM_SEED=420108
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_OUT="$RUN_DIR" \
  THERMO5_VECTORS="$VECTOR_DIR" THERMO5_USE_AXIL=1 \
  THERMO5_TESTNAME=thermo5_sku_axil_stop_restart_test UVM_SEED=610215
```

URG merged only the six design/test VDBs in this run directory: `simv.vdb`
and the five named test VDBs. No `.el` file was passed to URG.

### Raw DUT code coverage

All counts are raw URG `PROJECT_RTL` bins from the new product-only report.
The coverage denominator contains only the elaborated DUT main chain.

| Metric | Covered / total | Missing | Raw / adjusted coverage |
| --- | ---: | ---: | ---: |
| Aggregate URG | — | — | 75.96% / 75.96% |
| Line | 3,190 / 3,796 | 606 | 84.0358% / 84.0358% |
| Condition | 579 / 846 | 267 | 68.4397% / 68.4397% |
| Branch | 440 / 637 | 197 | 69.0738% / 69.0738% |
| Toggle, both directions | 82,919 / 104,478 | 21,559 | 79.3650% / 79.3650% |
| FSM states | 13 / 13 | 0 | 100.0000% / 100.0000% |
| FSM transitions | 15 / 22 | 7 | 68.1818% / 68.1818% |
| DUT assertions (URG score) | 13 / 15 attempted | 2 uncovered; 2 without attempts | 86.67% / 86.67% |

The assertion report has zero failures in this legal-only run. Two
unattempted assertions are shown separately from the attempted-score
denominator; no failure or uncovered status is converted into a pass.

### Functional coverage

URG reports eight groups at an aggregate score of 97.97%. Six groups are
100%; `core_cg` is 87.50% and `source_cg` is 96.30%. Remaining observed bins
include the intentionally untested illegal-frame bin
`core_cg.cp_illegal.bad_frame` and one of three
`source_cg.cp_packet_quanta` bins. This was a selected legal product campaign,
not the full feature-matrix closure. Task 4 will separate legal and negative
campaign reports and close all applicable bins with monitor-observed
stimulus/checkers.

### Candidate-only reports

The existing four nonidentity 2/4-tap DPD VDBs are summarized independently
under `runs/thermo5_tx_candidate_cov_20261030/candidate_dpd/report`; their
DPD elaboration uses `DPD_MAX_TAPS=4`. Raw aggregate is 70.94% (line
3,273/3,796; condition 489/846; toggle 94,683/120,990; branch 394/637;
FSM states 13/13 and transitions 15/22; assertion score 73.33%). These
candidate statistics are not merged into the product denominator.

`PAIR_LOOKAHEAD=1` remains a separate Gate 1 experiment. It is not instantiated
in the product DUT and its VCS/Formal evidence is not mixed into either URG
report.

## Task 3 — waiver and exclusion audit

[`thermo5_tx_waivers.csv`](thermo5_tx_waivers.csv) is an empty, schema-checked
approval ledger. Each future row must identify the exact configuration,
instance, file/line, metric/bin, rationale, proof artifact and hash, source
hash, reviewer, approval reference, and tool directive. No waiver has been
approved.

[`thermo5_tx_main.el`](../../dv/uvm/sim/thermo5_tx_main.el) contains only
comments. The automated gate rejects every non-comment directive and every
waiver row. This first revision intentionally fails closed rather than
producing an adjusted report without a reviewed, reproducible URG flow.
With zero exclusions, adjusted coverage is exactly the raw result; it is not
a second score. Future waivers require a separate reviewed change that keeps
raw reports and bins intact and reproduces the adjusted report from those
same VDBs.

Run the audit after URG:

```bash
python3.12 tools/hw/thermo5_tx_coverage_gate.py \
  --raw-summary runs/thermo5_tx_product_axil_cov_20261030/product_raw/raw_code_coverage.json/summary.json \
  --groups-html runs/thermo5_tx_product_axil_cov_20261030/product_raw/report/groups.html \
  --waivers-csv docs/verification/thermo5_tx_waivers.csv \
  --el-file dv/uvm/sim/thermo5_tx_main.el \
  --source-manifest docs/verification/thermo5-tx-product-coverage-evidence.json \
  --output runs/thermo5_tx_product_axil_cov_20261030/product_coverage_gate.json
```

The normal command returns an audited status of `RAW_100_OPEN`; adding
`--require-closed` returns a nonzero exit while any required raw bin remains
open. The gate verifies every compiled-source SHA-256 and its own source SHA,
reports raw and adjusted counters side by side, and refuses active `.el`
directives, waiver rows, stale hashes, or hidden denominator changes.

## Evidence and next step

The raw URG report, VDBs, five UVM logs, full VCS compile transcript, and
source-mapped 22,636-row product gap ledger are retained under the ignored
`runs/thermo5_tx_product_axil_cov_20261030/` directory. Their SHA-256 values
are indexed in the machine-readable evidence manifest. The 2/4-tap candidate
report and historic PR #5 evidence remain separate.

**Result for Tasks 1–3:** dependency/evidence audit complete; the actual
product configuration has a distinct raw coverage baseline; waiver/exclusion
controls fail closed. Raw code and selected-campaign functional closure
remain open. Task 4 begins with AXI-Lite FSM transitions, then reachable
branch/condition/line/toggle opportunities. Real XPM, GT Wizard and FPGA PPA
remain outside this Linux result.
