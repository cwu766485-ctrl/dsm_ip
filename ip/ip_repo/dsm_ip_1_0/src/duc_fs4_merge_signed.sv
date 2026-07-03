//------------------------------------------------------------------------------
// File: duc_fs4_merge_signed.sv
// Description:
//   TI-style Fs/4 digital upconversion + I/Q merge for signed multi-level
//   Cartesian DSM outputs. Produces a single real signed RF stream at Fs_dsm.
//
// Mapping (2-bit phase counter):
//   ph=0: +I
//   ph=1: +Q
//   ph=2: -I
//   ph=3: -Q
//
// Notes:
//   - in_valid is delayed by 1 cycle internally to align with registered
//     upstream outputs, matching duc_fs4_merge.sv behavior.
//   - W_OUT must be >= W_IN.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module duc_fs4_merge_signed #(
  parameter int W_IN = 4,
  parameter int W_OUT = W_IN,
  parameter bit HOLD_LAST_WHEN_INVALID = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W_IN-1:0] i_data,
  input  wire logic signed [W_IN-1:0] q_data,

  output logic rf_valid,
  output logic signed [W_OUT-1:0] rf_signed,
  output logic [1:0] phase
);

  logic in_valid_d1;
  logic [1:0] ph;
  logic signed [W_OUT-1:0] i_ext;
  logic signed [W_OUT-1:0] q_ext;
  logic signed [W_OUT-1:0] rf_signed_c;

  always_comb begin
    i_ext = {{(W_OUT-W_IN){i_data[W_IN-1]}}, i_data};
    q_ext = {{(W_OUT-W_IN){q_data[W_IN-1]}}, q_data};

    unique case (ph)
      2'd0: rf_signed_c = i_ext;
      2'd1: rf_signed_c = q_ext;
      2'd2: rf_signed_c = -i_ext;
      2'd3: rf_signed_c = -q_ext;
      default: rf_signed_c = '0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_valid_d1 <= 1'b0;
      rf_valid    <= 1'b0;
      rf_signed   <= '0;
      ph          <= 2'd0;
    end else begin
      in_valid_d1 <= in_valid;
      rf_valid    <= in_valid_d1;

      if (in_valid_d1) begin
        rf_signed <= rf_signed_c;
        ph        <= ph + 2'd1;
      end else if (!HOLD_LAST_WHEN_INVALID) begin
        rf_signed <= '0;
      end
    end
  end

  assign phase = ph;

endmodule

`default_nettype wire