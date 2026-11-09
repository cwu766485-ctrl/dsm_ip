# Thermo5 TX Final Code Coverage Closure — Round 18

**Status: Coverage signoff OPEN.** This round produced a real directed Raw coverage delta and a strict Analysis-only What-if URG result. It did not receive independent Waiver approval, so the Official Adjusted result remains equal to Raw. It is not a Linux DV final signoff.

## Baseline and product

- Review base: Round 17 PR #47 source `f9275273ef2137c5c181cb5395cdd9f706dd4b90`.
- Product source represented by the coverage compile: `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`.
- Execution environment: Rocky 8.10 under WSL2, 64-bit licensed VCS/URG.
- Product RTL aggregate SHA-256: `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.
- Compile fingerprint: `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`.
- Configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1; AXI-Lite; Generic FIFO.
- Tools: VCS V-2023.12-SP1 Full64, URG V-2023.12-SP1 Full64, Python 3.12.13.
- The frozen 553-Test input is one Design VDB plus 553 Test VDBs. The Round 18 set adds exactly one directed Test VDB (seed 180018), making one Design plus 554 Test VDBs. Each URG pair used an identical VDB input manifest. Content fingerprints, URG log hashes, and report/inventory tree hashes are in [`thermo5_tx_r18_portable_evidence_manifest.json`](data/thermo5-r18/thermo5_tx_r18_portable_evidence_manifest.json).

No product RTL, product parameter, or DSM algorithm changed.

## Raw and Official Adjusted Coverage

Official Waivers approved: **0**. Official Exclusions active: **0**. Therefore Official Adjusted equals Raw.

| Input set | Metric | Raw | Official Adjusted | Raw uncovered |
|---|---|---:|---:|---:|
| 553 Test VDBs | Branch | 524/637 (82.26%) | 524/637 (82.26%) | 113 |
| 553 Test VDBs | Condition | 657/849 (77.39%) | 657/849 (77.39%) | 192 |
| 553 Test VDBs | Line | 3338/3796 (87.93%) | 3338/3796 (87.93%) | 458 |
| 553 Test VDBs | Toggle | 92138/104480 (88.18%) | 92138/104480 (88.18%) | 12342 |
| 554 Test VDBs | Branch | 524/637 (82.26%) | 524/637 (82.26%) | 113 |
| 554 Test VDBs | Condition | 657/849 (77.39%) | 657/849 (77.39%) | 192 |
| 554 Test VDBs | Line | 3338/3796 (87.93%) | 3338/3796 (87.93%) | 458 |
| 554 Test VDBs | Toggle | 92568/104480 (88.60%) | 92568/104480 (88.60%) | 11912 |

FSM coverage is unchanged at 13/13 states and 22/22 transitions. URG assertion summary across the merged test sets is 13 SUCCESS, 3 FAILURE, 2 UNCOVERED; this round did not rerun or close the outstanding Assertion/Formal obligations.

## Analysis-only What-if URG

The 11,418 exact candidates were applied using `-excl_strict` to the same Raw VDB inputs. The original 11,405-candidate set left 1,270 bins after the directed test. The exact repair of the 9 Branch and 4 Line native mappings then left **1,257**. Covered numerators did not change; FSM and Assertion results did not change. The new strict run emitted no warning, checksum mismatch, ambiguous mapping, or scope diagnostic.

| Metric | Raw / Official Adjusted | Analysis-only excluded | What-if Adjusted | What-if remaining |
|---|---:|---:|---:|---:|
| Branch | 524/637 (82.26%) | 107 | 524/530 (98.87%) | 6 |
| Condition | 657/849 (77.39%) | 108 | 657/741 (88.66%) | 84 |
| Line | 3338/3796 (87.93%) | 433 | 3338/3363 (99.26%) | 25 |
| Toggle | 92568/104480 (88.60%) | 10770 | 92568/93710 (98.78%) | 1142 |
| **Total** |  | **11418** |  | **1257** |

This is strictly **Analysis-only What-if**, not Official Adjusted coverage. All 11,418 rows remain `PENDING_INDEPENDENT_REVIEW`; reviewer and approval fields are empty. No official `.el` was generated or applied.

### Candidate review packages and old Waiver reconciliation

The review packet has 11,418 exact candidates, partitioned without overlap:

| Root-cause packet | Candidates |
|---|---:|
| DPD Pair-1 fixed tap configuration | 8,192 |
| EF2 fixed parameters | 436 |
| DPD one-tap history/fallback | 176 |
| CDC residual | 137 |
| Other product parameter guards | 29 |
| EF2 pair/q-one fixed-parameter candidates | 2,328 |
| DPD Active-Tap fixed-configuration candidates | 120 |
| **Total** | **11,418** |

Every candidate row includes its semantic Exact Bin ID, instance, metric/bin expression and direction, source file/hash, product parameter string, static rationale/trace reference when present, native URG mapping/directive, What-if disposition, and an explicit pending-review state. Rows without a complete static trace remain marked unknown in their source evidence; the What-if application alone does not prove semantic unreachability.

The official 371-ID Waiver inventory is preserved verbatim in the review data: 367 pending rows map to the prior 8,970-candidate population, 2 pending rows are not in that population, and 2 Raw-hit rows remain `RESOLVED_BY_RAW_HIT`. Approved=0 and active Official Exclusions=0. The separate 13-row mapping repair adds 9 exact Branch vectors and 4 exact parameter-guard Line blocks; it does not widen any module or source-line exclusion.

Index: [`review_packages/`](data/thermo5-r18/review_packages/). Exact 13-row mapping evidence and Analysis-only directives: [`analysis_only_mapping_repair_13.csv.gz`](data/thermo5-r18/analysis_only_mapping_repair_13.csv.gz), [`analysis_only_mapping_repair_13.el`](data/thermo5-r18/analysis_only_mapping_repair_13.el).

## Directed DPD saturation and counter results

The new test legally programmed a non-Identity one-tap Q2.14 coefficient (`c1_re=0x7fff`) through AXI-Lite and committed it before streaming. Python generated 1,172 legal 56-word frames (65,632 core words) with range-stress I/Q. An independent bit-true oracle predicted per-lane sample and saturation counts; the test compared all 16 lanes and all four PA planes.

- VCS/UVM result: PASS; 65,632 output words checked; all 16 DPD lanes recorded saturation; predictor mismatches=0; early and final underflow=0; expected queues drained; UVM warnings/errors/fatals=0. After the drain poll, a separate settled STATUS read checked Active/Draining through the independent predictor (`status_stable=1`, two earlier synchronization-window reads masked).
- Actual per-lane `sample_count`: 66,804 for each lane.
- Actual `saturation_count` (lanes 0–15): `65632,65632,65632,65631,65631,65631,65631,65631,65631,65631,65631,65632,65632,65632,65632,49223`; every count matched the independent Python prediction.
- Raw 553→554 Exact Toggle delta: **430** new bins, all inside the previous What-if residual: 80 `sample_count`, 350 `saturation_count`, 0 other.
- `sample_count[14:31]`: 80/576 Exact Toggle directions hit; 496 remain open.
- `saturation_count`: 350/848 hit; 498 remain open.
- Other data toggles: 0/148 hit; all 148 remain open.
- The two 32-bit diagnostic counters remain in coverage scope. They wrap by ordinary unsigned 32-bit modulo increment; no system-lifetime bound or overflow contract justifying exclusion was established. No scope waiver is proposed.
- The observed run processed about 65.6k counter increments in 22.7 seconds of simulator CPU. At that measured rate, reaching 131,072 increments (the next power-of-two boundary) is about 45 seconds; reaching the bit-31 boundary at 2^31 increments is roughly 8.6 days for a counter that updates every sample. This is a throughput estimate, not a reachability proof; saturation-count cost is higher if not every sample clips. No approved block-level substitute or product lifetime policy exists yet, so those bins remain open.

Exact ledgers: [`counter_high_bit_exact_results_1424.csv.gz`](data/thermo5-r18/review_packages/counter_high_bit_exact_results_1424.csv.gz), [`other_toggle_remaining_148.csv.gz`](data/thermo5-r18/review_packages/other_toggle_remaining_148.csv.gz), and [`exact_raw_toggle_delta_553_to_554.csv.gz`](data/thermo5-r18/exact_raw_toggle_delta_553_to_554.csv.gz).

## Remaining exact bins

After the 11,418 Analysis-only candidates and the actual 430 new Raw hits, 1,257 Exact bins remain in the Analysis-only What-if ledger:

- Branch: 6
- Condition: 84
- Line: 25
- Toggle: 1,142 (496 sample counter, 498 saturation counter, 148 other data toggles)

The 115 residual non-toggle bins are 80 `RESET_RELEASE_OR_STATE_HOLD`, 27 `LEGAL_STIMULUS_OR_CHECKER_REVIEW`, 4 `INTERPOLATOR_EMPTY_OR_BLOCKED`, 2 `PRODUCT_CADENCE_ALIGNMENT`, 1 `GUARDED_ADDRESS_DECODE`, and 1 `CDC_OR_RESIDUAL_STATE`. Their current review labels are 113 UNKNOWN and 2 DEFENSIVE_NEGATIVE; no new Branch/Condition/Line Exact bin was hit by the saturation campaign. The full Exact IDs, source/instance, root cause, review class, and Round 18 disposition are in [`exact_remaining_control_bins_115.csv.gz`](data/thermo5-r18/review_packages/exact_remaining_control_bins_115.csv.gz) and the complete [`whatif_residual_11418_after_554.csv.gz`](data/thermo5-r18/whatif_residual_11418_after_554.csv.gz).

No `TRUE_DEAD_CODE` was established and no RTL was removed. The 1,257 What-if residual bins remain open for targeted legal stimulus, reachability evidence, or independent review; the 12,675 Raw/Official Adjusted uncovered bins remain the official coverage gap.

## Checks and reproduction

Directed campaign generation:

```bash
python3.12 dv/uvm/refmodel/python/generate_thermo5_dpd_counter_campaign.py \
  --output-dir runs/thermo5_r18_counter_20261109_05/vectors \
  --core-words 65632 --seed 180018
```

The VCS compile/run used the AXI-Lite product configuration, Generic FIFO and the same generated vectors. The run was followed by an actual Raw/zero-Waiver Adjusted/Analysis-only URG sweep over both frozen 553-Test and extended 554-Test sets. Each run's Full64 command, URG log hash, report/inventory tree hashes, VDB content fingerprint, and summary are recorded in the portable manifest. The ignored local `runs/` tree retains full logs and VDBs; generated logs/VDBs are not committed.

The targeted VCS build and run commands were:

```bash
build="$PWD/runs/thermo5_r18_counter_20261109_05/build"
vectors="$PWD/runs/thermo5_r18_counter_20261109_05/vectors"
make -C dv/uvm/sim thermo5-vcs PYTHON=python3.12 VCS=/usr/local/bin/vcs \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_FIFO_IMPL=generic \
  THERMO5_COVERAGE=1 \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_product_dut_coverage.hier" \
  THERMO5_VECTORS="$vectors" THERMO5_OUT="$build"
make -C dv/uvm/sim thermo5-vcs-run-only PYTHON=python3.12 \
  THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 THERMO5_CENTERED_CUBIC=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 THERMO5_FIFO_IMPL=generic \
  THERMO5_COVERAGE=1 \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_product_dut_coverage.hier" \
  THERMO5_VECTORS="$vectors" THERMO5_OUT="$build" \
  THERMO5_TESTNAME=thermo5_sku_axil_dpd_saturation_bittrue_test \
  UVM_SEED=180018 THERMO5_EXTRA_ARGS='+CORE_WORDS=65632 +PACKET_BEATS=32'
```

The URG sweep was run by `tools/hw/thermo5_tx_r18_final_coverage.py` with the resulting Test VDB, test log, generated campaign manifest, and `--out-dir runs/thermo5_r18_counter_20261109_06/urg`; it reused the frozen Round 17 base/prior VDB manifests and exact candidate inputs. The sweep executed Raw, zero-Waiver Official Adjusted, 11,405-candidate What-if, and 11,418-candidate What-if for both the 553-Test and 554-Test sets. All eight invocations completed with zero URG diagnostics.

Additional checks:

- Python reference suite: 66/66 PASS using `(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)`.
- Hardware/coverage tool suite: 47/47 PASS using `python3.12 -m unittest discover -s tools/hw/tests -v`.
- Python compile checks for both Round 18 coverage tools, the counter-campaign generator, and the modified reference model: PASS.
- `git diff --check`: PASS.
- Full product regression: NOT RUN in Round 18.
- Formal rerun: NOT RUN in Round 18.

## Decision

**Coverage signoff: OPEN. Linux DV final signoff: OPEN.** The 11,418 candidates are not formally approved. Official Adjusted remains Raw at Branch 524/637, Condition 657/849, Line 3338/3796, Toggle 92568/104480. Analysis-only What-if is Branch 524/530, Condition 657/741, Line 3338/3363, Toggle 92568/93710, with 1,257 Exact bins remaining. The outstanding 3 Assertion failures, 2 uncovered Assertions, required Formal properties, and full product regression still require closure/review. This report is not XPM, GT Wizard, FPGA PPA, board, RF, or physical QAM256 signoff.

The PR is an evidence/review step. No reviewer identity or approval reference has been fabricated.
