// Balanced fixed-size selector for an ordered map region containing state_in.
// The output priority is lowest index; valid map regions are disjoint, so this
// priority is defensive only.  Comparisons occur in parallel and the metadata
// travels through a three-level 8-leaf mux tree rather than a procedural
// linear scan.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_region_select #(
  parameter int ACC_W = 28,
  parameter int REGIONS = 5,
  parameter int BITS_W = 4
) (
  input  wire logic signed [ACC_W-1:0] state_in,
  input  wire logic [REGIONS-1:0] region_valid,
  input  wire logic [REGIONS-1:0] region_slope_neg,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_lo_bus,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_hi_bus,
  input  wire logic signed [REGIONS*ACC_W-1:0] region_offset_bus,
  input  wire logic [REGIONS*BITS_W-1:0] region_bits_bus,
  output logic found,
  output logic slope_neg_out,
  output logic signed [ACC_W-1:0] lo_out,
  output logic signed [ACC_W-1:0] hi_out,
  output logic signed [ACC_W-1:0] offset_out,
  output logic [BITS_W-1:0] bits_out
);
  localparam int LEAVES = (REGIONS <= 8) ? 8 : ((REGIONS <= 16) ? 16 : 32);
  localparam int LEVELS = (LEAVES == 8) ? 3 : ((LEAVES == 16) ? 4 : 5);
  logic [REGIONS-1:0] match;
  logic found_tree [0:LEVELS][0:LEAVES-1];
  logic slope_tree [0:LEVELS][0:LEAVES-1];
  logic signed [ACC_W-1:0] lo_tree [0:LEVELS][0:LEAVES-1];
  logic signed [ACC_W-1:0] hi_tree [0:LEVELS][0:LEAVES-1];
  logic signed [ACC_W-1:0] offset_tree [0:LEVELS][0:LEAVES-1];
  logic [BITS_W-1:0] bits_tree [0:LEVELS][0:LEAVES-1];
  integer i;

  always_comb begin
    for (i = 0; i < REGIONS; i = i + 1) begin
      match[i] = region_valid[i] && ($signed(state_in) >=
        $signed(region_lo_bus[i*ACC_W +: ACC_W])) && ($signed(state_in) <=
        $signed(region_hi_bus[i*ACC_W +: ACC_W]));
      found_tree[0][i] = match[i];
      slope_tree[0][i] = region_slope_neg[i];
      lo_tree[0][i] = region_lo_bus[i*ACC_W +: ACC_W];
      hi_tree[0][i] = region_hi_bus[i*ACC_W +: ACC_W];
      offset_tree[0][i] = region_offset_bus[i*ACC_W +: ACC_W];
      bits_tree[0][i] = region_bits_bus[i*BITS_W +: BITS_W];
    end
    for (i = REGIONS; i < LEAVES; i = i + 1) begin
      found_tree[0][i] = 1'b0; slope_tree[0][i] = 1'b0; lo_tree[0][i] = '0;
      hi_tree[0][i] = '0; offset_tree[0][i] = '0; bits_tree[0][i] = '0;
    end
  end

  genvar level;
  genvar node;
  generate
    for (level = 0; level < LEVELS; level = level + 1) begin : gen_level
      for (node = 0; node < (LEAVES >> (level + 1)); node = node + 1) begin : gen_node
        assign found_tree[level+1][node] = found_tree[level][2*node] |
                                            found_tree[level][2*node+1];
        assign slope_tree[level+1][node] = found_tree[level][2*node] ?
                                            slope_tree[level][2*node] : slope_tree[level][2*node+1];
        assign lo_tree[level+1][node] = found_tree[level][2*node] ?
                                          lo_tree[level][2*node] : lo_tree[level][2*node+1];
        assign hi_tree[level+1][node] = found_tree[level][2*node] ?
                                          hi_tree[level][2*node] : hi_tree[level][2*node+1];
        assign offset_tree[level+1][node] = found_tree[level][2*node] ?
                                              offset_tree[level][2*node] : offset_tree[level][2*node+1];
        assign bits_tree[level+1][node] = found_tree[level][2*node] ?
                                            bits_tree[level][2*node] : bits_tree[level][2*node+1];
      end
    end
  endgenerate

  assign found = found_tree[LEVELS][0];
  assign slope_neg_out = slope_tree[LEVELS][0];
  assign lo_out = lo_tree[LEVELS][0];
  assign hi_out = hi_tree[LEVELS][0];
  assign offset_out = offset_tree[LEVELS][0];
  assign bits_out = bits_tree[LEVELS][0];
endmodule

`default_nettype wire
