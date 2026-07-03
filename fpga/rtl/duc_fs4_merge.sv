//------------------------------------------------------------------------------
// File: duc_fs4_merge.sv
// Description:
//   TI-style Fs/4 digital upconversion + I/Q merge for 1-bit Cartesian DSM
//   outputs. Produces a single real RF bitstream at Fs_dsm.
//
// MATLAB reference (stage2_dsm_and_metrics_v3.m):
//   fc = Fs/4
//   loI = [ 1  0 -1  0 ...]
//   loQ = [ 0  1  0 -1 ...]
//   s_rf[n] = yI[n]*loI[n] + yQ[n]*loQ[n]  -> still binary {-1, +1}
//
// Mapping (2-bit phase counter):
//   ph=0: +I
//   ph=1: +Q
//   ph=2: -I
//   ph=3: -Q
//
// Conventions:
//   *_bit = 1 => +1, 0 => -1
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module duc_fs4_merge #(
  parameter int W_OUT = 16,
  parameter bit HOLD_LAST_WHEN_INVALID = 1'b1
) (
  input  wire  clk,
  input  wire  rst_n,

  // in_valid should assert once per DSM output sample.
  // NOTE: Because upstream DSM outputs are registered, this module delays
  // in_valid by 1 cycle internally to avoid same-edge sampling of i_bit/q_bit.
  input  wire  in_valid,
  input  wire  i_bit,
  input  wire  q_bit,

  output logic rf_valid,
  output logic rf_bit,                       // 1 => +1, 0 => -1
  output logic signed [W_OUT-1:0] rf_signed, // +/- full-scale (for debug/ILA)
  output logic [1:0] phase                   // debug: current Fs/4 phase
);

  localparam signed [W_OUT-1:0] RF_POS = {1'b0, {(W_OUT-1){1'b1}}};
  localparam signed [W_OUT-1:0] RF_NEG = -RF_POS;

  logic in_valid_d1;
  logic [1:0] ph;
  logic rf_bit_c;

  // Combinational merge for the current phase.
  always_comb begin
    unique case (ph)
      2'd0: rf_bit_c = i_bit;   // +I
      2'd1: rf_bit_c = q_bit;   // +Q
      2'd2: rf_bit_c = ~i_bit;  // -I
      2'd3: rf_bit_c = ~q_bit;  // -Q
      default: rf_bit_c = 1'b1;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_valid_d1 <= 1'b0;
      rf_valid    <= 1'b0;
      rf_bit      <= 1'b1;
      rf_signed   <= RF_POS;
      ph          <= 2'd0;
    end else begin
      // Pipeline valid to align with stable DSM outputs.
      in_valid_d1 <= in_valid;
      rf_valid    <= in_valid_d1;

      if (in_valid_d1) begin
        rf_bit    <= rf_bit_c;
        rf_signed <= rf_bit_c ? RF_POS : RF_NEG;
        ph        <= ph + 2'd1;
      end else if (!HOLD_LAST_WHEN_INVALID) begin
        rf_bit    <= 1'b1;
        rf_signed <= RF_POS;
      end
    end
  end

  assign phase = ph;

endmodule

`default_nettype wire
