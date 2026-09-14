`timescale 1ns/1ps
`default_nettype none

module ti64_cartesian_x4_frontend_tx_ooc (
  input  wire logic         clk,
  input  wire logic         rst_n,
  input  wire logic         in_valid,
  output wire logic         in_ready,
  input  wire logic signed [255:0] in_i_vec,
  input  wire logic signed [255:0] in_q_vec,
  input  wire logic [1:0]   dpd_mode,
  input  wire logic signed [15:0] c1_re,
  input  wire logic signed [15:0] c1_im,
  input  wire logic signed [15:0] c3_re,
  input  wire logic signed [15:0] c3_im,
  input  wire logic signed [15:0] c5_re,
  input  wire logic signed [15:0] c5_im,
  input  wire logic signed [15:0] c7_re,
  input  wire logic signed [15:0] c7_im,
  output wire logic [1:0]   dpd_effective_mode,
  output wire logic         gt_valid,
  input  wire logic         gt_ready,
  output wire logic [63:0]  gt_data
);
  ti64_cartesian_x4_frontend_tx #(.W(16), .ACC_W(28), .SATURATE(1'b1)) u_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec), .dpd_mode(dpd_mode),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .dpd_effective_mode(dpd_effective_mode), .gt_valid(gt_valid),
    .gt_ready(gt_ready), .gt_data(gt_data)
  );
endmodule

`default_nettype wire
