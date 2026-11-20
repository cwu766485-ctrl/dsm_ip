`timescale 1ns/1ps
`default_nettype none
// Independent AXI-Lite and Core reset model. Clock periods remain an explicit
// formal abstraction; no phase or reset-traffic assumption is added beyond
// initializing both resets before proof starts.
module formal_cfg_mailbox_candidate3_independent_v3 (
  input logic axil_clk, core_clk, axil_rst_n, core_rst_n, formal_por_n,
  input logic [7:0] awaddr, araddr,
  input logic awvalid, wvalid, bready, arvalid, rready,
  input logic [31:0] wdata,
  input logic [3:0] wstrb,
  input logic boundary, tx_active, draining, switch_idle, source_locked
);
  localparam logic [386:0] DEFAULT_CFG = {3'd1,64'h0000_0000_0000_4000,
      64'd0,64'd0,64'd0,64'd0,64'd0};

  wire logic axil_effective_rst_n = formal_por_n && axil_rst_n;
  wire logic core_effective_rst_n = formal_por_n && core_rst_n;
  thermo5_dpd_axi_lite_cfg_epoch_candidate3 #(.MAX_TAPS(1),.ENABLE_RUNTIME_DSM(1)) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(axil_effective_rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(),
    .s_axil_bresp(), .s_axil_bvalid(), .s_axil_bready(bready),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(),
    .s_axil_rdata(), .s_axil_rresp(), .s_axil_rvalid(), .s_axil_rready(rready),
    .core_clk(core_clk), .core_aresetn(core_effective_rst_n), .dpd_config_boundary(boundary),
    .core_tx_active(tx_active), .core_draining(draining), .core_enable(), .run_request(),
    .dpd_active_taps(), .c1_re(), .c1_im(), .c3_re(), .c3_im(), .c5_re(), .c5_im(),
    .cfg_busy(), .cfg_done(), .cfg_error(), .dsm_switch_idle(switch_idle),
    .dsm_source_locked(source_locked), .dsm_switch_pending(), .dsm_switch_busy(),
    .dsm_arch(), .dsm_reset_pulse(), .dsm_config_id()
  );

  // The formal-only POR establishes known DUT state, then the two real reset
  // inputs remain unconstrained and can assert independently at any time.
  a_aw_held_when_stalled: assume property (@(posedge axil_clk)
    disable iff (!axil_rst_n) awvalid && !dut.s_axil_awready |=> awvalid && $stable(awaddr));
  a_w_held_when_stalled: assume property (@(posedge axil_clk)
    disable iff (!axil_rst_n) wvalid && !dut.s_axil_wready |=>
      wvalid && $stable(wdata) && $stable(wstrb));
  a_ar_held_when_stalled: assume property (@(posedge axil_clk)
    disable iff (!axil_rst_n) arvalid && !dut.s_axil_arready |=> arvalid && $stable(araddr));

  logic await_fresh_request;
  always_ff @(posedge core_clk or negedge axil_rst_n or negedge core_rst_n) begin
    if (!axil_rst_n || !core_rst_n) await_fresh_request <= 1'b1;
    else if (dut.cfg_req_q) await_fresh_request <= 1'b0;
  end

  a_cfg_mailbox_hold: assert property (@(posedge axil_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    dut.cfg_req_q |=> $stable(dut.cfg_mailbox_q));
  a_capture_matches: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    (dut.cfg_req_sync2 && !dut.cfg_ack_core && !dut.cfg_pending_valid) |=>
       (dut.cfg_pending_valid && dut.cfg_pending_core == $past(dut.cfg_mailbox_q)));
  a_sample_stable: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_core_n)
    (dut.cfg_req_sync2 && !dut.cfg_ack_core && !dut.cfg_pending_valid) |=>
       $stable(dut.cfg_mailbox_q));
  a_boundary_bundle: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    (dut.cfg_pending_valid && boundary) |-> (dut.cfg_for_dpd == dut.cfg_pending_core));
  a_active_update: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    (dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary) |=>
      (dut.cfg_active_core == $past(dut.cfg_pending_core) && dut.cfg_ack_core));
  a_active_stable: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    !(dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary) |=> $stable(dut.cfg_active_core));
  a_ack_after_apply: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    $rose(dut.cfg_ack_core) |-> $past(dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary));

  a_epoch_reset_clears_pending: assert property (@(posedge core_clk)
    !dut.cfg_epoch_core_n |-> (!dut.cfg_pending_valid && dut.cfg_active_core == DEFAULT_CFG));
  a_reset_requires_fresh_request: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_core_n)
    (await_fresh_request && !dut.cfg_req_q) |->
      (!dut.cfg_pending_valid && dut.cfg_active_core == DEFAULT_CFG));
  a_axil_response_survives_core_reset: assert property (@(posedge axil_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    (dut.s_axil_bvalid && !bready) |=>
      (dut.s_axil_bvalid && $stable(dut.s_axil_bresp)));
  a_pending_bank_atomic: assert property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    dut.cfg_active_core != $past(dut.cfg_active_core) |->
      $past(dut.cfg_pending_valid && boundary && dut.cfg_req_sync2));

  c_cfg_apply: cover property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    dut.cfg_req_sync2 && dut.cfg_pending_valid && boundary);
  c_axil_reset_with_pending: cover property (@(posedge axil_clk)
    dut.cfg_busy_q ##1 !axil_rst_n);
  c_core_reset_with_held_b: cover property (@(posedge axil_clk)
    axil_rst_n && dut.s_axil_bvalid && !bready ##1 !core_rst_n);
  c_restart_new_request: cover property (@(posedge core_clk)
    disable iff (!dut.cfg_epoch_axil_n)
    await_fresh_request ##[1:8] dut.cfg_req_sync2);
endmodule
`default_nettype wire
