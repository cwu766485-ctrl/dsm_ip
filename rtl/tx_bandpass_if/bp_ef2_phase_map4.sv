// Exact four-sample phase map built from one-sample maps and composition.
//
// This replaces the former 16-history enumeration and runtime sorting network.
// The exact region bounds are 2 for map1, 3 for map2, and 5 for map4, so the
// hierarchy produces the same ordered intervals and affine transfers with a
// much smaller, statically structured synthesis problem.
`timescale 1ns/1ps
`default_nettype none

(* keep_hierarchy = "yes" *)
module bp_ef2_phase_map4 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter int OUT_BITS = 4,
  parameter int REGIONS = 5
) (
  input  wire logic signed [4*W_IN-1:0] x_vec,
  output logic [REGIONS-1:0] region_valid,
  output logic [REGIONS-1:0] region_slope_neg,
  output logic signed [REGIONS*ACC_W-1:0] region_lo_bus,
  output logic signed [REGIONS*ACC_W-1:0] region_hi_bus,
  output logic signed [REGIONS*ACC_W-1:0] region_offset_bus,
  output logic [REGIONS*OUT_BITS-1:0] region_bits_bus
);
  logic [1:0] m0_v, m0_s, m1_v, m1_s, m2_v, m2_s, m3_v, m3_s;
  logic signed [2*ACC_W-1:0] m0_lo, m0_hi, m0_of, m1_lo, m1_hi, m1_of;
  logic signed [2*ACC_W-1:0] m2_lo, m2_hi, m2_of, m3_lo, m3_hi, m3_of;
  logic [1:0] m0_b, m1_b, m2_b, m3_b;
  logic [2:0] a_v, a_s, b_v, b_s;
  logic signed [3*ACC_W-1:0] a_lo, a_hi, a_of, b_lo, b_hi, b_of;
  logic [5:0] a_b, b_b;

  bp_ef2_phase_map1 #(.W_IN(W_IN), .ACC_W(ACC_W)) u_m0 (
    .x_in(x_vec[0*W_IN +: W_IN]), .region_valid(m0_v), .region_slope_neg(m0_s),
    .region_lo_bus(m0_lo), .region_hi_bus(m0_hi), .region_offset_bus(m0_of), .region_bits_bus(m0_b));
  bp_ef2_phase_map1 #(.W_IN(W_IN), .ACC_W(ACC_W)) u_m1 (
    .x_in(x_vec[1*W_IN +: W_IN]), .region_valid(m1_v), .region_slope_neg(m1_s),
    .region_lo_bus(m1_lo), .region_hi_bus(m1_hi), .region_offset_bus(m1_of), .region_bits_bus(m1_b));
  bp_ef2_phase_map1 #(.W_IN(W_IN), .ACC_W(ACC_W)) u_m2 (
    .x_in(x_vec[2*W_IN +: W_IN]), .region_valid(m2_v), .region_slope_neg(m2_s),
    .region_lo_bus(m2_lo), .region_hi_bus(m2_hi), .region_offset_bus(m2_of), .region_bits_bus(m2_b));
  bp_ef2_phase_map1 #(.W_IN(W_IN), .ACC_W(ACC_W)) u_m3 (
    .x_in(x_vec[3*W_IN +: W_IN]), .region_valid(m3_v), .region_slope_neg(m3_s),
    .region_lo_bus(m3_lo), .region_hi_bus(m3_hi), .region_offset_bus(m3_of), .region_bits_bus(m3_b));

  bp_ef2_map_compose #(.ACC_W(ACC_W), .L_REGIONS(2), .R_REGIONS(2), .OUT_REGIONS(3), .L_BITS(1), .R_BITS(1)) u_a (
    .l_valid(m0_v), .l_slope_neg(m0_s), .l_lo_bus(m0_lo), .l_hi_bus(m0_hi), .l_offset_bus(m0_of), .l_bits_bus(m0_b),
    .r_valid(m1_v), .r_slope_neg(m1_s), .r_lo_bus(m1_lo), .r_hi_bus(m1_hi), .r_offset_bus(m1_of), .r_bits_bus(m1_b),
    .out_valid(a_v), .out_slope_neg(a_s), .out_lo_bus(a_lo), .out_hi_bus(a_hi), .out_offset_bus(a_of), .out_bits_bus(a_b));
  bp_ef2_map_compose #(.ACC_W(ACC_W), .L_REGIONS(2), .R_REGIONS(2), .OUT_REGIONS(3), .L_BITS(1), .R_BITS(1)) u_b (
    .l_valid(m2_v), .l_slope_neg(m2_s), .l_lo_bus(m2_lo), .l_hi_bus(m2_hi), .l_offset_bus(m2_of), .l_bits_bus(m2_b),
    .r_valid(m3_v), .r_slope_neg(m3_s), .r_lo_bus(m3_lo), .r_hi_bus(m3_hi), .r_offset_bus(m3_of), .r_bits_bus(m3_b),
    .out_valid(b_v), .out_slope_neg(b_s), .out_lo_bus(b_lo), .out_hi_bus(b_hi), .out_offset_bus(b_of), .out_bits_bus(b_b));
  bp_ef2_map_compose #(.ACC_W(ACC_W), .L_REGIONS(3), .R_REGIONS(3), .OUT_REGIONS(REGIONS), .L_BITS(2), .R_BITS(2)) u_final (
    .l_valid(a_v), .l_slope_neg(a_s), .l_lo_bus(a_lo), .l_hi_bus(a_hi), .l_offset_bus(a_of), .l_bits_bus(a_b),
    .r_valid(b_v), .r_slope_neg(b_s), .r_lo_bus(b_lo), .r_hi_bus(b_hi), .r_offset_bus(b_of), .r_bits_bus(b_b),
    .out_valid(region_valid), .out_slope_neg(region_slope_neg), .out_lo_bus(region_lo_bus), .out_hi_bus(region_hi_bus),
    .out_offset_bus(region_offset_bus), .out_bits_bus(region_bits_bus));
endmodule

`default_nettype wire
