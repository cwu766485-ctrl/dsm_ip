`timescale 1ns/1ps
`default_nettype none
module tid32_thermo5_frontend_tx_ooc (
  input wire logic clk, rst_n, in_valid, in_frame_start,
  input wire logic signed [15:0] in_frame_gain,
  input wire logic signed [127:0] in_i_vec, in_q_vec,
  input wire logic [2:0] dpd_active_taps,
  input wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic in_ready,
  output wire logic [3:0] pa_valid,
  output wire logic [63:0] pa0_data, pa1_data, pa2_data, pa3_data
);
  wire logic [63:0] pa_data [0:3];
  tid32_thermo5_frontend_tx #(.STEP(7168)) u_dut (
    .clk(clk),.rst_n(rst_n),.enable(1'b1),.in_valid(in_valid),.in_ready(in_ready),
    .in_frame_start(in_frame_start),.in_frame_gain(in_frame_gain),.in_i_vec(in_i_vec),.in_q_vec(in_q_vec),
    .dpd_active_taps(dpd_active_taps),.c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),.c5_re(c5_re),.c5_im(c5_im),
    .pa_valid(pa_valid),.pa_data(pa_data),.pa_ready(4'hf)
  );
  assign pa0_data=pa_data[0]; assign pa1_data=pa_data[1]; assign pa2_data=pa_data[2]; assign pa3_data=pa_data[3];
endmodule
`default_nettype wire
