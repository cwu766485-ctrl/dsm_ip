`timescale 1ns/1ps
`default_nettype none
module thermo5_dpd_identity_stall_harness(
  input logic clk, rst_n, in_valid, out_ready,
  input logic signed [15:0] i_in, q_in
);
  wire in_ready, out_valid;
  wire signed [15:0] i_out, q_out;
  wire [31:0] sample_count, saturation_count;
  logic signed [15:0] expected_i[0:10], expected_q[0:10];
  logic [10:0] expected_valid;
  wire advance = out_ready || !out_valid;
  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dut(
    .clk(clk), .rst_n(rst_n), .active_taps(3'd1),
    .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0),
    .i_in(i_in), .q_in(q_in), .i_tap_vec(i_in), .q_tap_vec(q_in),
    .in_valid(in_valid), .in_ready(in_ready), .i_out(i_out), .q_out(q_out),
    .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(sample_count), .saturation_count(saturation_count)
  );
  function automatic logic signed [63:0] q14(input logic signed [15:0] x);
    q14 = $signed({{48{x[15]}}, x}) <<< 14;
  endfunction
  function automatic logic signed [63:0] sx(input logic signed [15:0] x);
    sx = {{48{x[15]}}, x};
  endfunction
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      expected_valid <= '0;
      for (int p=0; p<11; p++) begin expected_i[p] <= '0; expected_q[p] <= '0; end
    end else if (advance) begin
      expected_valid <= {expected_valid[9:0], in_valid};
      expected_i[0] <= i_in; expected_q[0] <= q_in;
      for (int p=1; p<11; p++) begin expected_i[p] <= expected_i[p-1]; expected_q[p] <= expected_q[p-1]; end
    end
  end
  default clocking cb @(posedge clk); endclocking
  asm_payload_stable: assume property (disable iff(!rst_n)
    in_valid && !in_ready |=> in_valid && $stable({i_in,q_in}));
  a_v0: assert property (dut.tap_enable_s0[0] == expected_valid[0]);
  a_v1: assert property (dut.tap_enable_s1[0] == expected_valid[1]);
  a_v2: assert property (dut.tap_enable_s2[0] == expected_valid[2]);
  a_v3: assert property (dut.tap_enable_s3[0] == expected_valid[3]);
  a_v4: assert property (dut.tap_enable_s4[0] == expected_valid[4]);
  a_v5: assert property (dut.tap_enable_s5[0] == expected_valid[5]);
  a_v6: assert property (dut.tap_enable_s6[0] == expected_valid[6]);
  a_v7: assert property (dut.tap_enable_s7[0] == expected_valid[7]);
  a_i0: assert property (dut.tap_enable_s0[0] |-> dut.i_s0[0]==expected_i[0]);
  a_q0: assert property (dut.tap_enable_s0[0] |-> dut.q_s0[0]==expected_q[0]);
  a_i1: assert property (dut.tap_enable_s1[0] |-> dut.i_s1[0]==expected_i[1]);
  a_q1: assert property (dut.tap_enable_s1[0] |-> dut.q_s1[0]==expected_q[1]);
  a_i2: assert property (dut.tap_enable_s2[0] |-> dut.i_s2[0]==expected_i[2]);
  a_q2: assert property (dut.tap_enable_s2[0] |-> dut.q_s2[0]==expected_q[2]);
  a_i3: assert property (dut.tap_enable_s3[0] |-> dut.i_s3[0]==expected_i[3]);
  a_q3: assert property (dut.tap_enable_s3[0] |-> dut.q_s3[0]==expected_q[3]);
  a_i4: assert property (dut.tap_enable_s4[0] |-> dut.i_s4[0]==expected_i[4]);
  a_q4: assert property (dut.tap_enable_s4[0] |-> dut.q_s4[0]==expected_q[4]);
  a_i5: assert property (dut.tap_enable_s5[0] |-> dut.i_s5[0]==expected_i[5]);
  a_q5: assert property (dut.tap_enable_s5[0] |-> dut.q_s5[0]==expected_q[5]);
  a_i6: assert property (dut.tap_enable_s6[0] |-> dut.i_s6[0]==expected_i[6]);
  a_q6: assert property (dut.tap_enable_s6[0] |-> dut.q_s6[0]==expected_q[6]);
  a_coeff0: assert property (dut.tap_enable_s0[0] |->
    dut.c1_re_s0[0]==16'sd16384 && dut.c1_im_s0[0]==0 &&
    dut.c3_re_s0[0]==0 && dut.c3_im_s0[0]==0 &&
    dut.c5_re_s0[0]==0 && dut.c5_im_s0[0]==0);
  a_coeff1: assert property (dut.tap_enable_s1[0] |->
    dut.c1_re_s1[0]==16'sd16384 && dut.c1_im_s1[0]==0 &&
    dut.c3_re_s1[0]==0 && dut.c3_im_s1[0]==0 &&
    dut.c5_re_s1[0]==0 && dut.c5_im_s1[0]==0);
  a_coeff2: assert property (dut.tap_enable_s2[0] |->
    dut.c1_re_s2[0]==16'sd16384 && dut.c1_im_s2[0]==0 &&
    dut.c3_re_s2[0]==0 && dut.c3_im_s2[0]==0 &&
    dut.c5_re_s2[0]==0 && dut.c5_im_s2[0]==0);
  a_coeff3: assert property (dut.tap_enable_s3[0] |->
    dut.c1_re_s3[0]==16'sd16384 && dut.c1_im_s3[0]==0 &&
    dut.c3r_r2_s3[0]==0 && dut.c3i_r2_s3[0]==0 &&
    dut.c5_re_s3[0]==0 && dut.c5_im_s3[0]==0);
  a_coeff4: assert property (dut.tap_enable_s4[0] |->
    dut.c1_re_s4[0]==64'sd16384 && dut.c1_im_s4[0]==0 &&
    dut.c3r_r2_s4[0]==0 && dut.c3i_r2_s4[0]==0 &&
    dut.c5r_r4_s4[0]==0 && dut.c5i_r4_s4[0]==0);
  a_gain5: assert property (dut.tap_enable_s5[0] |->
    dut.gain_re_s5[0]==64'sd16384 && dut.gain_im_s5[0]==0);
  a_gain_c5_zero5: assert property (dut.tap_enable_s5[0] |->
    dut.gain_c5_re_s5[0]==0 && dut.gain_c5_im_s5[0]==0);
  a_gain6: assert property (dut.tap_enable_s6[0] |->
    dut.gain_re_s6[0]==64'sd16384 && dut.gain_im_s6[0]==0);
  a_prod_i7: assert property (dut.tap_enable_s7[0] |-> dut.i_gr_s7[0]==q14(expected_i[7]));
  a_prod_q7: assert property (dut.tap_enable_s7[0] |-> dut.q_gr_s7[0]==q14(expected_q[7]));
  a_cross_i7: assert property (dut.tap_enable_s7[0] |-> dut.q_gi_s7[0]==0);
  a_cross_q7: assert property (dut.tap_enable_s7[0] |-> dut.i_gi_s7[0]==0);
  a_term_i8: assert property (expected_valid[8] |-> dut.term_i_s8[0]==sx(expected_i[8]));
  a_term_q8: assert property (expected_valid[8] |-> dut.term_q_s8[0]==sx(expected_q[8]));
  a_valid_latency: assert property (out_valid == expected_valid[10]);
  a_pair_i9: assert property (expected_valid[9] |->
    dut.sum_i_pair0_s8==sx(expected_i[9]) && dut.sum_i_pair1_s8==0);
  a_pair_q9: assert property (expected_valid[9] |->
    dut.sum_q_pair0_s8==sx(expected_q[9]) && dut.sum_q_pair1_s8==0);
  a_sum_i10: assert property (expected_valid[10] |-> dut.sum_i_s9==sx(expected_i[10]));
  a_sum_q10: assert property (expected_valid[10] |-> dut.sum_q_s9==sx(expected_q[10]));
  a_output_i: assert property (disable iff(!rst_n) out_valid |-> i_out==expected_i[10]);
  a_output_q: assert property (disable iff(!rst_n) out_valid |-> q_out==expected_q[10]);
  a_no_saturation: assert property (disable iff(!rst_n)
    !out_valid || (!dut.sat_i && !dut.sat_q));
  a_saturation_count_zero: assert property (disable iff(!rst_n) saturation_count==0);
  c_max_endpoint: cover property (disable iff(!rst_n) out_valid && i_out==16'sh7fff);
  c_min_endpoint: cover property (disable iff(!rst_n) out_valid && i_out==16'sh8000);
  c_stall: cover property (disable iff(!rst_n) out_valid && !out_ready);
  c_recovery: cover property (disable iff(!rst_n) out_valid && !out_ready ##1 out_valid && out_ready);
endmodule
`default_nettype wire
