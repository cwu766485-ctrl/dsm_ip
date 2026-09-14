// One fixed output-region advance of ordered piecewise-affine map composition.
// This is the timing-bounded primitive for bp_ef2_map_compose_pipe: a complete
// compose operation is a chain of registered advances, not one long cursor
// dependency in a single fabric cycle.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_compose_step #(
  parameter int ACC_W = 28,
  parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5,
  parameter int L_BITS = 4,
  parameter int R_BITS = 4
) (
  input  wire logic signed [ACC_W-1:0] cursor_in,
  input  wire logic [L_REGIONS-1:0] l_valid,
  input  wire logic [L_REGIONS-1:0] l_slope_neg,
  input  wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus,
  input  wire logic signed [L_REGIONS*ACC_W-1:0] l_hi_bus,
  input  wire logic signed [L_REGIONS*ACC_W-1:0] l_offset_bus,
  input  wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input  wire logic [R_REGIONS-1:0] r_valid,
  input  wire logic [R_REGIONS-1:0] r_slope_neg,
  input  wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus,
  input  wire logic signed [R_REGIONS*ACC_W-1:0] r_hi_bus,
  input  wire logic signed [R_REGIONS*ACC_W-1:0] r_offset_bus,
  input  wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  output logic valid_out,
  output logic slope_neg_out,
  output logic signed [ACC_W-1:0] lo_out,
  output logic signed [ACC_W-1:0] hi_out,
  output logic signed [ACC_W-1:0] offset_out,
  output logic [L_BITS+R_BITS-1:0] bits_out,
  output logic signed [ACC_W-1:0] cursor_next
);
  localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;
  localparam int CALC_W = ACC_W + 2;
  localparam logic signed [CALC_W-1:0] ONE_C = {{(CALC_W-1){1'b0}}, 1'b1};
  logic l_found, r_found, l_slope_value, r_slope_value;
  logic signed [ACC_W-1:0] l_lo_value, l_hi_value, l_offset_value;
  logic signed [ACC_W-1:0] r_lo_value, r_hi_value, r_offset_value;
  logic [L_BITS-1:0] l_bits_value;
  logic [R_BITS-1:0] r_bits_value;
  logic signed [CALC_W-1:0] state_left, preimage_hi, interval_hi, offset_value;
  bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(L_REGIONS), .BITS_W(L_BITS)) u_left (
    .state_in(cursor_in), .region_valid(l_valid), .region_slope_neg(l_slope_neg),
    .region_lo_bus(l_lo_bus), .region_hi_bus(l_hi_bus), .region_offset_bus(l_offset_bus),
    .region_bits_bus(l_bits_bus), .found(l_found), .slope_neg_out(l_slope_value),
    .lo_out(l_lo_value), .hi_out(l_hi_value), .offset_out(l_offset_value), .bits_out(l_bits_value)
  );
  always_comb begin
    state_left = l_slope_value ? (-$signed(cursor_in) + $signed(l_offset_value)) :
                                 ( $signed(cursor_in) + $signed(l_offset_value));
  end
  bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(R_REGIONS), .BITS_W(R_BITS)) u_right (
    .state_in(state_left[ACC_W-1:0]), .region_valid(r_valid), .region_slope_neg(r_slope_neg),
    .region_lo_bus(r_lo_bus), .region_hi_bus(r_hi_bus), .region_offset_bus(r_offset_bus),
    .region_bits_bus(r_bits_bus), .found(r_found), .slope_neg_out(r_slope_value),
    .lo_out(r_lo_value), .hi_out(r_hi_value), .offset_out(r_offset_value), .bits_out(r_bits_value)
  );

  always_comb begin
    preimage_hi = l_slope_value ? ($signed(l_offset_value) - $signed(r_lo_value)) :
                                  ($signed(r_hi_value) - $signed(l_offset_value));
    interval_hi = ($signed(l_hi_value) < $signed(preimage_hi)) ? l_hi_value : preimage_hi;
    offset_value = r_slope_value ? (-$signed(l_offset_value) + $signed(r_offset_value)) :
                                   ( $signed(l_offset_value) + $signed(r_offset_value));
    valid_out = l_found && r_found && ($signed(cursor_in) <= $signed(DOMAIN_MAX)) &&
                ($signed(interval_hi) >= $signed(cursor_in));
    slope_neg_out = l_slope_value ^ r_slope_value;
    lo_out = cursor_in;
    hi_out = interval_hi[ACC_W-1:0];
    offset_out = offset_value[ACC_W-1:0];
    bits_out = {r_bits_value, l_bits_value};
    cursor_next = valid_out ? (interval_hi + ONE_C) : (DOMAIN_MAX + 1'b1);
  end
endmodule

`default_nettype wire
