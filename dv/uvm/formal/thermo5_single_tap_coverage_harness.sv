`timescale 1ns/1ps
module thermo5_single_tap_coverage_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic [2:0] taps,
  input logic signed [15:0] i, q, c1r, c1i, c3r, c3i, c5r, c5i
);
  wire ready, valid;
  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .out_ready(out_ready),
    .in_ready(ready), .out_valid(valid), .active_taps(taps),
    .i_in(i), .q_in(q), .i_tap_vec(i), .q_tap_vec(q),
    .c1_re(c1r), .c1_im(c1i), .c3_re(c3r), .c3_im(c3i), .c5_re(c5r), .c5_im(c5i),
    .i_out(), .q_out(), .sample_count(), .saturation_count()
  );
  default clocking cb @(posedge clk); endclocking
  a_second_pair_zero: assert property (disable iff (!rst_n)
    {dut.sum_i_pair1_comb,dut.sum_q_pair1_comb,dut.sum_i_pair1_s8,dut.sum_q_pair1_s8} == '0);
  // Expose the stage-by-stage zero invariant to the induction engines.
  a_invalid_stages_zero: assert property (disable iff (!rst_n)
    (dut.valid_pipe[0] || !dut.tap_enable_s0[0]) &&
    (dut.valid_pipe[1] || !dut.tap_enable_s1[0]) &&
    (dut.valid_pipe[2] || !dut.tap_enable_s2[0]) &&
    (dut.valid_pipe[3] || !dut.tap_enable_s3[0]) &&
    (dut.valid_pipe[4] || !dut.tap_enable_s4[0]) &&
    (dut.valid_pipe[5] || !dut.tap_enable_s5[0]) &&
    (dut.valid_pipe[6] || !dut.tap_enable_s6[0]) &&
    (dut.valid_pipe[7] || !dut.tap_enable_s7[0]) &&
    (dut.valid_pipe[8] || ({dut.term_i_s8[0],dut.term_q_s8[0]} == '0)) &&
    (dut.valid_pipe[9] || ({dut.sum_i_pair0_s8,dut.sum_q_pair0_s8,
                           dut.sum_i_pair1_s8,dut.sum_q_pair1_s8} == '0)) &&
    (dut.valid_pipe[10] || ({dut.sum_i_s9,dut.sum_q_s9} == '0)) &&
    (valid || (!dut.sat_i && !dut.sat_q)));
  a_invalid_output_no_saturation: assert property (disable iff (!rst_n)
    !valid |-> (!dut.sat_i && !dut.sat_q));
  c_valid: cover property (disable iff (!rst_n) valid);
  c_stalled: cover property (disable iff (!rst_n) valid && !out_ready);
  c_accept_bubble: cover property (disable iff (!rst_n) ready && !in_valid);
endmodule
