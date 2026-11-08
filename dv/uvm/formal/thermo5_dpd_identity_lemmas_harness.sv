`timescale 1ns/1ps
// Intermediate datapath alignment/range lemmas for the identity DPD proof.
module thermo5_identity_lemmas_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in, q_in
);
  thermo5_identity_harness model(.*);
  default clocking cb @(posedge clk); endclocking
  a_c3_zero: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s3[0] |-> model.dut.c3r_r2_s3[0]==0 && model.dut.c3i_r2_s3[0]==0);
  a_c5_zero: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c5r_r4_s4[0]==0 && model.dut.c5i_r4_s4[0]==0);
  a_linear_coeff: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c1_re_s4[0]==64'sd16384 && model.dut.c1_im_s4[0]==0);
  a_c3_delay: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s4[0] |-> model.dut.c3r_r2_s4[0]==0 && model.dut.c3i_r2_s4[0]==0);
  a_gain_identity: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s5[0] |-> model.dut.gain_re_s5[0]==64'sd16384 && model.dut.gain_im_s5[0]==0);
  a_gain_identity_s6: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s6[0] |-> model.dut.gain_re_s6[0]==64'sd16384 && model.dut.gain_im_s6[0]==0);
  a_product_i: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s7[0] |-> model.dut.i_gr_s7[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.q_gi_s7[0]==0);
  a_product_q: assert property (disable iff(!rst_n)
    model.dut.tap_enable_s7[0] |-> model.dut.q_gr_s7[0] inside {[-64'sd536870912:64'sd536854528]} && model.dut.i_gi_s7[0]==0);
  a_term_i: assert property (disable iff(!rst_n) model.dut.term_i_s8[0] inside {[-64'sd32768:64'sd32767]});
  a_term_q: assert property (disable iff(!rst_n) model.dut.term_q_s8[0] inside {[-64'sd32768:64'sd32767]});
  a_pair_i: assert property (disable iff(!rst_n) model.dut.sum_i_pair0_s8 inside {[-64'sd32768:64'sd32767]} && model.dut.sum_i_pair1_s8==0);
  a_pair_q: assert property (disable iff(!rst_n) model.dut.sum_q_pair0_s8 inside {[-64'sd32768:64'sd32767]} && model.dut.sum_q_pair1_s8==0);
  a_sum_i: assert property (disable iff(!rst_n) model.dut.sum_i_s9 inside {[-64'sd32768:64'sd32767]});
  a_sum_q: assert property (disable iff(!rst_n) model.dut.sum_q_s9 inside {[-64'sd32768:64'sd32767]});
  // Pipeline alignment lemmas: each valid token at a datapath stage must
  // carry the corresponding independently tracked input sample.  These do
  // not assume identity arithmetic or suppress downstream saturation checks.
  a_stage0_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[0] |-> model.dut.i_s0[0] == model.expected_i[0]);
  a_stage1_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[1] |-> model.dut.i_s1[0] == model.expected_i[1]);
  a_stage2_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[2] |-> model.dut.i_s2[0] == model.expected_i[2]);
  a_stage3_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[3] |-> model.dut.i_s3[0] == model.expected_i[3]);
  a_stage4_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[4] |-> model.dut.i_s4[0] == model.expected_i[4]);
  a_stage5_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[5] |-> model.dut.i_s5[0] == model.expected_i[5]);
  a_stage6_i_align: assert property (disable iff (!rst_n)
    model.expected_valid[6] |-> model.dut.i_s6[0] == model.expected_i[6]);
  a_stage0_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[0] |-> model.dut.q_s0[0] == model.expected_q[0]);
  a_stage1_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[1] |-> model.dut.q_s1[0] == model.expected_q[1]);
  a_stage2_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[2] |-> model.dut.q_s2[0] == model.expected_q[2]);
  a_stage3_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[3] |-> model.dut.q_s3[0] == model.expected_q[3]);
  a_stage4_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[4] |-> model.dut.q_s4[0] == model.expected_q[4]);
  a_stage5_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[5] |-> model.dut.q_s5[0] == model.expected_q[5]);
  a_stage6_q_align: assert property (disable iff (!rst_n)
    model.expected_valid[6] |-> model.dut.q_s6[0] == model.expected_q[6]);

  // Extend the token-indexed reference through the arithmetic stages. The
  // reference pipeline advances on the DUT ready/valid clock enable, so these
  // checks retain their meaning during arbitrary output stalls.
  a_stage7_i_product_identity: assert property (disable iff (!rst_n)
    model.expected_valid[7] |->
      model.dut.i_gr_s7[0] == ($signed(model.expected_i[7]) * 64'sd16384) &&
      model.dut.q_gi_s7[0] == 64'sd0);
  a_stage7_q_product_identity: assert property (disable iff (!rst_n)
    model.expected_valid[7] |->
      model.dut.i_gi_s7[0] == 64'sd0 &&
      model.dut.q_gr_s7[0] == ($signed(model.expected_q[7]) * 64'sd16384));
  a_stage7_valid_align: assert property (disable iff (!rst_n)
    model.expected_valid[7] == model.dut.tap_enable_s7[0]);

  a_stage8_i_term_identity: assert property (disable iff (!rst_n)
    model.expected_valid[8] |->
      model.dut.term_i_s8[0] == $signed(model.expected_i[8]));
  a_stage8_q_term_identity: assert property (disable iff (!rst_n)
    model.expected_valid[8] |->
      model.dut.term_q_s8[0] == $signed(model.expected_q[8]));

  a_stage9_i_pair_identity: assert property (disable iff (!rst_n)
    model.expected_valid[9] |->
      model.dut.sum_i_pair0_s8 == $signed(model.expected_i[9]) &&
      model.dut.sum_i_pair1_s8 == 64'sd0);
  a_stage9_q_pair_identity: assert property (disable iff (!rst_n)
    model.expected_valid[9] |->
      model.dut.sum_q_pair0_s8 == $signed(model.expected_q[9]) &&
      model.dut.sum_q_pair1_s8 == 64'sd0);

  a_stage10_i_sum_and_output_identity: assert property (disable iff (!rst_n)
    model.expected_valid[10] |->
      model.dut.sum_i_s9 == $signed(model.expected_i[10]) &&
      !model.dut.sat_i && model.i_out == model.expected_i[10]);
  a_stage10_q_sum_and_output_identity: assert property (disable iff (!rst_n)
    model.expected_valid[10] |->
      model.dut.sum_q_s9 == $signed(model.expected_q[10]) &&
      !model.dut.sat_q && model.q_out == model.expected_q[10]);
endmodule
