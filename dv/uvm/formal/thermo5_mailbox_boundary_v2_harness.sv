`timescale 1ns/1ps
`default_nettype none
// Overapproximate external traffic: no AXI protocol or boundary assumptions.
// Saved common-reset state only. MAX_TAPS matches the frozen product instance.
module thermo5_mailbox_boundary_v2_harness (
  input logic axil_clk, core_clk, rst_n,
  input logic [7:0] awaddr, araddr,
  input logic awvalid, wvalid, bready, arvalid, rready,
  input logic [31:0] wdata,
  input logic [3:0] wstrb,
  input logic boundary, tx_active, draining
);
  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(1)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(),
    .s_axil_bresp(), .s_axil_bvalid(), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(),
    .s_axil_rdata(), .s_axil_rresp(), .s_axil_rvalid(), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(rst_n), .dpd_config_boundary(boundary),
    .core_tx_active(tx_active), .core_draining(draining), .core_enable(), .run_request(),
    .dpd_active_taps(), .c1_re(), .c1_im(), .c3_re(), .c3_im(), .c5_re(), .c5_im(),
    .cfg_busy(), .cfg_done(), .cfg_error()
  );
  a_pending_requires_request: assert property (@(posedge core_clk) disable iff (!rst_n)
    dut.cfg_pending_valid |-> dut.cfg_req_sync2);
  // TXB-a8041f215017e6e9b5f5, procedural line333 tuple0/1/1.
  c_exact_line333: cover property (@(posedge core_clk) disable iff (!rst_n)
    !dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary);
  c_pending: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.cfg_req_sync2 && dut.cfg_pending_valid && !boundary);
  c_apply: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary);
  c_return_to_idle: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.cfg_ack_core ##[1:16] (!dut.cfg_req_sync2 && !dut.cfg_pending_valid));
endmodule
`default_nettype wire
