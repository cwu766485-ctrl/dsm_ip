# DSM V1.3 Round 4 — Functional Coverage Closure

Date: 2026-11-26 00:04 SGT
Branch: `work/dsm-v13-mash-uvm-round4`
Baseline: Round 3 commit `9ae4e3fc574c34149930dca055d83528458be553`

## Result

**Adjusted functional coverage is closed for all six Product and AXI-Lite
configurations.** Each is 100.00% after 22 exact raw bins are excluded under
the user-confirmed four-plane MASH contract and STOP-drain-only RUN contract.
The URG databases and raw reports are unchanged by these accounting rules;
all 22 raw holes remain visible in the machine evidence.

Final DV sign-off remains **OPEN**. Selected-DUT raw code coverage is below the
Line/Branch/Condition/Toggle targets, and serializer DV-L2, MATLAB latency
alignment, CDC/RDC, STA/PPA, and board/RF sign-off remain outside this result.
No Product RTL behavior changed.

The original 2,621 Round 3 OPEN records remain represented:

| Disposition | Records |
|---|---:|
| Exact evidence HIT | 110 |
| NOT_APPLICABLE after Product-only AXI-Lite applicability audit | 3 |
| User-approved adjusted exclusion | 14 |
| OPEN | 2,493 |
| OPEN_UNMAPPED | 1 |

The 14 approved disposition records represent 22 exact bins: 10 formally
unreachable MASH bins and 12 restart/FIFO bins outside the selected software
contract. The current raw RTL inventory has 2,463 OPEN bins, with 75 exact
Round 3 raw-bin keys no longer present.

## Functional coverage

All six functional configurations meet 100% adjusted group and mandatory
cross coverage. Raw scores and adjusted scores are reported separately:

| Configuration | Raw score | Raw missing group bins | Adjusted score | Adjusted missing group bins |
|---|---:|---:|---:|---:|
| EF1 Product | 100.00% | 0 | 100.00% | 0 |
| EF2 Product | 100.00% | 0 | 100.00% | 0 |
| MASH Product | 98.20% | 5 | 100.00% | 0 |
| EF1 AXI-Lite | 97.22% | 4 | 100.00% | 0 |
| EF2 AXI-Lite | 97.39% | 4 | 100.00% | 0 |
| MASH AXI-Lite | 96.63% | 9 | 100.00% | 0 |

Raw functional group coverage has 22 missing bins. Raw mandatory cross coverage
has eight missing cells; those eight are a subset of the 22 group bins:

- **MASH, 10 bins across Product and AXI-Lite:** raw weighted levels `-4`,
  `-2`, `0`, and `+4` (four per configuration), plus minimum input rail ×
  positive Stage 1 (one per configuration). The user selected the existing
  four-plane Thermo5 interface contract. A full-width sequential proof covers
  W=16, 32 lanes, ACC_W=18, IN_SHIFT=0, and SATURATE=1. All five assertions
  prove, all four operational covers hit, and all five unreachable candidate
  covers report `uncoverable`. Both MASH configurations retain the raw bins;
  only the adjusted view excludes them.
- **Restart/FIFO, 12 bins across EF1, EF2, and MASH AXI-Lite:** partial/full
  FIFO coverpoint bins and partial/full restart × FIFO cross cells. The agreed
  software contract allows RUN only after a successful STATUS read reports
  RUN_ACTIVE=0 and DRAINING=0, with ingress FIFO empty. Each legal restart test
  checks that state, requires exactly one qualifying restart, and compares all
  112 four-plane output words. These bins remain raw-visible; the adjusted
  view excludes only the four exact out-of-contract bins per AXI-Lite
  configuration.

The early-RUN-during-DRAINING reproducer remains a separate failure diagnostic:
it observed a partial FIFO and RUN_ACTIVE+DRAINING, then recorded a four-plane
scoreboard mismatch at output word 45. It is excluded from passing VDB merges.
The agreed contract classifies this sequence as an illegal software operation;
no RTL change was made to force it to pass.

The Product-only `transaction_event_cg` applicability correction retains the
three frozen Round 3 rows as `NOT_APPLICABLE` without including AXI-Lite-only
bins in Product denominators. MASH maximum rail × negative Stage 1 was hit by
directed rail-history replay and checked by the independent four-plane
scoreboard.

The exact raw and adjusted values, per-bin disposition, approval basis, and
evidence links are in `round4_functional_coverage.csv`,
`round4_cross_coverage.csv`, `round4_waiver_proposal.csv`, and
`round4_coverage_disposition.csv`.

## UVM and URG evidence

The six selected Product/AXI-Lite elaborations were rebuilt from the current
UVM source and all 50 saved positive/negative directed test commands were
replayed. Seven separate URG merges passed: EF1 Product (9 VDBs), EF2 Product
(10), MASH Product (7), EF1 AXI-Lite (7), EF2 AXI-Lite (8), MASH AXI-Lite (9),
and the isolated MASH wrapper/core (1). Positive runs have zero UVM warnings,
errors, or fatals. Positive-only assertion reports and per-test MASH AXI-Lite
assertion-isolation reports were regenerated from the current-source VDBs.

The MASH wrapper/core VDB remains its own elaboration and is not merged with
Product or AXI-Lite. The early-restart diagnostic VDB is not part of any passing
merge.

## Raw code coverage

Final raw code targets remain Line/Branch/Condition ≥95% and Toggle ≥90%. Raw
equals adjusted for code coverage; no code bins were excluded.

| Configuration | Line | Branch | Condition | Toggle |
|---|---:|---:|---:|---:|
| EF1 Product | 88.32% | 75.46% | 77.39% | 84.24% |
| EF2 Product | 83.09% | 64.10% | 67.65% | 81.98% |
| MASH Product | 87.88% | 75.53% | 76.90% | 80.63% |
| EF1 AXI-Lite | 88.97% | 78.74% | 79.76% | 80.46% |
| EF2 AXI-Lite | 84.04% | 69.07% | 71.61% | 78.63% |
| MASH AXI-Lite | 88.65% | 79.28% | 79.76% | 76.63% |
| MASH wrapper/core | 90.16% | 71.43% | 100.00% | 98.36% |

Focused DPD/interpolator block tests remain separate from Product URG. DPD
polynomial orders 3/5/7 close Line, Branch, and Condition in their standalone
elaborations but retain toggle holes. Memory-polynomial, interpolator, and
EF2-specific raw code holes remain; their exact results are in
`round4_block_level_code_coverage.csv` and `round4_block_raw_open_rtl_bins.csv`.

## Assertions and formal evidence

The current-source MASH sequential Formal run proves five assertions, hits four
required operational covers, and establishes five candidate covers as
uncoverable. The run result records the W16/32-lane/ACC18 parameters, source
hashes, Formal properties hash, engine log hash, VCS Formal log hash, and
non-vacuity results. This supports only the MASH 1-1 four-plane scope above.

The separate frame-tail metadata proof remains PASS for its exact legal
centered-cubic geometry. MASH AXI-Lite retains one reset-aborted incomplete
assertion attempt as `RESET_ABORT_EXPECTED`; it is not counted as success or
failure. Positive legal assertion runs have zero failures.

Eight separate DPD/interpolator block runs pass their independent checkers:
DPD identity exhaustive, DPD protocol, DPD polynomial orders 3/5/7, four-tap
memory-polynomial, centered-cubic sustained, and polyphase reachable.

## Checks and remaining scope

- Current-source VCS replay: 50/50 tests PASS across six selected
  Product/AXI-Lite elaborations.
- Seven independent URG merges and positive-only assertion reports: PASS.
- MASH sequential Formal: 5/5 assertions proven, 4/4 required covers hit,
  5/5 unreachable candidates `uncoverable`; source and report hashes verified.
- Evidence generation: PASS; raw 22 functional misses and raw 8 cross misses
  retained, adjusted misses 0 and 0.
- Python reference suite: 74/74 PASS in the earlier Round 4 verification run;
  no MATLAB or bit-true model source changed in this closure update.
- PowerShell/XSim is unavailable in this Linux environment and was not run.

Raw code-coverage closure and final DV sign-off remain OPEN. CDC/RDC, STA/PPA,
MATLAB latency alignment, physical serializer DV-L2, and board/RF sign-off are
not established by this Round 4 functional-coverage result.
