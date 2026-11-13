# Thermo5 CDC Debug Checkpoint

Date: 2026-11-13. Status: `PARTIAL_CLOSURE; SIGNOFF_OPEN`.

Immutable PR #62 reference: `ac08611af825586dc378041d2568eb7ee1ea563c`.
Candidate worktree: `/tmp/dsm_ip_cdc_quantified_research`, branch
`task/thermo5-cdc-quantified-research`, HEAD
`3b60f37929c23d014ab533ba80099e02f67c3e8d`. The current IDE checkout is a
different dirty branch and was not edited. Failed logs and native VCDs remain
under `runs/` and `/tmp/thermo5_axil_compare_*`. Product RTL, testbench,
formal-harness and research edits are still mixed in this candidate and must
be separated before proposing integration.

The uncommitted source/test patch snapshot is
`docs/verification/data/thermo5-cdc-quantified-debug/candidate_source_and_test_changes.patch`
(SHA-256 `9926f87a52886285f2c45464734e5cf71e935fb4f5320a675d2ff36af50af92e`).
`manifest.json` binds relevant RTL, TB, formal, native report and VCD hashes.
The working-tree change ownership is:

| Class | Files |
|---|---|
| Product ECO | `rtl/axis/dsm_async_fifo.sv`, `rtl/axis/dsm_axis14_to_core8_cdc.sv`, `rtl/axis/dsm_xpm_async_fifo.sv`, `rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv`, `rtl/tx_bandpass_if/tid32_thermo5_axi_lite_axis_frontend_tx.sv` |
| Testbench / infrastructure | `dv/uvm/env/thermo5/thermo5_sku_uvm_pkg.sv`, `dv/uvm/tests/thermo5/thermo5_sku_base_test.svh`, `dv/uvm/tests/thermo5/thermo5_sku_bittrue_test.svh`, `dv/verif/axis/tb_thermo5_generic_fifo_epochs.sv`, `dv/verif/axis/tb_thermo5_generic_fifo_skew_epochs.sv`, `dv/verif/reset/tb_thermo5_reset_release_contract.sv`, `tools/hw/check_thermo5_axil_illegal_frame.py` |
| Formal harness | `dv/uvm/formal/thermo5_cdc_source_status_harness.sv`, `dv/uvm/formal/thermo5_rdc_async_epoch_harness.sv` |
| Research-only RTL | None in this diff; EF2 parallel and joint spectral work remains in model/ablation artifacts. |

## Full-stream UVM timeout

The original failure reproduced with identical vectors and seed 610216 on
PR #62 and candidate. Earliest no-progress state was 16/32 source beats,
zero CDC/EF2/PA progress, and RUN deasserted. AXI-Lite RUN is controlled by
its register path, but the shared bit-true sequence called `core_on()` through
an unconnected control interface and did not create an AXI agent. This is a
testbench configuration/control defect, not evidence of an ECO-induced RTL
regression.

The test now creates the AXI agent in AXI-Lite mode, writes RUN/STOP through
the register interface, and requests STOP after accepted TLAST before drain.
Watchdogs and four-plane bit-true checks remain enabled.

| Image | Source | Output | Comparison | UVM Error/Fatal | Underflow |
|---|---:|---:|---|---:|---:|
| PR #62 baseline | 32 beats | 56 words | Four planes bit-true | 0 | 0 |
| Candidate ECO | 32 beats | 56 words | Four planes bit-true | 0 | 0 |

Logs/traces: `/tmp/thermo5_axil_compare_pr62_stopdrain_610216/` and
`/tmp/thermo5_axil_compare_candidate_stopdrain_610216/`. Independent Python
trace oracle passed both. Candidate STOP/Restart passed 112 ordered words;
nine-reset sweep oracle passed 206 CDC / 101 EF2 / 91 PA words with zero
underflow. These are directed tests, not a 594-scenario replay.

Example reproduction (licensed VCS and seed-610216 vectors required):

```bash
make -C dv/uvm/sim thermo5-vcs-run-only THERMO5_USE_AXIL=1 \
  THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_OUT=/tmp/thermo5_axil_compare_candidate_stopdrain_610216 \
  THERMO5_VECTORS=<seed-610216-vectors> \
  THERMO5_TESTNAME=thermo5_sku_bittrue_test UVM_SEED=610216 \
  THERMO5_EXTRA_ARGS=+THERMO5_TRACE_JSONL=/tmp/candidate_trace.jsonl
python3 dv/uvm/refmodel/python/check_thermo5_monitor_trace.py /tmp/candidate_trace.jsonl
```

## Four historical Full CDC errors

The edge-corrected prior full-goal comparison is preserved in
`docs/verification/data/thermo5-cdc-debug/full_cdc_comparison.json`.

| Old native ID | Rule | Source / target | Risk and disposition |
|---|---|---|---|
| 66A | Ac_cdc01a | `tx_active_status_c` -> AXI-Lite `tx_active_sync1` | Registered source removes combinational glitch; short pulse capture is not guaranteed. OPEN. |
| 669 | Ac_cdc01a | `draining_status_c` -> AXI-Lite `draining_sync1` | Same pulse-width/status contract question. OPEN. |
| 66C | Ac_cdc01a | `tx_active_status_c` -> `core_active_s1` | Registration alone does not prove restart/prefill behavior for a missed pulse. OPEN. |
| 654 | Ac_conv02 | FIFO synchronized write Gray pointer + `prefill_ready_c1` -> `rd_empty_next` | Mixed pointer/control convergence is not a pointer-only Gray check. OPEN pending protocol proof. |

The preserved `Ac_conv02.1.1.vcd` SHA-256 is
`2413af9d039a9c9c8e9b9655e5daaa579b954a04f7ec75cd4635e792448679dd`.
Its observed reset inputs remain released throughout; common reset cannot
explain away the failure. The edge-corrected full-goal comparison records the
mixed convergence as ID 654. Other snapshots use different IDs; request ID
652 cannot be mapped without its exact report snapshot. Candidate v6 IDs
646/648 are Ac_conv02 warnings for `wr_full_next` and `fifo_rd_count[4]`; ID
652 is not identified as Ac_conv02 there. Native IDs are run-local. Compare
rule, hierarchy, gate and message semantics.

Candidate report: `runs/cdc_quant_research/spyglass_full_v6/moresimple.rpt`
(SpyGlass V-2023.12-SP1, AXI-Lite top, `DPD_MAX_TAPS=1`, generic FIFO). Its
CDC goal rows parse as 0 Error / 21 Warning / 102 Info. Across the complete
`moresimple.rpt`, there are 32 `Warning` rows plus four `SynthesisWarning`
rows (36 warning-class messages total). This artifact does not support the
requested 37-warning count. The inherited edge-corrected summary says
4E/34W/109I, while the preserved prior report rows count 4E/32W, four
synthesis warnings and 108 Info. The two-warning mismatch is unresolved;
different report snapshots/scopes cannot replace the missing exact Native-ID
inventory. Candidate v6 still has seven convergence warnings and eight
data-hold warnings marked Partially-Proved. No waiver was used. A clean
same-scope run on the exact frozen ECO source is still required.

The three preserved status counterexamples include 4.5 ns transitions while
receiver periods are 8/10 ns in the previous native audit. A lost transient
may be acceptable only if status semantics are documented as levels and
restart safety is independently proved. No status/event equivalence or
minimum-pulse assumption is introduced here.

| Required property | Evidence | Status |
|---|---|---|
| No read from empty | Selected FIFO simulation and partial structural checks | OPEN |
| No old-epoch read | Six-epoch skew simulation, 384 words; depth-16 formal epoch property inconclusive | OPEN |
| No duplicate/drop | Directed four-plane scoreboards passed selected tests | OPEN for full protocol/reset/skew space |
| Reset/restart safety | Nine-reset sweep passed; live-reset recovery formal is inconclusive | OPEN |
| Startup predicate safety | Source-status harness proves bounded local properties, not full pointer/RUN/prefill convergence | OPEN |
| Forward progress | Corrected full stream and STOP/Restart directed tests pass | OPEN for full legal backpressure/scenario inventory |

Candidate reports no Full CDC Error, but residual protocol/proof obligations
remain. This is not final CDC signoff.
