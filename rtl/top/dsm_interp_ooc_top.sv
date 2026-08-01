`timescale 1ns/1ps
`default_nettype none

module dsm_interp_ooc_top #(
  parameter int INTERP_IMPL = 0
) (
  input  wire                   clk,
  input  wire                   rst_n,
  input  wire                   enable,
  input  wire signed [15:0]     i_in,
  input  wire signed [15:0]     q_in,
  input  wire                   in_valid,
  output wire                   in_ready,
  output wire signed [15:0]     i_out,
  output wire signed [15:0]     q_out,
  output wire                   out_valid,
  input  wire                   out_ready
);

  dsm_interp_frontend #(
    .W_IN(16), .W_OUT(16), .INTERP_MODE(4), .INTERP_IMPL(INTERP_IMPL)
  ) u_interp (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready)
  );
endmodule

`default_nettype wire
