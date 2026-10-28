`timescale 1ns/1ps
// Relational proof of the exact two-sample transfer used by the pairwise
// look-ahead factoring. Sixteen such transfers compose the production vector.
module thermo5_ef2_pair_equiv_harness(
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic gt_ready,
  input logic signed [31:0] in_i_poly_vec,
  input logic signed [31:0] in_q_poly_vec
);
  wire ref_in_ready, ref_gt_valid;
  wire cand_in_ready, cand_gt_valid;
  wire [3:0] ref_gt_data, cand_gt_data;

  tid32_cartesian_ef2_fs4_gt_tx #(.W(16), .CHANNELS(2), .PAIR_LOOKAHEAD(1'b0)) ref_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(ref_in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(ref_gt_valid), .gt_ready(gt_ready), .gt_data(ref_gt_data)
  );

  tid32_cartesian_ef2_fs4_gt_tx #(.W(16), .CHANNELS(2), .PAIR_LOOKAHEAD(1'b1)) candidate_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(cand_in_ready),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .gt_valid(cand_gt_valid), .gt_ready(gt_ready), .gt_data(cand_gt_data)
  );

  default clocking cb @(posedge clk); endclocking

  a_ready_equivalent: assert property (disable iff (!rst_n)
    ref_in_ready == cand_in_ready);
  a_valid_equivalent: assert property (disable iff (!rst_n)
    ref_gt_valid == cand_gt_valid);
  a_sample0_quantizers_equivalent: assert property (disable iff (!rst_n)
    ref_dut.accept_word |->
      ref_dut.raw_word_comb[1:0] == candidate_dut.raw_word_comb[1:0]);
  a_sample1_quantizers_equivalent: assert property (disable iff (!rst_n)
    ref_dut.accept_word |->
      ref_dut.raw_word_comb[3:2] == candidate_dut.raw_word_comb[3:2]);
  a_state_equivalent: assert property (disable iff (!rst_n)
    {ref_dut.err1_i_q, ref_dut.err2_i_q, ref_dut.err1_q_q, ref_dut.err2_q_q} ==
    {candidate_dut.err1_i_q, candidate_dut.err2_i_q,
     candidate_dut.err1_q_q, candidate_dut.err2_q_q});
  a_candidate_no_wrap: assert property (disable iff (!rst_n)
    candidate_dut.arithmetic_no_wrap_comb);
  a_candidate_bounds: assert property (disable iff (!rst_n)
    candidate_dut.arithmetic_bounds_comb);

  c_input_accepted: cover property (disable iff (!rst_n)
    in_valid && ref_in_ready);
  c_back_to_back_accept: cover property (disable iff (!rst_n)
    in_valid && ref_in_ready ##1 in_valid && ref_in_ready);
  c_gt_transfer: cover property (disable iff (!rst_n)
    ref_gt_valid && gt_ready);
  c_gt_stall: cover property (disable iff (!rst_n)
    ref_gt_valid && !gt_ready);
endmodule
