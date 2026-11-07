# Thermo5 TX Linux DV Final Signoff — Round 13

**Decision: OPEN — NOT FULLY SIGNED OFF.** The Linux simulation and coverage tools are available and were exercised successfully. Functional regression evidence is substantially complete, and same-manifest Raw/Adjusted URG reports were regenerated. However, no Waiver has independent approval, 13,955 Raw DUT code bins remain uncovered, two legal `q1_tail` assertions have no attempts, and required Formal properties remain inconclusive. The report does not claim 100% Adjusted Code Coverage.

## 1. Source and Product Baseline

| Item | Result |
|---|---|
| Repository / working branch | `cwu766485-ctrl/dsm_ip` / `codex/thermo5-round13-closure` |
| Checkout HEAD | `fd65aae8fead67b736205610e59d1f706088774a` |
| Product compile-source commit | `a03c2ddf2b997a3aff7ea54acdd2f6e2f6cdcce0` |
| Product compile fingerprint | `9f5e2d49d42795bb4b38f62b909cc690dcb726f1217efcdc4cd50029a0d4184a` |
| Product configuration | Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1, Identity reset image; AXI-Lite; Generic FIFO |
| Compile input checks | 97/97 current source hashes match the compile manifest; 0 missing, 0 mismatches |
| VDB coverage input | 1 Design VDB + 232 Test VDBs; 3,040 VDB files checked, 0 missing or hash mismatches |
| Tools | Rocky Linux 8.10 / WSL2 kernel 6.6.87.2; VCS V-2023.12-SP1_Full64; URG V-2023.12-SP1; VC Formal V-2023.12-SP2; Python 3.12.13 |

The seven pre-existing Round 12 CSV modifications in the checkout are line-ending-only (`git diff --ignore-space-at-eol` is empty). They were preserved and not staged. The working branch is not `thermo5`; no PR merge, push, or branch cleanup was requested or performed.

The original Round 13 environment note said VCS/URG could not run under WSL2. That conclusion is superseded: actual VCS compile/simulation, URG report generation, and VC Formal jobs ran successfully. Standalone version/help probes are not used as evidence. A minimal VC Formal smoke proved an assertion non-vacuously and reached its cover at depth 2.

## 2. Same-Manifest Raw and Official Adjusted Coverage

Both URG reports use the exact same validated Design VDB and 232 Test VDBs, product compile fingerprint, and URG configuration. The official waiver file contains no active directives; the report manifest records 0 approved waivers and 0 applied exclusions. Thus official Adjusted equals Raw.

| Metric | Raw | Official Adjusted | Uncovered / remaining |
|---|---:|---:|---:|
| Branch | 524 / 637 (82.2606%) | 524 / 637 (82.2606%) | 113 |
| Condition | 657 / 849 (77.3852%) | 657 / 849 (77.3852%) | 192 |
| Line | 3,338 / 3,796 (87.9347%) | 3,338 / 3,796 (87.9347%) | 458 |
| Toggle | 91,288 / 104,480 (87.3737%) | 91,288 / 104,480 (87.3737%) | 13,192 |
| FSM states | 13 / 13 (100%) | 13 / 13 (100%) | 0 |
| FSM transitions | 22 / 22 (100%) | 22 / 22 (100%) | 0 |

There are **13,955 Raw uncovered code bins**. The exact ledger is [`thermo5-tx-coverage-open-bins.csv.gz`](data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz), 13,955 rows; its SHA-256 is recorded in the machine evidence manifest. It is valid for this rerun because the current source hashes and same-manifest VDB hashes were rechecked.

The Round 12 analysis-only What-if applied 361 unapproved candidate bins and left 13,594 uncovered (12 Branch, 84 Condition, 306 Line, 13,192 Toggle). That What-if is **not official Adjusted Coverage**, is not a waiver approval, and does not change the official figures above.

## 3. Waiver Review and Current-Source Reproof

The formal waiver list has 371 entries; the local review has 369. The two remote-only entries are already Raw hits and are archived as resolved by Raw coverage. Current candidate disposition is:

| Disposition | Count | Status |
|---|---:|---|
| Analysis-eligible candidates | 361 | Evidence package retained; all pending independent review |
| Candidates needing current Formal reproof | 4 | Current-source proof completed; exact URG mapping and reviewer decision still pending |
| Interpolator candidates | 4 | Unresolved; no exclusion proposed |
| Approved / rejected / active Exclusion | 0 / 0 / 0 | No approvals or exclusions have been invented |

The four fresh Formal reproofs bind to the current product source and are recorded row-by-row in [`thermo5_tx_r13_final_waiver_reproof_review.csv`](data/thermo5-r13/thermo5_tx_r13_final_waiver_reproof_review.csv). Their properties and positive activity covers support the stated reachability results, but a Formal result alone does not authorize a Waiver:

| Waiver | Exact target | Current-source property result | Review state |
|---|---|---|---|
| `W-9010fccd0889b46ea284` | AXI-Lite write-case default, `thermo5_dpd_axi_lite_cfg.sv:246` | `a_write_case_default_unreachable` proven non-vacuously; legal coefficient read cover reached; target default-arm cover is uncoverable | Pending exact URG mapping and independent review |
| `W-98a39b6429bbed7c29ad` | CDC outer residual-case default, `dsm_axis14_to_core8_cdc.sv:141` | `a_exact_default_path_unreachable` proven; product-advance cover at depth 2 and completed-frame cover at depth 65; exact target cover uncoverable | Pending exact URG mapping and independent review |
| `W-32b5745433f0ff75d5c2` | CDC immediate frame-end arm, `dsm_axis14_to_core8_cdc.sv:146` | `a_immediate_end_arm_unreachable` proven non-vacuously; product context and completed-frame covers reached; exact target cover uncoverable | Pending exact URG mapping and independent review |
| `W-a9fc97093bdddfb7f5aa` | CDC `end_remaining` false arm, `dsm_axis14_to_core8_cdc.sv:215` | `a_end_remaining_false_arm_unreachable` proven; legal end-arm and completed-frame covers reached; exact target cover uncoverable | Pending exact URG mapping and independent review |

These four are **proof candidates, not approved exclusions**. The 361 eligible entries also remain pending. The 8,192 DPD Pair-1 and 120 Active-Tap toggle entries have exact per-bit inventories and a plausible fixed-configuration structural argument, but they do not yet have the required independent proof review or approval. No official `.el` was generated from them.

The remaining Toggle root causes are not declared unreachable: 640 DPD sample-counter high-bit bins require an operating-duration/overflow contract; 3,262 data-value bins need directed stimulus and exact URG hit analysis; 130 CDC residual bits need product-path stimulus/reachability analysis; and the 848 DPD identity/arithmetic-related bins remain open. “Candidate” is not synonymous with `PROVEN_UNREACHABLE`.

## 4. Linux Regression and Checker Evidence

Fresh current-round runs completed on the checkout. All runs below keep the frozen product configuration; candidate DPD configurations were not substituted as the product default.

| Suite | Result | Evidence |
|---|---|---|
| Centered-Cubic / EF2 Generic FIFO directed regression | PASS; includes reset, bubbles/backpressure, FIFO boundary/empty, bit-true, expected-illegal-frame, STOP/restart | `runs/thermo5_r13_gate6_centered_ef2/` |
| AXI-Lite product regression | PASS; register access, config, coefficient transport, nonlinear legal 1-tap DPD, graceful STOP, boundary phase, two isolated expected-negative tests | `runs/thermo5_r13_gate6_axil_product/` |
| System random | 110 / 110 PASS, including 10 long-stream cases | `runs/thermo5_r13_native_system_random/summary.json` |
| Legal one-tap DPD / gain / input-profile matrix | 60 / 60 PASS | `runs/thermo5_r13_native_dpd_matrix/summary.json` |
| COMMIT boundary with PA stall | 2 / 2 PASS | `runs/thermo5_r13_native_scenario/commit_boundary_stall/summary.json` |
| Reset while COMMIT is pending | 8 / 8 PASS | `runs/thermo5_r13_native_scenario/reset_pending_commit/summary.json` |
| Direct SystemVerilog unified-scoreboard mutation | 6 / 6 injected faults detected: lost, duplicate, reordered, wrong Frame ID, premature apply, EF2 corruption | `runs/thermo5_r13_native_scoreboard_mutation/unified_scoreboard_mutation.log` |
| Python reference model | 64 / 64 PASS | `runs/thermo5_r13_python_refmodel_tests.log` |
| Python hardware/coverage utilities | 45 / 45 PASS | `runs/thermo5_r13_python_hw_tests.log` |

The current-round test VDBs from separate fresh builds are not merged into the official 233-VDB URG run. The official report deliberately uses the homogeneous, hash-verified compile/VDB set. Of the 232 product Test VDBs in that set, the full suite is same-source carry-forward evidence; Round 13 freshly reran the targeted suites listed above, not all 232 individually.

### Reproduction commands

The exact VDB paths, tree hashes, and complete raw/adjusted URG argument vectors are recorded in the ignored local `runs/thermo5_r13_final_signoff_raw_adjusted/{vdb_manifest.json,report_manifest.json}`. Their report/log hashes are in the checked-in evidence manifest.

```bash
python3.12 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
  --output-dir runs/thermo5_r13_gate6_centered_ef2/vectors --words 56 --seed 610216 \
  --interp-mode centered_cubic --tidsm-order 2 --step 5120 \
  --frame-start-words 1,15,36 --frame-gains 16384,14336,12288

make -C dv/uvm/sim thermo5-centered-cubic-ef2-vcs-regression PYTHON=python3.12 \
  THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 \
  THERMO5_STEP=5120 \
  THERMO5_VECTORS="$PWD/runs/thermo5_r13_gate6_centered_ef2/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_r13_gate6_centered_ef2"

make -C dv/uvm/sim thermo5-axil-product-vcs-regression PYTHON=python3.12 \
  THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_VECTORS="$PWD/runs/thermo5_r13_gate6_centered_ef2/vectors" \
  THERMO5_OUT="$PWD/runs/thermo5_r13_gate6_axil_product"

(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)
```

Two initial regression invocations were corrected before signoff evidence collection: one referenced an empty vector directory, and another forced AXI-Lite defines on the Generic-FIFO target. The corrected targets above passed; neither setup error is counted as a design regression failure.

## 5. Assertion and Formal Status

Legal and expected-negative assertions are reported separately:

| Assertion run | Success | Expected failure | Uncovered / without attempts |
|---|---:|---:|---:|
| Legal-only product tests | 13 | 0 | Two product `q1_tail` assertions |
| Expected-negative tests | Separate negative report | 3 expected, checker-confirmed (CDC underflow and two interpolator assertions) | Negative-only bins do not affect legal pass status |

The two remaining legal product properties are the elaborated `unnamed$$_1` assertions at `u_interp_1` and `u_interp_2`, both originating at `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` (`q1_tail`). They have zero legal attempts in the legal-only URG split. Two UVM library assertions also have no attempts; they are outside the DUT and are not counted as product obligations.

| Formal obligation | Result |
|---|---|
| Four exact waiver candidate properties above | Proven in current-source focused harnesses; independent mapping/review pending |
| Outstanding counter saturation / underflow guards | INCONCLUSIVE: five assertions and two target Covers unresolved; positive source/core/output activity Covers were reached |
| Full-chain DPD Identity payload and saturation arithmetic | INCONCLUSIVE: four properties unresolved; valid-latency property proven; activity Covers reached |
| `q1_tail` at both product interpolation stages | OPEN: legal URG has no attempts; scoped block evidence does not close the full product path |
| Native VC Formal smoke | PASS: one assertion proven non-vacuously and one Cover reached |

No `INCONCLUSIVE` is counted as `PROVEN`. The current formal proofs are block-focused; they do not establish full-chip XPM/GT or physical behavior.

## 6. Remaining Work and Final Decision

1. Obtain independent review and recorded approval for any exact waiver; then regenerate a strict `.el` and same-input Raw/Adjusted URG. Until then the official exclusion count remains zero.
2. Close or formally resolve the two legal `q1_tail` assertions; keep expected-negative assertion failures isolated.
3. Prove or test the outstanding-counter saturation/underflow contract and full-chain DPD Identity property. Inconclusive proofs remain open.
4. Close reachable Branch, Condition, Line, and Toggle bins with legal DUT stimulus and independent checking. Do not waive counter high bits without a defined run-time bound.
5. Re-run the complete clean product test set on one fixed product compile if a fresh all-tests-at-once run is required for release.

**Linux Functional DV:** PARTIAL PASS; current targeted regressions, carried-forward 436/436 applicable Functional bins, seven system-cross evidence, Python reference checks, and 6/6 direct SV scoreboard mutations are available. Full signoff remains OPEN because legal assertion and Formal obligations are not closed.

**Linux Code Coverage:** OPEN (`RAW_100_OPEN`). Official Adjusted equals Raw; no waiver was approved. Strict 100% Adjusted Coverage has not been achieved.

**FPGA / Physical:** NOT RUN here. Real XPM, GT Wizard, Vivado timing/PPA, board RF, and physical QAM256 tests remain separate signoff work.

## 7. Evidence Index

- Machine-readable manifest, including all 232 Test VDB paths/tree hashes: [`thermo5_tx_r13_final_coverage_manifest.json`](data/thermo5-r13/thermo5_tx_r13_final_coverage_manifest.json)
  - SHA-256: `a52ee69c7c27b74242266496a78ddea30c4b1bdeead2942b0c7e45dcf4cb106f`
- Exact Raw uncovered bins (13,955): [`thermo5-tx-coverage-open-bins.csv.gz`](data/thermo5-r12/thermo5-tx-coverage-open-bins.csv.gz)
- Waiver review with four current-source proof rebindings: [`thermo5_tx_r13_final_waiver_reproof_review.csv`](data/thermo5-r13/thermo5_tx_r13_final_waiver_reproof_review.csv)
- Full 13,594 What-if-open root-cause ledger: [`thermo5_tx_r13_exact_bin_disposition.csv.gz`](data/thermo5-r13/thermo5_tx_r13_exact_bin_disposition.csv.gz)
- Exact DPD Pair-1 candidate Toggle bins: [`thermo5_tx_r13_pair1_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_pair1_exact_bins.csv.gz)
- Exact Active-Tap candidate Toggle bins: [`thermo5_tx_r13_active_taps_exact_bins.csv.gz`](data/thermo5-r13/thermo5_tx_r13_active_taps_exact_bins.csv.gz)
- Raw/Adjusted URG logs and full reports: ignored local directory `runs/thermo5_r13_final_signoff_raw_adjusted/`
