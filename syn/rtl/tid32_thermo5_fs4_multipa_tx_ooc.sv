`timescale 1ns/1ps
`default_nettype none

module tid32_thermo5_fs4_multipa_tx_ooc (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic in_valid,
  input wire logic signed [511:0] in_i_poly_vec,
  input wire logic signed [511:0] in_q_poly_vec,
  output wire logic [3:0] pa_valid,
  output wire logic [63:0] pa0_data,
  output wire logic [63:0] pa1_data,
  output wire logic [63:0] pa2_data,
  output wire logic [63:0] pa3_data
);
  logic [63:0] pa_data [0:3];
  tid32_thermo5_fs4_multipa_tx #(.W(16), .CHANNELS(32), .STEP(6144)) u_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(4'b1111)
  );
  assign pa0_data = pa_data[0];
  assign pa1_data = pa_data[1];
  assign pa2_data = pa_data[2];
  assign pa3_data = pa_data[3];
endmodule

`default_nettype wire
