# Thermo5 clock, reset, and CDC evidence

Date: 2026-10-05. Scope: frozen thermo5 parent using AXI at 125 MHz, core at
218.75 MHz, and the real Vivado XPM asynchronous FIFO. This is a path-specific
evidence inventory, not CDC/RDC closure or a metastability proof.

## Evidence sources

| Evidence | Exact artifact | Result |
| --- | --- | --- |
| Latest routed static CDC | `runs/thermo5_parent_cleanroute_20261005_2117/cdc.rpt`, Vivado 2024.1, design `thermo5_qsfp_gt14_parent`, routed on `xczu15eg-ffvb1156`, report time 2026-10-05 22:08:24 | 2 XPM Gray-pointer CDC-6 warnings and 2 GT TX-active CDC-11 critical paths remain. No CDC waiver is recorded. |
| Focused two-reset FIFO test, freshly rerun 2026-10-05 23:56 Singapore time | Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\dv\verif\scripts\run_xsim_xpm_async_fifo_reset.ps1`; log: `verif/out_xsim_xpm_async_fifo_reset/console_xsim.log` | Exit code 0; `DSM_XPM_ASYNC_FIFO_RESET_PASS`. |
| Parent GT reset/recovery diagnostic from the same routed RTL run | `runs/thermo5_parent_cleanroute_20261005_2117/project/thermo5_qsfp_gt14_parent.sim/sim_1/behav/xsim/simulate.log` and wrapper transcript `runs/thermo5_parent_cleanroute_20261005_2117/sim_parent.stdout.log` | `THERMO5_QSFP_GT14_PARENT_RESET_SIM_PASS accepted=64 output=112 recovery=powergood+tx_active+common_reset rx_compare=SKIPPED`. RX comparison was explicitly skipped. |

The reset testbench is `dv/verif/block/axis/tb_dsm_xpm_async_fifo_reset.sv`;
the wrapper is `dv/verif/scripts/run_xsim_xpm_async_fifo_reset.ps1`. The parent
testbench is `dv/verif/subsystem/tx_frontend/tb/tb_thermo5_qsfp_gt14_parent.sv`.
The static report covers the real XPM instance under
`u_frontend/u_cdc/g_xpm_fifo/u_async_fifo/u_xpm_fifo_async`; the focused
functional test exercises that FIFO wrapper against the Vivado 2024.1 XPM
simulation sources with 125-MHz and 218.75-MHz clocks.

## Instance-level disposition

| Crossing or reset behavior | Exact routed report row / instance | Directed test and observable check | Assertion / status |
| --- | --- | --- | --- |
| AXI write pointer, 125 MHz to core read domain, 218.75 MHz | `cdc.rpt`, Source Clock `axi_clk125` to Destination Clock `core_clk218`, row 2, CDC-6, depth 2: `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/gen_cdc_pntr.wr_pntr_cdc_inst/src_gray_ff_reg[3:0]/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/gen_cdc_pntr.wr_pntr_cdc_inst/dest_graysync_ff_reg[0][3:0]/D`. | Focused FIFO test writes `16'h2468`, reads it after a read-side reset epoch; then writes `16'h5abc` and reads it after a write-side reset epoch. | Test's `$fatal` data comparisons check ordering/integrity at the FIFO interface, not Gray-pointer bits or metastability. Static CDC-6 remains **OPEN for review**; the report identifies a two-stage `ASYNC_REG` Gray-pointer crossing. |
| Core read pointer, 218.75 MHz to AXI read/empty domain, 125 MHz | `cdc.rpt`, Source Clock `core_clk218` to Destination Clock `axi_clk125`, row 3, CDC-6, depth 2: `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/gen_cdc_pntr.rd_pntr_cdc_inst/src_gray_ff_reg[3:0]/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/gen_cdc_pntr.rd_pntr_cdc_inst/dest_graysync_ff_reg[0][3:0]/D`. | Same focused test; `check_word` checks expected data and the final `rd_empty`, `rd_valid`, and `wr_full` flags. | Interface-level FIFO behavior only; no direct pointer SVA or metastability simulation. Static CDC-6 remains **OPEN for review**. |
| Core reset request (`rd_rst_n`) asserted in core domain and handled in AXI write domain | `cdc.rpt`, `core_clk218` to `axi_clk125`, row 1, CDC-9: `u_rst218/sync_q_reg[1]/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/rd_reset_in_wr_reg[0]/CLR`; row 2, CDC-3: same source to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/rd_reset_sync_reg[0]/D`. XPM's internal common-reset propagation is row 4, CDC-3: `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/xpm_fifo_rst_inst/gen_rst_ic.fifo_rd_rst_ic_reg/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/xpm_fifo_rst_inst/gen_rst_ic.rrst_wr_inst/syncstages_ff_reg[0]/D`. | `check_remote_reset(1)` drops only `rd_rst_n` while FIFO contains stale data and write valid is asserted. It checks immediate block of both handshakes, waits for common `fifo_rst`, releases reset, checks empty/no valid, and verifies fresh post-epoch data. | `$fatal` checks cover immediate blocking, stale-data flush, clean new write/read, and `fifo_rst` only changing on a `wr_clk` edge. Functional reset behavior **PASS** in the focused XSim; CDC/RDC timing and recovery/removal are not proven. |
| AXI reset request (`wr_rst_n`) asserted in AXI domain and handled in core read domain | `cdc.rpt`, `axi_clk125` to `core_clk218`, row 3, CDC-3: `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/xpm_fifo_rst_inst/gen_rst_ic.fifo_wr_rst_ic_reg/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/u_xpm_fifo_async/gnuram_async_fifo.xpm_fifo_base_inst/xpm_fifo_rst_inst/gen_rst_ic.wrst_rd_inst/syncstages_ff_reg[0]/D`; row 4, CDC-9: `u_rst125/sync_q_reg[1]/C` to `u_frontend/u_cdc/g_xpm_fifo.u_async_fifo/wr_reset_in_rd_reg[0]/CLR`. | `check_remote_reset(0)` independently drops only `wr_rst_n` with data pending, checks both public handshakes stop, observes common reset, then verifies stale-data removal and a clean post-reset transfer. | Same assertions/checks as above. Functional reset behavior **PASS**; this does not prove analog recovery/removal or CDC closure. |
| Generated GT TX-active to parent health synchronizer, TX user clock to 200-MHz free-run | `cdc.rpt`, `core_clk218` to `freerun_clk200`, row 2, CDC-11, depth 2: `u_gt/inst/gen_gtwizard_gthe4_top.thermo5_qsfp_gt14_probe_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.gtwiz_userclk_tx_active_sync_reg/C` to parent `tx_active_meta_reg/D`. Parent synchronizer is in `fpga/zu15eg/rtl/thermo5_qsfp_gt14_parent.sv` (`tx_active_meta`, `tx_active_sync`). | Existing parent reset-only XSim forces `dut.tx_active=0`; checks PA blanking immediately, waits for `link_ready` deassertion, checks both `rst125_n` and `rst218_n` assert, then releases the force and waits for recovery. Marker reports 64 accepted AXI beats and 112 output words. | Testbench `$fatal` checks and recovery marker pass at RTL simulation level. It does not stop the TX user clock during forced loss and cannot prove metastability or physical loss behavior. CDC-11 remains **OPEN**; no waiver/false path. |
| Generated GT TX-active to generated TX reset controller synchronizer | `cdc.rpt`, `core_clk218` to `freerun_clk200`, row 3, CDC-11, depth 5: `u_gt/inst/gen_gtwizard_gthe4_top.thermo5_qsfp_gt14_probe_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_tx_user_clocking_internal.gen_single_instance.gtwiz_userclk_tx_inst/gen_gtwiz_userclk_tx_main.gtwiz_userclk_tx_active_sync_reg/C` to `u_gt/inst/gen_gtwizard_gthe4_top.thermo5_qsfp_gt14_probe_gtwizard_gthe4_inst/gen_gtwizard_gthe4.gen_reset_controller_internal.gen_single_instance.gtwiz_reset_inst/bit_synchronizer_gtwiz_reset_userclk_tx_active_inst/i_in_meta_reg/D`. Generated source is `runs/thermo5_parent_cleanroute_20261005_2117/project/thermo5_qsfp_gt14_parent.gen/sources_1/ip/thermo5_qsfp_gt14_probe/hdl/gtwizard_ultrascale_v1_7_gtwiz_reset.v:301-307`; it clocks the `bit_synchronizer` from `gtwiz_reset_clk_freerun_in`, and the TX reset FSM consumes the synchronized active level at lines 401-406. | Parent reset/recovery simulation starts the generated Wizard and performs a forced TX-active loss/recovery sequence. It does not directly assert the generated synchronizer stages or the reset FSM's release condition. | Only indirect behavioral coverage; no path-specific assertion/proof of the generated IP reset controller. CDC-11 remains **OPEN** pending supported, path-specific vendor disposition or verified generated-IP configuration change. No waiver/false path. |

The reset implementation under test is `rtl/axis/dsm_xpm_async_fifo.sv`: each
local reset request is synchronized into the XPM write-clock reset domain;
separate asynchronous-assert/two-edge-release guards block public handshakes
while the remote reset crosses domains; `wr_rst_busy`/`rd_rst_busy` also gate
traffic. The static report shows the corresponding routed XPM and parent
instances. Gray-pointer crossings are vendor XPM implementation details and
remain separately visible as CDC-6; they are not waived by the functional
FIFO test.

The `Exception` column in Vivado's CDC table classifies the asynchronous clock
groups used for timing analysis. This evidence work added no exception or CDC
waiver. The two CDC-11 paths remain critical and open.

## Limits and remaining holes

- The block test exercises both reset requests independently and a common
  XPM reset epoch. It does not test arbitrary core-only reset while continuing
  AXI traffic as a supported operating mode; the integration contract requires
  both data domains to share an epoch and hold traffic until reset-busy clears.
- Simulation verifies deterministic functional behavior only. It does not
  model metastability, establish MTBF, or replace structural CDC/RDC review,
  recovery/removal analysis, or hardware clock/reset measurements.
- The two XPM Gray-pointer CDC-6 findings need instance-specific review of the
  vendor synchronizer implementation and parameterization. No blanket XPM
  disposition is recorded.
- The two generated-GT CDC-11 findings remain open. Parent TX-active test
  evidence is limited to forced status loss while clocks continue; generated
  reset-controller behavior lacks a direct path assertion and supported
  vendor disposition.
- Parent RX word comparison is skipped in the cited reset-only diagnostic;
  four-lane RX recovery, external 14-Gb/s behavior, board clock/pin budgets,
  analog PA blanking, and serial phase/deskew are not established here.
