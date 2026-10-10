# Thermo5 coverage closure and the 100% request

## Latest current-source bit21 result (2026-10-08)

After a 2,097,158-word bit-true generic/XPM stress run, raw DUT URG scores are
87.52% / 80.31%. Exact reviewed exclusions produce partial adjusted reports
of 99.66% / 96.71%, not100%. The review excludes only exact configuration or
linked scoped-proof bins. It leaves all reachable bins open: in particular,
`sample_count[31:22]` contributes320 natural toggle directions per FIFO; the
generic interpolation clamp line/branch bins remain open; and XPM still has
vendor gaps and one FWFT transition open. The XPM generator also leaves19
candidate branches unmatched to native signatures. Full details and artifacts:
[reachability closure](thermo5-reachability-closure-20261008.md). Raw or
adjusted100% has not been achieved.

Historical2026-10-07 candidate accounting (not a current-source adjustment):
[coverage reasons](thermo5-coverage-reasons-20261007.md). Raw latest
CI37462007850 is generic87.48%, XPM80.26%; no exclusions. Candidate generic
line/branch/condition accounting reaches100%, but toggle99.3461% retains544
reachable directions. Full raw or adjusted code100% is not achieved.

## Earlier current-source licensed package, before long-range closure
(2026-10-08)

`runs/thermo5_current_source_dv_resume_20261008/dv_package.json` is PASS for
source digest `0e1d0d9040bb4f7aba2905295cf7f117d432a2fdf1b2ebfe38300674ca1089f8`
(202 RTL/DV files, dirty worktree). Coverage, scoped formal and historical bug
controls all passed. The independent four-plane 131075-word stream checked
74900 source beats and 131075 output words per FIFO. Fresh VCS V-2023.12-SP1
raw DUT metrics are:

| Raw metric | Generic before | Generic after | XPM before | XPM after |
| --- | ---: | ---: | ---: | ---: |
| URG score | 87.01 | 87.49 | 79.96 | 80.27 |
| Line | 86.85 | 86.92 | 76.73 | 76.78 |
| Condition | 78.90 | 79.77 | 68.69 | 68.84 |
| Toggle | 83.83 | 85.27 | 81.26 | 82.71 |
| FSM | 100.00 | 100.00 | 90.91 | 90.91 |
| Branch | 72.45 | 73.00 | 62.19 | 62.37 |
| Assertion | 100.00 | 100.00 | 100.00 | 100.00 |

Exact after-report covered/total counts are generic line2512/2890, condition
276/346, toggle82744/97032, branch265/363; XPM line3122/4066, condition
453/658, toggle92123/111376, branch696/1116. These denominators match the
Oct7 candidate inventory, but source-hash mismatch prevents reuse of its
dispositions.

The package closure's exact condition hits were generic interpolation line71
tuple `1/0`, CDC lines190 and220 tuple `0/1/1`, and XPM vendor line754 tuple
`1/0`. Both variants hit both TID toggle directions for162/162 input bits;
the stream reached both directions through DPD counter bit17 in all16 lanes.
Bits31:18 remain448 open directions per FIFO. A separate same-source,
same-binary core-first/FWFT report remains at generic87.49% / XPM80.29%, with
the exact XPM line52 hit, line57/59 reset tuples still OPEN, and FWFT FSM at
8/9. Its evidence is
`runs/thermo5_gap_closure_fwftmon_20261008/exact_final_delta.json`; its VDBs
are not mixed into the fresh package report.

Adjusted URG is **NOT_RECOMPUTED**. The prior candidate ledger's raw
denominators match the fresh report, but its per-source hashes do not fully
match: 4358 project disposition rows reference a changed
`dv/uvm/tb/thermo5_sku_uvm_tb.sv` hash, and 6124 vendor XPM rows have no source
hash. No candidate dispositions were carried forward and no URG exclusions
were applied. Hosted current-source CI also remains OPEN.

One optional bit18 experiment was not run. MATLAB vector generation was
started for the smallest legal range-stress size above2^18, 262150 words,
seed610073, but was stopped after about32minutes near the agreed30-minute
resource cap with no output vectors; the launcher exited with
`MATLAB vector generation failed: -1`. The attempt record is
`runs/thermo5_bit18_20261008/attempt.json`. This is a resource
limit, not a simulation failure or coverage hit. Bit18 and all higher
directions remain OPEN. No raw or adjusted100% result is claimed.

Date: 2026-10-06 (Asia/Singapore). No physical board is available.

## Executed digital result

Fresh evidence: `runs/thermo5_coverage100_closure_final_20261006/`.
`closure.json` is PASS. A new compilation per FIFO passes the fourteen
directed baseline runs and six independent MATLAB payload runs. Five
additional directed tests per FIFO pass. Each before/after merge uses that
FIFO's own compiled binary and VDB. No coverage exclusions are applied.

| Raw DUT metric | Generic before | Generic after | XPM before | XPM after |
| --- | ---: | ---: | ---: | ---: |
| URG score | 87.00 | **87.47** | 79.96 | **80.25** |
| Line | 86.85 | 86.92 | 76.73 | 76.78 |
| Condition | 78.90 | 79.77 | 68.69 | 68.84 |
| Toggle | 83.82 | 85.14 | 81.25 | 82.63 |
| FSM | 100.00 | 100.00 | 90.91 | 90.91 |
| Branch | 72.45 | 73.00 | 62.19 | 62.37 |
| Assertion score | 100.00 | 100.00 | 100.00 | 100.00 |

All percentages are the measured `closure.json` DUT fields. Generic/XPM hierarchies differ.
Assertion score is successful-attempt coverage, not a claim of zero assertion
failures: the deliberately illegal frame test produces an expected failure.
The exported assertion inventory also contains unused UVM library assertions;
these are identified separately from DUT assertions.

| Gap / cause | Legal stimulus | Independent checker | Matching-build result |
| --- | --- | --- | --- |
| TID sign bits were not driven through all offset branches. | Signed endpoints and four-word plateaus, unity gain. | Source/metadata monitor and four-plane MATLAB output scoreboard. | All 162 earlier TID bit rows per FIFO have both directions. |
| Interpolation exact occupancy condition was missed by fixed-cycle stalls. | Observe stage1 empty/stage2+output occupied; apply public PA backpressure. | Four-plane scoreboard and held-output monitor. | Generic interpolation line71 operand `1/0` is Covered; XPM retains its existing hit. |
| DPD counter high bits require a longer epoch. | 9,364 AXIS beats produce 16,387 words; random legal PA stalls; after every output is checked, reset through public interfaces. | Four independent MATLAB planes, all sixteen sample/saturation counts, and post-reset zero checks. | All sixteen counters have both directions for bits5:14. Bits31:15 remain unhit and reachable. Reset supplies bit14 falling; a natural bit14 falling transition still requires 32,768 acceptances. |
| Gain saturation was absent because prior gains were 0.75..1. | Signed endpoint payload with legal Q2.14 gains 32767, -32768, 24576 at aligned frame starts. | Independent MATLAB rounding/saturation/TID oracle; 32 beats / 56 output words. | Both frame-gain saturation arms covered; two line bins and two branch arms added per FIFO. |
| Empty core before first frame was never enabled. | Enable core for eighty cycles before sending data, check quiet state, then send complete frame. | No premature underflow/protocol error/PA valid; full independent stream scoreboard afterward. | Generic CDC line190 `0/1/1` changes to Covered. XPM already had that bin. |

`tools/hw/validate_thermo5_coverage_closure.py` independently verifies all
162 TID rows, every counter bit5:14 in all lanes, untouched bit31:15 gaps,
golden output/count/reset markers, and the disappeared gain-saturation gaps.
`closure_validation.json` is PASS.

## Why raw all-DUT 100% cannot be delivered for this frozen SKU

Two-tap interpolation cannot execute three/four-tap implementations. One-tap
external DPD cannot execute internal-input/delayed-tap/unused pair1 paths.
Identity coefficients cannot exercise positive/negative DPD saturation.
Legal fixed parameters cannot execute parameter-error code. The non-low-power
SKU cannot drive `core_drain=1` or `HOLD_STATE_ON_DISABLE=1`. Constant coefficient
ports cannot toggle. Vendor XPM coverage additionally includes configuration
error checks, macro branches and unused optional memory behavior.

The complete raw project denominator is exported under
`denominator/{generic,xpm}/`: `denominators.csv`, `line_gaps.csv`,
`branch_arms.csv`, `fsm_denominators.csv`, `assertions.csv`, `summary.json`.
URG's single-instance shared sections, modules without condition coverage,
macro-expanded dotted lines and split source pages are included. Line and
branch gap details reconcile with their raw counts. The generic totals
reproduce the DUT metric percentages; no denominator is reduced.

Generic still has 378 missing line bins and 98 missing branch arms. XPM
has the same 378 project line bins / 98 project branch arms, plus 566 vendor
line bins / 322 vendor branch arms. Three vendor FSM transitions remain
missing. These totals are not a count of bugs: many are fixed-configuration
or unreachable protection paths. Vendor dispositions remain OPEN pending
per-bin review. A disposition table is not 100% code coverage.

Counter bits31:15 are reachable. The top bit needs at least 2^31 accepted
samples for its first rise, and 2^32 for a natural fall; forcing state,
shrinking the production counter or excluding a reachable bin is not used.
Formal transition proofs do not manufacture simulation toggle hits.

An exclusion-adjusted reachable-RTL target can be defined only with explicit
scope, precise bin identifiers, source hashes, proof/parameter evidence and
a reviewed exclusion ledger. It is a different metric and has not been
claimed or generated as 100%. A reusable-IP configuration matrix would
exercise alternative taps/coefficient modes separately; its databases must
not be represented as this frozen SKU's matching-build merge.

## Formal evidence and limits

`runs/thermo5_coverage100_formal_external_20261006/formal_summary.json` is
PASS: original reset and finite-budget counter jobs plus an unbounded
production-width counter job. The latter proves 35 assertions (ghost count
equality, increment, hold and all 32 bit/carry relations), all 35 vacuity
checks non-vacuous, four covers covered and zero black boxes. It uses the
production external-tap setting and has no acceptance budget.
The later repeat at `runs/thermo5_coverage100_formal_signoff_20261006/`
also passes the reset, budget and unbounded-counter gates.

An additional arithmetic/residual experiment is retained under
`runs/thermo5_coverage100_formal_full_20261006/`. Identity latency is proven
and all four endpoint/stall covers hit, but four arithmetic assertions are
inconclusive under the configured time limit; this job is not PASS and
does not replace the earlier exhaustive identity simulation evidence.
The initial generic CDC residual experiment has three proven invariants,
six/nine covers and inconclusive cover/vacuity checks; its strict gate fails.
The completed follow-up at `runs/thermo5_coverage100_residual_exact_20261006/`
is **PASS**: construct a registered legal AXIS source instead of assuming
465-bit payload stability, assert its stability, and use exact integral 7:4
clock periods scaled from 125/218.75 MHz. Four assertions prove, all nine
covers hit, stability is non-vacuous, selected setup checks are zero and
black boxes are zero. Thus the generic production residual default arm is
unreachable in this modeled reset/clock/interface environment. Raw URG
default-arm bins remain red; no exclusion is applied. The rounding to
4.572 ns in the earlier model created an expensive time grid; the exact
ratio repeat completed in 47.93 seconds. The proof does not establish
vendor-XPM internal behavior, metastability, or analog reset timing.
The intermediate rounded-clock registered-source run at
`runs/thermo5_coverage100_formal_driver_20261006/` was interrupted after its
exact-ratio replacement passed; no completed summary or PASS is claimed.

## Reproduce without a board

Generate independent vectors on the MATLAB workstation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dv/uvm/sim/generate_thermo5_sku_vectors.ps1 -Profile range_stress -Words 16387 -Seed 610081 -OutDir runs/coverage_vectors/range_long
powershell -NoProfile -ExecutionPolicy Bypass -File dv/uvm/sim/generate_thermo5_sku_vectors.ps1 -Profile extreme -SaturatingGain -Words 56 -Seed 610082 -OutDir runs/coverage_vectors/gain_saturation
```

Run a new same-build closure from the licensed Rocky environment:

```bash
python3.12 dv/uvm/sim/run_thermo5_gap_closure.py \
  --xpm-root /path/to/Vivado/2024.1 \
  --range-vectors runs/coverage_vectors/range_long --range-words 16387 \
  --gain-vectors runs/coverage_vectors/gain_saturation \
  --out-dir runs/coverage_review
python3.12 tools/hw/validate_thermo5_coverage_closure.py runs/coverage_review
python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --unbounded-counter --residual-only --out-dir runs/formal_review
```

The Windows package launcher accepts `-RangeWords`, `-GainVectors` and
`-UnboundedCounter`; its command planning is validated with `-DryRun`.
The complete extended package was not executed as a single job this time:
coverage and formal were executed separately; two bug reproductions retain
their earlier VCS/XSim evidence. GitHub CI was not executed.

MATLAB P0 required check `scripts/run_matlab_p0_bittrue_check.cmd` passed
seven designs x 65,536 samples, zero mismatches. No canonical RTL was edited
in this follow-up; no new XSim P0/IP smoke execution is claimed.

## Graduate recruitment priorities without hardware

For DV, complete per-bin coverage dispositions, protocol/reset assertions,
independent scoreboard negative controls, two historical bug walkthroughs,
and clean reproducible licensed CI with actual run evidence. Next useful
work is a frozen-top SpyGlass warning/error review and remaining vendor FIFO
states; a compiler-lint pass is not SpyGlass signoff.

For RTL/design roles, a mapped ASIC synthesis/constraint/timing report,
RTL-to-netlist equivalence and a defensible area/throughput/latency tradeoff
study are valuable board-free work. TSMC28 runs remain unfinished until
mapped reports and netlists exist. Graduate recruiting does not require a
board demonstration or raw 100%, but every resume claim must be defensible.

Actual board clocks, parent I/O budgets, GT CDC-11 review, RX recovery and
physical output retain their existing OPEN status. Ideal-clock/OOC simulation
does not close missing hardware provenance or physical measurements.
