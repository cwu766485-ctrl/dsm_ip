//------------------------------------------------------------------------------
// Second-order, one-bit bandpass error-feedback DSM.
//
// For a center frequency Fs/4, the error-feedback coefficients are B1 = 0 and
// B2 = -1.  The resulting NTF is 1 + z^-2, with zeros at +/- Fs/4.  This is a
// real-IF modulator and must be driven by a real IF waveform, not I/Q lanes.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_bp_ef2 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output wire logic y_bit,
  output wire logic signed [W_IN-1:0] y_signed,
  output wire logic signed [ACC_W-1:0] v_state
);

  dsm_core_ef2 #(
    .W_IN(W_IN),
    .ACC_W(ACC_W),
    .IN_SHIFT(IN_SHIFT),
    .SATURATE(SATURATE),
    .COEFF_W(2),
    .B1_NUM(0),
    .B2_NUM(-1),
    .COEFF_SHIFT(0)
  ) u_bp_ef2 (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .x_in(x_in),
    .y_bit(y_bit),
    .y_signed(y_signed),
    .v_state(v_state)
  );

endmodule

`default_nettype wire
