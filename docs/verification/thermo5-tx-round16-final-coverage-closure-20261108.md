# Thermo5 TX Round 16 Coverage Closure

**Date:** 2026-11-08
**Decision:** Linux DV signoff remains **OPEN** (`RAW_100_OPEN`).
**Product source:** `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`
**Scope:** TX Linux simulation, URG, Formal, exact-bin and waiver audit. No RX, AI-DPD, Vivado implementation, FPGA, GT hardware, or RF validation was run.

## 1. Baseline and Product Configuration

PR #45, *Thermo5 Round 15 coverage-directed signoff closure*, is already merged into `thermo5` as `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`. The repository's remote `thermo5` ref and the local Round 16 base resolve to this same commit. This round makes no RTL, testbench, frozen algorithm, or product-parameter changes.

The frozen product configuration is Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite control, and Generic FIFO.

| Baseline item | Round 16 value |
|---|---|
| Product RTL aggregate SHA-256 | `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003` |
| Compile-source fingerprint SHA-256 | `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7` |
| Compiled source entries rechecked | 95 / 95; 0 hash mismatches |
| VCS / URG / VC Formal | V-2023.12-SP1_Full64 / V-2023.12-SP1 / V-2023.12-SP2 |
| Python / kernel | Python 3.12.13 / `6.6.87.2-microsoft-standard-WSL2` |
| Coverage VDB set | 1 Design VDB + 362 unique Test VDBs |
| Test VDB carry-forward / additional | 240 preserved by tree hash / 122 additional |
| Raw URG VDB manifest SHA-256 | `75b83f5b49a6fd180f3485f56066a7325a27825edc78284be2d83d24c6fd6fef` |
| Path-free VDB manifest SHA-256 | `d457cd7eb89f8e607a3c18be6197d58982afe93186611dd5be9f76ccb60c4e34` |
| URG report manifest SHA-256 | `8745380d90c08e217a1e7bc8f21cd11fec93dc79eeb88f3e091daff7e76f30b3` |

The VDB manifest proves the 240 Round 15 Test VDB trees are present in the Round 16 set. The 122 additional VDBs include the 110 System Random cases, the two valid targeted directed tests, and control scenarios. The 60-case DPD/Gain/Profile matrix also ran and passed; its coverage data is not counted as new because its VDB content duplicates the already-carried product set. Raw and Adjusted URG consumed the same VDB snapshot. No waiver was approved and no exclusion was active.

## 2. Regression Results

| Suite | Result | Evidence / scope |
|---|---|---|
| Generic FIFO product VCS | PASS | Bit-true, bubbles/backpressure, FIFO boundary/empty, reset sweep, negative-frame tests |
| AXI-Lite product VCS | PASS | Register/configuration, coefficient transport, nonlinear DPD, STOP, reset and boundary tests |
| System Random | PASS, 110/110 | Seeds 760000–760099 and 860000–860009; randomized profiles, source gaps and PA stalls |
| DPD/Gain/Profile matrix | PASS, 60/60 | Identity and legal one-tap coefficients; low/nominal/high gain and profile matrix |
| COMMIT boundary × PA stall | PASS, 2/2 | Seeds 950000–950001 |
| Reset × pending COMMIT | PASS, 8/8 | Seeds 940000–940007 |
| Direct SV Unified Scoreboard mutation | PASS, 6/6 detected | Lost/duplicate/order/frame/config/data fault classes |
| Python reference model | PASS, 64/64 | `cd dv/uvm/refmodel/python && python3.12 -m unittest` |
| DPD one-tap saturation/extreme directed test | PASS | Seed 716001; no new exact DUT code hit |
| EF2 saturation/corner directed test | PASS | Seed 716002; 2,072 PA words checked bit-true; no new exact DUT code hit |
| Exploratory invalid packet-length attempt | EXCLUDED | `PACKET_BEATS=32` violated the required 1,184-beat packet contract and timed out; its VDB was not merged |

The expected-negative tests remain segregated from legal regression results. The aggregate URG assertion report contains three expected-negative failures; these are not reported as legal-test failures. The legal product `q1_tail` properties still have zero legal attempts, so assertion closure is not complete.

The exact VCS compile/simulation commands are recorded in the first line of each corresponding log; the URG invocations are stored in the local `coverage_after_ef2_corner_v2/report_manifest.json`, and Formal invocations are in their per-job manifests. `thermo5_tx_r16_run_log_manifest.json` indexes SHA-256 and size for 977 retained `.log`/JSONL and selected summary files. The simulator logs, traces, vectors, and VDBs remain in ignored `runs/thermo5_round16_fe315ca/`; generated logs and vendor products are not committed.

## 3. Functional Coverage

The current aggregate URG group report has 16/16 covergroups at 100%. The 436/436 legally applicable functional-bin audit is carried forward from Round 15's reviewed legal-bin set; it was not independently re-audited as a new semantic matrix in Round 16. The fresh scenarios passed their DUT integrity/reference checks. Functional coverage does not close the separate DUT Code Coverage or assertion gaps below.

## 4. Raw and Official Adjusted DUT Code Coverage

Raw and official Adjusted use the same VDB set. Since approved waivers and active exclusions are both zero, the numbers are identical.

| Metric | Covered / total | Raw | Approved Adjusted | Excluded | Exact uncovered |
|---|---:|---:|---:|---:|---:|
| Branch | 524 / 637 | 82.2606% | 82.2606% | 0 | 113 |
| Condition | 657 / 849 | 77.3852% | 77.3852% | 0 | 192 |
| Line | 3,338 / 3,796 | 87.9347% | 87.9347% | 0 | 458 |
| Toggle | 92,072 / 104,480 | 88.1240% | 88.1240% | 0 | 12,408 |
| FSM state | 13 / 13 | 100% | 100% | 0 | 0 |
| FSM transition | 22 / 22 | 100% | 100% | 0 | 0 |

**Total open DUT Code Coverage records: 13,171** (113 Branch + 192 Condition + 458 Line + 12,408 Toggle). The ledger has 13,171 unique `record_id` and `semantic_bin_id` values. Four legacy `bin_id` values collide across eight Condition records because URG expression and subexpression entries share the same older key; they remain separate bins and must not be deduplicated. The colliding IDs are `f590f2f86b62a69f82b1`, `311e197f026146db3b24`, `8d9e6e91ab0fe9a07abb`, and `9c594c34b17b7fdcff4a`. Use `record_id` or `semantic_bin_id` for exact review. The 784 Round 15 Toggle hits remain included. The 122 additional Round 16 Test VDBs produced **zero new exact Raw code hits**; none of the four code metrics changed. Therefore no further broad random-seed expansion is justified without a new exact-bin hypothesis.

### Fail-closed Coverage Gate attempt

The current source manifest now contains the required per-file `source_file_sha256` map and audit-tool hash; all 95 compile-source hashes validate. The Gate was then run against the repository's official 371-row waiver CSV and product `.el`. It returned exit code 3 with `COVERAGE_AUDIT_ERROR: waiver audit manifest is bound to a different CSV` when given the Round 16 legacy zero-approval audit. That audit is not a Waiver Pipeline output bound to the current official CSV, so the Gate result is **BLOCKED / NOT PASS**. No waiver was approved and no exclusion was added to work around this check. Raw and zero-exclusion Adjusted URG remain identical and auditable from the same VDB manifest, but the Gate-policy check itself is not signed off. Rebuild a current-source waiver inventory/audit through the fail-closed pipeline and reconcile the two official rows already hit by Raw before claiming Coverage Gate PASS. The failed command/output is hashed at `thermo5_round16_fe315ca/coverage_gate/attempt.log` in the local run manifest.

## 5. Exact-Bin Root-Cause Inventory

Every exact uncovered record is retained in `thermo5_tx_r16_exact_remaining_bins.csv.gz`, with the source location, instance, bin ID, source hash, prior and current source binding, disposition state, and next action. Group totals are:

| Metric | Root-cause groups |
|---|---|
| Branch — 113 | 89 `LEGAL_STIMULUS_OR_CHECKER_REVIEW`; 21 `FIXED_PRODUCT_CONFIGURATION`; 1 `GUARDED_ADDRESS_DECODE`; 2 `PRODUCT_CADENCE_ALIGNMENT` |
| Condition — 192 | 188 `RESET_RELEASE_OR_STATE_HOLD`; 4 `INTERPOLATOR_EMPTY_OR_BLOCKED` |
| Line — 458 | 244 `FIXED_PRODUCT_CONFIGURATION`; 176 `DPD_TAP_HISTORY_CONFIGURATION`; 32 `LEGAL_STIMULUS_OR_CHECKER_REVIEW`; 6 `CDC_OR_RESIDUAL_STATE` |
| Toggle — 12,408 | 8,192 `DPD_TAP_HISTORY_CONFIGURATION`; 2,478 `DATA_VALUE_OR_TOGGLE_STIMULUS`; 944 `IDENTITY_DPD_ARITHMETIC`; 640 `COUNTER_HIGH_BITS`; 130 `CDC_OR_RESIDUAL_STATE`; 24 `FIXED_PRODUCT_CONFIGURATION` |

Branch review has split the 113 exact misses into:

- **80 Pair-Look-Ahead helper branch bins** in `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv:144–189`. The current product elaborates W=16 / CHANNELS=32 and leaves `PAIR_LOOKAHEAD` at its default 0. The current-source parameter proof passes and its `c_pair_lookahead_arm_enabled` cover is uncoverable. These bins remain Raw and are only configuration-waiver candidates pending exact URG mapping review and an independent reviewer.
- **8 additional fixed-parameter candidates** at the parameter guard (`:96`) and Pair-Look-Ahead generate arm (`:231`) across product instances. They remain unapproved candidates.
- **25 OPEN exact Branch bins**: nine legal-stimulus/checker-review bins, thirteen other fixed-configuration bins without sufficient per-bin approval evidence, one AXI-Lite guarded address-decode bin, and two product-cadence/interpolator bins. They need targeted legal witnesses or stronger, exact reachability evidence.

All 192 Condition bins remain unhit: 188 reset-release/state-hold and four interpolator-empty/blocked bins. Exact condition operands and instance paths are in the compressed ledger. All 458 Line and 12,408 Toggle records remain unexcluded; their per-bin source paths and root-cause tasks are enumerated in the same ledger. The 640 counter-high Toggle bins remain open until the product runtime/overflow contract is formally bounded; a counter carry lemma alone is not an unreachability proof.

## 6. Waiver Audit

The repository's official waiver CSV still has 371 PENDING rows. Comparing it to the Round 16 Raw ledger shows 369 exact still-open candidates and two rows already covered by Raw. The clean candidate source is the 369-row Round 13 review file, revalidated against this round's exact ledger and source files:

- 361 `ELIGIBLE` analysis candidates;
- 4 `NEEDS_REPROOF` candidates;
- 4 `UNRESOLVED` candidates;
- 369/369 current source hashes match;
- 369/369 exact Raw bin IDs and bin descriptions map to the Round 16 remaining-bin ledger;
- 0 independent approvals, 0 rejected candidates, and 0 active exclusions.

The four Round 13 `NEEDS_REPROOF` rows retain historical scoped proof summaries, but their original run/log artifacts are not present in this checkout. They therefore remain pending reproduction/review; this report does not upgrade them to current-source Formal PASS.

The local Round 15 refresh CSV was found malformed: 370 physical rows but 368 unique IDs, duplicate rows for `W-92ac451faeb760079ca8` and `W-cd4717ad916b9979a47a`, and missing clean candidate `W-f4e9c70e66ecbf5e4ca2`. Round 16 does not use that malformed file as a source. The reconciliation record documents this and rebuilds the review table from the clean 369-row Round 13 inventory. This is a local evidence-file defect; the original Round 15 file and official 371-row waiver CSV are preserved unchanged. The two Raw-hit rows need to be marked resolved in a separately reviewed waiver-inventory update before the official pipeline audit is regenerated.

The separate Pair-1 review package contains 8,192 exact Toggle bins mapped to 64 current-source Formal properties (16 lanes × four accumulator signals; 128 bit/direction bins per property). It has zero overlap with the 369 legacy candidates. The leaf proof passes all 64 invariants for `MAX_TAPS=1`, with input-accept and output-transfer covers hit and arbitrary output backpressure. It does not include RUN/STOP or the AXI-Lite COMMIT/mailbox/CDC chain. All 8,192 rows have blank reviewer/approval fields and `official_exclusion=NO`.

**No official `.el` was generated or applied in this round.** Pair-1 and all other candidates remain out of Adjusted URG until a real independent approval is recorded. The local zero-exclusion `.el` was used only to regenerate Raw/Adjusted URG; its adjacent audit record is not accepted by the stricter Coverage Gate, as noted above. See `thermo5_tx_r16_waiver_review.csv`, `thermo5_tx_r16_pair1_waiver_review.csv.gz`, and `thermo5_tx_r16_waiver_reconciliation.json`.

## 7. Formal and Assertion Matrix

| Obligation | Round 16 result | Disposition |
|---|---|---|
| Pair-1 accumulator nodes, 16 product lanes | 64/64 scoped properties proven; two activity covers hit | **PROVEN_SCOPED**, pending exact-bin/reviewer review; not a system-chain proof |
| EF2 product parameters / Pair-Look-Ahead default | Two assertions proven; invalid-parameter and enabled-arm covers are uncoverable; no black-box instances | Current product-configuration evidence only; no automatic exclusion |
| AXI outstanding saturation/underflow and capacity | Five assertions and two guard covers inconclusive | **OPEN / INCONCLUSIVE** |
| Full-chain DPD Identity | Scoped output-under-stall leaf job completed; full AXI shadow/COMMIT/mailbox/CDC/TX composition absent | **OPEN**; leaf result does not prove full chain |
| Two product `q1_tail` assertions | Zero legal attempts at both interpolator stages | **OPEN / NO LEGAL ATTEMPTS** |
| COMMIT → Pending → Apply → ACK → STATUS/DONE | Directed and random tests pass, no proof/complete checker composition over every lifecycle stage | **OPEN** |
| Active-Tap configuration | Existing proof remains inconclusive/open | **OPEN** |

The Pair-1 proof is tied to the product RTL hash, compile fingerprint, and Formal manifest in the per-bin review package. The parameter proof's exact W/CHANNELS elaboration and static default are useful evidence, but any Exclusion still requires per-bin mapping verification and independent approval.

## 8. Signoff Decision and Next Closure Work

- **Functional simulation:** the listed fresh regressions pass; functional URG groups are 16/16 at 100%, with the 436-bin legal audit carried forward from Round 15.
- **FSM coverage:** state and transition metrics are 100% on this VDB set.
- **DUT Code Coverage:** **OPEN**. Raw and official Adjusted are both below 100% for Branch, Condition, Line, and Toggle; 13,171 exact bins remain.
- **Waiver:** **OPEN**. No candidate has independent approval; no active Exclusion exists.
- **Formal / Assertion:** **OPEN** due inconclusive outstanding-counter properties, full-chain DPD Identity, missing legal `q1_tail` attempts, and incomplete COMMIT lifecycle proof.
- **FPGA / physical:** not signed off. Real XPM, GT Wizard, CDC/RDC integration, Vivado timing/PPA, board output, and physical QAM256 were not run.

Next work should stay exact-bin-directed: obtain independent review of the Pair-1 and 88 configuration-only Branch candidates; build legal witnesses for the remaining 25 Branches and 192 Conditions; then target the 32 legal Lines, DPD tap-history/identity paths, CDC residuals, and data toggles. Resolve the counter runtime contract and required Formal/Assertion obligations. Keep every unproven or unmapped item OPEN; do not claim 100% until the accepted Raw/Adjusted reports and approvals support it.

## 9. Evidence Index

Machine-readable artifacts are under `docs/verification/data/thermo5-r16/`:

- `thermo5_tx_r16_source_manifest.json` — source hashes, compile defines and tool versions.
- `thermo5_tx_r16_vdb_manifest.json` — complete Design/Test VDB tree hashes and Raw/Adjusted input identity.
- `thermo5_tx_r16_coverage_summary.json` — metrics, group percentages, deltas and signoff state.
- `thermo5_tx_r16_exact_remaining_bins.csv.gz` — all 13,171 exact open bins.
- `thermo5_tx_r16_branch_rootcause_review.csv` — exact Branch decisions and review state.
- `thermo5_tx_r16_pair1_waiver_review.csv.gz` — exact Pair-1 bin/property mapping.
- `thermo5_tx_r16_waiver_review.csv` and `thermo5_tx_r16_waiver_reconciliation.json` — clean 369-item review set and R15 discrepancy audit.
- `thermo5_tx_r16_formal_matrix.json` — Formal/assertion evidence and open status.
- `thermo5_tx_r16_regression_matrix.json` — regression matrix.
- `thermo5_tx_r16_run_log_manifest.json` — relative paths, sizes and SHA-256 for retained run logs, traces and selected summary manifests.
- `thermo5_tx_r16_evidence_index.json` — top-level report/log/VDB/source linkage.
- The Coverage Gate attempt is recorded as `BLOCKED_NOT_PASS`; its exact failure is retained in the indexed run log. This is separate from the successful same-input Raw/Adjusted URG generation.

VDBs, waveforms, logs, traces and vendor tool products remain in local ignored `runs/thermo5_round16_fe315ca/` and are intentionally not committed. This report and its hash indices are the portable review package. No Linux FPGA/physical signoff is claimed.
