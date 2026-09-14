`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// 16-input / 64-output x4 complex vector polyphase interpolator.
//
// Input lane 0 is earliest. An accepted word produces phases 0..3 for input
// lane 0, then phases 0..3 for lane 1, through lane 15. The output vector
// therefore contains 64 consecutive time samples with lane 0 earliest.
//
// The filter arithmetic is the 29-tap fixed-point realization used by
// dsm_interp_fir_polyphase. To sustain one input word per clock at 218.75 MHz,
  // its tap sum is divided into 0..2, 3..5 and 6..7 groups. Five elastic
  // internal stages carry an input/history snapshot and partial sums; low/mid
  // and high partials are merged in separate registered stages. This adds
// latency only: coefficients, signed rounding, saturation and lane order do
// not change. Seven source-rate samples are retained across input words.
//------------------------------------------------------------------------------
module dsm_interp_x4_polyphase16 #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int LANES_IN = 16,
  parameter int INTERP = 4,
  parameter int COEFF_W = 18,
  parameter int COEFF_FRAC = 16,
  parameter int ACC_W = 48,
  parameter int NTAPS = 29
) (
  input  wire logic                             clk,
  input  wire logic                             rst_n,
  input  wire logic                             enable,
  input  wire logic                             in_valid,
  output wire logic                             in_ready,
  input  wire logic signed [LANES_IN*W_IN-1:0]  in_i_vec,
  input  wire logic signed [LANES_IN*W_IN-1:0]  in_q_vec,
  output logic signed [LANES_IN*INTERP*W_OUT-1:0] out_i_vec,
  output logic signed [LANES_IN*INTERP*W_OUT-1:0] out_q_vec,
  output logic                                  out_valid,
  input  wire logic                             out_ready
);
  localparam int HISTORY_DEPTH = (NTAPS - 1) / INTERP;
  localparam int LANES_OUT = LANES_IN * INTERP;

  logic signed [W_IN-1:0] history_i [0:HISTORY_DEPTH-1];
  logic signed [W_IN-1:0] history_q [0:HISTORY_DEPTH-1];

  logic s1_valid;
  logic signed [LANES_IN*W_IN-1:0] s1_i_vec, s1_q_vec;
  logic signed [W_IN-1:0] s1_history_i [0:HISTORY_DEPTH-1];
  logic signed [W_IN-1:0] s1_history_q [0:HISTORY_DEPTH-1];

  logic s2_valid;
  logic signed [LANES_IN*W_IN-1:0] s2_i_vec, s2_q_vec;
  logic signed [W_IN-1:0] s2_history_i [0:HISTORY_DEPTH-1];
  logic signed [W_IN-1:0] s2_history_q [0:HISTORY_DEPTH-1];
  logic signed [ACC_W-1:0] s2_low_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s2_low_q [0:LANES_OUT-1];

  logic s3_valid;
  logic signed [LANES_IN*W_IN-1:0] s3_i_vec, s3_q_vec;
  logic signed [W_IN-1:0] s3_history_i [0:HISTORY_DEPTH-1];
  logic signed [W_IN-1:0] s3_history_q [0:HISTORY_DEPTH-1];
  logic signed [ACC_W-1:0] s3_low_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s3_low_q [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s3_mid_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s3_mid_q [0:LANES_OUT-1];

  logic s4_valid;
  logic signed [ACC_W-1:0] s4_low_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s4_low_q [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s4_mid_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s4_mid_q [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s4_high_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s4_high_q [0:LANES_OUT-1];

  logic s5_valid;
  logic signed [ACC_W-1:0] s5_low_mid_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s5_low_mid_q [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s5_high_i [0:LANES_OUT-1];
  logic signed [ACC_W-1:0] s5_high_q [0:LANES_OUT-1];

  wire logic s6_ready = !out_valid || out_ready;
  wire logic s5_ready = !s5_valid || s6_ready;
  wire logic s4_ready = !s4_valid || s5_ready;
  wire logic s3_ready = !s3_valid || s4_ready;
  wire logic s2_ready = !s2_valid || s3_ready;
  wire logic s1_ready = !s1_valid || s2_ready;

  function automatic signed [COEFF_W-1:0] coeff(input int idx);
    begin
      case (idx)
        0: coeff = 18'sd128; 1: coeff = 18'sd512; 2: coeff = 18'sd1280;
        3: coeff = 18'sd2560; 4: coeff = 18'sd4480; 5: coeff = 18'sd7168;
        6: coeff = 18'sd10752; 7: coeff = 18'sd15360; 8: coeff = 18'sd20608;
        9: coeff = 18'sd26112; 10: coeff = 18'sd31488; 11: coeff = 18'sd36352;
        12: coeff = 18'sd40320; 13: coeff = 18'sd43008; 14: coeff = 18'sd44032;
        15: coeff = 18'sd43008; 16: coeff = 18'sd40320; 17: coeff = 18'sd36352;
        18: coeff = 18'sd31488; 19: coeff = 18'sd26112; 20: coeff = 18'sd20608;
        21: coeff = 18'sd15360; 22: coeff = 18'sd10752; 23: coeff = 18'sd7168;
        24: coeff = 18'sd4480; 25: coeff = 18'sd2560; 26: coeff = 18'sd1280;
        27: coeff = 18'sd512; 28: coeff = 18'sd128;
        default: coeff = '0;
      endcase
    end
  endfunction

  function automatic signed [ACC_W-1:0] round_shift(
    input signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] bias;
    begin
      bias = signed'(1) <<< (COEFF_FRAC - 1);
      if (value >= 0) round_shift = (value + bias) >>> COEFF_FRAC;
      else            round_shift = -(((-value) + bias) >>> COEFF_FRAC);
    end
  endfunction

  function automatic signed [W_OUT-1:0] sat_out(
    input signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] maxv;
    logic signed [ACC_W-1:0] minv;
    begin
      maxv = (signed'(1) <<< (W_OUT - 1)) - 1;
      minv = -(signed'(1) <<< (W_OUT - 1));
      if (value > maxv) sat_out = signed'(maxv[W_OUT-1:0]);
      else if (value < minv) sat_out = signed'(minv[W_OUT-1:0]);
      else sat_out = signed'(value[W_OUT-1:0]);
    end
  endfunction

  assign in_ready = enable && s1_ready;

  always_ff @(posedge clk) begin : p_vector_polyphase_pipeline
    logic signed [ACC_W-1:0] low_i, low_q;
    logic signed [ACC_W-1:0] mid_i, mid_q;
    logic signed [ACC_W-1:0] high_i, high_q;
    logic signed [W_IN-1:0] sample_i, sample_q;
    if (!rst_n || !enable) begin
      s1_valid <= 1'b0;
      s2_valid <= 1'b0;
      s3_valid <= 1'b0;
      s4_valid <= 1'b0;
      s5_valid <= 1'b0;
      out_valid <= 1'b0;
      out_i_vec <= '0;
      out_q_vec <= '0;
      for (int h = 0; h < HISTORY_DEPTH; h = h + 1) begin
        history_i[h] <= '0;
        history_q[h] <= '0;
      end
    end else begin
      // Registered final add/round/saturate stage. It has no FIR multiplication.
      if (s6_ready) begin
        out_valid <= s5_valid;
        if (s5_valid) begin
          for (int output_lane = 0; output_lane < LANES_OUT; output_lane = output_lane + 1) begin
            out_i_vec[output_lane*W_OUT +: W_OUT] <= sat_out(round_shift(
              s5_low_mid_i[output_lane] + s5_high_i[output_lane]));
            out_q_vec[output_lane*W_OUT +: W_OUT] <= sat_out(round_shift(
              s5_low_mid_q[output_lane] + s5_high_q[output_lane]));
          end
        end
      end

      // Merge low and middle partial sums independently from the high group.
      // A register boundary here prevents a three-operand DSP merge.
      if (s5_ready) begin
        s5_valid <= s4_valid;
        if (s4_valid) begin
          for (int output_lane = 0; output_lane < LANES_OUT; output_lane = output_lane + 1) begin
            s5_low_mid_i[output_lane] <= s4_low_i[output_lane] + s4_mid_i[output_lane];
            s5_low_mid_q[output_lane] <= s4_low_q[output_lane] + s4_mid_q[output_lane];
            s5_high_i[output_lane] <= s4_high_i[output_lane];
            s5_high_q[output_lane] <= s4_high_q[output_lane];
          end
        end
      end

      // High group: taps 6..7. Register before final partial-sum merge.
      if (s4_ready) begin
        s4_valid <= s3_valid;
        if (s3_valid) begin
          for (int input_lane = 0; input_lane < LANES_IN; input_lane = input_lane + 1) begin
            for (int phase = 0; phase < INTERP; phase = phase + 1) begin
              high_i = '0;
              high_q = '0;
              for (int tap = 6; tap <= HISTORY_DEPTH; tap = tap + 1) begin
                if ((phase + tap * INTERP) < NTAPS) begin
                  if (tap <= input_lane) begin
                    sample_i = s3_i_vec[(input_lane-tap)*W_IN +: W_IN];
                    sample_q = s3_q_vec[(input_lane-tap)*W_IN +: W_IN];
                  end else begin
                    sample_i = s3_history_i[tap-input_lane-1];
                    sample_q = s3_history_q[tap-input_lane-1];
                  end
                  high_i = high_i + signed'(sample_i) * signed'(coeff(phase + tap * INTERP));
                  high_q = high_q + signed'(sample_q) * signed'(coeff(phase + tap * INTERP));
                end
              end
              s4_low_i[input_lane*INTERP + phase] <= s3_low_i[input_lane*INTERP + phase];
              s4_low_q[input_lane*INTERP + phase] <= s3_low_q[input_lane*INTERP + phase];
              s4_mid_i[input_lane*INTERP + phase] <= s3_mid_i[input_lane*INTERP + phase];
              s4_mid_q[input_lane*INTERP + phase] <= s3_mid_q[input_lane*INTERP + phase];
              s4_high_i[input_lane*INTERP + phase] <= high_i;
              s4_high_q[input_lane*INTERP + phase] <= high_q;
            end
          end
        end
      end

      // Middle group: taps 3..5. Carry the input/history snapshot and low sum.
      if (s3_ready) begin
        s3_valid <= s2_valid;
        if (s2_valid) begin
          s3_i_vec <= s2_i_vec;
          s3_q_vec <= s2_q_vec;
          for (int h = 0; h < HISTORY_DEPTH; h = h + 1) begin
            s3_history_i[h] <= s2_history_i[h];
            s3_history_q[h] <= s2_history_q[h];
          end
          for (int input_lane = 0; input_lane < LANES_IN; input_lane = input_lane + 1) begin
            for (int phase = 0; phase < INTERP; phase = phase + 1) begin
              mid_i = '0;
              mid_q = '0;
              for (int tap = 3; tap <= 5; tap = tap + 1) begin
                if ((phase + tap * INTERP) < NTAPS) begin
                  if (tap <= input_lane) begin
                    sample_i = s2_i_vec[(input_lane-tap)*W_IN +: W_IN];
                    sample_q = s2_q_vec[(input_lane-tap)*W_IN +: W_IN];
                  end else begin
                    sample_i = s2_history_i[tap-input_lane-1];
                    sample_q = s2_history_q[tap-input_lane-1];
                  end
                  mid_i = mid_i + signed'(sample_i) * signed'(coeff(phase + tap * INTERP));
                  mid_q = mid_q + signed'(sample_q) * signed'(coeff(phase + tap * INTERP));
                end
              end
              s3_low_i[input_lane*INTERP + phase] <= s2_low_i[input_lane*INTERP + phase];
              s3_low_q[input_lane*INTERP + phase] <= s2_low_q[input_lane*INTERP + phase];
              s3_mid_i[input_lane*INTERP + phase] <= mid_i;
              s3_mid_q[input_lane*INTERP + phase] <= mid_q;
            end
          end
        end
      end

      // Low group: taps 0..2. Tap zero selects the current source sample.
      if (s2_ready) begin
        s2_valid <= s1_valid;
        if (s1_valid) begin
          s2_i_vec <= s1_i_vec;
          s2_q_vec <= s1_q_vec;
          for (int h = 0; h < HISTORY_DEPTH; h = h + 1) begin
            s2_history_i[h] <= s1_history_i[h];
            s2_history_q[h] <= s1_history_q[h];
          end
          for (int input_lane = 0; input_lane < LANES_IN; input_lane = input_lane + 1) begin
            for (int phase = 0; phase < INTERP; phase = phase + 1) begin
              low_i = '0;
              low_q = '0;
              for (int tap = 0; tap <= 2; tap = tap + 1) begin
                if ((phase + tap * INTERP) < NTAPS) begin
                  if (tap == 0) begin
                    sample_i = s1_i_vec[input_lane*W_IN +: W_IN];
                    sample_q = s1_q_vec[input_lane*W_IN +: W_IN];
                  end else if (tap <= input_lane) begin
                    sample_i = s1_i_vec[(input_lane-tap)*W_IN +: W_IN];
                    sample_q = s1_q_vec[(input_lane-tap)*W_IN +: W_IN];
                  end else begin
                    sample_i = s1_history_i[tap-input_lane-1];
                    sample_q = s1_history_q[tap-input_lane-1];
                  end
                  low_i = low_i + signed'(sample_i) * signed'(coeff(phase + tap * INTERP));
                  low_q = low_q + signed'(sample_q) * signed'(coeff(phase + tap * INTERP));
                end
              end
              s2_low_i[input_lane*INTERP + phase] <= low_i;
              s2_low_q[input_lane*INTERP + phase] <= low_q;
            end
          end
        end
      end

      // Snapshot input/history before the architectural history advances.
      if (s1_ready) begin
        s1_valid <= in_valid;
        if (in_valid) begin
          s1_i_vec <= in_i_vec;
          s1_q_vec <= in_q_vec;
          for (int h = 0; h < HISTORY_DEPTH; h = h + 1) begin
            s1_history_i[h] <= history_i[h];
            s1_history_q[h] <= history_q[h];
            history_i[h] <= in_i_vec[(LANES_IN-1-h)*W_IN +: W_IN];
            history_q[h] <= in_q_vec[(LANES_IN-1-h)*W_IN +: W_IN];
          end
        end
      end
    end
  end
endmodule

`default_nettype wire
