`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Frame-constant Q2.14 gain for a continuous complex vector stream.
//
// `in_frame_start` is asserted only with an accepted first word.  Its Q2.14
// gain is applied to that same word and retained for subsequent words until
// the next accepted frame start.  The module has two elastic stages, so it
// neither inserts nor removes samples under downstream backpressure.
//------------------------------------------------------------------------------
module dsm_frame_gain_vector #(
  parameter int W = 16,
  parameter int LANES = 8,
  parameter int GAIN_W = 16,
  parameter int GAIN_FRAC = 14,
  parameter logic signed [GAIN_W-1:0] RESET_GAIN = (1 <<< GAIN_FRAC)
) (
  input  wire logic                       clk,
  input  wire logic                       rst_n,
  input  wire logic                       enable,
  input  wire logic                       in_valid,
  output wire logic                       in_ready,
  input  wire logic                       in_frame_start,
  input  wire logic signed [GAIN_W-1:0]   in_frame_gain,
  input  wire logic signed [LANES*W-1:0]  in_i_vec,
  input  wire logic signed [LANES*W-1:0]  in_q_vec,
  output logic                            out_valid,
  input  wire logic                       out_ready,
  output logic signed [LANES*W-1:0]       out_i_vec,
  output logic signed [LANES*W-1:0]       out_q_vec
);
  localparam int PROD_W = W + GAIN_W;
  logic                                    s0_valid;
  logic signed [LANES*W-1:0]               s0_i_vec, s0_q_vec;
  logic signed [GAIN_W-1:0]                s0_gain, active_gain;
  wire logic s1_ready = !out_valid || out_ready;
  wire logic s0_ready = !s0_valid || s1_ready;

  assign in_ready = enable && s0_ready;

  function automatic logic signed [W-1:0] round_sat(
    input logic signed [PROD_W-1:0] value
  );
    logic signed [PROD_W-1:0] rounded, maxv, minv;
    begin
      if (value >= 0)
        rounded = (value + (signed'(1) <<< (GAIN_FRAC-1))) >>> GAIN_FRAC;
      else
        rounded = -(((-value) + (signed'(1) <<< (GAIN_FRAC-1))) >>> GAIN_FRAC);
      maxv = (signed'(1) <<< (W-1)) - 1;
      minv = -(signed'(1) <<< (W-1));
      if (rounded > maxv) round_sat = maxv[W-1:0];
      else if (rounded < minv) round_sat = minv[W-1:0];
      else round_sat = rounded[W-1:0];
    end
  endfunction

  always_ff @(posedge clk) begin : p_gain
    logic signed [PROD_W-1:0] prod_i, prod_q;
    if (!rst_n || !enable) begin
      s0_valid <= 1'b0;
      out_valid <= 1'b0;
      active_gain <= RESET_GAIN;
      s0_gain <= RESET_GAIN;
      out_i_vec <= '0;
      out_q_vec <= '0;
    end else begin
      if (s1_ready) begin
        out_valid <= s0_valid;
        if (s0_valid) begin
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            prod_i = $signed(s0_i_vec[lane*W +: W]) * $signed(s0_gain);
            prod_q = $signed(s0_q_vec[lane*W +: W]) * $signed(s0_gain);
            out_i_vec[lane*W +: W] <= round_sat(prod_i);
            out_q_vec[lane*W +: W] <= round_sat(prod_q);
          end
        end
      end
      if (s0_ready) begin
        s0_valid <= in_valid;
        if (in_valid) begin
          s0_i_vec <= in_i_vec;
          s0_q_vec <= in_q_vec;
          s0_gain <= in_frame_start ? in_frame_gain : active_gain;
          if (in_frame_start) active_gain <= in_frame_gain;
        end
      end
    end
  end
endmodule

`default_nettype wire
