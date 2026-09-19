//------------------------------------------------------------------------------
// Rate contract for a 16-complex-sample ingress feeding a fixed 64-sample
// output word every clock.  It does not interpolate data; it preserves each
// accepted source word and defines when a future polyphase engine must consume
// it.  For x128/x256, one source word supplies 32/64 output word periods.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_interp_word_cadence16 #(
  parameter int W = 16,
  parameter int LANES_IN = 16,
  parameter int WORD_PERIOD = 32
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic enable,
  input  wire logic in_valid,
  output wire logic in_ready,
  input  wire logic signed [LANES_IN*W-1:0] in_i_vec,
  input  wire logic signed [LANES_IN*W-1:0] in_q_vec,
  output logic source_word_valid,
  output logic [$clog2(WORD_PERIOD)-1:0] output_word_phase,
  output logic signed [LANES_IN*W-1:0] source_i_vec,
  output logic signed [LANES_IN*W-1:0] source_q_vec,
  output logic underflow
);
  initial begin
    if (WORD_PERIOD < 2) $error("WORD_PERIOD must be at least two");
  end

  assign in_ready = enable && (output_word_phase == '0);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_word_phase <= '0;
      source_word_valid <= 1'b0;
      source_i_vec <= '0;
      source_q_vec <= '0;
      underflow <= 1'b0;
    end else if (!enable) begin
      output_word_phase <= '0;
      source_word_valid <= 1'b0;
      underflow <= 1'b0;
    end else begin
      if (output_word_phase == WORD_PERIOD-1) begin
        output_word_phase <= '0;
      end else begin
        output_word_phase <= output_word_phase + 1'b1;
      end
      if (in_ready) begin
        source_word_valid <= in_valid;
        if (in_valid) begin
          source_i_vec <= in_i_vec;
          source_q_vec <= in_q_vec;
        end else begin
          underflow <= 1'b1;
        end
      end
    end
  end
endmodule

`default_nettype wire
