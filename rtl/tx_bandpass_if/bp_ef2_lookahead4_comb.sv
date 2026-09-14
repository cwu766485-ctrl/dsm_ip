// Exact four-sample look-ahead block for one BP EFDSM2 polyphase stream.
//
// The default frozen contract reaches this block with an ACC_W state and a
// Q1.15 input.  For that reachable state range, the accumulator does not
// saturate.  Each possible four-bit quantizer decision is therefore an
// affine function of the incoming state.  The valid affine candidate is
// selected by checking its four signs.  A sequential reference path remains
// in the block for saturation, wrap mode, or an otherwise invalid candidate.
// This file is an optimization candidate; it does not replace the frozen
// temporal64 top until equivalence and timing evidence are complete.

`timescale 1ns/1ps
`default_nettype none

module bp_ef2_lookahead4_comb #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic signed [4*W_IN-1:0] x_vec,
  input  wire logic signed [ACC_W-1:0] e_in,
  output logic [3:0] y_vec,
  output logic signed [4*W_IN-1:0] y_signed_vec,
  output logic signed [ACC_W-1:0] e_out,
  output logic signed [ACC_W-1:0] v_state
);

  localparam int SUM_W = ACC_W + 2;
  localparam int CALC_W = ACC_W + 4;
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] x_ext [0:3];
  logic signed [ACC_W-1:0] seq_v [0:3];
  logic signed [ACC_W-1:0] seq_e [0:3];
  logic seq_bit [0:3];
  logic signed [ACC_W-1:0] seq_q [0:3];

  logic signed [CALC_W-1:0] cand_v [0:15][0:3];
  logic signed [ACC_W-1:0] cand_e [0:15];
  logic cand_valid [0:15];
  logic signed [CALC_W-1:0] e_calc;
  logic signed [CALC_W-1:0] q_calc [0:15][0:3];
  logic signed [CALC_W-1:0] x_calc [0:3];
  logic signed [SUM_W-1:0] v_seq_calc;
  logic signed [ACC_W-1:0] e_seq;
  logic signed [ACC_W-1:0] q_seq;
  logic signed [SUM_W-1:0] seq_sum;
  logic seq_sat;
  logic lookahead_valid;
  logic [3:0] selected_mask;
  logic signed [ACC_W-1:0] selected_e;
  logic signed [ACC_W-1:0] selected_v;
  integer i;
  integer mask;

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

  function automatic logic signed [ACC_W-1:0] quant_level(input logic bit_value);
    begin
      quant_level = bit_value ? Y_POS : Y_NEG;
    end
  endfunction

  function automatic logic mask_bit(input integer value, input integer index);
    begin
      mask_bit = ((value >>> index) & 1) != 0;
    end
  endfunction

  function automatic logic signed [CALC_W-1:0] mask_quant(
    input integer value, input integer index
  );
    logic signed [ACC_W-1:0] level;
    begin
      level = quant_level(mask_bit(value, index));
      mask_quant = {{(CALC_W-ACC_W){level[ACC_W-1]}}, level};
    end
  endfunction

  function automatic logic signed [ACC_W-1:0] wrap_acc(
    input logic signed [SUM_W-1:0] value
  );
    begin
      wrap_acc = value[ACC_W-1:0];
    end
  endfunction

  always_comb begin
    y_vec = '0;
    y_signed_vec = '0;
    e_out = '0;
    v_state = '0;
    lookahead_valid = 1'b0;
    selected_mask = '0;
    selected_e = '0;
    selected_v = '0;
    seq_sat = 1'b0;
    e_seq = e_in;
    e_calc = {{(CALC_W-ACC_W){e_in[ACC_W-1]}}, e_in};

    for (i = 0; i < 4; i = i + 1) begin
      x_ext[i] = {{(ACC_W-W_IN){x_vec[i*W_IN+W_IN-1]}},
                  x_vec[i*W_IN +: W_IN]};
      x_calc[i] = {{(CALC_W-ACC_W){x_ext[i][ACC_W-1]}}, x_ext[i]};
    end

    // Exact sequential fallback.  This is also used to detect whether a
    // candidate encountered accumulator saturation.
    for (i = 0; i < 4; i = i + 1) begin
      seq_sum = $signed({{(SUM_W-ACC_W){x_ext[i][ACC_W-1]}}, x_ext[i]}) -
                 $signed({{(SUM_W-ACC_W){e_seq[ACC_W-1]}}, e_seq});
      seq_v[i] = sat_acc(seq_sum);
      seq_sat = seq_sat || (seq_sum > $signed({{(SUM_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX}));
      seq_sat = seq_sat || (seq_sum < $signed({{(SUM_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN}));
      seq_bit[i] = (seq_v[i] >= 0);
      seq_q[i] = quant_level(seq_bit[i]);
      q_seq = seq_q[i];
      e_seq = wrap_acc($signed({{(SUM_W-ACC_W){seq_v[i][ACC_W-1]}}, seq_v[i]}) -
                       $signed({{(SUM_W-ACC_W){q_seq[ACC_W-1]}}, q_seq}));
      seq_e[i] = e_seq;
    end

    // For every assumed four-bit decision sequence, derive v[0..3] directly
    // from e_in.  No candidate's v[i] depends on a previous candidate adder.
    for (mask = 0; mask < 16; mask = mask + 1) begin
      for (i = 0; i < 4; i = i + 1)
        q_calc[mask][i] = mask_quant(mask, i);

      cand_v[mask][0] = x_calc[0] - e_calc;
      cand_v[mask][1] = x_calc[1] - x_calc[0] + e_calc + q_calc[mask][0];
      cand_v[mask][2] = x_calc[2] - x_calc[1] + x_calc[0] - e_calc -
                        q_calc[mask][0] + q_calc[mask][1];
      cand_v[mask][3] = x_calc[3] - x_calc[2] + x_calc[1] - x_calc[0] +
                        e_calc + q_calc[mask][0] - q_calc[mask][1] +
                        q_calc[mask][2];
      cand_e[mask] = cand_v[mask][3] - q_calc[mask][3];
      cand_valid[mask] = SATURATE && !seq_sat;
      for (i = 0; i < 4; i = i + 1) begin
        cand_valid[mask] = cand_valid[mask] &&
          ((cand_v[mask][i] >= 0) == mask_bit(mask, i)) &&
          (cand_v[mask][i] <= $signed({{(CALC_W-ACC_W){V_MAX[ACC_W-1]}}, V_MAX})) &&
          (cand_v[mask][i] >= $signed({{(CALC_W-ACC_W){V_MIN[ACC_W-1]}}, V_MIN}));
      end
      if (cand_valid[mask] && !lookahead_valid) begin
        lookahead_valid = 1'b1;
        selected_mask = mask;
        selected_e = cand_e[mask];
        selected_v = cand_v[mask][3];
      end
    end

    if (lookahead_valid) begin
      y_vec = selected_mask;
      e_out = selected_e;
      v_state = selected_v;
      for (i = 0; i < 4; i = i + 1)
        y_signed_vec[i*W_IN +: W_IN] = selected_mask[i] ? Y_POS : Y_NEG;
    end else begin
      y_vec = {seq_bit[3], seq_bit[2], seq_bit[1], seq_bit[0]};
      e_out = seq_e[3];
      v_state = seq_v[3];
      for (i = 0; i < 4; i = i + 1)
        y_signed_vec[i*W_IN +: W_IN] = seq_bit[i] ? Y_POS : Y_NEG;
    end
  end
endmodule

`default_nettype wire
