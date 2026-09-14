`timescale 1ns/1ps
`default_nettype none

module ti32_lp1_fs4_dsm_ooc (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic enable,
  input wire logic signed [511:0] x_vec,
  output wire logic [31:0] y_vec,
  output wire logic out_valid
);
  ti32_lp1_fs4_dsm #(.LANES(32), .W_IN(16), .ACC_W(28), .SATURATE(1'b1)) u_dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_vec(x_vec),
    .y_vec(y_vec), .out_valid(out_valid)
  );
endmodule

`default_nettype wire
