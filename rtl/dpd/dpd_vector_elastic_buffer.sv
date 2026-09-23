`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// One-word ready/valid register slice for a packed complex vector.
//
// The buffer is intentionally placed after the memory-DPD.  It registers one
// atomic output transaction before the second x2 interpolator, cutting the
// DPD valid-pipeline fanout into the interpolator DSP clock-enables.  Data is
// accepted and released as one word; no lane can be inserted, dropped, or
// reordered.  The only architectural change is one fixed core-clock latency.
//------------------------------------------------------------------------------
module dpd_vector_elastic_buffer #(
  parameter int W = 16,
  parameter int LANES = 16
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [LANES*W-1:0]    in_i_vec,
  input  wire logic signed [LANES*W-1:0]    in_q_vec,
  output wire logic                         out_valid,
  input  wire logic                         out_ready,
  output wire logic signed [LANES*W-1:0]    out_i_vec,
  output wire logic signed [LANES*W-1:0]    out_q_vec
);
  logic full;
  logic signed [LANES*W-1:0] data_i, data_q;

  assign in_ready = !full || out_ready;
  assign out_valid = full;
  assign out_i_vec = data_i;
  assign out_q_vec = data_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      full <= 1'b0;
      data_i <= '0;
      data_q <= '0;
    end else if (in_ready) begin
      // Keep the transaction control and the wide payload separate.  If this
      // buffer is empty, or its prior word is being consumed, sampling an
      // invalid payload is harmless because full is cleared in the same
      // cycle.  Making that write unconditional prevents in_valid from
      // becoming the clock-enable of all 512 payload flops; it now drives
      // only the one-bit full state.
      full <= in_valid;
      data_i <= in_i_vec;
      data_q <= in_q_vec;
    end
  end
endmodule

`default_nettype wire
