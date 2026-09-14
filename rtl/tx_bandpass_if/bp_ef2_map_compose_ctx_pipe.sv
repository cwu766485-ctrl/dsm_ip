// Exact II=1 context/slot implementation of piecewise-affine map composition.
//
// Unlike bp_ef2_map_compose_pipe, this implementation never forwards a whole
// L-map/R-map plus accumulated output map through every micro-stage.  An input
// map travels once through reset-free delay lines; each region advance carries
// only cursor/select state and writes its own fixed output slot.  Per-slot
// delay lines align those writes at the common transaction output cycle.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_ctx_delay #(
  parameter int W = 1,
  parameter int DEPTH = 1
) (
  input wire logic clk,
  input wire logic [W-1:0] d,
  output wire logic [W-1:0] q
);
  logic [W-1:0] pipe [0:DEPTH-1];
  integer i;
  always_ff @(posedge clk) begin
    pipe[0] <= d;
    for (i = 1; i < DEPTH; i = i + 1) pipe[i] <= pipe[i-1];
  end
  assign q = pipe[DEPTH-1];
endmodule

module bp_ef2_map_compose_ctx_pipe #(
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
  output logic out_valid,
  output logic [OUT_REGIONS-1:0] out_map_valid, out_slope_neg,
  output logic signed [OUT_REGIONS*ACC_W-1:0] out_lo_bus, out_hi_bus, out_offset_bus,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] out_bits_bus
);
  localparam int LAT = 3*OUT_REGIONS;
  localparam int SLOT_W = 2 + 3*ACC_W + L_BITS + R_BITS;
  localparam logic signed [ACC_W-1:0] DOMAIN_MIN = -32769;
  localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;

  // A single time-indexed map context.  These chains are SRL candidates: map
  // payload never feeds a feedback mux and has no reset requirement.
  logic [L_REGIONS-1:0] lv_d [0:LAT-1], ls_d [0:LAT-1];
  logic signed [L_REGIONS*ACC_W-1:0] llo_d [0:LAT-1], lhi_d [0:LAT-1], lof_d [0:LAT-1];
  logic [L_REGIONS*L_BITS-1:0] lb_d [0:LAT-1];
  logic [R_REGIONS-1:0] rv_d [0:LAT-1], rs_d [0:LAT-1];
  logic signed [R_REGIONS*ACC_W-1:0] rlo_d [0:LAT-1], rhi_d [0:LAT-1], rof_d [0:LAT-1];
  logic [R_REGIONS*R_BITS-1:0] rb_d [0:LAT-1];
  integer d;
  always_ff @(posedge clk) begin
    lv_d[0] <= l_valid; ls_d[0] <= l_slope_neg; llo_d[0] <= l_lo_bus; lhi_d[0] <= l_hi_bus; lof_d[0] <= l_offset_bus; lb_d[0] <= l_bits_bus;
    rv_d[0] <= r_valid; rs_d[0] <= r_slope_neg; rlo_d[0] <= r_lo_bus; rhi_d[0] <= r_hi_bus; rof_d[0] <= r_offset_bus; rb_d[0] <= r_bits_bus;
    for (d = 1; d < LAT; d = d + 1) begin
      lv_d[d] <= lv_d[d-1]; ls_d[d] <= ls_d[d-1]; llo_d[d] <= llo_d[d-1]; lhi_d[d] <= lhi_d[d-1]; lof_d[d] <= lof_d[d-1]; lb_d[d] <= lb_d[d-1];
      rv_d[d] <= rv_d[d-1]; rs_d[d] <= rs_d[d-1]; rlo_d[d] <= rlo_d[d-1]; rhi_d[d] <= rhi_d[d-1]; rof_d[d] <= rof_d[d-1]; rb_d[d] <= rb_d[d-1];
    end
  end

  logic valid_l [0:OUT_REGIONS-1], valid_r [0:OUT_REGIONS-1], valid_e [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] cursor_l [0:OUT_REGIONS-1], cursor_r [0:OUT_REGIONS-1], cursor_e [0:OUT_REGIONS-1];
  logic lf [0:OUT_REGIONS-1], lsx [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] lhi_sel [0:OUT_REGIONS-1], lof_sel [0:OUT_REGIONS-1];
  logic [L_BITS-1:0] lb_sel [0:OUT_REGIONS-1];
  logic rf [0:OUT_REGIONS-1], rsx [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] rlo_sel [0:OUT_REGIONS-1], rhi_sel [0:OUT_REGIONS-1], rof_sel [0:OUT_REGIONS-1];
  logic [R_BITS-1:0] rb_sel [0:OUT_REGIONS-1];
  // The emit stage consumes a complete right-stage record.  Preserve the
  // selected left metadata alongside the right result so consecutive tokens
  // cannot cross-pair at this stage.
  logic lfr [0:OUT_REGIONS-1], lsxr [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] lhi_sel_r [0:OUT_REGIONS-1], lof_sel_r [0:OUT_REGIONS-1];
  logic [L_BITS-1:0] lb_sel_r [0:OUT_REGIONS-1];
  logic [SLOT_W-1:0] slot_e [0:OUT_REGIONS-1], slot_aligned [0:OUT_REGIONS-1];

  genvar g;
  generate for (g = 0; g < OUT_REGIONS; g = g + 1) begin : gen_slot
    wire in_token = (g == 0) ? in_valid : valid_e[g-1];
    wire logic signed [ACC_W-1:0] in_cursor = (g == 0) ? DOMAIN_MIN : cursor_e[g-1];
    // Each slot consumes the cursor from the preceding emit three clocks
    // earlier.  Because the context shift occurs at that same edge, the
    // left-select and following right-select observe ages 3*g-1 and 3*g.
    wire [L_REGIONS-1:0] l_v = (g == 0) ? l_valid : lv_d[3*g-1];
    wire [L_REGIONS-1:0] l_s = (g == 0) ? l_slope_neg : ls_d[3*g-1];
    wire logic signed [L_REGIONS*ACC_W-1:0] l_lo = (g == 0) ? l_lo_bus : llo_d[3*g-1];
    wire logic signed [L_REGIONS*ACC_W-1:0] l_hi = (g == 0) ? l_hi_bus : lhi_d[3*g-1];
    wire logic signed [L_REGIONS*ACC_W-1:0] l_of = (g == 0) ? l_offset_bus : lof_d[3*g-1];
    wire [L_REGIONS*L_BITS-1:0] l_b = (g == 0) ? l_bits_bus : lb_d[3*g-1];
    wire [R_REGIONS-1:0] r_v = rv_d[3*g];
    wire [R_REGIONS-1:0] r_s = rs_d[3*g];
    wire logic signed [R_REGIONS*ACC_W-1:0] r_lo = rlo_d[3*g];
    wire logic signed [R_REGIONS*ACC_W-1:0] r_hi = rhi_d[3*g];
    wire logic signed [R_REGIONS*ACC_W-1:0] r_of = rof_d[3*g];
    wire [R_REGIONS*R_BITS-1:0] r_b = rb_d[3*g];
    logic left_found_c, left_slope_c, right_found_c, right_slope_c;
    logic signed [ACC_W-1:0] left_lo_c, left_hi_c, left_of_c;
    logic signed [ACC_W-1:0] right_lo_c, right_hi_c, right_of_c;
    logic [L_BITS-1:0] left_bits_c;
    logic [R_BITS-1:0] right_bits_c;
    logic signed [ACC_W-1:0] left_state;
    logic signed [ACC_W:0] preimage_hi, interval_hi, offset_value;
    logic emit_valid;
    logic signed [ACC_W-1:0] cursor_next;
    logic [SLOT_W-1:0] slot_c;

    bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(L_REGIONS), .BITS_W(L_BITS)) u_left (
      .state_in(in_cursor), .region_valid(l_v), .region_slope_neg(l_s), .region_lo_bus(l_lo), .region_hi_bus(l_hi), .region_offset_bus(l_of), .region_bits_bus(l_b),
      .found(left_found_c), .slope_neg_out(left_slope_c), .lo_out(left_lo_c), .hi_out(left_hi_c), .offset_out(left_of_c), .bits_out(left_bits_c)
    );
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) valid_l[g] <= 1'b0;
      else valid_l[g] <= in_token;
    end
    always_ff @(posedge clk) begin
      cursor_l[g] <= in_cursor; lf[g] <= left_found_c; lsx[g] <= left_slope_c; lhi_sel[g] <= left_hi_c; lof_sel[g] <= left_of_c; lb_sel[g] <= left_bits_c;
    end

    always_comb left_state = lsx[g] ? (-$signed(cursor_l[g]) + $signed(lof_sel[g])) : ($signed(cursor_l[g]) + $signed(lof_sel[g]));
    bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(R_REGIONS), .BITS_W(R_BITS)) u_right (
      .state_in(left_state), .region_valid(r_v), .region_slope_neg(r_s), .region_lo_bus(r_lo), .region_hi_bus(r_hi), .region_offset_bus(r_of), .region_bits_bus(r_b),
      .found(right_found_c), .slope_neg_out(right_slope_c), .lo_out(right_lo_c), .hi_out(right_hi_c), .offset_out(right_of_c), .bits_out(right_bits_c)
    );
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) valid_r[g] <= 1'b0;
      else valid_r[g] <= valid_l[g];
    end
    always_ff @(posedge clk) begin
      cursor_r[g] <= cursor_l[g];
      lfr[g] <= lf[g]; lsxr[g] <= lsx[g]; lhi_sel_r[g] <= lhi_sel[g];
      lof_sel_r[g] <= lof_sel[g]; lb_sel_r[g] <= lb_sel[g];
      rf[g] <= right_found_c; rsx[g] <= right_slope_c; rlo_sel[g] <= right_lo_c;
      rhi_sel[g] <= right_hi_c; rof_sel[g] <= right_of_c; rb_sel[g] <= right_bits_c;
    end

    always_comb begin
      preimage_hi = lsxr[g] ? ($signed(lof_sel_r[g]) - $signed(rlo_sel[g])) : ($signed(rhi_sel[g]) - $signed(lof_sel_r[g]));
      interval_hi = ($signed(lhi_sel_r[g]) < $signed(preimage_hi)) ? $signed(lhi_sel_r[g]) : preimage_hi;
      offset_value = rsx[g] ? (-$signed(lof_sel_r[g]) + $signed(rof_sel[g])) : ($signed(lof_sel_r[g]) + $signed(rof_sel[g]));
      emit_valid = lfr[g] && rf[g] && ($signed(cursor_r[g]) <= $signed(DOMAIN_MAX)) && ($signed(interval_hi) >= $signed(cursor_r[g]));
      cursor_next = emit_valid ? interval_hi[ACC_W-1:0] + 1'b1 : DOMAIN_MAX + 1'b1;
      slot_c = {emit_valid, (lsxr[g] ^ rsx[g]), cursor_r[g], interval_hi[ACC_W-1:0], offset_value[ACC_W-1:0], rb_sel[g], lb_sel_r[g]};
    end
    always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) valid_e[g] <= 1'b0;
      else valid_e[g] <= valid_r[g];
    end
    always_ff @(posedge clk) begin
      cursor_e[g] <= cursor_next; slot_e[g] <= slot_c;
    end

    if (g == OUT_REGIONS-1) begin : gen_last_slot
      assign slot_aligned[g] = slot_e[g];
    end else begin : gen_delay_slot
      // slot_e is registered.  The delay chain samples its newly emitted value
      // on the following edge, so a depth of 3 slots per remaining region
      // aligns it with the final emit edge without an extra cycle of skew.
      bp_ef2_map_ctx_delay #(.W(SLOT_W), .DEPTH(3*(OUT_REGIONS-1-g))) u_delay (.clk(clk), .d(slot_e[g]), .q(slot_aligned[g]));
    end
    always_comb begin
      out_map_valid[g] = slot_aligned[g][SLOT_W-1];
      out_slope_neg[g] = slot_aligned[g][SLOT_W-2];
      out_lo_bus[g*ACC_W +: ACC_W] = slot_aligned[g][SLOT_W-3 -: ACC_W];
      out_hi_bus[g*ACC_W +: ACC_W] = slot_aligned[g][SLOT_W-3-ACC_W -: ACC_W];
      out_offset_bus[g*ACC_W +: ACC_W] = slot_aligned[g][SLOT_W-3-2*ACC_W -: ACC_W];
      out_bits_bus[g*(L_BITS+R_BITS) +: (L_BITS+R_BITS)] = slot_aligned[g][L_BITS+R_BITS-1:0];
    end
  end endgenerate
  always_comb out_valid = valid_e[OUT_REGIONS-1];
endmodule

`default_nettype wire
