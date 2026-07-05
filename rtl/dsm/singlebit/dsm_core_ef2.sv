//------------------------------------------------------------------------------
// File: dsm_core_ef2.sv
// Description:
//   2nd-order 1-bit Error-Feedback (EF2) DSM core, aligned to MATLAB model:
//     y_raw[n] = x[n] + b1*e[n-1] + b2*e[n-2]
//     q[n]     = sign(y_raw[n]) * FS
//     e[n]     = y[n] - q[n]
//
// Conventions:
//   - x_in is signed Q1.(W_IN-1)
//   - y_bit: 1 => +1, 0 => -1
//   - y_signed: +/- (2^(W_IN-1)-1)
//
// Notes:
//   - COEFF_SHIFT implements fixed-point coeff scaling:
//       coeff_real = B*_NUM / 2^COEFF_SHIFT
//   - Multiplication uses symmetric round-to-nearest before shifting.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_ef2 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1,
  parameter int COEFF_W = 8,
  parameter int signed B1_NUM = 2,
  parameter int signed B2_NUM = -1,
  parameter int COEFF_SHIFT = 0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,                          // 1 => +1, 0 => -1
  output logic signed [W_IN-1:0] y_signed,     // +/- (2^(W_IN-1)-1)
  output logic signed [ACC_W-1:0] v_state      // current quantizer input y[n]
);

  localparam int MUL_W = ACC_W + COEFF_W;
  localparam int SUM_W = MUL_W + 2;
  localparam int HALF_SHIFT = (COEFF_SHIFT > 0) ? (COEFF_SHIFT-1) : 0;

  localparam signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  localparam signed [COEFF_W-1:0] B1_Q = B1_NUM;
  localparam signed [COEFF_W-1:0] B2_Q = B2_NUM;

  logic signed [ACC_W-1:0] e1;
  logic signed [ACC_W-1:0] e2;

  logic signed [W_IN-1:0]  x_shifted;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;

  logic signed [MUL_W-1:0] b1_prod;
  logic signed [MUL_W-1:0] b2_prod;
  logic signed [MUL_W-1:0] b1_term;
  logic signed [MUL_W-1:0] b2_term;

  logic signed [SUM_W-1:0] y_sum;
  logic signed [ACC_W-1:0] y_int;
  logic signed [ACC_W-1:0] e0;

  logic y_bit_c;
  logic signed [W_IN-1:0] y_signed_c;

  function automatic logic signed [MUL_W-1:0] round_shift(
    input logic signed [MUL_W-1:0] vin
  );
    logic signed [MUL_W-1:0] vtmp;
    logic signed [MUL_W-1:0] half;
    begin
      if (COEFF_SHIFT > 0) begin
        half = $signed({{(MUL_W-1){1'b0}}, 1'b1}) <<< HALF_SHIFT;
        if (vin >= 0) begin
          vtmp = vin + half;
        end else begin
          vtmp = vin - half;
        end
        round_shift = vtmp >>> COEFF_SHIFT;
      end else begin
        round_shift = vin;
      end
    end
  endfunction

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};

    b1_prod = $signed(B1_Q) * $signed(e1);
    b2_prod = $signed(B2_Q) * $signed(e2);
    b1_term = round_shift(b1_prod);
    b2_term = round_shift(b2_prod);

    y_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
            $signed({{(SUM_W-MUL_W){b1_term[MUL_W-1]}}, b1_term}) +
            $signed({{(SUM_W-MUL_W){b2_term[MUL_W-1]}}, b2_term});

    if (SATURATE) begin
      if (y_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        y_int = V_MAX;
      end else if (y_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        y_int = V_MIN;
      end else begin
        y_int = y_sum[ACC_W-1:0];
      end
    end else begin
      // Two's-complement wrap (mod 2^ACC_W).
      y_int = y_sum[ACC_W-1:0];
    end

    y_bit_c = (y_int >= 0);
    y_signed_c = y_bit_c ? Y_POS : Y_NEG;
    q_ext = {{(ACC_W-W_IN){y_signed_c[W_IN-1]}}, y_signed_c};
    e0 = y_int - q_ext;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e1      <= '0;
      e2      <= '0;
      y_bit   <= 1'b1;
      y_signed<= Y_POS;
      v_state <= '0;
    end else if (enable) begin
      e2      <= e1;
      e1      <= e0;
      y_bit   <= y_bit_c;
      y_signed<= y_signed_c;
      v_state <= y_int;
    end
  end

endmodule

`default_nettype wire
