`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Coherent 16-sample vector wrapper for the shipped DPD frontend.
//
// A word represents 16 consecutive complex samples.  Bypass and memoryless
// polynomial modes have no inter-sample dependency, so all 16 scalar engines
// may operate in parallel.  LUT and memory-polynomial modes are deliberately
// disabled here: the former needs a defined vector read/configuration-bank
// contract and the latter needs a temporal history hand-off at word boundaries.
//------------------------------------------------------------------------------
module dpd_vector16_frontend #(
  parameter int W = 16,
  parameter int LANES = 16,
  parameter int COEFF_W = 16,
  parameter int COEFF_FRAC = 14
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic [1:0]                   mode,
  input  wire logic signed [COEFF_W-1:0]    c1_re,
  input  wire logic signed [COEFF_W-1:0]    c1_im,
  input  wire logic signed [COEFF_W-1:0]    c3_re,
  input  wire logic signed [COEFF_W-1:0]    c3_im,
  input  wire logic signed [COEFF_W-1:0]    c5_re,
  input  wire logic signed [COEFF_W-1:0]    c5_im,
  input  wire logic signed [COEFF_W-1:0]    c7_re,
  input  wire logic signed [COEFF_W-1:0]    c7_im,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [LANES*W-1:0]    in_i_vec,
  input  wire logic signed [LANES*W-1:0]    in_q_vec,
  output wire logic                         out_valid,
  input  wire logic                         out_ready,
  output wire logic signed [LANES*W-1:0]    out_i_vec,
  output wire logic signed [LANES*W-1:0]    out_q_vec,
  output wire logic [1:0]                   effective_mode_out,
  output wire logic                         busy
);
  wire logic [LANES-1:0] lane_in_ready;
  wire logic [LANES-1:0] lane_out_valid;
  wire logic [LANES-1:0] lane_busy;
  wire logic [LANES*2-1:0] lane_effective_mode;

  assign in_ready = &lane_in_ready;
  assign out_valid = &lane_out_valid;
  assign effective_mode_out = lane_effective_mode[1:0];
  assign busy = |lane_busy;

  for (genvar lane = 0; lane < LANES; lane = lane + 1) begin : g_dpd
    dpd_frontend #(
      .W(W), .COEFF_W(COEFF_W), .COEFF_FRAC(COEFF_FRAC),
      .ENABLE_DPD_POLY(1), .ENABLE_DPD_LUT(0), .ENABLE_DPD_MEMORY(0)
    ) u_dpd (
      .clk(clk), .rst_n(rst_n), .mode(mode),
      .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
      .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
      .mp_active_taps(3'd0), .mp_coeff_we(1'b0), .mp_commit(1'b0),
      .mp_coeff_tap(3'd0), .mp_coeff_order(2'd0),
      .mp_coeff_re('0), .mp_coeff_im('0), .mp_coeff_rdata_re(),
      .mp_coeff_rdata_im(), .mp_active_bank(),
      .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr('0),
      .lut_wgain_re('0), .lut_wgain_im('0), .lut_raddr('0),
      .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
      .safety_enable(1'b0), .safety_clear(1'b0), .safety_fault(),
      .mp_commit_rejected(), .lut_commit_rejected(),
      .i_in(in_i_vec[lane*W +: W]), .q_in(in_q_vec[lane*W +: W]),
      .in_valid(in_valid), .in_ready(lane_in_ready[lane]),
      .i_out(out_i_vec[lane*W +: W]), .q_out(out_q_vec[lane*W +: W]),
      .out_valid(lane_out_valid[lane]), .out_ready(out_ready),
      .effective_mode_out(lane_effective_mode[lane*2 +: 2]),
      .busy(lane_busy[lane]), .sample_count(), .saturation_count()
    );
  end
endmodule

`default_nettype wire
