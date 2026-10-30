# Thermo5 TX Linux Coverage Closure — Tasks 4–6 Update

**Date:** 2026-10-30 12:22 SGT
**Disposition:** `TASK4_PARTIAL; TASK5_PARTIAL; RAW_100_OPEN; LINUX_SIGNOFF_OPEN`
**Product source commit tested:** `cab04feb6b41bfc75efd064eb1f13b2a4262c22d`
**Stack base:** PR #6 head `006d52deaaf8ef3980461a6d4efdf1d2c0aa7011`
**Machine-readable evidence:** [`thermo5-tx-linux-coverage-closure-evidence.json`](thermo5-tx-linux-coverage-closure-evidence.json)

This is the Task 4–6 follow-up to the product denominator, waiver ledger, and
coverage gate established in PR #6. Earlier PASS evidence is retained; the
full Gate 0–3 regressions were not rerun. The tested GT-parent TX product
configuration is centered-cubic interpolation, EF2 ORDER=2, STEP=5120,
`DPD_MAX_TAPS=1`, identity DPD, and Generic FIFO as the Linux substitute for
XPM. Coverage remains restricted to the elaborated DUT main chain. RX,
AI-DPD, frozen TX algorithms, and physical FPGA implementation were not
changed or started.

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

Raw URG includes the original five selected legal product tests plus the
reset-sweep and coefficient-transport VDBs. The expected-negative assertion
VDB and checker-mutation VDB are excluded from this merge. No candidate DPD or
PAIR_LOOKAHEAD VDB is included.

| Metric | Covered / total | Open | Raw coverage |
| --- | ---: | ---: | ---: |
| URG aggregate | — | — | 81.95% |
| Line | 3,190 / 3,796 | 606 | 84.0358% |
| Condition | 581 / 846 | 265 | 68.6761% |
| Branch | 440 / 637 | 197 | 69.0738% |
| Toggle, both directions | 86,951 / 104,478 | 17,527 | 83.2242% |
| FSM states | 13 / 13 | 0 | 100.0000% |
| FSM transitions | 22 / 22 | 0 | 100.0000% |

Relative to PR #6's product-only run, the same denominators are retained;
toggle hits increased by 4,032, conditions by 2, and all 7 remaining FSM
transitions were hit. Line and branch counts did not change. The exact
source-linked gap ledger now contains 18,595 open rows: 9,513 configuration
review, 3,789 open stimulus/checker review, 141 formal-mapping review, 4,512
arithmetic review, and 640 counter/formal review. These are review states,
not waivers.

The priority queue is still real: 37 branch arms remain generic project-bin
review, while fixed-parameter error arms, identity/saturation branches, and
the CDC residual default branch remain explicitly open. The coefficient
transport test improved toggle coverage, but did not close the outstanding
line, branch, or condition sets. No bin was removed from the denominator.

### Functional coverage and applicability

The unchanged raw URG functional report remains **97.97%** across 8 groups:
`source_cg` 96.30%, `core_cg` 87.50%, and the other six groups 100%.
URG reports 170/174 expected bins hit across these groups (the reported
97.97% is the unweighted average of the eight group scores, not the aggregate
bin ratio):

| Functional group | Covered / expected bins | URG group score |
| --- | ---: | ---: |
| `stop_restart_cg` | 12 / 12 | 100.00% |
| `ef2_cg` | 28 / 28 | 100.00% |
| `plane_atomic_cg` | 16 / 16 | 100.00% |
| AXI-Lite `read_cg` | 22 / 22 | 100.00% |
| AXI-Lite `write_cg` | 36 / 36 | 100.00% |
| AXI-Lite `reset_cg` | 4 / 4 | 100.00% |
| `source_cg` | 38 / 40 | 96.30% |
| `core_cg` | 14 / 16 | 87.50% |
| **Total bins** | **170 / 174** | **97.97% group average** |

The positive-only report leaves two negative-only bins open:

| Group/bin | Positive legal product report | Separate negative report |
| --- | ---: | ---: |
| `source_cg.cp_packet_quanta.malformed_early` | 0 | 1 hit |
| `core_cg.cp_illegal.bad_frame` | 0 | 49 hits |

All other existing functional bins are hit by the legal product tests. The two
bins above describe deliberately malformed framing and are exercised only in
the separately reported illegal test. This applicability annotation does
not edit URG bins or its denominator: raw functional coverage remains 97.97%,
and the machine gate continues to return `RAW_100_OPEN`.

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

### Formal and reachability

- **EF2 safety: PASS.** The fresh VC Formal property report has 6/6 proven
  assertions and 3/3 covered properties, zero black boxes, and four
  non-vacuous properties. Scope is the 32-lane signed-16 production EF2
  recurrence with arbitrary input/ready sequences: widened no-wrap and
  inductive bounds, state update/hold, output capture, and output hold under
  stall. This is not an end-to-end BER proof or formal equivalence to the
  Python oracle.
- **Generic FIFO CDC: prior PASS retained.** The existing exact-clock
  Generic CDC proof has 7/7 assertions, 9/9 covers, and zero black boxes.
  Current simulation also hits every product `rem_count_q` state/transition.
  A fresh rerun in this update was blocked before setup by
  `Cannot connect to license server`; it is not marked as a new PASS. The
  proof does not transfer to XPM.
- **DPD identity arithmetic: OPEN.** Prior scoped work proves selected
  no-saturation/bounds properties, but the full identity-payload proof remains
  inconclusive. No unreachable DPD bins are waived from that result.
- **Centered frame tail: simulation reachable; formal mapping OPEN.** The
  legal four-plane replay covers normal frame-tail processing, and the
  separate negative assertion run checks malformed tail ordering. There is
  no dedicated tail reachability harness in the current formal package, so no
  formal-unreachability claim is made for tail-related bins.
- **PAIR_LOOKAHEAD and nonidentity 2/4-tap DPD:** candidate-only. Their prior
  A/B/formal evidence remains separate; none is counted in the product Raw
  denominator.

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

The VCS reset-sweep target and coefficient-transport target use VCS
V-2023.12-SP1, EF2 ORDER=2, STEP=5120, centered-cubic, one DPD tap, and
`thermo5_tx_product_coverage.hier`. The raw URG merge uses only the seven
positive product VDBs. The illegal-frame test and PA0 mutation use separate
VDBs/reports. Exact commands, SHA-256 hashes, coverage numerators and
denominators, and tool/run directories are recorded in the adjacent machine
evidence file. Large VDBs, generated HTML, logs, vectors, and formal workdirs
remain ignored under `runs/`.

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

Both Make targets passed. The combined formal command proved EF2 before
the identity job stalled; a separate fresh CDC proof attempt stopped at VCF
license connection. These are recorded as a partial run and a blocked rerun,
not as a combined formal PASS. The retained exact-clock Generic CDC proof is
the earlier Linux result named above.

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

**Acceptance:** Task 4 closed the previously missing product FSM transitions
and improved toggles, while reachable line/branch/condition closure remains
open. Task 5 has legal/negative assertion separation and a caught product
checker mutation; DPD identity formal and dedicated Frame Tail formal remain
open. Task 6 is Linux-only partial signoff: functional applicable bins are
covered, but `RAW_100_OPEN` and `COMMUNICATION_ACCEPTANCE_UNDEFINED` remain.
