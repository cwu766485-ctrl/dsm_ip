//------------------------------------------------------------------------------
// File: dsm_core_mash22.sv
// Description:
//   Fixed-point MASH 2-2 core (two cascaded 2nd-order EF stages):
//
//   stage-1 EF2:
//     y1_raw[n] = x[n] + b1*e11[n-1] + b2*e12[n-2]
//     q1[n]     = sign(y1[n]) * FS
//     e10[n]    = y1[n] - q1[n]
//
//   stage-2 EF2 (input is stage-1 quantization error):
//     y2_raw[n] = e10[n] + b1*e21[n-1] + b2*e22[n-2]
//     q2[n]     = sign(y2[n]) * FS
//     e20[n]    = y2[n] - q2[n]
//
//   mash combine (MATLAB sweep_mash22_fixed_min.m):
//     y_mash[n] = y1_pm[n] + (y2_pm[n] - 2*y2_pm[n-1] + y2_pm[n-2])
//
//   For interface compatibility with 1-bit downstream logic:
//     y_bit = sign(y_mash) (1 => +, 0 => -)
//
// Notes:
//   - y_mash_signed is 4-bit signed and covers [-5, +5].
//   - If SATURATE=0, stage accumulators wrap in two's-complement.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_mash22 #(
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

  output logic y_bit,                          // sign(y_mash): 1 => +, 0 => -
  output logic y1_bit,                         // stage-1 quantizer bit
  output logic y2_bit,                         // stage-2 quantizer bit
  output logic signed [3:0] y_mash_signed,     // [-5..+5]
  output logic signed [ACC_W-1:0] v1_state,    // stage-1 quantizer input
  output logic signed [ACC_W-1:0] v2_state     // stage-2 quantizer input
);

  localparam int MUL_W = ACC_W + COEFF_W;
  localparam int SUM_W = MUL_W + 2;
  localparam int HALF_SHIFT = (COEFF_SHIFT > 0) ? (COEFF_SHIFT-1) : 0;

  localparam signed [W_IN-1:0] Q_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Q_NEG = -Q_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};
  localparam signed [3:0] PM_POS = 4'sd1;
  localparam signed [3:0] PM_NEG = -4'sd1;

  localparam signed [COEFF_W-1:0] B1_Q = B1_NUM;
  localparam signed [COEFF_W-1:0] B2_Q = B2_NUM;

  // EF2 stage states:
  // stage1 -> e11=e[n-1], e12=e[n-2]
  // stage2 -> e21=e[n-1], e22=e[n-2]
  logic signed [ACC_W-1:0] e11_state;
  logic signed [ACC_W-1:0] e12_state;
  logic signed [ACC_W-1:0] e21_state;
  logic signed [ACC_W-1:0] e22_state;

  // MASH FIR history on stage-2 1-bit output
  logic signed [3:0] y2_pm_prev1;
  logic signed [3:0] y2_pm_prev2;

  logic signed [W_IN-1:0]  x_shifted;
  logic signed [ACC_W-1:0] x_ext;

  // Stage-1 arithmetic
  logic signed [MUL_W-1:0] s1_b1_prod;
  logic signed [MUL_W-1:0] s1_b2_prod;
  logic signed [MUL_W-1:0] s1_b1_term;
  logic signed [MUL_W-1:0] s1_b2_term;
  (* use_dsp = "yes" *) logic signed [SUM_W-1:0] y1_sum;
  logic signed [ACC_W-1:0] y1_int;
  logic signed [ACC_W-1:0] q1_ext;
  logic signed [W_IN-1:0]  q1_w;
  logic signed [ACC_W-1:0] e10_next;

  // Stage-2 arithmetic
  logic signed [MUL_W-1:0] s2_b1_prod;
  logic signed [MUL_W-1:0] s2_b2_prod;
  logic signed [MUL_W-1:0] s2_b1_term;
  logic signed [MUL_W-1:0] s2_b2_term;
  (* use_dsp = "yes" *) logic signed [SUM_W-1:0] y2_sum;
  logic signed [ACC_W-1:0] y2_int;
  logic signed [ACC_W-1:0] q2_ext;
  logic signed [W_IN-1:0]  q2_w;
  logic signed [ACC_W-1:0] e20_next;

  // ==========================================
  // Stage-1 -> Stage-2 pipeline registers
  // ==========================================
  logic signed [ACC_W-1:0] e10_reg;
  logic signed [3:0]       y1_pm_reg;
  logic                    y1_bit_reg;
  logic signed [ACC_W-1:0] y1_int_reg;

  logic y1_bit_c;
  logic y2_bit_c;
  logic signed [3:0] y1_pm_c;
  logic signed [3:0] y2_pm_c;
  logic signed [3:0] y_mash_c;
  logic y_bit_c;

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

    // Stage-1 EF2
    s1_b1_prod = $signed(B1_Q) * $signed(e11_state);
    s1_b2_prod = $signed(B2_Q) * $signed(e12_state);
    s1_b1_term = round_shift(s1_b1_prod);
    s1_b2_term = round_shift(s1_b2_prod);

    y1_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) +
             $signed({{(SUM_W-MUL_W){s1_b1_term[MUL_W-1]}}, s1_b1_term}) +
             $signed({{(SUM_W-MUL_W){s1_b2_term[MUL_W-1]}}, s1_b2_term});

    if (SATURATE) begin
      if (y1_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        y1_int = V_MAX;
      end else if (y1_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        y1_int = V_MIN;
      end else begin
        y1_int = y1_sum[ACC_W-1:0];
      end
    end else begin
      y1_int = y1_sum[ACC_W-1:0];
    end

    y1_bit_c = (y1_int >= 0);
    y1_pm_c = y1_bit_c ? PM_POS : PM_NEG;
    q1_w = y1_bit_c ? Q_POS : Q_NEG;
    q1_ext = {{(ACC_W-W_IN){q1_w[W_IN-1]}}, q1_w};
    e10_next = y1_int - q1_ext;

    // Stage-2 EF2
    s2_b1_prod = $signed(B1_Q) * $signed(e21_state);
    s2_b2_prod = $signed(B2_Q) * $signed(e22_state);
    s2_b1_term = round_shift(s2_b1_prod);
    s2_b2_term = round_shift(s2_b2_prod);

    y2_sum = $signed({{(SUM_W-ACC_W){e10_reg[ACC_W-1]}}, e10_reg}) +
             $signed({{(SUM_W-MUL_W){s2_b1_term[MUL_W-1]}}, s2_b1_term}) +
             $signed({{(SUM_W-MUL_W){s2_b2_term[MUL_W-1]}}, s2_b2_term});

    if (SATURATE) begin
      if (y2_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        y2_int = V_MAX;
      end else if (y2_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        y2_int = V_MIN;
      end else begin
        y2_int = y2_sum[ACC_W-1:0];
      end
    end else begin
      y2_int = y2_sum[ACC_W-1:0];
    end

    y2_bit_c = (y2_int >= 0);
    y2_pm_c = y2_bit_c ? PM_POS : PM_NEG;
    q2_w = y2_bit_c ? Q_POS : Q_NEG;
    q2_ext = {{(ACC_W-W_IN){q2_w[W_IN-1]}}, q2_w};
    e20_next = y2_int - q2_ext;

    // y = y1[n] + (1 - 2 z^-1 + z^-2) y2[n]
    y_mash_c = y1_pm_reg + y2_pm_c - (y2_pm_prev1 <<< 1) + y2_pm_prev2;
    y_bit_c = (y_mash_c >= 0);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e11_state      <= '0;
      e12_state      <= '0;
      e21_state      <= '0;
      e22_state      <= '0;
      e10_reg        <= '0;
      y1_pm_reg      <= PM_POS;
      y1_bit_reg     <= 1'b1;
      y1_int_reg     <= '0;
      y2_pm_prev1    <= 4'sd0;
      y2_pm_prev2    <= 4'sd0;
      y_bit          <= 1'b1;
      y1_bit         <= 1'b1;
      y2_bit         <= 1'b1;
      y_mash_signed  <= 4'sd1;
      v1_state       <= '0;
      v2_state       <= '0;
    end else if (enable) begin
      // Stage-1 history
      e12_state      <= e11_state;
      e11_state      <= e10_next;

      // Inter-stage pipeline
      e10_reg        <= e10_next;
      y1_pm_reg      <= y1_pm_c;
      y1_bit_reg     <= y1_bit_c;
      y1_int_reg     <= y1_int;

      // Stage-2 history
      e22_state      <= e21_state;
      e21_state      <= e20_next;

      y2_pm_prev2    <= y2_pm_prev1;
      y2_pm_prev1    <= y2_pm_c;
      y_bit          <= y_bit_c;
      y1_bit         <= y1_bit_reg;
      y2_bit         <= y2_bit_c;
      y_mash_signed  <= y_mash_c;
      v1_state       <= y1_int;
      v2_state       <= y2_int;
    end
  end

endmodule

`default_nettype wire
