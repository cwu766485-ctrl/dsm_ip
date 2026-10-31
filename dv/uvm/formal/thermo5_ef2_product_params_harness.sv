`timescale 1ns/1ps
// Exact product parameter reachability for the production 32-sample EF2.
// The GT parent omits PAIR_LOOKAHEAD, so the RTL module default (0) is used.
module thermo5_ef2_product_params_harness(
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

  a_product_pair_lookahead_disabled: assert property (disable iff (!rst_n)
    !dut.PAIR_LOOKAHEAD);
  a_product_parameter_guard_inactive: assert property (disable iff (!rst_n)
    (dut.W >= 2) && (dut.CHANNELS >= 2) && ((dut.CHANNELS % 2) == 0));

  c_pair_lookahead_arm_enabled: cover property (disable iff (!rst_n)
    dut.PAIR_LOOKAHEAD);
  c_invalid_parameter_guard: cover property (disable iff (!rst_n)
    (dut.W < 2) || (dut.CHANNELS < 2) || ((dut.CHANNELS % 2) != 0));
endmodule
