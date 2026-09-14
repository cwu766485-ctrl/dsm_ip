//------------------------------------------------------------------------------
// 32-way TI-DDSM research baseline: LP EFDSM1 followed by Fs/4 digital mixing.
//
// Each lane retains its own first-order error state and is updated once per
// 32-sample word.  y_vec[0] is the earliest serialized sample.  The fixed
// mixer is +,+,-,- over lane index, so a low-pass shaped sequence is translated
// to Fs/4.  This is a separately specified TI candidate, NOT a bit-true
// implementation of dsm_core_bp_ef2 and must be accepted by RF metrics.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module ti32_lp1_fs4_dsm #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1,
  parameter int LANES = 32
) (
  input  wire logic                      clk,
  input  wire logic                      rst_n,
  input  wire logic                      enable,
  input  wire logic signed [LANES*W_IN-1:0] x_vec,
  output logic [LANES-1:0]               y_vec,
  output logic                           out_valid
);
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  localparam logic signed [ACC_W-1:0] V_MAX = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] V_MIN = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [ACC_W-1:0] e_state [0:LANES-1];
  logic signed [ACC_W:0] v_sum [0:LANES-1];
  logic signed [ACC_W-1:0] v_int [0:LANES-1];
  logic signed [ACC_W-1:0] e_next [0:LANES-1];
  logic base_bit [0:LANES-1];
  integer comb_lane;
  integer seq_lane;

  always_comb begin
    for (comb_lane = 0; comb_lane < LANES; comb_lane = comb_lane + 1) begin
      v_sum[comb_lane] = $signed({x_vec[comb_lane*W_IN + W_IN-1], x_vec[comb_lane*W_IN +: W_IN]}) +
                    $signed({e_state[comb_lane][ACC_W-1], e_state[comb_lane]});
      if (SATURATE && (v_sum[comb_lane] > $signed({V_MAX[ACC_W-1], V_MAX})))
        v_int[comb_lane] = V_MAX;
      else if (SATURATE && (v_sum[comb_lane] < $signed({V_MIN[ACC_W-1], V_MIN})))
        v_int[comb_lane] = V_MIN;
      else
        v_int[comb_lane] = v_sum[comb_lane][ACC_W-1:0];
      base_bit[comb_lane] = (v_int[comb_lane] >= 0);
      e_next[comb_lane] = v_int[comb_lane] - (base_bit[comb_lane] ?
                      {{(ACC_W-W_IN){Y_POS[W_IN-1]}}, Y_POS} :
                      {{(ACC_W-W_IN){Y_NEG[W_IN-1]}}, Y_NEG});
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y_vec     <= '0;
      out_valid <= 1'b0;
      for (seq_lane = 0; seq_lane < LANES; seq_lane = seq_lane + 1) e_state[seq_lane] <= '0;
    end else begin
      out_valid <= enable;
      if (enable) begin
        for (seq_lane = 0; seq_lane < LANES; seq_lane = seq_lane + 1) begin
          e_state[seq_lane] <= e_next[seq_lane];
          y_vec[seq_lane] <= base_bit[seq_lane] ^ ((seq_lane % 4) >= 2);
        end
      end
    end
  end
endmodule

`default_nettype wire
