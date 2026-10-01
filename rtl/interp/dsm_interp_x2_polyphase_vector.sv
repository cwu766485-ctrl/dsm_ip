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
// elastic pipeline stages keep DSP multiplication, accumulation, rounding and
// output
// backpressure separate.
//
// INTERP_TAPS selects a causal half-sample fractional-delay preset.  The
// default 4-tap cubic coefficients are bit-for-bit unchanged.  Smaller
// presets are normalized to unity DC gain and exist only as explicit PPA
// study SKUs; they must be evaluated by the matching MATLAB model before a
// communication-quality claim is made.
//------------------------------------------------------------------------------
module dsm_interp_x2_polyphase_vector #(
  parameter int W = 16,
  parameter int LANES_IN = 8,
  parameter int COEFF_FRAC = 14,
  parameter int INTERP_TAPS = 4,
  parameter bit HOLD_STATE_ON_DISABLE = 1'b0
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
  localparam int HISTORY = (INTERP_TAPS > 1) ? INTERP_TAPS-1 : 1;
  localparam int LANES_OUT = 2*LANES_IN;
  localparam int ACC_W = W + COEFF_FRAC + 3;

  logic signed [W-1:0] history_i [0:HISTORY-1];
  logic signed [W-1:0] history_q [0:HISTORY-1];
  // Per-lane copies prevent one word-valid net from directly driving every
  // lane's DSP CE.  lane 0 remains the formal word transaction; assertions
  // prove all replicas stay identical.
  (* KEEP = "TRUE", MAX_FANOUT = 4 *) logic [LANES_IN-1:0] s0_valid_lane;
  logic signed [LANES_IN*W-1:0] s0_i_vec, s0_q_vec;
  logic signed [W-1:0] s0_history_i [0:HISTORY-1];
  logic signed [W-1:0] s0_history_q [0:HISTORY-1];
  (* KEEP = "TRUE", MAX_FANOUT = 4 *) logic [LANES_IN-1:0] s1_valid_lane;
  logic signed [LANES_IN*W-1:0] s1_phase0_i, s1_phase0_q;
  logic signed [ACC_W-1:0] s1_prod_i [0:LANES_IN-1][0:INTERP_TAPS-1];
  logic signed [ACC_W-1:0] s1_prod_q [0:LANES_IN-1][0:INTERP_TAPS-1];
  logic s2_valid;
  logic signed [LANES_IN*W-1:0] s2_phase0_i, s2_phase0_q;
  // Keep the accumulation width identical to the legacy procedural
  // accumulator.  The new register changes latency only, not arithmetic.
  logic signed [ACC_W-1:0] s2_acc_i [0:LANES_IN-1];
  logic signed [ACC_W-1:0] s2_acc_q [0:LANES_IN-1];

  wire logic s0_valid = s0_valid_lane[0];
  wire logic s1_valid = s1_valid_lane[0];
  wire logic s3_ready = !out_valid || out_ready;
  wire logic s2_ready = !s2_valid || s3_ready;
  wire logic s1_ready = !s1_valid || s2_ready;
  wire logic s0_ready = !s0_valid || s1_ready;
  assign in_ready = enable && s0_ready;

  initial begin
    if (INTERP_TAPS < 2 || INTERP_TAPS > 4)
      $error("INTERP_TAPS must be 2, 3, or 4; got %0d", INTERP_TAPS);
  end

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
    if (!rst_n) begin
      s0_valid_lane <= '0;
      s1_valid_lane <= '0;
      s2_valid <= 1'b0;
      out_valid <= 1'b0;
      out_i_vec <= '0;
      out_q_vec <= '0;
      for (int h = 0; h < HISTORY; h = h + 1) begin
        history_i[h] <= '0;
        history_q[h] <= '0;
      end
    end else if (!enable) begin
      s0_valid_lane <= '0;
      s1_valid_lane <= '0;
      s2_valid <= 1'b0;
      out_valid <= 1'b0;
      if (!HOLD_STATE_ON_DISABLE) begin
        out_i_vec <= '0;
        out_q_vec <= '0;
        for (int h = 0; h < HISTORY; h = h + 1) begin
          history_i[h] <= '0;
          history_q[h] <= '0;
        end
      end
    end else begin
      if (s3_ready) begin
        out_valid <= s2_valid;
        // The output payload is deliberately written even for an invalid
        // elastic slot.  It is ignored whenever out_valid is low, while this
        // prevents word_valid from becoming a high-fanout CE on every output
        // register.  A valid word is still strictly word-atomic.
        for (int lane = 0; lane < LANES_IN; lane = lane + 1) begin
            out_i_vec[(2*lane)*W +: W] <= s2_phase0_i[lane*W +: W];
            out_q_vec[(2*lane)*W +: W] <= s2_phase0_q[lane*W +: W];
            out_i_vec[(2*lane+1)*W +: W] <= round_sat(s2_acc_i[lane]);
            out_q_vec[(2*lane+1)*W +: W] <= round_sat(s2_acc_q[lane]);
        end
      end

      if (s2_ready) begin
        s2_valid <= s1_valid;
        // Register the legacy ACC_W sum before rounding/saturation.  Payload
        // writes are unconditional so s1_valid cannot become a large CE net.
        for (int lane = 0; lane < LANES_IN; lane = lane + 1) begin
          acc_i = '0;
          acc_q = '0;
          for (int tap = 0; tap < INTERP_TAPS; tap = tap + 1) begin
            acc_i = acc_i + s1_prod_i[lane][tap];
            acc_q = acc_q + s1_prod_q[lane][tap];
          end
          s2_phase0_i[lane*W +: W] <= s1_phase0_i[lane*W +: W];
          s2_phase0_q[lane*W +: W] <= s1_phase0_q[lane*W +: W];
          s2_acc_i[lane] <= acc_i;
          s2_acc_q[lane] <= acc_q;
        end
      end

      if (s1_ready) begin
        s1_valid_lane <= s0_valid_lane;
        // As above, invalid payload values are don't-care.  Updating these
        // product registers unconditionally removes the global valid signal
        // from the inferred DSP CEA pins; only the small valid pipeline
        // carries transaction control.
        for (int lane = 0; lane < LANES_IN; lane = lane + 1) begin
            s1_phase0_i[lane*W +: W] <= s0_i_vec[lane*W +: W];
            s1_phase0_q[lane*W +: W] <= s0_q_vec[lane*W +: W];
            for (int tap = 0; tap < INTERP_TAPS; tap = tap + 1) begin
              if (tap <= lane) begin
                si = s0_i_vec[(lane-tap)*W +: W];
                sq = s0_q_vec[(lane-tap)*W +: W];
              end else begin
                si = s0_history_i[tap-lane-1];
                sq = s0_history_q[tap-lane-1];
              end
              if (INTERP_TAPS == 2) begin
                // Linear: [1/2, 1/2].
                s1_prod_i[lane][tap] <= signed'(si)*16'sd8192;
                s1_prod_q[lane][tap] <= signed'(sq)*16'sd8192;
              end else if (INTERP_TAPS == 3) begin
                // Causal quadratic: [3, 6, -1] / 8.
                case (tap)
                  0: begin s1_prod_i[lane][tap] <= signed'(si)*16'sd6144;  s1_prod_q[lane][tap] <= signed'(sq)*16'sd6144;  end
                  1: begin s1_prod_i[lane][tap] <= signed'(si)*16'sd12288; s1_prod_q[lane][tap] <= signed'(sq)*16'sd12288; end
                  default: begin s1_prod_i[lane][tap] <= -signed'(si)*16'sd2048; s1_prod_q[lane][tap] <= -signed'(sq)*16'sd2048; end
                endcase
              end else begin
                // Cubic: [5, 15, -5, 1] / 16 (legacy default).
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
        s0_valid_lane <= {LANES_IN{in_valid}};
        // Capture payload whenever the elastic slot advances.  If in_valid is
        // low it is unreachable at the output because s0_valid_lane is zero;
        // the recursive history remains protected below and is updated only
        // for an accepted source word.
        s0_i_vec <= in_i_vec;
        s0_q_vec <= in_q_vec;
        if (in_valid) begin
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

`ifndef SYNTHESIS
  always @(posedge clk) begin
    if (rst_n && enable) begin
      assert (s0_valid_lane == {LANES_IN{s0_valid_lane[0]}})
        else $error("interpolator s0 valid replicas diverged: %b", s0_valid_lane);
      assert (s1_valid_lane == {LANES_IN{s1_valid_lane[0]}})
        else $error("interpolator s1 valid replicas diverged: %b", s1_valid_lane);
    end
  end
`endif
endmodule

`default_nettype wire
