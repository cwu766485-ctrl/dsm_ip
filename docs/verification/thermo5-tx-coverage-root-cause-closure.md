# Thermo5 TX Coverage Root-Cause Closure — Step 1/2

- Raw VCS/URG product source SHA: c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b; the baseline Raw report remains bound to its original compile source manifest.
- The Raw compile source manifest is pinned to base commit `913be930bfcbbad0f78dbc90e06299db3d1bb337`. Current-tree audit differences are listed in the machine-readable summary: the AXI-Lite interface adds read-only frame probes, the UVM package includes an additive diagnostic test, and the UVM top assigns those probes. Their separate diagnostic VDB was not merged into baseline Raw. All product `rtl/` source hashes and the coverage hierarchy match the baseline; the AXI-Lite Formal harness is outside the product VCS compile.
- Raw gap ledger: 18,593 rows; SHA-256 e586d27684fffe4e98b1d4c4bd43b22839c349ef31c07b1779d4a69c4ce45222.
- Expression-aware semantic IDs: 18,593; old ID collisions: 17 groups, 17 extra rows.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.
- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.
- Raw equals Adjusted; approved waivers 0; exclusions 0.

## Functional Group Report audit

The complete product Group Report contains 210/214 denominator-eligible bin records across covergroup-type and monitor-instance views. This includes generated cross bins; the earlier 170/174 tally omitted 40 EF2 cross-bin records and is superseded. Four zero-hit records are two semantic illegal-frame bins repeated in the two report views. Separate negative URG evidence hits them; the Raw records remain in the denominator and are not legal positive-product stimulus.

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
| branch | 440/637 (69.0738%) | 197 | 53 |
| condition | 583/846 (68.9125%) | 263 | 107 |
| line | 3,190/3,796 (84.0358%) | 606 | 123 |
| toggle | 86,951/104,478 (83.2242%) | 17,527 | 209 |

The task CSV has 492 source/instance/location-rooted tasks. The compressed bin ledger preserves all 18,593 source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. After exact Formal review, 6 rows are PROVEN_UNREACHABLE and 18587 remain OPEN; Raw URG is unchanged.

| Metric / root-cause hypothesis | Raw gap rows |
|---|---:|
| branch / CDC_OR_RESIDUAL_STATE | 3 |
| branch / FIXED_PRODUCT_CONFIGURATION | 105 |
| branch / GUARDED_ADDRESS_DECODE | 2 |
| branch / IDENTITY_DPD_ARITHMETIC | 80 |
| branch / LEGAL_STIMULUS_OR_CHECKER_REVIEW | 5 |
| branch / PRODUCT_CADENCE_ALIGNMENT | 2 |
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

This source-linked audit uses the fresh licensed VCS/URG report recorded in `docs/verification/data/thermo5-tx-final-vcs-refresh.json`. The Raw report was regenerated from two fresh targeted product tests plus retained exact-source VDBs; no full regression was rerun. No Raw/Adjusted denominator changed.

## Clean AXI-Lite Formal refresh (2026-10-31)

VC Formal V-2023.12-SP2 reran the AXI-Lite configuration harness against its current source and the unchanged DUT. The run passed with 4/4 assertions proven, one legal coefficient-read Cover hit, and three exact path Covers reported uncoverable. It used zero environment assumptions, had zero black-box instances and zero setup violations, and reported three non-vacuous assertions. The runner now fails if VC Formal marks any goal as tautological.

This refresh supplies current-source proof evidence for the write-address default branch at `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:246`. A separate fresh run also closes the coefficient-read function default Branch at line 135: `coeff_read_word` is called only after the address guard accepts a coefficient register, and the masked address is one of six defined words. Its exact line-142 default Line bin is linked to the same assertion/Cover pair. The accepted read transaction Cover is hit; the default-arm Cover is uncoverable. Both Raw bins remain in the denominator.

## Current-worktree Raw source audit (2026-10-31)

The fail-closed coverage gate was rerun against the recorded Raw summary and Group Report using `docs/verification/data/thermo5-tx-product-compile-manifest.json`. It returned exit code 3, `FAIL_CLOSED_SOURCE_HASH_MISMATCH`, because the current worktree differs from the baseline compile manifest in the three UVM files listed above. All product RTL hashes in that manifest match; this is a compile-input identity gap, not evidence of a DUT RTL change. The exact command, expected/observed hashes, return code, and log SHA are recorded in the machine-readable root-cause summary and manifest. The prior Raw report remains unchanged and valid for its recorded baseline compile; it is not promoted as an exact-current-worktree compile signoff. No VDB, denominator, waiver, or exclusion was changed to bypass the gate.

The `MAX_TAPS=1` initialization-guard candidate and one interpolator append-arm candidate were removed from the accepted Formal disposition set after their exact properties were identified as tautologies. Both candidates remain OPEN for separately audited evidence; neither has a waiver or exclusion.

## Coefficient-read default Branch closure (2026-10-31)

The source-linked task `TXC-9617be8f4050d3cd1751` was initially mislabeled in its root-cause note as a write-address path. The exact Raw bin `TXB-65f3dfeee7bc0b854f52` is the `default` arm of `coeff_read_word` at `thermo5_dpd_axi_lite_cfg.sv:135`, instance `thermo5_sku_uvm_tb.dut.u_cfg`. The function call is guarded by `coeff_word_addr`, whose accepted aligned addresses mask to `8'h10`, `18`, `20`, `28`, `30`, or `38`.

Fresh VC Formal V-2023.12-SP2 run `runs/thermo5_axil_cfg_final_closure_20261031` used the committed baseline harness and no environment assumptions. All 4 assertions passed, the legal coefficient-read Cover was reached, and the exact default-arm Cover was reported uncoverable. The run reported 3 non-vacuous assertions, zero black boxes, and zero setup violations. The fail-closed disposition updater matched the semantic Bin ID, instance, branch record (`135:default`), RTL SHA-256, property/Cover result, and unchanged Raw report. The line-142 default Line bin is independently source-mapped to the same predicate and remains a separate Raw metric bin.

Disposition: both exact bins are `PROVEN_UNREACHABLE` for this product configuration and remain in Raw. No `.el`, waiver, or denominator change was applied. Coverage values are unchanged.

## AXI-Lite mailbox stability diagnostic remains OPEN (2026-10-31)

An exploratory Formal property was added temporarily to check the simulation-only mailbox stability guard. A full AXI-Lite Formal run left the new assertion inconclusive and reached the mailbox-change Cover. A selected-property trace job produced a depth-4 witness, but its property report shows the AXI AW/W stability assumptions as `not_run`; that witness is unconstrained and cannot establish a legal-protocol defect or an unreachable bin. The temporary harness edits were reverted and are not part of the accepted Formal runner or any disposition.

The focused VCS `thermo5_sku_axil_config_test` run at seed 610931 passed with zero UVM warnings, errors, or fatals and checked a legal identity-equivalent two-tap commit at a DPD frame boundary. This single test does not resolve the Formal inconclusive result. Keep the mailbox stability checker path OPEN pending a reproducible, assumption-audited proof and matching directed simulation. No RTL was changed and no coverage credit or waiver was applied. Local diagnostic artifacts are under `runs/thermo5_axil_cfg_mailbox_formal_20261031/`, `runs/thermo5_axil_cfg_mailbox_trace_20261031/`, and `runs/thermo5_axil_mailbox_vcs_20261031/`.

## Separate early-TLAST negative regression (2026-10-31)

After VCS license recovery, the current-source `thermo5_sku_axil_illegal_frame_test` compiled and passed at seed 420102. The stimulus asserted TLAST at source beat 15 inside the 32-beat product quantum. The test observed both expected RTL protocol assertions, checked `protocol_error` and its cycle count, then verified public reset clears the sticky error. UVM reported 0 warnings, 0 errors, and 0 fatals.

A separate URG report hit the exact early-TLAST Branch `TXB-646dd03c99766d877d30` at `tid32_thermo5_axi_lite_axis_frontend_tx.sv:141`, instance `thermo5_sku_uvm_tb.dut`. This is negative-only evidence: its VDB/report was not merged into legal-product Raw, and the Raw bin remains OPEN in the product-only ledger. No denominator, waiver, or exclusion changed. The command lines, source hashes, log hashes, URG page hash, VDB tree hash, observed messages, and result are recorded in [`thermo5-tx-negative-assertion-evidence.json`](data/thermo5-tx-negative-assertion-evidence.json).

## Centered-Cubic product cadence review for two missing pop/push branches (2026-10-31)

The exact missing bins are `TXB-9141942b3f6f51689217` in `g_interp1_centered.u_interp_1` and `TXB-33db6d34081fd3b6ec60` in `g_interp2_centered.u_interp_2`, both at the `end else if (push_input)` arm of `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255`. A reproducible AXI-Lite product test sends two legal back-to-back 32-beat packets using the fixed product configuration. The independent four-plane scoreboard checks all 112 output words, and DPD lane sample/saturation counts are checked.

The same waveform seed (610901) was run across nine source-start and seventeen RUN-start phase placements. All 26 UVM runs passed with zero errors/fatals. In each interpolator, the test observed `q_count==1 && q0_end` once and the corresponding `pop_head` once; neither instance asserted `push_input` on that pop edge. Thus neither exact Raw Branch bin was hit. One phase VDB was merged into a separate diagnostic URG report; the Raw metrics and denominator were unchanged: line 3190/3796, condition 583/846, branch 440/637, toggle 86951/104478; target branch coverage delta was zero. Standalone stage-level Formal has a valid pop/push Cover witness, so the paths are not structurally impossible; product-bound cadence reachability remains OPEN. No waiver or exclusion was created.

Exact VCS and URG command lines, source hashes, all 26 log hashes, VDB tree hash, URG report hash, coverage gate, target Bin IDs, and per-instance event counts are recorded in [`thermo5-tx-frame-replacement-coverage-review.json`](data/thermo5-tx-frame-replacement-coverage-review.json). The next action is a product-bound reachability/root-cause analysis of the 14-to-8 ingress cadence and frame-tail timing. Do not repeat random seeds or convert this miss into a Formal disposition without a non-vacuous product-bound proof.

## Evidence inputs

- Raw Group Report: runs/thermo5_tx_final_vcs_resume_20261030_41691/product_raw_after_register_access
- Separate expected-negative Group Report: runs/thermo5_tx_product_axil_register_access_20261030/negative_expected_assertions/report
- Source-linked gap ledger: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/thermo5-tx-gate3-coverage-ledger.csv
- Source manifest: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/axil_gap_ledger.json
- Closure evidence JSON: docs/verification/thermo5-tx-linux-coverage-closure-evidence.json

## Formal disposition update

The source-bound review closed 6 exact bins as PROVEN_UNREACHABLE; 18587 remain OPEN. Formal Inconclusive is not a closure. Raw URG and its denominator are unchanged; approved waivers and active .el exclusions are both zero.

| Semantic Bin ID | Assertion | Cover | Disposition |
|---|---|---|---|
| `TXB-39a0a549d32bc9ef1e01` | `thermo5_frame_tail_harness.a_append_no_input_tail` | `thermo5_frame_tail_harness.c_append_tail_head_drop_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-3df5f13a8d51ee9bdea5` | `thermo5_axil_cfg_coverage_harness.a_write_case_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_write_case_default_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-603e97cceda8c0d4d0ed` | `thermo5_frame_tail_harness.a_plain_tail_fire_disabled` | `thermo5_frame_tail_harness.c_plain_tail_fire_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-65f3dfeee7bc0b854f52` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-74a3bacf0956921ac9bf` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-872eb98e51c3229e4c86` | `thermo5_axil_cfg_coverage_harness.a_line88_tuple_unreachable` | `thermo5_axil_cfg_coverage_harness.c_line88_tuple_unreachable` | PROVEN_UNREACHABLE; retained in Raw |

Reviewed candidates with tautological or otherwise invalid Formal evidence remain OPEN:

| Semantic Bin ID | Status | Reason |
|---|---|---|
| `TXB-054d97a87a8d74c36c8b` | OPEN | Not accepted as a Formal disposition: VC Formal reports the MAX_TAPS assertion/Cover as tautological for compile-time MAX_TAPS=1. Retain Raw bin and OPEN status pending separately audited static configuration evidence. |
| `TXB-c79cdf2b9f5b4620688e` | OPEN | Not accepted as a Formal disposition: the assertion a_plain_append_arm_disabled is explicitly reported tautological by VC Formal. Retain Raw bin and OPEN status; no waiver or exclusion. |
