`timescale 1ns/1ps
`default_nettype none

// I2: monolithic x32 FIR realization of the complete I0 interpolation
// response.  The 1,195-tap prototype is decomposed into 32 phases, so a
// sample-rate cycle evaluates no more than 38 products.  This is deliberately
// a single-filter architecture; it does not retain I0's stage-level rounding.
module dsm_interp_fir_i2_polyphase #(
  parameter int W_IN = 16,
  parameter int W_OUT = 16,
  parameter int COEFF_W = 18,
  parameter int COEFF_FRAC = 16,
  parameter int ACC_W = 56,
  parameter int INTERP = 32,
  parameter int NTAPS = 1195
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

  localparam int PHASE_W = $clog2(INTERP);
  localparam int HISTORY_DEPTH = (NTAPS - 1) / INTERP;

  logic [PHASE_W-1:0] phase;
  logic signed [W_IN-1:0] current_sample;
  logic signed [W_IN-1:0] history [0:HISTORY_DEPTH-1];

`include "dsm_interp_i2_coeffs.svh"

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
              sample_value = current_sample;
            end else if (phase_zero) begin
              sample_value = history[k-2];
            end else begin
              sample_value = history[k-1];
            end
            total = total + signed'(sample_value) *
                            signed'(coeff_i2(phase + k * INTERP));
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
