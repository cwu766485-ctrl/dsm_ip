`timescale 1ns/1ps
`default_nettype none

module thermo5_axil_cfg_coverage_harness (
  input logic axil_clk,
  input logic axil_rst_n,
  input logic core_clk,
  input logic core_rst_n,
  input logic [7:0] awaddr,
  input logic awvalid,
  input logic [31:0] wdata,
  input logic [3:0] wstrb,
  input logic wvalid,
  input logic bready,
  input logic [7:0] araddr,
  input logic arvalid,
  input logic rready,
  input logic dpd_config_boundary
);
  logic awready;
  logic wready;
  logic [1:0] bresp;
  logic bvalid;
  logic arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic core_enable;
  logic [2:0] active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;
  logic cfg_busy, cfg_done, cfg_error;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(4)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(core_rst_n),
    .dpd_config_boundary(dpd_config_boundary), .core_enable(core_enable),
    .dpd_active_taps(active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  // These properties are deliberately bound to the production RTL instance.
  // They justify only the exact condition bins named in the coverage ledger.
  a_bvalid_clears_pending:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      bvalid |-> (!dut.aw_pending && !dut.w_pending));

  a_line88_tuple_unreachable:
    assert property (@(posedge axil_clk) disable iff (!axil_rst_n)
      !(bvalid && (dut.aw_pending || dut.aw_take) && (dut.w_pending || dut.w_take)));

  a_pending_requires_request:
    assert property (@(posedge core_clk) disable iff (!core_rst_n)
      dut.cfg_pending_valid |-> dut.cfg_req_sync2);

  a_line315_011_unreachable:
    assert property (@(posedge core_clk) disable iff (!core_rst_n)
      !(!dut.cfg_req_sync2 && dut.cfg_pending_valid && dpd_config_boundary));
endmodule

`default_nettype wire
