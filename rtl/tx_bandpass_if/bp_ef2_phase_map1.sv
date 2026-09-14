// Exact one-sample piecewise-affine BP-EFDSM2 phase map.
// state_out = -state_in + x - q, with q selected by x - state_in >= 0.
// The two ordered regions cover the complete reset-reachable error domain.
`timescale 1ns/1ps
`default_nettype none

(* keep_hierarchy = "yes" *)
module bp_ef2_phase_map1 #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28
) (
  input  wire logic signed [W_IN-1:0] x_in,
  output logic [1:0] region_valid,
  output logic [1:0] region_slope_neg,
  output logic signed [2*ACC_W-1:0] region_lo_bus,
  output logic signed [2*ACC_W-1:0] region_hi_bus,
  output logic signed [2*ACC_W-1:0] region_offset_bus,
  output logic [1:0] region_bits_bus
);
  localparam logic signed [ACC_W-1:0] DOMAIN_MIN = -32769;
  localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;
  localparam logic signed [ACC_W-1:0] ONE = {{(ACC_W-1){1'b0}}, 1'b1};
  localparam logic signed [W_IN-1:0] Y_POS = {1'b0, {(W_IN-1){1'b1}}};
  localparam logic signed [W_IN-1:0] Y_NEG = -Y_POS;
  logic signed [ACC_W-1:0] x_c;

  always_comb begin
    x_c = {{(ACC_W-W_IN){x_in[W_IN-1]}}, x_in};
    // bit=1: x-state >= 0, equivalently state <= x.
    region_valid = 2'b11;
    region_slope_neg = 2'b11;
    region_lo_bus[0*ACC_W +: ACC_W] = DOMAIN_MIN;
    region_hi_bus[0*ACC_W +: ACC_W] = x_c;
    region_offset_bus[0*ACC_W +: ACC_W] = x_c - Y_POS;
    region_bits_bus[0] = 1'b1;
    // bit=0: x-state < 0, equivalently state >= x+1.
    region_lo_bus[1*ACC_W +: ACC_W] = $signed(x_c) + ONE;
    region_hi_bus[1*ACC_W +: ACC_W] = DOMAIN_MAX;
    region_offset_bus[1*ACC_W +: ACC_W] = x_c - Y_NEG;
    region_bits_bus[1] = 1'b0;
  end
endmodule

`default_nettype wire
