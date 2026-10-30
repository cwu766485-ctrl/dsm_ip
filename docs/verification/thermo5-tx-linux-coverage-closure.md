# Thermo5 TX Linux Coverage Closure — Tasks 4–6 Update

**Date:** 2026-10-30 14:18 SGT
**Disposition:** `TASK4_PARTIAL; TASK5_PARTIAL; RAW_100_OPEN; LINUX_SIGNOFF_OPEN`
**Current product VCS source SHA:** `c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b` (tree `694457bbacf2eda2a061da910f404975fd75ec8d`)
**Formal follow-up SHA:** `23214fbe4b7a06bcf489e39ec9110d76885eda9e` (tree `498d78da91ce2bc48e29f3c28e1a8c4d52a19efd`; clean Formal run)
**Latest exact-parameter Formal SHA:** `36d88f41de20202bd42d98fa9b510cb8dc1bf0f7` (tree `a0219fd779c20b7b85ecaaf3a2275567a0cf65de`; clean AXI-Lite `MAX_TAPS=1` check)
**Product simulation-source SHA:** `913be930bfcbbad0f78dbc90e06299db3d1bb337` (the refreshed VCS filelist excludes the Formal-only harness update)
**Stack base:** PR #6 head `006d52deaaf8ef3980461a6d4efdf1d2c0aa7011`
**Machine-readable evidence:** [`thermo5-tx-linux-coverage-closure-evidence.json`](thermo5-tx-linux-coverage-closure-evidence.json)

**License-restored continuation:** The first boundary-phase attempt and fresh
CDC Formal rerun below were blocked by the license service. After license
checkout recovered, the boundary tests and fresh CDC proof completed. This
continuation supersedes those blocked-status statements for current signoff;
the failed attempts remain in the run history for traceability.

This is the Task 4–6 follow-up to the product denominator, waiver ledger, and
coverage gate established in PR #6. Earlier PASS evidence is retained; the
full Gate 0–3 regressions were not rerun. The tested GT-parent TX product
configuration is centered-cubic interpolation, EF2 ORDER=2, STEP=5120,
`DPD_MAX_TAPS=1`, identity DPD, and Generic FIFO as the Linux substitute for
XPM. Coverage remains restricted to the elaborated DUT main chain. RX,
AI-DPD, frozen TX algorithms, and physical FPGA implementation were not
changed or started.

**License-restored continuation at source SHA `c1fa9f3`:** VCS recompiled the
product configuration (20 modules) and the positive Raw URG merge was refreshed
with 29 product-scoped simulation VDBs plus the current product compile VDB.
Three targeted two-frame source-gap runs (2, 4, and 8 source-clock cycles)
passed the independent four-plane checker with zero UVM errors/fatals and
`early_underflow=0`; the 16-cycle point failed the stream-contract checker with
54 underflow events despite producing all 112 expected words and observing both
TLASTs. The failing VDB is excluded from the positive merge. The sampled points
do not establish an exact starvation threshold. Coverage numerators and
denominators did not change. A new AXI-Lite read-default VC Formal proof under
the exact `MAX_TAPS=1` product setting proves the mapped decoder default arm
unreachable (4/4 assertions and 1/1 cover; target non-vacuous); its Raw branch
bin remains present and no waiver was added. Identity-DPD Formal with helper
constraints remains inconclusive (1/13 assertions proven, 12/13 inconclusive).

## Task 4 — product coverage convergence

### AXI-Lite and CDC FSM transitions

Added `thermo5_sku_axil_reset_sweep_test`, which uses legal public AXI-Lite
RUN writes and the public reset BFM. Five legal 24-beat prefixes target
nonzero 14:8 residual counts 2, 4, 6, 10, and 12; each is reset and checked
for clearing. A final 56-word four-plane identity replay runs after reset and
is independently checked by the existing scoreboard. There are no RTL
forces. VCS reports five nonzero-residual resets, five reset reassertions,
89 PA words across the sweep and replay, zero underflow/protocol error, and
zero UVM warning/error/fatal.

The product FSM inventory is now fully hit:

| FSM | States | Transitions |
| --- | ---: | ---: |
| Centered interpolation stage 1 `q_count` | 3/3 | 5/5 |
| Centered interpolation stage 2 `q_count` | 3/3 | 5/5 |
| Generic FIFO CDC `rem_count_q` | 7/7 | 12/12 |
| **Total** | **13/13** | **22/22** |

The reset sweep specifically closes the five previously unhit CDC reset
transitions. The remaining seven CDC transitions were hit by the selected
legal product traffic. A separate legal one-tap coefficient-transport test
also passed a 56-word four-plane replay; nonzero values in inactive
coefficient banks do not change the active one-tap identity product image.
That run increased raw toggle hits without changing any denominator.

### Latest raw product DUT code coverage

The latest authoritative merge contains **29 scoped product simulation VDBs
plus the product compile VDB**. It includes the established product tests, seeds
610806–610821, a zero-gap continuous two-frame identity run (610823), the
inter-frame-gap run (610824), and the properly hierarchy-scoped 64-cycle
all-plane PA backpressure run (610825).
Candidate PAIR_LOOKAHEAD/nonidentity DPD and expected-negative/mutation VDBs
remain separate. The older 610822 PA-stall VDB was compiled without the product
hierarchy filter and is intentionally excluded; its scoped replacement is
610825.

| Metric | Covered / total | Open | Raw coverage |
| --- | ---: | ---: | ---: |
| URG aggregate | — | — | 81.99% |
| Line | 3,190 / 3,796 | 606 | 84.0358% |
| Condition | 583 / 846 | 263 | 68.9125% |
| Branch | 440 / 637 | 197 | 69.0738% |
| Toggle, both directions | 86,951 / 104,478 | 17,527 | 83.2242% |
| FSM states | 13 / 13 | 0 | 100.0000% |
| FSM transitions | 22 / 22 | 0 | 100.0000% |
| DUT assertions attempted | 13 / 15 | 2 additionally unhit | 86.6667% |

The seed-610823 zero-gap test sends two legal 32-beat frames in one RUN epoch.
The independent checker matched all 112 words on all four planes, accepted two
TLASTs and checked 114 one-tap DPD samples per lane with no saturation. UVM
warning/error/fatal counts were zero and `early_underflow=0`; the direct Generic
wrapper reports 71 post-source finite-tail diagnostic cycles. Its correctly
scoped VDB added no code or functional bins.

The seed-610824 test sends two legal 32-beat frames in one RUN epoch, with one
source-clock bubble before beat 32. The independent checker matched all 112
words on all four planes, accepted two TLASTs, observed two frame starts, and
checked 114 one-tap DPD samples per lane with no DPD saturation. UVM warning,
error, and fatal counts were zero; `early_underflow=0`. The direct Generic
wrapper still reports 71 post-source finite-tail underflow diagnostic cycles,
which are not hidden or counted as early underflow.

The seed-610825 test held all four PA ready signals low for 64 requested core
cycles. It then checked a 56-word four-plane identity replay; the monitor
observed 65 PA stall cycles, including pipeline interaction. UVM warning,
error, and fatal counts were zero and `early_underflow=0`; the direct Generic
wrapper reported 70 post-source finite-tail diagnostic cycles. This scoped VDB
added no Raw line, condition, branch, toggle, FSM, or functional bins.

The inter-frame-gap VDB exposed one additional legal centered-interpolator
frame-tail condition combination at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:309`: condition coverage
rose from 582/846 to 583/846. The scoped PA-stall VDB did not change the
counters. Denominators and
waivers are unchanged: Raw equals Adjusted, waiver count is zero, and no
Exclusion was applied. The freshly regenerated source-linked Raw gap ledger
contains 18,593 open/review records: 9,513 configuration review, 3,787 open
stimulus/checker review, 141 formal-mapping review, 4,512 arithmetic review,
and 640 counter/formal review. These are not approved waivers.

The license-restored source-gap sweep compiled the current product testbench
and ran the same two-frame, four-plane identity checker at 2/4/8/16 source
clock cycles of gap before frame 2. Seeds 610834, 610835, and 610836 passed
with 112/112 output words, 2/2 TLASTs, zero protocol errors, zero early
underflow, and zero UVM warning/error/fatal. Seed 610837 at gap 16 failed the
stream-contract assertion: 64/64 inputs, 2/2 TLASTs, 2/2 frames, and 112/112
outputs were observed, but the monitor counted 54 underflow events. The VCS
process exit was 0 because UVM terminates with `$finish`; the checked UVM_FATAL
means the test result is FAIL. That VDB was not merged. These four points do
not establish the exact starvation boundary, and none changed coverage bins.

The branch inventory still has 37 `OPEN_PROJECT_BIN_REVIEW` rows. A new exact
VC Formal property proves the AXI-Lite write-case `default` arm at
`thermo5_dpd_axi_lite_cfg.sv:282` unreachable for the legal product register
map; this is review evidence only. The raw branch bin remains in the 637-bin
denominator until a separate waiver review approves any disposition. The
current hierarchy manifest, command, Raw/Adjusted gate JSON, full URG report,
and regenerated ledger paths and hashes are indexed in the machine evidence.

### Fixed-parameter EF2 branch audit

The current product instantiates four EF2 planes through
`tid32_thermo5_fs4_multipa_tx.sv:80-85`. That wrapper passes `W` and `CHANNELS`
to `tid32_cartesian_ef2_fs4_gt_tx`, but not `PAIR_LOOKAHEAD`; the module
default at `tid32_cartesian_ef2_fs4_gt_tx.sv:20` is `1'b0`. Therefore the
`if (PAIR_LOOKAHEAD)` true arm at line 231 is structurally inactive for this
GT-parent product. The exact Raw ledger retains one unhit `231:1` branch bin
in each `g_branch[0..3].g_order2.u_tid` instance as
`OPEN_CONFIGURATION_REVIEW`. Candidate PAIR_LOOKAHEAD runs remain separate;
the exact-parameter VC Formal harness now also elaborates `W=16`,
`CHANNELS=32` with the module-default `PAIR_LOOKAHEAD=0`: 2/2 parameter
assertions are proven and both the enabled look-ahead cover and
invalid-parameter guard cover are `uncoverable`, with zero black boxes and
zero setup violations. This is static-parameter reachability evidence; it
does not hit or waive the four Raw bins, which remain in the denominator.

### Functional coverage and applicability

The unchanged raw URG functional report remains **97.97%** across 8 groups:
`source_cg` 96.30%, `core_cg` 87.50%, and the other six groups 100%.
The complete URG pages contain 214 denominator-eligible bin records across
covergroup-type and monitor-instance views: 210 hit and four are unhit. The
earlier 170/174 report tally omitted 40 generated EF2 cross-bin records (20
per view); this is an accounting correction from the unchanged Raw report,
not a change to the coverage database or denominator. The 97.97% figure is
the unweighted average of the eight URG group scores, not the aggregate bin
ratio.

| Functional group | Covered / expected bins | URG group score |
| --- | ---: | ---: |
| `stop_restart_cg` | 12 / 12 | 100.00% |
| `ef2_cg` | 68 / 68 | 100.00% |
| `plane_atomic_cg` | 16 / 16 | 100.00% |
| AXI-Lite `read_cg` | 22 / 22 | 100.00% |
| AXI-Lite `write_cg` | 36 / 36 | 100.00% |
| AXI-Lite `reset_cg` | 4 / 4 | 100.00% |
| `source_cg` | 38 / 40 | 96.30% |
| `core_cg` | 14 / 16 | 87.50% |
| **Total scoreable bin records** | **210 / 214** | **97.97% group average** |

The complete bin-level export has 226 rows: the 214 scoreable records above
and 12 bins that the existing URG model already labels Illegal/Excluded.
Those model-defined records remain visible in the [full functional bin CSV](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-detail.csv);
they are not newly waived or excluded. That export records both report views,
all coverpoints and generated crosses, each count/status, and the source-page
SHA. The separate [negative-only audit](data/thermo5-tx-coverage-root-cause/thermo5-tx-functional-bin-audit.csv)
contains the expected illegal-frame hits.

The positive-only report leaves two negative-only bins open:

| Group/bin | Positive legal product report | Separate negative report |
| --- | ---: | ---: |
| `source_cg.cp_packet_quanta.malformed_early` | 0 | 1 hit |
| `core_cg.cp_illegal.bad_frame` | 0 | 49 hits |

All 210 legally applicable positive scoreable records are hit by the legal
product tests. The two bins above describe deliberately malformed framing and
are exercised only in the separately reported illegal test. This applicability
annotation does not edit URG bins or its denominator: the eight-group URG
score remains 97.97%, and the machine gate continues to return
`RAW_100_OPEN`.

## Task 5 — assertions, formal evidence, and mutation

### Legal and expected-negative assertion reports

The legal product Raw URG report contains 13 DUT assertion `SUCCESS`, 2
`UNCOVERED`, 2 `WITHOUT_ATTEMPTS`, and 0 `FAILURE` records. The attempted
assertion score is 13/15 = 86.67%; without-attempt records remain separately
visible. The two legal-run uncovered assertions are not presented as PASS.
Across all 17 DUT assertion records, 13 are successful and 4 are unhit (2
uncovered and 2 without attempts); the 13/15 attempted score excludes only
the two without-attempt records and does not hide the uncovered assertions.

The AXI-Lite illegal-frame test ran in its own VDB and own URG report. It
observed the expected assertion at
`rtl/axis/dsm_axis14_to_core8_cdc.sv:257` for an intentionally misaligned
`frame_start`, and at
`rtl/interp/dsm_interp_x2_centered_cubic_vector.sv:310` for intentionally
placing same-frame data after a frame-tail vector. Both assertions fail once
in this negative run as intended; the UVM test checks both messages, checks
the sticky error, resets through the public interface, and finishes with zero
UVM warning/error/fatal. These two expected failures remain in the negative
report and are not merged into legal product coverage.

A separate mailbox-corruption negative test (seed 420103) deliberately forces
the pending AXI-Lite mailbox bundle to change before acknowledgement. VCS
observed the expected `$error` at `thermo5_dpd_axi_lite_cfg.sv:365`; the UVM
test checked the message, released the force, reasserted public reset, and
passed with zero UVM warnings/errors/fatals. Its VDB is included only in a
separate expected-negative URG report alongside the illegal-frame VDB. The
combined report contains two test VDBs; mailbox `$error` is not counted as an
SVA failure. Neither negative VDB is merged into positive product Raw.

### Formal and reachability

- **AXI-Lite default reachability: PASS for the exact `MAX_TAPS=1` product
  configuration.** The latest VC Formal run proved 4/4 assertions, including
  non-vacuous `a_write_case_default_unreachable` at
  `thermo5_dpd_axi_lite_cfg.sv:282` and
  `a_coeff_read_default_unreachable` at the coefficient decoder/default
  (`:135/:142`); the legal coefficient-read cover hit (1/1). The earlier
  3/3 write-default run is retained as historical evidence. Setup checks report
  zero clock, glitch, oscillating/combinational-loop, or multidriver violations;
  two reset assumptions are vacuous. This is exact-configuration reachability
  evidence only: Raw branch bins remain in the denominator, with no waiver or
  exclusion.
- **EF2 safety: PASS.** The fresh VC Formal property report has 6/6 proven
  assertions and 3/3 covered properties, zero black boxes, and four
  non-vacuous properties. Scope is the 32-lane signed-16 production EF2
  recurrence with arbitrary input/ready sequences: widened no-wrap and
  inductive bounds, state update/hold, output capture, and output hold under
  stall. This is not an end-to-end BER proof or formal equivalence to the
  Python oracle.
- **Generic FIFO CDC: fresh PASS.** After license recovery, the exact 7:4
  scaled-clock proof completed with 7/7 assertions proven, 9/9 covers hit,
  zero black boxes, and 56.67 seconds runtime. Current simulation also hits
  every product `rem_count_q` state/transition. The proof does not transfer
  to XPM.
- **DPD identity arithmetic: OPEN.** The initial license-restored run and a
  second extended run both report 1/5 assertions proven (`a_valid_latency`),
  4/5 inconclusive (`a_identity_payload`, both no-saturation assertions,
  and saturation count), 4/4 covers hit, and zero black boxes. The extended
  run raised the per-property limit to 2 minutes and max effort to 6 minutes;
  it ended at the maximum-effort limit after 367.39 seconds with the same
  four properties inconclusive and no counterexample. This does not prove
  identity payload or absence of saturation. No DPD bins are waived.
  A subsequent bounded helper-constraint attempt completed in 131.33 seconds:
  1/13 assertions proven (`a_valid_latency`), 12/13 inconclusive, 4/4 covers
  hit, zero black boxes. Five non-vacuous helper constraints were activated,
  but identity payload and no-saturation assertions remained inconclusive. No
  RTL or formal harness was changed in that attempt.
- **Centered frame tail: scoped parameter reachability PASS.** A new
  VC Formal harness uses the production stage parameters (`W=16`, `LANES=8`)
  and the frontend's `APPEND_TAIL_VECTOR=1` / `0` split at
  `tid32_thermo5_frontend_tx.sv:102` / `:178`. It proves 3/3
  assertions, covers the legal frame-end and appended-tail transfer at the
  enabled parameter, and marks the disabled parameter's tail cover
  `uncoverable`; zero black boxes and setup violations. The harness is
  module-level and does not prove end-to-end composition between the two
  cascaded stages. This is reachability evidence only: Raw bins remain in the
  denominator, no waiver is applied, and URG counts do not change.
- **EF2 product parameters: scoped reachability PASS.** At clean source
  `f6956b9342add9af86c8977999c517283232275e`, the production EF2 module was
  elaborated at `W=16`, `CHANNELS=32` without overriding `PAIR_LOOKAHEAD`.
  VC Formal proved 2/2 static parameter assertions and returned `uncoverable`
  for both the `PAIR_LOOKAHEAD=1` arm and invalid-parameter guard cover; zero
  black boxes and zero setup violations. These are elaboration-constant checks,
  not temporal proofs. Raw branch bins remain in the denominator and no
  waiver is applied.
- **AXI-Lite `MAX_TAPS` guard: static product-parameter check PASS.** At clean
  Formal source `36d88f41de20202bd42d98fa9b510cb8dc1bf0f7`, the production
  config harness elaborates `MAX_TAPS=1`. VC Formal reports 5/5 assertions
  proven; the new `a_product_max_taps_guard_inactive` is a constant/tautology,
  and its invalid-parameter cover is expected `uncoverable`. The legal
  coefficient-read cover is hit; there are zero black boxes and setup
  violations. This is a static elaboration check, not a temporal proof. The
  `thermo5_dpd_axi_lite_cfg.sv:348` Raw branch remains counted and unwaived.
- **PAIR_LOOKAHEAD and nonidentity 2/4-tap DPD:** candidate-only. Their prior
  A/B/formal evidence remains separate; none is counted in the product Raw
  denominator.

The latest commands, logs, source manifest, property/setup reports, and hashes
for the EF2 and AXI-Lite parameter checks and mailbox expected-negative test
are indexed in `thermo5-tx-linux-coverage-closure-evidence.json`. These checks
did not change the product Raw VDB set, so Raw DUT and functional coverage
remain the 81.99% / 170-of-174 figures above; no coverage waiver or exclusion
was added.

### Checker mutation

The product AXI-Lite identity test was rerun with bit 0 flipped in expected
PA0 word 0 (`33BB39BF8B9F88C8` → `33BB39BF8B9F88C9`). The independent
four-plane scoreboard reported the one-LSB mismatch at epoch 0 / word 0 /
plane 0 and raised one `UVM_FATAL`. The VCS process returns 0 because UVM
calls `$finish`; the checked `[BITTRUE]` marker and fatal count are the
mutation oracle. This is `PASS_MUTATION_CAUGHT`, not a legal test PASS, and
its VDB is not merged into product coverage.

## Task 6 — Linux-only signoff status

The existing held-out Python worst-case model result is retained without a
rerun: at RMS 0.10, STEP 5120, 20-bit state, no backoff/clipping, the selected
finite model set reports digital BER 21/224,256 = 9.3643e-5 and EVM 2.4640%.
The behavioral nominal/stress BERs are 1.4269e-4 / 7.7144e-4. Because the
project still has no product BER/BLER acceptance target or calibrated RF
model, the benchmark disposition is `MODEL_SCREEN_PASS;
COMMUNICATION_ACCEPTANCE_UNDEFINED`, not a QAM256 link signoff.

The automatic coverage gate reports `RAW_100_OPEN`; there are zero approved
waivers and zero active exclusions, so adjusted coverage is exactly raw. The
code coverage target is not closed. Linux cannot close actual XPM or GT Wizard
simulation, FPGA PPA/routed timing, or physical QAM256 BER here; all remain
open and are not claimed as PASS.

## Commands and evidence

The initial VCS reset-sweep and coefficient-transport checkpoint used VCS
V-2023.12-SP1, EF2 ORDER=2, STEP=5120, centered-cubic, one DPD tap, and
`thermo5_tx_product_coverage.hier`; its historical URG checkpoint used seven
positive product VDBs. The current 29-simulation-VDB product merge is listed
below. The illegal-frame test and PA0 mutation use separate VDBs/reports.
Exact commands, SHA-256 hashes, coverage numerators and denominators, and
tool/run directories are recorded in the adjacent machine evidence file.
Large VDBs, generated HTML, logs, vectors, and formal workdirs remain ignored
under `runs/`.

Latest license-restored evidence (current tested source SHA
`c1fa9f3e7ca5ac4756f7da3245b71727ac71bb4b`):

- Two-frame inter-frame-gap VCS command and full compile/run logs:
  `runs/thermo5_tx_product_interframe_gap_scoped_20261030/commands.txt`.
- Zero-gap continuous two-frame VCS command/log:
  `runs/thermo5_tx_product_continuous_scoped_20261030/commands.txt`.
- Correctly scoped PA-stall VCS command/log:
  `runs/thermo5_tx_product_pa_stall_scoped_20261030/commands.txt`.
- Latest 29-VDB URG merge command and report:
  `runs/thermo5_tx_product_axil_reset_cov_20261030/urg_product_raw_after_source_gap_current_20261030.command.txt`
  and `.../product_raw_after_source_gap_current_20261030/`.
- Latest Raw/Adjusted gate: `.../coverage_gate_after_source_gap_current_20261030.json`;
  source-linked ledger: `.../gap_ledger_after_source_gap_current_20261030/`.
- Product VCS compile and source-gap results:
  `runs/thermo5_tx_product_current_compile_20261030/compile.log` and
  `runs/thermo5_tx_product_source_gap_current_20261030/results.json`.
- Exact product AXI-Lite read-default proof:
  `runs/thermo5_tx_product_formal_axil_read_default_20261030/`.
- Identity-DPD helper-constraint Formal attempt:
  `runs/thermo5_tx_product_formal_identity_lemmas_retry2_20261030/`.
- Frame-tail parameter reachability Formal at the clean follow-up SHA:
  `runs/thermo5_tx_frame_tail_formal_clean_20261030/`.
- Earlier AXI-Lite write-case default proof (3/3 assertions) and current exact
  product configuration proof (4/4 assertions, 1/1 cover; both default targets
  non-vacuous; zero setup violations):
  `runs/thermo5_tx_product_formal_case_default_20261030/axil_cfg/` and
  `runs/thermo5_tx_product_formal_axil_read_default_20261030/axil_cfg/`.


Key reproduction commands (run from the repository root):

```bash
make -C dv/uvm/sim thermo5-tx-product-axil-reset-sweep \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_product_axil_reset_cov_20261030" \
  THERMO5_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_tx_product_coverage.hier" \
  THERMO5_DPD_MAX_TAPS=1

make -C dv/uvm/sim thermo5-tx-product-axil-coeff-transport \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 PYTHON=python3.12 \
  THERMO5_OUT="$PWD/runs/thermo5_tx_product_coeff_target_20261030" \
  THERMO5_VECTORS="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_tx_product_coverage.hier" \
  THERMO5_DPD_MAX_TAPS=1

PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH \
  python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py \
  --jobs ef2 identity cdc_residual \
  --out-dir runs/thermo5_tx_product_formal_20261030
```

The extended identity-only attempt changed only the temporary Tcl effort
limits (per-property 2 minutes, total 6 minutes); the original RTL and formal
harness were unchanged:

```bash
repo_dir=$PWD
run_dir="$repo_dir/runs/thermo5_tx_product_formal_identity_extended_20261030"
cd "$run_dir"
env THERMO5_FORMAL_TOP=thermo5_identity_harness \
  THERMO5_FORMAL_OUT="$run_dir/identity" \
  THERMO5_FORMAL_REPO="$repo_dir" \
  PATH="/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH" \
  /opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf -batch -fmode FPV \
  -f "$run_dir/run_thermo5_gap_fpv_extended.tcl" \
  > "$run_dir/manual_console.log" 2>&1
```

Both Make targets passed. The combined formal command proved EF2 before the
identity job exceeded its bounded run; that combined command is not a full
formal PASS. The fresh CDC proof is separately recorded as PASS above. The
license-restored identity-only retry completed but remained inconclusive as
reported above; the generated summary is the source of the counts.

The follow-up with the longer effort budget used a retained Tcl snapshot and
completed at its 6-minute maximum-effort limit. Its exact property report and
machine summary are under
`runs/thermo5_tx_product_formal_identity_extended_20261030/`; it did not
change the identity proof disposition.

The coefficient-transport VDB included in the seven-VDB merge was produced by
the same product-configured simulator executable with this invocation:

```bash
runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
  +UVM_TESTNAME=thermo5_sku_axil_coeff_transport_test \
  +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  +ntb_random_seed=610803 -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir runs/thermo5_tx_product_axil_reset_cov_20261030/cov_thermo5_sku_axil_coeff_transport_test_seed610803.vdb \
  +CORE_WORDS=56 \
  -l runs/thermo5_tx_product_axil_reset_cov_20261030/thermo5_sku_axil_coeff_transport_test_seed610803.log
```

The license-restored boundary-phase family used the same product-configured
simulator executable, with seeds 610806–610821 and per-run options captured
under `runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/`.
The prior boundary-phase checkpoint's URG command and 23 simulation VDB paths
are preserved in
`runs/thermo5_tx_product_axil_reset_cov_20261030/urg_product_raw_after_run_sweep_20261030.command.txt`;
its historical results are in the adjacent `.log` file. The latest command
uses the inter-frame-gap and properly scoped PA-stall VDBs and is linked above.
The following loops reproduce the license-restored legal runs. Each invocation
has its own seed, log, and VDB; the VCS executable and vectors come from the
product-configured run described above.

```bash
for spec in '1 610807' '2 610808' '4 610809' '8 610810' '16 610811' '32 610812'; do
  set -- $spec
  offset=$1
  seed=$2
  case_dir="runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/offset${offset}_seed${seed}"
  mkdir -p "$case_dir"
  runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
    +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
    +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
    +ntb_random_seed="$seed" -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir "$case_dir/cov.vdb" +CORE_WORDS=56 \
    +AXIL_BOUNDARY_OFFSET="$offset" -l "$case_dir/sim.log" \
    > "$case_dir/console.log" 2>&1
done
```

```bash
case_dir=runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/commit_on_run_seed610813
mkdir -p "$case_dir"
runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
  +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
  +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  +ntb_random_seed=610813 -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir "$case_dir/cov.vdb" +CORE_WORDS=56 \
  +AXIL_COMMIT_ON_RUN +AXIL_BOUNDARY_AW_GAP=3 +AXIL_BOUNDARY_W_GAP=1 \
  +AXIL_EARLY_BREADY -l "$case_dir/sim.log" > "$case_dir/console.log" 2>&1
```

```bash
for spec in '8 610814' '20 610815'; do
  set -- $spec
  gap_beat=$1
  seed=$2
  case_dir="runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/source_gap_beat${gap_beat}_seed${seed}"
  mkdir -p "$case_dir"
  runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
    +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
    +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
    +ntb_random_seed="$seed" -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir "$case_dir/cov.vdb" +CORE_WORDS=56 \
    +AXIL_BOUNDARY_GAP_BEAT="$gap_beat" +AXIL_BOUNDARY_GAP_CYCLES=4 \
    -l "$case_dir/sim.log" > "$case_dir/console.log" 2>&1
done
```

The six RUN-relative COMMIT-delay invocations use the following exact
parameter sweep (each pair maps to its own seed, log, and VDB):

```bash
for spec in '0 610816' '1 610817' '2 610818' '4 610819' '8 610820' '16 610821'; do
  set -- $spec
  delay=$1
  seed=$2
  case_dir="runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/run_after_run_sweep/delay${delay}_seed${seed}"
  mkdir -p "$case_dir"
  runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
    +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
    +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
    +ntb_random_seed="$seed" -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir "$case_dir/cov.vdb" +CORE_WORDS=56 \
    +AXIL_COMMIT_AFTER_RUN_CORE_CYCLES="$delay" -l "$case_dir/sim.log"
done
```

The first seed-610806 invocation was blocked before UVM and is retained as a
failed attempt. Its license-restored retry passed:

```bash
case_dir=runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/license_retry_seed610806
runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
  +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
  +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  +ntb_random_seed=610806 -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir "$case_dir/cov.vdb" +CORE_WORDS=56 +AXIL_BOUNDARY_OFFSET=0 \
  -l "$case_dir/sim.log" > "$case_dir/console.log" 2>&1
```

The original blocked attempt's command is retained below for traceability:

```bash
runs/thermo5_tx_product_axil_reset_cov_20261030/simv \
  +UVM_TESTNAME=thermo5_sku_axil_boundary_phase_test \
  +VEC_DIR="$PWD/runs/thermo5_tx_linux_closure_wip/corners/regression_vectors" \
  +ntb_random_seed=610806 -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/cov.vdb \
  +CORE_WORDS=56 +AXIL_BOUNDARY_OFFSET=0 \
  -l runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/sim_retry.log
```

The console license failure and exit status for the first attempt are retained
in `runs/thermo5_tx_product_axil_reset_cov_20261030/boundary_phase/attempt_result.txt`.

**Acceptance:** Task 4 closed the previously missing product FSM transitions
and improved toggles, while reachable line/branch/condition closure remains
open. Task 5 has legal/negative assertion separation and a caught product
checker mutation; DPD identity formal and end-to-end Frame Tail composition
remain open. The Frame Tail parameter reachability proof passes at module level, but
full cascaded-stage composition remains open. Task 6 is Linux-only partial
signoff: functional applicable bins are covered, but `RAW_100_OPEN` and
`COMMUNICATION_ACCEPTANCE_UNDEFINED` remain.
