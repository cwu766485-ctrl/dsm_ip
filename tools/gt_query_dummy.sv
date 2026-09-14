`timescale 1ns/1ps
`default_nettype none

module gt_query_dummy (
  input  wire clk,
  output wire probe
);
  assign probe = clk;
endmodule

`default_nettype wire
