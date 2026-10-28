`timescale 1ns/1ps
// Formal safety proof for the production 32-sample EF2 recurrence.
// Inputs are unconstrained signed-16 samples; backpressure and valid may vary
// arbitrarily. The widened checks inside the DUT compare each ACC_W result
// against an independently sign-extended ACC_W+1 arithmetic result.
module thermo5_ef2_stability_harness(
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic gt_ready,
  input logic signed [511:0] in_i_poly_vec,
  input logic signed [511:0] in_q_poly_vec
);
  wire in_ready, gt_valid;
  wire [63:0] gt_data;

  tid32_cartesian_ef2_fs4_gt_tx #(.W(16), .CHANNELS(32)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data)
  );

  default clocking cb @(posedge clk); endclocking

  a_intermediates_do_not_wrap: assert property (disable iff (!rst_n)
    dut.arithmetic_no_wrap_comb);
  a_intermediates_obey_inductive_bounds: assert property (disable iff (!rst_n)
    dut.arithmetic_bounds_comb);
  a_state_updates_match_accepted_word: assert property (disable iff (!rst_n)
    dut.accept_word |=>
      {dut.err1_i_q, dut.err2_i_q, dut.err1_q_q, dut.err2_q_q} ==
      $past({dut.err1_i_next, dut.err2_i_next,
             dut.err1_q_next, dut.err2_q_next}));
  a_state_holds_without_accept: assert property (disable iff (!rst_n)
    !dut.accept_word |=> $stable(
      {dut.err1_i_q, dut.err2_i_q, dut.err1_q_q, dut.err2_q_q}));
  a_output_captures_accepted_word: assert property (disable iff (!rst_n)
    dut.accept_word |=> dut.raw_word_q == $past(dut.raw_word_comb));
  a_output_stable_when_stalled: assert property (disable iff (!rst_n)
    gt_valid && !gt_ready |=> gt_valid && $stable(gt_data));

  c_input_accepted: cover property (disable iff (!rst_n) in_valid && in_ready);
  c_gt_transfer: cover property (disable iff (!rst_n) gt_valid && gt_ready);
  c_gt_stall: cover property (disable iff (!rst_n) gt_valid && !gt_ready);
endmodule
