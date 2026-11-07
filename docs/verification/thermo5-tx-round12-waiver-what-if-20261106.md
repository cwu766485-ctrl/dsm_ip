# Thermo5 TX Round 12 Waiver What-if Coverage Analysis

**Status: ANALYSIS ONLY — NOT OFFICIAL SIGNOFF.** No waiver was approved, the official waiver CSV was not changed, and the official `.el` remains inactive. The What-if `.el` is only for reproducing this report.

## Raw vs What-if Adjusted Coverage

| DUT metric | Raw covered / total | Raw | What-if covered / total | What-if | Exact bins excluded in What-if | Exact bins still open |
|---|---:|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.2606% | 524 / 536 | 97.7612% | 101 | 12 |
| Condition | 657 / 849 | 77.3852% | 657 / 741 | 88.6640% | 108 | 84 |
| Line | 3,338 / 3,796 | 87.9347% | 3,338 / 3,644 | 91.6026% | 152 | 306 |
| Toggle | 91,288 / 104,480 | 87.3737% | 91,288 / 104,480 | 87.3737% | 0 | 13,192 |
| FSM states | 13 / 13 | 100% | 13 / 13 | 100% | 0 | 0 |
| FSM transitions | 22 / 22 | 100% | 22 / 22 | 100% | 0 | 0 |

The same 361 exact, evidence-eligible candidate bins were excluded in the What-if run: 101 Branch, 108 Condition, and 152 Line bins. Covered numerators did not change. URG's aggregate DUT score moves from 86.94 to 92.01; that aggregate is supplemental and does not replace the per-metric rows above.

**Answer:** after applying only the 361 currently evidence-eligible candidates, **13,594 exact uncovered bins remain**: 12 Branch, 84 Condition, 306 Line, and 13,192 Toggle bins. FSM has no open state or transition bins. This is a What-if result, not an approved adjusted signoff.

The smallest bounded closure batch is the **12 remaining Branch bins**. They comprise nine stimulus/checker-review bins, two interpolation cadence bins, and one guarded AXI-Lite address-response bin. Each still needs either a legal public-interface witness with an independent checker or current-source, non-vacuous Formal evidence followed by exact reviewer approval. Closing these 12 would make Branch 100% for this What-if denominator; it would leave the other 13,582 bins open.

## Baseline and Reproduction Evidence

The analysis uses the Round 12 Product Configuration and VDB set without changing RTL, tests, or compile settings:

- Product RTL source SHA: `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0`.
- Repository HEAD during this analysis: `98620217e8b752cef165fa0c01512e5c34306aff` on `codex/thermo5-linux-dv-signoff-closure`.
- Integrated `thermo5` base: `73577475230a9c4e51273ac7071437f0a7373d48`.
- Configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1 with Identity reset image; AXI-Lite; Generic FIFO.
- Compile fingerprint: `9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a`.
- Tool versions: URG V-2023.12-SP1; Python 3.12.13. The VCS-created Product VDB is from the same source and compile fingerprint.
- Inputs: one Design VDB plus 232 Test VDBs (233 VDBs total). The What-if input-tree manifest reports `same_as_round12_manifest=true`. Raw and Adjusted command path lists are byte-for-byte identical; normalized VDB path-list SHA-256 is `58118a7f4172c1098585655eab58712ce3e10443284fc22ad20b09b534cedb7a`.

The final paired URG runs were repeated after removing three trailing blank lines from the analysis `.el`; URG semantics and the 361 exact exclusions are unchanged. The normalized analysis `.el` SHA-256 is `9a4c29b2ec8ac8392057621a0d65f43fdd9a40abdda9140623e9a94702ee7fbb`. Only URG and its report parser were rerun; no VCS regression or source change was made. The earlier paired run manifests and `.el` hashes are superseded.

Both final URG jobs exited 0, produced dashboards, and had zero warning lines. The Raw command had no exclusion file. The What-if command added `-elfile <analysis-only .el> -excl_strict`. Both used `-metric line+cond+fsm+tgl+branch+assert -format both` and the same 233 VDBs. The exact command arrays, command hashes, run exit codes, log hashes, and VDB manifest hash are recorded in `runs/thermo5_tx_round12_waiver_whatif_20261106/final_pair_execution_manifest.json` (ignored local run evidence).

The reports were independently inventoried with:

```bash
python3.12 tools/hw/thermo5_coverage_denominator.py \
  runs/thermo5_tx_round12_waiver_whatif_20261106/final_clean_pair_raw \
  runs/thermo5_tx_round12_waiver_whatif_20261106/final_clean_pair_raw_inventory

python3.12 tools/hw/thermo5_coverage_denominator.py \
  runs/thermo5_tx_round12_waiver_whatif_20261106/final_clean_pair_adjusted \
  runs/thermo5_tx_round12_waiver_whatif_20261106/final_clean_pair_adjusted_inventory
```

The parser-derived Raw and Adjusted counts match the denominator deltas in the final URG reports. Both final inventory summaries reproduce the table above exactly. The portable command/log hash summary is [here](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_whatif_urg_execution_summary.json); complete local command arrays and report trees remain under ignored `runs/`. The exact Round 12 source/VDB records are in `data/thermo5-r12/`.

## GitHub 371 vs Local 369 Waiver Rows

I fetched `docs/verification/thermo5_tx_waivers.csv` from the GitHub `thermo5` branch during this audit and compared IDs with the local active candidate CSV:

| Source | Rows | Difference |
|---|---:|---|
| GitHub `thermo5` | 371 | Two rows not present locally |
| Local Round 12 candidates | 369 | No local-only IDs |

The two remote-only rows are not lost candidates. Round 12 Raw URG already reports both as covered, so they were archived as “no waiver required”:

| Waiver ID | Exact item | Raw result | Treatment |
|---|---|---:|---|
| `W-75530ed17d5b396a4e9b` | `thermo5_dpd_axi_lite_cfg.sv:142`, line bin, instance `thermo5_sku_uvm_tb.dut.u_cfg` | 1/1 HIT | Excluded from the active candidate list; retained in the raw-hit archive |
| `W-d7cb262894a5aae016b6` | `thermo5_dpd_axi_lite_cfg.sv:135`, branch/case bin, instance `thermo5_sku_uvm_tb.dut.u_cfg` | 7/7 HIT | Excluded from the active candidate list; retained in the raw-hit archive |

GitHub file SHA (Git blob SHA): `d3e7eebefb61fef68089101779db70ee647f68fa`. The local active CSV remains 369 rows; no official row was edited by this analysis.

## Candidate-by-Candidate Disposition

Every one of the 369 local candidate rows was checked against its exact instance, source file hash, line/bin ID, product source SHA, product configuration and native URG mapping. All 369 source-file hashes match the current working source, all bind to product source SHA `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0`, and all have exactly one native URG mapping. No `MAPPING_ERROR` was found. The full row-level audit is in `data/thermo5-r12-whatif-20261106/thermo5_tx_round12_candidate_audit.csv`.

| Classification | Count | Metrics | Evidence review | Used in What-if `.el`? |
|---|---:|---|---|---|
| `ELIGIBLE` | 361 | 152 Line, 101 Branch, 108 Condition | Current-source exact configuration/parameter evidence and unique exact URG mapping. 344 rows rely on the product's `PAIR_LOOKAHEAD=0`; 17 are exact fixed-product-parameter guard cases. This is not a Formal proof and still requires independent reviewer approval for official waiver status. | Yes, analysis only |
| `NEEDS_REPROOF` | 4 | 4 Branch | Formal runs exist, but their recorded product source SHAs (`19d295360aa6438f4af20e7a6ab44bfebf2fc1ea` or `1236d49c72360aa62e316aea147528d93a1b3705`) predate Round 12. | No |
| `MAPPING_ERROR` | 0 | — | All candidate rows map to one native URG object. | No |
| `REACHABLE` | 0 | — | No candidate row was classified reachable. This does not mean all remaining raw bins are unreachable; they remain OPEN unless independently proven. | No |
| `UNRESOLVED` | 4 | 4 Branch | Stale or incomplete Formal/configuration context; no current-source non-vacuous proof is bound to these exact bins. | No |

The 245 selected native URG objects represent the 361 exact raw bins: 36 line blocks, 101 branch objects, and 108 condition objects. For the 152 Line records, every unhit raw Line bin in each selected native block has its own current product-configuration candidate; no broader source block was added. The What-if `.el` passed `-excl_strict` with zero URG warnings. It is not copied into the official approved `.el`.

### Candidates withheld from this What-if

| Classification | Waiver ID | Instance / source | Exact URG bin | Why withheld |
|---|---|---|---|---|
| NEEDS_REPROOF | `W-9010fccd0889b46ea284` | `u_cfg`, `thermo5_dpd_axi_lite_cfg.sv:246` | `190:0/-/-/-/-/1/0/-/default/-/-/-/-/-/-/-/-/-` | Formal product SHA is stale |
| NEEDS_REPROOF | `W-32b5745433f0ff75d5c2` | `u_cdc`, `dsm_axis14_to_core8_cdc.sv:146` | `122:0/-/1/1/0/-/-/-/-/-/-/-` | Formal product SHA is stale |
| NEEDS_REPROOF | `W-a9fc97093bdddfb7f5aa` | `u_cdc`, `dsm_axis14_to_core8_cdc.sv:215` | `122:0/-/1/-/-/0 2 4 6/1/-/1/1/-/-` | Formal product SHA is stale |
| NEEDS_REPROOF | `W-98a39b6429bbed7c29ad` | `u_cdc`, `dsm_axis14_to_core8_cdc.sv:141` | `122:0/-/1/-/-/default/-/-/-/-/-/-` | Formal product SHA is stale |
| UNRESOLVED | `W-fca77c64e5465f089f37` | `u_interp_2`, centered interpolator `:129` | `129:1/-` | Stale/incomplete Formal context |
| UNRESOLVED | `W-e8e68602c739b86a80b5` | `u_interp_2`, centered interpolator `:217` | `182:0/0/-/1/-/-/-/-/-/-/-/-/-` | Stale/incomplete Formal context |
| UNRESOLVED | `W-f83f4a14b37b232df778` | `u_interp_2`, centered interpolator `:223` | `182:0/0/-/-/1/1/-/-/-/-/-/-/-` | Stale/incomplete Formal context |
| UNRESOLVED | `W-ccf37502b42fd61c4cd7` | `u_interp_1`, centered interpolator `:229` | `182:0/0/-/-/-/-/1/-/-/-/-/-/-` | Stale/incomplete Formal context |

Source hashes and the exact source excerpts for all eight withheld rows are retained in the row-level audit CSV. None were silently converted to unreachable waivers.

## Exact Remaining Coverage by Root Cause

The 13,594-row ledger below is generated by subtracting only the 361 selected candidate `raw_bin_id` values from the Round 12 raw exact-bin ledger. Every remaining entry is marked `OPEN`; the original Bin ID, metric, instance, source position, source hash, root-cause task and suggested next action are preserved. Counts agree with the final Adjusted URG denominators.

| Metric | Root-cause class | Remaining exact bins | Root-cause tasks | First action |
|---|---|---:|---:|---|
| Branch | Guarded address decode | 1 | 1 | Legal AXI-Lite transaction and independent BRESP checker; or non-vacuous proof |
| Branch | Legal stimulus / checker review | 9 | 9 | Target each exact decision with legal interface stimulus and independent checker |
| Branch | Product cadence alignment | 2 | 2 | Derive 14:8 ingress and centered-stage cadence; add product-bound witness |
| Condition | Reset release / state hold | 80 | 62 | Directed legal reset-release, enable, and stall sequences |
| Condition | Interpolator empty / blocked | 4 | 4 | Legal source bubble plus downstream backpressure, with four-plane checker |
| Line | CDC / residual state | 6 | 6 | Map and witness exact residual-state statements |
| Line | DPD tap history / configuration | 176 | 11 | Review one-tap elaboration and prove or activate exact path |
| Line | Fixed product configuration | 92 | 23 | Bind parameter guards to actual elaborated product values |
| Line | Legal stimulus / checker review | 32 | 32 | Add exact public stimulus and independent checker where reachable |
| Toggle | CDC / residual state | 130 | 6 | Trace residual packing/shift and legal frame-tail behavior |
| Toggle | Counter high bits | 640 | 2 | Derive accepted-sample count needed for every exact bit/direction |
| Toggle | Data value / toggle stimulus | 3,262 | 140 | Classify each signal and create targeted legal data patterns |
| Toggle | DPD tap history / configuration | 8,192 | 8 | Audit the structurally idle pair-1 signals and exact toggle bins |
| Toggle | Fixed product configuration | 24 | 8 | Prove active-tap configuration invariant and map exact signals |
| Toggle | Identity DPD arithmetic | 944 | 4 | Split active-tap state from saturation counter; prove or stimulate each |

There are 318 distinct root-cause task IDs represented by the remaining exact rows (12 Branch, 66 Condition, 72 Line, and 168 Toggle tasks). The Round 12 raw ledger has 415 tasks while an inherited plan reports 416; this analysis does not claim that historical task-count discrepancy is fixed.

### Remaining Branch Bin IDs

| Bin ID | Instance | Source location | Root cause |
|---|---|---|---|
| `9010fccd0889b46ea284` | `u_cfg` | `thermo5_dpd_axi_lite_cfg.sv:246` | Guarded address decode |
| `98a39b6429bbed7c29ad` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:141` | Legal stimulus / checker review |
| `32b5745433f0ff75d5c2` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:146` | Legal stimulus / checker review |
| `a9fc97093bdddfb7f5aa` | `u_cdc` | `dsm_axis14_to_core8_cdc.sv:215` | Legal stimulus / checker review |
| `ccf37502b42fd61c4cd7` | `u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:229` | Legal stimulus / checker review |
| `fca77c64e5465f089f37` | `u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:129` | Legal stimulus / checker review |
| `e8e68602c739b86a80b5` | `u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:217` | Legal stimulus / checker review |
| `f83f4a14b37b232df778` | `u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:223` | Legal stimulus / checker review |
| `0cfac9d3b4f8ffc01d7e` | DUT | `tid32_thermo5_axi_lite_axis_frontend_tx.sv:203` | Outstanding counter saturation guard |
| `280780368b4aad849606` | DUT | `tid32_thermo5_axi_lite_axis_frontend_tx.sv:204` | Outstanding counter underflow guard |
| `4796580247344dc2c731` | `u_interp_1` | `dsm_interp_x2_centered_cubic_vector.sv:255` | Product cadence alignment |
| `f2b36b12b909c892747f` | `u_interp_2` | `dsm_interp_x2_centered_cubic_vector.sv:255` | Product cadence alignment |

For all exact remaining Branch, Condition, and Line IDs, use `data/thermo5-r12-whatif-20261106/thermo5_tx_round12_remaining_exact_uncovered_bins.csv.gz`. It includes a `whatif_candidate_classification` column that identifies the eight stale/unresolved candidates; all other entries are marked `NO_CANDIDATE` rather than implicitly waived.

## Toggle Gap Audit (13,192 Exact Transition Bins)

| Audit bucket | Bins | Classification | Interpretation / next check |
|---|---:|---|---|
| DPD pair-1 sums | 8,192 | Strong fixed-configuration candidate; OPEN, not waived | Four 64-bit signals (`sum_i/q_pair1_comb` and `sum_i/q_pair1_s8`) × 16 lane instances × two transition directions. With `MAX_TAPS=1`, the product loop executes tap 0 only; pair-1 sums stay at their zero initialization. Confirm exact elaboration and reviewer-approved bin mapping before proposing any toggle waiver. |
| Active-tap buses | 120 | Fixed by current product legality; OPEN, not waived | 96 internal `active_taps[2:0]` bins plus 24 cfg/top/vector `dpd_active_taps[2:0]` bins. `MAX_TAPS=1` makes `tap_count_legal` accept only 1; reset and active/pending banks initialize to 1. Add a current-source product-bound invariant and exact mapping before proposing exclusions. |
| DPD `sample_count[12:31]` | 640 | Reachable, not exercised at this duration | Sixteen DPD lanes × 20 bits × two directions. The counter increments for each valid sample and resets with DPD reset. Both transitions of bit *k* require at least `2^(k+1)` accepted samples since reset; bit 31 would require `2^32` increments. |
| DPD `saturation_count` high bits | 848 | Potentially reachable; stress/proof required | Increments on `sat_i || sat_q`. Per lane the open bins comprise one direction for bit 5 and both directions for bits 6–31. The high bits need repeated saturation events; no bounded proof or waiver is inferred here. |
| Other data-value toggles | 3,262 | OPEN stimulus and signal audit | 756 source-file/signal-bit combinations, compressed to 111 normalized signal/instance groups in the summary CSV. Use the exact-bin ledger to select public legal stimuli and independent checkers. |
| CDC residual state | 130 | OPEN reachability | `rem_i_q[192:223]`, `rem_q_q[192:223]` in both directions, plus `rem_count_q[0]` in both directions. These are declared, elaborated product state bits; exact legal reachability depends on source lane packing and residual/frame-tail schedules. |
| Confirmed URG range/counting artifact | 0 | None confirmed | No listed bin was shown to refer to a nonexistent declared bit. For example, product `wr_data` is 466 bits (`2*14*16 + 2 + 16`), so bits `[450:465]` are real payload bits. This is not a blanket proof that every URG mapping is correct. |

These buckets partition all 13,192 exact Toggle misses. The 8,312 fixed-configuration bins (pair-1 plus active-tap buses) are **not** included in the measured What-if exclusions: the current waiver file has no such Toggle candidates, and this round did not create Formal-backed toggle waivers. The remaining 4,880 bins require stimulus or reachability work. The exact per-signal rollup is `data/thermo5-r12-whatif-20261106/thermo5_tx_round12_toggle_signal_groups.csv`.

## Review Artifacts and Signoff Boundary

- [What-if evidence manifest](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_whatif_evidence_manifest.json) — source/config/VDB bindings, classifications, metric counts, and artifact hashes.
- [369-row candidate audit](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_candidate_audit.csv) — exact instance, source hash, product SHA, Bin ID, Formal context, and native URG mapping per candidate.
- [Exact remaining-bin ledger](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_remaining_exact_uncovered_bins.csv.gz) — all 13,594 post-What-if OPEN bins, ordered by metric and root cause.
- [Remaining root-cause summary](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_remaining_root_cause_summary.csv).
- [Toggle root-cause audit](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_toggle_root_cause_audit.csv) and [toggle signal groups](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_toggle_signal_groups.csv).
- [GitHub/local 371-vs-369 reconciliation](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_github_local_waiver_diff.csv).
- [Analysis-only `.el`](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_whatif_ANALYSIS_ONLY_NOT_APPROVED.el) — SHA-256 `9a4c29b2ec8ac8392057621a0d65f43fdd9a40abdda9140623e9a94702ee7fbb`; do not use as the official approved file.
- [Raw vs What-if metric CSV](data/thermo5-r12-whatif-20261106/thermo5_tx_round12_raw_vs_whatif_metrics.csv).

No official waiver status changed: **0 approved, 369 pending, 0 rejected, 0 official exclusions**. The strict final URG rerun used the normalized `.el` SHA above and retained all What-if counts. The Raw URG remains the official coverage view and `RAW_100_OPEN` remains the gate. The separate What-if Adjusted report is 97.7612% Branch, 88.6640% Condition, 91.6026% Line, 87.3737% Toggle, and 100% FSM. Linux DV and FPGA/physical signoff are not changed by this analysis.
