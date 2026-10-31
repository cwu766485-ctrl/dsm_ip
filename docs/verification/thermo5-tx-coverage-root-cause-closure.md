# Thermo5 TX Coverage Root-Cause Closure — Step 1/2

## Current-source static EF2 product-path closure — 2026-10-31

The latest exact-source audit retains all **21,732** unhit Raw URG records and
does not apply waivers or `.el` exclusions. The audit disposition ledger now
contains **355 `PROVEN_UNREACHABLE`** records and **21,377 `OPEN`** records
across 470 grouped tasks (97 fully dispositioned tasks, 373 open tasks). The
355 are eleven source-bound Formal bins plus 344 EF2 PAIR_LOOKAHEAD bins whose
product elaboration is disabled by the exact parameter chain. The separate
PAIR_LOOKAHEAD SVA run remains rejected as tautological and is not used as
reachability evidence.

The 344 static product-path records comprise 84 Branch, 108 Condition, and
152 Line bins in the EF2 helper and its selector Branch. The product top is
the exact VCS `thermo5_sku_uvm_tb` compile with AXI-Lite, Centered-Cubic,
EF2 ORDER=2, STEP=5120, and DPD_MAX_TAPS=1. The four-plane parent selects
`g_order2.u_tid` without overriding `PAIR_LOOKAHEAD`, whose RTL default is
zero; the helper's only call sites are under its true arm. The source hashes,
compile command, and 13/13 positive VCS replay witness are checked by the
fail-closed disposition updater. All Raw IDs and denominators remain intact.

The tracked product compile manifest had stale source hashes. It was rebuilt
from the saved exact 13-test VCS compile log and captured parent source
manifest; the generator reports 75 compiled local source files and all 77
source/control entries match. Raw coverage remains Branch 520/637, Condition
601/849, Line 3334/3796, Toggle 83575/104480; `RAW_100_OPEN` remains the
acceptance result. No RTL or product behavior changed.

## Product CDC frame-start alignment — 2026-10-31

The exact Raw Branch `TXB-158c42868bfe37061f07` at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:224` is the `fifo_frame_start &&
(rem_count_q != 0)` protocol-error arm. A new VC Formal V-2023.12-SP2 harness
uses the production 14:8 CDC and Generic FIFO with two consecutive legal
32-beat AXIS packets. It proves every popped frame-start is aligned with zero
residual count and reaches Covers for the first and second frame starts, the
second frame-end pop, and the second output frame end. The exact misaligned
frame-start target Cover is `uncoverable`.

The run has no SVA environment assumptions, zero selected setup violations,
zero black boxes, and no tautology warnings. An initial harness attempt had a
6-bit accepted-beat counter that could not represent its 64-beat stop value;
all Covers were uncoverable and the runner failed. That attempt is retained as
a failed run and is not evidence. The corrected 7-bit harness passed. Exact
commands, source hashes, and report hashes are bound in the current Formal
review JSON; the full reports remain under the ignored `runs/` directory.

At the PR #20 checkpoint this closed exactly one audit-ledger record as
`PROVEN_UNREACHABLE`; the Raw bin and denominator were retained. Raw coverage
did not change: Branch 520/637, Condition 601/849, Line 3334/3796, Toggle
83575/104480. At that checkpoint the ledger had 354 proven-unreachable
records and 21,378 OPEN records. Waivers and active `.el` exclusions were
zero; the gate remained `RAW_100_OPEN`.

## Product CDC frame-end threshold — 2026-10-31

The exact Raw Branch `TXB-7ea7a7506f13f31ca4a9` is the true arm of
`if (rem_count_q + SRC_LANES <= CORE_LANES)` at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:215`, instance
`thermo5_sku_uvm_tb.dut.u_cdc`. A separate Formal harness explicitly ties
`SRC_LANES=14`, `CORE_LANES=8`, uses the production CDC and Generic FIFO, and
sends two legal consecutive 32-beat packets. VC Formal V-2023.12-SP2
non-vacuously proves `frame_end_pop |=> end_pending_q`; the second frame-end
pop is covered at depth 119, and the exact short-final-word target Cover is
uncoverable. There are no SVA environment assumptions, setup violations,
black boxes, or tautology warnings.

The source-bound updater closed exactly this semantic Bin as
`PROVEN_UNREACHABLE`. Raw URG/VDB and denominators are unchanged. Raw remains
Branch 520/637, Condition 601/849, Line 3334/3796, Toggle 83575/104480;
legal Functional Coverage remains 210/210. The ledger now has 355 proven
unreachable records and 21,377 OPEN records across 470 tasks; waivers and
active exclusions remain zero. The gate remains `RAW_100_OPEN`. No product
VCS/URG rerun was needed because no DUT or product compile input changed.
This incremental Formal update is in [Draft PR #21](https://github.com/cwu766485-ctrl/dsm_ip/pull/21), stacked on PR #20 and not merged.

## Latest Centered-Cubic frame-tail Formal follow-up — 2026-10-31

VC Formal V-2023.12-SP2 was rerun after matching both interpolator lane counts
to the product: stage 1 is W=16/LANES=8/APPEND_TAIL_VECTOR=1 with its input
tail tied low; stage 2 is W=16/LANES=16/APPEND_TAIL_VECTOR=0. The stage-2
append-arm Cover includes the full branch prefix (`pop_head && !q0_tail`)
before the source condition. The former constant-parameter assertion was
removed; a state invariant replaced it. This is module-level reachability
under exact product parameters, not a proof of complete two-stage composition.

The final run passed 6/6 assertions and reached 5/9 Covers; the four exact
tail-only Covers were `uncoverable`. The legal `asm_source_stable` input
assumption was reported non-vacuous; setup violations=0, black boxes=0, and no
tautology warnings were reported. The four source-bound Raw Branch records
are now `PROVEN_UNREACHABLE`, but remain in the unchanged Raw denominator:

| Semantic Bin ID | Product instance / source | Exact Formal pair |
|---|---|---|
| `TXB-39a0a549d32bc9ef1e01` | `u_interp_1`, `dsm_interp_x2_centered_cubic_vector.sv:229` | `a_append_no_input_tail` proven; `c_append_tail_head_drop_unreachable` uncoverable |
| `TXB-ef2fb170941b345476dc` | `u_interp_2`, `dsm_interp_x2_centered_cubic_vector.sv:129` | `a_plain_tail_disabled` proven; `c_plain_tail_unreachable` uncoverable |
| `TXB-603e97cceda8c0d4d0ed` | `u_interp_2`, `dsm_interp_x2_centered_cubic_vector.sv:217` | `a_plain_tail_fire_disabled` proven; `c_plain_tail_fire_unreachable` uncoverable |
| `TXB-c79cdf2b9f5b4620688e` | `u_interp_2`, `dsm_interp_x2_centered_cubic_vector.sv:223` | `a_plain_tail_pending_never_set` proven; exact-prefix `c_plain_append_tail_arm_unreachable` uncoverable |

Raw code coverage did not change: Branch 520/637, Condition 601/849, Line
3334/3796, Toggle 83575/104480. The current ledger retains all 21,732 Raw
misses: 9 are formally classified `PROVEN_UNREACHABLE` and 21,723 remain
`OPEN` across 461 open tasks. Waivers=0, exclusions=0, and the gate remains
`RAW_100_OPEN`.

The legal frame-replacement UVM test (seed 610900, 112 output words, two
frames) passed its four-plane bit-true checker, but added no Raw code hits and
is not merged into the product baseline. Do not repeat phase/seed sweeps for
these two line-255 pop/push bins without a new product-timing hypothesis.

Reproduction command:

```bash
export PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH
export SNPSLMD_LICENSE_FILE=27000@localhost
export VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --jobs frame_tail --out-dir runs/thermo5_tx_branch_closure_frame_tail_20261031_r5
```

The review JSON binds the exact DUT/harness/Tcl hashes and `properties.txt`,
`setup.txt`, and console hashes. The full local run is under the ignored
`runs/` directory; generated logs and Formal databases are not committed.

## Latest 13-test current-source audit — product RTL SHA `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea` (2026-10-31)

This section supersedes the focused 12-test current-source snapshot later in this document. The product configuration remains Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120, 20-bit state, 32 chronological lanes, DPD_MAX_TAPS=1 identity reset image, AXI-Lite frontend, and Generic FIFO. The Raw coverage hierarchy contains only elaborated product DUT RTL. Candidate 2/4-tap DPD and PAIR_LOOKAHEAD VDBs, the negative-only test, and the failing source-gap test are separate. No DUT algorithm, denominator, URG database, or active exclusion was edited.

A fresh VCS V-2023.12-SP1 compile replayed 13 directed positive tests with independent data/bit-true checks. The additional legal AXI-Lite DPD saturation test uses a one-tap non-identity Q2.14 image; its 56-word/four-plane output matches generated Python vectors, it produces one TLAST, and each of the 16 DPD lanes observes I/Q positive and negative saturation. The same-compile 12-to-13 test delta is +80 Branch, +16 Condition, +144 Line, and +654 Toggle.

### Functional coverage

The full URG Group Report has 226 records, 214 scoreable records, 210 covered records, and four zero-hit Raw records. All 210 legally applicable positive records are covered. The four zero-hit records are two illegal-only bins duplicated across type and monitor-instance views:

| Exact bin | Product Raw hits | Separate negative hits | Classification |
|---|---:|---:|---|
| `source_cg.cp_packet_quanta.malformed_early` (type and instance views) | 0 | 1 | Illegal-test-only; excluded from legal-positive target, retained in Raw |
| `core_cg.cp_illegal.bad_frame` (type and instance views) | 0 | 49 | Illegal-test-only; excluded from legal-positive target, retained in Raw |

The separate negative run is not merged into positive Raw. Twelve further URG-model Illegal/Excluded records remain reported as produced by URG; no new exclusion is applied. Functional groups: `core_cg` 7/8; `ef2_cg` 34/34; `plane_atomic_cg` 8/8; `read_cg` 11/11; `reset_cg` 2/2; `source_cg` 19/20; `stop_restart_cg` 6/6; `write_cg` 18/18 per type view, with the corresponding monitor view also present. This is 210/210 legal positives across both report scopes.

### Raw DUT code coverage and root-cause inventory

| Metric | Raw covered / total | Raw unhit |
|---|---:|---:|
| Branch | 520/637 (81.6327%) | 117 |
| Condition | 601/849 (70.7892%) | 248 |
| Line | 3,334/3,796 (87.8293%) | 462 |
| Toggle | 83,575/104,480 (79.9914%) | 20,905 |
| FSM state / transitions | 13/13; 22/22 | 0 |
| DUT assertions | 13 SUCCESS / 15 attempted (86.67%) | 2 UNCOVERED; 2 WITHOUT_ATTEMPTS |

Raw and Adjusted are identical. The fail-closed gate returns `RAW_100_OPEN`, with zero approved waivers and zero active `.el` exclusions. The 21,732 unhit records are grouped into 470 exact source/instance/root-cause tasks: 48 Branch, 107 Condition, 114 Line, and 201 Toggle tasks. Nine exact records are `PROVEN_UNREACHABLE` and remain in Raw: the two CDC branches, three AXI-Lite defaults, and four Centered-Cubic frame-tail branches. The remaining 21,723 records across 461 tasks are OPEN. The task ledger uses HIT/PROVEN_UNREACHABLE/WAIVER_CANDIDATE/OPEN vocabulary; there are no approved waivers or applied exclusions.

The one added saturation test increased the same-compile Raw by 80 Branch, 16 Condition, 144 Line, and 654 Toggle bins. Sixty-four Branch hits are the four clamp directions across 16 DPD lanes; 16 are per-lane saturation counters. No new seed or VDB is included without an exact-source compile link and positive checker result.


| Semantic Bin ID | Raw target | Formal result | Raw treatment |
|---|---|---|---|
| `TXB-85afd49f35a994cc290c` | CDC end false-arm Branch at `dsm_axis14_to_core8_cdc.sv:146` | Matching assertion proven; exact false-arm Cover uncoverable under aligned 32-beat Generic-FIFO contract | Retained in Raw; PROVEN_UNREACHABLE |
| `TXB-0260d31bb5bee4f1a4c6` | CDC outer-case default Branch at `dsm_axis14_to_core8_cdc.sv:141` (nested default at line 154) | Residual-legal and exact-default-path assertions proven; exact-default Cover uncoverable; legal advance/frame Covers reached | Retained in Raw; PROVEN_UNREACHABLE |
| `TXB-3df5f13a8d51ee9bdea5` | AXI-Lite write-case default Branch at `thermo5_dpd_axi_lite_cfg.sv:246` | `a_write_case_default_unreachable` non-vacuously proven; matching Cover uncoverable | Retained in Raw; PROVEN_UNREACHABLE |
| `TXB-65f3dfeee7bc0b854f52` | Coefficient-read default Branch at `thermo5_dpd_axi_lite_cfg.sv:135` | `a_coeff_read_default_unreachable` non-vacuously proven; matching Cover uncoverable | Retained in Raw; PROVEN_UNREACHABLE |
| `TXB-74a3bacf0956921ac9bf` | Matching default Line at `thermo5_dpd_axi_lite_cfg.sv:142` | Same exact coefficient-read default property/Cover pair | Retained in Raw; PROVEN_UNREACHABLE |

The condition tuple `TXB-872eb98e51c3229e4c86` remains OPEN: its assertion is proven but not reported non-vacuous. No conclusion is inferred from that result.

### Formal, mutation, and open interface risk

The DPD identity-only saturation harness proves 4/4 no-clamp assertions and reaches input/output Covers; its four clamp Covers are uncoverable only for the fixed unity coefficient image. The AXI-Lite product allows coefficients to be written at runtime, and the legal UVM stress test hits all clamp directions, so no product Raw bin is dispositioned from that restricted proof. The general DPD identity payload-equivalence assertion remains INCONCLUSIVE at depth 252 and OPEN.

The EF2 exact-parameter PAIR_LOOKAHEAD run reports 2 assertions proven and 2 Covers uncoverable, but VC Formal marks both exact goals tautological (`SVAC-TAUT-PROPERTY` and `SVAC-TAUT-COVER`); these goals are rejected as reachability evidence. A later exact-source static parameter-chain audit separately classifies the 344 helper/selector bins as unreachable in the current product elaboration, including its four selector Branch records. The nine Formal dispositions remain source-bound. The CDC disposition is contract-scoped and does not justify unrelated FIFO/XPM paths. The AXI-Lite tuple condition assertion is not non-vacuous, so that condition remains OPEN.

Mutation run seed 1 passed the baseline; both `late_gain` and EF2 `plane_swap` mutants were caught by the independent `[BITTRUE]` scoreboard. The earlier failed mutation-runner invocations are retained as failed setup attempts and not counted as mutation PASS.

The legal-frame 16-cycle source-gap case produces all 112 expected output words but reports 54 underflows and fails the independent checker. AXI-Stream currently defines no maximum legal source gap; do not classify this as an illegal environment or waive it without a service-rate contract.

The executable evidence index is [`thermo5-tx-coverage-closure-index.json`](data/thermo5-tx-coverage-closure-index.json). It binds the product SHA, compile manifest, Raw URG, gate, functional detail, closure artifacts, Formal reports, mutation manifest, commands, and hashes. VCS/URG results are focused AXI-Lite frontend scope. The separate behavioral GT Parent test is not bit-true on payload. Real XPM/GT Wizard, full parent payload checking, complete reachable code closure, DPD identity Formal convergence, FPGA timing/PPA, and physical QAM256 BER remain OPEN. No final signoff or 100% code coverage is claimed.

---


> **Source-scope notice (2026-10-31):** The 18,593-row inventory and formal dispositions described below were generated for the earlier source SHA `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`. A reset-ready RTL fix is now committed at `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`. The focused 12-test Raw report and newly generated current-source gap ledger are recorded in the final section. Do not treat the old-source counters or dispositions as current-source full-suite coverage.

- Raw VCS/URG product source SHA: c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b; the baseline Raw report remains bound to its original compile source manifest.
- The Raw compile source manifest is pinned to base commit `913be930bfcbbad0f78dbc90e06299db3d1bb337`. Current-tree audit differences are listed in the machine-readable summary: the AXI-Lite interface adds read-only frame probes, the UVM package includes an additive diagnostic test, and the UVM top assigns those probes. Their separate diagnostic VDB was not merged into baseline Raw. All product `rtl/` source hashes and the coverage hierarchy match the baseline; the AXI-Lite Formal harness is outside the product VCS compile.
- Source gap inventory: 18,593 rows; original ledger SHA-256 e586d27684fffe4e98b1d4c4bd43b22839c349ef31c07b1779d4a69c4ce45222. Current disposition-ledger SHA-256 540e71bac7f07361578cf04e53e5d9b6766ede48354234fa3f4d2db8de9034bb.
- Expression-aware semantic IDs: 18,593; old ID collisions: 17 groups, 17 extra rows.
- Product: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; 32 chronological lanes; DPD_MAX_TAPS=1 identity; AXI-Lite wrapper and Generic FIFO.
- All code gaps start OPEN. Root-cause labels are review hypotheses, not approved exclusions.
- Raw equals Adjusted; approved waivers 0; exclusions 0.

## Functional Group Report audit — original source SHA `c1fa9f3`

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

## Code coverage and root-cause task inventory — original source SHA `c1fa9f3`

| Metric | Raw covered / total | Raw missing | Closure tasks |
|---|---:|---:|---:|
| branch | 440/637 (69.0738%) | 197 | 53 |
| condition | 583/846 (68.9125%) | 263 | 107 |
| line | 3,190/3,796 (84.0358%) | 606 | 123 |
| toggle | 86,951/104,478 (83.2242%) | 17,527 | 209 |

The task CSV has 492 source/instance/location-rooted tasks. The compressed bin ledger preserves all 18,593 source rows and includes expression-aware IDs, URG Condition text, instance, source file/location, product SHA, and status. For this original source SHA, 8 rows are PROVEN_UNREACHABLE and 18,585 remain OPEN; Raw URG is unchanged.

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

## Outstanding-word guard Formal attempt (2026-10-31)

The product-bound `thermo5_axil_outstanding_harness` targeted the saturation guard at line 203 (`TXB-e99262dd92665c3b9ea8`) and the zero-count decrement guard at line 204 (`TXB-c16debdf7d9cbab220ac`). It elaborated the fixed AXI-Lite product configuration: Centered-Cubic, EF2 ORDER=2/STEP=5120, one-tap identity DPD, Generic FIFO. A legal 32-beat AXIS source and legal AXI-Lite RUN write were sequenced in the harness; PA backpressure remained arbitrary. AXI/source/core clocks used exact scaled periods 35/28/16.

VC Formal V-2023.12-SP2 had no external SVA assumptions, zero clock/glitch/loop/multidriver setup issues, two non-vacuous assertions, and reached source, core, and output acceptance Covers. After 489.77 seconds, both assertions and both exact guard Covers were INCONCLUSIVE (depths 142/102 and 141/103 respectively). No counterexample was found, but no proof or Cover witness was obtained. Both ledger rows remain OPEN; no disposition, waiver, exclusion, or Raw merge was applied. Full run properties, setup and console hashes are in [`thermo5-tx-outstanding-counter-formal-evidence.json`](data/thermo5-tx-outstanding-counter-formal-evidence.json); raw logs remain under the ignored `runs/thermo5_axil_outstanding_formal_20261031_retry/` directory.

## Centered-Cubic product cadence review for two missing pop/push branches (2026-10-31)

The exact missing bins are `TXB-9141942b3f6f51689217` in `g_interp1_centered.u_interp_1` and `TXB-33db6d34081fd3b6ec60` in `g_interp2_centered.u_interp_2`, both at the `end else if (push_input)` arm of `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:255`. A reproducible AXI-Lite product test sends two legal back-to-back 32-beat packets using the fixed product configuration. The independent four-plane scoreboard checks all 112 output words, and DPD lane sample/saturation counts are checked.

The same waveform seed (610901) was run across nine source-start and seventeen RUN-start phase placements. All 26 UVM runs passed with zero errors/fatals. In each interpolator, the test observed `q_count==1 && q0_end` once and the corresponding `pop_head` once; neither instance asserted `push_input` on that pop edge. Thus neither exact Raw Branch bin was hit. One phase VDB was merged into a separate diagnostic URG report; the Raw metrics and denominator were unchanged: line 3190/3796, condition 583/846, branch 440/637, toggle 86951/104478; target branch coverage delta was zero. Standalone stage-level Formal has a valid pop/push Cover witness, so the paths are not structurally impossible; product-bound cadence reachability remains OPEN. No waiver or exclusion was created.

Exact VCS and URG command lines, source hashes, all 26 log hashes, VDB tree hash, URG report hash, coverage gate, target Bin IDs, and per-instance event counts are recorded in [`thermo5-tx-frame-replacement-coverage-review.json`](data/thermo5-tx-frame-replacement-coverage-review.json). The next action is a product-bound reachability/root-cause analysis of the 14-to-8 ingress cadence and frame-tail timing. Do not repeat random seeds or convert this miss into a Formal disposition without a non-vacuous product-bound proof.

## Causal interpolation test scope check (2026-10-31)

After VCS license recovery, the existing `thermo5_sku_interp1_empty_blocked_test` was compiled with the fixed Centered-Cubic product profile (AXI-Lite, EF2 ORDER=2/STEP=5120, one-tap identity DPD, Generic FIFO) and run at seed 620131. Compilation passed, but the UVM test timed out after 10,000 core cycles with one fatal; its bit-true completion checker and pass marker were not reached. The test waits for `vif.interp1_stall_window`, while the `THERMO5_CENTERED_CUBIC` branch of the UVM top assigns that causal-FIR probe to constant zero (`dv/uvm/tb/thermo5_sku_uvm_tb.sv:217`). Its `interp1_stage1_empty_blocked` hit counter is also tied low in that branch (`:216`). This is a test/configuration scope mismatch, not evidence of a DUT failure.

The failed run's VDB remains separate and was not merged into product Raw; no coverage delta is claimed. The run command, current source hashes, compile/run log hashes, VDB tree hash and exact cause are captured in [`thermo5-tx-centered-test-scope-evidence.json`](data/thermo5-tx-centered-test-scope-evidence.json). The test README now labels the scenario causal-FIR-only. Product closure still requires a Centered-Cubic-specific legal stimulus/checker or audited Formal result; do not rerun this causal-stage test under the Centered-Cubic product defines.

## Product 14:8 CDC immediate frame-end Branch (2026-10-31)

The exact Raw Branch is `TXB-222f90478aca6253d9a5` at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:210`, instance
`thermo5_sku_uvm_tb.dut.u_cdc`. The fixed product elaboration uses
`SRC_LANES=14`, `CORE_LANES=8`, and the Generic FIFO. In the enclosing legal
path, the residual count is one of 0, 2, 4, or 6; therefore adding a 14-lane
source word cannot satisfy `rem_count_q + SRC_LANES <= CORE_LANES`.

VC Formal V-2023.12-SP2 passed at clean source SHA
`bcf1f9a10b7a203e13cefb6fa64efcff0e588815`. The deterministic source holds
VALID continuously, advances its 32-beat packet counter only on handshakes,
and drives constant payload; no environment assumptions are used. The exact
branch assertion is proven and non-vacuous. The matching true-arm Cover is
uncoverable, while Covers reach the enclosing frame-end context (depth 59) and
a completed legal frame (depth 63). The setup report has zero violations and
the model has zero black boxes. Full logs, setup, property report, source
hashes, and command are under
`runs/thermo5_cdc_end_branch_20261031_bcf1f9a/`.

The source-bound disposition closes this one audit-ledger row as
`PROVEN_UNREACHABLE`; the Raw URG bin and denominator remain untouched. The
audit now contains seven such records and 18,586 OPEN rows out of 18,593.
Code coverage percentages do not change. No waiver, exclusion, VDB merge, or
RTL change was made.

## Product 14:8 CDC outer-case default Branch (2026-10-31)

The exact Raw bin `TXB-f787ff8f614d2d391c4c` maps to the `advance` path at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:136` followed by the outer
`case (rem_count_q)` default at line 149, instance
`thermo5_sku_uvm_tb.dut.u_cdc`. The product-bound harness explicitly
elaborates `SRC_LANES=14`, `CORE_LANES=8`, `W=16`, FIFO depth 16, and the
Generic FIFO. A deterministic legal source sends aligned 32-beat packets with
the exact 14:8 clock ratio; no environment assumptions are used.

VC Formal V-2023.12-SP2 passed at clean verification SHA
`eff0c4169d40320ad8bb08e0fb78bc8ce72b2ed7`: both the residual-set invariant
and exact default-path assertion are proven. The path Cover is uncoverable;
legal advancement and a completed legal frame are covered at depths 2 and 63.
The setup report has zero violations and the model has zero black boxes. The
fail-closed runner and complete local evidence are under
`runs/thermo5_cdc_default_branch_20261031_eff0c41/`.

The exact source-bound audit row is now `PROVEN_UNREACHABLE` but stays in Raw.
No URG/VDB, denominator, DUT RTL, waiver, or exclusion changed. Code coverage
remains `RAW_100_OPEN`; eight exact rows are proven unreachable and 18,585
remain OPEN out of 18,593.

## CDC source-reset handshake defect found during end-residual closure (2026-10-31)

Legal-startup Formal review changed the disposition of the 14:8 end-residual Branch investigation. The source holds `TVALID=0` through the first source-clock edge after external reset release, then may assert it while the CDC two-flop source reset synchronizer is still active. On the pre-fix RTL, VC Formal reached the exact `end_remaining_q <= CORE_LANES` false arm together with a product protocol error; the public FIFO ready was not gated by the synchronized local reset. This was a reachable behavior defect, not a configuration-only dead path.

The RTL now routes FIFO readiness through a private `fifo_wr_ready` signal and assigns public `s_axis_tready = s_rst_n && fifo_wr_ready` for both Generic and XPM generate branches. The UVM driver holds `TVALID` low for the first source cycle after external reset release. A directed AXI-Lite product test then starts a legal source stream while the core domain remains reset, checks that the source is backpressured until local reset release, and uses the independent four-plane scoreboard on all 56 output words. VCS V-2023.12-SP1 run seed 610713 passed: 32 beats accepted, 56 words checked, one frame end, zero underflow/protocol error, zero UVM warnings/errors/fatals. Its local run log is `runs/thermo5_cdc_resetready_repro_20261031/vcs_after_gate/thermo5_sku_axil_reset_release_source_test_seed610713.log`.

The clean-source VC Formal repeat at `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea` proves 5/5 CDC assertions; 5/7 Covers are hit, including legal end/frame completion and TVALID during internal reset. The two exact false-arm Covers are uncoverable; the audited Branch mapping and limits are recorded in the current-source snapshot below.

The historical Raw URG and 18,593-row ledger remain bound to pre-fix RTL SHA `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b` and remain unchanged. The focused 12-test Raw report and 22,626-row ledger below are separately bound to `19d2953`; the old-source disposition counts are not transferred. No waiver, exclusion, or denominator change is applied.

## Evidence inputs

- Raw Group Report: runs/thermo5_tx_final_vcs_resume_20261030_41691/product_raw_after_register_access
- Separate expected-negative Group Report: runs/thermo5_tx_product_axil_register_access_20261030/negative_expected_assertions/report
- Source-linked gap ledger: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/thermo5-tx-gate3-coverage-ledger.csv
- Source manifest: runs/thermo5_tx_product_axil_reset_cov_20261030/gap_ledger_after_source_gap_current_20261030/axil_gap_ledger.json
- Closure evidence JSON: docs/verification/thermo5-tx-linux-coverage-closure-evidence.json

## Formal disposition update

The source-bound review closed 8 exact bins as PROVEN_UNREACHABLE; 18585 remain OPEN. Formal Inconclusive is not a closure. Raw URG and its denominator are unchanged; approved waivers and active .el exclusions are both zero.

| Semantic Bin ID | Assertion | Cover | Disposition |
|---|---|---|---|
| `TXB-222f90478aca6253d9a5` | `thermo5_cdc_end_branch_harness.a_immediate_end_arm_unreachable` | `thermo5_cdc_end_branch_harness.c_immediate_end_arm` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-39a0a549d32bc9ef1e01` | `thermo5_frame_tail_harness.a_append_no_input_tail` | `thermo5_frame_tail_harness.c_append_tail_head_drop_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-3df5f13a8d51ee9bdea5` | `thermo5_axil_cfg_coverage_harness.a_write_case_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_write_case_default_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-603e97cceda8c0d4d0ed` | `thermo5_frame_tail_harness.a_plain_tail_fire_disabled` | `thermo5_frame_tail_harness.c_plain_tail_fire_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-65f3dfeee7bc0b854f52` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-74a3bacf0956921ac9bf` | `thermo5_axil_cfg_coverage_harness.a_coeff_read_default_unreachable` | `thermo5_axil_cfg_coverage_harness.c_coeff_read_default_arm_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-872eb98e51c3229e4c86` | `thermo5_axil_cfg_coverage_harness.a_line88_tuple_unreachable` | `thermo5_axil_cfg_coverage_harness.c_line88_tuple_unreachable` | PROVEN_UNREACHABLE; retained in Raw |
| `TXB-f787ff8f614d2d391c4c` | `thermo5_cdc_default_branch_harness.a_exact_default_path_unreachable` | `thermo5_cdc_default_branch_harness.c_exact_default_path` | PROVEN_UNREACHABLE; retained in Raw |

Reviewed candidates with tautological or otherwise invalid Formal evidence remain OPEN:

| Semantic Bin ID | Status | Reason |
|---|---|---|
| `TXB-054d97a87a8d74c36c8b` | OPEN | Not accepted as a Formal disposition: VC Formal reports the MAX_TAPS assertion/Cover as tautological for compile-time MAX_TAPS=1. Retain Raw bin and OPEN status pending separately audited static configuration evidence. |
| `TXB-c79cdf2b9f5b4620688e` | OPEN | Not accepted as a Formal disposition: the assertion a_plain_append_arm_disabled is explicitly reported tautological by VC Formal. Retain Raw bin and OPEN status; no waiver or exclusion. |

## Current-source focused AXI-Lite frontend snapshot at `19d2953` — 2026-10-31

This snapshot uses product source SHA `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`, Centered-Cubic x2+x2, EF2 ORDER=2/STEP=5120, 20-bit state, 32 chronological lanes, `DPD_MAX_TAPS=1` identity, AXI-Lite frontend, and Generic FIFO. The 12-test UVM top instantiates the frontend directly with parameters matching the actual GT Parent, but it does not elaborate the GT Parent, `u_continuous`, GT bridge, or parent clock/reset logic. It is a focused positive VCS subset, not the complete accepted product regression. Separate expected-negative and failing 16-cycle-gap VDBs are not merged.

### Functional coverage

The full Group Report export contains 226 rows, 214 scoreable rows, 210 hits, and four zero-hit rows. The four records are two illegal-only bins duplicated across type and instance views:

| Exact bin | Product Raw hits | Separate negative hits | Classification |
|---|---:|---:|---|
| `thermo5_sku_uvm_pkg::thermo5_sku_coverage::core_cg.cp_illegal.bad_frame` | 0 | 49 | Illegal-test-only; not applicable to legal product coverage |
| `thermo5_sku_uvm_tb.me.obj.core_cg.cp_illegal.bad_frame` | 0 | 49 | Same semantic illegal bin in monitor-instance view; not applicable to legal product coverage |
| `thermo5_sku_uvm_pkg::thermo5_sku_coverage::source_cg.cp_packet_quanta.malformed_early` | 0 | 1 | Illegal-test-only; not applicable to legal product coverage |
| `thermo5_sku_uvm_tb.me.obj.source_cg.cp_packet_quanta.malformed_early` | 0 | 1 | Same semantic illegal bin in monitor-instance view; not applicable to legal product coverage |

All 210 legally applicable positive bins hit. Group counts are `core_cg` 14/16, `ef2_cg` 68/68, `plane_atomic_cg` 16/16, `read_cg` 22/22, `reset_cg` 4/4, `source_cg` 38/40, `stop_restart_cg` 12/12, and `write_cg` 36/36. The four uncovered rows are the illegal-only records above; no functional exclusion was added. Exact report rows and provenance are in [`thermo5-tx-product-19d2953-functional-bins.csv`](data/thermo5-tx-product-19d2953-functional-bins.csv).

### Focused Raw DUT code coverage

| Metric | Raw covered / total | Raw missing |
|---|---:|---:|
| Branch | 440/637 (69.0738%) | 197 |
| Condition | 585/849 (68.9046%) | 264 |
| Line | 3,190/3,796 (84.0358%) | 606 |
| Toggle | 82,921/104,480 (79.3654%) | 21,559 |
| FSM states | 13/13 | 0 |
| FSM transitions | 22/22 | 0 |
| DUT assertions | 13/15 attempted (86.67%) | 2 uncovered; 2 not attempted |

The fail-closed gate returned `RAW_100_OPEN`: zero approved waivers, zero active `.el` exclusions, and Adjusted equal to Raw. It did not alter URG data or denominators.

The current-source ledger has 22,626 unhit records grouped into 493 source/instance/location/root-cause tasks. The table distinguishes Raw missing bins from grouped tasks; the CDC Formal disposition does not remove its Raw bin or denominator. Root-cause labels are triage hypotheses, not waivers.

| Priority / metric | Raw missing bins | Grouped tasks | OPEN tasks | PROVEN_UNREACHABLE tasks |
|---|---:|---:|---:|---:|
| P0 Branch | 197 | 53 | 52 | 1 |
| P0 Condition | 264 | 108 | 108 | 0 |
| P1 Line | 606 | 123 | 123 | 0 |
| P2 Toggle | 21,559 | 209 | 209 | 0 |
| **Total** | **22,626** | **493** | **492** | **1** |

Each grouped task has an exact source position, instance, parameter profile, Raw bin IDs, root-cause hypothesis, next action, and current disposition in [`thermo5-tx-focused-product-closure-tasks.csv`](data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-closure-tasks.csv). The gzip ledger preserves each of the 22,626 individual Raw records. `HIT` records are represented by the separate complete Raw URG inventory; this ledger is specifically the unhit-bin closure queue and therefore contains only `OPEN` and the single Formal-reviewed disposition.

### VCS and Formal evidence

VCS V-2023.12-SP1 compiled the exact frontend parameter profile and passed twelve directed positive runs with independent bit-true/data checkers and zero UVM warnings/errors/fatals. These cover reset release/replay, one- and two-frame streams, 1- and 8-cycle gaps, EF2 positive/negative clamp corners, AXI-Lite access, STOP/drain/restart, CDC residual handling, and boundary commit. The separate expected-negative early-TLAST test passed its assertions but was not merged into positive Raw.

VC Formal V-2023.12-SP2 at this clean SHA proves all 5 CDC assertions; 5/7 Covers are reached, including legal frame completion and TVALID during internal source reset. The exact false-arm Cover for `end_remaining_q > CORE_LANES` is `uncoverable`, while the legal end-arm Cover is reached. The resulting one-bin disposition is limited to the fixed 14:8 Generic-FIFO harness, aligned frame starts, and positive multiples of 32 accepted source beats per frame. It does not prove XPM behavior or arbitrary malformed AXI traffic. Proof used no SVA assumptions, zero black boxes, and no selected setup violations. Machine review and evidence hashes are in [`thermo5-tx-focused-product-formal-review.json`](data/thermo5-tx-current-source-gaps/thermo5-tx-focused-product-formal-review.json); full local Formal artifacts remain under ignored `runs/thermo5_cdc_resetready_repro_20261031/`.

The extended 16-minute DPD Identity proof improved from 1/5 to 4/5 assertions proven. Both no-saturation assertions, saturation-count-zero, and valid-latency are proven; all four endpoint/stall/recovery Covers are reached. The payload equivalence assertion remains non-vacuous but `INCONCLUSIVE` at depth 252. The valid-hold assumption is non-vacuous; reset is modeled through `sim_save_reset` and released to `rst_n==1`; setup reports zero selected violations and the design has zero black boxes. Therefore the DPD payload proof remains `OPEN`, and no DPD Raw bin is dispositioned from this run. Full property, engine, setup, command, and hash evidence is recorded in the CDC reset-ready evidence JSON. This proof does establish the exact no-saturation fact needed to review the identity-image clamp branches; branch dispositions still require explicit source/bin mapping and an exact unreachable Cover result.

The 8-cycle source-gap test passed without adding code-coverage hits. The 16-cycle source-gap test failed its independent stream checker with 54 underflows (64 accepted inputs, two frames, 112 expected output words, no protocol errors); this interface service-rate contract remains `OPEN`, and that VDB is separate. The extended DPD identity Formal is non-vacuous for the payload checker and remains `OPEN` because payload equivalence is inconclusive at depth 252.

See [`thermo5-tx-cdc-resetready-evidence.json`](data/thermo5-tx-cdc-resetready-evidence.json), the current-source focused gap ledger, closure-task CSV, summary, and root-cause manifest under [`data/thermo5-tx-current-source-gaps/`](data/thermo5-tx-current-source-gaps/). This is not final signoff: complete current-source Raw coverage, reachable-bin closure, mutation testing, and DPD Formal remain open. Real XPM/GT Wizard, FPGA timing/PPA, and physical QAM256 BER remain outside this Linux evidence set.

### Actual GT Parent Linux coverage — separate report

After VCS license recovery, a separate run elaborated the real `thermo5_qsfp_gt14_parent` at the same current source SHA. The parent defaults select `INTERP_CENTERED_CUBIC=1`, `TIDSM_ORDER=2`, and `STEP=5120`; the instance overrides `DPD_MAX_TAPS=1`, `INTERP_TAPS=2`, `BYPASS_DPD=0`, and `FPGA_USE_XPM_FIFO=0`. Reset initializes the one-tap DPD image to identity (`c1_re=0x4000` in Q2.14, all other coefficients zero). The Linux testbench replaces board clock/GT vendor models behaviorally, with RX inactive.

The dedicated link-fault test passed its existing PA immediate-blank, sticky-fault, and reset-recovery checks. It accepted 54 TX input beats and observed 24 PA words, but has no bit-true sample-payload checker. Therefore this result establishes only that this targeted parent-level behavioral test passed; it does not extend the frontend UVM checkers or constitute full-chain functional signoff. The TX-only compile hierarchy excludes the two testbench behavioral module definitions `IBUFDS_GTE4` (TB lines 11–20) and `thermo5_qsfp_gt14_probe` (TB lines 22–78); both remain elaborated as stimulus/clock/GT replacements, but their model code is outside the project DUT coverage denominator. Parent Raw is reported separately and has not been merged with frontend UVM Raw:

| Metric | Parent Raw covered / total | Missing | Percent |
|---|---:|---:|---:|
| Line | 3,119/3,868 | 749 | 80.64% |
| Condition | 435/889 | 454 | 48.93% |
| Toggle | 59,820/107,486 | 47,666 | 55.65% |
| FSM | 14/22 | 8 | 63.64% |
| Branch | 351/671 | 320 | 52.31% |
| Assertion | 14/19 | 5 | 73.68% |

Parent URG has no Functional Coverage groups. No waiver, `.el` exclusion, or Adjusted score was applied; the two compile-time module scope exclusions identify testbench models, not uncovered DUT bins. Full commands, configuration, source hashes, VCS/URG versions, VDB tree hashes, and report/log hashes are recorded in [`thermo5-tx-gt-parent-linux-coverage.json`](data/thermo5-tx-gt-parent-linux-coverage.json); raw reports and logs remain in ignored `runs/thermo5_cdc_resetready_repro_20261031/gt_parent_tx_coverage/`.

The actual GT Parent's AXI-Lite coefficient bank is writable: reset selects one-tap unity, but software may commit another legal one-tap coefficient image at a frame boundary. Therefore an identity-only Formal harness is scoped to the reset-default image. It cannot by itself classify clamp branches unreachable for every legal runtime configuration; keep those Raw bins OPEN unless the product contract forbids coefficient writes or an additional legal one-tap configuration is formally/tested.

## Current-source Formal disposition update — `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`

The source-bound review closed 1 exact bins as PROVEN_UNREACHABLE; 22625 remain OPEN. Formal Inconclusive is not a closure. Raw URG and its denominator are unchanged; approved waivers and active .el exclusions are both zero.

| Semantic Bin ID | Assertion | Cover | Disposition |
|---|---|---|---|
| `TXB-85afd49f35a994cc290c` | `thermo5_cdc_end_remaining_harness.a_end_remaining_false_arm_unreachable` | `thermo5_cdc_end_remaining_harness.c_target_false_arm` | PROVEN_UNREACHABLE; retained in Raw |

Reviewed candidates with tautological or otherwise invalid Formal evidence remain OPEN:

| Semantic Bin ID | Status | Reason |
|---|---|---|
| `TXB-054d97a87a8d74c36c8b` | OPEN | MAX_TAPS=1 assertion/Cover is tautological at compile time; no unreachable disposition accepted. |
| `TXB-c79cdf2b9f5b4620688e` | OPEN | a_plain_append_arm_disabled is reported tautological; no unreachable disposition accepted. |
