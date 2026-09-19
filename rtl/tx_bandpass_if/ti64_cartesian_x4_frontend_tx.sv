`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Cartesian x4 frontend for the TI64 Fs/4 transmitter.
//
// One accepted 16-lane input word contains consecutive baseband I/Q samples.
// Vector DPD is applied before the x4 interpolation.  The polyphase block
// produces 64 consecutive I/Q samples. TI64 receives the baseband-interleaved
// [I, Q, I, Q] sequence and applies the sole +,+,-,- Fs/4 translation at its
// one-bit output. Applying signs here as well would cancel that translation.
//------------------------------------------------------------------------------
module ti64_cartesian_x4_frontend_tx #(
  parameter int W = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1,
  parameter int DPD_COEFF_W = 16,
  parameter int DPD_COEFF_FRAC = 14
) (
  input  wire logic                       clk,
  input  wire logic                       rst_n,
  input  wire logic                       in_valid,
  output wire logic                       in_ready,
  input  wire logic signed [16*W-1:0]     in_i_vec,
  input  wire logic signed [16*W-1:0]     in_q_vec,
  input  wire logic [1:0]                 dpd_mode,
  input  wire logic signed [DPD_COEFF_W-1:0] c1_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c1_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c3_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c3_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c5_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c5_im,
  input  wire logic signed [DPD_COEFF_W-1:0] c7_re,
  input  wire logic signed [DPD_COEFF_W-1:0] c7_im,
  output wire logic [1:0]                 dpd_effective_mode,
  output wire logic                       gt_valid,
  input  wire logic                       gt_ready,
  output wire logic [63:0]                gt_data
);
  localparam int LANES_IN = 16;
  localparam int LANES_OUT = 64;

  wire logic dpd_out_valid;
  wire logic dpd_out_ready;
  wire logic signed [LANES_IN*W-1:0] dpd_i_vec;
  wire logic signed [LANES_IN*W-1:0] dpd_q_vec;
  wire logic interp_out_valid;
  wire logic interp_out_ready;
  wire logic signed [LANES_OUT*W-1:0] interp_i_vec;
  wire logic signed [LANES_OUT*W-1:0] interp_q_vec;
  logic signed [LANES_OUT*W-1:0] ti_baseband_vec;
  wire logic ti64_in_ready;

  dpd_vector16_frontend #(
    .W(W), .LANES(LANES_IN), .COEFF_W(DPD_COEFF_W),
    .COEFF_FRAC(DPD_COEFF_FRAC)
  ) u_vector_dpd (
    .clk(clk), .rst_n(rst_n), .mode(dpd_mode),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec),
    .out_valid(dpd_out_valid), .out_ready(dpd_out_ready),
    .out_i_vec(dpd_i_vec), .out_q_vec(dpd_q_vec),
    .effective_mode_out(dpd_effective_mode), .busy()
  );

  dsm_interp_x4_polyphase16 #(
    .W_IN(W), .W_OUT(W), .LANES_IN(LANES_IN), .INTERP(4)
  ) u_x4_polyphase (
    .clk(clk), .rst_n(rst_n), .enable(1'b1),
    .in_valid(dpd_out_valid), .in_ready(dpd_out_ready),
    .in_i_vec(dpd_i_vec), .in_q_vec(dpd_q_vec),
    .out_i_vec(interp_i_vec), .out_q_vec(interp_q_vec),
    .out_valid(interp_out_valid), .out_ready(interp_out_ready)
  );

  for (genvar lane = 0; lane < LANES_OUT; lane = lane + 1) begin : g_ti_baseband
    always_comb begin
      unique case (lane % 4)
        0, 2: ti_baseband_vec[lane*W +: W] = interp_i_vec[lane*W +: W];
        default: ti_baseband_vec[lane*W +: W] = interp_q_vec[lane*W +: W];
      endcase
    end
  end

  ti64_lp1_fs4_gt_tx #(
    .W_IN(W), .ACC_W(ACC_W), .SATURATE(SATURATE)
  ) u_ti64 (
    .clk(clk), .rst_n(rst_n), .in_valid(interp_out_valid),
    .in_ready(interp_out_ready), .in_x_vec(ti_baseband_vec),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data)
  );
endmodule

`default_nettype wire
