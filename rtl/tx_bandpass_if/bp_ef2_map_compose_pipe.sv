// II=1 micro-pipelined ordered map composition.
//
// A compose result contains at most OUT_REGIONS ordered output intervals.  One
// interval advance is split into left-select, right-select, and emit stages.
// Every stage carries the map transaction payload, so a new map is accepted on
// every clock while older maps occupy later stages.  Latency is therefore
// 3*OUT_REGIONS clocks, but initiation interval remains one.
`timescale 1ns/1ps
`default_nettype none

module bp_ef2_map_compose_pipe_left #(
  parameter int ACC_W = 28, parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5, parameter int L_BITS = 4,
  parameter int R_BITS = 4, parameter int OUT_REGIONS = 9
) (
  input wire logic clk, rst_n, token_valid,
  input wire logic signed [ACC_W-1:0] cursor_in,
  input wire logic [L_REGIONS-1:0] l_valid, l_slope_neg,
  input wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input wire logic [R_REGIONS-1:0] r_valid, r_slope_neg,
  input wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  input wire logic [OUT_REGIONS-1:0] acc_valid, acc_slope_neg,
  input wire logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_bus, acc_hi_bus, acc_offset_bus,
  input wire logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_bus,
  output logic token_valid_q, output logic signed [ACC_W-1:0] cursor_q,
  output logic [L_REGIONS-1:0] l_valid_q, l_slope_neg_q,
  output logic signed [L_REGIONS*ACC_W-1:0] l_lo_q, l_hi_q, l_offset_q,
  output logic [L_REGIONS*L_BITS-1:0] l_bits_q,
  output logic [R_REGIONS-1:0] r_valid_q, r_slope_neg_q,
  output logic signed [R_REGIONS*ACC_W-1:0] r_lo_q, r_hi_q, r_offset_q,
  output logic [R_REGIONS*R_BITS-1:0] r_bits_q,
  output logic [OUT_REGIONS-1:0] acc_valid_q, acc_slope_neg_q,
  output logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_q, acc_hi_q, acc_offset_q,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_q,
  output logic left_found_q, left_slope_q,
  output logic signed [ACC_W-1:0] left_hi_q, left_offset_q,
  output logic [L_BITS-1:0] left_bits_q
);
  logic left_found_c, left_slope_c;
  logic signed [ACC_W-1:0] left_lo_c, left_hi_c, left_offset_c;
  logic [L_BITS-1:0] left_bits_c;
  bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(L_REGIONS), .BITS_W(L_BITS)) u_select (
    .state_in(cursor_in), .region_valid(l_valid), .region_slope_neg(l_slope_neg),
    .region_lo_bus(l_lo_bus), .region_hi_bus(l_hi_bus), .region_offset_bus(l_offset_bus),
    .region_bits_bus(l_bits_bus), .found(left_found_c), .slope_neg_out(left_slope_c),
    .lo_out(left_lo_c), .hi_out(left_hi_c), .offset_out(left_offset_c), .bits_out(left_bits_c)
  );
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      token_valid_q <= 1'b0;
    end else begin
      token_valid_q <= token_valid;
    end
  end
  always_ff @(posedge clk) begin
      cursor_q <= cursor_in;
      l_valid_q <= l_valid; l_slope_neg_q <= l_slope_neg; l_lo_q <= l_lo_bus; l_hi_q <= l_hi_bus; l_offset_q <= l_offset_bus; l_bits_q <= l_bits_bus;
      r_valid_q <= r_valid; r_slope_neg_q <= r_slope_neg; r_lo_q <= r_lo_bus; r_hi_q <= r_hi_bus; r_offset_q <= r_offset_bus; r_bits_q <= r_bits_bus;
      acc_valid_q <= acc_valid; acc_slope_neg_q <= acc_slope_neg; acc_lo_q <= acc_lo_bus; acc_hi_q <= acc_hi_bus; acc_offset_q <= acc_offset_bus; acc_bits_q <= acc_bits_bus;
      left_found_q <= left_found_c; left_slope_q <= left_slope_c; left_hi_q <= left_hi_c; left_offset_q <= left_offset_c; left_bits_q <= left_bits_c;
  end
endmodule

module bp_ef2_map_compose_pipe_right #(
  parameter int ACC_W = 28, parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5, parameter int L_BITS = 4,
  parameter int R_BITS = 4, parameter int OUT_REGIONS = 9
) (
  input wire logic clk, rst_n, token_valid,
  input wire logic signed [ACC_W-1:0] cursor_in,
  input wire logic [L_REGIONS-1:0] l_valid, l_slope_neg,
  input wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input wire logic [R_REGIONS-1:0] r_valid, r_slope_neg,
  input wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  input wire logic [OUT_REGIONS-1:0] acc_valid, acc_slope_neg,
  input wire logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_bus, acc_hi_bus, acc_offset_bus,
  input wire logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_bus,
  input wire logic left_found, left_slope,
  input wire logic signed [ACC_W-1:0] left_hi, left_offset,
  input wire logic [L_BITS-1:0] left_bits,
  output logic token_valid_q, output logic signed [ACC_W-1:0] cursor_q,
  output logic [L_REGIONS-1:0] l_valid_q, l_slope_neg_q,
  output logic signed [L_REGIONS*ACC_W-1:0] l_lo_q, l_hi_q, l_offset_q,
  output logic [L_REGIONS*L_BITS-1:0] l_bits_q,
  output logic [R_REGIONS-1:0] r_valid_q, r_slope_neg_q,
  output logic signed [R_REGIONS*ACC_W-1:0] r_lo_q, r_hi_q, r_offset_q,
  output logic [R_REGIONS*R_BITS-1:0] r_bits_q,
  output logic [OUT_REGIONS-1:0] acc_valid_q, acc_slope_neg_q,
  output logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_q, acc_hi_q, acc_offset_q,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_q,
  output logic left_found_q, left_slope_q,
  output logic signed [ACC_W-1:0] left_hi_q, left_offset_q,
  output logic [L_BITS-1:0] left_bits_q,
  output logic right_found_q, right_slope_q,
  output logic signed [ACC_W-1:0] right_lo_q, right_hi_q, right_offset_q,
  output logic [R_BITS-1:0] right_bits_q
);
  logic signed [ACC_W-1:0] left_state;
  logic right_found_c, right_slope_c;
  logic signed [ACC_W-1:0] right_lo_c, right_hi_c, right_offset_c;
  logic [R_BITS-1:0] right_bits_c;
  always_comb left_state = left_slope ? (-$signed(cursor_in) + $signed(left_offset)) :
                                      ( $signed(cursor_in) + $signed(left_offset));
  bp_ef2_map_region_select #(.ACC_W(ACC_W), .REGIONS(R_REGIONS), .BITS_W(R_BITS)) u_select (
    .state_in(left_state), .region_valid(r_valid), .region_slope_neg(r_slope_neg),
    .region_lo_bus(r_lo_bus), .region_hi_bus(r_hi_bus), .region_offset_bus(r_offset_bus),
    .region_bits_bus(r_bits_bus), .found(right_found_c), .slope_neg_out(right_slope_c),
    .lo_out(right_lo_c), .hi_out(right_hi_c), .offset_out(right_offset_c), .bits_out(right_bits_c)
  );
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      token_valid_q <= 1'b0;
    end else begin
      token_valid_q <= token_valid;
    end
  end
  always_ff @(posedge clk) begin
      cursor_q <= cursor_in; l_valid_q <= l_valid; l_slope_neg_q <= l_slope_neg; l_lo_q <= l_lo_bus; l_hi_q <= l_hi_bus; l_offset_q <= l_offset_bus; l_bits_q <= l_bits_bus;
      r_valid_q <= r_valid; r_slope_neg_q <= r_slope_neg; r_lo_q <= r_lo_bus; r_hi_q <= r_hi_bus; r_offset_q <= r_offset_bus; r_bits_q <= r_bits_bus;
      acc_valid_q <= acc_valid; acc_slope_neg_q <= acc_slope_neg; acc_lo_q <= acc_lo_bus; acc_hi_q <= acc_hi_bus; acc_offset_q <= acc_offset_bus; acc_bits_q <= acc_bits_bus;
      left_found_q <= left_found; left_slope_q <= left_slope; left_hi_q <= left_hi; left_offset_q <= left_offset; left_bits_q <= left_bits;
      right_found_q <= right_found_c; right_slope_q <= right_slope_c; right_lo_q <= right_lo_c; right_hi_q <= right_hi_c; right_offset_q <= right_offset_c; right_bits_q <= right_bits_c;
  end
endmodule

module bp_ef2_map_compose_pipe_emit #(
  parameter int ACC_W = 28, parameter int L_REGIONS = 5,
  parameter int R_REGIONS = 5, parameter int L_BITS = 4,
  parameter int R_BITS = 4, parameter int OUT_REGIONS = 9, parameter int SLOT = 0
) (
  input wire logic clk, rst_n, token_valid,
  input wire logic signed [ACC_W-1:0] cursor_in,
  input wire logic [L_REGIONS-1:0] l_valid, l_slope_neg,
  input wire logic signed [L_REGIONS*ACC_W-1:0] l_lo_bus, l_hi_bus, l_offset_bus,
  input wire logic [L_REGIONS*L_BITS-1:0] l_bits_bus,
  input wire logic [R_REGIONS-1:0] r_valid, r_slope_neg,
  input wire logic signed [R_REGIONS*ACC_W-1:0] r_lo_bus, r_hi_bus, r_offset_bus,
  input wire logic [R_REGIONS*R_BITS-1:0] r_bits_bus,
  input wire logic [OUT_REGIONS-1:0] acc_valid, acc_slope_neg,
  input wire logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_bus, acc_hi_bus, acc_offset_bus,
  input wire logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_bus,
  input wire logic left_found, left_slope, right_found, right_slope,
  input wire logic signed [ACC_W-1:0] left_hi, left_offset, right_lo, right_hi, right_offset,
  input wire logic [L_BITS-1:0] left_bits,
  input wire logic [R_BITS-1:0] right_bits,
  output logic token_valid_q, output logic signed [ACC_W-1:0] cursor_q,
  output logic [L_REGIONS-1:0] l_valid_q, l_slope_neg_q,
  output logic signed [L_REGIONS*ACC_W-1:0] l_lo_q, l_hi_q, l_offset_q,
  output logic [L_REGIONS*L_BITS-1:0] l_bits_q,
  output logic [R_REGIONS-1:0] r_valid_q, r_slope_neg_q,
  output logic signed [R_REGIONS*ACC_W-1:0] r_lo_q, r_hi_q, r_offset_q,
  output logic [R_REGIONS*R_BITS-1:0] r_bits_q,
  output logic [OUT_REGIONS-1:0] acc_valid_q, acc_slope_neg_q,
  output logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_q, acc_hi_q, acc_offset_q,
  output logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_q
);
  localparam logic signed [ACC_W-1:0] DOMAIN_MAX = 32769;
  logic signed [ACC_W:0] preimage_hi;
  logic signed [ACC_W:0] interval_hi;
  logic signed [ACC_W:0] offset_value;
  logic emit_valid;
  logic signed [ACC_W-1:0] cursor_next;
  logic [OUT_REGIONS-1:0] acc_valid_c, acc_slope_c;
  logic signed [OUT_REGIONS*ACC_W-1:0] acc_lo_c, acc_hi_c, acc_offset_c;
  logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] acc_bits_c;
  always_comb begin
    preimage_hi = left_slope ? ($signed(left_offset) - $signed(right_lo)) : ($signed(right_hi) - $signed(left_offset));
    interval_hi = ($signed(left_hi) < $signed(preimage_hi)) ? $signed(left_hi) : preimage_hi;
    offset_value = right_slope ? (-$signed(left_offset) + $signed(right_offset)) : ($signed(left_offset) + $signed(right_offset));
    emit_valid = left_found && right_found && ($signed(cursor_in) <= $signed(DOMAIN_MAX)) && ($signed(interval_hi) >= $signed(cursor_in));
    cursor_next = emit_valid ? interval_hi[ACC_W-1:0] + 1'b1 : DOMAIN_MAX + 1'b1;
    acc_valid_c = acc_valid; acc_slope_c = acc_slope_neg; acc_lo_c = acc_lo_bus; acc_hi_c = acc_hi_bus; acc_offset_c = acc_offset_bus; acc_bits_c = acc_bits_bus;
    acc_valid_c[SLOT] = emit_valid;
    acc_slope_c[SLOT] = left_slope ^ right_slope;
    acc_lo_c[SLOT*ACC_W +: ACC_W] = cursor_in;
    acc_hi_c[SLOT*ACC_W +: ACC_W] = interval_hi[ACC_W-1:0];
    acc_offset_c[SLOT*ACC_W +: ACC_W] = offset_value[ACC_W-1:0];
    acc_bits_c[SLOT*(L_BITS+R_BITS) +: (L_BITS+R_BITS)] = {right_bits, left_bits};
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      token_valid_q <= 1'b0;
    end else begin
      token_valid_q <= token_valid;
    end
  end
  always_ff @(posedge clk) begin
      cursor_q <= cursor_next; l_valid_q <= l_valid; l_slope_neg_q <= l_slope_neg; l_lo_q <= l_lo_bus; l_hi_q <= l_hi_bus; l_offset_q <= l_offset_bus; l_bits_q <= l_bits_bus;
      r_valid_q <= r_valid; r_slope_neg_q <= r_slope_neg; r_lo_q <= r_lo_bus; r_hi_q <= r_hi_bus; r_offset_q <= r_offset_bus; r_bits_q <= r_bits_bus;
      acc_valid_q <= acc_valid_c; acc_slope_neg_q <= acc_slope_c; acc_lo_q <= acc_lo_c; acc_hi_q <= acc_hi_c; acc_offset_q <= acc_offset_c; acc_bits_q <= acc_bits_c;
  end
endmodule

(* keep_hierarchy = "yes" *)
module bp_ef2_map_compose_pipe #(
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
  localparam logic signed [ACC_W-1:0] DOMAIN_MIN = -32769;
  logic valid_t [0:OUT_REGIONS];
  logic signed [ACC_W-1:0] cursor_t [0:OUT_REGIONS];
  logic [L_REGIONS-1:0] lv_t [0:OUT_REGIONS], ls_t [0:OUT_REGIONS];
  logic signed [L_REGIONS*ACC_W-1:0] llo_t [0:OUT_REGIONS], lhi_t [0:OUT_REGIONS], lof_t [0:OUT_REGIONS];
  logic [L_REGIONS*L_BITS-1:0] lb_t [0:OUT_REGIONS];
  logic [R_REGIONS-1:0] rv_t [0:OUT_REGIONS], rs_t [0:OUT_REGIONS];
  logic signed [R_REGIONS*ACC_W-1:0] rlo_t [0:OUT_REGIONS], rhi_t [0:OUT_REGIONS], rof_t [0:OUT_REGIONS];
  logic [R_REGIONS*R_BITS-1:0] rb_t [0:OUT_REGIONS];
  logic [OUT_REGIONS-1:0] av_t [0:OUT_REGIONS], as_t [0:OUT_REGIONS];
  logic signed [OUT_REGIONS*ACC_W-1:0] alo_t [0:OUT_REGIONS], ahi_t [0:OUT_REGIONS], aof_t [0:OUT_REGIONS];
  logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] ab_t [0:OUT_REGIONS];
  logic valid_l [0:OUT_REGIONS-1], valid_r [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] cursor_l [0:OUT_REGIONS-1], cursor_r [0:OUT_REGIONS-1];
  logic [L_REGIONS-1:0] lv_l [0:OUT_REGIONS-1], ls_l [0:OUT_REGIONS-1], lv_r [0:OUT_REGIONS-1], ls_r [0:OUT_REGIONS-1];
  logic signed [L_REGIONS*ACC_W-1:0] llo_l [0:OUT_REGIONS-1], lhi_l [0:OUT_REGIONS-1], lof_l [0:OUT_REGIONS-1], llo_r [0:OUT_REGIONS-1], lhi_r [0:OUT_REGIONS-1], lof_r [0:OUT_REGIONS-1];
  logic [L_REGIONS*L_BITS-1:0] lb_l [0:OUT_REGIONS-1], lb_r [0:OUT_REGIONS-1];
  logic [R_REGIONS-1:0] rv_l [0:OUT_REGIONS-1], rs_l [0:OUT_REGIONS-1], rv_r [0:OUT_REGIONS-1], rs_r [0:OUT_REGIONS-1];
  logic signed [R_REGIONS*ACC_W-1:0] rlo_l [0:OUT_REGIONS-1], rhi_l [0:OUT_REGIONS-1], rof_l [0:OUT_REGIONS-1], rlo_r [0:OUT_REGIONS-1], rhi_r [0:OUT_REGIONS-1], rof_r [0:OUT_REGIONS-1];
  logic [R_REGIONS*R_BITS-1:0] rb_l [0:OUT_REGIONS-1], rb_r [0:OUT_REGIONS-1];
  logic [OUT_REGIONS-1:0] av_l [0:OUT_REGIONS-1], as_l [0:OUT_REGIONS-1], av_r [0:OUT_REGIONS-1], as_r [0:OUT_REGIONS-1];
  logic signed [OUT_REGIONS*ACC_W-1:0] alo_l [0:OUT_REGIONS-1], ahi_l [0:OUT_REGIONS-1], aof_l [0:OUT_REGIONS-1], alo_r [0:OUT_REGIONS-1], ahi_r [0:OUT_REGIONS-1], aof_r [0:OUT_REGIONS-1];
  logic [OUT_REGIONS*(L_BITS+R_BITS)-1:0] ab_l [0:OUT_REGIONS-1], ab_r [0:OUT_REGIONS-1];
  logic lf_l [0:OUT_REGIONS-1], lsx_l [0:OUT_REGIONS-1], lf_r [0:OUT_REGIONS-1], lsx_r [0:OUT_REGIONS-1], rf_r [0:OUT_REGIONS-1], rsx_r [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] lhi_sel_l [0:OUT_REGIONS-1], lof_sel_l [0:OUT_REGIONS-1], lhi_sel_r [0:OUT_REGIONS-1], lof_sel_r [0:OUT_REGIONS-1];
  logic [L_BITS-1:0] lb_sel_l [0:OUT_REGIONS-1], lb_sel_r [0:OUT_REGIONS-1];
  logic signed [ACC_W-1:0] rlo_sel_r [0:OUT_REGIONS-1], rhi_sel_r [0:OUT_REGIONS-1], rof_sel_r [0:OUT_REGIONS-1];
  logic [R_BITS-1:0] rb_sel_r [0:OUT_REGIONS-1];

  assign valid_t[0] = in_valid; assign cursor_t[0] = DOMAIN_MIN;
  assign lv_t[0] = l_valid; assign ls_t[0] = l_slope_neg; assign llo_t[0] = l_lo_bus; assign lhi_t[0] = l_hi_bus; assign lof_t[0] = l_offset_bus; assign lb_t[0] = l_bits_bus;
  assign rv_t[0] = r_valid; assign rs_t[0] = r_slope_neg; assign rlo_t[0] = r_lo_bus; assign rhi_t[0] = r_hi_bus; assign rof_t[0] = r_offset_bus; assign rb_t[0] = r_bits_bus;
  assign av_t[0] = '0; assign as_t[0] = '0; assign alo_t[0] = '0; assign ahi_t[0] = '0; assign aof_t[0] = '0; assign ab_t[0] = '0;

  genvar g;
  generate for (g = 0; g < OUT_REGIONS; g = g + 1) begin : gen_region_pipe
    bp_ef2_map_compose_pipe_left #(.ACC_W(ACC_W), .L_REGIONS(L_REGIONS), .R_REGIONS(R_REGIONS), .L_BITS(L_BITS), .R_BITS(R_BITS), .OUT_REGIONS(OUT_REGIONS)) u_left (
      .clk(clk), .rst_n(rst_n), .token_valid(valid_t[g]), .cursor_in(cursor_t[g]), .l_valid(lv_t[g]), .l_slope_neg(ls_t[g]), .l_lo_bus(llo_t[g]), .l_hi_bus(lhi_t[g]), .l_offset_bus(lof_t[g]), .l_bits_bus(lb_t[g]),
      .r_valid(rv_t[g]), .r_slope_neg(rs_t[g]), .r_lo_bus(rlo_t[g]), .r_hi_bus(rhi_t[g]), .r_offset_bus(rof_t[g]), .r_bits_bus(rb_t[g]), .acc_valid(av_t[g]), .acc_slope_neg(as_t[g]), .acc_lo_bus(alo_t[g]), .acc_hi_bus(ahi_t[g]), .acc_offset_bus(aof_t[g]), .acc_bits_bus(ab_t[g]),
      .token_valid_q(valid_l[g]), .cursor_q(cursor_l[g]), .l_valid_q(lv_l[g]), .l_slope_neg_q(ls_l[g]), .l_lo_q(llo_l[g]), .l_hi_q(lhi_l[g]), .l_offset_q(lof_l[g]), .l_bits_q(lb_l[g]), .r_valid_q(rv_l[g]), .r_slope_neg_q(rs_l[g]), .r_lo_q(rlo_l[g]), .r_hi_q(rhi_l[g]), .r_offset_q(rof_l[g]), .r_bits_q(rb_l[g]), .acc_valid_q(av_l[g]), .acc_slope_neg_q(as_l[g]), .acc_lo_q(alo_l[g]), .acc_hi_q(ahi_l[g]), .acc_offset_q(aof_l[g]), .acc_bits_q(ab_l[g]), .left_found_q(lf_l[g]), .left_slope_q(lsx_l[g]), .left_hi_q(lhi_sel_l[g]), .left_offset_q(lof_sel_l[g]), .left_bits_q(lb_sel_l[g])
    );
    bp_ef2_map_compose_pipe_right #(.ACC_W(ACC_W), .L_REGIONS(L_REGIONS), .R_REGIONS(R_REGIONS), .L_BITS(L_BITS), .R_BITS(R_BITS), .OUT_REGIONS(OUT_REGIONS)) u_right (
      .clk(clk), .rst_n(rst_n), .token_valid(valid_l[g]), .cursor_in(cursor_l[g]), .l_valid(lv_l[g]), .l_slope_neg(ls_l[g]), .l_lo_bus(llo_l[g]), .l_hi_bus(lhi_l[g]), .l_offset_bus(lof_l[g]), .l_bits_bus(lb_l[g]),
      .r_valid(rv_l[g]), .r_slope_neg(rs_l[g]), .r_lo_bus(rlo_l[g]), .r_hi_bus(rhi_l[g]), .r_offset_bus(rof_l[g]), .r_bits_bus(rb_l[g]), .acc_valid(av_l[g]), .acc_slope_neg(as_l[g]), .acc_lo_bus(alo_l[g]), .acc_hi_bus(ahi_l[g]), .acc_offset_bus(aof_l[g]), .acc_bits_bus(ab_l[g]), .left_found(lf_l[g]), .left_slope(lsx_l[g]), .left_hi(lhi_sel_l[g]), .left_offset(lof_sel_l[g]), .left_bits(lb_sel_l[g]),
      .token_valid_q(valid_r[g]), .cursor_q(cursor_r[g]), .l_valid_q(lv_r[g]), .l_slope_neg_q(ls_r[g]), .l_lo_q(llo_r[g]), .l_hi_q(lhi_r[g]), .l_offset_q(lof_r[g]), .l_bits_q(lb_r[g]), .r_valid_q(rv_r[g]), .r_slope_neg_q(rs_r[g]), .r_lo_q(rlo_r[g]), .r_hi_q(rhi_r[g]), .r_offset_q(rof_r[g]), .r_bits_q(rb_r[g]), .acc_valid_q(av_r[g]), .acc_slope_neg_q(as_r[g]), .acc_lo_q(alo_r[g]), .acc_hi_q(ahi_r[g]), .acc_offset_q(aof_r[g]), .acc_bits_q(ab_r[g]), .left_found_q(lf_r[g]), .left_slope_q(lsx_r[g]), .left_hi_q(lhi_sel_r[g]), .left_offset_q(lof_sel_r[g]), .left_bits_q(lb_sel_r[g]), .right_found_q(rf_r[g]), .right_slope_q(rsx_r[g]), .right_lo_q(rlo_sel_r[g]), .right_hi_q(rhi_sel_r[g]), .right_offset_q(rof_sel_r[g]), .right_bits_q(rb_sel_r[g])
    );
    bp_ef2_map_compose_pipe_emit #(.ACC_W(ACC_W), .L_REGIONS(L_REGIONS), .R_REGIONS(R_REGIONS), .L_BITS(L_BITS), .R_BITS(R_BITS), .OUT_REGIONS(OUT_REGIONS), .SLOT(g)) u_emit (
      .clk(clk), .rst_n(rst_n), .token_valid(valid_r[g]), .cursor_in(cursor_r[g]), .l_valid(lv_r[g]), .l_slope_neg(ls_r[g]), .l_lo_bus(llo_r[g]), .l_hi_bus(lhi_r[g]), .l_offset_bus(lof_r[g]), .l_bits_bus(lb_r[g]),
      .r_valid(rv_r[g]), .r_slope_neg(rs_r[g]), .r_lo_bus(rlo_r[g]), .r_hi_bus(rhi_r[g]), .r_offset_bus(rof_r[g]), .r_bits_bus(rb_r[g]), .acc_valid(av_r[g]), .acc_slope_neg(as_r[g]), .acc_lo_bus(alo_r[g]), .acc_hi_bus(ahi_r[g]), .acc_offset_bus(aof_r[g]), .acc_bits_bus(ab_r[g]), .left_found(lf_r[g]), .left_slope(lsx_r[g]), .right_found(rf_r[g]), .right_slope(rsx_r[g]), .left_hi(lhi_sel_r[g]), .left_offset(lof_sel_r[g]), .right_lo(rlo_sel_r[g]), .right_hi(rhi_sel_r[g]), .right_offset(rof_sel_r[g]), .left_bits(lb_sel_r[g]), .right_bits(rb_sel_r[g]),
      .token_valid_q(valid_t[g+1]), .cursor_q(cursor_t[g+1]), .l_valid_q(lv_t[g+1]), .l_slope_neg_q(ls_t[g+1]), .l_lo_q(llo_t[g+1]), .l_hi_q(lhi_t[g+1]), .l_offset_q(lof_t[g+1]), .l_bits_q(lb_t[g+1]), .r_valid_q(rv_t[g+1]), .r_slope_neg_q(rs_t[g+1]), .r_lo_q(rlo_t[g+1]), .r_hi_q(rhi_t[g+1]), .r_offset_q(rof_t[g+1]), .r_bits_q(rb_t[g+1]), .acc_valid_q(av_t[g+1]), .acc_slope_neg_q(as_t[g+1]), .acc_lo_q(alo_t[g+1]), .acc_hi_q(ahi_t[g+1]), .acc_offset_q(aof_t[g+1]), .acc_bits_q(ab_t[g+1])
    );
  end endgenerate
  assign out_valid = valid_t[OUT_REGIONS]; assign out_map_valid = av_t[OUT_REGIONS]; assign out_slope_neg = as_t[OUT_REGIONS];
  assign out_lo_bus = alo_t[OUT_REGIONS]; assign out_hi_bus = ahi_t[OUT_REGIONS]; assign out_offset_bus = aof_t[OUT_REGIONS]; assign out_bits_bus = ab_t[OUT_REGIONS];
endmodule

`default_nettype wire
