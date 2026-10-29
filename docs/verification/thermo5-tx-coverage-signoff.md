# Thermo5 TX coverage audit — Gate 3 Linux result

**Disposition:** `FUNCTIONAL_GROUPS_PASS; RAW_100_OPEN; GATE3_NOT_SIGNED_OFF`
**Date:** 2026-10-29 (Asia/Singapore)
**Coverage source base:** `e5d1951dde51089ae431017aa39ea25af48cf26e` (same tree as the pushed Gate 1 branch commit `813db9c9a488b033dc4686553cbe3a06856acc0b`)
**Coverage exclusions:** 0
**Coverage denominator edits:** 0
**Audited-adjusted score:** not calculated; no exclusion review has been approved.

> **Product-only scope update (2026-10-30):** This file retains the historical
> PR #5 Gate 3 campaign, whose AXI-Lite VDB merge includes
> nonidentity 2/4-tap candidate DPD runs. It is not the product-only score for
> the actual GT-parent one-tap identity setting. The selected-test,
> AXI-Lite/Generic-FIFO product baseline, candidate separation, and zero-waiver
> audit are recorded in
> [`thermo5-tx-coverage-closure.md`](thermo5-tx-coverage-closure.md) and
> [`thermo5-tx-product-coverage-evidence.json`](thermo5-tx-product-coverage-evidence.json).
> Do not substitute either report for the other.

The Gate 3 Linux campaign reran Generic and AXI-Lite VCS/UVM suites, targeted
EF2 clamp/rail/stall/reset cases, STOP/restart, legal vector corners, scoped
VC Formal, and a checker negative mutation. URG was merged and parsed
separately for each elaboration. Every unhit row is preserved as OPEN in the
source-linked, gzip-compressed [`thermo5-tx-gate3-coverage-ledger.csv.gz`](thermo5-tx-gate3-coverage-ledger.csv.gz).
Decompress it with `gzip -dc thermo5-tx-gate3-coverage-ledger.csv.gz > thermo5-tx-gate3-coverage-ledger.csv` to inspect all 22,720 rows.
The current Feature/Testpoint/Checker summary is in
[`thermo5-tx-feature-matrix.md`](thermo5-tx-feature-matrix.md).

## Raw project RTL URG scores

These are distinct configurations and are not merged together. Counts are
raw URG counts scoped to project RTL; there are no exclusions or denominator
changes. The aggregate score is the raw URG DUT score, not an adjusted score.

| Metric | Generic | AXI-Lite |
| --- | ---: | ---: |
| Raw aggregate score | 80.81% | 84.59% |
| Line | 2,965 / 3,566 = 83.15% | 3,428 / 3,796 = 90.31% |
| Condition | 482 / 711 = 67.79% | 635 / 846 = 75.06% |
| Toggle, both directions | 81,348 / 98,270 = 82.78% | 116,912 / 120,990 = 96.63% |
| Branch | 343 / 532 = 64.47% | 520 / 637 = 81.63% |
| FSM states | 13 / 13 = 100% | 13 / 13 = 100% |
| FSM transitions | 22 / 22 = 100% | 17 / 22 = 77.27% |
| Assertion URG score | 86.67% | 86.67% |

Assertion status counts are retained verbatim: Generic has 13 `SUCCESS`, 1
`FAILURE`, 2 `UNCOVERED`, and 2 `WITHOUT_ATTEMPTS` DUT assertion records.
AXI-Lite has 13 `SUCCESS`, 2 `FAILURE`, 2 `UNCOVERED`, and 1
`WITHOUT_ATTEMPTS`. The failures are the expected negative early-frame checks
in `dsm_axis14_to_core8_cdc.sv` (both runs) and
`dsm_interp_x2_centered_cubic_vector.sv` (AXI-Lite only). They remain raw
failures in the signed report and are not relabeled as successful assertion
coverage.

The refreshed exact unhit-bin ledger contains **17,941 Generic rows** and
**4,779 AXI-Lite rows**. Current-source one- and two-packet non-identity
2-tap and 4-tap DPD tests were added to the AXI-Lite VDB merge; the raw
AXI-Lite toggle score rose from 89.86% to 96.63%. The ledger includes exact
source file, elaborated instance, line or
branch/condition/toggle/FSM bin, review status, reason, and a stable bin ID.
No row is waived. For AXI-Lite, five individual unhit
`rem_count_q` transitions are named in the ledger; the Generic FSM transition
bins are all covered. Source mapping succeeded for every ledger record.
The independent raw URG summaries and complete URG reports are retained in
the local run directory referenced by the evidence manifest.

## Functional coverage and directed checkers

URG functional group results:

| Configuration | Current group score | Interpretation |
| --- | ---: | --- |
| Generic | 80.00% aggregate; 4/4 applicable groups are 100% | The only zero group is AXI-Lite STOP/Restart, which is not part of the direct Generic configuration. |
| AXI-Lite | 100.00%; 8/8 groups are 100% | Includes read, write, reset, source/core, four-plane atomicity, EF2, and STOP/Restart groups. |

Targeted independent checks also confirm:

- Eight legal digital corner vectors per Generic and AXI-Lite configuration
  (zero, positive/negative full scale, alternating endpoints, impulse, ramp,
  PRBS, and quantizer tie) match the four-plane integer oracle.
- EF2 positive and negative clamp activity is checked on each of four
  thermometric branches. Clamp-candidate stall tests assert state hold for
  eight cycles; rail interaction, reset and replay are checked.
- AXI-Lite graceful STOP overlaps an accepted TLAST with partial PA
  backpressure (`tlast_pa_stall=5`, `stop_partial_pa_stall=5`) and checks 56
  drained words. STOP/drain/restart checks 112 ordered four-plane words and
  six event bins.
- Current-source non-identity two- and four-tap DPD cases each pass 56-word
  and 112-word bit-true comparisons on all four planes with zero UVM errors or
  fatals. These are test-only elaborations; the product GT parent remains
  one-tap identity.
- The corrupted-oracle negative mutation flips bit 0 of output word 0 in the
  expected `pa0` memory image. The scoreboard reports a one-LSB mismatch at
  epoch 0 / word 0 / plane 0 and raises `UVM_FATAL`; this proves that the
  checker detects a deliberate data error.

Functional covergroup closure is not equivalent to full feature-matrix or
source code closure. The matrix calls out the remaining XPM, GT Wizard,
physical and unmeasured crossings explicitly.

## Commands and run evidence

Python reference suite:

```bash
cd dv/uvm/refmodel/python
python3.12 -m unittest discover -s tests -v
```

Result: **39/39 passed**.

Generic centered-cubic/EF2 regression and AXI-Lite regression were run using
the `thermo5-vcs-regression` and `thermo5-axil-vcs-regression` Make targets
with Python 3.12, `TIDSM_ORDER=2`, `STEP=5120`, and the 56-word regression
vectors whose frame starts are `1,8,36`. Their full logs are
`runs/thermo5_tx_linux_closure_wip/generic_full_regression.log` and
`runs/thermo5_tx_linux_closure_wip/axil_full_regression.log`; each selected
positive-path run reports zero UVM errors/fatals. The negative malformed
frame tests intentionally trigger and check the expected RTL assertions.

Additional checks recorded in the run manifest:

- `make -C dv/uvm/sim thermo5-ef2-qualification PYTHON=python3.12 THERMO5_OUT="$PWD/runs/thermo5_tx_linux_closure_wip/generic_vcs" THERMO5_EF2_SUSTAINED_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/ef2_qualification/vectors/sustained" THERMO5_EF2_RANDOM_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/ef2_qualification/vectors/random" THERMO5_EF2_EXTREME_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/ef2_qualification/vectors/extreme"` — three seeded 2,072-word Generic scenarios pass bit-true checking, clamp / stall / reset checks, and directed target crosses. The direct Generic wrapper reports post-source finite-tail underflow cycles because it has no drain control; `early_underflow=0`. This diagnostic is not hidden.
- `make -C dv/uvm/sim thermo5-axil-ef2-qualification PYTHON=python3.12 THERMO5_OUT="$PWD/runs/thermo5_tx_linux_closure_wip/axil_vcs" THERMO5_AXIL_EF2_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/axil_ef2_qualification/vectors/extreme"` — 2,072 AXI-Lite output words match; positive/negative clamps, per-branch events, state rail and rail stall are observed; `underflow=0`.
- `make -C dv/uvm/sim thermo5-axil-stop-restart-vcs-run PYTHON=python3.12 THERMO5_OUT="$PWD/runs/thermo5_tx_linux_closure_wip/stop_restart_vcs" THERMO5_STOP_RESTART_TIDSM_ORDER=2 THERMO5_STOP_RESTART_STEP=5120 THERMO5_STOP_RESTART_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/vectors/stop_restart"` — 112 ordered words match, six event bins pass, no protocol/underflow error.
- `python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --out-dir
  runs/thermo5_tx_linux_closure_wip/formal --jobs ef2 ef2_pair` — EF2 safety
  6/6 assertions and 3/3 covers; pair-look-ahead 7/7 assertions and 4/4
  covers; zero black boxes. Formal evidence is separate from simulation
  coverage.
- Checker mutation: the VCS executable under
  `runs/thermo5_tx_linux_closure_wip/generic_vcs/simv` ran
  `thermo5_sku_bittrue_test` with `+CORE_WORDS=56` and the corrupted vector
  directory. `sim.log` contains the expected `[BITTRUE]` mismatch and one
  UVM fatal. VCS returns process status 0 after UVM `$finish`; the checker
  marker, not the process return code, is the mutation oracle.
- Raw generic and AXI-Lite URG summaries were exported with
  `python3.12 tools/hw/thermo5_coverage_denominator.py` through the existing
  `thermo5-coverage-merge` regression targets. The source-linked gap CSV was
  regenerated by:

  ```bash
  python3.12 tools/hw/thermo5_gap_ledger.py \
    runs/thermo5_tx_linux_closure_wip/coverage_refresh \
    runs/thermo5_tx_linux_closure_wip/coverage_refresh/gaps \
    --report-layout flat --variants generic axil
  ```

- Current-source non-identity DPD coverage was collected with
  `thermo5-axil-centered-nonlinear-bittrue-vcs` and
  `thermo5-axil-centered-nonlinear-tap4-bittrue-vcs`, using
  `TIDSM_ORDER=2`, `STEP=5120`, and the vector/output paths in the evidence
  manifest. Their four VDBs were added to the AXI-Lite URG merge at
  `axil_all_with_dpd/report`; the updated raw score and gap ledger come from
  that report.

The machine-readable source hashes, exact run paths, raw summary hashes,
logs, VDBs, expected-negative assertions, and no-exclusion record are in
[`thermo5-tx-gate3-evidence.json`](thermo5-tx-gate3-evidence.json). Full
VCS/formal logs, VDBs, vector directories, and raw URG HTML remain under
ignored `runs/thermo5_tx_linux_closure_wip/`; generated logs and databases are
not committed.

## Remaining Gate 3 and Gate 4 limits

`RAW_100_OPEN` remains the result. The exact gaps include legal stimulus
opportunities, fixed-parameter error arms, DPD tap/history alternatives,
arithmetic saturation arms, formal-mapping leads, counter transitions, and
five AXI-Lite residual-state FSM transitions. These classifications are
review queues generated from source and instance context, not approved
exclusions. They must be individually reviewed and either hit with legal
stimulus, proven unreachable under explicit fixed-SKU assumptions and
approved for exclusion, or left OPEN. A formal proof is not a simulator hit.

Real XPM/GT Wizard simulations, XSim/Vivado, FPGA PPA/routed Fmax, CDC/RDC
implementation review, calibrated DPA/RF data and physical QAM256 BER are not
available in this Linux run. Gate 4 is therefore **OPEN**; no board-ready or
100%-eligible claim is made.
