//------------------------------------------------------------------------------
// File: dsm_core.sv
// Description:
//   1st-order 1-bit lowpass delta-sigma modulator.
//     y = sign(v)
//     v = v + x - y
//
// Conventions:
//   - x_in is signed Q1.(W_IN-1)
//   - y_bit: 1 => +1, 0 => -1
//   - y_signed: +/- (2^(W_IN-1)-1)
//
// Parameters:
//   W_IN      : input width
//   ACC_W     : integrator width
//   IN_SHIFT  : arithmetic right shift on x_in for headroom
//   SATURATE  : clamp integrator to prevent overflow (set 0 for bit-true)
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core #(
  parameter int W_IN  = 16,
  parameter int ACC_W = 24,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b0
) (
  input  wire  clk,
  input  wire  rst_n,
  input  wire  enable,
  input  wire  signed [W_IN-1:0] x_in,
  output logic y_bit,                         // 1 => +1, 0 => -1
  output logic signed [W_IN-1:0] y_signed,     // +/- (2^(W_IN-1)-1)
  output logic signed [ACC_W-1:0] v_state
);

  localparam signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] v;
  logic signed [W_IN-1:0]  x_shifted;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] y_ext;
  logic signed [ACC_W-1:0] v_next;
  logic signed [ACC_W:0]   v_sum;

  logic y_bit_c;
  logic signed [W_IN-1:0] y_signed_c;

  always_comb begin
    y_bit_c    = (v >= 0);
    y_signed_c = y_bit_c ? Y_POS : Y_NEG;

    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};
    y_ext = {{(ACC_W-W_IN){y_signed_c[W_IN-1]}}, y_signed_c};

    v_sum = $signed(v) + $signed(x_ext) - $signed(y_ext);

    if (SATURATE) begin
      if (v_sum > V_MAX) begin
        v_next = V_MAX;
      end else if (v_sum < V_MIN) begin
        v_next = V_MIN;
      end else begin
        v_next = v_sum[ACC_W-1:0];
      end
    end else begin
      v_next = v_sum[ACC_W-1:0];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v        <= '0;
      y_bit    <= 1'b1;
      y_signed <= Y_POS;
    end else if (enable) begin
      v        <= v_next;
      y_bit    <= y_bit_c;
      y_signed <= y_signed_c;
    end
  end

  assign v_state = v;

endmodule

`default_nettype wire
