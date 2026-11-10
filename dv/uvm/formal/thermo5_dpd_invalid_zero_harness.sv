`timescale 1ns/1ps
// Frozen one-tap leaf with arbitrary coefficients, samples, valid and stalls.
// No identity arithmetic assumption is used for an invalid transaction.
module thermo5_dpd_invalid_zero_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in,q_in,c1_re,c1_im,c3_re,c3_im,c5_re,c5_im
);
  wire in_ready,out_valid;
  wire signed [15:0] i_out,q_out;
  wire [31:0] sample_count,saturation_count;
  dpd_memory_poly #(.MAX_TAPS(1),.USE_EXTERNAL_TAPS(1)) dut(
    .clk(clk),.rst_n(rst_n),.active_taps(3'd1),
    .c1_re(c1_re),.c1_im(c1_im),.c3_re(c3_re),.c3_im(c3_im),
    .c5_re(c5_re),.c5_im(c5_im),.i_in(i_in),.q_in(q_in),
    .i_tap_vec(i_in),.q_tap_vec(q_in),.in_valid(in_valid),.in_ready(in_ready),
    .out_valid(out_valid),.out_ready(out_ready),.i_out(i_out),.q_out(q_out),
    .sample_count(sample_count),.saturation_count(saturation_count));
  default clocking cb @(posedge clk); endclocking
  a_enable0: assert property (disable iff(!rst_n)
    dut.tap_enable_s0[0] == dut.valid_pipe[0]);
  a_enable1: assert property (disable iff(!rst_n)
    dut.tap_enable_s1[0] == dut.valid_pipe[1]);
  a_enable2: assert property (disable iff(!rst_n)
    dut.tap_enable_s2[0] == dut.valid_pipe[2]);
  a_enable3: assert property (disable iff(!rst_n)
    dut.tap_enable_s3[0] == dut.valid_pipe[3]);
  a_enable4: assert property (disable iff(!rst_n)
    dut.tap_enable_s4[0] == dut.valid_pipe[4]);
  a_enable5: assert property (disable iff(!rst_n)
    dut.tap_enable_s5[0] == dut.valid_pipe[5]);
  a_enable6: assert property (disable iff(!rst_n)
    dut.tap_enable_s6[0] == dut.valid_pipe[6]);
  a_enable7: assert property (disable iff(!rst_n)
    dut.tap_enable_s7[0] == dut.valid_pipe[7]);
  a_invalid_term_zero: assert property (disable iff(!rst_n)
    !dut.valid_pipe[8] |-> dut.term_i_s8[0]==0 && dut.term_q_s8[0]==0);
  a_invalid_pair_zero: assert property (disable iff(!rst_n)
    !dut.valid_pipe[9] |-> dut.sum_i_pair0_s8==0 && dut.sum_q_pair0_s8==0);
  a_invalid_sum_zero: assert property (disable iff(!rst_n)
    !out_valid |-> dut.sum_i_s9==0 && dut.sum_q_s9==0);
  a_invalid_no_saturation: assert property (disable iff(!rst_n)
    !out_valid |-> !dut.sat_i && !dut.sat_q);
  c_invalid_saturation: cover property (disable iff(!rst_n)
    !out_valid && (dut.sat_i || dut.sat_q));
  c_output: cover property (disable iff(!rst_n) out_valid);
  c_bubble_after_output: cover property (disable iff(!rst_n)
    out_valid ##1 !out_valid);
endmodule
