# Thermo5 TX Gate 0 baseline

**Status:** `PASS_LINUX_GENERIC_SCOPE`. Gate 0's exact-source Linux checks,
raw Generic URG, and source-linked inventory are complete. Vendor-specific
XPM/GT Wizard and board/physical checks remain outside the available Linux
tool environment; they are recorded as NOT RUN, not PASS.

**Audit date:** 2026-10-29 (Asia/Singapore)

**Audited branch source:** `thermo5`, HEAD
`eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`.

**Verification source:** `codex/thermo5-tx-gate0-baseline`, commit
`04550289e1ecb5fa0e38168869d4f2539929cb80`, tree
`b56d79ac3f3481a8dcaa86ae024539b10aff590a`. The run manifests record a clean
worktree. This commit changes documentation only relative to the audited RTL,
DV, constraints, and build inputs.

**Comparison checkpoint:** `759fc8e77446046cb942e7939c53ca49d3bde882`.
The exact-current Generic URG report was independently regenerated and its
HTML/XML coverage tables match the checkpoint report after timestamp/path
normalization. The CSV inventory now points to the exact-current report.

## Scope and source identity

The reviewed product is the thermo5 transmitter path only. No RX or AI-DPD
source, parameter, test, or configuration was changed. The starting worktree
was clean. Comparing the audited source with checkpoint 759fc8e shows only a
documentation-only change: the TX closure plan. No HDL, testbench, filelist,
constraint, or build-configuration input differs. The latest VCS, URG, and VC
Formal results below were rerun at verification commit 04550289, not inferred
from the earlier checkpoint.

## Active hierarchy and configuration

The current thermo5 TX SKU is described by the following source hierarchy and
settings. This table is read from RTL, filelists, the ZU15EG parent, and the
UVM configuration; it is not inferred from a report title.

| Item | Active configuration | Evidence source |
| --- | --- | --- |
| Board parent | `thermo5_qsfp_gt14_parent`; four GT user-data TX planes | `fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv` |
| TX frontend | `tid32_thermo5_axi_lite_axis_frontend_tx` → `tid32_thermo5_axis_frontend_tx` | parent RTL and `rtl/tx_bandpass_if/` |
| AXI ingress | 125 MHz, 14 complex signed Q1.15 samples per accepted beat | `fpga/zu15eg/constraints/thermo5_qsfp_gt14_parent.xdc`; UVM top |
| CDC and gearbox | 16-entry FIFO; 14 ingress lanes to 8 core lanes; frame alignment quantum 56 samples | `rtl/axis/dsm_axis14_to_core8_cdc.sv`, `rtl/axis/dsm_async_fifo.sv` |
| FIFO implementation | Parent default selects XPM; Linux Generic UVM baseline selects generic FIFO. Real XPM is not available on this host. | Parent parameter; `dv/uvm/sim/Makefile` |
| Core clock | GT user clock; UVM model is 218.75 MHz | UVM top and parent clock wiring |
| Interpolation | centered-cubic x2, two-tap parameter selection; phase 0 exact, phase 1 `[-1, 9, 9, -1]/16` | `rtl/interp/dsm_interp_x2_centered_cubic_vector.sv` |
| DPD | ZU15EG parent explicitly elaborates `DPD_MAX_TAPS=1`, bypass off; default active coefficients are identity (`C1=0x4000`, other terms zero) | Parent instance and `thermo5_dpd_axi_lite_cfg.sv` |
| AXI-Lite DPD test elaboration | Separate test top may elaborate `DPD_MAX_TAPS=4`; this is not the GT parent hardware SKU. | `dv/uvm/tb/thermo5_sku_uvm_tb.sv` |
| Quantizer | Four thermometric offsets `{+3,+1,-1,-3} * STEP`; `STEP=5120` | `rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv` |
| TIDSM | EF2 order 2; 20-bit state, 22-bit temporary accumulator; chronological sample order; `PAIR_LOOKAHEAD=0` | `rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv` and wrappers |
| Output | Four lockstep 64-bit planes to GT TX user boundary | GT parent and bridge RTL |
| Reference test clocking | 125 MHz source, 218.75 MHz core, 100 MHz AXI-Lite | `dv/uvm/tb/thermo5_sku_uvm_tb.sv` |

The exact ZU15EG XDC also defines a 125-MHz AXI period, 100-MHz AXI-Lite
period, 200-MHz free-running clock period, and 125-MHz GT reference clock.
Parent I/O budgets and board-level timing remain assumptions until measured
board constraints are supplied.

## Gate 0 commands and exact-source results

All current outputs and complete logs are preserved under the ignored
`runs/thermo5_tx_gate0_0455028_recheck/` directory. The tracked
[`thermo5-tx-gate0-evidence.json`](thermo5-tx-gate0-evidence.json) records
commands, source SHA, selected artifact checksums, configuration, and results.
Generated logs, VDBs, URG output, and vectors are not committed as source.

| Check | Exact command/configuration | Result at verification SHA `0455028` |
| --- | --- | --- |
| Python reference suite | `cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v` | **PASS, 36/36**; `python/unittest.log` |
| Generic Python oracle vectors | `python3.12 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py --output-dir runs/thermo5_tx_gate0_0455028_recheck/vectors/generic --words 56 --seed 610216 --profile random --interp-mode centered_cubic --tidsm-order 2 --step 5120 --frame-start-words 1,15,36 --frame-gains 16384,14336,12288` | **PASS**, 56 source/output words on each of four planes |
| Generic VCS UVM regression | `make -C dv/uvm/sim thermo5-vcs-regression THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_0455028_recheck/generic_vcs THERMO5_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/generic THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120` | **PASS**: bit-true, bubble/backpressure, FIFO boundary/empty, reset/replay, and expected illegal-frame negative test; zero UVM errors/fatals |
| Generic URG merge | `make -C dv/uvm/sim thermo5-coverage-merge THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_0455028_recheck/generic_vcs` | **PASS**; fresh raw URG at SHA 0455028, details below |
| Full AXI-Lite VCS regression | `make -C dv/uvm/sim thermo5-axil-vcs-regression THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_0455028_recheck/axil_full_vcs THERMO5_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/axil THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120` | **PASS**: config/register, graceful STOP, coefficient transport, nonlinear coefficient transport, tap-4 identity, boundary phase, negative frame/mailbox, parameter guard, and separate AXI-Lite URG merge; raw AXI-Lite URG 78.47% line (3328/4241), 58.58% condition (693/1183), 88.85% toggle (111362/125344), 77.27% FSM (17/22), 53.86% branch (453/841), 76.47% assertion (13/17), 80.787% group; zero UVM errors/fatals in legal UVM cases |
| STOP/drain/restart | `make -C dv/uvm/sim thermo5-axil-stop-restart-vcs-run PYTHON=python3.12 THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_0455028_recheck/stop_restart_vcs THERMO5_STOP_RESTART_TIDSM_ORDER=2 THERMO5_STOP_RESTART_STEP=5120 THERMO5_STOP_RESTART_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/stop_restart` | **PASS**: 112 ordered four-plane words matched the Python oracle; packet 2 remained blocked until RUN restarted; zero UVM errors/fatals |
| EF2 2,072-word qualification | `make -C dv/uvm/sim thermo5-ef2-qualification PYTHON=python3.12 THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_0455028_recheck/ef2_qualification_vcs THERMO5_EF2_SUSTAINED_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/qualification/sustained THERMO5_EF2_RANDOM_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/qualification/random THERMO5_EF2_EXTREME_VECTORS=$PWD/runs/thermo5_tx_gate0_0455028_recheck/vectors/qualification/extreme` | **PASS**, seeds 271027/271028/271029: sustained 2,072 words/no gaps, positive and negative clamp with stall-hold/reset/replay, random stalls, all four targeted clamp/rail crosses 4/4; zero UVM errors/fatals |
| EF2 scoped VC Formal | `PATH=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin:$PATH python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --jobs ef2 --out-dir runs/thermo5_tx_gate0_0455028_recheck/formal_withpath` | **PASS**, 6/6 assertions proven, 3/3 covers covered, zero black boxes; VC Formal V-2023.12-SP2 |
| Vivado / XSim / MATLAB / real XPM / GT Wizard | Linux tool and vendor-source discovery | **NOT AVAILABLE** on this host. No vendor-model or physical result is claimed. |

The initial VCS checkout attempt failed before compile while the license
service was unavailable. A retry at the same verification SHA completed the
Generic, AXI-Lite, STOP/restart, and qualification flows after license access
recovered; the retry logs are the PASS evidence. One assertion failure in the
raw coverage report is the expected trip from the deliberately malformed
frame negative test. Three assertions remain unattempted, so `13/17` does not
mean every assertion passed.

The EF2 proof establishes its stated 32-lane no-wrap/bounds and handshake
properties. It is not a formal equivalence proof against the Python model and
does not prove clamp-free operation for every signed-16 input.

The subsequent Linux Gate 1 candidate evidence is recorded separately in
[`thermo5-tx-algorithm-ab.md`](thermo5-tx-algorithm-ab.md) and
[`thermo5-tx-gate1-evidence.json`](thermo5-tx-gate1-evidence.json). Those
candidate-run coverage numbers are not substituted for the Gate 0 baseline.

## Latest raw Generic URG baseline at exact verification source

The freshly generated Generic URG report is bound to verification source
`04550289e1ecb5fa0e38168869d4f2539929cb80`, VCS V-2023.12-SP1, centered-cubic
+ EF2, Generic FIFO, and the recorded UVM hierarchy. Its raw URG summary is:

| URG category | Covered / total | Raw score |
| --- | ---: | ---: |
| Line | 2,969 / 3,593 | 82.63% |
| Condition | 594 / 949 | 62.59% |
| Toggle | 81,740 / 102,612 | 79.66% |
| FSM | 22 / 22 | 100.00% |
| Branch | 336 / 540 | 62.22% |
| Assertion | 13 / 17 | 76.47% |
| Functional covergroup aggregate | 69.2592% | 69.26% |
| Mean of the seven URG category scores | — | **76.12%** |

These are raw unmodified report values for the measured hierarchy, not an
audited DUT-only denominator and not a claim that 76.12% of required TX
features are verified. The exact-source 784-row inventory is in
[`thermo5-tx-coverage-ledger.csv`](thermo5-tx-coverage-ledger.csv): 100
zero-hit source-line records, 214 uncovered condition vectors, 108 uncovered
branch vectors, 292 signal-direction toggle records, three unattempted
assertion records, and one assertion failure requiring disposition. The
report's toggle detail is at signal-direction granularity; Gate 3 must
regenerate per-bit transitions before declaring bit-toggle closure. No
exclusions or denominator changes were applied.

The earlier **79.86%** current-baseline statement has no traceable matching
raw URG artifact in the inspected evidence set and conflicts with the exact
Generic report above. It is withdrawn as a current baseline. The AXI-Lite
session is a separate elaboration and is not merged into or compared with the
Generic mainline score.

## Historical source-equivalent regression evidence

Because the current source tree differs from checkpoint 759fc8e only by the
addition of this closure plan, the checkpoint's runtime results remain useful
for identifying existing tests and likely behavior. They are explicitly
**historical, not rerun at current HEAD**:

| Historical check | Result recorded at checkpoint | Limits |
| --- | --- | --- |
| Generic UVM bit-true/full regression | PASS; 32 ingress words to 56 output words per plane, independent four-plane oracle; bubbles/backpressure, FIFO boundary/empty, reset/replay, residual reset points | Generic FIFO only; raw URG includes the recorded compile hierarchy. |
| Expected illegal-frame negative test | PASS as test; one deliberate RTL assertion trip is visible in raw URG | `rem_count_q==0` assertion is expected to trip for the injected misaligned `frame_start`; keep raw assertion failure visible and review disposition. |
| AXI-Lite STOP/drain/restart | PASS, 112 ordered four-plane words matched; test covers stop during packet, drain, second packet blocked, restart | Separate AXI-Lite elaboration; do not conflate with Generic mainline UVM. |
| EF2 long-frame qualification | PASS, three 2,072-word seeds 271027/271028/271029; four targeted EF2 clamp/stall/rail crosses each 4/4 | These are selected functional bins, not full functional or code coverage. |
| EF2 scoped formal | PASS, 6 assertions and 3 covers, zero black boxes | Historical proof; not current SHA rerun. It proves its stated bounds/handshake scope, not oracle equivalence or universal clamp-free operation. |

The raw Generic assertion category must be read with care: one failure is the
intentional illegal-frame assertion trip above, and four assertions are
unattempted. The ratio 13/17 must not be described as “all assertions passed.”

## Gate 0 disposition and next action

**Gate 0 accepted for the Linux Generic/behavioral verification scope.** The
exact-source Python, Generic VCS/URG, full AXI-Lite VCS, STOP/drain/restart,
2,072-word EF2 qualification, and scoped EF2 formal checks all passed at
verification SHA `04550289e1ecb5fa0e38168869d4f2539929cb80`. The full raw
coverage report and 784-row inventory are preserved without exclusions.

**Still outside this Linux Gate 0 acceptance:** real XPM FIFO, XSim/Vivado,
current GT Wizard model, routed FPGA timing/resources, and physical RF/QAM256
BER. These remain explicit NOT RUN / OPEN items. Targeted functional bins do
not equal complete feature coverage, and raw code coverage remains 76.12%.

Gate 1 A/B candidates, Gate 2 worst-case benchmark, and Gate 3 coverage
convergence may now proceed as separate reviewable stages/PRs. Keep the
verified main-chain configuration unchanged until candidate evidence and
acceptance criteria justify a promotion.
