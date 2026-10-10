`timescale 1ns/1ps
`default_nettype none

// Prospective four-GTH digital parent for the frozen thermo5 SKU. The board
// must supply an actual 125-MHz bank-128 MGTREFCLK before hardware use.
// The AXI/freerun clocks and board PA-blanking path are integration inputs;
// this module does not claim a tested physical RF output.
module thermo5_qsfp_gt14_parent #(
  parameter bit ENABLE_INTERNAL_PMA_LOOPBACK = 1'b0
) (
  input  wire logic        axi_clk125,
  input  wire logic        freerun_clk200,
  input  wire logic        reset_n,
  input  wire logic        run_request_axi,
  input  wire logic        mgtrefclk125_p,
  input  wire logic        mgtrefclk125_n,
  input  wire logic [3:0]  qsfp_rx_p,
  input  wire logic [3:0]  qsfp_rx_n,
  output wire logic [3:0]  qsfp_tx_p,
  output wire logic [3:0]  qsfp_tx_n,
  input  wire logic        s_axis_tvalid,
  output wire logic        s_axis_tready,
  input  wire logic signed [223:0] s_axis_i_vec,
  input  wire logic signed [223:0] s_axis_q_vec,
  input  wire logic        s_axis_frame_start,
  input  wire logic signed [15:0] s_axis_frame_gain,
  output wire logic        s_axis_fifo_full,
  output wire logic        core_underflow,
  output wire logic        core_protocol_error,
  output wire logic        core_clk218,
  output wire logic        link_ready,
  output wire logic        pa_enable,
  output wire logic        stream_fault,
  output wire logic [255:0] gt_rxdata
);
  wire logic refclk, refclk_div2_unused;
  wire logic [0:0] tx_clk_i, tx_active, tx_done;
  wire logic [0:0] rx_active_unused, rx_done_unused;
  wire logic [3:0] tx_pma_done, powergood;
  wire logic [3:0] rx_pma_done_unused;
  wire logic [0:0] rx_cdr_unused, qpll_clk_unused, qpll_ref_unused;
  wire logic [0:0] rx_clk_unused;
  // Verification-only near-end PMA loopback (GTH LOOPBACK=3'b010). The
  // default stays normal external-lane operation for implementation.
  wire logic [11:0] gt_loopback = ENABLE_INTERNAL_PMA_LOOPBACK ? {4{3'b010}} : '0;
  wire logic [3:0] gt_rxslide = '0;
  wire logic [3:0] pa_valid, pa_ready;
  wire logic [63:0] pa_data [0:3];
  wire logic [255:0] tx_word;
  wire logic reset_freerun_n, rst125_n, rst218_n;
  (* ASYNC_REG = "TRUE" *) logic [1:0] run_sync;
  (* ASYNC_REG = "TRUE" *) logic tx_active_meta, tx_active_sync;
  (* ASYNC_REG = "TRUE" *) logic [8:0] health_meta, health_sync;
  logic [3:0] health_stable_count;
  logic link_ready_q;
  // The GT Wizard's TX-active level is asynchronous to the free-running
  // control clock and may change when the TX user clock is stopped. Sample it
  // as data through a two-flop synchronizer here; do not use a status crossing
  // as an asynchronous-clear pin on the synchronizer or health state.
  wire logic [8:0] health_raw = {tx_done, powergood, tx_pma_done};
  wire logic pa_enable_request;
  wire logic run_core = run_sync[1];
  wire logic gt_reset = !reset_n;

  IBUFDS_GTE4 u_refclk (.I(mgtrefclk125_p), .IB(mgtrefclk125_n),
                       .CEB(1'b0), .O(refclk), .ODIV2(refclk_div2_unused));
  thermo5_qsfp_gt14_probe u_gt (
    .gtwiz_userclk_tx_reset_in({gt_reset}),
    .gtwiz_userclk_tx_srcclk_out(), .gtwiz_userclk_tx_usrclk_out(),
    .gtwiz_userclk_tx_usrclk2_out(tx_clk_i),
    .gtwiz_userclk_tx_active_out(tx_active),
    .gtwiz_userclk_rx_reset_in({gt_reset}),
    .gtwiz_userclk_rx_srcclk_out(), .gtwiz_userclk_rx_usrclk_out(),
    .gtwiz_userclk_rx_usrclk2_out(rx_clk_unused),
    .gtwiz_userclk_rx_active_out(rx_active_unused),
    .gtwiz_reset_clk_freerun_in({freerun_clk200}),
    .gtwiz_reset_all_in({gt_reset}),
    .gtwiz_reset_tx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_tx_datapath_in(1'b0),
    .gtwiz_reset_rx_pll_and_datapath_in(1'b0),
    .gtwiz_reset_rx_datapath_in(1'b0),
    .gtwiz_reset_rx_cdr_stable_out(rx_cdr_unused),
    .gtwiz_reset_tx_done_out(tx_done),
    .gtwiz_reset_rx_done_out(rx_done_unused),
    .gtwiz_userdata_tx_in(tx_word),
    .gtwiz_userdata_rx_out(gt_rxdata),
    .loopback_in(gt_loopback), .rxslide_in(gt_rxslide),
    .gtrefclk00_in({refclk}),
    .qpll0outclk_out(qpll_clk_unused),
    .qpll0outrefclk_out(qpll_ref_unused),
    .gthrxn_in(qsfp_rx_n), .gthrxp_in(qsfp_rx_p),
    .gthtxn_out(qsfp_tx_n), .gthtxp_out(qsfp_tx_p),
    .gtpowergood_out(powergood),
    .rxpmaresetdone_out(rx_pma_done_unused),
    .txpmaresetdone_out(tx_pma_done)
  );

  assign core_clk218 = tx_clk_i[0];
  dsm_reset_sync u_rst_freerun (.clk(freerun_clk200),
      .arst_n(reset_n), .srst_n(reset_freerun_n));

  // Synchronize every GT health level into the free-running reset-control
  // domain, then require a stable interval before releasing both data domains.
  // PA blanking still uses raw TX-active/health as a fail-safe asynchronous
  // gate; only reset and link qualification use synchronized status.
  always_ff @(posedge freerun_clk200 or negedge reset_freerun_n) begin
    if (!reset_freerun_n) begin
      tx_active_meta <= 1'b0;
      tx_active_sync <= 1'b0;
      health_meta <= '0;
      health_sync <= '0;
      health_stable_count <= '0;
      link_ready_q <= 1'b0;
    end else begin
      tx_active_meta <= tx_active[0];
      tx_active_sync <= tx_active_meta;
      health_meta <= health_raw;
      health_sync <= health_meta;
      if (!tx_active_sync || !(&health_sync)) begin
        health_stable_count <= '0;
        link_ready_q <= 1'b0;
      end else if (!link_ready_q) begin
        if (health_stable_count == 4'd15) link_ready_q <= 1'b1;
        else health_stable_count <= health_stable_count + 1'b1;
      end
    end
  end
  assign link_ready = link_ready_q;
  assign pa_enable = pa_enable_request && tx_active[0] && (&health_raw) && reset_n;

  // link_ready_q asynchronously asserts local data-domain resets on global
  // reset or after synchronized GT-health loss; each domain releases locally.
  dsm_reset_sync u_rst125 (.clk(axi_clk125),
      .arst_n(link_ready_q), .srst_n(rst125_n));
  dsm_reset_sync u_rst218 (.clk(core_clk218),
      .arst_n(link_ready_q), .srst_n(rst218_n));
  always_ff @(posedge core_clk218 or negedge rst218_n) begin
    if (!rst218_n) run_sync <= '0;
    else run_sync <= {run_sync[0], run_request_axi};
  end

  tid32_thermo5_axis_frontend_tx #(
    .DPD_MAX_TAPS(1), .INTERP_TAPS(2), .BYPASS_DPD(1'b0),
    .FPGA_USE_XPM_FIFO(1'b1)
  ) u_frontend (
    .s_axis_aclk(axi_clk125), .s_axis_aresetn(rst125_n),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_frame_start),
    .s_axis_tuser_frame_gain(s_axis_frame_gain),
    .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk218), .core_aresetn(rst218_n),
    .core_enable(run_core),
    .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error),
    .dpd_active_taps(3'd1),
    .c1_re(64'h0000_0000_0000_4000), .c1_im(64'd0),
    .c3_re(64'd0), .c3_im(64'd0),
    .c5_re(64'd0), .c5_im(64'd0),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );

  thermo5_raw64_continuous_tx u_continuous (
    .clk(core_clk218), .rst_n(rst218_n),
    // The local reset-ready is the core-domain view of link readiness.
    .link_ready(rst218_n), .run_request(run_core),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready),
    .gt_txdata(tx_word), .pa_enable(pa_enable_request),
    .stream_fault(stream_fault)
  );
endmodule

`default_nettype wire
