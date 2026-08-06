//------------------------------------------------------------------------------
// Second-order, one-bit single-loop bandpass DSM centered at Fs/4.
//
// A two-state resonator is driven by the previous one-bit quantizer output.
// Its linearized noise transfer function is 1 + z^-2, giving zeros at
// +/- Fs/4.  This is the single-loop counterpart to dsm_core_bp_ef2.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_bp_single #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,
  output logic signed [W_IN-1:0] y_signed,
  output logic signed [ACC_W-1:0] s1_state,
  output logic signed [ACC_W-1:0] s2_state
);

  localparam int SUM_W = ACC_W + 2;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] s1;
  logic signed [ACC_W-1:0] s2;
  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext;
  logic signed [ACC_W-1:0] q_ext;
  logic signed [SUM_W-1:0] s1_sum;
  logic signed [ACC_W-1:0] s1_next;
  logic signed [ACC_W-1:0] s2_next;
  logic signed [ACC_W-1:0] quantizer_input;
  logic y_bit_next;
  logic signed [W_IN-1:0] y_signed_next;

  function automatic logic signed [ACC_W-1:0] sat_acc(
    input logic signed [SUM_W-1:0] value
  );
    begin
      if (!SATURATE) begin
        sat_acc = value[ACC_W-1:0];
      end else if (value > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
        sat_acc = V_MAX;
      end else if (value < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
        sat_acc = V_MIN;
      end else begin
        sat_acc = value[ACC_W-1:0];
      end
    end
  endfunction

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};
    q_ext = {{(ACC_W-W_IN){y_signed[W_IN-1]}}, y_signed};

    // Resonator state update: s1[n+1] = x[n] - q[n] - s2[n],
    // s2[n+1] = s1[n].  Quantizing -s2[n+1] gives the Fs/4 BP loop.
    s1_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) -
             $signed({{(SUM_W-ACC_W){q_ext[ACC_W-1]}}, q_ext}) -
             $signed({{(SUM_W-ACC_W){s2[ACC_W-1]}}, s2});
    s1_next = sat_acc(s1_sum);
    s2_next = s1;
    quantizer_input = -s2_next;
    y_bit_next = (quantizer_input >= 0);
    y_signed_next = y_bit_next ? Y_POS : Y_NEG;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      s1 <= '0;
      s2 <= '0;
      y_bit <= 1'b1;
      y_signed <= Y_POS;
    end else if (enable) begin
      s1 <= s1_next;
      s2 <= s2_next;
      y_bit <= y_bit_next;
      y_signed <= y_signed_next;
    end
  end

  assign s1_state = s1;
  assign s2_state = s2;

endmodule

`default_nettype wire
