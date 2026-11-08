# Thermo5 TX Final Closure Review — Round 17

**Date:** 2026-11-08
**Review branch:** `codex/thermo5-round16-coverage-closure` (PR #46, base `thermo5`)
**Decision:** Linux DV signoff remains **OPEN**. This report is an intermediate closure review, not a final signoff.

## 1. Frozen source and evidence baseline

| Item | Value |
|---|---|
| `thermo5` base SHA | `fe315cabf058dd184b6d94ffa4ed3b5fb9916733` |
| Product coverage source revision | `4d92ecb8467b095b50478065e29e9646f2cff27e` |
| Formal harness checkout for the current AXI-Lite proof | `81416724359d99038e2c36bc07692d8dd44c0c63` |
| Product RTL aggregate SHA-256 | `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003` |
| Compile fingerprint | `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7` |
| Product configuration | Centered-Cubic x2+x2; EF2 ORDER=2 / STEP=5120 / 20-bit; DPD_MAX_TAPS=1; Identity reset; AXI-Lite; Generic FIFO |
| VDB manifest | 1 Design + 551 Test VDBs; canonical SHA-256 `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509` |
| URG report manifest SHA-256 | `8dde1764a8a697be66859d8c8dda5671c77bd3bc1546ee29a18d3936152d92df` |
| Compile-parent manifest SHA-256 | `d815447c35abfbca8cc40849b4d24af4acaab13fff49f2fd962b9ed3d8300c6a` |
| Tools | VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1 / CovDB 13.1; VC Formal V-2023.12-SP2; Python 3.12.13 |

The current-source Generic FIFO and AXI-Lite UVM regressions, System Random 110/110, DPD/gain/profile 60/60, COMMIT-boundary/PA-stall 2/2, Reset/pending-COMMIT 8/8, STOP/Drain/Restart, direct scoreboard mutations 6/6, Python reference 64/64 and reset-only Formal smoke passed in the recorded runs. The 189 fresh Test VDBs added in Round 17 contributed **zero exact DUT code-coverage hits** over the 362-Test-VDB carry-forward set. No additional random seeds were started for this closure review.

## 2. DPD Identity Formal root cause

The original Identity runner ended **FAIL** because its required assertion gate was not met. It did not report a SAT counterexample. Four properties were bounded without a proof result; the valid-latency property was proven. Engine outcomes are:

| Assertion | Result | Engine | Depth / cause |
|---|---|---|---|
| `a_identity_payload` | INCONCLUSIVE / bounded | `b8` | depth 221; no counterexample; property is non-vacuous |
| `a_no_saturation_i` | INCONCLUSIVE / bounded | `b8` | depth 221; no counterexample |
| `a_no_saturation_q` | INCONCLUSIVE / bounded | `b6` | depth 2569; no counterexample |
| `a_saturation_count_zero` | INCONCLUSIVE / bounded | `b6` | depth 2569; no counterexample |
| `a_valid_latency` | PROVEN | `e1` | depth 1611 |

The payload-stability assumption is non-vacuous. The max/min endpoint, stall and recovery Covers all have witnesses. Therefore the failure is proof incompletion under the current elastic/stall model, not a demonstrated RTL counterexample. The four unresolved arithmetic/payload assertions remain OPEN.

Two decomposition attempts were run without weakening the assertions:

- The no-stall leaf partition proves 5/5 assertions and reaches 3/3 Covers. It fixes `out_ready=1`, so it proves arithmetic identity, saturation absence and latency only without downstream backpressure.
- The partitioned arbitrary-stall run proves 6/18 assertions and leaves 12 INCONCLUSIVE; the compositional attempt proves 5/18 and leaves 13 INCONCLUSIVE. Both reach the four endpoint/stall/recovery Covers. Promoting arithmetic lemmas did not close the payload/saturation proof; the gain claim regressed to INCONCLUSIVE at depth 289 in the compositional attempt.

No Assertion was edited to weaken its meaning. The full configured TX chain, including coefficient shadow/COMMIT, CDC and frame-boundary application, is not proven by these leaf harnesses.

### Current-source Formal follow-up on `thermo5` HEAD `7708d0e`

The monolithic five-property runner was rerun with VC Formal V-2023.12-SP2 on the current `thermo5` HEAD before the alignment Lemmas were added. Its raw property states are `a_identity_payload` INCONCLUSIVE (depth 94), `a_no_saturation_i` INCONCLUSIVE (94), `a_no_saturation_q` INCONCLUSIVE (94), `a_saturation_count_zero` INCONCLUSIVE (94), and `a_valid_latency` PROVEN. The run had no failed goal or SAT counterexample, four of four endpoint/stall/recovery Covers were reached, and zero black boxes. The fresh per-property output did not expose engine IDs. The `b8`, `b8`, `b6`, `b6`, and `e1` labels in the table above come from the preserved earlier engine report, not from this fresh rerun.

To decompose the arbitrary-stall proof without weakening its claims, the Formal Harness now contains 14 independent data/valid alignment Lemmas covering I/Q at stages S0–S6. All 14 were non-vacuous and PROVEN. The automatic assume-guarantee runner then proved and promoted the gain-identity Lemma, for 19 independently proven intermediate Lemmas in total. In the remaining composed goals, valid latency is PROVEN; payload identity, both no-saturation properties, saturation-count-zero, and eight product/term/pair/sum arithmetic properties remain INCONCLUSIVE. The four endpoint/stall/recovery Covers remain COVERED. This narrows the unresolved proof to arithmetic under arbitrary stalls; it does not close Identity or authorize a Waiver.

The run command, exact Harness hash, property depths, engine-source caveat, and raw log/property SHA-256 values are in [the machine-readable Formal follow-up](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_identity_formal_followup.json). A separate VCS/URG smoke on HEAD `7708d0e` passed AXI-Lite register access and URG report generation for one Test VDB only. It is not a replacement for the 551-Test-VDB official coverage set or a full product regression. The official Round 17 Raw/zero-exclusion Adjusted numbers therefore remain the last same-manifest result; no Waiver is approved and no `.el` is active.

## 3. Other required Formal obligations

| Obligation | Current result | Evidence and remaining limit |
|---|---|---|
| Outstanding Counter saturation/underflow and capacity | **OPEN / INCONCLUSIVE** | Fresh current-source run: five product properties and both guard Covers INCONCLUSIVE; activity Covers for source/core/output and arbitrary source bubble are COVERED. No SAT counterexample; exact manifest and log hashes are in the Formal follow-up JSON. |
| COMMIT lifecycle | **OPEN** | No composed proof of Shadow → COMMIT → CDC Pending → DPD Frame Boundary → Active Epoch → ACK → STATUS/DONE. Directed and randomized tests pass but do not replace this proof. |
| Active-Tap product configuration | **OPEN / runner FAIL** | Four AXI-Lite assertions prove; `a_active_taps_one` (depth 3) and `a_pending_taps_one` (depth 2) are INCONCLUSIVE. Legal/reject-commit Covers are INCONCLUSIVE at depth 3. No assumptions or black boxes; only 2 assertions are counted non-vacuous, below the runner gate. |
| Pair-1 fixed tap | **PROVEN in scoped harness; review pending** | 64/64 lane assertions and 2/2 activity Covers prove for sixteen `MAX_TAPS=1` production DPD lanes with reset as the only assumption and arbitrary `out_ready`. The harness does not compose AXI-Lite COMMIT, RUN/STOP or the whole TX configuration path. |
| EF2 fixed product parameter | **PROVEN in scoped harness; mapping review pending** | `W=16`, `CHANNELS=32`, `PAIR_LOOKAHEAD=0`; 2/2 assertions prove and the enabled-helper/invalid-parameter Covers are uncoverable. This is not itself an URG exclusion. |
| Two product `q1_tail` antecedents | **Scoped proof only; product signoff OPEN** | Two legal 56-sample stage-metadata properties prove non-vacuously and their active-bin Covers are uncoverable in that model. The harness omits intermediate FIFO/DPD composition, so this is not yet full-path proof or waiver approval. |

Exact property/run hashes are indexed in [the Formal/Assertion root-cause JSON](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_formal_assertion_rootcause.json). Formal logs remain in the local ignored `runs/` tree; the JSON binds their result files by SHA-256.

## 4. URG Assertion Failure and Uncovered audit

The product assertion report contains three DUT `FAILURE` rows and two DUT `UNCOVERED` rows. The two `q1_tail` properties occur in both categories: the failure rows record deliberate illegal-frame attempts, while their legal successful-attempt coverage remains uncovered. Thus the five rows correspond to **three unique DUT assertion properties**, not five distinct properties.

| URG row | Exact property and source | Classification |
|---|---|---|
| FAILURE | `dut.u_cdc.unnamed$$_1`, `rtl/axis/dsm_axis14_to_core8_cdc.sv:262`, `(rem_count_q == 0)` | Two failures are from the generic and AXI-Lite illegal-frame tests. Both intentionally send a frame marker off the 56-sample boundary. Logs show the expected RTL assertion, the negative checker marker, sticky protocol error and public-reset recovery PASS. Legal suites pass. Keep this as a defensive assertion and report negative testing separately. |
| FAILURE + UNCOVERED | `dut.u_frontend.g_interp1_centered.u_interp_1.unnamed$$_1`, `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310`, `q1_tail` | Both attempts are from AXI-Lite illegal-frame seed 420102 (early TLAST at beat 15). The test expects the assertion and verifies sticky-error/reset recovery. No legal successful attempt was recorded. |
| FAILURE + UNCOVERED | `dut.u_frontend.g_interp2_centered.u_interp_2.unnamed$$_1`, same RTL line/property | Same illegal-frame seed and expected-negative checker; no legal successful attempt was recorded. |

The two UVM register-map assertions marked `WITHOUT_ATTEMPTS` are library code, not DUT assertions, and are excluded from this DUT classification. Exact test/log references and dispositions are in [the assertion CSV](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_assertion_disposition.csv). The legal metadata proof supports `q1_tail` antecedent unreachability for the stated stage schedule, but full-DUT composition and independent review are still open. No Assertion Exclusion was applied.

## 5. Waiver reconciliation and fail-closed status

The audit fingerprint failure was caused by comparing two hashes from different canonical schemas: the product compile fingerprint (`e723…`) and the Waiver-audit configuration fingerprint (`f0ef…`). The reconciliation now checks them independently and verifies the actual binding chain: product source file hashes, compile-parent source hashes, tool hashes, Raw/Adjusted URG input lists, embedded VDB manifest, canonical VDB hash and equal Raw/Adjusted summaries. It does **not** treat the two unlike fingerprints as equal.

| Inventory | Count / status |
|---|---:|
| Official Waiver CSV rows / unique IDs | 371 / 371 |
| Already hit by Raw, `RESOLVED_BY_RAW_HIT` | 2 |
| Remaining clean review candidates | 369 |
| Candidate classification | 361 ELIGIBLE, 4 NEEDS_REPROOF, 4 UNRESOLVED |
| Candidate exact gap matches / source-hash matches | 369/369 / 371/371 |
| Independent reviewer approvals | 0 |
| Official `.el` exclusions applied | 0 |

The two Raw-hit entries are line bin `W-75530ed17d5b396a4e9b` (`thermo5_dpd_axi_lite_cfg.sv:142`) and branch bin `W-d7cb262894a5aae016b6` (`thermo5_dpd_axi_lite_cfg.sv:135`). They are removed from active candidate scope; no exclusion is needed. The old Round 15 refresh artifact is malformed (370 rows, 368 unique IDs, duplicate IDs and three official IDs missing); it remains preserved as historical evidence. The normalized Round 17 reconciliation uses the official 371-row CSV, not that malformed refresh.

The 8,192 Pair-1 Toggle candidates have now been rebound to the current 551-Test VDB manifest. All 8,192 IDs map to current Raw-open Toggle bins and match their source hashes. The candidate rows still have empty Reviewer/Approval fields, `PENDING_INDEPENDENT_REVIEW`, and `official_exclusion=NO`. See [current Pair-1 ledger](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review.csv.gz) and [its manifest](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review_manifest.json).

The `ELIGIBLE` label means “prepare for independent review,” not “approved.” No Formal or configuration candidate was automatically approved. Since approvals remain zero, no nonempty official `.el` was generated and no Adjusted URG with exclusions was run. The existing Raw and zero-exclusion Adjusted reports use identical VDB inputs and remain identical.

## 6. Coverage-directed closure status

No test was added solely to increase seed count. The Round 17 exact-ledger review reports no new Raw code hits from the 189 fresh VDBs. The current actionable groups are:

| Metric | Raw covered / total | Raw % | Exact open bins | Root-cause groups |
|---|---:|---:|---:|---|
| Branch | 524 / 637 | 82.26% | 113 | 89 legal stimulus/checker review; 21 fixed product configuration; 2 product cadence alignment; 1 guarded address decode |
| Condition | 657 / 849 | 77.39% | 192 | 188 reset-release/state-hold; 4 interpolator empty/blocked |
| Line | 3338 / 3796 | 87.93% | 458 | 244 fixed product configuration; 176 DPD tap/history configuration; 32 legal stimulus/checker review; 6 CDC/residual state |
| Toggle | 92072 / 104480 | 88.12% | 12,408 | 8,192 Pair-1; 2,478 data value/stimulus; 944 Identity-DPD arithmetic; 640 counter high bits; 130 CDC residual; 24 fixed product configuration |
| FSM states | 13 / 13 | 100% | 0 | — |
| FSM transitions | 22 / 22 | 100% | 0 | — |

The 944 Identity-DPD Toggle bins consist of 96 `active_taps` bits and 848 saturation-counter bits; do not carry forward the older “120 Active-Tap” estimate. The 113 Branch / 192 Condition Exact Bin ledger is in [the current Round 17 root-cause ledger](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_branch_condition_ledger.csv); all 13,171 exact uncovered code bins remain in [the Round 16 source-linked ledger](data/thermo5-r16/thermo5_tx_r16_exact_remaining_bins.csv.gz), which the 551-VDB current report confirms unchanged.

Disposition guidance from this audit:

- **PROVEN_UNREACHABLE candidate, pending review:** Pair-1 accumulator nodes under the fixed one-tap elaboration; EF2 helper branches only within the proven `PAIR_LOOKAHEAD=0` parameter scope. Neither group is excluded yet.
- **UNRESOLVED / OPEN:** 25 other exact Branch opportunities, the 192 Conditions, 458 Lines and remaining Toggle groups await a specific legal witness, exact proof or identified tool artifact. The 89 Branch records labelled stimulus/checker review are root-cause labels that cross-cut the separate 80 Pair-Look-Ahead / 8 fixed-parameter / 25 other-open Branch buckets; do not add these counts. The grouped ledger provides each Exact Bin and location; zero new hits means no test is claimed to close them.
- No item is classified as a confirmed `TOOL_ARTIFACT` in this round. No legal reachable RTL was deleted or excluded.

## 7. PR #46 review and merge decision

PR #46 was open Draft with no GitHub review submissions at evidence capture. It changes verification harness/runner and audit tooling in addition to reports/manifests. The local review found no product RTL or algorithm change. The AXI-Lite Formal runner correctly returns FAIL when Active-Tap assertions remain INCONCLUSIVE; the reconciliation utility is fail-closed on source/VDB/report mismatch. Local product regressions pass within their recorded scope; the hosted `licensed-dv` job was skipped. The split Identity evidence still leaves required properties open.

**Review result: pass for intermediate integration only.** The report and Formal runner clearly preserve the OPEN result, so the audit evidence may be merged as an intermediate snapshot; this is not a final signoff merge. No independent Waiver approval is implied, no Exclusion is applied, and no Force Push is used. The final signoff PR remains a separate future gate after Coverage, Waiver, Formal/Assertion and final Regression closure.

## 8. Signoff decision and next exact work

- Product UVM and listed Linux checks: **PASS within recorded scope**.
- DPD Identity under arbitrary backpressure: **OPEN / INCONCLUSIVE**.
- Outstanding Counter, Active-Tap COMMIT and composed COMMIT lifecycle: **OPEN**.
- Legal product `q1_tail`: **OPEN**; negative assertion behavior is correctly observed, but there is no legal successful attempt and full-chain Formal is not complete.
- Waivers: 2 `RESOLVED_BY_RAW_HIT`; 369 candidates pending independent review; 0 approved; 0 active Exclusions.
- Code coverage: Raw and zero-exclusion Adjusted are identical; 13,171 code bins remain. `RAW_100_OPEN`.
- XPM/GT Wizard, Vivado timing/PPA, board/FPGA/RF and physical QAM256: **NOT RUN**.

The next productive step is not more broad random regression. It is (1) an independent review of the Pair-1/EF2 exact mapping packages, (2) proof decomposition for stall-dependent Identity payload/saturation and Outstanding Counter capacity, (3) full-path `q1_tail` contract composition, and (4) one-at-a-time legal directed witnesses for the Exact Branch/Condition groups, accepting a test only when URG reports a new target Bin hit.

Machine evidence and hashes:

- [Waiver reconciliation](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_waiver_reconciliation.json)
- [Formal/Assertion root-cause matrix](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_formal_assertion_rootcause.json)
- [Assertion disposition CSV](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_assertion_disposition.csv)
- [Pair-1 current Raw review package](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review.csv.gz)
- [Final evidence and log hash manifest](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_final_closure_evidence_manifest.json)
- [VCS/URG source and VDB manifest](data/thermo5-r17/thermo5_tx_r17_wsl_vcs_reverification.json)
