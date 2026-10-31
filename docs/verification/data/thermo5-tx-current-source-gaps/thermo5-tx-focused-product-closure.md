# Thermo5 TX Coverage Root-Cause Closure — Step 1/2

- Raw VCS/URG product source SHA: 19d295360aa6438f4af20e7a6ab44bfebf2fc1ea; the Raw report and source ledger are bound to this source manifest.
- Current-tree source manifest mismatches: 0 (none). Only the three hash-bound diagnostic testbench files are accepted as separate read-only instrumentation; their VDB is not merged into baseline Raw. DUT RTL and the coverage model are unchanged.
- Raw gap ledger: 21,732 rows; SHA-256 4211ad741bd3be0aecc5b9a07d91c3f704304cbc23514a42eeae3d9f14943c78.
- Expression-aware semantic IDs: 21,732; old ID collisions: 17 groups, 17 extra rows.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.
- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.
- Raw equals Adjusted; approved waivers 0; exclusions 0.

## Functional Group Report audit

The provided product Group Report contains 210/214 denominator-eligible bin records across covergroup-type and monitor-instance views. This includes generated cross bins; the earlier 170/174 tally omitted 40 EF2 cross-bin records and is superseded. Four zero-hit records are two semantic illegal-frame bins repeated in the two report views. Separate negative URG evidence hits them; the Raw records remain in the denominator and are not legal positive-product stimulus.

| Group | Raw bin hits / denominator | Uncovered |
|---|---:|---:|
| core_cg | 14/16 | 2 |
| ef2_cg | 68/68 | 0 |
| plane_atomic_cg | 16/16 | 0 |
| read_cg | 22/22 | 0 |
| reset_cg | 4/4 | 0 |
| source_cg | 38/40 | 2 |
| stop_restart_cg | 12/12 | 0 |
| write_cg | 36/36 | 0 |

The complete bin CSV has 226 rows: 214 scoreable Raw records and 12 bins already marked Illegal/Excluded by the URG model. These model statuses are listed transparently; no URG exclusion directive or waiver was added. See `thermo5-tx-functional-bin-detail.csv` for every group, coverpoint/cross, bin, count, report view, and source-page SHA.

| Exact URG scope | Raw product hits | Separate negative hits | Classification |
|---|---:|---:|---|
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.source_cg.cp_packet_quanta.malformed_early | 0 | 1 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_pkg::thermo5_sku_coverage::core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |
| thermo5_sku_uvm_tb.me.obj.core_cg.cp_illegal.bad_frame | 0 | 49 | ILLEGAL_TEST_ONLY; NOT_APPLICABLE |

Legally applicable positive bins are 210/210. The four Raw zero-hit report rows remain visible in the denominator.

## Code coverage and root-cause task inventory

| Metric | Raw covered / total | Raw missing | Closure tasks |
|---|---:|---:|---:|
| branch | 520/637 (81.6327%) | 117 | 48 |
| condition | 601/849 (70.7892%) | 248 | 107 |
| line | 3,334/3,796 (87.8293%) | 462 | 114 |
| toggle | 83,575/104,480 (79.9914%) | 20,905 | 201 |

The task CSV has 470 source/instance/location-rooted tasks. The compressed bin ledger preserves all 21,732 source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. Every row is OPEN at this audit stage.

| Metric / root-cause hypothesis | Raw gap rows |
|---|---:|
| branch / CDC_OR_RESIDUAL_STATE | 1 |
| branch / FIXED_PRODUCT_CONFIGURATION | 21 |
| branch / GUARDED_ADDRESS_DECODE | 2 |
| branch / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 91 |
| branch / PRODUCT_CADENCE_ALIGNMENT | 2 |
| cond / INTERPOLATOR_EMPTY_OR_BLOCKED | 4 |
| cond / RESET_RELEASE_OR_STATE_HOLD | 244 |
| line / CDC_OR_RESIDUAL_STATE | 7 |
| line / DPD_TAP_HISTORY_CONFIGURATION | 176 |
| line / FIXED_PRODUCT_CONFIGURATION | 244 |
| line / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 35 |
| toggle / CDC_OR_RESIDUAL_STATE | 130 |
| toggle / COUNTER_HIGH_BITS | 640 |
| toggle / DATA_VALUE_OR_TOGGLE_STIMULUS | 6,262 |
| toggle / DPD_TAP_HISTORY_CONFIGURATION | 8,192 |
| toggle / FIXED_PRODUCT_CONFIGURATION | 1,889 |
| toggle / IDENTITY_DPD_ARITHMETIC | 3,792 |

This source-linked audit uses the fresh licensed VCS/URG report recorded in `runs/thermo5_cdc_resetready_repro_20261031/current_coverage_gate_13tests/coverage-refresh-evidence.json`. The Raw report was regenerated from two fresh targeted product tests plus retained exact-source VDBs; no full regression was rerun. No Raw/Adjusted denominator changed.

## Evidence inputs

- Raw Group Report: runs/thermo5_cdc_resetready_repro_20261031/product_focused_urg_product_13tests
- Separate expected-negative Group Report: runs/thermo5_cdc_resetready_repro_20261031/product_negative_urg_illegal_frame
- Source-linked gap ledger: runs/thermo5_cdc_resetready_repro_20261031/gap_ledger_13tests/out/thermo5-tx-gate3-coverage-ledger.csv
- Source manifest: runs/thermo5_cdc_resetready_repro_20261031/gap_ledger_13tests/out/axil_gap_ledger.json
- Closure evidence JSON: docs/verification/data/thermo5-tx-cdc-resetready-evidence.json

## Current-source Formal disposition update — `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`

The source-bound review closed 5 exact bins as PROVEN_UNREACHABLE; 21727 remain OPEN. Formal Inconclusive is not a closure. Raw URG and its denominator are unchanged; approved waivers and active .el exclusions are both zero.

| Semantic Bin ID | Assertion | Cover | Disposition |
|---|---|---|---|
| `TXB-0260d31bb5bee4f1a4c6` | `thermo5_cdc_default_branch_harness.a_exact_default_path_unreachable` | `thermo5_cdc_default_branch_harness.c_exact_default_path` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-3df5f13a8d51ee9bdea5` | `thermo5_axil_cfg_coverage_harness.a_write_case_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_write_case_default_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-65f3dfeee7bc0b854f52` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-74a3bacf0956921ac9bf` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-85afd49f35a994cc290c` | `thermo5_cdc_end_remaining_harness.a_end_remaining_false_arm_unreachable` | `thermo5_cdc_end_remaining_harness.c_target_false_arm` | PROVEN_UNREACHABLE; retained in Raw |

Reviewed candidates with tautological or otherwise invalid Formal evidence remain OPEN:

| Semantic Bin ID | Status | Reason |
|---|---|---|
| `TXB-04e9d574fb6ea4ead927` | OPEN | PAIR_LOOKAHEAD parameter assertions/covers in the exact-product VC Formal run were marked SVAC-TAUT-PROPERTY/SVAC-TAUT-COVER. Their proven/uncoverable labels are tool tautology outcomes, not a non-vacuous reachability proof; retain the Raw branch bin pending a non-tautological proof or exact elaboration review. |
| `TXB-054d97a87a8d74c36c8b` | OPEN | MAX_TAPS=1 assertion/Cover is tautological at compile time; no unreachable disposition accepted. |
| `TXB-1d51526aa2408931cc40` | OPEN | PAIR_LOOKAHEAD parameter assertions/covers in the exact-product VC Formal run were marked SVAC-TAUT-PROPERTY/SVAC-TAUT-COVER. Their proven/uncoverable labels are tool tautology outcomes, not a non-vacuous reachability proof; retain the Raw branch bin pending a non-tautological proof or exact elaboration review. |
| `TXB-58579fd96d9947af37f8` | OPEN | PAIR_LOOKAHEAD parameter assertions/covers in the exact-product VC Formal run were marked SVAC-TAUT-PROPERTY/SVAC-TAUT-COVER. Their proven/uncoverable labels are tool tautology outcomes, not a non-vacuous reachability proof; retain the Raw branch bin pending a non-tautological proof or exact elaboration review. |
| `TXB-c318c70882fc01f2dc58` | OPEN | PAIR_LOOKAHEAD parameter assertions/covers in the exact-product VC Formal run were marked SVAC-TAUT-PROPERTY/SVAC-TAUT-COVER. Their proven/uncoverable labels are tool tautology outcomes, not a non-vacuous reachability proof; retain the Raw branch bin pending a non-tautological proof or exact elaboration review. |
| `TXB-c79cdf2b9f5b4620688e` | OPEN | a_plain_append_arm_disabled is reported tautological; no unreachable disposition accepted. |
