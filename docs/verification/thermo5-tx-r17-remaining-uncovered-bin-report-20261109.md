# Thermo5 TX Round 17 — Remaining Uncovered Bin Report

**Date:** 2026-11-09  |  **Branch:** `codex/thermo5-round17-formal-closure`  |  **Status:** Analysis-only; official coverage/signoff remains open.

## Executive summary

This report enumerates the exact bins still uncovered after the Round 17 same-VDB Analysis-only What-if URG run. It does not promote any candidate to an approved waiver. URG removed 8,957 candidate rows with strict mode and zero diagnostics; 13 candidate mapping gaps were left out. The resulting report has **4,214 uncovered code bins**. The official waiver inventory still has **0 approvals and 0 active exclusions**, so the official Raw/Adjusted gap remains 13,171 bins.

| Metric | Official Raw / zero-exclusion Adjusted uncovered | Analysis-only What-if uncovered | What-if covered / denominator |
|---|---:|---:|---:|
| Branch | 113 | 15 | 524 / 539 (97.2171%) |
| Condition | 192 | 84 | 657 / 741 (88.6640%) |
| Line | 458 | 29 | 3,338 / 3,367 (99.1387%) |
| Toggle | 12,408 | 4,086 | 92,072 / 96,158 (95.7507%) |
| **Total code bins** | **13,171** | **4,214** | — |

FSM is unchanged at 13/13 states and 22/22 transitions. The What-if denominator changes are measured by actual URG output; this is not a projected percentage.

## Interpretation and review status

- The What-if ledger contains 4,214 unique semantic IDs and 4,214 unique record IDs. Every row has `official_adjusted_status=UNCHANGED_RAW_OPEN`; its What-if status is either `OPEN_CANDIDATE_NATIVE_MAPPING` or `OPEN_NOT_IN_8970_CANDIDATE_SET`. None was hit by Raw URG or removed by the Analysis-only exclusions.
- The 13 candidate-mapping gaps are part of the 4,214 total: 9 Branch and 4 Line bins. They are not extra bins beyond the metric totals.
- Static-review tags are bookkeeping, not proof or approval. All bins remain open for official coverage purposes, including rows tagged `CONFIG_UNREACHABLE`, `STATIC_UNREACHABLE`, or `DEFENSIVE_NEGATIVE_ONLY`.
- This run did not add tests, Formal proofs, new coverage hits, or official exclusions. No RTL or product configuration changed.

### Prior static-review tags on these remaining bins

| Review tag in source ledger | Count | Meaning for this report |
| --- | --- | --- |
| <code>UNKNOWN</code> | 4,199 | No complete per-bin reachability/dataflow argument in the static pass; keep OPEN. |
| <code>CONFIG_UNREACHABLE</code> | 10 | Candidate configuration-based classification only; no independent approval/exclusion is active. |
| <code>STATIC_UNREACHABLE</code> | 3 | Candidate structural classification only; no independent approval/exclusion is active. |
| <code>DEFENSIVE_NEGATIVE_ONLY</code> | 2 | Tagged as negative-path behavior; still needs policy/review and remains OPEN. |

## Root-cause grouping

These are inherited triage labels from the exact-bin source ledger. They prioritize review; they do not declare reachability or waiver eligibility.

| Metric | Triage group | Exact bins |
| --- | --- | --- |
| Branch | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | 9 |
| Branch | <code>FIXED_PRODUCT_CONFIGURATION</code> | 3 |
| Branch | <code>PRODUCT_CADENCE_ALIGNMENT</code> | 2 |
| Branch | <code>GUARDED_ADDRESS_DECODE</code> | 1 |
| Condition | <code>RESET_RELEASE_OR_STATE_HOLD</code> | 80 |
| Condition | <code>INTERPOLATOR_EMPTY_OR_BLOCKED</code> | 4 |
| Line | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | 28 |
| Line | <code>CDC_OR_RESIDUAL_STATE</code> | 1 |
| Toggle | <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | 2,478 |
| Toggle | <code>IDENTITY_DPD_ARITHMETIC</code> | 944 |
| Toggle | <code>COUNTER_HIGH_BITS</code> | 640 |
| Toggle | <code>FIXED_PRODUCT_CONFIGURATION</code> | 24 |

## Remaining bins by source file

This table groups the exact ledger by metric and RTL source. The following sections list every Branch, Condition, and Line semantic ID individually; Toggle IDs and transition directions are fully preserved in the linked machine ledger.

| RTL source | Branch | Condition | Line | Toggle | Total |
| --- | --- | --- | --- | --- | --- |
| <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | 3 | 8 | 1 | 8 | 20 |
| <code>rtl/dpd/dpd_memory_poly.v</code> | — | 21 | — | 1,584 | 1,605 |
| <code>rtl/dpd/dpd_vector16_memory_poly.sv</code> | — | 1 | 4 | 6 | 11 |
| <code>rtl/frontend/dsm_frame_gain_vector.sv</code> | 1 | 6 | — | — | 7 |
| <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | 8 | 36 | 24 | 80 | 148 |
| <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | 1 | 3 | — | 38 | 42 |
| <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | — | — | — | 2,344 | 2,344 |
| <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | 2 | 7 | — | 14 | 23 |
| <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | — | 2 | — | 12 | 14 |

## Branch — 15 exact uncovered bins

All 15 Branch bins are listed below. The source ledger gives the exact branch predicate/decision path. The nine candidate mapping gaps are marked `OPEN_CANDIDATE_NATIVE_MAPPING`; they remain open.

| Record ID | Semantic Bin ID | Instance | Source | Native URG bin | RTL expression | Triage | What-if status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <code>TXR-09cfe3a3ae45a29d7aff</code> | <code>TXB-0260d31bb5bee4f1a4c6</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:141</code> | <code>122:0/-/1/-/-/default/-/-/-/-/-/-</code> | if (advance) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-330ddd60073e926ec313</code> | <code>TXB-85afd49f35a994cc290c</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:146</code> | <code>122:0/-/1/1/0/-/-/-/-/-/-/-</code> | if (end_remaining_q <= CORE_LANES) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |
| <code>TXR-4ca9572515cfc8e4f17c</code> | <code>TXB-7ea7a7506f13f31ca4a9</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:215</code> | <code>122:0/-/1/-/-/0 2 4 6/1/-/1/1/-/-</code> | if (rem_count_q + SRC_LANES <= CORE_LANES) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-5d66742ac5ee92698d70</code> | <code>TXB-91d5b4a40917c980da7a</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:97</code> | <code>71:0/1/0/-/-/-/-/-/-/-/-</code> | if (!HOLD_STATE_ON_DISABLE) begin | <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-2e110a6a42b9507f4f4e</code> | <code>TXB-ef2fb170941b345476dc</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:129</code> | <code>129:1/-</code> | if (tail_output) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-158f98630956bf8f38d1</code> | <code>TXB-e8358208ee175c15bb7d</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210</code> | <code>182:0/1/0/-/-/-/-/-/-/-/-/-/-</code> | if (!HOLD_STATE_ON_DISABLE) begin | <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-9ae5aed11efe319e4f3e</code> | <code>TXB-32b923f55e34401249a8</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210</code> | <code>182:0/1/0/-/-/-/-/-/-/-/-/-/-</code> | if (!HOLD_STATE_ON_DISABLE) begin | <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-adeaefe4f47bc818c54c</code> | <code>TXB-603e97cceda8c0d4d0ed</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:217</code> | <code>182:0/0/-/1/-/-/-/-/-/-/-/-/-</code> | if (tail_fire) | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-b6aed066c642859ac818</code> | <code>TXB-c79cdf2b9f5b4620688e</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:223</code> | <code>182:0/0/-/-/1/1/-/-/-/-/-/-/-</code> | if (APPEND_TAIL_VECTOR && head_final) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-69a63074fc234cce76ba</code> | <code>TXB-39a0a549d32bc9ef1e01</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:229</code> | <code>182:0/0/-/-/-/-/1/-/-/-/-/-/-</code> | if (pop_head && q0_tail) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_CANDIDATE_NATIVE_MAPPING</code> |
| <code>TXR-84205a62a431aaefa779</code> | <code>TXB-9141942b3f6f51689217</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255</code> | <code>182:0/0/-/-/-/-/-/1/0/-/1/-/-</code> | end else if (push_input) begin | <code>PRODUCT_CADENCE_ALIGNMENT</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |
| <code>TXR-fc0d476fff4a4ef4c9be</code> | <code>TXB-33db6d34081fd3b6ec60</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255</code> | <code>182:0/0/-/-/-/-/-/1/0/-/1/-/-</code> | end else if (push_input) begin | <code>PRODUCT_CADENCE_ALIGNMENT</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |
| <code>TXR-a245b56f91903b46c8e2</code> | <code>TXB-3df5f13a8d51ee9bdea5</code> | <code>thermo5_sku_uvm_tb.dut.u_cfg</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:246</code> | <code>190:0/-/-/-/-/1/0/-/default/-/-/-/-/-/-/-/-/-</code> | if (write_resp != 2'b00) begin | <code>GUARDED_ADDRESS_DECODE</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |
| <code>TXR-c6cb4b244ad6c95a968d</code> | <code>TXB-e99262dd92665c3b9ea8</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:203</code> | <code>198:0/2'b10/0/-/-/-</code> | 2'b10: if (!(&outstanding_words_q)) outstanding_words_q <= outstanding_words_q + 1'b1; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |
| <code>TXR-71d5cb9d483fdbda695f</code> | <code>TXB-c16debdf7d9cbab220ac</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:204</code> | <code>198:0/2'b01/-/0/-/-</code> | 2'b01: if (outstanding_words_q != 0) outstanding_words_q <= outstanding_words_q - 1'b1; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> | <code>OPEN_NOT_IN_8970_CANDIDATE_SET</code> |

## Condition — 84 exact uncovered bins

Each row is an exact semantic bin. Similar conditions may share a source expression but differ by operand vector or instance; do not collapse these bins when planning closure.

| Record ID | Semantic Bin ID | Instance | Source | Native URG bin | RTL expression | Operands | Triage |
| --- | --- | --- | --- | --- | --- | --- | --- |
| <code>TXR-73170dd897f525f8a2b0</code> | <code>TXB-3b8b5df27b5b204fbb04</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:113</code> | <code>113:0/1/1/1/1</code> | assign core_data_empty = fifo_rd_empty && !fifo_rd_valid && | <code>0/1/1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-cda60d4b7d6420e5bd65</code> | <code>TXB-8b1edaf71e9793afe4ba</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:113</code> | <code>113:1/0/1/1/1</code> | assign core_data_empty = fifo_rd_empty && !fifo_rd_valid && | <code>1/0/1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d3941e16ebd0298a6c96</code> | <code>TXB-caf8cf334f65d932e7ed</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:113</code> | <code>113:1/1/0/1/1</code> | assign core_data_empty = fifo_rd_empty && !fifo_rd_valid && | <code>1/1/0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-dce80fc10adce793854b</code> | <code>TXB-6b10fe02160c9657a91f</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:113</code> | <code>113:1/1/1/1/0</code> | assign core_data_empty = fifo_rd_empty && !fifo_rd_valid && | <code>1/1/1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-daefbb5d51113b99aad0</code> | <code>TXB-601ed947c812fac07c13</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:138</code> | <code>138:0/1/1</code> | if (core_valid && core_ready && core_frame_start) | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-cd79e432e8f67f5d65dc</code> | <code>TXB-12757f483dbb77b4700b</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:145</code> | <code>145:0/1</code> | if ((rem_count_q >= CORE_LANES) && end_pending_q) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-4ea2d1f18ceb72c8e281</code> | <code>TXB-508b759e14e613ff239b</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:231</code> | <code>231:0/1/1</code> | if (stream_started_q && !out_valid_q && !core_drain) | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d845ac156f5ba5d18718</code> | <code>TXB-7283983e103cdc1728bb</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:261</code> | <code>261:0/1/1</code> | if (fifo_rd_valid && fifo_rd_ready && fifo_frame_start) | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-0e0cda523a2f065ec84a</code> | <code>TXB-33f998ffd11c9fa2d532</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[0].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b3886936c14e9680fcb6</code> | <code>TXB-ac77a26f1b5db67a5992</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[10].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-a136df0ac7097a533912</code> | <code>TXB-12d7b8d0a06eb411ea9b</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[11].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-372abf950eb32a9eced7</code> | <code>TXB-50a5665beba084b7b1dc</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[11].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-850a48abd429dce84055</code> | <code>TXB-4caf9df4a2f1c31b35a4</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[11].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:1/0</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-fdb741f0207b1f623b67</code> | <code>TXB-2a13a9e0cbae6d6c0221</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[12].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b81740a182305956e87d</code> | <code>TXB-4824eabcba7861563ca2</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[13].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-bdf0a82319375bd444bd</code> | <code>TXB-19f4d21d889c1bc2f9e4</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[14].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-c3c7feb7fd5afdf17656</code> | <code>TXB-4c43ef65894613bf582a</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[15].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d5de5bc6ba07b5b220af</code> | <code>TXB-7e3d8ab85dcbfde179c8</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[15].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-e587fb9f1f6e41a7a7e6</code> | <code>TXB-2be3fbc912d0d3657002</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[1].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-7e47c466622cae6bdd3f</code> | <code>TXB-f4f5dc437ff697b9f097</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[2].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-a1350847787ce394d130</code> | <code>TXB-075cf0a496177c8cf2bd</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[3].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-f88164ffdbec7e9bae97</code> | <code>TXB-fdacdc50990c5affa98e</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[3].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-4503d356cbe57c881f87</code> | <code>TXB-3dd5a40ea4392f6818d0</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[3].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:1/0</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-a2c7c75cdf6c9311fb92</code> | <code>TXB-ff6abb5b0277d5db673e</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[4].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-be0fb6228111344ace7d</code> | <code>TXB-a42d9362f0edb908b78f</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[5].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-74d7d3e739e8883588b7</code> | <code>TXB-b04ec0a0673636cb97a9</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[6].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-9a595f95b6c3955df19f</code> | <code>TXB-876853420d96f475fcbc</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[7].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d7246d04a0d12aef5723</code> | <code>TXB-fbc614fb3362b9d74635</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[8].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d5ed9fc1a986ffb5ebec</code> | <code>TXB-6984135c09f560921045</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[9].u_dpd</code> | <code>rtl/dpd/dpd_memory_poly.v:337</code> | <code>337:0/1</code> | if (valid_pipe[PIPE_STAGES-1] && (sat_i \|\| sat_q)) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-9703c95a79cdab910ef2</code> | <code>TXB-33613a1855fcc02e8ef4</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv:93</code> | <code>93:0/1</code> | end else if (in_ready \|\| !out_valid) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-9faf22b9f6a69be6b224</code> | <code>TXB-ba0c7be4a35a2263df2a</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:112</code> | <code>112:0/1</code> | out_frame_start <= s1_valid && s1_frame_start; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-fb90f5b41cd820c5a57a</code> | <code>TXB-471ba2ea5587355c3ddd</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:113</code> | <code>113:0/1</code> | out_frame_end <= s1_valid && s1_frame_end; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-ed23bd23668a69bcacc5</code> | <code>TXB-c0af3237c7bc5a5ca81a</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:123</code> | <code>123:0/1</code> | s1_frame_start <= s0_valid && s0_frame_start; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-11af55cc3dd2db004753</code> | <code>TXB-93322a7c6bee5c2bc42c</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:124</code> | <code>124:0/1</code> | s1_frame_end <= s0_valid && s0_frame_end; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-f6b2203c1586ea56f10a</code> | <code>TXB-1a46bada439ec7a2903c</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:136</code> | <code>136:0/1</code> | s0_frame_start <= in_valid && in_frame_start; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-6412146e9869a24c497f</code> | <code>TXB-7b1fe74dbf7ff06539d5</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:137</code> | <code>137:0/1</code> | s0_frame_end <= in_valid && in_frame_end; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-41cdee4d8939fac2393d</code> | <code>TXB-b22da1a128d4c228fdbd</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:220</code> | <code>220:1/0</code> | if (pop_head && !q0_tail) begin | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-eaaf72aabbc55b79a882</code> | <code>TXB-49fe8b7a3097cfabcafe</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:229</code> | <code>229:0/1</code> | if (pop_head && q0_tail) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-2c330fc93bce393be650</code> | <code>TXB-471301ea0e99716856de</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:229</code> | <code>229:1/1</code> | if (pop_head && q0_tail) begin | <code>1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-129c7b00a01d39375af5</code> | <code>TXB-162e100d0c56b0f6d5fd</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:300</code> | <code>300:0/1/1</code> | else stalled_last <= enable && out_valid && !out_ready; | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-ca6e0822bad279991984</code> | <code>TXB-88bf5b09aec9ee58a8ff</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:300</code> | <code>300:0/1/1</code> | else stalled_last <= enable && out_valid && !out_ready; | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-7bf1068721bfe70d72ca</code> | <code>TXB-2cb17f70d19098c6deca</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:304</code> | <code>304:0/1</code> | if (rst_n && stalled_last) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-968764d10d7eaa4100b8</code> | <code>TXB-d9c09d96c814db206877</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:304</code> | <code>304:0/1</code> | if (rst_n && stalled_last) begin | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-99c1f2753660818fffaf</code> | <code>TXB-8ed12996edaade43bb74</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309</code> | <code>309:0/1/1/1</code> | if (rst_n && q_count == 2 && q0_end && !q1_start) | <code>0/1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-8d6ece32642e3560803b</code> | <code>TXB-1a3c01edbe1a6cdf4f0f</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309</code> | <code>309:0/1/1/1</code> | if (rst_n && q_count == 2 && q0_end && !q1_start) | <code>0/1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-264b8cb68819b7728c43</code> | <code>TXB-110db3f8a9b52bda4df5</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:67</code> | <code>67:0/1</code> | wire logic next_is_boundary = (q_count == 2) && q1_start; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-6cc6b32d0f3ee02ee88d</code> | <code>TXB-386083089f1b41f3fbbd</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:67</code> | <code>67:0/1</code> | wire logic next_is_boundary = (q_count == 2) && q1_start; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-f363c2923e19d7506ba3</code> | <code>TXB-ecf5a64e7dd78bc35ae0</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:68</code> | <code>68:1/0/1</code> | wire logic can_emit_head = ((q_count == 2) \|\| ((q_count == 1) && q0_end)) && | <code>1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-34460ddb7f0a36b33780</code> | <code>TXB-d07f79d0903a608e2544</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:68</code> | <code>68:1/1/0</code> | wire logic can_emit_head = ((q_count == 2) \|\| ((q_count == 1) && q0_end)) && | <code>1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-a450d308aa3e2334ffe7</code> | <code>TXB-e4abdd28c8384d2dfa8f</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:68</code> | <code>68:1/0/1</code> | wire logic can_emit_head = ((q_count == 2) \|\| ((q_count == 1) && q0_end)) && | <code>1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-475d01bfff9208c54348</code> | <code>TXB-909c9c41ce328d3b5464</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:71</code> | <code>71:1/0</code> | wire logic pop_head = drop_head_tail \|\| | <code>1/0</code> | <code>INTERPOLATOR_EMPTY_OR_BLOCKED</code> |
| <code>TXR-afd974d4ccb1354ba2c5</code> | <code>TXB-1f1ce5bdcc2c308628e9</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:71</code> | <code>71:1/1/1/0</code> | wire logic pop_head = drop_head_tail \|\| | <code>1/1/1/0</code> | <code>INTERPOLATOR_EMPTY_OR_BLOCKED</code> |
| <code>TXR-5d7b5adf38fc69f91faa</code> | <code>TXB-5289de10c1a887214158</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:71</code> | <code>71:1/0/1/1</code> | wire logic pop_head = drop_head_tail \|\| | <code>1/0/1/1</code> | <code>INTERPOLATOR_EMPTY_OR_BLOCKED</code> |
| <code>TXR-c2b17925ba3e14c75c06</code> | <code>TXB-ab53b1aadded931bc157</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:71</code> | <code>71:1/1/1/0</code> | wire logic pop_head = drop_head_tail \|\| | <code>1/1/1/0</code> | <code>INTERPOLATOR_EMPTY_OR_BLOCKED</code> |
| <code>TXR-fc143b7e86ff4133b1de</code> | <code>TXB-5fe8d53a8b7b430139d1</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:74</code> | <code>74:1/1/0</code> | wire logic tail_fire = tail_output && out_ready && enable; | <code>1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-1bd9d1e194483596835c</code> | <code>TXB-da673e9462548c47c6c3</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:74</code> | <code>74:1/0/1</code> | wire logic tail_fire = tail_output && out_ready && enable; | <code>1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-e42166a16d273854b1a4</code> | <code>TXB-4445cf3565dc723fc045</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:74</code> | <code>74:1/1/0</code> | wire logic tail_fire = tail_output && out_ready && enable; | <code>1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b439e2bdfdd6df60d117</code> | <code>TXB-1d320f7692d3831884d0</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:74</code> | <code>74:1/1/1</code> | wire logic tail_fire = tail_output && out_ready && enable; | <code>1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b456b197cd12b6493d8a</code> | <code>TXB-a014e054137f7efba83d</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:75</code> | <code>75:0/1</code> | wire logic head_final = q0_end \|\| next_is_boundary; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-11a7d797db689de73a9c</code> | <code>TXB-84309750691c8e9b8ebf</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:83</code> | <code>83:0/1</code> | assign out_valid = enable && (tail_output \|\| can_emit_head); | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-c8919ad2a13f20b77f38</code> | <code>TXB-6f08406287cccaa17533</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:83</code> | <code>83:0/1</code> | assign out_valid = enable && (tail_output \|\| can_emit_head); | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-e8ce707e812476afd674</code> | <code>TXB-9ce20b84a284eb4c0773</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:83</code> | <code>83:1/0</code> | assign out_valid = enable && (tail_output \|\| can_emit_head); | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-a8e6f51c3ee8e04cd5ae</code> | <code>TXB-f4d358f564e64090910b</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:84</code> | <code>84:0/1</code> | assign out_tail = out_valid && tail_output; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-06ca437436ce9509cb48</code> | <code>TXB-ac118cc658b7c8ebe27f</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:84</code> | <code>84:0/1</code> | assign out_tail = out_valid && tail_output; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-d0b3057588c2db231e28</code> | <code>TXB-b450fec02bca474b90bf</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:84</code> | <code>84:1/1</code> | assign out_tail = out_valid && tail_output; | <code>1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-649d125e36de6637a659</code> | <code>TXB-3a9590e170ea70bbfa6e</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:85</code> | <code>85:1/0/1</code> | assign out_frame_start = out_valid && !tail_output && q0_start; | <code>1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-c4002b492ed0bb03583f</code> | <code>TXB-77c77b40cc71b60978cb</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:0/1</code> | assign out_frame_end = out_valid && | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-814b2fcb1fcbf25966b1</code> | <code>TXB-a274d5dd6bfd26bfb01d</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:0/1</code> | assign out_frame_end = out_valid && | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b2609f63a9b47b4eea2c</code> | <code>TXB-6bd0d4bf3b12051ce406</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:-/0/1/1</code> | assign out_frame_end = out_valid && | <code>-/0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-c56ec98907e6d308f39c</code> | <code>TXB-597ed4ee79b36ae4a224</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:-/1/1/0</code> | assign out_frame_end = out_valid && | <code>-/1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-25389af5989951600fa1</code> | <code>TXB-94e8e7df882f0d59f4b4</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:0/1</code> | assign out_frame_end = out_valid && | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-21cd3daf66b77efbce8e</code> | <code>TXB-9f2139c02a8e2f3c5234</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:86</code> | <code>86:1/0</code> | assign out_frame_end = out_valid && | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-b2508bf79c5b023f47c3</code> | <code>TXB-a8041f215017e6e9b5f5</code> | <code>thermo5_sku_uvm_tb.dut.u_cfg</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:333</code> | <code>333:0/1/1</code> | if (cfg_req_sync2 && cfg_pending_valid && dpd_config_boundary) begin | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-036a0de971d50b4d6b23</code> | <code>TXB-fe4a2292a0aa4da543b9</code> | <code>thermo5_sku_uvm_tb.dut.u_cfg</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:333</code> | <code>333:1/0/1</code> | if (cfg_req_sync2 && cfg_pending_valid && dpd_config_boundary) begin | <code>1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-aa2255444a4dbc01c674</code> | <code>TXB-872eb98e51c3229e4c86</code> | <code>thermo5_sku_uvm_tb.dut.u_cfg</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv:93</code> | <code>93:0/1/1</code> | wire logic write_fire = !s_axil_bvalid && (aw_pending \|\| aw_take) && (w_pending \|\| w_take); | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-5511f555cfee4040ce33</code> | <code>TXB-6c0ccdbf194f518cd524</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:128</code> | <code>128:0/1/1</code> | if (run_seen_s && ingress_closed_s && !core_active_s2) | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-05968be6e1302377792e</code> | <code>TXB-452db0275b9ed7af0d4b</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:171</code> | <code>171:0/1</code> | assign core_protocol_error = cdc_protocol_error \| source_error_c2; | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-2cda902865edc3e4352b</code> | <code>TXB-581f1256dd0672fd753a</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:204</code> | <code>204:0</code> | 2'b01: if (outstanding_words_q != 0) outstanding_words_q <= outstanding_words_q - 1'b1; | <code>0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-cf9444490c995b5dd2a6</code> | <code>TXB-4b80ed59cfb06d66498c</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:216</code> | <code>216:0/1</code> | assign core_datapath_enable = core_tx_active_q && | <code>0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-8ca736fc786b40af5842</code> | <code>TXB-557fefb1c4381a209747</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:96</code> | <code>96:1/0/1/1/1</code> | wire logic drain_complete = ingress_closed_c3 && core_data_empty && | <code>1/0/1/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-1c098e4b4e6e97f5228c</code> | <code>TXB-4b437512c777826f8907</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:96</code> | <code>96:1/1/1/0/1</code> | wire logic drain_complete = ingress_closed_c3 && core_data_empty && | <code>1/1/1/0/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-1a443becf6ba81b2b593</code> | <code>TXB-dc9aededce3dd7b07105</code> | <code>thermo5_sku_uvm_tb.dut</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv:96</code> | <code>96:1/1/1/1/0</code> | wire logic drain_complete = ingress_closed_c3 && core_data_empty && | <code>1/1/1/1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-9a8acef48141acc1789e</code> | <code>TXB-c1cc186d91eb6e6b0021</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv:142</code> | <code>142:0/1/1</code> | assign dpd_config_boundary = i1_buf_valid && i1_buf_ready && i1_buf_frame_start; | <code>0/1/1</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |
| <code>TXR-ae8b14b8f9f28a890f05</code> | <code>TXB-9ce4e23a9dab37d7ea28</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv:76</code> | <code>76:1/0</code> | ) u_cdc_to_frame_gain_fifo ( | <code>1/0</code> | <code>RESET_RELEASE_OR_STATE_HOLD</code> |

## Line — 29 exact uncovered bins

URG line coverage is instance-sensitive here. The same source line can appear as separate uncovered bins in two interpolator instances; retain both identities.

| Record ID | Semantic Bin ID | Instance | Source | Native URG bin | RTL statement | Triage |
| --- | --- | --- | --- | --- | --- | --- |
| <code>TXR-c3693b2817a9ee392fba</code> | <code>TXB-e4810d348ea657bf627a</code> | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:151</code> | <code>151:0</code> | end_remaining_q <= end_remaining_q - CORE_LANES; | <code>CDC_OR_RESIDUAL_STATE</code> |
| <code>TXR-65eb5c69d4ee9abadccb</code> | <code>TXB-85e4dc08ceaaa6cb3089</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv:61</code> | <code>61:0</code> | lane_i_taps[(lane*MAX_TAPS+tap)*W +: W] = history_i[tap-lane-1]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-d9dbcb3409a3d6d1b29c</code> | <code>TXB-2630d236b14544679aef</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv:62</code> | <code>62:0</code> | lane_q_taps[(lane*MAX_TAPS+tap)*W +: W] = history_q[tap-lane-1]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-c44d06b376ffd694f7ce</code> | <code>TXB-ba031f7f15eab43758d9</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv:80</code> | <code>80:0</code> | history_i[h] <= history_i[h-LANES]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-fdf86156f292b94b8c62</code> | <code>TXB-a26f239c3d988ed66b21</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_memory_dpd.u_memory_dpd</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv:81</code> | <code>81:0</code> | history_q[h] <= history_q[h-LANES]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-06543e6951be66f5f7ff</code> | <code>TXB-d50ead3bf05f3974fcad</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:218</code> | <code>218:0</code> | tail_pending_q <= 1'b0; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-a3df532309a85a436599</code> | <code>TXB-ba8067539d65e06536a5</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:224</code> | <code>224:0</code> | tail_pending_q <= 1'b1; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-d11c605dca37caa6adc3</code> | <code>TXB-c659ce0f8167f1f726df</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:225</code> | <code>225:0</code> | tail_sample_i_q <= q0_i[LANES-1]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-74c1aec01804556010b2</code> | <code>TXB-a0aba78f44b5d6586879</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:226</code> | <code>226:0</code> | tail_sample_q_q <= q0_q[LANES-1]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-a2a9bb11e4017db592e1</code> | <code>TXB-be8f42508812865048fe</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:230</code> | <code>230:0</code> | history_i <= '0; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-6f7b1c1460abc335f81a</code> | <code>TXB-9b12c02ba9030d039784</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:231</code> | <code>231:0</code> | history_q <= '0; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-71789c4e5357a231cf5b</code> | <code>TXB-34cbf9ac3a7a356354ac</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:256</code> | <code>256:0</code> | q0_start <= in_frame_start; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-6edad1b8baf4bc70d207</code> | <code>TXB-616381f91de7706c5742</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:256</code> | <code>256:0</code> | q0_start <= in_frame_start; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-34f358783bd11347b541</code> | <code>TXB-48b12fbd09cb95aac030</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:257</code> | <code>257:0</code> | q0_end <= in_frame_end; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-78204c3c5b4a8f79c837</code> | <code>TXB-90710cfaee31703c6f52</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:257</code> | <code>257:0</code> | q0_end <= in_frame_end; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-672fec70ef5b2d85c5d1</code> | <code>TXB-8ac50a6225dbfc001c29</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:258</code> | <code>258:0</code> | q0_tail <= in_tail; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-756f72a61ecc8e1d33d8</code> | <code>TXB-ee77a2532822744027ae</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:258</code> | <code>258:0</code> | q0_tail <= in_tail; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-ee7d44fd8a99d99f121f</code> | <code>TXB-e55b24a42faf7c588707</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:259</code> | <code>259:0</code> | for (int lane = 0; lane < LANES; lane = lane + 1) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-9af13c346981eed4d1ea</code> | <code>TXB-ef4de32514369c5afb17</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:259</code> | <code>259:0</code> | for (int lane = 0; lane < LANES; lane = lane + 1) begin | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-5794072416f755797e7c</code> | <code>TXB-04b3ad415e515585f0f7</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:260</code> | <code>260:0</code> | q0_i[lane] <= in_i_vec[lane*W +: W]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-74cfca5d2e9f05d56ae2</code> | <code>TXB-73338708e85349628a04</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:260</code> | <code>260:0</code> | q0_i[lane] <= in_i_vec[lane*W +: W]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-f86184a7f595df4dcbf9</code> | <code>TXB-c3f76df6c78e76b6893d</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:261</code> | <code>261:0</code> | q0_q[lane] <= in_q_vec[lane*W +: W]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-8af3b6acddde89449f86</code> | <code>TXB-5a7392cd70a1b7e26263</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:261</code> | <code>261:0</code> | q0_q[lane] <= in_q_vec[lane*W +: W]; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-0c891bbe1cd8b04fc6cb</code> | <code>TXB-8f965edcea055340b8e0</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:263</code> | <code>263:0</code> | q_count <= 1; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-1cddaa42e65967b722d0</code> | <code>TXB-7a74d25e2f42834c20e0</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:263</code> | <code>263:0</code> | q_count <= 1; | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-7e241a7b79141319ca0d</code> | <code>TXB-484e84e9cd94e6ec3279</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294</code> | <code>294:0</code> | if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2"); | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-e3900d3466ef41bc33c3</code> | <code>TXB-7c41e79c69d1cad81d2f</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294</code> | <code>294:0</code> | if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2"); | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-ce96d871e70173a45806</code> | <code>TXB-c4ef368c3540489d22a1</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295</code> | <code>295:0</code> | if (COEFF_FRAC != 14) $error("centered cubic coefficients require Q14"); | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |
| <code>TXR-951f511a4341e180d9fe</code> | <code>TXB-f79886c4544d0700fcd7</code> | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295</code> | <code>295:0</code> | if (COEFF_FRAC != 14) $error("centered cubic coefficients require Q14"); | <code>LEGAL_STIMULUS_OR_CHECKER_REVIEW</code> |

## Toggle — 4,086 exact uncovered transition bins

The toggle total is grouped below by inherited root-cause label and source file. There are 4,086 exact toggle bins: 2,055 `1_to_0` and 2,031 `0_to_1`. The signal/bit, exact direction, instance, and semantic ID for every row are in the machine ledger. The signal-group table below shows each source-position group and how many exact bins/instances it covers.

| Toggle triage group | RTL source | Exact bins |
| --- | --- | --- |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | 640 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | 8 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | 80 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | 32 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | 2,344 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | 8 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | 6 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv</code> | 6 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | 6 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | 6 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | 6 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | 944 |

### Toggle signal groups (426 groups)

Exact direction counts are counted from URG-native toggle identities. To locate every bit and hierarchy path, join this summary with the complete exact ledger using `semantic_bin_id`; no signal group is treated as unreachable merely because it did not toggle in this run.

| Triage | RTL source | Signal / bit group | Exact bins | Instances | 0→1 | 1→0 |
| --- | --- | --- | --- | --- | --- | --- |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[12]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[13]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[14]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[15]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[16]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[17]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[18]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[19]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[20]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[21]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[22]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[23]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[24]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[25]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[26]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[27]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[28]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[29]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[30]</code> | 32 | 16 | 16 | 16 |
| <code>COUNTER_HIGH_BITS</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>sample_count[31]</code> | 32 | 16 | 16 | 16 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | <code>end_remaining_q[0]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | <code>end_remaining_q[1]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | <code>end_remaining_q[2]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv</code> | <code>end_remaining_q[4]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>drop_head_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>in_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>out_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>q0_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>q1_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_fire</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_output</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_pending_q</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[0]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[10]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[11]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[12]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[13]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[14]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[15]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[1]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[2]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[3]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[4]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[5]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[6]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[7]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[8]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_i_q[9]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[0]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[10]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[11]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[12]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[13]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[14]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[15]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[1]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[2]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[3]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[4]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[5]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[6]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[7]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[8]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv</code> | <code>tail_sample_q_q[9]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>awaddr_q[1]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>awaddr_q[7]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_active_core[384]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_active_core[385]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_active_core[386]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_for_dpd[384]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_for_dpd[385]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_for_dpd[386]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_mailbox_q[384]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_pending_core[384]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_pending_core[385]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>cfg_pending_core[386]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>mailbox_hold[385]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>mailbox_hold[386]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>s_axil_awaddr[1]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>s_axil_awaddr[7]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>shadow_taps[1]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>write_addr[1]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>write_addr[7]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>arithmetic_bounds_comb</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>arithmetic_no_wrap_comb</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.clamp_negative</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.clamp_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_raw[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e0_state[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_raw[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.e1_state[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.in_bounds</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.no_wrap</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.q0_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.q1_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u0[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_i.u1[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.clamp_negative</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.clamp_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_raw[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e0_state[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_raw[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.e1_state[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.in_bounds</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.no_wrap</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.q0_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.q1_positive</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u0[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>pair_q.u1[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[0]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[10]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[11]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[12]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[13]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[14]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[15]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[16]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[17]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[18]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[19]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[1]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[20]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[21]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[22]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[2]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[3]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[4]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[5]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[6]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[7]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[8]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv</code> | <code>q_one_check[9]</code> | 8 | 4 | 4 | 4 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>outstanding_words_q[5]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>outstanding_words_q[6]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>outstanding_words_q[7]</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>s_axil_awaddr[1]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>s_axil_awaddr[7]</code> | 1 | 1 | 0 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>i2_tail</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>in_meta</code> | 2 | 1 | 1 | 1 |
| <code>DATA_VALUE_OR_TOGGLE_STIMULUS</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>out_meta</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv</code> | <code>active_taps[0]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv</code> | <code>active_taps[1]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/dpd/dpd_vector16_memory_poly.sv</code> | <code>active_taps[2]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>dpd_active_taps[0]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>dpd_active_taps[1]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv</code> | <code>dpd_active_taps[2]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>dpd_active_taps[0]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>dpd_active_taps[1]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv</code> | <code>dpd_active_taps[2]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>dpd_active_taps[0]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>dpd_active_taps[1]</code> | 2 | 1 | 1 | 1 |
| <code>FIXED_PRODUCT_CONFIGURATION</code> | <code>rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv</code> | <code>dpd_active_taps[2]</code> | 2 | 1 | 1 | 1 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>active_taps[0]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>active_taps[1]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>active_taps[2]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[10]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[11]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[12]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[13]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[14]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[15]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[16]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[17]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[18]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[19]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[20]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[21]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[22]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[23]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[24]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[25]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[26]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[27]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[28]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[29]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[30]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[31]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[5]</code> | 16 | 16 | 0 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[6]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[7]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[8]</code> | 32 | 16 | 16 | 16 |
| <code>IDENTITY_DPD_ARITHMETIC</code> | <code>rtl/dpd/dpd_memory_poly.v</code> | <code>saturation_count[9]</code> | 32 | 16 | 16 | 16 |

## Highest-priority closure plan

this is a test/proof planning order, not a claim that the bins are unreachable or waivable. Keep each exact semantic ID linked to its stimulus/checker or reviewed proof.

1. **84 Conditions:** split 80 `RESET_RELEASE_OR_STATE_HOLD` bins by stage/instance and four `INTERPOLATOR_EMPTY_OR_BLOCKED` bins. Build one minimal legal scenario per distinct state/condition vector; record exact URG delta and an independent checker. Avoid counting expected-negative tests as legal business coverage.
2. **15 Branches:** first resolve AXI-Lite write-response/address behavior, outstanding counter guards, CDC residual/end conditions, interpolator tail/pop/push states, frame-gain hold parameter, and the fixed-parameter branches. Use legal directed tests where reachable. For asserted fixed-config unreachability, require source/parameter evidence and independent review; do not infer from this miss.
3. **29 Lines:** prioritize interpolator tail metadata/reset and queue update statements, DPD vector history/tap statements, and the CDC residual decrement. Verify product instance and line-level URG mapping before proposing any exclusion.
4. **4,086 Toggles:** separate 640 `COUNTER_HIGH_BITS` from 2,478 data toggles, 944 identity-DPD arithmetic toggles, and 24 fixed-product-configuration toggles. Target actual bit/direction with legal stimulus. For long-period counters, establish an explicit product runtime/overflow contract and block-level proof; do not label high bits unreachable without it.
5. Stop a test batch if it adds no target exact hits; then re-check the bin-to-source trace and reachability instead of expanding random seeds.

## Exact remaining mapping gaps

These 13 rows are included in the metric totals above. Mapping gaps are an additional review issue: they were not written into any `.el`, and their presence does not change the What-if denominator.

| Record ID | Semantic Bin ID | Metric | Instance | Source | Native URG bin | Reason |
| --- | --- | --- | --- | --- | --- | --- |
| <code>TXR-09cfe3a3ae45a29d7aff</code> | <code>TXB-0260d31bb5bee4f1a4c6</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:141</code> | <code>122:0/-/1/-/-/default/-/-/-/-/-/-</code> | <code>CDC_RESIDUAL_INVARIANT</code> |
| <code>TXR-4ca9572515cfc8e4f17c</code> | <code>TXB-7ea7a7506f13f31ca4a9</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_cdc</code> | <code>rtl/axis/dsm_axis14_to_core8_cdc.sv:215</code> | <code>122:0/-/1/-/-/0 2 4 6/1/-/1/1/-/-</code> | <code>CDC_14_TO_8_END_ARITHMETIC</code> |
| <code>TXR-5d66742ac5ee92698d70</code> | <code>TXB-91d5b4a40917c980da7a</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.u_frame_gain</code> | <code>rtl/frontend/dsm_frame_gain_vector.sv:97</code> | <code>71:0/1/0/-/-/-/-/-/-/-/-</code> | <code>FRAME_GAIN_HOLD_STATE_DEFAULT</code> |
| <code>TXR-2e110a6a42b9507f4f4e</code> | <code>TXB-ef2fb170941b345476dc</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:129</code> | <code>129:1/-</code> | <code>INTERPOLATOR_STAGE2_TAIL_DISABLED</code> |
| <code>TXR-9ae5aed11efe319e4f3e</code> | <code>TXB-32b923f55e34401249a8</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210</code> | <code>182:0/1/0/-/-/-/-/-/-/-/-/-/-</code> | <code>INTERPOLATOR_HOLD_STATE_PARAMETER</code> |
| <code>TXR-158f98630956bf8f38d1</code> | <code>TXB-e8358208ee175c15bb7d</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:210</code> | <code>182:0/1/0/-/-/-/-/-/-/-/-/-/-</code> | <code>INTERPOLATOR_HOLD_STATE_PARAMETER</code> |
| <code>TXR-adeaefe4f47bc818c54c</code> | <code>TXB-603e97cceda8c0d4d0ed</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:217</code> | <code>182:0/0/-/1/-/-/-/-/-/-/-/-/-</code> | <code>INTERPOLATOR_STAGE2_TAIL_DISABLED</code> |
| <code>TXR-b6aed066c642859ac818</code> | <code>TXB-c79cdf2b9f5b4620688e</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:223</code> | <code>182:0/0/-/-/1/1/-/-/-/-/-/-/-</code> | <code>INTERPOLATOR_STAGE2_TAIL_DISABLED</code> |
| <code>TXR-69a63074fc234cce76ba</code> | <code>TXB-39a0a549d32bc9ef1e01</code> | Branch | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:229</code> | <code>182:0/0/-/-/-/-/1/-/-/-/-/-/-</code> | <code>INTERPOLATOR_STAGE1_TAIL_TIED_LOW</code> |
| <code>TXR-7e241a7b79141319ca0d</code> | <code>TXB-484e84e9cd94e6ec3279</code> | Line | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294</code> | <code>294:0</code> | <code>INTERPOLATOR_PARAMETER_GUARD</code> |
| <code>TXR-e3900d3466ef41bc33c3</code> | <code>TXB-7c41e79c69d1cad81d2f</code> | Line | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:294</code> | <code>294:0</code> | <code>INTERPOLATOR_PARAMETER_GUARD</code> |
| <code>TXR-ce96d871e70173a45806</code> | <code>TXB-c4ef368c3540489d22a1</code> | Line | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295</code> | <code>295:0</code> | <code>INTERPOLATOR_PARAMETER_GUARD</code> |
| <code>TXR-951f511a4341e180d9fe</code> | <code>TXB-f79886c4544d0700fcd7</code> | Line | <code>thermo5_sku_uvm_tb.dut.u_frontend.g_interp2_centered.u_interp_2</code> | <code>rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:295</code> | <code>295:0</code> | <code>INTERPOLATOR_PARAMETER_GUARD</code> |

By metric, these are 9 of the 15 remaining Branch bins and 4 of the 29 remaining Line bins. The other 4,201 bins were outside the 8,970-candidate exclusion set.

## Reproducibility and evidence

- Product profile: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1, Identity reset image; AXI-Lite; Generic FIFO.
- VDB source checkout SHA: `17b88280e98096469a57ba51df5b17d53194911a`; compile Product Source SHA: `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`.
- Compile fingerprint SHA-256: `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`; product RTL aggregate SHA-256: `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.
- VDB input: one Design plus 551 Test VDBs. Canonical manifest SHA-256: `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`; compressed manifest SHA-256: `60c15a64cba00a0b243af7c5142d0a6153d61299155429cf9c65678dc67fdbae`.
- URG: V-2023.12-SP1, 64-bit, strict exclusion mode; the Raw and What-if runs used the same VDBs. VDB tree fingerprints matched before/after; diagnostic count was zero.
- Portable run evidence SHA-256: `72a2588cc51d56596433872c7d3850d824643617094d7a4e0fe47a626b51ba5e`; exact remaining ledger SHA-256: `439afbeaea3c45ea367afac7833a8b7103ecb2b653e66d686376a4c49c9858f4`.
- Full Raw-vs-What-if run report: [Round 17 Precise Exclusions What-if](thermo5-tx-r17-precise-exclusions-whatif-20261109.md).
- Complete exact uncovered ledger (all 4,214 semantic IDs, URG native bins, instances, source positions, parameters, source hashes, review tags and next actions): [round17_exact_whatif_remaining_bins.csv.gz](data/thermo5-r17/analysis_only/round17_exact_whatif_remaining_bins.csv.gz).
- Full tool logs and VDB trees remain under ignored `runs/`; their paths and hashes are bound in the portable evidence JSON.

## Signoff decision

**Analysis-only remaining-bin report: complete. Official adjusted coverage: not achieved.** Because there are zero independent Waiver approvals and zero official Exclusions, official Adjusted still equals Raw and the official code-coverage gate remains open. The What-if report leaves 4,214 bins; all require a legitimate exact hit, independently reviewed exclusion, or a formally approved coverage acceptance policy. This report is not a final Linux DV, FPGA, GT, physical, or RF signoff.
