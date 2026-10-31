# Thermo5 TX Coverage Closure — Current Linux Snapshot

**Status: `LINUX_CLOSURE_OPEN; RAW_100_OPEN`.** This report is bound to Product RTL SHA `19d295360aa6438f4af20e7a6ab44bfebf2fc1ea`. Product configuration: Centered-Cubic x2+x2; EF2 ORDER=2, STEP=5120, STATE_BITS=20; 32 chronological lanes; `DPD_MAX_TAPS=1` identity DPD; AXI-Lite product frontend; Generic FIFO for Linux. No algorithm, RX, or AI-DPD RTL was changed.

The raw code report is the union of 13 legal Product VDBs, 11 legal source-gap VDBs, and one independently checked expected-negative malformed-frame VDB. Legal Functional and Assertion Coverage use the positive-only report. The source-bound audit has zero current product-source manifest mismatches. Raw URG/VDB denominators are unchanged; approved waivers=0 and active `.el` exclusions=0.

## Functional coverage

| Scope | Covered / total | Status |
|---|---:|---|
| Legal applicable positive Product bins | 210/210 | PASS |
| Raw scoreable union records | 214/214 | Includes 4 negative-only illegal semantics; not legal positive bins |
| Existing URG-model Illegal/Excluded rows | 12 | Reported separately; no new exclusion directive |

The 214 scoreable records include report-type and monitor-instance views. The four negative-only records are two semantic bins duplicated across those views (`bad_frame`, 49 hits, and `malformed_early`, 1 hit). The full 226-row detail is in `thermo5-tx-focused-product-functional-bin-detail.csv`.

## Raw code coverage and root-cause ledger

| Metric | Raw covered / total | Raw missing | Percent |
|---|---:|---:|---:|
| Branch | 524/637 | 113 | 82.2606% |
| Condition | 610/849 | 239 | 71.8492% |
| Line | 3,350/3,796 | 446 | 88.2508% |
| Toggle (both directions) | 83,587/104,480 | 20,893 | 80.0029% |
| FSM states | 13/13 | 0 | 100% |
| FSM transitions | 22/22 | 0 | 100% |

The source-linked ledger has 21,691 Raw miss records grouped into 429 tasks: 371 `PROVEN_UNREACHABLE` records and 21,320 `OPEN` records. The proven records are retained in Raw and comprise 10 exact current-source Formal bins, 344 EF2 `PAIR_LOOKAHEAD` static-product-configuration bins, and 17 fixed-parameter Branch bins. No waiver or exclusion was used to reduce the denominator.

| Metric | Tasks | Proven/dispositioned | Open |
|---|---:|---:|---:|
| Branch | 44 | 41 | 3 |
| Condition | 98 | 27 | 71 |
| Line | 98 | 39 | 59 |
| Toggle | 189 | 0 | 189 |
| **Total** | **429** | **107** | **322** |

The exact ledger is `thermo5-tx-focused-product-gap-ledger.csv.gz` (SHA-256 `4da683c08f8b58614de1b7e5018d39d077bf99b3af768b9a6ccbd4aaf41a8064`); task dispositions are in `thermo5-tx-focused-product-closure-tasks.csv`. Raw equals Adjusted. The gate is `RAW_100_OPEN`, not signed off.

## Regression, assertions, Formal, and mutation

- VCS V-2023.12-SP1: exact-source positive Product replay 13/13 PASS. The 11-case legal source-gap sweep passed its independent four-plane checker. These unchanged VDBs were reused for the current URG union rather than rerunning the full suite.
- Expected-negative malformed-frame regression, seed 420102: independent sticky-error/reset-recovery checker PASS with zero UVM warnings/errors/fatals. Two expected RTL assertion failures are reported separately from legal assertions.
- Legal assertion summary: 13 successes / 15 attempted; 2 uncovered, 2 without attempts, 0 failures.
- Mutation: baseline PASS; `late_gain` and `plane_swap` mutations detected by the bit-true scoreboard. No broader mutation claim is made.
- VC Formal V-2023.12-SP2: the legal early-TLAST harness reached legal packet-end Cover at depth 59, but the no-early-TLAST assertion was INCONCLUSIVE at depth 312 and the target Cover INCONCLUSIVE at depth 342 (0 environment assumptions, 0 selected setup violations, 0 black boxes). It creates no disposition. DPD Identity and outstanding-word counter saturation/underflow proofs also remain INCONCLUSIVE.
- The 16-cycle source-gap case fails its independent underflow checker and remains OPEN as a service-rate/environment contract question.

## Current evidence and limitations

- Combined code URG report: `runs/thermo5_tx_centered_pop_push_gap_closure_20261031_pr22/negative_combined_code`.
- Coverage gate JSON: `runs/thermo5_tx_centered_pop_push_gap_closure_20261031_pr22/negative/combined_coverage-gate.json`.
- Source-frame Formal manifest: `runs/thermo5_tx_early_tlast_legal_formal_20261031/formal_manifest.json`.
- Machine-readable current summary: `../thermo5-tx-final-coverage-evidence.json`.

Real XPM and GT Wizard/TXP payload simulation, FPGA PPA/timing, and physical QAM256 BER remain outside Linux signoff. All remaining reachable/applicable DUT bins stay OPEN until hit with legal stimulus and an independent checker, or individually reviewed with valid non-vacuous Formal evidence.
