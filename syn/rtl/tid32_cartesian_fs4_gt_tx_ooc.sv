`timescale 1ns/1ps
`default_nettype none

module tid32_cartesian_fs4_gt_tx_ooc (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic in_valid,
  input wire logic signed [511:0] in_i_poly_vec,
  input wire logic signed [511:0] in_q_poly_vec,
  output wire logic gt_valid,
  output wire logic [63:0] gt_data
);
  tid32_cartesian_fs4_gt_tx #(.W(16), .CHANNELS(32)) u_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(gt_valid), .gt_ready(1'b1), .gt_data(gt_data)
  );
endmodule

`default_nettype wire
