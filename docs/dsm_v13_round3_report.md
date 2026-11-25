# DSM V1.3 Round 3 — Coverage-Driven Final Closure

Date: 2026-11-25 (SGT)
Branch: `work/dsm-v13-mash-uvm-round3`
Baseline: Round 2 HEAD `83bbb608fafa6406a1406c19669dd050c7a0e03d`
Run root: `runs/dsm_v13_round3/`
Tools: Synopsys VCS/URG V-2023.12-SP1, VC Formal V-2023.12-SP2, Python 3.12

## Disposition

The Round 3 verification-platform additions and focused regressions passed.
All seven configuration-local URG merges passed, the independent Python
reference suite passed 74/74, and the MASH reachability proof passed. Fresh
raw DUT code metrics are equal to adjusted metrics: no exclusion or waiver was
applied. Every code metric is unchanged or improved against the Round 2 raw
baseline.

**Coverage closure and final DV sign-off remain OPEN.** The frozen Round 2
coverage-hole matrix contained 2,887 OPEN records. Round 3 closes 266 by exact
fresh raw-bin hits or matching functional-bin evidence; 2,621 remain OPEN.
This disposition changes no coverage denominator. The current seven-configuration
raw RTL inventory still has 2,500 uncovered code bins; six Product/AXI-Lite
functional group scores remain below 98%, with 27 functional-bin records and
22 cross records still open. No reachability waiver was requested or granted.

| Gate | Result | Evidence |
|---|---|---|
| Frozen Round 2 baseline audit | PASS | 2,887 OPEN records preserved; 2,787 code rows and 517 exact code signatures |
| Product-only constrained random | PASS, reduced budget | 12/12 campaigns; 9,216 accepted AXIS beats; 16,128 matched PA words |
| AXI-Lite constrained random | PASS, smoke only | 3/3 Round 3 campaigns; 3,072 accepted AXIS beats; matching Round 2 random VDBs included in final URG |
| Directed multi-SKU VCS and register access | PASS | Seven configurations; register predictor mismatch count 0 |
| Per-configuration URG | PASS | Seven independent merges; no cross-SKU or cross-elaboration merge |
| MASH reachability FPV | PASS | Three assertions proven; four non-vacuous covers hit; no waiver |
| Coverage closure / final sign-off | OPEN | 266 baseline rows closed; 2,621 remain; targets are not all met |

## Platform and scenario changes

- Added a Product-only random UVM test for EF1, EF2, and MASH. It randomizes
  bounded AXIS source gaps and four-plane PA backpressure, uses the independent
  scoreboard, fills the actual DUT input FIFO before starting the core, and
  samples the source-gap × FIFO-full × PA-stall cross only after queue/integrity
  checks pass.
- Added a state-driven reset/replay scenario. It waits for a real accepted PA
  output, holds output backpressure, asserts the actual reset, checks that
  `pa_valid` is cleared, then replays and drains the vectors through the
  scoreboard. Coverage is sampled from the observed DUT state rather than a
  fixed delay.
- Added a three-SKU AXI-Lite register-access run to cover read/write address
  classes, read-only write attempts, unmapped addresses, partial and zero
  WSTRB, DECERR/SLVERR behavior, and response backpressure. Each SKU recorded
  52 predictor-checked writes, 48 reads, and zero mismatches.
- Added a Round 2 OPEN-record audit and an exact Round 3 disposition generator.
  The original matrix stays intact as the comparison baseline. Fresh raw code,
  functional, cross, assertion, module-hole, and manifest data are under
  `docs/verification/data/dsm-v13-round3/`.
- Added an RTL-based MASH 1-1 formal harness for atomic four-plane validity,
  stable output during stall, and the legal combined-level set. Formal covers
  hit an accepted sample, output stall, reset/restart, and startup `+2`.
  Formal proves raw levels `-4`, `-2`, `0`, and `+4` unreachable under the
  modeled reset contract, but these raw coverage bins remain visible and OPEN.

No Product RTL, arithmetic, interface, latency, reset behavior, or MATLAB model
was changed. The candidate MASH plane-weight mapping remains a digital
four-plane contract; physical PA polarity/weights remain unapproved.

## Raw DUT code coverage

Percentages below are the selected DUT hierarchy subtree, raw URG values.
Targets are Line/Branch/Condition ≥95%, Toggle ≥90%, FSM ≥100%. Raw equals
adjusted because there are no active waivers or exclusions.

| Configuration | Line | Branch | Condition | Toggle | FSM |
|---|---:|---:|---:|---:|---:|
| EF1 Product | 88.38% | 75.92% | 79.87% | 84.38% | 100.00% |
| EF1 AXI-Lite | 89.03% | 79.11% | 81.38% | 81.09% | 68.18% |
| EF2 Product | 83.15% | 64.47% | 67.65% | 81.93% | 100.00% |
| EF2 AXI-Lite | 84.04% | 69.07% | 71.02% | 78.78% | 68.18% |
| MASH Product | 87.88% | 75.53% | 76.40% | 80.54% | 81.82% |
| MASH AXI-Lite | 88.62% | 79.09% | 79.49% | 76.80% | 68.18% |
| MASH wrapper/core | 90.16% | 71.43% | 100.00% | 98.36% | Not reported |

The largest per-metric increases are EF1 AXI-Lite Branch (+4.25 percentage
points), MASH AXI-Lite Branch (+4.38), EF2 Product Branch (+2.25), and EF1
Product Condition (+2.81). The remaining exact bins and source locations are
listed in `round3_raw_open_rtl_bins.csv`; per-metric deltas are in
`round3_code_coverage.csv`.

## Functional coverage

| Configuration | URG functional-group score |
|---|---:|
| EF1 Product | 94.35% |
| EF1 AXI-Lite | 92.71% |
| EF2 Product | 93.27% |
| EF2 AXI-Lite | 93.14% |
| MASH Product | 90.26% |
| MASH AXI-Lite | 92.54% |

All three AXI-Lite configurations reached 100% in the AXI-Lite `read_cg` and
`write_cg` register groups; reset-register coverage is also fully hit. The
EF2 Product and AXI-Lite `ef2_cg` clamp/rail/stall group is covered. The
Product-only source-gap × PA-stall × FIFO-full cross is hit in EF1, EF2, and
MASH Product. The exact remaining functional bins/crosses are retained in
`round3_functional_coverage.csv` and `round3_cross_coverage.csv`; none were
removed to inflate scores.

MASH Product still has raw weighted-level misses `-4`, `-2`, `0`, and `+4`,
plus two quantizer input-range × stage-1 rail crosses. The four raw-level
values are formally unreachable in the harness contract, but remain in raw
coverage and are not waived. The source/reset/FIFO context and remaining
configuration groups also have open bins.

## Regression accounting

- Product-only campaigns: four per SKU (smoke, scenario, reset, hole-directed),
  each PASS. Together they accepted 9,216 AXIS beats, matched 16,128 four-plane
  PA words, and accepted 12 TLAST markers.
- Round 3 AXI-Lite random: one 1,024-beat smoke per SKU, all PASS. Final URG
  additionally includes the three original Round 2 random VDBs per AXI-Lite
  SKU so the comparison uses equivalent random history. These read-only VDBs
  are individually hashed in `round3_evidence_manifest.json`.
- Directed regression and added register-access sequence: PASS for EF1, EF2,
  and MASH AXI-Lite plus Product and MASH wrapper/core configurations. Final
  URG used 56 test VDBs across the seven separate elaborations.
- Across the captured run logs: 47 UVM report summaries, zero UVM warnings,
  zero UVM errors, zero UVM fatals, and zero unexpected assertion failures.
- URG assertion inventories still have four assertions without attempts in
  each Product/AXI-Lite configuration (two in the MASH wrapper/core report).
  EF1 and EF2 Product each include one expected negative-test assertion
  failure; neither is counted as unexpected. Critical assertion activation is
  not claimed complete.
- Product random budget was four short campaigns per SKU; AXI-Lite random was
  one smoke per SKU. No 100,000-beat stress campaign was run. Coverage-driven
  reset and hole-directed tests were prioritized over adding broad random
  seeds; this does not meet the longer stress budget from the plan.

## Checks

- Seven-configuration VCS regression and URG merge — PASS.
- Product-only and AXI-Lite random campaigns — PASS (12/12 and 3/3).
- AXI-Lite register-access tests — PASS for all three SKUs; zero predictor
  mismatches.
- Python reference suite — 74/74 PASS.
- VC Formal MASH reachability — PASS: 3/3 assertions proven, 4/4 covers hit,
  `NO_WAIVER_REQUESTED`.
- Round 2 baseline audit — PASS: 2,887 OPEN rows, 2,787 code rows, 517 code
  signatures; no baseline disposition was overwritten.
- Evidence generator, source hashing, and per-configuration metric extraction
  — PASS; seven fresh URG configurations; no adjusted-coverage change.
- `python3 -m py_compile` for the Round 3 Python utilities and `git diff
  --check` — PASS.

PowerShell/XSim and MATLAB/Octave were unavailable in this Linux environment.
No XSim, MATLAB bit-true comparison, CDC/RDC, synthesis/PPA, physical serializer,
or board/RF check is claimed. The four-plane Product boundary is DV-L1; the
parallel-PA-to-physical-serializer DV-L2 remains OPEN. Final DV sign-off is
therefore OPEN.

## Machine evidence

`docs/verification/data/dsm-v13-round3/round3_coverage_summary.json` is the
machine-readable run summary. `round3_evidence_manifest.json` records source
hashes, URG reports, VDB tree hashes, logs, extracted tables, and the external
read-only Round 2 AXI-Lite VDB paths used in the final comparison. The detailed
per-record disposition is in `round2_open_round3_disposition.csv` and
`round3_remaining_open_records.csv`.
