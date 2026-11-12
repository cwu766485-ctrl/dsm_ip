# Thermo5 TX Code Coverage and Uncovered RTL — Round 21

Date: 2026-11-12 (Asia/Singapore). Scope: the frozen thermo5 AXI-Lite product
configuration and the latest Round 21 legal single-entry queue replacement
coverage increment. This is a code-coverage inventory, not a signoff approval.

## Result

Round 21's latest incremental Raw result is 12,580 uncovered DUT code bins.
There are no approved waivers or exclusions, so official Adjusted equals Raw.
The strict analysis-only What-if leaves 1,161 bins, but it removes 11,419
pending candidates without independent approval and is not official coverage.
Code Coverage Signoff and Full Linux DV Signoff remain OPEN.

| Metric | Raw / official Adjusted | Uncovered | What-if remaining |
|---|---:|---:|---:|
| Branch | 526 / 637 (82.57%) | 111 | 3 / 529 |
| Condition | 664 / 849 (78.21%) | 185 | 77 / 741 |
| Line | 3,352 / 3,796 (88.30%) | 444 | 11 / 3,363 |
| Toggle | 92,640 / 104,480 (88.66%) | 11,840 | 1,070 / 93,710 |
| FSM states | 13 / 13 (100%) | 0 | 0 |
| FSM transitions | 22 / 22 (100%) | 0 | 0 |
| **Total code bins** | | **12,580** | **1,161** |

The remaining 1,161 What-if bins comprise 231 non-counter bins and 930
counter-toggle bins. The 12,580 Raw gap partitions exactly into 11,419
analysis candidates, 231 open non-counter bins, and 930 open counter bins.
All 18 new exact hits in the Round 21 queue-boundary test are included in the
latest Raw totals: 2 Branch, 14 Line, and 2 Condition bins.

## Uncovered RTL by Source File

Counts below combine the exact 11,419 candidate records, the 231 current
non-counter open records, and the 930 counter records. Each record is one
exact uncovered code bin; the 930 counter rows are all in
`rtl/dpd/dpd_memory_poly.v`.

| RTL source file | Uncovered bins |
|---|---:|
| `rtl/dpd/dpd_memory_poly.v` | 9,410 |
| `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv` | 2,780 |
| `rtl/axis/dsm_axis14_to_core8_cdc.sv` | 154 |
| `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv` | 137 |
| `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv` | 36 |
| `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv` | 23 |
| `rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv` | 14 |
| `rtl/dpd/dpd_vector16_memory_poly.sv` | 11 |
| `rtl/gt/gt_tx_user_bridge.sv` | 8 |
| `rtl/frontend/dsm_frame_gain_vector.sv` | 7 |
| **Total** | **12,580** |

## Exact Bin Disposition

| Inventory | Count | Metric breakdown | Status |
|---|---:|---|---|
| Analysis candidates | 11,419 | Branch 108, Condition 108, Line 433, Toggle 10,770 | Pending independent review; What-if only |
| Remaining technical non-counter bins | 231 | Branch 3, Condition 77, Line 11, Toggle 140 | OPEN; no independent approval |
| Counter-toggle bins | 930 | Toggle 930: `sample_count` 464, `saturation_count` 466 | OPEN; legal transitions, no approved system-level acceptance |
| **Raw uncovered** | **12,580** | Branch 111, Condition 185, Line 444, Toggle 11,840 | **OPEN** |

The 231 non-counter bins are classified in their exact ledger as 140
`DATA_VALUE_OR_TOGGLE_STIMULUS`, 73 `RESET_RELEASE_OR_STATE_HOLD`, 13
`LEGAL_STIMULUS_OR_CHECKER_REVIEW`, 4 `INTERPOLATOR_EMPTY_OR_BLOCKED`, and 1
`CDC_OR_RESIDUAL_STATE`. The last 231 exact records retain source locations,
semantic IDs, native URG bins, and unresolved dispositions in the linked CSV.
The 930 counter rows retain lane, bit, transition direction, first transition
count, legal stream lower bounds, and measured-rate projections.

## Machine-Readable Exact Inventories

- [11,419 analysis-candidate records](data/thermo5-r21/candidate_review_11419.csv.gz)
- [231 current non-counter open records](data/thermo5-r21/queue_boundary/remaining_non_counter_231.csv)
- [930 open counter-toggle records](data/thermo5-r20/thermo5_tx_r20_counter_remaining_930.csv.gz)
- [18 exact Round 21 queue-boundary hits](data/thermo5-r21/queue_boundary/exact_hits.json)
- [Round 21 coverage summary snapshots](data/thermo5-r21/coverage_summaries.json)
- [Round 21 single-entry queue replacement closure](thermo5-round21-single-replacement-closure.md)

The earlier `final_counts.json` snapshot reports 12,606 Raw and 1,187 What-if
gaps. It predates the 26 exact hits closed by the address-return and
single-entry queue replacement follow-ups; this report uses the latest
incremental totals in the Round 21 single-entry closure report. The older
snapshot is retained unchanged as historical evidence.

## Limitations

The Round 21 follow-up used incremental URG aggregates and the strict passing
Test VDB plus the preserved address-return aggregate; it did not rerun the
full product regression or Formal. The 11,419 What-if candidates are not
approved exclusions. The 930 counter directions remain within the DUT URG
scope; their reachability is not a waiver. This report does not claim 100%
coverage or full verification signoff.
