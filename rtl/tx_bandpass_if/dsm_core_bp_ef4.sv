//------------------------------------------------------------------------------
// Fourth-order, one-bit bandpass error-feedback DSM.
//
// At Fs/4 the error-feedback path is
//   v[n] = x[n] - 2e[n-2] - e[n-4].
// The linearized NTF magnitude is |(1 + z^-2)^2|, giving a double zero at
// +/- Fs/4.  This is an experimental candidate: its input backoff and
// stability envelope must be established by the accompanying bit-true screen
// before it is used in an integrated transmitter.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_core_bp_ef4 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1,
  parameter int signed C2_NUM = -2,
  parameter int signed C4_NUM = -1
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic signed [W_IN-1:0] x_in,
  output logic y_bit,
  output logic signed [W_IN-1:0] y_signed,
  output logic signed [ACC_W-1:0] v_state
);

  localparam int SUM_W = ACC_W + 3;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] e1, e2, e3, e4;
  logic signed [W_IN-1:0] x_shifted;
  logic signed [ACC_W-1:0] x_ext, q_ext, v_int, e0;
  logic signed [SUM_W-1:0] v_sum;
  logic signed [SUM_W-1:0] c2_term, c4_term;
  logic y_bit_c;
  logic signed [W_IN-1:0] y_signed_c;

  always_comb begin
    x_shifted = (IN_SHIFT == 0) ? x_in : (x_in >>> IN_SHIFT);
    x_ext = {{(ACC_W-W_IN){x_shifted[W_IN-1]}}, x_shifted};
    c2_term = C2_NUM * $signed(e2);
    c4_term = C4_NUM * $signed(e4);
    v_sum = $signed({{(SUM_W-ACC_W){x_ext[ACC_W-1]}}, x_ext}) + c2_term + c4_term;
    if (!SATURATE) begin
      v_int = v_sum[ACC_W-1:0];
    end else if (v_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) begin
      v_int = V_MAX;
    end else if (v_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN})) begin
      v_int = V_MIN;
    end else begin
      v_int = v_sum[ACC_W-1:0];
    end
    y_bit_c = (v_int >= 0);
    y_signed_c = y_bit_c ? Y_POS : Y_NEG;
    q_ext = {{(ACC_W-W_IN){y_signed_c[W_IN-1]}}, y_signed_c};
    // Error history deliberately wraps in ACC_W bits, matching EF2.
    e0 = v_int - q_ext;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      e1 <= '0; e2 <= '0; e3 <= '0; e4 <= '0;
      y_bit <= 1'b1;
      y_signed <= Y_POS;
      v_state <= '0;
    end else if (enable) begin
      e4 <= e3;
      e3 <= e2;
      e2 <= e1;
      e1 <= e0;
      y_bit <= y_bit_c;
      y_signed <= y_signed_c;
      v_state <= v_int;
    end
  end

endmodule

`default_nettype wire
