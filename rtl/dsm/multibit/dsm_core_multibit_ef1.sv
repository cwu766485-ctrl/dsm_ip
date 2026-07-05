`timescale 1ns/1ps
`default_nettype none

module dsm_core_multibit_ef1 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 16,
  parameter int OUT_W = 8,
  parameter int Q_BITS = 4,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,
  output logic signed [OUT_W-1:0] y_code,
  output logic signed [ACC_W-1:0] v1_state,
  output logic signed [ACC_W-1:0] v2_state
);
  dsm_core_multibit #(.W_IN(W_IN), .ACC_W(ACC_W), .OUT_W(OUT_W), .Q_BITS(Q_BITS),
    .MB_ALGORITHM(2), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_core (
    .clk(clk), .rst_n(rst_n), .enable(enable), .x_in(x_in), .y_bit(y_bit),
    .y_code(y_code), .v1_state(v1_state), .v2_state(v2_state));
endmodule

`default_nettype wire
