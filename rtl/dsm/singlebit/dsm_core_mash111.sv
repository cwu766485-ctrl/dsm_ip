//------------------------------------------------------------------------------
// File: dsm_core_mash111.sv
// Description:
//   Fixed-point MASH 1-1-1 core (three cascaded 1st-order stages):
//
//     stage1:
//       y1_raw[n] = x[n] + e1[n-1]
//       q1[n]     = sign(y1[n]) * FS
//       e1[n]     = y1[n] - q1[n]
//
//     stage2:
//       y2_raw[n] = e1[n] + e2[n-1]
//       q2[n]     = sign(y2[n]) * FS
//       e2[n]     = y2[n] - q2[n]
//
//     stage3:
//       y3_raw[n] = e2[n] + e3[n-1]
//       q3[n]     = sign(y3[n]) * FS
//       e3[n]     = y3[n] - q3[n]
//
//     mash combine (MATLAB sweep_mash111_fixed_min.m):
//       y_mash[n] = y1_pm[n]
//                 + (y2_pm[n] - y2_pm[n-1])
//                 + (y3_pm[n] - 2*y3_pm[n-1] + y3_pm[n-2])
//
//   For interface compatibility with 1-bit downstream logic:
//     y_bit = sign(y_mash) (1 => +, 0 => -)
//
// Notes:
//   - y_mash_signed is 4-bit signed and covers [-7, +7].
//   - If SATURATE=0, stage accumulators wrap in two's-complement.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_mash111 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,

  output logic y_bit,                          // sign(y_mash): 1 => +, 0 => -
  output logic y1_bit,                         // stage-1 quantizer bit
  output logic y2_bit,                         // stage-2 quantizer bit
  output logic y3_bit,                         // stage-3 quantizer bit
  output logic signed [3:0] y_mash_signed,     // [-7..+7]
  output logic signed [ACC_W-1:0] v1_state,    // stage-1 quantizer input
  output logic signed [ACC_W-1:0] v2_state,    // stage-2 quantizer input
  output logic signed [ACC_W-1:0] v3_state     // stage-3 quantizer input
);

  localparam signed [W_IN-1:0] Q_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Q_NEG = -Q_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};
  localparam signed [3:0] PM_POS = 4'sd1;
  localparam signed [3:0] PM_NEG = -4'sd1;

  logic signed [ACC_W-1:0] e1_state;
  logic signed [ACC_W-1:0] e2_state;
  logic signed [ACC_W-1:0] e3_state;
  logic signed [ACC_W-1:0] e1_reg;
  logic signed [ACC_W-1:0] e2_reg;
  logic signed [3:0] y2_pm_prev;
  logic signed [3:0] y3_pm_prev1;
  logic signed [3:0] y3_pm_prev2;

  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext;

  logic signed [ACC_W:0] y1_sum;
  logic signed [ACC_W:0] y2_sum;
  logic signed [ACC_W:0] y3_sum;
  logic signed [ACC_W-1:0] y1_int;
  logic signed [ACC_W-1:0] y2_int;
  logic signed [ACC_W-1:0] y3_int;
  logic signed [ACC_W-1:0] q1_ext;
  logic signed [ACC_W-1:0] q2_ext;
  logic signed [ACC_W-1:0] q3_ext;
  logic signed [W_IN-1:0] q1_w;
  logic signed [W_IN-1:0] q2_w;
  logic signed [W_IN-1:0] q3_w;
  logic signed [ACC_W-1:0] e1_next;
  logic signed [ACC_W-1:0] e2_next;
  logic signed [ACC_W-1:0] e3_next;

  logic y1_bit_c;
  logic y2_bit_c;
  logic y3_bit_c;
  logic signed [3:0] y1_pm_c;
  logic signed [3:0] y2_pm_c;
  logic signed [3:0] y3_pm_c;
  logic signed [3:0] y_mash_c;
  logic y_bit_c;
  logic signed [3:0] y1_pm_reg1;
  logic signed [3:0] y1_pm_reg2;
  logic y1_bit_reg1;
  logic y1_bit_reg2;
  logic signed [ACC_W-1:0] y1_int_reg1;
  logic signed [ACC_W-1:0] y1_int_reg2;
  logic signed [3:0] y2_pm_reg;
  logic y2_bit_reg;
  logic signed [ACC_W-1:0] y2_int_reg;

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};

    // Stage 1
    y1_sum = $signed({x_ext[ACC_W-1], x_ext}) + $signed({e1_state[ACC_W-1], e1_state});
    if (SATURATE) begin
      if (y1_sum > $signed({V_MAX[ACC_W-1], V_MAX})) begin
        y1_int = V_MAX;
      end else if (y1_sum < $signed({V_MIN[ACC_W-1], V_MIN})) begin
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
    e1_next = y1_int - q1_ext;

    // Stage 2 consumes the registered stage-1 error from the previous enabled
    // sample.
    y2_sum = $signed({e1_reg[ACC_W-1], e1_reg}) + $signed({e2_state[ACC_W-1], e2_state});
    if (SATURATE) begin
      if (y2_sum > $signed({V_MAX[ACC_W-1], V_MAX})) begin
        y2_int = V_MAX;
      end else if (y2_sum < $signed({V_MIN[ACC_W-1], V_MIN})) begin
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
    e2_next = y2_int - q2_ext;

    // Stage 3 consumes the registered stage-2 error, creating a three-stage
    // pipeline across the cascaded MASH loop.
    y3_sum = $signed({e2_reg[ACC_W-1], e2_reg}) + $signed({e3_state[ACC_W-1], e3_state});
    if (SATURATE) begin
      if (y3_sum > $signed({V_MAX[ACC_W-1], V_MAX})) begin
        y3_int = V_MAX;
      end else if (y3_sum < $signed({V_MIN[ACC_W-1], V_MIN})) begin
        y3_int = V_MIN;
      end else begin
        y3_int = y3_sum[ACC_W-1:0];
      end
    end else begin
      y3_int = y3_sum[ACC_W-1:0];
    end
    y3_bit_c = (y3_int >= 0);
    y3_pm_c = y3_bit_c ? PM_POS : PM_NEG;
    q3_w = y3_bit_c ? Q_POS : Q_NEG;
    q3_ext = {{(ACC_W-W_IN){q3_w[W_IN-1]}}, q3_w};
    e3_next = y3_int - q3_ext;

    // y = y1 + (1-z^-1)*y2 + (1-2z^-1+z^-2)*y3
    y_mash_c = y1_pm_reg2 +
               (y2_pm_reg - y2_pm_prev) +
               (y3_pm_c - (y3_pm_prev1 <<< 1) + y3_pm_prev2);
    y_bit_c = (y_mash_c >= 0);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e1_state      <= '0;
      e2_state      <= '0;
      e3_state      <= '0;
      e1_reg        <= '0;
      e2_reg        <= '0;
      y2_pm_prev    <= 4'sd0;
      y3_pm_prev1   <= 4'sd0;
      y3_pm_prev2   <= 4'sd0;
      y1_pm_reg1    <= PM_POS;
      y1_pm_reg2    <= PM_POS;
      y1_bit_reg1   <= 1'b1;
      y1_bit_reg2   <= 1'b1;
      y1_int_reg1   <= '0;
      y1_int_reg2   <= '0;
      y2_pm_reg     <= 4'sd0;
      y2_bit_reg    <= 1'b1;
      y2_int_reg    <= '0;
      y_bit         <= 1'b1;
      y1_bit        <= 1'b1;
      y2_bit        <= 1'b1;
      y3_bit        <= 1'b1;
      y_mash_signed <= 4'sd1;
      v1_state      <= '0;
      v2_state      <= '0;
      v3_state      <= '0;
    end else if (enable) begin
      e1_state      <= e1_next;
      e1_reg        <= e1_next;
      e2_state      <= e2_next;
      e2_reg        <= e2_next;
      e3_state      <= e3_next;
      y2_pm_prev    <= y2_pm_reg;
      y3_pm_prev2   <= y3_pm_prev1;
      y3_pm_prev1   <= y3_pm_c;
      y1_pm_reg1    <= y1_pm_c;
      y1_pm_reg2    <= y1_pm_reg1;
      y1_bit_reg1   <= y1_bit_c;
      y1_bit_reg2   <= y1_bit_reg1;
      y1_int_reg1   <= y1_int;
      y1_int_reg2   <= y1_int_reg1;
      y2_pm_reg     <= y2_pm_c;
      y2_bit_reg    <= y2_bit_c;
      y2_int_reg    <= y2_int;
      y_bit         <= y_bit_c;
      y1_bit        <= y1_bit_reg2;
      y2_bit        <= y2_bit_reg;
      y3_bit        <= y3_bit_c;
      y_mash_signed <= y_mash_c;
      v1_state      <= y1_int_reg2;
      v2_state      <= y2_int_reg;
      v3_state      <= y3_int;
    end
  end

endmodule

`default_nettype wire
