# CDC/RDC root cause and formal disposition — 2026-11-18

Status **BLOCKED** for product CDC/RDC signoff. Run-start Git HEAD `80b2167844a3338cb6cf746f1da1829977aac5f4`. Prior artifacts are hashed in `runs/cdc_sta_closure_baseline_20261118_01/manifest.json`.

## Clock contract

`research/vcu118_arch/thermo5_ppa_top.sv` exposes AXI-Lite, AXIS and core clocks as separate top inputs. The experiment creates clocks at 100, 125 and nominal 218.75 MHz. It does not supply a board source, MMCM relationship or fixed relative phase. Routed `report_clock_interaction` says core↔AXI-Lite `No Common Clock`, `Unexpanded`, `Timed (unsafe)`; this is not proof of an actual board phase relationship. The Live GTY test drives core from GT TXUSRCLK2 while testbench clocks drive AXI-Lite/AXIS: testbench phasing cannot establish production clock topology. Parent clock sources, generated clocks, phase jitter and board resets remain unverified.

EF1 worst ACK path is `cfg_ack_core_reg/C` to `cfg_ack_sync1_reg/D` (core→AXI-Lite). The two ACK flops and two request flops carry `ASYNC_REG`; the first flop necessarily samples an asynchronous input, but synchronizer structure alone does not establish MTBF or reset safety. MASH's data bus is AXI-Lite `cfg_mailbox_q` → core `cfg_pending_core`: source holds a bundled vector throughout a four-phase request/ACK, core samples after the synchronized request, and pending applies at a DPD boundary. Formal common-reset proof covers bounded digital semantics, not physical metastability, bus delay/skew or arbitrary phases. Existing candidate EF1 exception is one exploratory `set_max_delay 4` from mailbox source cells to pending cells, without `-datapath_only`; hold remains timed. MASH A/B had no valid exceptions. Neither is a system CDC disposition. No new exception was introduced this round.

## Independent reset witness

**FAIL for the hypothesis that arbitrary independent source reset cancels a pending transaction.** The actual `thermo5_dpd_axi_lite_cfg` is driven over AXI-Lite to submit `c1_re=0x1234`, with frame boundary low until `cfg_pending_valid`. Then AXI-Lite reset alone is asserted and a core boundary follows before the request synchronizer has observed its deassertion. At 61,723 ps, the core applies the pre-reset `0x1234` and asserts ACK while AXI-Lite remains reset. This is a concrete stale-epoch witness, not a claim that the currently documented common-reset environment violates its contract. Its product acceptability cannot be determined without the parent reset/transaction contract. Simply adding a timing exception, masking ACK or asynchronously resetting a foreign domain would not establish atomic epoch semantics. A repair requires an agreed cancellation/replay contract and verification through both directions of independent reset, including traffic and reset release.

Reproduce with Icarus Verilog 12.0 from a new empty working directory:

```bash
iverilog -g2012 -s tb_cfg_independent_reset_epoch -o simv \
  /ABS/REPO/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
  /ABS/REPO/research/vcu118_arch/tb_cfg_independent_reset_epoch.sv
vvp simv
```

Evidence `runs/cfg_independent_reset_epoch_01/simulation.log` and `witness.vcd`; VCD SHA-256 `a2cbf5ea946c0a37060d5ca3740b83edfd79c8eb5c490cf6f6eff5b9e13f7094`. The test is a witness, not a product pass.

## Formal

Previous seven-property atomic harness: 6 proved and 1 inconclusive, all 7 non-vacuous and 4/4 covers hit. The same sample-stability assertion was proven non-vacuously in the smaller original capture harness under the same RTL, clocks and common-reset model; addition of other proof goals changed solver behavior, not the asserted expression. Neither result proves reset independence, metastability or arbitrary phase. `research/vcu118_arch/formal_cfg_mailbox_sample_isolated.tcl` repeats the exact unresolved assertion from the seven-property harness without adding assumptions, with a 12-minute per-property bound. In `runs/mailbox_sample_isolated_01/properties.txt`, the exact assertion is PROVEN after 7m02s. The isolated run did not run vacuity or covers, while the previous seven-property run marked this same assertion non-vacuous and hit the capture cover. Across the two runs the seven individual assertions are proved in the same fixed-phase/common-reset model; this is a composite result, not a single 7/7 proof run. Setup reset check remains disabled, and fixed 16:35 periods plus released common reset scope remain limitations.

## Static audit

A new SpyGlass V-2023.12-SP1 CDC/RDC run is in `runs/cdc_rdc_generic_static_20261118_02/` against `tid32_thermo5_axi_lite_axis_frontend_tx` with Generic FIFO and three clocks declared asynchronous in `dv/uvm/static/thermo5_axil_generic.sgdc`. This does not cover the runtime wrapper or XPM implementation. The previous attempt `..._01/` failed in shell startup because `set -u` was incompatible with `/etc/profile`; it is preserved. Review actual report messages, not just shell exit codes.

Fresh EF1 routed DCP audit is queued in `runs/ef1_vivado_cdc_audit_queue_01/`; it will write Vivado 2026.1 `report_cdc -details`, clock interaction, exceptions, timing summary and check_timing into a new directory only after the route completes. Neither Vivado CDC alone nor Generic SpyGlass closes RDC/system signoff.


SpyGlass run 02 completed: setup 0 errors/18 warnings; structural CDC
0 errors/29 warnings, 6 convergence findings; structural RDC **FAIL** with
10,539 errors and 18 warnings, no waivers. All 10,539 error messages are
`Ar_resetcross01`; for example, a reset-driven write-full qualifier reaches
unreset Generic FIFO memory enable (`Q->EN`, qualifier not found). This is
a rule grouping, not proof that all messages share one safe disposition. The
SGDC declares three clocks unrelated and three resets separately; reconciling
the actual parent reset contract and classifying each crossing are open.
Reproduction uses `runs/cdc_rdc_generic_static_20261118_02/run.sh`, after
choosing new output paths; native goal reports and logs remain under that run.


## Chosen common-reset contract and directed test

The integration contract is now common assertion in AXI-Lite, AXIS and Core,
with local synchronous deassertion; reset aborts all in-flight frames and
configuration/mode requests and software reconfigures before RUN. See
`docs/spec/thermo5-runtime-dsm.md`. The three existing top reset ports do not
enforce this; parent distribution, skew and traffic gating are still **BLOCKED**
until implemented and verified.

A new real-RTL directed test `research/vcu118_arch/tb_cfg_common_reset_abort.sv`
uses `dsm_reset_sync` in each of the two configuration domains. It submits an
old pending DPD configuration, asserts common reset, checks no old pending or
ACK remains after release, then submits and applies a new configuration. It
passed in `runs/cfg_common_reset_abort_01/` with a retained VCD. This is one
phase/scenario, not an arbitrary-clock/reset formal or complete runtime proof.
Reproduce in an unused directory with Icarus 12.0:

```bash
iverilog -g2012 -D SYNTHESIS -s tb_cfg_common_reset_abort -o simv \
  /ABS/REPO/rtl/axis/dsm_reset_sync.sv \
  /ABS/REPO/rtl/tx_bandpass_if/thermo5_dpd_axi_lite_cfg.sv \
  /ABS/REPO/research/vcu118_arch/tb_cfg_common_reset_abort.sv
vvp simv
```

VC Formal V-2023.12-SP2 `runs/cfg_common_reset_formal_01/properties.txt`
additionally proves 2/2 non-vacuous reset-state assertions with 2/2 covers:
a common reset epoch clears AXI-Lite request/busy and Core pending/ACK, and
the scenarios include a pending request before reset and a later new request.
The arbitrary `epoch_n` pulse is combined with boot reset and feeds two local
reset synchronizers; clock periods are fixed at 16/35 formal units. Reset setup
checks were disabled and VC Formal reported three potential reset setup issues.
This is limited to the configuration block's reset state, not every possible
transaction ordering, physical reset release, output frame abort, full product
or arbitrary clock phase. Reproduce with `MAILBOX_FORMAL_ROOT`,
`MAILBOX_FORMAL_OUT` and `research/vcu118_arch/formal_cfg_common_reset_abort.tcl`
in a fresh directory; do not treat the scoped proof as RDC signoff.
