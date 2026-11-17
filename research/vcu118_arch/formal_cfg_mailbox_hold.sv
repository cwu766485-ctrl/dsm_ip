`timescale 1ns/1ps
`default_nettype none
// Common-reset, arbitrary-AXI traffic scope. This proves only a source-domain
// data hold relation; it does not prove CDC physical delay or reset independence.
module formal_cfg_mailbox_hold (
  input logic axil_clk, core_clk, rst_n,
  input logic [7:0] awaddr, araddr,
  input logic awvalid, wvalid, bready, arvalid, rready,
  input logic [31:0] wdata,
  input logic [3:0] wstrb,
  input logic boundary, tx_active, draining, switch_idle, source_locked
);
  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(1),.ENABLE_RUNTIME_DSM(1)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(),
    .s_axil_bresp(), .s_axil_bvalid(), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(),
    .s_axil_rdata(), .s_axil_rresp(), .s_axil_rvalid(), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(rst_n), .dpd_config_boundary(boundary),
    .core_tx_active(tx_active), .core_draining(draining), .core_enable(), .run_request(),
    .dpd_active_taps(), .c1_re(), .c1_im(), .c3_re(), .c3_im(), .c5_re(), .c5_im(),
    .cfg_busy(), .cfg_done(), .cfg_error(), .dsm_switch_idle(switch_idle),
    .dsm_source_locked(source_locked), .dsm_switch_pending(), .dsm_switch_busy(),
    .dsm_arch(), .dsm_reset_pulse(), .dsm_config_id()
  );
  a_cfg_mailbox_hold: assert property (@(posedge axil_clk) disable iff (!rst_n)
    dut.cfg_req_q |=> $stable(dut.cfg_mailbox_q));
  c_cfg_request: cover property (@(posedge axil_clk) disable iff (!rst_n) dut.cfg_req_q);
  c_cfg_ack: cover property (@(posedge core_clk) disable iff (!rst_n) dut.cfg_ack_core);
endmodule
`default_nettype wire
