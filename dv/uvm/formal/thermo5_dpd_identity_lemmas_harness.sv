`timescale 1ns/1ps
// Intermediate datapath range lemmas for the identity DPD proof.
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
endmodule
