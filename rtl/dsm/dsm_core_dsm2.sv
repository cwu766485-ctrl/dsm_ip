//------------------------------------------------------------------------------
// File: dsm_core_dsm2.sv
// Description:
//   Traditional 2nd-order 1-bit low-pass single-loop DSM, aligned to the
//   MATLAB reference model:
//     q[n]      = sign(v2[n-1]) * FS
//     v1[n]     = v1[n-1] + x[n] - q[n]
//     v2[n]     = v2[n-1] + v1[n] - q[n]
//
// Notes:
//   - The second integrator uses the updated v1[n], matching the MATLAB
//     dsm2_singleloop_fixed_model implementation.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_dsm2 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 40,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,                          // 1 => +1, 0 => -1
  output logic signed [W_IN-1:0] y_signed,     // +/- (2^(W_IN-1)-1)
  output logic signed [ACC_W-1:0] v1_state,
  output logic signed [ACC_W-1:0] v2_state
);

  localparam int SUM_W = ACC_W + 2;

  localparam signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] v1;
  logic signed [ACC_W-1:0] v2;

  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic signed [SUM_W-1:0] v1_sum;
  logic signed [SUM_W-1:0] v2_sum;
  logic signed [ACC_W-1:0] v1_next;
  logic signed [ACC_W-1:0] v2_next;

  logic y_bit_c;
  logic signed [W_IN-1:0] y_signed_c;

  always_comb begin
    y_bit_c = (v2 >= 0);
    y_signed_c = y_bit_c ? Y_POS : Y_NEG;

    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};
    q_ext = {{(ACC_W-W_IN){y_signed_c[W_IN-1]}}, y_signed_c};

    v1_sum = $signed({{(SUM_W-ACC_W){v1[ACC_W-1]}}, v1}) +
             $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
             $signed({{(SUM_W-ACC_W){q_ext[ACC_W-1]}}, q_ext});

    if (SATURATE) begin
      if (v1_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        v1_next = V_MAX;
      end else if (v1_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        v1_next = V_MIN;
      end else begin
        v1_next = v1_sum[ACC_W-1:0];
      end
    end else begin
      v1_next = v1_sum[ACC_W-1:0];
    end

    v2_sum = $signed({{(SUM_W-ACC_W){v2[ACC_W-1]}}, v2}) +
             $signed({{(SUM_W-ACC_W){v1_next[ACC_W-1]}}, v1_next}) -
             $signed({{(SUM_W-ACC_W){q_ext[ACC_W-1]}}, q_ext});

    if (SATURATE) begin
      if (v2_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        v2_next = V_MAX;
      end else if (v2_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        v2_next = V_MIN;
      end else begin
        v2_next = v2_sum[ACC_W-1:0];
      end
    end else begin
      v2_next = v2_sum[ACC_W-1:0];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      v1       <= '0;
      v2       <= '0;
      y_bit    <= 1'b1;
      y_signed <= Y_POS;
    end else if (enable) begin
      v1       <= v1_next;
      v2       <= v2_next;
      y_bit    <= y_bit_c;
      y_signed <= y_signed_c;
    end
  end

  assign v1_state = v1;
  assign v2_state = v2;

endmodule

`default_nettype wire
