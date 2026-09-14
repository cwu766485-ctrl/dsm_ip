// Ordered composition of two piecewise-affine state maps.
//
// Each map is an ordered, gap-free partition of the legal state domain; unused
// entries follow the valid prefix.  The former implementation enumerated every
// LxR pair and dynamically compacted valid intersections through a variable
// wide-bus write.  That form is mathematically correct but creates a very
// large mux/compaction network in FPGA synthesis.
//
// This implementation walks the input state domain from low to high.  Output
// slot k has a fixed destination: it selects the left/right regions containing
// the current lower state boundary and emits their exact common interval.  A
// completed interval advances the boundary for slot k+1.  The number of slots
// is statically bounded by L_REGIONS + R_REGIONS - 1 for complete partitions.
`timescale 1ns/1ps
`default_nettype none

(* keep_hierarchy = "yes" *)
module bp_ef2_map_compose #(
  parameter int ACC_W = 28,
  parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5,
  parameter int OUT_REGIONS = 9,
  parameter int L_BITS = 4,
  parameter int R_BITS = 4
) (
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
  output logic [OUT_REGIONS-1:0] out_valid,
  output logic [OUT_REGIONS-1:0] out_slope_neg,
  output logic signed [OUT_REGIONS*ACC_W-1:0] out_lo_bus,
  output logic signed [OUT_REGIONS*ACC_W-1:0] out_hi_bus,
  output logic signed [OUT_REGIONS*ACC_W-1:0] out_offset_bus,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] out_bits_bus
);
  localparam logic signed [ACC_W-1:0] DOMAIN_MIN = -32769;
  localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;
  localparam int CALC_W = ACC_W + 2;
  localparam logic signed [CALC_W-1:0] DOMAIN_MIN_C =
    {{(CALC_W-ACC_W){DOMAIN_MIN[ACC_W-1]}}, DOMAIN_MIN};
  localparam logic signed [CALC_W-1:0] DOMAIN_MAX_C =
    {{(CALC_W-ACC_W){DOMAIN_MAX[ACC_W-1]}}, DOMAIN_MAX};
  localparam logic signed [CALC_W-1:0] ONE_C = {{(CALC_W-1){1'b0}}, 1'b1};

  logic signed [ACC_W-1:0] l_lo [0:L_REGIONS-1];
  logic signed [ACC_W-1:0] l_hi [0:L_REGIONS-1];
  logic signed [ACC_W-1:0] l_offset [0:L_REGIONS-1];
  logic [L_BITS-1:0] l_bits [0:L_REGIONS-1];
  logic signed [ACC_W-1:0] r_lo [0:R_REGIONS-1];
  logic signed [ACC_W-1:0] r_hi [0:R_REGIONS-1];
  logic signed [ACC_W-1:0] r_offset [0:R_REGIONS-1];
  logic [R_BITS-1:0] r_bits [0:R_REGIONS-1];
  logic signed [CALC_W-1:0] cursor [0:OUT_REGIONS];
  logic signed [CALC_W-1:0] state_left;
  logic signed [CALC_W-1:0] interval_hi;
  logic signed [CALC_W-1:0] r_preimage_hi;
  logic signed [CALC_W-1:0] offset_value;
  logic l_found;
  logic r_found;
  logic l_slope_value;
  logic r_slope_value;
  logic signed [ACC_W-1:0] l_hi_value;
  logic signed [ACC_W-1:0] l_offset_value;
  logic signed [ACC_W-1:0] r_lo_value;
  logic signed [ACC_W-1:0] r_hi_value;
  logic signed [ACC_W-1:0] r_offset_value;
  logic [L_BITS-1:0] l_bits_value;
  logic [R_BITS-1:0] r_bits_value;
  integer i;
  integer j;
  integer k;

  always_comb begin
    for (i = 0; i < L_REGIONS; i = i + 1) begin
      l_lo[i] = l_lo_bus[i*ACC_W +: ACC_W];
      l_hi[i] = l_hi_bus[i*ACC_W +: ACC_W];
      l_offset[i] = l_offset_bus[i*ACC_W +: ACC_W];
      l_bits[i] = l_bits_bus[i*L_BITS +: L_BITS];
    end
    for (j = 0; j < R_REGIONS; j = j + 1) begin
      r_lo[j] = r_lo_bus[j*ACC_W +: ACC_W];
      r_hi[j] = r_hi_bus[j*ACC_W +: ACC_W];
      r_offset[j] = r_offset_bus[j*ACC_W +: ACC_W];
      r_bits[j] = r_bits_bus[j*R_BITS +: R_BITS];
    end

    out_valid = '0;
    out_slope_neg = '0;
    out_lo_bus = '0;
    out_hi_bus = '0;
    out_offset_bus = '0;
    out_bits_bus = '0;
    cursor[0] = DOMAIN_MIN_C;

    for (k = 0; k < OUT_REGIONS; k = k + 1) begin
      l_found = 1'b0;
      r_found = 1'b0;
      l_slope_value = 1'b0;
      r_slope_value = 1'b0;
      l_hi_value = '0;
      l_offset_value = '0;
      r_lo_value = '0;
      r_hi_value = '0;
      r_offset_value = '0;
      l_bits_value = '0;
      r_bits_value = '0;

      for (i = 0; i < L_REGIONS; i = i + 1) begin
        if (!l_found && l_valid[i] &&
            ($signed(cursor[k]) >= $signed(l_lo[i])) &&
            ($signed(cursor[k]) <= $signed(l_hi[i]))) begin
          l_found = 1'b1;
          l_slope_value = l_slope_neg[i];
          l_hi_value = l_hi[i];
          l_offset_value = l_offset[i];
          l_bits_value = l_bits[i];
        end
      end

      state_left = l_slope_value ?
        (-$signed(cursor[k]) + $signed(l_offset_value)) :
        ( $signed(cursor[k]) + $signed(l_offset_value));
      for (j = 0; j < R_REGIONS; j = j + 1) begin
        if (!r_found && r_valid[j] &&
            ($signed(state_left) >= $signed(r_lo[j])) &&
            ($signed(state_left) <= $signed(r_hi[j]))) begin
          r_found = 1'b1;
          r_slope_value = r_slope_neg[j];
          r_lo_value = r_lo[j];
          r_hi_value = r_hi[j];
          r_offset_value = r_offset[j];
          r_bits_value = r_bits[j];
        end
      end

      // As input state increases, a positive left slope exits r at r_hi;
      // a negative left slope exits r at r_lo.
      r_preimage_hi = l_slope_value ?
        ($signed(l_offset_value) - $signed(r_lo_value)) :
        ($signed(r_hi_value) - $signed(l_offset_value));
      interval_hi = ($signed(l_hi_value) < $signed(r_preimage_hi)) ?
                    $signed(l_hi_value) : $signed(r_preimage_hi);
      offset_value = r_slope_value ?
        (-$signed(l_offset_value) + $signed(r_offset_value)) :
        ( $signed(l_offset_value) + $signed(r_offset_value));

      if (($signed(cursor[k]) <= DOMAIN_MAX_C) && l_found && r_found &&
          ($signed(interval_hi) >= $signed(cursor[k]))) begin
        out_valid[k] = 1'b1;
        out_slope_neg[k] = l_slope_value ^ r_slope_value;
        out_lo_bus[k*ACC_W +: ACC_W] = cursor[k][ACC_W-1:0];
        out_hi_bus[k*ACC_W +: ACC_W] = interval_hi[ACC_W-1:0];
        out_offset_bus[k*ACC_W +: ACC_W] = offset_value[ACC_W-1:0];
        out_bits_bus[k*(L_BITS+R_BITS) +: (L_BITS+R_BITS)] =
          {r_bits_value, l_bits_value};
        cursor[k+1] = interval_hi + ONE_C;
      end else begin
        cursor[k+1] = DOMAIN_MAX_C + ONE_C;
      end
    end
  end
endmodule

`default_nettype wire
