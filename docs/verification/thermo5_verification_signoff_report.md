# Thermo5 Verification Signoff Status

Date: 2026-11-12 (Asia/Singapore). Product candidate: PR #62 draft HEAD
`ac08611af825586dc378041d2568eb7ee1ea563c`. This is a partial execution
record, not final product signoff. No PR was merged and no waiver was approved.

## Gate status

| Gate | Status | Evidence and remaining work |
|---|---|---|
| 0. ECO baseline | **PARTIAL / OPEN** | Clean immutable PR #62 checkout; fresh VCS compile and seven-test legal-only DUT Raw URG. Full 594-test rebuild and exact 12,580/12,577 Condition-bin reconciliation remain open. |
| 1. Code coverage closure | **OPEN** | Smoke Raw has 14,972 open bins. No exact-bin classifications were transferred from old RTL; 930 diagnostic counter directions remain open. No approved exclusions or exceptions. |
| 2. CDC/RDC closure | **OPEN** | Structural CDC errors cleared, but Full CDC has 4 Errors; RDC has 10,506 Errors. Async FIFO epoch proof remains inconclusive. All RDC groups remain `OPEN_NO_WAIVER`. |
| 3. Warning closure | **OPEN** | Four simulation-initialization synthesis warnings and eleven redundant signed-argument warnings reviewed; no arithmetic RTL changed. |
| 4. System corners | **PARTIAL / OPEN** | Product regression and nine-epoch reset sweep passed. Full scenario inventory and the seven requested cross-product corners were not rerun on this source. |
| 5. Integrated signoff | **NOT RUN** | PRs #55-#62 are open and stacked. There is no single integrated commit, no independent review/waiver approval, and no licensed full regression on that commit. |

## Coverage and regression

The hierarchy-scoped new Raw result covers Branch 436/639, Condition 585/849,
Line 3,188/3,805, Toggle 90,592/104,480, FSM states 13/13 and FSM transitions
22/22. It leaves 14,972 code bins open. This result combines six legal AXI-Lite
product cases and the nine-epoch reset sweep; it is a seven-test smoke sample.
It excludes the expected-negative runs and does not replace the inherited
594-scenario matrix. The official adjusted view is identical to Raw because
zero exclusions were active.

The source-bound Raw summary, per-instance denominators, exact line-gap and
branch-arm lists, assertions, and RTL ECO diff are preserved under
`data/thermo5-pr62-signoff/`. The current Raw parser does not emit exact
condition-vector or toggle-direction IDs; Gate 1 requires a complete native
bin inventory on the full VDB set.

The fresh AXI-Lite product target compiled and passed its six legal cases,
isolated expected-negative frame/mailbox/parameter checks, and product URG
merge. The reset sweep passed four partial-DSP-frame resets and five CDC
residual resets. The independent trace oracle passed 206 CDC, 101 EF2, and 91
PA words over ten epochs, with zero underflow and no data mismatch.

The prior 12,580 and 12,577 totals differ by three Condition hits while
Branch/Line/Toggle hit counts match. The source hashes and VDB populations are
not homogeneous; exact native IDs for the three Condition hits were not
available. See [baseline reconciliation](baseline_reconciliation.md). This
discrepancy remains open rather than being assigned an unsupported cause.

## SpyGlass CDC/RDC

Fresh SpyGlass V-2023.12-SP1 results at the PR #62 source are:

Every Error/Warning row from each native run, including all 10,506 RDC
messages, is retained in the [per-goal issue ledger](data/thermo5-pr62-signoff/spyglass_issue_inventory.csv.gz)
with goal, native message ID, rule, source location and message text. The
adjacent `spyglass_issue_summary.json` reconciles each row count to the native
goal summary. Records repeat across goals where SpyGlass reports the same
setup warning in more than one goal.

| Goal | Errors | Warnings | Info | Waived |
|---|---:|---:|---:|---:|
| CDC setup | 0 | 15 | 65 | 0 |
| CDC structural | 0 | 27 | 101 | 0 |
| Full CDC Verify | 4 | 34 | 109 | 0 |
| RDC structural | 10,506 | 15 | 70 | 0 |

The four Full CDC errors are three `Ac_cdc01a` data-hold failures and one
`Ac_conv02` mixed-convergence failure:

| Message | Rule | Source / destination | Finding |
|---|---|---|---|
| `66A` | `Ac_cdc01a` | `tx_active_status_c` -> `u_cfg.tx_active_sync1` | Data-hold check failed. |
| `669` | `Ac_cdc01a` | `draining_status_c` -> `u_cfg.draining_sync1` | Data-hold check failed. |
| `66C` | `Ac_cdc01a` | `tx_active_status_c` -> `core_active_s1` | Data-hold check failed. |
| `654` | `Ac_conv02` | FIFO write Gray pointer plus `prefill_ready_c1`/`run_s2` -> `rd_empty_next` | Seven-synchronizer mixed-control convergence; Gray check failed. |

Full CDC waveform analysis measured a 4.5 ns low pulse on
`tx_active_status_c` and a 4.5 ns high pulse on `draining_status_c`, with all
resets released. Such a pulse can be missed by a slower destination clock.
These signals are documented synchronized status levels, not event counters;
the miss alone does not establish an architectural failure. However,
`core_active_s2` participates in prefill clearing, so restart/epoch behavior
still needs an explicit proof under skew. Adding a synchronizer stage or
assuming a minimum RUN hold does not close this obligation.

RDC retains 10,519 native `Ar_resetcross01` records grouped into 104 root
groups: unreset elastic storage 7,576, DPD pipeline/history 2,680, frame gain
149, generic FIFO 98, and config/TX-top 16. Every group remains
`OPEN_NO_WAIVER`. The actual depth-16 FIFO Formal run proves reset push/pop
guards and Gray-pointer properties, but initialization/read-frontier/capacity
goals are inconclusive (depth 10-11); the live-reset cover is inconclusive.
The passing six-epoch/384-word skew simulation is useful system evidence, not
an exhaustive old-epoch isolation proof.

## Warning review

The four `SYNTH_5143` warnings report simulation `initial` blocks ignored for
synthesis in `gt_tx_user_bridge.sv:19`, `thermo5_dpd_axi_lite_cfg.sv:347`,
`tid32_cartesian_ef2_fs4_gt_tx.sv:95`, and
`tid32_thermo5_axi_lite_axis_frontend_tx.sv:293`. They are initialization
constructs, not synthesized state or product datapath logic.

The eleven `WRN_1024` warnings say an already-signed argument is passed to
`$signed`: `dpd_memory_poly.v:285` (1), `dsm_frame_gain_vector.sv:128,130`
(2), and `tid32_cartesian_ef2_fs4_gt_tx.sv:175-178,296-299` (8). They are
redundant-cast diagnostics; the warnings alone do not prove arithmetic
equivalence after editing. No casts were changed. Any cleanup touching DPD,
Gain, or EF2 must use old/new bit-true comparison and, where the expression
width or signed context changes, LEC/Formal.

## Formal results

Fresh separate-directory VC Formal V-2023.12-SP2 results:

| Harness | Result |
|---|---|
| Source status | 7/7 assertions proven; 2/2 covers reached. |
| Elastic FIFO repeated epoch | 4/4 assertions proven; 2/2 covers reached. |
| DPD epoch | 3/3 assertions proven; 2/2 covers reached. |
| Async FIFO depth-16 epoch | 4 proven, 3 inconclusive; transfer cover reached, live-reset cover inconclusive. |

The async FIFO inconclusive obligations are not passed or waived. No reset
equivalence is assumed; source status uses the public common-assertion/local
synchronous-release contract. The broad source-frame and full-chain identity
obligations remain open as recorded in the PR #62 evidence report.

## Reproduction

Run from a clean checkout of `ac08611af825586dc378041d2568eb7ee1ea563c` on
the licensed Linux host. The first command runs setup, structural/full CDC,
RDC, and four isolated formal harnesses. The remaining commands build and
exercise the hierarchy-scoped product set, reset sweep, oracle, and legal-only
Raw URG report.

```bash
PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
SPYGLASS_BIN=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin/sg_shell \
VCF_BIN=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
bash tools/hw/thermo5_rootfix_reproduce.sh

/tmp/nmaforge_arch_v2_py312/bin/python \
  dv/uvm/refmodel/python/generate_thermo5_frontend_vectors.py \
  --output-dir "$PWD/runs/pr62_signoff/vectors" --words 56 --seed 610216 \
  --interp-mode centered_cubic --tidsm-order 2 --step 5120 \
  --frame-start-words 1,15,36 --frame-gains 16384,14336,12288

make -C dv/uvm/sim thermo5-axil-product-vcs-regression \
  PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  THERMO5_OUT="$PWD/runs/pr62_signoff_hier/product" \
  THERMO5_VECTORS="$PWD/runs/pr62_signoff/vectors" \
  THERMO5_COV_HIER="$PWD/dv/uvm/sim/thermo5_product_dut_coverage.hier"

make -C dv/uvm/sim thermo5-vcs-run-only PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
  UVM_SEED=610802 THERMO5_USE_AXIL=1 THERMO5_DPD_MAX_TAPS=1 \
  THERMO5_TIDSM_ORDER=2 THERMO5_STEP=5120 \
  THERMO5_TESTNAME=thermo5_sku_axil_reset_sweep_test \
  THERMO5_OUT="$PWD/runs/pr62_signoff_hier/product" \
  THERMO5_VECTORS="$PWD/runs/pr62_signoff/vectors" \
  THERMO5_EXTRA_ARGS="+THERMO5_TRACE_JSONL=$PWD/runs/pr62_signoff_hier/reset_trace.jsonl"

/tmp/nmaforge_arch_v2_py312/bin/python \
  dv/uvm/refmodel/python/check_thermo5_monitor_trace.py \
  runs/pr62_signoff_hier/reset_trace.jsonl

/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir runs/pr62_signoff_hier/product/simv.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_register_access_test_seed420100.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_config_test_seed420101.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_graceful_stop_test_seed420108.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_coeff_transport_test_seed420104.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_nonlinear_dpd_test_seed420105.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_boundary_phase_test_seed420107.vdb \
  runs/pr62_signoff_hier/product/cov_thermo5_sku_axil_reset_sweep_test_seed610802.vdb \
  -report runs/pr62_signoff_hier/legal_raw -dbname thermo5_pr62_dut_raw

/tmp/nmaforge_arch_v2_py312/bin/python tools/hw/thermo5_coverage_denominator.py \
  runs/pr62_signoff_hier/legal_raw \
  runs/pr62_signoff_hier/legal_raw_summary.json
```

The full final gate remains blocked on one immutable integrated commit, a
homogeneous full legal VDB set and exact coverage inventory, closure or
independent disposition of the four Full CDC errors and 10,506 RDC errors,
all requested system corner tests, and external exact-bin/waiver review. Real
XPM vendor models, XSim, board-level reset/CDC, and physical implementation
remain unverified.
