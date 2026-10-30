# Thermo5 TX Coverage Root-Cause Closure — Step 1/2

- Raw VCS/URG product source SHA: c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b; product RTL/UVM compile source hashes match.
- Source manifest mismatches: 1 (dv/uvm/formal/thermo5_axil_cfg_coverage_harness.sv). Any Formal-harness mismatch is reported separately and is not represented as current Formal evidence.
- Raw gap ledger: 18,593 rows; SHA-256 e586d27684fffe4e98b1d4c4bd43b22839c349ef31c07b1779d4a69c4ce45222.
- Expression-aware semantic IDs: 18,593; old ID collisions: 17 groups, 17 extra rows.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.
- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.
- Raw equals Adjusted; approved waivers 0; exclusions 0.

## Functional Group Report audit

Raw URG reports 170/174 hits. The four zero-hit records are two semantic illegal-frame bins, each shown in covergroup-type and monitor-instance views. Separate negative URG evidence hits them. They remain in the Raw denominator and are not legal positive-product stimulus.

| Exact URG scope | Raw product hits | Separate negative hits | Classification |
|---|---:|---:|---|
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |

Legal positive semantic bins are 170/170. The four Raw zero-hit report rows remain visible; Raw is still 170/174.

## Code coverage and root-cause task inventory

| Metric | Raw covered / total | Raw missing | Closure tasks |
|---|---:|---:|---:|
| branch | 440/637 (69.0738%) | 197 | 53 |
| condition | 583/846 (68.9125%) | 263 | 107 |
| line | 3,190/3,796 (84.0358%) | 606 | 123 |
| toggle | 86,951/104,478 (83.2242%) | 17,527 | 209 |

The task CSV has 492 source/instance/location-rooted tasks. The compressed bin ledger preserves all 18,593 source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. Every row is OPEN at this audit stage.

| Metric / root-cause hypothesis | Raw gap rows |
|---|---:|
| branch / CDC_OR_RESIDUAL_STATE | 4 |
| branch / FIXED_PRODUCT_CONFIGURATION | 92 |
| branch / IDENTITY_DPD_ARITHMETIC | 64 |
| branch / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 37 |
| cond / INTERPOLATOR_EMPTY_OR_BLOCKED | 4 |
| cond / RESET_RELEASE_OR_STATE_HOLD | 259 |
| line / CDC_OR_RESIDUAL_STATE | 7 |
| line / DPD_TAP_HISTORY_CONFIGURATION | 192 |
| line / FIXED_PRODUCT_CONFIGURATION | 244 |
| line / IDENTITY_DPD_ARITHMETIC | 128 |
| line / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 35 |
| toggle / CDC_OR_RESIDUAL_STATE | 130 |
| toggle / COUNTER_HIGH_BITS | 640 |
| toggle / DATA_VALUE_OR_TOGGLE_STIMULUS | 3,452 |
| toggle / DPD_TAP_HISTORY_CONFIGURATION | 8,192 |
| toggle / FIXED_PRODUCT_CONFIGURATION | 793 |
| toggle / IDENTITY_DPD_ARITHMETIC | 4,320 |

This was a deterministic re-analysis of the fixed-SHA VCS/URG evidence. No simulator was rerun, no new hit was claimed, and no Raw/Adjusted denominator changed.

## Evidence inputs

- Raw Group Report: runs/thermo5_tx_product_axil_reset_cov_20261030/product_raw_after_source_gap_current_20261030
- Separate expected-negative Group Report: runs/thermo5_tx_product_axil_register_access_20261030/negative_expected_assertions/report
- Source-linked gap ledger: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/thermo5-tx-gate3-coverage-ledger.csv
- Source manifest: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/axil_gap_ledger.json
- Closure evidence JSON: docs/verification/thermo5-tx-linux-coverage-closure-evidence.json
