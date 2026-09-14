// Compatibility wrapper for the compact two-sample look-ahead candidate.

`timescale 1ns/1ps
`default_nettype none

module bp_ef2_lookahead2_acc17 #(
  parameter int W_IN = 16,
  parameter bit SATURATE = 1'b1
) (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic enable,
  input wire logic [64*W_IN-1:0] x_vec,
  output wire logic [63:0] y_vec,
  output wire logic signed [64*W_IN-1:0] y_signed_vec,
  output wire logic out_valid,
  output wire logic signed [16:0] v_state
);
  bp_ef2_polyphase2_lookahead2_acc17 #(
    .W_IN(W_IN), .SATURATE(SATURATE)
  ) u_lookahead (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_vec(x_vec),
    .y_vec(y_vec), .y_signed_vec(y_signed_vec), .out_valid(out_valid),
    .v_state(v_state)
  );
endmodule

`default_nettype wire
