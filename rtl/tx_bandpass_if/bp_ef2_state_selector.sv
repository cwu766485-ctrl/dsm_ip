// Balanced exact selector for a fixed-size piecewise-affine state map.
//
// Each valid map region covers an inclusive, disjoint interval.  All regions
// compare with state_in in parallel; a 64-leaf balanced reduction tree selects
// the lowest matching region.  The priority is only defensive because valid
// map regions are required to be disjoint.  Keeping selection in this module
// prevents a linear region scan from becoming part of the transaction-state
// feedback path.
`timescale 1ns/1ps
`default_nettype none

(* keep_hierarchy = "yes" *)
module bp_ef2_state_selector #(
  parameter int ACC_W = 28,
  parameter int REGIONS = 34,
  parameter int OUT_BITS = 32
) (
  input  wire logic signed [ACC_W-1:0] state_in,
  input  wire logic [REGIONS-1:0] region_valid,
  input  wire logic [REGIONS-1:0] region_slope_neg,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_lo_bus,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_hi_bus,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_offset_bus,
  input  wire logic [REGIONS*OUT_BITS-1:0] region_bits_bus,
  output logic found,
  output logic region_slope_neg_out,
  output logic signed [ACC_W-1:0] region_offset_out,
  output logic [OUT_BITS-1:0] region_bits_out
);
  localparam int TREE_LEAVES = 64;
  localparam int TREE_LEVELS = 6;

  logic [REGIONS-1:0] region_match;
  logic [TREE_LEAVES-1:0] tree_found [0:TREE_LEVELS];
  logic [5:0] tree_index [0:TREE_LEVELS][0:TREE_LEAVES-1];
  integer r;

  always_comb begin
    for (r = 0; r < REGIONS; r = r + 1) begin
      region_match[r] = region_valid[r] &&
                        ($signed(state_in) >=
                         $signed(region_lo_bus[r*ACC_W +: ACC_W])) &&
                        ($signed(state_in) <=
                         $signed(region_hi_bus[r*ACC_W +: ACC_W]));
    end
  end

  genvar leaf;
  generate
    for (leaf = 0; leaf < TREE_LEAVES; leaf = leaf + 1) begin : gen_tree_leaf
      if (leaf < REGIONS) begin : gen_active_leaf
        assign tree_found[0][leaf] = region_match[leaf];
      end else begin : gen_pad_leaf
        assign tree_found[0][leaf] = 1'b0;
      end
      assign tree_index[0][leaf] = leaf[5:0];
    end
  endgenerate

  genvar level;
  genvar node;
  generate
    for (level = 0; level < TREE_LEVELS; level = level + 1) begin : gen_tree_level
      for (node = 0; node < (TREE_LEAVES >> (level + 1)); node = node + 1) begin : gen_tree_node
        assign tree_found[level+1][node] = tree_found[level][2*node] |
                                              tree_found[level][2*node+1];
        assign tree_index[level+1][node] = tree_found[level][2*node] ?
                                               tree_index[level][2*node] :
                                               tree_index[level][2*node+1];
      end
    end
  endgenerate

  // Unpacked arrays give the final mux constant-width inputs; this avoids a
  // variable packed part-select on the selector's feedback path.
  logic region_slope [0:REGIONS-1];
  logic signed [ACC_W-1:0] region_offset [0:REGIONS-1];
  logic [OUT_BITS-1:0] region_bits [0:REGIONS-1];
  genvar unpack;
  generate
    for (unpack = 0; unpack < REGIONS; unpack = unpack + 1) begin : gen_unpack
      assign region_slope[unpack] = region_slope_neg[unpack];
      assign region_offset[unpack] = region_offset_bus[unpack*ACC_W +: ACC_W];
      assign region_bits[unpack] = region_bits_bus[unpack*OUT_BITS +: OUT_BITS];
    end
  endgenerate

  always_comb begin
    found = tree_found[TREE_LEVELS][0];
    region_slope_neg_out = 1'b0;
    region_offset_out = '0;
    region_bits_out = '0;
    if (tree_found[TREE_LEVELS][0] && (tree_index[TREE_LEVELS][0] < REGIONS)) begin
      region_slope_neg_out = region_slope[tree_index[TREE_LEVELS][0]];
      region_offset_out = region_offset[tree_index[TREE_LEVELS][0]];
      region_bits_out = region_bits[tree_index[TREE_LEVELS][0]];
    end
  end
endmodule

`default_nettype wire
