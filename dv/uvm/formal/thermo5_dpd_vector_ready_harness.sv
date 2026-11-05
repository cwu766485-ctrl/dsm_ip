`timescale 1ns/1ps
`default_nettype none

// Product-shaped control proof for the 16-lane, one-tap DPD used by Thermo5.
// Payload and coefficients are unconstrained because this target is the
// ready/valid relation, not DPD arithmetic equivalence.
module thermo5_dpd_vector_ready_harness (
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic out_ready,
  input logic [2:0] active_taps,
  input logic signed [15:0] c1_re,
  input logic signed [15:0] c1_im,
  input logic signed [15:0] c3_re,
  input logic signed [15:0] c3_im,
  input logic signed [15:0] c5_re,
  input logic signed [15:0] c5_im,
  input logic signed [255:0] in_i_vec,
  input logic signed [255:0] in_q_vec
);
  logic in_ready;
  logic out_valid;
  logic [1:0] out_meta;
  logic signed [255:0] out_i_vec;
  logic signed [255:0] out_q_vec;

  dpd_vector16_memory_poly #(
    .W(16), .LANES(16), .COEFF_W(16), .COEFF_FRAC(14), .MAX_TAPS(1)
  ) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .in_valid(in_valid),
    .in_ready(in_ready), .in_meta(2'b00), .in_i_vec(in_i_vec),
    .in_q_vec(in_q_vec), .out_valid(out_valid), .out_ready(out_ready),
    .out_meta(out_meta), .out_i_vec(out_i_vec), .out_q_vec(out_q_vec)
  );

  default clocking cb @(posedge clk); endclocking

  // The product instance's line-93 false/true tuple is exactly
  // (!in_ready && !out_valid). A legal output stall must retain the complete
  // output transaction until the sink accepts it.
  a_empty_output_allows_input:
    assert property (disable iff (!rst_n) !out_valid |-> in_ready);
  a_stalled_output_is_held:
    assert property (disable iff (!rst_n)
      out_valid && !out_ready |=> out_valid &&
      $stable({out_meta, out_i_vec, out_q_vec}));

  c_input_accept: cover property (disable iff (!rst_n)
    in_valid && in_ready);
  c_output_transfer: cover property (disable iff (!rst_n)
    out_valid && out_ready);
  c_output_stall: cover property (disable iff (!rst_n)
    out_valid && !out_ready);
  c_stall_release: cover property (disable iff (!rst_n)
    out_valid && !out_ready ##1 out_valid && out_ready);
  c_line93_uncovered_tuple: cover property (disable iff (!rst_n)
    !in_ready && !out_valid);
endmodule

`default_nettype wire
