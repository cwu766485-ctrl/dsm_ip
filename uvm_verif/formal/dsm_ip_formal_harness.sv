`timescale 1ns/1ps
`default_nettype none

module dsm_ip_formal_harness (
  input logic aclk,
  input logic aresetn,
  input logic [8:0] s_axi_awaddr,
  input logic s_axi_awvalid,
  input logic [31:0] s_axi_wdata,
  input logic [3:0] s_axi_wstrb,
  input logic s_axi_wvalid,
  input logic s_axi_bready,
  input logic [8:0] s_axi_araddr,
  input logic s_axi_arvalid,
  input logic s_axi_rready,
  input logic [31:0] s_axis_tdata,
  input logic s_axis_tlast,
  input logic s_axis_tuser,
  input logic s_axis_tvalid,
  input logic [31:0] s_axis_obs_tdata,
  input logic s_axis_obs_tlast,
  input logic s_axis_obs_tuser,
  input logic s_axis_obs_tvalid
);
  logic s_axi_awready;
  logic s_axi_wready;
  logic [1:0] s_axi_bresp;
  logic s_axi_bvalid;
  logic s_axi_arready;
  logic [31:0] s_axi_rdata;
  logic [1:0] s_axi_rresp;
  logic s_axi_rvalid;
  logic s_axis_tready;
  logic s_axis_obs_tready;
  logic obs_irq;
  logic dsm_valid;
  logic i_bit;
  logic q_bit;
  logic signed [7:0] i_yout;
  logic signed [7:0] q_yout;
  logic rf_valid;
  logic rf_bit;
  logic signed [15:0] rf_signed;
  logic [23:0] phase_acc_dbg;

  dsm_ip_axi_top #(
    .ALGORITHM(3),
    .DUC_MODE(3),
    // The arithmetic-heavy interpolation path is covered by bit-true
    // simulation.  Bypass it here so FPV can exhaustively prove the AXI,
    // reset and coefficient-bank control logic without an irrelevant CIC
    // state-space explosion.
    .INTERP_MODE(0),
    .INTERP_IMPL(1),
    .ENABLE_DPD_POLY(1),
    .ENABLE_DPD_LUT(0),
    .ENABLE_DPD_MEMORY(1),
    .DPD_MP_MAX_TAPS(4),
    .DPD_POLY_ORDER(5),
    .CLK_FREQ_HZ(100000000)
  ) dut (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr),
    .s_axi_awvalid(s_axi_awvalid),
    .s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),
    .s_axi_wstrb(s_axi_wstrb),
    .s_axi_wvalid(s_axi_wvalid),
    .s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),
    .s_axi_bvalid(s_axi_bvalid),
    .s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),
    .s_axi_arvalid(s_axi_arvalid),
    .s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(s_axi_rresp),
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser(s_axis_tuser),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_obs_tdata(s_axis_obs_tdata),
    .s_axis_obs_tlast(s_axis_obs_tlast),
    .s_axis_obs_tuser(s_axis_obs_tuser),
    .s_axis_obs_tvalid(s_axis_obs_tvalid),
    .s_axis_obs_tready(s_axis_obs_tready),
    .obs_irq(obs_irq),
    .dsm_valid(dsm_valid),
    .i_bit(i_bit),
    .q_bit(q_bit),
    .i_yout(i_yout),
    .q_yout(q_yout),
    .rf_valid(rf_valid),
    .rf_bit(rf_bit),
    .rf_signed(rf_signed),
    .phase_acc_dbg(phase_acc_dbg)
  );

  default clocking cb @(posedge aclk); endclocking

  // The formal environment is an AXI/AXI-Stream master. It must preserve
  // valid and payload while the DUT applies backpressure.
  asm_aw_stable: assume property (
    disable iff (!aresetn)
    s_axi_awvalid && !s_axi_awready
      |=> s_axi_awvalid && $stable(s_axi_awaddr));
  asm_w_stable: assume property (
    disable iff (!aresetn)
    s_axi_wvalid && !s_axi_wready
      |=> s_axi_wvalid && $stable({s_axi_wdata, s_axi_wstrb}));
  asm_ar_stable: assume property (
    disable iff (!aresetn)
    s_axi_arvalid && !s_axi_arready
      |=> s_axi_arvalid && $stable(s_axi_araddr));
  asm_tx_stable: assume property (
    disable iff (!aresetn)
    s_axis_tvalid && !s_axis_tready
      |=> s_axis_tvalid && $stable({s_axis_tdata, s_axis_tuser, s_axis_tlast}));
  asm_obs_stable: assume property (
    disable iff (!aresetn)
    s_axis_obs_tvalid && !s_axis_obs_tready
      |=> s_axis_obs_tvalid &&
          $stable({s_axis_obs_tdata, s_axis_obs_tuser, s_axis_obs_tlast}));

  // DUT-owned AXI response channels must remain stable under backpressure.
  ast_b_stable: assert property (
    disable iff (!aresetn)
    s_axi_bvalid && !s_axi_bready
      |=> s_axi_bvalid && $stable(s_axi_bresp));
  ast_r_stable: assert property (
    disable iff (!aresetn)
    s_axi_rvalid && !s_axi_rready
      |=> s_axi_rvalid && $stable({s_axi_rdata, s_axi_rresp}));

  dsm_rf_protocol_sva rf_sva (
    .aclk(aclk),
    .aresetn(aresetn),
    .rf_valid(rf_valid),
    .rf_bit(rf_bit),
    .rf_signed(rf_signed)
  );

  dsm_ip_control_sva control_sva (
    .aclk(aclk),
    .aresetn(aresetn),
    .soft_reset(dut.soft_reset),
    .s_axis_tready(s_axis_tready),
    .axis_buf_valid(dut.axis_buf_valid),
    .rf_valid(rf_valid),
    .mp_commit_pending(dut.mp_commit_pending),
    .mp_commit_inflight(dut.mp_commit_inflight),
    .mp_commit_pulse(dut.mp_commit_pulse),
    .mp_commit_success_event(dut.mp_commit_success_event),
    .mp_commit_ack(dut.mp_commit_ack),
    .mp_commit_failed(dut.mp_commit_failed),
    .mp_commit_epoch(dut.mp_commit_epoch),
    .mp_active_bank(dut.mp_active_bank),
    .obs_enable(dut.obs_enable_reg),
    .obs_active(dut.obs_active),
    .obs_ready(s_axis_obs_tready)
  );
endmodule

`default_nettype wire
