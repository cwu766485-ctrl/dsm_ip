`timescale 1ns/1ps
`default_nettype none

module dpd_lut #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14,
  parameter integer LUT_AW = 4
) (
  input wire clk,
  input wire rst_n,

  input wire lut_we,
  input wire lut_commit,
  input wire [LUT_AW-1:0] lut_waddr,
  input wire signed [COEFF_W-1:0] lut_wgain_re,
  input wire signed [COEFF_W-1:0] lut_wgain_im,
  input wire [LUT_AW-1:0] lut_raddr,
  output wire signed [COEFF_W-1:0] lut_rgain_re,
  output wire signed [COEFF_W-1:0] lut_rgain_im,
  output reg active_bank,

  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,
  output wire signed [W-1:0] i_out,
  output wire signed [W-1:0] q_out,
  output wire sat
);

  localparam integer ACC_W = 48;
  localparam integer LUT_DEPTH = (1 << LUT_AW);

  reg signed [COEFF_W-1:0] gain_re_mem0 [0:LUT_DEPTH-1];
  reg signed [COEFF_W-1:0] gain_im_mem0 [0:LUT_DEPTH-1];
  reg signed [COEFF_W-1:0] gain_re_mem1 [0:LUT_DEPTH-1];
  reg signed [COEFF_W-1:0] gain_im_mem1 [0:LUT_DEPTH-1];

  wire [W-1:0] abs_i = i_in[W-1] ? (~i_in + {{(W-1){1'b0}}, 1'b1}) : i_in;
  wire [W-1:0] abs_q = q_in[W-1] ? (~q_in + {{(W-1){1'b0}}, 1'b1}) : q_in;
  wire [W-1:0] mag = (abs_i > abs_q) ? abs_i : abs_q;
  wire [LUT_AW-1:0] lut_index = mag[W-2 -: LUT_AW];

  wire signed [COEFF_W-1:0] active_gain_re =
      active_bank ? gain_re_mem1[lut_index] : gain_re_mem0[lut_index];
  wire signed [COEFF_W-1:0] active_gain_im =
      active_bank ? gain_im_mem1[lut_index] : gain_im_mem0[lut_index];
  wire signed [COEFF_W-1:0] shadow_rgain_re =
      active_bank ? gain_re_mem0[lut_raddr] : gain_re_mem1[lut_raddr];
  wire signed [COEFF_W-1:0] shadow_rgain_im =
      active_bank ? gain_im_mem0[lut_raddr] : gain_im_mem1[lut_raddr];

  assign lut_rgain_re = shadow_rgain_re;
  assign lut_rgain_im = shadow_rgain_im;

  wire signed [ACC_W-1:0] mix_i =
      (i_in * active_gain_re) - (q_in * active_gain_im);
  wire signed [ACC_W-1:0] mix_q =
      (i_in * active_gain_im) + (q_in * active_gain_re);

  wire signed [ACC_W-1:0] lut_i_wide = mix_i >>> COEFF_FRAC;
  wire signed [ACC_W-1:0] lut_q_wide = mix_q >>> COEFF_FRAC;
  wire sat_i;
  wire sat_q;

  dpd_sat_signed #(
    .IN_W(ACC_W),
    .OUT_W(W)
  ) u_sat_i (
    .din(lut_i_wide),
    .dout(i_out),
    .sat(sat_i)
  );

  dpd_sat_signed #(
    .IN_W(ACC_W),
    .OUT_W(W)
  ) u_sat_q (
    .din(lut_q_wide),
    .dout(q_out),
    .sat(sat_q)
  );

  assign sat = sat_i | sat_q;

  integer idx;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active_bank <= 1'b0;
      for (idx = 0; idx < LUT_DEPTH; idx = idx + 1) begin
        gain_re_mem0[idx] <= 16'sd16384;
        gain_im_mem0[idx] <= 16'sd0;
        gain_re_mem1[idx] <= 16'sd16384;
        gain_im_mem1[idx] <= 16'sd0;
      end
    end else begin
      if (lut_we) begin
        if (active_bank) begin
          gain_re_mem0[lut_waddr] <= lut_wgain_re;
          gain_im_mem0[lut_waddr] <= lut_wgain_im;
        end else begin
          gain_re_mem1[lut_waddr] <= lut_wgain_re;
          gain_im_mem1[lut_waddr] <= lut_wgain_im;
        end
      end
      if (lut_commit) begin
        active_bank <= ~active_bank;
      end
    end
  end

endmodule

`default_nettype wire
