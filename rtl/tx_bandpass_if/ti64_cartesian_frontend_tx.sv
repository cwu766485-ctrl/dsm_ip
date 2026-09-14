//------------------------------------------------------------------------------
// 64-lane Cartesian frontend for the TI64 LP1 Fs/4 transmitter.
//
// Contract at this boundary: one accepted word contains 64 consecutive complex
// samples at the already-interpolated 14-GS/s rate.  Each lane uses the shipped
// memoryless polynomial DPD implementation; the real IF packer then produces
// [I, Q, -I, -Q] across every four consecutive samples before TI64 quantizes.
//
// This is deliberately an x1 interpolation integration point.  The existing
// dsm_interp_frontend is scalar and cannot provide 64 output samples per
// 218.75-MHz clock for an interpolation ratio greater than one.  A non-x1
// TI64 interpolator must be a separately verified 64-phase polyphase block.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module ti64_cartesian_frontend_tx #(
  parameter int W = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1,
  parameter int DPD_COEFF_W = 16,
  parameter int DPD_COEFF_FRAC = 14
) (
  input  wire logic                      clk,
  input  wire logic                      rst_n,
  input  wire logic                      in_valid,
  output wire logic                      in_ready,
  input  wire logic signed [64*W-1:0]    in_i_vec,
  input  wire logic signed [64*W-1:0]    in_q_vec,

  // The replicated DPD supports bypass (0) and memoryless polynomial (1).
  // LUT and memory-polynomial requests fall back to bypass in dpd_frontend.
  input  wire logic [1:0]                dpd_mode,
  input  wire logic signed [DPD_COEFF_W-1:0] c1_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c1_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c3_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c3_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c5_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c5_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c7_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c7_im,
  output wire logic [1:0]                dpd_effective_mode,

  output wire logic                      gt_valid,
  input  wire logic                      gt_ready,
  output wire logic [63:0]               gt_data
);
  localparam int LANES = 64;

  wire logic [LANES-1:0] dpd_in_ready;
  wire logic [LANES-1:0] dpd_out_valid;
  wire logic [LANES-1:0] interp_in_ready;
  wire logic [LANES-1:0] interp_out_valid;
  wire logic signed [LANES*W-1:0] dpd_i_vec;
  wire logic signed [LANES*W-1:0] dpd_q_vec;
  wire logic signed [LANES*W-1:0] interp_i_vec;
  wire logic signed [LANES*W-1:0] interp_q_vec;
  logic signed [LANES*W-1:0] real_if_vec;
  wire logic ti64_in_ready;
  wire logic [2*LANES-1:0] dpd_effective_mode_lanes;

  // Every lane has the same ready/valid contract.  ANDing ready prevents an
  // accidental partial vector acceptance if a future lane implementation
  // acquires a different latency or stall condition.
  assign in_ready = &dpd_in_ready;
  assign dpd_effective_mode = dpd_effective_mode_lanes[1:0];

  for (genvar lane = 0; lane < LANES; lane = lane + 1) begin : g_lane_frontend
    // The DPD polynomial has no temporal taps and can therefore be replicated
    // across interleaved lanes without changing its per-sample arithmetic.
    dpd_frontend #(
      .W(W), .COEFF_W(DPD_COEFF_W), .COEFF_FRAC(DPD_COEFF_FRAC),
      .ENABLE_DPD_POLY(1), .ENABLE_DPD_LUT(0), .ENABLE_DPD_MEMORY(0)
    ) u_dpd (
      .clk(clk), .rst_n(rst_n), .mode(dpd_mode),
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
      .in_valid(in_valid), .in_ready(dpd_in_ready[lane]),
      .i_out(dpd_i_vec[lane*W +: W]), .q_out(dpd_q_vec[lane*W +: W]),
      .out_valid(dpd_out_valid[lane]), .out_ready(interp_in_ready[lane]),
      .effective_mode_out(dpd_effective_mode_lanes[lane*2 +: 2]),
      .busy(), .sample_count(), .saturation_count()
    );

    // This explicit x1 instance preserves the existing interpolation
    // interface and backpressure semantics without making an unsupported
    // claim about x4/x8/x16/x32 vector interpolation.
    dsm_interp_frontend #(
      .W_IN(W), .W_OUT(W), .INTERP_MODE(0), .INTERP_IMPL(0)
    ) u_interp_x1 (
      .clk(clk), .rst_n(rst_n), .enable(1'b1),
      .i_in(dpd_i_vec[lane*W +: W]), .q_in(dpd_q_vec[lane*W +: W]),
      .in_valid(dpd_out_valid[lane]), .in_ready(interp_in_ready[lane]),
      .i_out(interp_i_vec[lane*W +: W]), .q_out(interp_q_vec[lane*W +: W]),
      .out_valid(interp_out_valid[lane]), .out_ready(ti64_in_ready)
    );

    always_comb begin
      unique case (lane % 4)
        0: real_if_vec[lane*W +: W] = interp_i_vec[lane*W +: W];
        1: real_if_vec[lane*W +: W] = interp_q_vec[lane*W +: W];
        2: real_if_vec[lane*W +: W] = -interp_i_vec[lane*W +: W];
        default: real_if_vec[lane*W +: W] = -interp_q_vec[lane*W +: W];
      endcase
    end
  end

  ti64_lp1_fs4_gt_tx #(
    .W_IN(W), .ACC_W(ACC_W), .SATURATE(SATURATE)
  ) u_ti64 (
    .clk(clk), .rst_n(rst_n), .in_valid(interp_out_valid[0]),
    .in_ready(ti64_in_ready), .in_x_vec(real_if_vec),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data)
  );
endmodule

`default_nettype wire
