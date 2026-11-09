# Thermo5 TX Final Code Coverage Round 19 — 2026-11-09

## Decision

Round 19 closes **64 exact counter-toggle bins** and preserves the validated Round 18 554-Test set. The 263 non-counter bins remain OPEN: these runs produced zero exact hits in their target Branch, Condition, Line, and Other Toggle inventory. The remaining 930 counter bins are reachable under the 32-bit modulo counter contract, but the upper bits require impractically long product-level runs. No waiver is independently approved and no official exclusion is active. Code Coverage and Linux DV signoff remain OPEN.

This report separates the official zero-waiver Adjusted result from a strict, analysis-only What-if run. The latter is not signoff evidence and must not be presented as approved coverage.

## Frozen Product and Evidence Binding

- Product source SHA: `fe315cabf058dd184b6d94ffa4ed3b5fb9916733`; review branch base SHA: `93077e9c87b48f8af5ed142b2653e62775b6131e`.
- Product RTL aggregate SHA-256: `fc046317c99fe2a89b60f3ddeff1c7a0e178cd1c219349b942b7565fa7cec003`.
- Compile fingerprint SHA-256: `e723c226349f61a5f150e193f578995af02452dcfdea473ac2b79ecfe0eccca7`; VCS/URG: `V-2023.12-SP1_Full64` / `V-2023.12-SP1 Full64`.
- Configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, 20-bit state; DPD_MAX_TAPS=1; AXI-Lite; Generic FIFO.
- VDB set: 1 Design + 575 Test VDBs. All 554 Round 18 Test VDB fingerprints are present; 21 fingerprinted Round 19 Test VDBs were added.
- Canonical Round 18 554-Test manifest SHA-256: `0e4e726d5160adde81fd6d409a7284d82ca2306d04e87aae6431b225915bc130`.
- Round 19 VDB set fingerprint SHA-256: `a1bb74a686ee3516a93a8965d126290a0179cfa6621f66bef7fc9ea525683450`.
- Coverage Design VDB tree SHA-256: `662b4f873f12f664fb2ddf22b0d69415952c96d2734814d7a6016ab6f65f50db`; the 21 new Test VDBs bind to compile-parent tree SHA-256 `33cbac8aa113aaad104f68cf42a19528113faa6e818244c4da6a32aecf1c9b37`. These parent trees differ, so the evidence records the inherited VDB provenance variance explicitly.
- Raw URG log SHA-256: `18781f5af44a58a8f438137272c981283bbacb170a77f0df6c1ce1c49c9ae1e5`; What-if URG log SHA-256: `98b61570695dd0091a58876ade5c6645ecb1d62a371c0f3d812a1e5dd80cc808`.
- Both URG reports used the same Design VDB and same ordered Test VDB list. What-if used `-elfilelist` plus `-excl_strict`; both runs exited 0 with no warning/error/reject/checksum/mapping diagnostics.
- A diagnostic-only strict URG pair used the new-test compile-parent VDB as Design with the same 575 ordered tests and exclusion list. Its Raw and What-if metric vectors exactly matched the primary run; test inventory hashes also matched. Diagnostic logs: `runs/thermo5_r19_non_counter_20261109/urg_576_design_r18_parent_diag/raw/urg.log` and `runs/thermo5_r19_non_counter_20261109/urg_576_design_r18_parent_diag/whatif_11418/urg.log`. This confirms metric stability across the two Design VDBs, while the primary result remains bound to the frozen Round 18 Design VDB.

## Raw, Official Adjusted, and Analysis-only What-if

Official Adjusted remains identical to Raw because approved waivers and active exclusions are both zero.
The What-if counts come from a separate strict URG run using the same VDB inputs and the 11,418-candidate Round 18 analysis-only list.

| Metric | Raw | Official Adjusted | Analysis-only What-if | What-if excluded | What-if remaining |
|---|---:|---:|---:|---:|---:|
| Branch | 524/637 (82.26%) | 524/637 (82.26%) | 524/530 (98.87%) | 107 | 6 |
| Condition | 657/849 (77.39%) | 657/849 (77.39%) | 657/741 (88.66%) | 108 | 84 |
| Line | 3338/3796 (87.93%) | 3338/3796 (87.93%) | 3338/3363 (99.26%) | 433 | 25 |
| Toggle | 92632/104480 (88.66%) | 92632/104480 (88.66%) | 92632/93710 (98.85%) | 10770 | 1078 |
| FSM states / transitions | 13/13 / 22/22 | unchanged | unchanged | 0 | 0 |

The Analysis-only list removes 107 Branch, 108 Condition, 433 Line, and 10,770 Toggle bins from the respective URG denominators (11,418 total). The raw covered numerators did not change. These are analysis exclusions only; approved exclusions remain zero.

## Exact Coverage Delta

The long legal one-tap DPD saturation stream (seed 190031, 131,096 PA words) added 64 Raw Toggle hits. The exact rows, Native URG names, lane/bit/direction, Semantic Bin IDs, and source bindings are in `docs/verification/data/thermo5-r19/r19_exact_raw_toggle_delta.csv.gz`.

| Counter | Exact new hits | Breakdown |
|---|---:|---|
| sample_count | 32 | bit 16 1→0 on 16 lanes; bit 17 0→1 on 16 lanes |
| saturation_count | 32 | lanes 0–14: bit 16 1→0 and bit 17 0→1; lane 15: bit 15 1→0 and bit 16 0→1 |
| Other Toggle | 0 | no exact hit |

Branch, Condition, Line, and Other Toggle exact hit deltas are zero. The legal randomized packet test, legal frame replacement test, frame-tail/backpressure test, and 16 deterministic phase variants all passed their UVM checks but added no exact DUT Code Coverage bins. The 16 phase variants each left the targeted centered pop/push event at stage 1=0 and stage 2=0; this remains OPEN rather than being inferred unreachable.

## Non-Counter Residuals

The requested 263-bin set remains 263/263 OPEN: 6 Branch, 84 Condition, 25 Line, and 148 Other Toggle. The exact ledger is `docs/verification/data/thermo5-r19/r19_non_counter_remaining_263.csv.gz`.

| Root-cause group (Round 18 ledger) | Exact bins | Round 19 disposition |
|---|---:|---|
| `DATA_VALUE_OR_TOGGLE_STIMULUS` | 148 | OPEN; no new exact hit |
| `DEFENSIVE_NEGATIVE` | 2 | OPEN; no new exact hit |
| `UNKNOWN` | 113 | OPEN; no new exact hit |

The 80 Reset/State-Hold Conditions and 4 Interpolator Empty/Blocked Conditions remain without a closure witness. The focused Interpolator Empty/Blocked probe timed out before drain; its VDB is excluded from the merged coverage set. It is not a DUT pass or a reachability proof. A separate invalid frame-metadata diagnostic (seed 190041) also failed its expected checks and is excluded. No new assertions or Formal harnesses were run.

## Counter Coverage Cost and Scope

Both `sample_count` and `saturation_count` are 32-bit modulo counters in `rtl/dpd/dpd_memory_poly.v`, reset to zero. `sample_count` increments on each accepted `pipe_ce && in_valid`; `saturation_count` increments on each valid output when either I or Q saturates. The DPD vector wrapper leaves both outputs unconnected (`rtl/dpd/dpd_vector16_memory_poly.sv`), and no external product status/readback use or normative counter requirement was found. They are diagnostic/internal outputs, but remain in the current DUT URG Code Coverage scope. No scope exclusion is applied; changing that scope requires an independently reviewed policy and does not change the reported URG denominator in this round.

From reset, bit *k* first toggles 0→1 at count `2^k` and 1→0 at `2^(k+1)`. The long-run schedule observed 57 sample-count increments per 56-word legal frame, 32 AXIS beats per frame, and measured 2,051.4 output words/s CPU throughput. Sample-count lengths below use that measured legal schedule. Saturation lengths show the one-event-per-output theoretical lower bound and a separate projection using the observed per-lane saturation rate; both projections are estimates, not guarantees or proof of reachability under every waveform.

| Remaining target | First remaining transition | Minimum / projected stream | CPU-time estimate |
|---|---|---:|---:|
| sample_count | bit 17 1_to_0 (all 16 lanes) | 4,600 frames / 257,600 words / 147,200 AXIS beats | 0.03 hours |
| sample_count | bit 31 1_to_0 (all 16 lanes) | 75,350,304 frames / 4,219,617,024 words / 2,411,209,728 AXIS beats | 23.81 days |
| saturation_count | bit 17 1_to_0 (all 16 lanes) | 6,242 frames / 349,552 words / 199,744 AXIS beats | 0.05 hours |
| saturation_count | bit 31 1_to_0 (worst observed lane 15) | 102,262,167 frames / 5,726,681,352 words / 3,272,389,344 AXIS beats | 32.31 days |

Per-Exact-Bin event thresholds, lane, legal-frame length, lower bound, measured-rate projection, and CPU-time estimate are in `docs/verification/data/thermo5-r19/r19_counter_minimum_lengths.csv.gz`. At the top end, reaching the 32-bit falling edge requires about 4.22 billion output words for sample_count and 4.29 billion saturating output events in the ideal counter model; the measured lane-15 saturation rate projects roughly 32 days of CPU time. These counters remain reachable; no high-bit bin is classified unreachable.

## Waiver and Formal / Assertion Status

The official inventory remains 371 unique IDs: Round 18 reconciliation identifies 2 `RESOLVED_BY_RAW_HIT` and 369 pending review (367 matched to the prior candidate set, 2 outside it). The CSV's raw `review_status` field is still PENDING for all 371 rows; reviewer approvals are 0 and active official exclusions are 0. Round 18's 11,418 candidates remain analysis-only and require real independent reviewer approval. The seven root-cause review packages are retained; this round created no approval record and no official `.el`.
The carried URG DUT assertion summary is 13 SUCCESS, 3 FAILURE, 2 UNCOVERED. This summary is inherited from the same merged VDB set; it is not a fresh assertion regression. Formal was NOT RUN in Round 19. The historical DPD Identity, Outstanding Counter, COMMIT lifecycle, and product-level `q1_tail` proof obligations remain OPEN / INCONCLUSIVE as documented in Round 18.

## Regression Matrix and Excluded Experiments

| Test group | Result | Coverage use |
|---|---|---|
| Legal random packet seeds 190024/190025 | PASS; 0 UVM errors/fatals; independent event/transaction checks and drain pass | included; 0 exact code delta |
| Long legal DPD saturation stream seed 190031 | PASS; 131,096 PA words; four-plane bit-true check and Python lane counters match | included; +64 exact Raw Toggle |
| Legal frame replacement seed 190042 | PASS; 112 PA words; ordered four-plane checks; target pop/push stage1/2 still 0 | included; 0 exact code delta |
| Frame replacement phase 1–16 | 16/16 PASS; target pop/push remains 0 at both stages | included; 0 exact code delta |
| Frame-tail PA backpressure seed 190019 | PASS; queue drains; no mismatch | included; 0 exact code delta |
| Interpolator Empty/Blocked probe | FAIL / timeout before drain | excluded from formal VDB set |
| Frame replacement seed 190041 | FAIL under malformed frame-start metadata | excluded; invalid stimulus, not a product conclusion |
| Random packet seed 190023 | FAIL before stimulus due missing EF2 reference vector | excluded |

Full Product Regression and Formal were not rerun. Test command lines, run-log hashes, VDB tree fingerprints, and exact URG command arguments are indexed in `docs/verification/data/thermo5-r19/thermo5_tx_r19_final_evidence_manifest.json.gz`.

## Final Status

- Functional targeted tests: PASS for the included directed/random scenarios; the Interpolator Empty/Blocked probe remains an open failed attempt.
- Raw Code Coverage: 524/637 Branch, 657/849 Condition, 3338/3796 Line, 92632/104480 Toggle; FSM states and transitions 100%.
- Official Adjusted Code Coverage: equal to Raw; 0 approved exclusions.
- Strict Analysis-only What-if: Branch 524/530, Condition 657/741, Line 3338/3363, Toggle 92632/93710; 1,193 exact bins remain. Not official signoff.
- Waiver review: 369 pending; 0 approved. Counter bins remain in scope.
- Formal / Assertion: OPEN; VCS/URG assertion carry-forward has three DUT failures and two uncovered DUT properties; Formal not rerun.
- Linux DV Coverage Signoff: **OPEN**. Full Linux DV Signoff: **OPEN**. XPM, GT Wizard, Vivado PPA/timing, FPGA, RF and physical QAM256: **NOT RUN**.
