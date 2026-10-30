# Thermo5 TX-only Linux closure status

**Status:** Linux functional/model work through Gate 3 is recorded; complete
source-code coverage and Gate 4 hardware signoff remain open. This report does
not claim a stable physical QAM256 link.

> **Current product-only follow-up — PR #7, 2026-10-30:** The product VCS
> source remains `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b` (tree
> `694457bbacf2eda2a061da910f404975fd75ec8d`); the product VCS filelist is
> unchanged from simulation source SHA `913be930bfcbbad0f78dbc90e06299db3d1bb337`.
> A later Formal-only source commit `f6956b9342add9af86c8977999c517283232275e`
> adds exact EF2 product-parameter reachability evidence; it does not change
> VCS inputs or TX RTL.
> Formal-only source `36d88f41de20202bd42d98fa9b510cb8dc1bf0f7` extends the
> AXI-Lite `MAX_TAPS=1` parameter guard proof; it changes no VCS input or DUT RTL.
> The TX product Raw URG is 81.99%: line 3190/3796, condition 583/846, branch
> 440/637, toggle 86951/104478, FSM states 13/13 and transitions 22/22.
> Functional report: 210/214 scoreable Raw bin records, including all generated
> crosses; 210/210 legally applicable positive records are hit. There are 0
> approved code waivers/exclusions;
> Raw 100% remains open. The detailed product-only report and exact run
> provenance are in [`thermo5-tx-linux-coverage-closure.md`](thermo5-tx-linux-coverage-closure.md)
> and its evidence JSON.

> **Functional bin accounting correction — 2026-10-30:** The previous 170/174
> tally omitted 40 automatically generated EF2 cross-bin records from the same
> unchanged URG Group Report. The full type and instance view now enumerates
> 214 scoreable rows (210 hit, four illegal-frame-only misses) plus 12 bins
> already marked Illegal/Excluded by the URG model. Raw URG data and its
> denominator were not changed. See the [complete bin detail](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-detail.csv)
> and [current Linux signoff snapshot](thermo5-tx-coverage-final-signoff.md).

## Gate status and published revisions

| Gate | Result | Published change / evidence | Acceptance boundary |
| --- | --- | --- | --- |
| Gate 0 — baseline | `PASS_LINUX_GENERIC_SCOPE` | Verification source `04550289e1ecb5fa0e38168869d4f2539929cb80`; [PR #2](https://github.com/cwu766485-ctrl/dsm_ip/pull/2) | Generic Linux baseline and documented AXI-Lite behavioral checks pass. XPM/vendor and board behavior are outside this result. |
| Gate 1 — algorithm A/B | `PASS_FUNCTIONAL_EQUIVALENCE` | Tested source `dfb15a278657e4417b545fc138df0f0dd0399ac4`; published commit `813db9c9a488b033dc4686553cbe3a06856acc0b`; [PR #3](https://github.com/cwu766485-ctrl/dsm_ip/pull/3) | Pair-look-ahead miter/formal and 2/4-tap bit-true tests pass. No candidate was promoted. Hardware cost, routed timing, and fitted DPD benefit remain open. |
| Gate 2 — TX worst-case model | `MODEL_CAMPAIGN_COMPLETE; TARGET_UNDEFINED` | Published commit `d65ac3762d344c1001552890ae81cd9d243a4910`; [PR #4](https://github.com/cwu766485-ctrl/dsm_ip/pull/4) | Held-out Python results and sensitivity cases are recorded. Product BER/BLER/EVM/ACLR limits and physical performance are not defined or signed off. |
| Gate 3 — functional/code coverage | `FUNCTIONAL_GROUPS_PASS; RAW_100_OPEN` | Historical PR #5 code `459c69094f3353558321075305808d9712e6f335`; current product-only follow-up [PR #7](https://github.com/cwu766485-ctrl/dsm_ip/pull/7) | Current product-only result is 81.99% Raw; the exact source-linked open/review ledger has 18,593 rows. No exclusions or denominator edits are applied. |
| Gate 4 — hardware/link signoff | `OPEN` | No Linux signoff revision | Real XPM, current GT Wizard/TXP, parent CDC/RDC, FPGA PPA, and physical QAM256 BER require unavailable vendor or hardware flows. |

The Gate 2 and Gate 3 PRs are stacked on the Gate 1 branch and remain open
for review; they have not been merged to `thermo5`.

## Frozen TX configuration and algorithm results

The product defaults remain centered-cubic x2 interpolation, second-order
EF2 TIDSM, `STEP=5120`, 20-bit state, chronological sample order, and four
thermometric output planes. Pair-look-ahead remains disabled in the product
hierarchy. No RX, AI-DPD, or synthesizable datapath RTL behavior was changed
in this Linux closure work.

Gate 2 used four development and four disjoint held-out QAM256 seeds. Its
finite-set selected point was RMS drive 0.10, `STEP=5120`, 20-bit state, no
backoff and no clipping: 21/224,256 uncoded bit errors (`BER=9.3643e-5`),
mean EVM 2.4640%, and mean SNDR 32.1675 dB. The illustrative nominal/stress
analog-chain cases measured BER `1.4269e-4` / `7.7144e-4`. These results do
not establish a production threshold, device calibration, or physical BER.
The 18-bit model saturated 30 times in this sample; finite-set non-saturation
at 19 bits is not evidence to reduce RTL state width. The tested fixed 2/4-tap
DPD images performed worse than identity, which rejects those images only.
Full assumptions, matrices, commands, and hashes are in
[`thermo5-tx-worst-case.md`](thermo5-tx-worst-case.md) and
[`thermo5-tx-gate2-evidence.json`](thermo5-tx-gate2-evidence.json).

## Current product-only coverage follow-up (PR #7)

| Raw product DUT metric | Covered / total | Raw coverage |
| --- | ---: | ---: |
| Aggregate URG | — | 81.99% |
| Line | 3,190 / 3,796 | 84.0358% |
| Condition | 583 / 846 | 68.9125% |
| Branch | 440 / 637 | 69.0738% |
| Toggle, both directions | 86,951 / 104,478 | 83.2242% |
| FSM states / transitions | 13/13; 22/22 | 100% |

The latest Raw merge contains 29 product-hierarchy-scoped simulation VDBs
plus the compile VDB. The full URG Group Report contains 214 scoreable bin
records; 210/210 legally applicable positives are hit, while four illegal-frame
rows remain unhit in Raw. The earlier 170/174 tally omitted the 40 EF2
cross-bin records and is superseded by the complete bin detail.
The 18,593-row source-linked ledger remains OPEN/review-only. The targeted
zero-gap, inter-frame-gap, and source-pacing VCS tests and AXI-Lite reachability
proof are documented in the linked closure report. At `MAX_TAPS=1`, Formal
proved 4/4 AXI-Lite assertions, including both write-case and coefficient-read
default targets, plus a 1/1 legal-read cover; both targets are non-vacuous. This
has not removed a raw bin or created a waiver. A source-gap
sweep passed at 2/4/8 cycles and failed at 16 cycles due to 54 underflow events
even though all 112 outputs and both frame markers were observed; the failed
VDB is excluded from Raw coverage. No full Gate 0–3 regression was repeated in
PR #7.

The Frame Tail module-level VC Formal check now passes with the parameter split
used by `tid32_thermo5_frontend_tx.sv:102/:178`: the append-enabled stage
reaches and transfers its synthetic tail, while the append-disabled stage's
tail output is uncoverable.
All three assertions and all three applicable covers pass; the fourth cover is
expected uncoverable, with zero black boxes and setup violations. This does not
prove full two-stage composition and does not change Raw URG coverage or its
denominator.

The exact EF2 product parameters (`W=16`, `CHANNELS=32`, default
`PAIR_LOOKAHEAD=0`) also pass a scoped VC Formal reachability check: 2/2
parameter assertions proven and 2/2 candidate covers expected-uncoverable,
zero black boxes. The Raw branch bins remain open and counted. A mailbox fault
injection test separately observed the expected RTL `$error` and passed public
reset recovery; its report is kept with other expected-negative results and
outside positive Raw coverage.

The exact AXI-Lite `MAX_TAPS=1` Formal harness also checks the parameter guard:
5/5 assertions proven, with the guard assertion identified as a static
tautology and the invalid-parameter cover expected uncoverable. Its
`thermo5_dpd_axi_lite_cfg.sv:348` Raw branch remains counted and unwaived;
this is elaboration-parameter evidence, not a sequential proof.

## Historical PR #5 multi-configuration Gate 3 coverage result

| Raw project RTL metric | Generic | AXI-Lite |
| --- | ---: | ---: |
| Aggregate URG score | 80.81% | 84.59% |
| Line | 2,965/3,566 (83.15%) | 3,428/3,796 (90.31%) |
| Condition | 482/711 (67.79%) | 635/846 (75.06%) |
| Toggle, both directions | 81,348/98,270 (82.78%) | 116,912/120,990 (96.63%) |
| FSM states | 13/13 | 13/13 |
| FSM transitions | 22/22 | 17/22 |
| Branch | 343/532 (64.47%) | 520/637 (81.63%) |
| Assertion URG score | 86.67% | 86.67% |

Current sampled functional groups are 4/4 applicable Generic groups and 8/8
AXI-Lite groups at 100%. Generic STOP/Restart is not present in that direct
configuration. Raw aggregate code coverage is not 100%: the source-linked
ledger contains 17,941 Generic and 4,779 AXI-Lite unhit rows. All rows remain
OPEN; there are zero exclusions and zero denominator edits. No audited-adjusted
coverage score is claimed. The [coverage report](thermo5-tx-coverage-signoff.md)
and [evidence manifest](thermo5-tx-gate3-evidence.json) distinguish raw code,
functional groups, expected negative assertion failures, and unavailable
configurations.

## Linux checks and exact evidence

Python reference suite: **39/39 passed**.

```bash
cd dv/uvm/refmodel/python
python3.12 -m unittest discover -s tests -v
```

Current-source Generic and AXI-Lite VCS regressions, 2,072-word EF2
positive/negative clamp and state-hold qualification, STOP/drain/restart,
eight legal corner patterns per configuration, scoped EF2/pair-look-ahead VC
Formal, and the one-LSB checker mutation are recorded with exact commands,
logs, source hashes, raw coverage numbers, and run-directory checksums in
[`thermo5-tx-gate3-evidence.json`](thermo5-tx-gate3-evidence.json). Formal
proved 6/6 EF2 assertions and 7/7 pair-look-ahead assertions, with 3/3 and
4/4 cover properties, respectively, and zero black boxes. The Generic direct
wrapper's post-source finite-tail underflow diagnostic remains reported with
`early_underflow=0`; the AXI-Lite EF2 qualification reports zero underflow.

Tool inventory on this host: VCS V-2023.12-SP1 and VC Formal V-2023.12-SP2
are available; Vivado, XSim, Yosys, Verilator, and real XPM source are absent.
The exact per-bin coverage ledger is stored as
[`thermo5-tx-gate3-coverage-ledger.csv.gz`](thermo5-tx-gate3-coverage-ledger.csv.gz);
the manifest records both compressed and reconstructed CSV hashes.

## Remaining work

- Define the supported communication envelope and product BER/BLER/EVM/ACLR
  limits before judging QAM256 stability.
- Resolve the current PR #7 product ledger's 18,593 open/review records by
  legal tests or evidence-based, reviewed reachability dispositions; keep
  every current row OPEN until reviewed. The 22,720 count below is the
  historical PR #5 multi-configuration ledger. Do not alter denominators to
  reach 100%.
- Run real XPM and current GT Wizard/TXP simulation, parent CDC/RDC review,
  VCU118/ZCU111 Vivado implementation/PPA, and physical QAM256 BER when those
  tools, IP sources, constraints, and hardware are available.
- Pair-look-ahead routed Fmax/LUT/FF/DSP comparison and fitted/calibrated
  non-identity DPD assessment remain unmeasured.
- A tracked-RTL module text-reference scan found no module with zero textual
  references. No source was deleted or archived without a demonstrably unused
  file candidate.
