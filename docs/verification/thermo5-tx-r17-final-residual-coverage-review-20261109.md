# Thermo5 TX Round 17 Final Residual Coverage Review

**Status: Analysis-only coverage closure; Linux DV signoff remains OPEN.**

**Review branch:** `codex/thermo5-round17-formal-closure`

**Product source SHA:** `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`

**Product RTL aggregate SHA-256:** `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`

**Compile fingerprint SHA-256:** `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`

## Result

The 2,448 supplemental fixed-configuration Toggle candidates were each mapped to one exact native URG bin and were each excluded by strict Analysis-only URG. The runs reported no checksum, mapping, scope, or other URG diagnostics. This is a What-if result: all 2,448 candidates remain pending independent review, and none is an official exclusion.

On the frozen Round 17 set of one Design VDB plus 551 Test VDBs, the existing 8,957 strict candidates left 4,214 bins. Adding the EF2 and Active-Tap candidate batches left 1,766 bins. Two additional directed Test VDBs then hit 66 exact Toggle bins; on the resulting one Design plus 553 Test VDB set, the combined Analysis-only report has 1,700 exact bins remaining.

The newest 66 raw hits are 32 transitions on `sample_count[12]`, 32 on `sample_count[13]`, and both transitions on `shadow_taps[1]`. The 64 counter hits span both directions across 16 DPD lanes. `shadow_taps` is intentionally absent from the 120 Active-Tap exclusion candidates: software can write it, and the new AXI-Lite test observes its readback. No Branch, Condition, or Line numerator changed in the supplemental run.

## Product and Evidence Binding

The product configuration is Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; `DPD_MAX_TAPS=1` with Identity reset image; AXI-Lite; Generic FIFO. Product RTL and frozen algorithm were not changed.

The primary candidate review and strict URG run used the already-bound Round 17 VDB manifest: one Design VDB and 551 Test VDBs, manifest file SHA-256 `b093efb2140adb6faaba6a2669c113ecad8f72bba120e8d572872b446d40c43f`, canonical SHA-256 `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`. The source checkout for that VDB set was `17b88280e98096469a57ba51df5b17d53194911a`. The Round 17 compile manifest and all VDB tree fingerprints matched before and after the run.

The two targeted tests were run separately and then added to the same frozen VDB set for an incremental comparison. This supplemental set contains one Design VDB plus 553 Test VDBs; its canonical manifest SHA-256 is `3a94a52a55549dfc85d63e06e1012244d14dfa13757cf2d6504a06b0327a7ff4`. Added VDB tree hashes are in [the machine-readable evidence](data/thermo5-r17/analysis_only/round17_supplemental_urg_evidence.json). Tools: VCS V-2023.12-SP1 Full64, URG V-2023.12-SP1, Python 3.12.13.

The coverage artifacts and manifests are Analysis-only. Raw URG is preserved. All Raw and What-if scenarios use the same VDB set within each comparison; the 551-Test primary comparison and the 553-Test incremental comparison are reported separately.

## Raw and Analysis-only What-if URG

The table reports `covered / denominator`, percentage, number of exact excluded bins, and remaining uncovered bins. Covered numerators are unchanged by every exclusion batch; only reviewed candidate bins are removed from the Analysis-only denominator.

| Metric | Raw, 553 tests | Raw % | Analysis-only What-if, 553 tests | What-if % | Excluded | Remaining |
|---|---:|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.26% | 524 / 539 | 97.22% | 98 | 15 |
| Condition | 657 / 849 | 77.39% | 657 / 741 | 88.66% | 108 | 84 |
| Line | 3,338 / 3,796 | 87.93% | 3,338 / 3,367 | 99.14% | 429 | 29 |
| Toggle | 92,138 / 104,480 | 88.19% | 92,138 / 93,710 | 98.32% | 10,770 | 1,572 |

The What-if excluded total is 11,405 bins: 8,957 from the prior five Analysis-only batches, 2,328 from the EF2 constant batch, and 120 from the Active-Tap batch. This total is not an official waiver count.

For the exact frozen one-Design/551-Test input, the strict URG results were:

| Scenario | Branch | Condition | Line | Toggle | Uncovered total |
|---|---:|---:|---:|---:|---:|
| Raw | 524 / 637 | 657 / 849 | 3,338 / 3,796 | 92,072 / 104,480 | 13,171 |
| Existing 8,957 candidates | 524 / 539 | 657 / 741 | 3,338 / 3,367 | 92,072 / 96,158 | 4,214 |
| Existing + EF2 2,328 | 524 / 539 | 657 / 741 | 3,338 / 3,367 | 92,072 / 93,830 | 1,886 |
| Existing + Active-Tap 120 | 524 / 539 | 657 / 741 | 3,338 / 3,367 | 92,072 / 96,038 | 4,094 |
| Existing + both new batches | 524 / 539 | 657 / 741 | 3,338 / 3,367 | 92,072 / 93,710 | 1,766 |

With the two supplemental tests, Raw Toggle increases by 66 to 92,138. The same complete exclusion set then leaves 1,700 bins. Exclusion counts are exact: Branch 98, Condition 108, Line 429, Toggle 10,770. Strict URG showed no diagnostics; the script also checked that covered numerators, FSM coverage, and assertion coverage were unchanged across exclusion scenarios. FSM remained 13/13 states and 22/22 transitions. URG assertion counts remained 13 SUCCESS, 3 FAILURE, and 2 UNCOVERED; this round did not alter or waive assertion results.

## Fixed-Configuration Candidate Review

### EF2: 2,328 Toggle candidates

| Signal group | Candidate bins | Current product evidence | Disposition |
|---|---:|---|---|
| `pair_i.*` and `pair_q.*` | 2,144 (1,072 each) | `PAIR_LOOKAHEAD=0`; `pair_i` and `pair_q` are initialized to zero and assigned only inside the `if (PAIR_LOOKAHEAD)` block. The product parent does not override the parameter. | Exact Analysis-only exclusions applied; pending independent review. |
| `q_one_check` | 184 | Derived from fixed `Q_ONE` for W=16 and used by the active arithmetic checks; it is constant in this product configuration but is not dead code. | Exact Toggle exclusions applied; retain the logic; pending independent review. |

The candidates do not include `arithmetic_bounds_comb` or `arithmetic_no_wrap_comb`. Those checks remain in the active path and their uncovered Toggle bins remain open. The EF2 source hash is `852e17a445889491b9ed4f04e94129df82224b68b92322b2edb4534bf7ccd584`.

### DPD Active-Tap: 120 Toggle candidates

With `DPD_MAX_TAPS=1`, the legal tap predicate accepts only `shadow_taps==1`. Reset initializes the shadow, mailbox, pending, and active images to one tap; a legal commit therefore keeps active tap count at one. The exact candidate set covers `active_taps` and `dpd_active_taps` in the elaborated product hierarchy, not `shadow_taps`.

The supplemental AXI-Lite test writes `shadow_taps=2`, checks readback, attempts COMMIT, and checks SLVERR, unchanged active tap count, and error status. This proves that an illegal shadow value is software-writable but does not enter the active product image through a legal COMMIT. It is simulation evidence for review, not a full-chain Formal proof. The six relevant product source hashes and the parameter rationale are recorded per candidate in the extended candidate ledger.

All 120 Active-Tap bins mapped and were excluded by strict URG in the Analysis-only run. The active datapath is not dead code and must not be deleted. `shadow_taps` remains covered by Raw URG; its two newly hit transitions are present in the exact hit ledger.

### Native mapping and official waiver association

The new candidate ledger contains 2,448 unique semantic IDs and 2,448 exact native mappings. Exact `(source, instance, metric, bin)` identities are unique within the new set. The candidates have no exact-bin or semantic-ID overlap with the 367 official rows already mapped to the older candidate set. The official reconciliation separately records 2 Raw-hit rows and 2 pending rows outside that older set.

The official `thermo5_tx_waivers.csv` remains unchanged at 371 unique IDs, all still marked `PENDING`; its independent approval count is zero and official Exclusion count is zero. No reviewer identity or approval reference was fabricated. Thus the official adjusted report remains identical to Raw. Candidate mapping success is not approval.

The native Exclusion files are explicitly Analysis-only:

- [EF2 pair and Q_ONE constant candidates](data/thermo5-r17/analysis_only/f_r17_ef2_pair_and_qone_constants_analysis_only.el) — SHA-256 `9198fadfa82bb3b2bf6332be5c938b15f7c0594275b428aeed11695a16e4d354`.
- [DPD Active-Tap candidates](data/thermo5-r17/analysis_only/g_r17_dpd_active_taps_max1_analysis_only.el) — SHA-256 `b27fde8cb56019fb98127ac174ba6435e690a3d790fef5ba9722112fe62e9195`.

The exact candidate ledger bound to the original 551-Test VDB set is [here](data/thermo5-r17/analysis_only/round17_residual_fixed_config_candidates.csv.gz) — 2,448 rows, SHA-256 `1a4b1314da7ee22847fbe4aee6c4ad42a16e020f37ae29afa091e6c9c0724bc2`.

## Counter Coverage Scope Decision

`sample_count` and `saturation_count` are 32-bit unsigned counters on each `dpd_memory_poly` instance. They are not exposed by the Thermo5 product top-level or AXI-Lite status. The 16-lane wrapper leaves the corresponding module outputs unconnected; the UVM DSP boundary monitor observes them hierarchically for verification/diagnostics. They are nevertheless elaborated DUT logic and remain in the current DUT-only URG denominator.

Both counters reset to zero and use ordinary 32-bit addition, so the RTL arithmetic wraps modulo 2^32; neither has explicit saturation or overflow control. `sample_count` increments on accepted `in_valid`; `saturation_count` increments when the last valid pipeline stage is active and either I or Q saturates.

The 8,232-word directed stream demonstrates both Toggle directions on sample-count bits 12 and 13 across all 16 lanes. The 576 remaining `sample_count[14:31]` direction bins are not unreachable: there is no product lifetime bound that prevents a sufficiently long valid stream from reaching them. The 848 remaining `saturation_count` Toggle bins also remain OPEN; the reset Identity image alone does not prove them unreachable for all legal writable coefficient settings and inputs.

**Scope decision:** retain both counters in DUT Code Coverage for this signoff. No approved scope policy or Exclusion exists for diagnostic counters. A future policy change would need a reviewed verification-plan change and must not be represented as a reachability proof.

Machine-readable scope record: [counter coverage scope CSV](data/thermo5-r17/analysis_only/round17_counter_product_coverage_scope.csv).

## Exact Remaining Bin Inventory

The 553-Test exact What-if ledger contains 1,700 unique semantic bins with native URG identity, hierarchy, source file and hash, source position, prior review label, rationale, and official/What-if status:

- [Complete compressed Exact Bin inventory](data/thermo5-r17/analysis_only/round17_post_directed_whatif_remaining_bins.csv.gz) — 1,700 rows, SHA-256 `bd192903764ecb6e4b26bed8697563c5fe79707aa8ab987664cc87697f77b58b`.
- [Same 551-Test input inventory before supplemental directed hits](data/thermo5-r17/analysis_only/round17_residual_exact_whatif_remaining_bins.csv.gz) — 1,766 rows, SHA-256 `513f4fe7c4b2d24000e53fcc6c35c494b6236fcde4c920e6c12e363dfcdc5f5a`.
- [New 2,448-candidate ledger](data/thermo5-r17/analysis_only/round17_fixed_config_candidates_extended_553_vdb.csv.gz) — 2,448 rows, SHA-256 `ff12d384e27813b9a093ff9eac6bd8e34e386cb49d1f8ba6996757c9a2afd3b0`.
- [66 exact supplemental Raw hits](data/thermo5-r17/analysis_only/round17_directed_target_exact_bin_results.csv.gz) — SHA-256 `d71edd9319fb8421293fee4d87300cf67385902b4b626d97f81c6885c1040290`.

The remaining root-cause groups are:

| Metric | Root-cause group | Exact bins | Current disposition |
|---|---|---:|---|
| Toggle | DPD `saturation_count` / arithmetic group | 848 | OPEN; no all-legal-config reachability proof or independent exclusion approval. |
| Toggle | `sample_count` high bits | 576 | OPEN and reachable over sufficiently long operation absent a lifetime bound; do not waive. |
| Toggle | Other data/value stimulus | 148 | OPEN; exact signals and source positions are in the ledger. |
| Condition | Reset release / state hold | 80 | OPEN; prioritize legal state-directed witnesses and checker review. |
| Condition | Interpolator empty / blocked | 4 | OPEN; prioritize legal queue/tail witnesses. |
| Branch | Legal stimulus / checker review | 9 | OPEN. |
| Branch | Fixed product configuration | 3 | OPEN pending exact proof/reviewer decision. |
| Branch | Product cadence alignment | 2 | OPEN. |
| Branch | Guarded address decode | 1 | OPEN. |
| Line | Legal stimulus / checker review | 28 | OPEN. |
| Line | CDC residual state | 1 | OPEN. |

Of the 1,700 rows, 1,685 remain `UNKNOWN` with incomplete trace evidence; 10 carry a static-review `CONFIG_UNREACHABLE` label, 3 `STATIC_UNREACHABLE`, and 2 `DEFENSIVE_NEGATIVE_ONLY`. These labels are not Formal proofs, approvals, or active exclusions. All 1,700 remain OPEN in both the What-if and official status fields. No `TRUE_DEAD_CODE` was identified, and no RTL was removed.

## Directed Test Evidence

Two targeted UVM tests passed with zero UVM warnings, errors, fatals, predictor mismatches, or scoreboard data/metadata mismatches:

1. `thermo5_sku_axil_config_test`, seed 271030, `CORE_WORDS=8232`: 8,232 PA words; source/CDC/DSP/EF2 event counts were recorded; the independent four-plane bit-true check passed and queues drained. The finite-source/no-EOS test observed 70 late underflow cycles only after the final source beat and zero early-underflow cycles. This is reported explicitly rather than described as zero underflow.
2. `thermo5_sku_axil_register_access_test`, seed 271032: register-access checks passed; 56 writes, 51 reads, 3 SLVERR and 7 DECERR responses were observed; predictor mismatches were zero. The illegal tap write/COMMIT check and legal shadow readback passed.

VCS log SHA-256 values: long stream `f739930d83bbc4829a011adc0172e7dd09454bab6a3122cfa9f5192a7653d523`; AXI-Lite register access `f0210f58bb35af5f474bd2e5d7e1e2d0bfb18eab3b67dcac5524a834707e02ea`. Logs and VDBs remain in ignored `runs/` and are not committed. The full regression and Formal suite were not rerun in this residual-review step.

An earlier direct long-counter test attempt did not issue RUN and is not counted as a pass or included in the VDB set. An initial register-access attempt used a mismatched vector length and emitted an out-of-bounds warning; that run was discarded. Only the clean seed 271032 run is included.

The exact rerun commands are represented by the VCS log command headers and by the two strict-URG manifests under ignored `runs/thermo5_r17_residual_whatif_20261109_run2/` and `runs/thermo5_r17_final_residual_20261109_run5/`. The tracked runner commands are:

```sh
python3.12 tools/hw/thermo5_tx_r17_residual_whatif.py \
  --out-dir runs/thermo5_r17_residual_whatif_20261109_run2

python3.12 tools/hw/thermo5_tx_r17_supplemental_coverage.py \
  --extra-test-vdb runs/thermo5_r17_counter_highbit_20261109/supplemental_vcs/cov_thermo5_sku_axil_config_test_seed271030.vdb \
  --extra-test-vdb runs/thermo5_r17_counter_highbit_20261109/supplemental_vcs/cov_thermo5_sku_axil_register_access_test_seed271032.vdb \
  --out-dir runs/thermo5_r17_final_residual_20261109_run5
```

## Signoff Decision and Next Closure Work

- **Coverage analysis:** strict native mapping and What-if URG completed; 2,448 new candidate bins mapped and applied in Analysis-only runs; 66 supplemental exact Raw Toggle hits were observed.
- **Official Adjusted Coverage:** identical to Raw because all 371 official Waiver records remain pending, approved Waivers=0, and active official Exclusions=0.
- **Linux DV signoff:** OPEN. The 1,700 exact What-if bins remain open, URG still reports 3 assertion failures and 2 uncovered assertions, and required Formal obligations are not closed by this run.
- **Physical signoff:** real XPM, GT Wizard, Vivado timing/PPA, board/RF, and physical QAM256 validation remain outside this Linux coverage review and are not signed off.

Next work should start with independent review of the 2,448 candidate rows and exact source/parameter evidence. For the remaining 1,685 unknown bins, work from the ledger by exact root cause and require a witnessed legal test or a current-source proof. Do not expand random seeds without a predicted exact-bin target. Keep counter high bits and arithmetic/saturation bins OPEN until their legal runtime and configuration contracts are resolved.

Machine-readable run evidence: [Round 17 supplemental URG evidence JSON](data/thermo5-r17/analysis_only/round17_supplemental_urg_evidence.json). Historical 4,214-bin baseline: [Round 17 remaining uncovered report](thermo5-tx-r17-remaining-uncovered-bin-report-20261109.md).
