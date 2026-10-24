`timescale 1ns/1ps
`default_nettype none

// Prospective four-GTH digital parent for the frozen thermo5 SKU. The board
// must supply an actual 125-MHz bank-128 MGTREFCLK before hardware use.
// The AXI-Stream, AXI-Lite, freerun clocks and board PA-blanking path are
// integration inputs;
// this module does not claim a tested physical RF output.
module thermo5_qsfp_gt14_parent #(
  parameter bit ENABLE_INTERNAL_PMA_LOOPBACK = 1'b0,
  parameter bit INTERP_CENTERED_CUBIC = 1'b0
) (
  input  wire logic        axi_clk125,
  input  wire logic        axil_clk100,
  input  wire logic        freerun_clk200,
  input  wire logic        reset_n,
  // Assert only after the AXIS and AXI-Lite clock sources are stable.
  input  wire logic        fabric_clocks_stable,
  input  wire logic        mgtrefclk125_p,
  input  wire logic        mgtrefclk125_n,
  input  wire logic [3:0]  qsfp_rx_p,
  input  wire logic [3:0]  qsfp_rx_n,
  output wire logic [3:0]  qsfp_tx_p,
  output wire logic [3:0]  qsfp_tx_n,
  input  wire logic        s_axis_tvalid,
  output wire logic        s_axis_tready,
  input  wire logic        s_axis_tlast,
  input  wire logic signed [223:0] s_axis_i_vec,
  input  wire logic signed [223:0] s_axis_q_vec,
  input  wire logic        s_axis_frame_start,
  input  wire logic signed [15:0] s_axis_frame_gain,
  input  wire logic [7:0]  s_axil_awaddr,
  input  wire logic        s_axil_awvalid,
  output wire logic        s_axil_awready,
  input  wire logic [31:0] s_axil_wdata,
  input  wire logic [3:0]  s_axil_wstrb,
  input  wire logic        s_axil_wvalid,
  output wire logic        s_axil_wready,
  output wire logic [1:0]  s_axil_bresp,
  output wire logic        s_axil_bvalid,
  input  wire logic        s_axil_bready,
  input  wire logic [7:0]  s_axil_araddr,
  input  wire logic        s_axil_arvalid,
  output wire logic        s_axil_arready,
  output wire logic [31:0] s_axil_rdata,
  output wire logic [1:0]  s_axil_rresp,
  output wire logic        s_axil_rvalid,
  input  wire logic        s_axil_rready,
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
  wire logic reset_freerun_n, rst125_n, axil_rst_n, rst218_n;
  (* ASYNC_REG = "TRUE" *) logic tx_active_meta, tx_active_sync;
  (* ASYNC_REG = "TRUE" *) logic [9:0] health_meta, health_sync;
  logic [3:0] health_stable_count;
  logic link_ready_q;
  // The GT Wizard's TX-active level is asynchronous to the free-running
  // control clock and may change when the TX user clock is stopped. Sample it
  // as data through a two-flop synchronizer here; do not use a status crossing
  // as an asynchronous-clear pin on the synchronizer or health state.
  wire logic [9:0] health_raw = {fabric_clocks_stable, tx_done, powergood, tx_pma_done};
  wire logic pa_enable_request;
  wire logic core_run_request;
  wire logic core_tx_active;
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

  // Synchronize fabric-clock stability and GT health into the free-running
  // reset-control domain, then require a stable interval before releasing all
  // three application domains.
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

  // link_ready_q is the reset-controller release request. Each independent
  // clock domain asynchronously asserts and locally synchronizes reset
  // deassertion; AXI-Lite state also resets on common reset or GT loss.
  dsm_reset_sync u_rst125 (.clk(axi_clk125),
      .arst_n(link_ready_q), .srst_n(rst125_n));
  dsm_reset_sync u_rst_axil (.clk(axil_clk100),
      .arst_n(link_ready_q), .srst_n(axil_rst_n));
  dsm_reset_sync u_rst218 (.clk(core_clk218),
      .arst_n(link_ready_q), .srst_n(rst218_n));

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    // Keep the parent on the frozen one-tap thermo5 SKU by default. The
    // optional centered-cubic interpolator remains explicitly selectable;
    // AXI-Lite owns the active DPD image.
    .DPD_MAX_TAPS(1), .INTERP_TAPS(2), .BYPASS_DPD(1'b0),
    .INTERP_CENTERED_CUBIC(INTERP_CENTERED_CUBIC), .FPGA_USE_XPM_FIFO(1'b1)
  ) u_frontend (
    .s_axil_aclk(axil_clk100), .s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(s_axil_awaddr), .s_axil_awvalid(s_axil_awvalid), .s_axil_awready(s_axil_awready),
    .s_axil_wdata(s_axil_wdata), .s_axil_wstrb(s_axil_wstrb), .s_axil_wvalid(s_axil_wvalid), .s_axil_wready(s_axil_wready),
    .s_axil_bresp(s_axil_bresp), .s_axil_bvalid(s_axil_bvalid), .s_axil_bready(s_axil_bready),
    .s_axil_araddr(s_axil_araddr), .s_axil_arvalid(s_axil_arvalid), .s_axil_arready(s_axil_arready),
    .s_axil_rdata(s_axil_rdata), .s_axil_rresp(s_axil_rresp), .s_axil_rvalid(s_axil_rvalid), .s_axil_rready(s_axil_rready),
    .s_axis_aclk(axi_clk125), .s_axis_aresetn(rst125_n),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_frame_start),
    .s_axis_tuser_frame_gain(s_axis_frame_gain),
    .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk218), .core_aresetn(rst218_n),
    .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error),
    .core_run_request(core_run_request),
    .core_tx_active(core_tx_active),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );

  thermo5_raw64_continuous_tx u_continuous (
    .clk(core_clk218), .rst_n(rst218_n),
    // The local reset-ready is the core-domain view of link readiness.
    .link_ready(rst218_n), .run_request(core_tx_active),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready),
    .gt_txdata(tx_word), .pa_enable(pa_enable_request),
    .stream_fault(stream_fault)
  );
endmodule

`default_nettype wire
