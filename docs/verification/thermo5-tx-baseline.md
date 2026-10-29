# Thermo5 TX Gate 0 baseline

**Status:** audit and inventory prepared; exact-HEAD licensed simulation/formal
rerun is blocked by the Synopsys license connection. Gate 0 is therefore
**PARTIAL / ACCEPTANCE OPEN**, not a full PASS.

**Audit date:** 2026-10-29 (Asia/Singapore)

**Current source:** branch `thermo5`, HEAD
`eb1081bc7607ba2e9825d9e9fb32bcfa1c6a270e`

**Comparison checkpoint:** `759fc8e77446046cb942e7939c53ca49d3bde882`.

## Scope and source identity

The reviewed product is the thermo5 transmitter path only. No RX or AI-DPD
source, parameter, test, or configuration was changed. `git status` was clean
before this audit. Comparing the current HEAD with the plan's checkpoint shows
one documentation-only change: the addition of
`docs/exec-plans/active/thermo5-tx-only-closure-codex.md`. There are no HDL,
testbench, filelist, constraint, or build-configuration changes between those
two commits. The prior run at the checkpoint is useful source-equivalent
historical evidence, but it is not an exact-HEAD rerun and is labeled as such
throughout this report.

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

## Gate 0 commands and current-run results

All current-run outputs are preserved locally under the ignored directory
`runs/thermo5_tx_gate0_eb1081/`.
[`thermo5-tx-gate0-evidence.json`](thermo5-tx-gate0-evidence.json) records the
source SHA, commands, outcomes, and log checksums. Generated logs and vectors
remain in `runs/` and are not committed as project source.

| Check | Command / configuration | Result at current HEAD |
| --- | --- | --- |
| Python reference tests | `cd dv/uvm/refmodel/python && python3.12 -m unittest discover -s tests -v` | **PASS, 36/36** (`python/unittest.log`) |
| Generic Python oracle vectors | `python3.12 dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py --output-dir runs/thermo5_tx_gate0_eb1081/vectors/generic --words 56 --seed 610216 --profile random --interp-mode centered_cubic --tidsm-order 2 --step 5120 --frame-start-words 1,15,36 --frame-gains 16384,14336,12288` | **PASS**, 56 source/output words, four planes (`python/generate_generic_vectors.log`) |
| Generic VCS full regression | `make -C dv/uvm/sim thermo5-vcs-regression THERMO5_OUT=$PWD/runs/thermo5_tx_gate0_eb1081/generic_vcs THERMO5_VECTORS=$PWD/runs/thermo5_tx_gate0_eb1081/vectors/generic THERMO5_CENTERED_CUBIC=1 THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120` | **BLOCKED before compile**: VCS V-2023.12-SP1 could not connect to license server (`generic_vcs/full_regression.log`). No RTL compile or runtime result. |
| AXI-Lite STOP/drain/restart | Would use `thermo5-axil-stop-restart-vcs-run`, order 2, STEP 5120 | **NOT RUN at current HEAD**: same VCS license blocker; historical exact test is listed below. |
| 2,072-word EF2 qualification | Would use `thermo5-ef2-qualification`, seeds 271027/271028/271029 | **NOT RUN at current HEAD**: same VCS license blocker; historical exact test is listed below. |
| EF2 scoped formal | `python3.12 dv/uvm/formal/run_thermo5_scoped_formal.py --jobs ef2 --out-dir runs/thermo5_tx_gate0_eb1081/formal/ef2` | **BLOCKED**: VC Formal V-2023.12-SP2 started but could not connect to license server; no proof was produced (`formal/ef2/ef2/vcf.log`). |
| Vivado / XSim / MATLAB / real XPM | Tool discovery on this Linux host | **NOT AVAILABLE**. No XPM, XSim, or GT Wizard run is claimed. |

The Python vector result verifies oracle generation only; it does not replace
RTL simulation. The VCS and VC Formal attempts stopped before compiling or
proving properties, so their current-run status is not PASS or RTL failure.

## Latest raw Generic URG baseline available

The latest traceable Generic UVM/URG database is from source checkpoint
`759fc8e77446046cb942e7939c53ca49d3bde882`, VCS V-2023.12-SP1, the centered
cubic + EF2 configuration, Generic FIFO, and the UVM hierarchy recorded in
`runs/thermo5_linux_ef2_signoff_759fc8e/signoff_manifest.json`. Its raw URG
summary is:

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
audited DUT-only denominator, and they do not mean 76.12% of required TX
features are verified. The full source-linked uncovered inventory has 784
records in [`thermo5-tx-coverage-ledger.csv`](thermo5-tx-coverage-ledger.csv):
100 zero-hit source-line records, 214 uncovered condition vectors, 108
uncovered branch vectors, 292 signal-direction toggle records, three
unattempted assertion records, and one assertion failure requiring
disposition. Toggle records are at the
reported signal-direction granularity; Gate 3 must regenerate per-bit
transitions from an exact-current-source VDB before declaring bit-toggle
closure.

The portfolio's previous **79.86%** current-baseline statement has no
traceable matching raw URG artifact in the inspected evidence set and conflicts
with the exact Generic report numerators above. It is withdrawn as a current
baseline, retained only as an unverified historical document claim, and must
not be compared with 76.12% as if same-hierarchy evidence existed. The
AXI-Lite session is a separate elaboration and is not merged into or compared
with the Generic mainline score.

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

**Completed:** source/configuration audit; exact current SHA capture; Python
reference suite; Python vector generation; raw coverage snapshot; complete
source-linked inventory; feature/testpoint matrix; evidence manifest; report
correction. No TX RTL or architecture was changed.

**Open for Gate 0 acceptance:** re-run Generic UVM/URG, AXI-Lite STOP/restart,
2,072-word EF2 qualification, and scoped EF2 formal at exact HEAD after the
VCS/VCF license connection is restored. Then regenerate raw URG and replace
historical 759fc8e coverage rows only with same-run evidence. Real XPM remains
separate and unavailable on this host.

Do not begin Gate 1 A/B experiments or Gate 2 worst-case sweeps as part of this
baseline checkpoint. Those are separate PRs in the closure plan.
