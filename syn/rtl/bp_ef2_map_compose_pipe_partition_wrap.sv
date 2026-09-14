// Wrapper used only to create a hierarchical, cell-importable DCP for one
// production bp_ef2_map_compose_pipe specialization.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_compose_pipe_partition_wrap #(
  parameter int ACC_W = 28, parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5, parameter int OUT_REGIONS = 9,
  parameter int L_BITS = 4, parameter int R_BITS = 4
) (
  input wire logic clk, rst_n, in_valid,
  input wire logic [L_REGIONS-1:0] l_valid, l_slope_neg,
  input wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input wire logic [R_REGIONS-1:0] r_valid, r_slope_neg,
  input wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  output wire logic out_valid,
  output wire logic [OUT_REGIONS-1:0] out_map_valid, out_slope_neg,
  output wire logic signed [OUT_REGIONS*ACC_W-1:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output wire logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] out_bits_bus
);
  bp_ef2_map_compose_pipe #(
    .ACC_W(ACC_W), .L_REGIONS(L_REGIONS), .R_REGIONS(R_REGIONS),
    .OUT_REGIONS(OUT_REGIONS), .L_BITS(L_BITS), .R_BITS(R_BITS)
  ) u_compose (.*);
endmodule

`default_nettype wire
