# Thermo5 TX System Verification — Phase C Minimum Random Qualification

Date: 2026-11-02 13:01 SGT
Implementation source SHA: `26a9f0482e952f70ed62c438aa9201e626bd103e`
Product RTL baseline: `2d7a58df43f7bffecd3d34edd2f21bb3262abe2b`
Branch: `codex/thermo5-tx-system-random`
Predecessors: PR #27 (Phase A) and PR #28 (Phase B); both remain unmerged.
Review PR: [#29](https://github.com/cwu766485-ctrl/dsm_ip/pull/29), open and
unmerged, stacked on PR #28. At initial publication, its remote commit was
`983c1a4ad217d0abf68b2e14a3ccb2d34f79b0b6`, parented on PR #28 head
`991591dca3bf710405e5cd3a35ea855f23248dfa`; the remote tree matched the
locally reviewed tree.

## Scope and result

This is a minimum runnable Phase C qualification on the Linux Generic FIFO,
AXI-Lite TX product configuration. It adds seeded packet/stream scenarios,
accepted-transaction trace recording, and an independent Python trace replay.
The frozen product RTL and algorithm are unchanged.

Product settings: Centered-Cubic x2+x2, EF2 ORDER=2, STEP=5120, 20-bit state,
four 64-bit PA planes, `DPD_MAX_TAPS=1`, reset-loaded Identity DPD, Generic
FIFO, AXI-Lite control.

| Result | Evidence |
|---|---|
| Overall | PASS, 110/110 UVM seeds and 110/110 trace-oracle replays |
| Regular packet cases | 100 seeds, 56 PA words / one 32-beat packet each; seeds 720000–720099 |
| Long cases | 10 seeds, 112 PA words / two 32-beat packets each; seeds 820000–820009 |
| UVM independent checks | Zero PA bit mismatches, predictor mismatches, protocol errors, underflow, missing/extra transactions, UVM errors, or fatals |
| Python monitor-trace oracle | Exact four-plane output comparison; zero unexpected underflow |
| URG merge | PASS for 110 per-seed VDBs plus the compile/design VDB |
| DUT-only Raw/Adjusted code coverage | NOT RUN; the URG dashboard is mixed hierarchy and is not a product signoff result |
| Formal, mutation, XPM/GT Wizard, Vivado, RF/BER | NOT RUN in this phase |

## Stimulus and observed transactions

The 110 runs use four generated input profiles: random (28 runs), extreme (28),
range-stress (27), and EF2-saturation (27). Frame gains are selected from six
legal Q14 values; range-stress uses unity gain. Each run preloads 16 accepted
source beats with bounded 0–2-cycle valid gaps before issuing RUN. Source data
is continuous after RUN. The PA sink randomizes four-plane ready masks and
stalls. The virtual flow performs RUN, sends complete packet(s), requests STOP,
and polls for drained STATUS.

Aggregate accepted transactions: 3,840 AXIS beats, 120 TLAST events, and 6,720
four-plane PA words. The traces contain 1,100 source beats with a nonzero gap,
1,656 total source-gap cycles, 2,371 PA-stall cycles, and 291 FIFO-full
assertion events. Each run had 16 source beats accepted before RUN.

The trace-derived observation matrix reports 20 distinct labels. These are
run-level observations from accepted traces, not an assertion that all exact
SystemVerilog covergroup crosses are closed:

| Cross / event | Observed | Qualification |
|---|---:|---|
| Identity DPD × gain class × input profile | 10/10 generator-supported tuples | DPD remains Identity in every run; non-Identity coefficients are not randomized |
| Source gap × PA stall class × FIFO-full category | 2/12 run-level tuples | Both observations include a prefill gap, a later FIFO-full event, and either zero-ready or partial-ready stalls; this is not a same-cycle cross |
| STOP × TLAST × drained STATUS | 1/1 | Observed in all 110 runs |
| RUN × 16-beat prefill × source gap | 1/1 | Observed in all 110 runs |
| COMMIT × frame boundary × PA stall | 0/1 | OPEN; COMMIT timing was not randomized |
| Reset × pending COMMIT | 0/1 | OPEN; reset was not randomized |
| STATUS × COMMIT × STOP | 0/1 | OPEN; COMMIT was not randomized |

## URG coverage comparison

URG merged the 110 per-seed VDBs with the current compile/design VDB. Its
reported aggregate includes testbench and mixed hierarchy. A same-source
single-seed view was separately built from the compile/design VDB and the
Phase B replay VDB. The delta is campaign-level exploratory data only; it is
not DUT-only Raw/Adjusted product coverage.

| Metric | One-test baseline | 110-seed aggregate | Delta (percentage points) |
|---|---:|---:|---:|
| Overall score | 61.51% | 68.13% | +6.62 |
| Line | 74.42% | 74.89% | +0.47 |
| Condition | 48.21% | 63.51% | +15.30 |
| Toggle | 74.84% | 75.55% | +0.71 |
| FSM | 68.18% | 68.18% | +0.00 |
| Branch | 43.88% | 48.51% | +4.63 |
| Assertion | 68.42% | 78.95% | +10.53 |
| Functional groups | 52.65% | 67.32% | +14.67 |

These figures do not replace the current DUT-only Raw/Adjusted baseline or
approved waiver ledger. No coverage denominator was changed and no exclusion
was applied.

## Commands and reproducibility

The exact VCS compile command, per-seed commands, seed parameters, accepted
transaction/log hashes, VDB fingerprints, and tool versions are recorded in
the machine-readable evidence files:

- [`thermo5-tx-phase-c-evidence.json`](data/thermo5-tx-phase-c-evidence.json)
- [`thermo5-tx-phase-c-vdb-manifest.json`](data/thermo5-tx-phase-c-vdb-manifest.json)

Full reproduction command:

```bash
python3.12 dv/uvm/sim/run_thermo5_system_random.py \
  --random-seeds 100 --long-seeds 10 --seed-base 720000 \
  --out runs/thermo5_tx_system_random_phase_c
```

Tools: VCS V-2023.12-SP1_Full64, URG V-2023.12-SP1, Synopsys UVM 1.1d,
Python 3.12.13. The retained VCS/URG logs, traces, vectors, VDBs, and reports
are under the ignored `runs/thermo5_tx_system_random_phase_c/` directory.
Evidence JSON records SHA-256 values for the compile log, URG log, dashboard,
summary, all per-seed traces/logs, and the VDB manifest. VDB tree fingerprints
use the repository's sorted relative path / size / file SHA-256 algorithm.

Python reference tests were run with:

```bash
(cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v)
```

Result: 57/57 PASS. JSON parsing, all retained VDB file counts/byte counts/tree
fingerprints, per-seed trace/UVM/oracle log hashes, evidence SHA links, and
`git diff --check` were also checked after the run.

## Remaining work

This result closes only the minimum runnable Phase C milestone. The following
remain OPEN: legal non-Identity 1-Tap DPD coefficient randomization; randomized
COMMIT and reset epochs; exact SV functional crosses and the missing cross bins
above; a complete independent STATUS/commit event matrix; Phase D DUT-only
Raw/Adjusted coverage, Formal reachability and waiver review; and Phase E
Linux benchmark reconciliation. Real XPM, GT Wizard, FPGA PPA, routed timing,
and physical RF/QAM256 performance require separate platform evidence.

No RX, AI-DPD learning, Vivado, product RTL, or frozen TX algorithm was changed.

## Superseding status update — 2026-11-03

The report above is a dated snapshot of the initial Phase C minimum random
campaign. Its then-open DPD, randomized COMMIT/reset, exact functional coverage,
and starvation items have since been exercised in separate campaigns. As of
the update below, 60/60 runtime DPD × gain × profile tuples, 48/48 randomized
reset/COMMIT trials, directed reset/commit and source-gap crosses, and 392/392
legally applicable functional bins pass. The detailed current status, exact
VDB provenance, Raw/Adjusted code coverage, assertion/Formal results, and
remaining open items are in
[`thermo5-tx-linux-system-verification-signoff.md`](thermo5-tx-linux-system-verification-signoff.md)
and
[`thermo5-tx-linux-system-verification-signoff.json`](data/thermo5-tx-linux-system-verification-signoff.json).

The Phase C functional objectives are closed for the declared legal bins.
Overall Linux signoff remains partial because DUT Code Coverage is
`RAW_100_OPEN`, the outstanding-counter and DPD Identity Formal tasks remain
inconclusive, and platform-level XPM/GT Wizard, FPGA PPA, and physical RF/QAM256
evidence has not been run.
