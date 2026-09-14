`timescale 1ns/1ps
`default_nettype none

module ti64_lp1_fs4_gt_tx_ooc (
  input  wire logic         clk,
  input  wire logic         rst_n,
  input  wire logic         in_valid,
  output wire logic         in_ready,
  input  wire logic signed [1023:0] in_x_vec,
  output wire logic         gt_valid,
  input  wire logic         gt_ready,
  output wire logic [63:0]  gt_data
);
  ti64_lp1_fs4_gt_tx #(.W_IN(16), .ACC_W(28), .SATURATE(1'b1)) u_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_x_vec(in_x_vec), .gt_valid(gt_valid), .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
endmodule

`default_nettype wire
