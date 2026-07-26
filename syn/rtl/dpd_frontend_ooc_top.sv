`timescale 1ns/1ps
`default_nettype none

module dpd_frontend_ooc_top #(
  parameter integer ENABLE_DPD_POLY = 1,
  parameter integer ENABLE_DPD_LUT = 1,
  parameter integer ENABLE_DPD_MEMORY = 1,
  parameter integer DPD_POLY_ORDER = 5,
  parameter integer DPD_MP_MAX_TAPS = 4,
  parameter integer RUNTIME_MODE_INPUT = 0
) (
  input wire clk,
  input wire rst_n,
  input wire signed [15:0] i_in,
  input wire signed [15:0] q_in,
  input wire signed [15:0] c1_re,
  input wire signed [15:0] c1_im,
  input wire signed [15:0] c3_re,
  input wire signed [15:0] c3_im,
  input wire signed [15:0] c5_re,
  input wire signed [15:0] c5_im,
  input wire signed [15:0] c7_re,
  input wire signed [15:0] c7_im,
  input wire [1:0] mode,
  input wire in_valid,
  output wire in_ready,
  output wire signed [15:0] i_out,
  output wire signed [15:0] q_out,
  output wire out_valid,
  input wire out_ready
);

  // Keep exactly one active branch observable during OOC synthesis. This makes
  // the report represent a product SKU rather than a development build where
  // every runtime-selectable branch is retained.
  localparam [1:0] ACTIVE_MODE = ENABLE_DPD_POLY ? 2'd1 :
                               (ENABLE_DPD_LUT ? 2'd2 :
                               (ENABLE_DPD_MEMORY ? 2'd3 : 2'd0));
  wire [1:0] selected_mode = RUNTIME_MODE_INPUT ? mode : ACTIVE_MODE;

  dpd_frontend #(
    .MP_MAX_TAPS(DPD_MP_MAX_TAPS),
    .MP_POLY_ORDER(DPD_POLY_ORDER),
    .ENABLE_DPD_POLY(ENABLE_DPD_POLY),
    .ENABLE_DPD_LUT(ENABLE_DPD_LUT),
    .ENABLE_DPD_MEMORY(ENABLE_DPD_MEMORY)
  ) u_dut (
    .clk(clk), .rst_n(rst_n), .mode(selected_mode),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .c7_re(c7_re), .c7_im(c7_im),
    .mp_active_taps(DPD_MP_MAX_TAPS[2:0]), .mp_coeff_we(1'b0), .mp_commit(1'b0),
    .mp_coeff_tap(3'd0), .mp_coeff_order(2'd0),
    .mp_coeff_re(16'sd0), .mp_coeff_im(16'sd0),
    .mp_coeff_rdata_re(), .mp_coeff_rdata_im(), .mp_active_bank(),
    .lut_we(1'b0), .lut_commit(1'b0), .lut_waddr(4'd0),
    .lut_wgain_re(16'sd16384), .lut_wgain_im(16'sd0), .lut_raddr(4'd0),
    .lut_rgain_re(), .lut_rgain_im(), .lut_active_bank(),
    .safety_enable(1'b0), .safety_clear(1'b0), .safety_fault(),
    .mp_commit_rejected(), .lut_commit_rejected(),
    .i_in(i_in), .q_in(q_in), .in_valid(in_valid), .in_ready(in_ready),
    .i_out(i_out), .q_out(q_out), .out_valid(out_valid), .out_ready(out_ready),
    .sample_count(), .saturation_count()
  );
endmodule

`default_nettype wire
