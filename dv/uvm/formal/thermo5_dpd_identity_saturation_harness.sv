`timescale 1ns/1ps

// Exact clamp-branch reachability check for the one-tap identity product image.
// The datapath is the production dpd_memory_poly module; all signed input
// samples, valid, and downstream ready are otherwise unconstrained.
module thermo5_identity_saturation_harness(
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic out_ready,
  input logic signed [15:0] i_in,
  input logic signed [15:0] q_in
);
  wire in_ready;
  wire signed [15:0] i_out, q_out;
  wire out_valid;
  wire [31:0] sample_count, saturation_count;

  dpd_memory_poly #(.MAX_TAPS(1), .USE_EXTERNAL_TAPS(1)) dut (
    .clk(clk), .rst_n(rst_n), .active_taps(3'd1),
    .c1_re(16'sd16384), .c1_im(16'sd0),
    .c3_re(16'sd0), .c3_im(16'sd0),
    .c5_re(16'sd0), .c5_im(16'sd0),
    .i_in(i_in), .q_in(q_in), .i_tap_vec(i_in), .q_tap_vec(q_in),
    .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid),
    .out_ready(out_ready), .sample_count(sample_count),
    .saturation_count(saturation_count)
  );

  default clocking cb @(posedge clk); endclocking

  a_identity_i_no_positive_saturation:
    assert property (disable iff (!rst_n) !(dut.u_sat_i.din > 64'sd32767));
  a_identity_i_no_negative_saturation:
    assert property (disable iff (!rst_n) !(dut.u_sat_i.din < -64'sd32768));
  a_identity_q_no_positive_saturation:
    assert property (disable iff (!rst_n) !(dut.u_sat_q.din > 64'sd32767));
  a_identity_q_no_negative_saturation:
    assert property (disable iff (!rst_n) !(dut.u_sat_q.din < -64'sd32768));

  c_accept_input: cover property (disable iff (!rst_n) in_valid && in_ready);
  c_produce_output: cover property (disable iff (!rst_n) out_valid);
  c_i_positive_clamp_bin:
    cover property (disable iff (!rst_n) dut.u_sat_i.din > 64'sd32767);
  c_i_negative_clamp_bin:
    cover property (disable iff (!rst_n) dut.u_sat_i.din < -64'sd32768);
  c_q_positive_clamp_bin:
    cover property (disable iff (!rst_n) dut.u_sat_q.din > 64'sd32767);
  c_q_negative_clamp_bin:
    cover property (disable iff (!rst_n) dut.u_sat_q.din < -64'sd32768);
endmodule
