//------------------------------------------------------------------------------
// File: dsm_core_ef1.sv
// Description:
//   1st-order 1-bit Error-Feedback (EF1) DSM core, aligned to MATLAB model:
//     y_raw[n] = x[n] + e[n-1]
//     q[n]     = sign(y_raw[n]) * FS
//     e[n]     = y[n] - q[n]
//
// Conventions:
//   - x_in is signed Q1.(W_IN-1)
//   - y_bit: 1 => +1, 0 => -1
//   - y_signed: +/- (2^(W_IN-1)-1)
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_ef1 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,                          // 1 => +1, 0 => -1
  output logic signed [W_IN-1:0] y_signed,     // +/- (2^(W_IN-1)-1)
  output logic signed [ACC_W-1:0] v_state      // current quantizer input y[n]
);

  localparam int SUM_W = ACC_W + 1;

  localparam signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] e1;

  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic signed [SUM_W-1:0] y_sum;
  logic signed [ACC_W-1:0] y_int;
  logic signed [ACC_W-1:0] e0;

  logic y_bit_c;
  logic signed [W_IN-1:0] y_signed_c;

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};

    y_sum = $signed({x_ext[ACC_W-1], x_ext}) +
            $signed({e1[ACC_W-1], e1});

    if (SATURATE) begin
      if (y_sum > $signed({V_MAX[ACC_W-1], V_MAX})) begin
        y_int = V_MAX;
      end else if (y_sum < $signed({V_MIN[ACC_W-1], V_MIN})) begin
        y_int = V_MIN;
      end else begin
        y_int = y_sum[ACC_W-1:0];
      end
    end else begin
      y_int = y_sum[ACC_W-1:0];
    end

    y_bit_c = (y_int >= 0);
    y_signed_c = y_bit_c ? Y_POS : Y_NEG;
    q_ext = {{(ACC_W-W_IN){y_signed_c[W_IN-1]}}, y_signed_c};
    e0 = y_int - q_ext;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e1       <= '0;
      y_bit    <= 1'b1;
      y_signed <= Y_POS;
      v_state  <= '0;
    end else if (enable) begin
      e1       <= e0;
      y_bit    <= y_bit_c;
      y_signed <= y_signed_c;
      v_state  <= y_int;
    end
  end

endmodule

`default_nettype wire
