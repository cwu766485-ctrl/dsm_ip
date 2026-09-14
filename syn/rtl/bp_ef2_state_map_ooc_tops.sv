// Register-to-register OOC harnesses for the state-map pipeline stages.
// They retain the exact production combinational blocks but replace adjacent
// pipeline stages with registers, making each stage's timing independently
// measurable before attempting the full 64-sample top-level synthesis.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_state_map_leaf4_ooc (
  input wire logic clk,
  input wire logic signed [63:0] x_vec,
  output logic [4:0] region_valid,
  output logic [4:0] region_slope_neg,
  output logic signed [139:0] region_lo_bus,
  output logic signed [139:0] region_hi_bus,
  output logic signed [139:0] region_offset_bus,
  output logic [19:0] region_bits_bus
);
  logic signed [63:0] x_q;
  logic [4:0] valid_c, slope_c;
  logic signed [139:0] lo_c, hi_c, offset_c;
  logic [19:0] bits_c;
  always_ff @(posedge clk) x_q <= x_vec;
  bp_ef2_phase_map4 u_map (
    .x_vec(x_q), .region_valid(valid_c), .region_slope_neg(slope_c),
    .region_lo_bus(lo_c), .region_hi_bus(hi_c), .region_offset_bus(offset_c),
    .region_bits_bus(bits_c)
  );
  always_ff @(posedge clk) begin
    region_valid <= valid_c; region_slope_neg <= slope_c;
    region_lo_bus <= lo_c; region_hi_bus <= hi_c; region_offset_bus <= offset_c;
    region_bits_bus <= bits_c;
  end
endmodule

module bp_ef2_state_map_compose8_ooc (
  input wire logic clk,
  input wire logic [4:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [139:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [19:0] l_bits_bus,
  input wire logic signed [139:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [19:0] r_bits_bus,
  output logic [8:0] out_valid, out_slope_neg,
  output logic signed [251:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [71:0] out_bits_bus
);
  logic [8:0] valid_c, slope_c;
  logic signed [251:0] lo_c, hi_c, offset_c;
  logic [71:0] bits_c;
  bp_ef2_map_compose #(.L_REGIONS(5), .R_REGIONS(5), .OUT_REGIONS(9), .L_BITS(4), .R_BITS(4)) u_compose (
    .l_valid(l_valid), .l_slope_neg(l_slope_neg), .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus), .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus),
    .out_valid(valid_c), .out_slope_neg(slope_c), .out_lo_bus(lo_c), .out_hi_bus(hi_c), .out_offset_bus(offset_c), .out_bits_bus(bits_c)
  );
  always_ff @(posedge clk) begin
    out_valid <= valid_c; out_slope_neg <= slope_c; out_lo_bus <= lo_c;
    out_hi_bus <= hi_c; out_offset_bus <= offset_c; out_bits_bus <= bits_c;
  end
endmodule

module bp_ef2_state_map_compose8_pipe_ooc (
  input wire logic clk, rst_n, in_valid,
  input wire logic [4:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [139:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [19:0] l_bits_bus,
  input wire logic signed [139:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [19:0] r_bits_bus,
  output logic out_valid,
  output logic [8:0] out_map_valid, out_slope_neg,
  output logic signed [251:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [71:0] out_bits_bus
);
  bp_ef2_map_compose_pipe #(.L_REGIONS(5), .R_REGIONS(5), .OUT_REGIONS(9), .L_BITS(4), .R_BITS(4)) u_pipe (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .l_valid(l_valid), .l_slope_neg(l_slope_neg),
    .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus),
    .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus), .out_valid(out_valid),
    .out_map_valid(out_map_valid), .out_slope_neg(out_slope_neg), .out_lo_bus(out_lo_bus),
    .out_hi_bus(out_hi_bus), .out_offset_bus(out_offset_bus), .out_bits_bus(out_bits_bus)
  );
endmodule

// Fixed-tap compose8 experiment.  This keeps map context in reset-free delay
// lines and moves only cursor/select metadata through the active micro-stages.
module bp_ef2_state_map_compose8_ctx_pipe_ooc (
  input wire logic clk, rst_n, in_valid,
  input wire logic [4:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [139:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [19:0] l_bits_bus,
  input wire logic signed [139:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [19:0] r_bits_bus,
  output logic out_valid,
  output logic [8:0] out_map_valid, out_slope_neg,
  output logic signed [251:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [71:0] out_bits_bus
);
  bp_ef2_map_compose_ctx_pipe #(.L_REGIONS(5), .R_REGIONS(5), .OUT_REGIONS(9), .L_BITS(4), .R_BITS(4)) u_pipe (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .l_valid(l_valid), .l_slope_neg(l_slope_neg),
    .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus),
    .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus), .out_valid(out_valid),
    .out_map_valid(out_map_valid), .out_slope_neg(out_slope_neg), .out_lo_bus(out_lo_bus),
    .out_hi_bus(out_hi_bus), .out_offset_bus(out_offset_bus), .out_bits_bus(out_bits_bus)
  );
endmodule

module bp_ef2_state_map_compose16_pipe_ooc (
  input wire logic clk, rst_n, in_valid,
  input wire logic [8:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [251:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [71:0] l_bits_bus,
  input wire logic signed [251:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [71:0] r_bits_bus,
  output logic out_valid,
  output logic [16:0] out_map_valid, out_slope_neg,
  output logic signed [475:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [271:0] out_bits_bus
);
  bp_ef2_map_compose_pipe #(.L_REGIONS(9), .R_REGIONS(9), .OUT_REGIONS(17), .L_BITS(8), .R_BITS(8)) u_pipe (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .l_valid(l_valid), .l_slope_neg(l_slope_neg),
    .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus),
    .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus), .out_valid(out_valid),
    .out_map_valid(out_map_valid), .out_slope_neg(out_slope_neg), .out_lo_bus(out_lo_bus),
    .out_hi_bus(out_hi_bus), .out_offset_bus(out_offset_bus), .out_bits_bus(out_bits_bus)
  );
endmodule

module bp_ef2_state_map_compose32_pipe_ooc (
  input wire logic clk, rst_n, in_valid,
  input wire logic [16:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [475:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [271:0] l_bits_bus,
  input wire logic signed [475:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [271:0] r_bits_bus,
  output logic out_valid,
  output logic [33:0] out_map_valid, out_slope_neg,
  output logic signed [951:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [1087:0] out_bits_bus
);
  bp_ef2_map_compose_pipe #(.L_REGIONS(17), .R_REGIONS(17), .OUT_REGIONS(34), .L_BITS(16), .R_BITS(16)) u_pipe (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .l_valid(l_valid), .l_slope_neg(l_slope_neg),
    .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus),
    .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus), .out_valid(out_valid),
    .out_map_valid(out_map_valid), .out_slope_neg(out_slope_neg), .out_lo_bus(out_lo_bus),
    .out_hi_bus(out_hi_bus), .out_offset_bus(out_offset_bus), .out_bits_bus(out_bits_bus)
  );
endmodule

// One registered cursor advance of compose8.  The production map-builder can
// pipeline one such advance per cycle; this harness measures the achievable
// clock of that micro-stage independently of the number of output regions.
module bp_ef2_state_map_compose8_step_ooc (
  input wire logic clk,
  input wire logic signed [27:0] cursor_in,
  input wire logic [4:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [139:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [19:0] l_bits_bus,
  input wire logic signed [139:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [19:0] r_bits_bus,
  output logic valid_out, slope_neg_out,
  output logic signed [27:0] lo_out, hi_out, offset_out, cursor_next,
  output logic [7:0] bits_out
);
  logic valid_c, slope_c;
  logic signed [27:0] lo_c, hi_c, offset_c, cursor_c;
  logic [7:0] bits_c;
  bp_ef2_map_compose_step #(.L_REGIONS(5), .R_REGIONS(5), .L_BITS(4), .R_BITS(4)) u_step (
    .cursor_in(cursor_in), .l_valid(l_valid), .l_slope_neg(l_slope_neg),
    .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus),
    .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus), .valid_out(valid_c),
    .slope_neg_out(slope_c), .lo_out(lo_c), .hi_out(hi_c), .offset_out(offset_c),
    .bits_out(bits_c), .cursor_next(cursor_c)
  );
  always_ff @(posedge clk) begin
    valid_out <= valid_c; slope_neg_out <= slope_c; lo_out <= lo_c; hi_out <= hi_c;
    offset_out <= offset_c; bits_out <= bits_c; cursor_next <= cursor_c;
  end
endmodule

// First micro-stage of a pipelined compose advance: choose the left region.
module bp_ef2_state_map_compose8_left_select_ooc (
  input wire logic clk,
  input wire logic signed [27:0] cursor_in,
  input wire logic [4:0] region_valid, region_slope_neg,
  input wire logic signed [139:0] region_lo_bus, region_hi_bus, region_offset_bus,
  input wire logic [19:0] region_bits_bus,
  output logic found, slope_neg_out,
  output logic signed [27:0] lo_out, hi_out, offset_out,
  output logic [3:0] bits_out
);
  logic found_c, slope_c;
  logic signed [27:0] lo_c, hi_c, offset_c;
  logic [3:0] bits_c;
  bp_ef2_map_region_select #(.REGIONS(5), .BITS_W(4)) u_select (
    .state_in(cursor_in), .region_valid(region_valid), .region_slope_neg(region_slope_neg),
    .region_lo_bus(region_lo_bus), .region_hi_bus(region_hi_bus), .region_offset_bus(region_offset_bus),
    .region_bits_bus(region_bits_bus), .found(found_c), .slope_neg_out(slope_c),
    .lo_out(lo_c), .hi_out(hi_c), .offset_out(offset_c), .bits_out(bits_c)
  );
  always_ff @(posedge clk) begin
    found <= found_c; slope_neg_out <= slope_c; lo_out <= lo_c; hi_out <= hi_c;
    offset_out <= offset_c; bits_out <= bits_c;
  end
endmodule

// Second micro-stage: derive right-map state then choose the right region.
module bp_ef2_state_map_compose8_right_select_ooc (
  input wire logic clk,
  input wire logic signed [27:0] cursor_in, l_offset_in,
  input wire logic l_slope_neg_in,
  input wire logic [4:0] region_valid, region_slope_neg,
  input wire logic signed [139:0] region_lo_bus, region_hi_bus, region_offset_bus,
  input wire logic [19:0] region_bits_bus,
  output logic found, slope_neg_out,
  output logic signed [27:0] lo_out, hi_out, offset_out,
  output logic [3:0] bits_out
);
  logic signed [27:0] state_left;
  logic found_c, slope_c;
  logic signed [27:0] lo_c, hi_c, offset_c;
  logic [3:0] bits_c;
  always_comb state_left = l_slope_neg_in ? (-$signed(cursor_in) + $signed(l_offset_in)) :
                                           ( $signed(cursor_in) + $signed(l_offset_in));
  bp_ef2_map_region_select #(.REGIONS(5), .BITS_W(4)) u_select (
    .state_in(state_left), .region_valid(region_valid), .region_slope_neg(region_slope_neg),
    .region_lo_bus(region_lo_bus), .region_hi_bus(region_hi_bus), .region_offset_bus(region_offset_bus),
    .region_bits_bus(region_bits_bus), .found(found_c), .slope_neg_out(slope_c),
    .lo_out(lo_c), .hi_out(hi_c), .offset_out(offset_c), .bits_out(bits_c)
  );
  always_ff @(posedge clk) begin
    found <= found_c; slope_neg_out <= slope_c; lo_out <= lo_c; hi_out <= hi_c;
    offset_out <= offset_c; bits_out <= bits_c;
  end
endmodule

module bp_ef2_state_map_compose16_ooc (
  input wire logic clk,
  input wire logic [8:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [251:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [71:0] l_bits_bus,
  input wire logic signed [251:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [71:0] r_bits_bus,
  output logic [16:0] out_valid, out_slope_neg,
  output logic signed [475:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [271:0] out_bits_bus
);
  logic [16:0] valid_c, slope_c;
  logic signed [475:0] lo_c, hi_c, offset_c;
  logic [271:0] bits_c;
  bp_ef2_map_compose #(.L_REGIONS(9), .R_REGIONS(9), .OUT_REGIONS(17), .L_BITS(8), .R_BITS(8)) u_compose (
    .l_valid(l_valid), .l_slope_neg(l_slope_neg), .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus), .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus),
    .out_valid(valid_c), .out_slope_neg(slope_c), .out_lo_bus(lo_c), .out_hi_bus(hi_c), .out_offset_bus(offset_c), .out_bits_bus(bits_c)
  );
  always_ff @(posedge clk) begin
    out_valid <= valid_c; out_slope_neg <= slope_c; out_lo_bus <= lo_c;
    out_hi_bus <= hi_c; out_offset_bus <= offset_c; out_bits_bus <= bits_c;
  end
endmodule

module bp_ef2_state_map_compose32_ooc (
  input wire logic clk,
  input wire logic [16:0] l_valid, l_slope_neg, r_valid, r_slope_neg,
  input wire logic signed [475:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [271:0] l_bits_bus,
  input wire logic signed [475:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [271:0] r_bits_bus,
  output logic [33:0] out_valid, out_slope_neg,
  output logic signed [951:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [1087:0] out_bits_bus
);
  logic [33:0] valid_c, slope_c;
  logic signed [951:0] lo_c, hi_c, offset_c;
  logic [1087:0] bits_c;
  bp_ef2_map_compose #(.L_REGIONS(17), .R_REGIONS(17), .OUT_REGIONS(34), .L_BITS(16), .R_BITS(16)) u_compose (
    .l_valid(l_valid), .l_slope_neg(l_slope_neg), .l_lo_bus(l_lo_bus), .l_hi_bus(l_hi_bus), .l_offset_bus(l_offset_bus), .l_bits_bus(l_bits_bus),
    .r_valid(r_valid), .r_slope_neg(r_slope_neg), .r_lo_bus(r_lo_bus), .r_hi_bus(r_hi_bus), .r_offset_bus(r_offset_bus), .r_bits_bus(r_bits_bus),
    .out_valid(valid_c), .out_slope_neg(slope_c), .out_lo_bus(lo_c), .out_hi_bus(hi_c), .out_offset_bus(offset_c), .out_bits_bus(bits_c)
  );
  always_ff @(posedge clk) begin
    out_valid <= valid_c; out_slope_neg <= slope_c; out_lo_bus <= lo_c;
    out_hi_bus <= hi_c; out_offset_bus <= offset_c; out_bits_bus <= bits_c;
  end
endmodule

module bp_ef2_state_selector_ooc (
  input wire logic clk,
  input wire logic signed [27:0] state_in,
  input wire logic [33:0] region_valid, region_slope_neg,
  input wire logic signed [951:0] region_lo_bus, region_hi_bus, region_offset_bus,
  input wire logic [1087:0] region_bits_bus,
  output logic found, region_slope_neg_out,
  output logic signed [27:0] region_offset_out,
  output logic [31:0] region_bits_out
);
  logic found_c, slope_c;
  logic signed [27:0] offset_c;
  logic [31:0] bits_c;
  bp_ef2_state_selector u_selector (
    .state_in(state_in), .region_valid(region_valid), .region_slope_neg(region_slope_neg),
    .region_lo_bus(region_lo_bus), .region_hi_bus(region_hi_bus), .region_offset_bus(region_offset_bus),
    .region_bits_bus(region_bits_bus), .found(found_c), .region_slope_neg_out(slope_c),
    .region_offset_out(offset_c), .region_bits_out(bits_c)
  );
  always_ff @(posedge clk) begin
    found <= found_c; region_slope_neg_out <= slope_c;
    region_offset_out <= offset_c; region_bits_out <= bits_c;
  end
endmodule

`default_nettype wire
