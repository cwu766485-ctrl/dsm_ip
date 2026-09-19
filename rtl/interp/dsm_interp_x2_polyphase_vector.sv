`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Vector x2 cubic polyphase interpolator.
//
// Lane 0 is the earliest complex input sample.  For each input lane the
// output order is phase-0 then phase-1, hence lane 0 is also earliest at the
// doubled rate.  Phase-0 is an exact sample copy; phase-1 is a causal cubic
// fractional-delay FIR using x[n], x[n-1], x[n-2], x[n-3]:
//   [5, 15, -5, 1] / 16.
//
// The three-sample history is transferred at every accepted vector word.  Two
// elastic pipeline stages keep DSP multiplication, arithmetic and output
// backpressure separate.
//------------------------------------------------------------------------------
module dsm_interp_x2_polyphase_vector #(
  parameter int W = 16,
  parameter int LANES_IN = 8,
  parameter int COEFF_FRAC = 14
) (
  input  wire logic                             clk,
  input  wire logic                             rst_n,
  input  wire logic                             enable,
  input  wire logic                             in_valid,
  output wire logic                             in_ready,
  input  wire logic signed [LANES_IN*W-1:0]     in_i_vec,
  input  wire logic signed [LANES_IN*W-1:0]     in_q_vec,
  output logic                                  out_valid,
  input  wire logic                             out_ready,
  output logic signed [2*LANES_IN*W-1:0]       out_i_vec,
  output logic signed [2*LANES_IN*W-1:0]       out_q_vec
);
  localparam int HISTORY = 3;
  localparam int LANES_OUT = 2*LANES_IN;
  localparam int ACC_W = W + COEFF_FRAC + 3;

  logic signed [W-1:0] history_i [0:HISTORY-1];
  logic signed [W-1:0] history_q [0:HISTORY-1];
  logic s0_valid;
  logic signed [LANES_IN*W-1:0] s0_i_vec, s0_q_vec;
  logic signed [W-1:0] s0_history_i [0:HISTORY-1];
  logic signed [W-1:0] s0_history_q [0:HISTORY-1];
  logic s1_valid;
  logic signed [LANES_IN*W-1:0] s1_phase0_i, s1_phase0_q;
  logic signed [ACC_W-1:0] s1_prod_i [0:LANES_IN-1][0:3];
  logic signed [ACC_W-1:0] s1_prod_q [0:LANES_IN-1][0:3];

  wire logic s2_ready = !out_valid || out_ready;
  wire logic s1_ready = !s1_valid || s2_ready;
  wire logic s0_ready = !s0_valid || s1_ready;
  assign in_ready = enable && s0_ready;

  function automatic logic signed [W-1:0] round_sat(
    input logic signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] rounded, maxv, minv;
    begin
      if (value >= 0)
        rounded = (value + (signed'(1) <<< (COEFF_FRAC-1))) >>> COEFF_FRAC;
      else
        rounded = -(((-value) + (signed'(1) <<< (COEFF_FRAC-1))) >>> COEFF_FRAC);
      maxv = (signed'(1) <<< (W-1)) - 1;
      minv = -(signed'(1) <<< (W-1));
      if (rounded > maxv) round_sat = maxv[W-1:0];
      else if (rounded < minv) round_sat = minv[W-1:0];
      else round_sat = rounded[W-1:0];
    end
  endfunction

  always_ff @(posedge clk) begin : p_interp
    logic signed [W-1:0] si, sq;
    logic signed [ACC_W-1:0] acc_i, acc_q;
    if (!rst_n || !enable) begin
      s0_valid <= 1'b0;
      s1_valid <= 1'b0;
      out_valid <= 1'b0;
      out_i_vec <= '0;
      out_q_vec <= '0;
      for (int h = 0; h < HISTORY; h = h + 1) begin
        history_i[h] <= '0;
        history_q[h] <= '0;
      end
    end else begin
      if (s2_ready) begin
        out_valid <= s1_valid;
        if (s1_valid) begin
          for (int lane = 0; lane < LANES_IN; lane = lane + 1) begin
            acc_i = s1_prod_i[lane][0] + s1_prod_i[lane][1] +
                    s1_prod_i[lane][2] + s1_prod_i[lane][3];
            acc_q = s1_prod_q[lane][0] + s1_prod_q[lane][1] +
                    s1_prod_q[lane][2] + s1_prod_q[lane][3];
            out_i_vec[(2*lane)*W +: W] <= s1_phase0_i[lane*W +: W];
            out_q_vec[(2*lane)*W +: W] <= s1_phase0_q[lane*W +: W];
            out_i_vec[(2*lane+1)*W +: W] <= round_sat(acc_i);
            out_q_vec[(2*lane+1)*W +: W] <= round_sat(acc_q);
          end
        end
      end

      if (s1_ready) begin
        s1_valid <= s0_valid;
        if (s0_valid) begin
          for (int lane = 0; lane < LANES_IN; lane = lane + 1) begin
            s1_phase0_i[lane*W +: W] <= s0_i_vec[lane*W +: W];
            s1_phase0_q[lane*W +: W] <= s0_q_vec[lane*W +: W];
            for (int tap = 0; tap < 4; tap = tap + 1) begin
              if (tap <= lane) begin
                si = s0_i_vec[(lane-tap)*W +: W];
                sq = s0_q_vec[(lane-tap)*W +: W];
              end else begin
                si = s0_history_i[tap-lane-1];
                sq = s0_history_q[tap-lane-1];
              end
              case (tap)
                0: begin s1_prod_i[lane][tap] <= signed'(si)*16'sd5120;  s1_prod_q[lane][tap] <= signed'(sq)*16'sd5120;  end
                1: begin s1_prod_i[lane][tap] <= signed'(si)*16'sd15360; s1_prod_q[lane][tap] <= signed'(sq)*16'sd15360; end
                2: begin s1_prod_i[lane][tap] <= -signed'(si)*16'sd5120; s1_prod_q[lane][tap] <= -signed'(sq)*16'sd5120; end
                default: begin s1_prod_i[lane][tap] <= signed'(si)*16'sd1024; s1_prod_q[lane][tap] <= signed'(sq)*16'sd1024; end
              endcase
            end
          end
        end
      end

      if (s0_ready) begin
        s0_valid <= in_valid;
        if (in_valid) begin
          s0_i_vec <= in_i_vec;
          s0_q_vec <= in_q_vec;
          for (int h = 0; h < HISTORY; h = h + 1) begin
            s0_history_i[h] <= history_i[h];
            s0_history_q[h] <= history_q[h];
            if (h < LANES_IN) begin
              history_i[h] <= in_i_vec[(LANES_IN-1-h)*W +: W];
              history_q[h] <= in_q_vec[(LANES_IN-1-h)*W +: W];
            end else begin
              history_i[h] <= history_i[h-LANES_IN];
              history_q[h] <= history_q[h-LANES_IN];
            end
          end
        end
      end
    end
  end
endmodule

`default_nettype wire
