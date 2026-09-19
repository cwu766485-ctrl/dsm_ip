`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// 1.75-GS/s complex ingress to the 7-GS/s / dual-PA TID transmitter.
//
// Fabric cadence is one 8-sample input word at 218.75 MHz.  The first x2
// creates 16 samples at 3.5 GS/s, where the vector memory DPD runs.  The
// second x2 creates the 32 consecutive samples consumed by the L=32 TIDSM.
// All interfaces use lane 0 as the earliest sample and preserve ready/valid
// word atomicity.  Coefficients are external because a physical PA feedback
// calibration is still required before non-identity DPD may be released.
//------------------------------------------------------------------------------
module tid32_thermo3_frontend_tx #(
  parameter int W = 16,
  parameter int IN_LANES = 8,
  parameter int DPD_LANES = 16,
  parameter int MAX_TAPS = 4,
  parameter int COEFF_W = 16,
  parameter int COEFF_FRAC = 14,
  parameter int THRESHOLD = 8192
) (
  input  wire logic                                      clk,
  input  wire logic                                      rst_n,
  input  wire logic                                      enable,
  input  wire logic                                      in_valid,
  output wire logic                                      in_ready,
  input  wire logic signed [IN_LANES*W-1:0]              in_i_vec,
  input  wire logic signed [IN_LANES*W-1:0]              in_q_vec,
  input  wire logic [2:0]                                dpd_active_taps,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c1_re, c1_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c3_re, c3_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c5_re, c5_im,
  output wire logic                                      pa_p_valid,
  output wire logic [63:0]                               pa_p_data,
  input  wire logic                                      pa_p_ready,
  output wire logic                                      pa_m_valid,
  output wire logic [63:0]                               pa_m_data,
  input  wire logic                                      pa_m_ready
);
  logic i1_valid, i1_ready, dpd_valid, dpd_ready, i2_valid, i2_ready;
  logic signed [DPD_LANES*W-1:0] i1_i, i1_q, dpd_i, dpd_q;
  logic signed [2*DPD_LANES*W-1:0] i2_i, i2_q;

  dsm_interp_x2_polyphase_vector #(.W(W), .LANES_IN(IN_LANES)) u_interp_1 (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(in_valid), .in_ready(in_ready), .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(i1_valid), .out_ready(i1_ready), .out_i_vec(i1_i), .out_q_vec(i1_q)
  );

  dpd_vector16_memory_poly #(
    .W(W), .LANES(DPD_LANES), .COEFF_W(COEFF_W), .COEFF_FRAC(COEFF_FRAC),
    .MAX_TAPS(MAX_TAPS)
  ) u_memory_dpd (
    .clk(clk), .rst_n(rst_n), .active_taps(dpd_active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im),
    .in_valid(i1_valid), .in_ready(i1_ready), .in_i_vec(i1_i), .in_q_vec(i1_q),
    .out_valid(dpd_valid), .out_ready(dpd_ready), .out_i_vec(dpd_i), .out_q_vec(dpd_q)
  );

  dsm_interp_x2_polyphase_vector #(.W(W), .LANES_IN(DPD_LANES)) u_interp_2 (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(dpd_valid), .in_ready(dpd_ready), .in_i_vec(dpd_i), .in_q_vec(dpd_q),
    .out_valid(i2_valid), .out_ready(i2_ready), .out_i_vec(i2_i), .out_q_vec(i2_q)
  );

  tid32_thermo3_fs4_multipa_tx #(.W(W), .CHANNELS(2*DPD_LANES), .THRESHOLD(THRESHOLD)) u_tid (
    .clk(clk), .rst_n(rst_n), .in_valid(i2_valid), .in_ready(i2_ready),
    .in_i_poly_vec(i2_i), .in_q_poly_vec(i2_q),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(pa_p_ready),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(pa_m_ready)
  );
endmodule

`default_nettype wire
