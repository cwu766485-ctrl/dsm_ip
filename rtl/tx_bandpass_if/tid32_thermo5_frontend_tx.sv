`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Full five-level 14-GS/s frontend at a 218.75-MHz word cadence.
//
// 8 complex samples -> frame gain -> x2 -> identity-capable vector DPD ->
// x2 -> 32 complex samples -> four aligned Fs/4 raw code planes.
// Lane 0 is always the earliest sample.  The four outputs are code planes;
// they are not a claim of four physically routed GTH lanes.
//------------------------------------------------------------------------------
module tid32_thermo5_frontend_tx #(
  parameter int W = 16,
  parameter int IN_LANES = 8,
  parameter int DPD_LANES = 16,
  parameter int MAX_TAPS = 4,
  parameter int COEFF_W = 16,
  parameter int COEFF_FRAC = 14,
  parameter int GAIN_W = 16,
  parameter int GAIN_FRAC = 14,
  parameter int STEP = 7168
) (
  input  wire logic                                      clk,
  input  wire logic                                      rst_n,
  input  wire logic                                      enable,
  input  wire logic                                      in_valid,
  output wire logic                                      in_ready,
  input  wire logic                                      in_frame_start,
  input  wire logic signed [GAIN_W-1:0]                  in_frame_gain,
  input  wire logic signed [IN_LANES*W-1:0]              in_i_vec,
  input  wire logic signed [IN_LANES*W-1:0]              in_q_vec,
  input  wire logic [2:0]                                dpd_active_taps,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c1_re, c1_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c3_re, c3_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c5_re, c5_im,
  output wire logic [3:0]                                pa_valid,
  output wire logic [63:0]                               pa_data [0:3],
  input  wire logic [3:0]                                pa_ready
);
  logic gain_valid, gain_ready, i1_valid, i1_ready, dpd_valid, dpd_ready, i2_valid, i2_ready;
  logic signed [IN_LANES*W-1:0] gain_i, gain_q;
  logic signed [DPD_LANES*W-1:0] i1_i, i1_q, dpd_i, dpd_q;
  logic signed [2*DPD_LANES*W-1:0] i2_i, i2_q;

  dsm_frame_gain_vector #(
    .W(W), .LANES(IN_LANES), .GAIN_W(GAIN_W), .GAIN_FRAC(GAIN_FRAC)
  ) u_frame_gain (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(in_valid), .in_ready(in_ready),
    .in_frame_start(in_frame_start), .in_frame_gain(in_frame_gain),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(gain_valid), .out_ready(gain_ready), .out_i_vec(gain_i), .out_q_vec(gain_q)
  );

  dsm_interp_x2_polyphase_vector #(.W(W), .LANES_IN(IN_LANES)) u_interp_1 (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .in_valid(gain_valid), .in_ready(gain_ready), .in_i_vec(gain_i), .in_q_vec(gain_q),
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

  tid32_thermo5_fs4_multipa_tx #(.W(W), .CHANNELS(2*DPD_LANES), .STEP(STEP)) u_tid (
    .clk(clk), .rst_n(rst_n), .in_valid(i2_valid), .in_ready(i2_ready),
    .in_i_poly_vec(i2_i), .in_q_poly_vec(i2_q),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
endmodule

`default_nettype wire
