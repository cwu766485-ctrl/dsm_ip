`timescale 1ns/1ps
`default_nettype none

// Product-bound structural invariant for the MAX_TAPS=1 vector DPD.
// All sixteen lanes use the same production dpd_memory_poly parameterization.
module thermo5_dpd_pair1_harness (
  input logic clk,
  input logic rst_n,
  input logic in_valid,
  input logic out_ready,
  input logic [2:0] active_taps,
  input logic signed [15:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  input logic signed [255:0] in_i_vec, in_q_vec
);
  logic in_ready, out_valid;
  logic [1:0] out_meta;
  logic signed [255:0] out_i_vec, out_q_vec;

  dpd_vector16_memory_poly #(
    .W(16), .LANES(16), .COEFF_W(16), .COEFF_FRAC(14), .MAX_TAPS(1)
  ) dut (
    .clk, .rst_n, .active_taps,
    .c1_re, .c1_im, .c3_re, .c3_im, .c5_re, .c5_im,
    .in_valid, .in_ready, .in_meta(2'b00), .in_i_vec, .in_q_vec,
    .out_valid, .out_ready, .out_meta, .out_i_vec, .out_q_vec
  );

  default clocking cb @(posedge clk); endclocking

  for (genvar lane = 0; lane < 16; lane++) begin : g_pair1_invariant
    a_pair1_i_comb_zero: assert property (disable iff (!rst_n)
      dut.g_lane[lane].u_dpd.sum_i_pair1_comb == '0);
    a_pair1_q_comb_zero: assert property (disable iff (!rst_n)
      dut.g_lane[lane].u_dpd.sum_q_pair1_comb == '0);
    a_pair1_i_reg_zero: assert property (disable iff (!rst_n)
      dut.g_lane[lane].u_dpd.sum_i_pair1_s8 == '0);
    a_pair1_q_reg_zero: assert property (disable iff (!rst_n)
      dut.g_lane[lane].u_dpd.sum_q_pair1_s8 == '0);
  end

  c_product_input_accept: cover property (disable iff (!rst_n)
    in_valid && in_ready);
  c_product_output_transfer: cover property (disable iff (!rst_n)
    out_valid && out_ready);
endmodule

`default_nettype wire
