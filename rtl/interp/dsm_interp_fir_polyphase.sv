`timescale 1ns/1ps
`default_nettype none

// Polyphase realization of the shipped 29-tap, x8 CIC-equivalent FIR.
// I3 deliberately uses exactly I0's quantized coefficients and rounding;
// only the realization changes.  Each output phase needs at most four
// products instead of evaluating all 29 taps at the output sample rate.
module dsm_interp_fir_polyphase #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int COEFF_W = 18,
  parameter int COEFF_FRAC = 16,
  parameter int ACC_W = 48,
  parameter int INTERP = 8,
  parameter int NTAPS = 29
) (
  input  wire                         clk,
  input  wire                         rst_n,
  input  wire                         enable,
  input  wire signed [W_IN-1:0]       in_data,
  input  wire                         in_valid,
  output wire                         in_ready,
  output logic signed [W_OUT-1:0]     out_data,
  output logic                        out_valid,
  input  wire                         out_ready
);

  localparam int PHASE_W = (INTERP <= 1) ? 1 : $clog2(INTERP);
  localparam int HISTORY_DEPTH = (NTAPS - 1) / INTERP;

  logic [PHASE_W-1:0] phase;
  logic signed [W_IN-1:0] current_sample;
  logic signed [W_IN-1:0] history [0:HISTORY_DEPTH-1];

  function automatic signed [COEFF_W-1:0] coeff(input int idx);
    begin
      case (idx)
        0:  coeff = 18'sd128;
        1:  coeff = 18'sd512;
        2:  coeff = 18'sd1280;
        3:  coeff = 18'sd2560;
        4:  coeff = 18'sd4480;
        5:  coeff = 18'sd7168;
        6:  coeff = 18'sd10752;
        7:  coeff = 18'sd15360;
        8:  coeff = 18'sd20608;
        9:  coeff = 18'sd26112;
        10: coeff = 18'sd31488;
        11: coeff = 18'sd36352;
        12: coeff = 18'sd40320;
        13: coeff = 18'sd43008;
        14: coeff = 18'sd44032;
        15: coeff = 18'sd43008;
        16: coeff = 18'sd40320;
        17: coeff = 18'sd36352;
        18: coeff = 18'sd31488;
        19: coeff = 18'sd26112;
        20: coeff = 18'sd20608;
        21: coeff = 18'sd15360;
        22: coeff = 18'sd10752;
        23: coeff = 18'sd7168;
        24: coeff = 18'sd4480;
        25: coeff = 18'sd2560;
        26: coeff = 18'sd1280;
        27: coeff = 18'sd512;
        28: coeff = 18'sd128;
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
      if (value >= 0) begin
        round_shift = (value + bias) >>> COEFF_FRAC;
      end else begin
        round_shift = -(((-value) + bias) >>> COEFF_FRAC);
      end
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
      if (value > maxv) begin
        sat_out = signed'(maxv[W_OUT-1:0]);
      end else if (value < minv) begin
        sat_out = signed'(minv[W_OUT-1:0]);
      end else begin
        sat_out = signed'(value[W_OUT-1:0]);
      end
    end
  endfunction

  wire pipe_ready = !out_valid || out_ready;
  wire phase_zero = (phase == '0);
  wire do_step = pipe_ready && enable && (phase_zero ? in_valid : 1'b1);

  assign in_ready = pipe_ready && enable && phase_zero;

  always_ff @(posedge clk) begin : p_polyphase
    logic signed [ACC_W-1:0] total;
    logic signed [ACC_W-1:0] rounded;
    logic signed [W_IN-1:0] sample_value;
    if (!rst_n) begin
      phase <= '0;
      current_sample <= '0;
      out_data <= '0;
      out_valid <= 1'b0;
      for (int k = 0; k < HISTORY_DEPTH; k = k + 1) begin
        history[k] <= '0;
      end
    end else if (!enable) begin
      phase <= '0;
      current_sample <= '0;
      out_valid <= 1'b0;
      for (int k = 0; k < HISTORY_DEPTH; k = k + 1) begin
        history[k] <= '0;
      end
    end else if (pipe_ready) begin
      out_valid <= do_step;
      if (do_step) begin
        total = '0;
        for (int k = 0; k <= HISTORY_DEPTH; k = k + 1) begin
          if ((phase + k * INTERP) < NTAPS) begin
            if (k == 0) begin
              sample_value = phase_zero ? in_data : current_sample;
            end else if (phase_zero && (k == 1)) begin
              // At phase zero the history shift happens after this sum.  The
              // most recent preceding input is therefore still held in
              // current_sample, not yet in history[0].
              sample_value = current_sample;
            end else if (phase_zero) begin
              sample_value = history[k-2];
            end else begin
              sample_value = history[k-1];
            end
            total = total + signed'(sample_value) * signed'(coeff(phase + k * INTERP));
          end
        end
        rounded = round_shift(total);
        out_data <= sat_out(rounded);

        if (phase_zero) begin
          for (int k = HISTORY_DEPTH-1; k > 0; k = k - 1) begin
            history[k] <= history[k-1];
          end
          history[0] <= current_sample;
          current_sample <= in_data;
        end
        phase <= (phase == INTERP-1) ? '0 : phase + 1'b1;
      end
    end
  end
endmodule

`default_nettype wire
