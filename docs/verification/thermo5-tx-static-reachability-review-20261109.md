# Thermo5 TX Static Reachability and Coverage Review

**Status: intermediate audit; Linux DV signoff remains OPEN.** This review classifies the carried Round 17 exact uncovered-bin ledger against the current Thermo5 product RTL. It does not approve waivers, apply URG exclusions, or claim a newly generated What-if report.

## 1. Baseline and evidence binding

The audit started from PR #47 (`codex/thermo5-round17-formal-closure`), local HEAD `a33894e445df07c91899bc76104ffb39a8a656e9`; PR #47's published head was `1867c3212136ce4c950a24a64767a65874cfa59f`. The product-source revision recorded by the Round 17 compile-parent manifest is `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`. All 97 source-file hashes in that manifest match this review checkout. The product RTL aggregate SHA-256 is `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`; the compile fingerprint is `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`.

Product parameters are Centered-Cubic x2+x2, EF2 ORDER=2 / STEP=5120 / 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 with Identity reset image, AXI-Lite control, and Generic FIFO. The compile defines and hierarchy fingerprint are recorded in [`thermo5_tx_r17_compile_parent_manifest.json`](data/thermo5-r17/thermo5_tx_r17_compile_parent_manifest.json).

The source-linked baseline is the 13,171-row Round 16 exact uncovered-bin ledger, confirmed unchanged by the Round 17 report. Round 17 records one Design VDB plus 551 Test VDBs (362 carry-forward and 189 newly generated), VDB manifest SHA-256 `e0f306b30b206df08b6c37991c940d855e4e03d0659640d38c066b4b6897b509`, and URG report-manifest SHA-256 `8dde1764a8a697be66859d8c8dda5671c77bd3bc1546ee29a18d3936152d92df`. The 189 new VDBs added zero exact DUT code hits. The last recorded same-manifest Raw and zero-exclusion Adjusted values are listed below; they are carried evidence, not rerun in this static audit. Tool versions in that evidence are VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1 (`-full64`), VC Formal V-2023.12-SP2, and Python 3.12.13.

The exact VDB inputs are not available for another URG merge in this checkout. The review worktree contains 13 `.vdb` directories, chiefly Formal databases and a one-test smoke database. The broader local workspace has 1,540 `.vdb` directories from unrelated historical runs; no manifest in that workspace binds them to the Round 17 SHA above. The two GitHub Actions runs on the published PR head succeeded, but both have zero artifacts. Reusing a different database would violate the same-input requirement. Therefore the **actual What-if URG is NOT RUN**.

## 2. Classification totals

Every semantic bin ID is unique. The legacy short `bin_id` field has eight collision rows (four duplicate pairs); the audit preserves those IDs and marks the collision while using the unique `semantic_bin_id` / `record_id` as the row identity. This is a legacy ledger-ID collision, not evidence of a VCS/URG mapping defect.

| Classification | Exact bins | Meaning / disposition |
|---|---:|---|
| `STATIC_UNREACHABLE` | 138 | Current-product topology/state invariants structurally prevent these bins. Candidate only; exact native URG mapping and independent review remain required. |
| `CONFIG_UNREACHABLE` | 8,832 | Current elaborated parameters select a different branch/path. Shared RTL remains useful for other supported configurations; retain it. Candidate only. |
| `DEFENSIVE_NEGATIVE_ONLY` | 2 | CDC end-residual branch/line require malformed early TLAST. Preserve the guard; these are not legal-product exclusions. |
| `REACHABLE_UNTESTED` | 0 established | No exact legal witness was demonstrated in this pass. This is **not** evidence that no such bins exist; unresolved bins stay in `UNKNOWN`. |
| `TRUE_DEAD_CODE` | 0 established | No code was proven redundant across all supported configurations. No RTL was deleted. |
| `TOOL_OR_MAPPING_ISSUE` | 0 established | No reproducible native coverage mapping issue was demonstrated. The four duplicate pairs above are confined to the old short-ID column. |
| `UNKNOWN` | 4,199 | The assignment/use path or legal reachability is not established sufficiently. Keep OPEN. |
| **Total** | **13,171** | Exact semantic-bin rows in the source ledger. |

Per-metric counts:

| Metric | Static unreachable | Config unreachable | Negative-only | Unknown | Raw uncovered |
|---|---:|---:|---:|---:|---:|
| Branch | 3 | 104 | 1 | 5 | 113 |
| Condition | 0 | 108 | 0 | 84 | 192 |
| Line | 5 | 428 | 1 | 24 | 458 |
| Toggle | 130 | 8,192 | 0 | 4,086 | 12,408 |

The complete row-level CSV includes unique semantic ID and legacy ID, instance, source line, exact URG signature, source text, branch/condition path, product parameters, source-file/product-source SHA, classification rationale, trace references, and a trace-completeness status. For `UNKNOWN`, the trace status explicitly remains incomplete/open. Candidate rows have their own exact mapping, rationale, source refs, and blank approval fields. See [`coverage_static_reachability_review.csv`](data/thermo5-r17/static_reachability_review/coverage_static_reachability_review.csv), [`thermo5_tx_unreachable_exclusion_candidates.csv`](data/thermo5-r17/static_reachability_review/thermo5_tx_unreachable_exclusion_candidates.csv), and [`thermo5_tx_remaining_open_bins.csv`](data/thermo5-r17/static_reachability_review/thermo5_tx_remaining_open_bins.csv). The latter has 4,199 `UNKNOWN` and two negative-only rows; it does not assert all unknowns are reachable.

## 3. Fixed-configuration and structural audit

### DPD Pair-1 and one-tap history — 8,368 candidate bins

The 8,192 Pair-1 Toggle rows map to 16 elaborated `dpd_memory_poly` lane instances × four signals (`sum_i_pair1_comb`, `sum_q_pair1_comb`, `sum_i_pair1_s8`, `sum_q_pair1_s8`) × 64 bits × two transition directions. With `MAX_TAPS=1`, the loop in [`dpd_memory_poly.v`](../../rtl/dpd/dpd_memory_poly.v#L180) visits only `comb_tap=0`, and `0 < ((1+1)/2)` selects Pair-0. Pair-1 combinational sums are initialized to zero and never accumulated. The Pair-1 registers reset to zero, load those combinational sums only on `pipe_ce`, and otherwise hold (lines 198–230). The product vector wrapper sets `USE_EXTERNAL_TAPS=1` (see [`dpd_vector16_memory_poly.sv`](../../rtl/dpd/dpd_vector16_memory_poly.sv#L100)), so the internal tap-0 fallback and history tap arms are not selected. The 176 DPD Line rows map 11 exact source lines × 16 instances: lines 191–192, 210–211, 238–240, 242–243, and 332–333.

All 8,192 Pair-1 IDs are cross-checked against the [current-Raw Pair-1 review ledger](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review.csv.gz); its [manifest](data/thermo5-r17/final_closure_audit/thermo5_tx_r17_pair1_current_raw_review_manifest.json) says source hashes match and maps every row to the Round 17 report/VDB manifest. The Pair-1 binding-manifest SHA-256 is `4191259502316ccc181c9f8974674652804a9ca1f8547b78c52976df3395aab0`; it records Formal manifest SHA-256 `cd73bcdc6be9b6ca9b6a0b13245100d176e17f813fd0c601e293d5e6fdcf318d` and properties SHA-256 `5858856248a95d42354a2da44767e7d97619f5c88f16071b72ef6a9f4b264ed2`. The existing current-source Formal result reports 64/64 properties proven across 16 lanes, input/output activity Covers reached, reset-only initialization, and zero black boxes. It proves the four Pair-1 accumulators zero under `MAX_TAPS=1`; the scope excludes the AXI-Lite COMMIT/RUN-STOP/CDC lifecycle. Reviewer and approval fields are empty. See [the prior Round 17 Formal matrix](thermo5-tx-round17-approved-exclusion-exact-bin-closure-20261108.md#11-license-recovery-and-current-source-formal-reruns). This is strong product-configuration evidence, not an approved exclusion.

The 176 one-tap history/fallback Line bins are structural/configuration candidates, but no separate Formal result was found that promotes them to a proven waiver. Keep the shared DPD implementation and all defensive logic.

### EF2 `PAIR_LOOKAHEAD=0` — 436 candidate bins

The product parent instantiates four EF2 blocks with only `W` and `CHANNELS` overridden; `PAIR_LOOKAHEAD` retains the module default `1'b0` (see [`tid32_cartesian_ef2_fs4_gt_tx.sv`](../../rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv#L15) and [`tid32_thermo5_fs4_multipa_tx.sv`](../../rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv#L80)). The 428 pair-helper bins are 236 Lines, 84 Branches, and 108 Conditions guarded by the disabled look-ahead path. Eight more bins are the four invalid-parameter guard Lines and four Branches; the product uses W=16 and CHANNELS=32. Existing product-parameter Formal reports 2/2 assertions proven and the invalid-parameter / enabled-lookahead Covers uncoverable within its stated scope. Preserve the experimental helper and guards for other configurations. Do not exclude the rest of the EF2 module: 2,344 other EF2 Toggle bins remain `UNKNOWN`.

### CDC 14:8 residual — 137 static candidates, two negative-only bins

For W=16, SRC_LANES=14, CORE_LANES=8, reset clears the residual vector/count. The complete residual update case writes only counts `{0,2,4,6,8,10,12}`; stalls hold state. Thus `rem_count_q[0]` cannot toggle (two bins), and 14-to-8 packing/drain leaves at most 12 residual samples, so `rem_i_q[223:192]` and `rem_q_q[223:192]` cannot toggle (128 bins). The `rem_count_q + SRC_LANES <= CORE_LANES` true arm is impossible for nonnegative residual count because 14 > 8; its 1 Branch and 3 Lines make four more static candidates. The invalid-residual `case` default adds one Branch and two Lines. These are 137 rows total; source paths, reset, every update, consumer, and exact bin are enumerated in the ledger. Existing scoped Formal reports prove CDC residual-even/legal/bound and unused-buffer-zero properties with residual and stall/accept Covers reached; separate exact CDC default/end-arm checks report their target arm uncoverable under the legal packet contract. This is supporting reachability evidence only, not an URG exclusion. No module-wide exclusion is proposed.

The separate `end_remaining_q > CORE_LANES` path (one Branch and one Line) is classified `DEFENSIVE_NEGATIVE_ONLY`, not a legal-path waiver. The AXI-Lite contract requires packet TLAST at a positive multiple of 32 accepted beats; early TLAST sets a sticky source error. Under the legal 14:8 packet schedule, the end-residual arithmetic does not need the subtract-by-eight continuation. Keep the defensive logic and retain malformed-TLAST checking in the negative suite.

### Other exact product-parameter and topology bins — 20 additional candidates

The previously counted GT/frame-gain group contributes nine candidates: the GT boundary derives both bridge widths from `DATA_W=2*CHANNELS=64` (eight mismatch-guard bins), and the frame-gain block inherits `HOLD_STATE_ON_DISABLE=0` (one opposite-arm Branch). The additional 20 are: DPD `MAX_TAPS` guard (two bins); top-level `DPD_MAX_TAPS` guard (two); interpolator parameter guards (four per-instance Branch/Line pairs, eight); interpolator hold-state false arms (two); stage-2 tail-disabled paths (three Branches and two Lines); and the stage-1 `q0_tail` arm (one structural bin because stage-1 `in_tail` is tied low and its queue metadata copies that input). All source/instance/bin IDs and rationales are in the candidate CSV. The stage-1 tie-off claim does not apply to stage 2, which consumes stage-1 tail metadata. Keep all reusable branches and defensive logic.

## 4. Root-cause inventory for the 4,199 unknown bins

| Existing root-cause label | Branch | Condition | Line | Toggle | Total | Initial next action |
|---|---:|---:|---:|---:|---:|---|
| `DATA_VALUE_OR_TOGGLE_STIMULUS` | 0 | 0 | 0 | 2,478 | 2,478 | Group by signal/bit/direction; try legal zero, signed extrema, alternating, and walking-bit profiles; require the existing bit-true checker and exact URG delta. |
| `IDENTITY_DPD_ARITHMETIC` | 0 | 0 | 0 | 944 | 944 | Split Active-Tap bits from saturation-counter bits; prove configuration source and exercise legal arithmetic profiles. Do not infer all are constant from Identity reset. |
| `COUNTER_HIGH_BITS` | 0 | 0 | 0 | 640 | 640 | Define the product maximum run/overflow contract first. No runtime upper bound currently justifies exclusion. Use block carry/overflow checks only as supplemental evidence, not product URG hits. |
| `RESET_RELEASE_OR_STATE_HOLD` | 0 | 80 | 0 | 0 | 80 | Map each condition to the reset-release/hold state and its legal ready/enable sequence; test only those exact bins. |
| `LEGAL_STIMULUS_OR_CHECKER_REVIEW` | 2 | 0 | 24 | 0 | 26 | Derive per-bin preconditions, then add minimal legal directed tests with independent monitor/checker. |
| `FIXED_PRODUCT_CONFIGURATION` | 8 | 0 | 0 | 24 | 32 | Recheck elaborated value and runtime mutability for each exact source/instance; current evidence is not enough to classify these as exclusions. |
| `INTERPOLATOR_EMPTY_OR_BLOCKED` | 0 | 4 | 0 | 0 | 4 | Target empty/blocked transitions separately with legal valid/ready and frame-tail timing. |
| `PRODUCT_CADENCE_ALIGNMENT` | 2 | 0 | 0 | 0 | 2 | Verify legal 56-sample frame/cadence setup and checker before concluding unreachable. |
| `GUARDED_ADDRESS_DECODE` | 1 | 0 | 0 | 0 | 1 | Exercise the public AXI-Lite address/response path; retain the guard until an exact native-bin check says otherwise. |
| **Total** | **5** | **84** | **24** | **4,086** | **4,199** | Keep every row OPEN until a witness, proof, or reproducible tool issue closes it. |

The five unknown Branch IDs are `TXB-3df5f13a8d51ee9bdea5` (AXI-Lite write response/default nested path), `TXB-33db6d34081fd3b6ec60` and `TXB-9141942b3f6f51689217` (interpolator stage queue `push_input` arms), and `TXB-e99262dd92665c3b9ea8` / `TXB-c16debdf7d9cbab220ac` (outstanding counter saturation/underflow guards). The four unknown Interpolator Condition IDs are `TXB-5289de10c1a887214158`, `TXB-ab53b1aadded931bc157`, `TXB-909c9c41ce328d3b5464`, and `TXB-1f1ce5bdcc2c308628e9`; their complete operand tuples are in the open CSV. The 80 Reset/State-Hold Condition, 24 Line, and 4,086 Toggle IDs and source positions are also enumerated there. The two negative-only IDs are `TXB-85afd49f35a994cc290c` (CDC end-residual Branch) and `TXB-e4810d348ea657bf627a` (CDC subtract-by-eight Line); both remain defense logic, not legal-path exclusions.

`REACHABLE_UNTESTED` requires an established legal path that the current tests failed to exercise. This pass did not classify any remaining exact bin at that confidence. A focused centered-cubic bubble/stall test was identified, but not run: the installed VCS launcher fails before compile on this WSL2 kernel (see Section 6). Therefore no new DUT Coverage Hit or directed-test PASS is claimed.

## 5. Raw vs What-if Adjusted URG

| Metric | Last recorded Raw | Last recorded official Adjusted | Approved exclusions | Actual new What-if |
|---|---:|---:|---:|---|
| Branch | 524/637 (82.26%) | 524/637 (82.26%) | 0 | **NOT RUN** |
| Condition | 657/849 (77.39%) | 657/849 (77.39%) | 0 | **NOT RUN** |
| Line | 3,338/3,796 (87.93%) | 3,338/3,796 (87.93%) | 0 | **NOT RUN** |
| Toggle | 92,072/104,480 (88.12%) | 92,072/104,480 (88.12%) | 0 | **NOT RUN** |
| FSM states | 13/13 (100%) | 13/13 (100%) | 0 | **NOT RUN** |
| FSM transitions | 22/22 (100%) | 22/22 (100%) | 0 | **NOT RUN** |

The official 371-ID waiver reconciliation remains two `RESOLVED_BY_RAW_HIT` plus 369 pending (361 earlier eligible, four needing reproof, four unresolved), with zero approvals. The 8,970-row static/configuration candidate file is a separate bin-level technical review set; it is not a reviewer decision and is not automatically interchangeable with those official waiver records.

No actual What-if Adjusted URG was run. If every one of the 8,970 technical candidates were eventually approved and mapped exactly, the arithmetic projection would leave 4,201 bins: Branch 6, Condition 84, Line 25, Toggle 4,086. The corresponding denominator-only figures would be Branch 524/530 (98.87%), Condition 657/741 (88.66%), Line 3,338/3,363 (99.26%), Toggle 92,072/96,158 (95.75%). **These are not URG measurements or approved coverage.** No `.el` was generated, no native URG mapping was revalidated, and no independent reviewer approved any candidate. Official zero-exclusion Adjusted remains identical to Raw, with 13,171 uncovered bins.

## 6. Closure recommendation and signoff

1. Independent reviewer first checks the 8,192 Pair-1 rows against the exact current source, formal manifest, proof scope, product hierarchy, and each URG native toggle bin. The reset-only leaf result does not establish the whole AXI-Lite configuration lifecycle.
2. Review the 778 non-Pair-1 structural/configuration candidates by evidence group. Confirm each parameter at the elaborated instance and reject any row whose native bin mapping is not exact. Keep candidates pending until a reviewer identity and approval reference are supplied.
3. Reconstruct the exact one-Design/551-Test VDB set or regenerate that same set from a frozen source/compile manifest. Only then can Raw and Analysis-only What-if URG be run on identical inputs. Save native bin inventories and the generated `.el`; do not mutate the VDB.
4. Use the open ledger to create minimal legal tests for the 5 Branch, 84 Condition, 24 Line, and 4,086 Toggle unknown rows. Start with Reset/State Hold, the four exact interpolator condition bins, the two queue `push_input` paths, and the exact AXI-Lite guarded-address signature; then signal-group data toggles. Stop any batch that yields no exact DUT-bin delta and revisit the reachability hypothesis.
5. Keep the two malformed-TLAST defensive bins in the negative-test audit. Define a product run-time bound before disposition of the 640 counter-high-bit toggles.

No RTL, Product parameter, assertion, official Waiver, or URG denominator changed. The ledger builder checked all 97 compile-parent hashes, all 13,171 ledger source hashes, 8,192 exact Pair-1 ID mappings, and class totals. VCS smoke was attempted with `/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -ID`; default launch exits 1 because it selects a non-existent `linux/bin/vcs1`. The `VCS_ARCH_OVERRIDE=linux64` retry exits 1 with “Linux version 6.6.87.2-microsoft-standard-WSL2 is not supported.” Both logs are under ignored `runs/thermo5_static_reachability_20261109/` (SHA-256: `bedce869a98a3d9b3b091cb11d0d52960a25d40b1f9e4fbcd7fef83f7692d093` and `014f33392fd1e9b278321b665ec6e02302e0820ad4545dd0a3ca2718a9225d9d`). The URG `-version` probe also exited 1 with a VCS_HOME helper lookup error (log SHA-256 `bd2186c6e7d11b83f1bb80bfac5a4f9c3e90b9578eeed1592f44528216718ae8`). No compile started, so no directed simulation, URG, or VC Formal ran in this pass. `git diff --check` passed. **Linux DV signoff remains OPEN; no actual What-if Adjusted Coverage is available from the currently present artifacts. FPGA/XPM/GT/Vivado/physical RF signoff is outside this review.**

## 7. Generated artifacts

- [`build_thermo5_static_reachability_review.py`](../../tools/hw/build_thermo5_static_reachability_review.py) regenerates the three CSVs and summary manifest from the checked-in source ledger and Round 17 evidence.
- [`coverage_static_reachability_review.csv`](data/thermo5-r17/static_reachability_review/coverage_static_reachability_review.csv): 13,171 per-bin records.
- [`thermo5_tx_unreachable_exclusion_candidates.csv`](data/thermo5-r17/static_reachability_review/thermo5_tx_unreachable_exclusion_candidates.csv): 8,970 pending technical/reviewer candidates; every row says `official_exclusion=NO`.
- [`thermo5_tx_remaining_open_bins.csv`](data/thermo5-r17/static_reachability_review/thermo5_tx_remaining_open_bins.csv): 4,201 non-candidate rows retained OPEN.
- [`thermo5_tx_static_reachability_review_manifest.json`](data/thermo5-r17/static_reachability_review/thermo5_tx_static_reachability_review_manifest.json): source hashes, input-manifest hashes, row counts, output hashes, zero approvals/exclusions, and `what_if_urg_status=NOT_RUN`.

Generated data hashes: review ledger `c6678af52b912f336097cdf6b6dba53c8f91372e6c7bcaf3294db1ebb90b734d`; candidate ledger `11e4fed459654acca7414c311c81367b273dcc5547ddbbd771c0befb76028d68`; remaining-open ledger `facaa35ae1174ff259b21ef56d4647217cfe0fc98646b7162f1707d08bb9d034`; artifact manifest `0052e665512e984cab4bfcff3e34031785391f61fe67b969fd742bec2781d3c1`; generator `f1aa7eac01763fc7aad202c3ca713bcc6ec1607fd2e15f968b0bafcb842a00aa`.
