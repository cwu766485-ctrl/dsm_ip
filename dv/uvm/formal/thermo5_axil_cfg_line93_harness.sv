`timescale 1ns/1ps
`default_nettype none

// Exact AXI-Lite configuration-block reachability check for the unhit
// write_fire condition tuple at thermo5_dpd_axi_lite_cfg.sv:93.
module thermo5_axil_cfg_line93_harness (
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
  logic awready, wready, bvalid;
  logic [1:0] bresp;
  logic arready, rvalid;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic core_enable, cfg_busy, cfg_done, cfg_error;
  logic run_request;
  logic [2:0] active_taps;
  logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(1)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid),
    .s_axil_wready(wready), .s_axil_bresp(bresp), .s_axil_bvalid(bvalid),
    .s_axil_bready(bready), .s_axil_araddr(araddr), .s_axil_arvalid(arvalid),
    .s_axil_arready(arready), .s_axil_rdata(rdata), .s_axil_rresp(rresp),
    .s_axil_rvalid(rvalid), .s_axil_rready(rready), .core_clk(core_clk),
    .core_aresetn(core_rst_n), .dpd_config_boundary(dpd_config_boundary),
    .core_tx_active(1'b0), .core_draining(1'b0), .core_enable(core_enable),
    .run_request(run_request), .dpd_active_taps(active_taps), .c1_re(c1_re),
    .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re),
    .c5_im(c5_im), .cfg_busy(cfg_busy), .cfg_done(cfg_done),
    .cfg_error(cfg_error)
  );

  default clocking axil_cb @(posedge axil_clk); endclocking

  // Raw bin 93:0/1/1 corresponds to BVALID=1 and both buffered/take terms=1.
  // BVALID is reachable; prove that the two terms cannot simultaneously hold.
  a_bvalid_excludes_line93_tuple:
    assert property (disable iff (!axil_rst_n)
      bvalid |-> !((dut.aw_pending || dut.aw_take) &&
                   (dut.w_pending || dut.w_take)));

  c_write_response_active:
    cover property (disable iff (!axil_rst_n) bvalid);
  c_write_fire:
    cover property (disable iff (!axil_rst_n) dut.write_fire);
  c_line93_uncovered_tuple:
    cover property (disable iff (!axil_rst_n)
      bvalid && (dut.aw_pending || dut.aw_take) &&
      (dut.w_pending || dut.w_take));
endmodule

`default_nettype wire
