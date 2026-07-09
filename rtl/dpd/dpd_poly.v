`timescale 1ns/1ps
`default_nettype none

module dpd_poly #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14
) (
  input wire clk,
  input wire rst_n,
  input wire enable,

  input wire signed [COEFF_W-1:0] c1_re,
  input wire signed [COEFF_W-1:0] c1_im,
  input wire signed [COEFF_W-1:0] c3_re,
  input wire signed [COEFF_W-1:0] c3_im,
  input wire signed [COEFF_W-1:0] c5_re,
  input wire signed [COEFF_W-1:0] c5_im,

  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,
  input wire in_valid,
  output wire in_ready,

  output reg signed [W-1:0] i_out,
  output reg signed [W-1:0] q_out,
  output reg out_valid,
  input wire out_ready,

  output reg [31:0] sample_count,
  output reg [31:0] saturation_count
);

  localparam integer R_FRAC = W - 1;
  localparam integer MUL_W = 2 * W;
  localparam integer ACC_W = 48;
  localparam integer PWR_W = 32;

  reg [7:0] valid_pipe;
  wire pipe_ce = out_ready | !valid_pipe[7];
  assign in_ready = pipe_ce;

  reg enable_s0;
  reg signed [W-1:0] i_s0;
  reg signed [W-1:0] q_s0;
  reg signed [COEFF_W-1:0] c1_re_s0;
  reg signed [COEFF_W-1:0] c1_im_s0;
  reg signed [COEFF_W-1:0] c3_re_s0;
  reg signed [COEFF_W-1:0] c3_im_s0;
  reg signed [COEFF_W-1:0] c5_re_s0;
  reg signed [COEFF_W-1:0] c5_im_s0;

  reg enable_s1;
  reg signed [W-1:0] i_s1;
  reg signed [W-1:0] q_s1;
  reg signed [COEFF_W-1:0] c1_re_s1;
  reg signed [COEFF_W-1:0] c1_im_s1;
  reg signed [COEFF_W-1:0] c3_re_s1;
  reg signed [COEFF_W-1:0] c3_im_s1;
  reg signed [COEFF_W-1:0] c5_re_s1;
  reg signed [COEFF_W-1:0] c5_im_s1;
  reg signed [MUL_W-1:0] i_sq_s1;
  reg signed [MUL_W-1:0] q_sq_s1;

  reg enable_s2;
  reg signed [W-1:0] i_s2;
  reg signed [W-1:0] q_s2;
  reg signed [COEFF_W-1:0] c1_re_s2;
  reg signed [COEFF_W-1:0] c1_im_s2;
  reg signed [COEFF_W-1:0] c3_re_s2;
  reg signed [COEFF_W-1:0] c3_im_s2;
  reg signed [COEFF_W-1:0] c5_re_s2;
  reg signed [COEFF_W-1:0] c5_im_s2;
  reg signed [PWR_W-1:0] r2_s2;

  reg enable_s3;
  reg signed [W-1:0] i_s3;
  reg signed [W-1:0] q_s3;
  reg signed [COEFF_W-1:0] c1_re_s3;
  reg signed [COEFF_W-1:0] c1_im_s3;
  reg signed [ACC_W-1:0] c3r_r2_s3;
  reg signed [ACC_W-1:0] c3i_r2_s3;
  reg signed [PWR_W-1:0] r4_s3;
  reg signed [COEFF_W-1:0] c5_re_s3;
  reg signed [COEFF_W-1:0] c5_im_s3;

  reg enable_s4;
  reg signed [W-1:0] i_s4;
  reg signed [W-1:0] q_s4;
  reg signed [ACC_W-1:0] c1_re_s4;
  reg signed [ACC_W-1:0] c1_im_s4;
  reg signed [ACC_W-1:0] c3r_r2_s4;
  reg signed [ACC_W-1:0] c3i_r2_s4;
  reg signed [ACC_W-1:0] c5r_r4_s4;
  reg signed [ACC_W-1:0] c5i_r4_s4;

  reg enable_s5;
  reg signed [W-1:0] i_s5;
  reg signed [W-1:0] q_s5;
  reg signed [ACC_W-1:0] gain_re_s5;
  reg signed [ACC_W-1:0] gain_im_s5;

  reg enable_s6;
  reg signed [ACC_W-1:0] in_i_wide_s6;
  reg signed [ACC_W-1:0] in_q_wide_s6;
  reg signed [ACC_W-1:0] i_gr_s6;
  reg signed [ACC_W-1:0] q_gi_s6;
  reg signed [ACC_W-1:0] i_gi_s6;
  reg signed [ACC_W-1:0] q_gr_s6;

  reg enable_s7;
  reg signed [ACC_W-1:0] dpd_i_wide_s7;
  reg signed [ACC_W-1:0] dpd_q_wide_s7;
  reg signed [ACC_W-1:0] in_i_wide_s7;
  reg signed [ACC_W-1:0] in_q_wide_s7;

  wire signed [MUL_W+1:0] r2_full_s1 =
      {{2{i_sq_s1[MUL_W-1]}}, i_sq_s1} + {{2{q_sq_s1[MUL_W-1]}}, q_sq_s1};
  wire signed [PWR_W-1:0] r2_q_s1 = r2_full_s1 >>> R_FRAC;
  wire signed [(2*PWR_W)-1:0] r4_full_s2 = r2_s2 * r2_s2;
  wire signed [PWR_W-1:0] r4_q_s2 = r4_full_s2 >>> R_FRAC;

  wire signed [ACC_W-1:0] gain_re_s4 =
      c1_re_s4 + (c3r_r2_s4 >>> R_FRAC) + (c5r_r4_s4 >>> R_FRAC);
  wire signed [ACC_W-1:0] gain_im_s4 =
      c1_im_s4 + (c3i_r2_s4 >>> R_FRAC) + (c5i_r4_s4 >>> R_FRAC);

  wire signed [ACC_W-1:0] sel_i_wide =
      enable_s7 ? dpd_i_wide_s7 : in_i_wide_s7;
  wire signed [ACC_W-1:0] sel_q_wide =
      enable_s7 ? dpd_q_wide_s7 : in_q_wide_s7;

  wire sat_i;
  wire sat_q;
  wire signed [W-1:0] sat_i_val;
  wire signed [W-1:0] sat_q_val;

  dpd_sat_signed #(
    .IN_W(ACC_W),
    .OUT_W(W)
  ) u_sat_i (
    .din(sel_i_wide),
    .dout(sat_i_val),
    .sat(sat_i)
  );

  dpd_sat_signed #(
    .IN_W(ACC_W),
    .OUT_W(W)
  ) u_sat_q (
    .din(sel_q_wide),
    .dout(sat_q_val),
    .sat(sat_q)
  );

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipe <= 8'd0;
      i_out <= {W{1'b0}};
      q_out <= {W{1'b0}};
      out_valid <= 1'b0;
      sample_count <= 32'd0;
      saturation_count <= 32'd0;
    end else begin
      if (pipe_ce) begin
        valid_pipe <= {valid_pipe[6:0], in_valid};
        out_valid <= valid_pipe[7];

        enable_s0 <= enable;
        i_s0 <= i_in;
        q_s0 <= q_in;
        c1_re_s0 <= c1_re;
        c1_im_s0 <= c1_im;
        c3_re_s0 <= c3_re;
        c3_im_s0 <= c3_im;
        c5_re_s0 <= c5_re;
        c5_im_s0 <= c5_im;

        enable_s1 <= enable_s0;
        i_s1 <= i_s0;
        q_s1 <= q_s0;
        c1_re_s1 <= c1_re_s0;
        c1_im_s1 <= c1_im_s0;
        c3_re_s1 <= c3_re_s0;
        c3_im_s1 <= c3_im_s0;
        c5_re_s1 <= c5_re_s0;
        c5_im_s1 <= c5_im_s0;
        i_sq_s1 <= i_s0 * i_s0;
        q_sq_s1 <= q_s0 * q_s0;

        enable_s2 <= enable_s1;
        i_s2 <= i_s1;
        q_s2 <= q_s1;
        c1_re_s2 <= c1_re_s1;
        c1_im_s2 <= c1_im_s1;
        c3_re_s2 <= c3_re_s1;
        c3_im_s2 <= c3_im_s1;
        c5_re_s2 <= c5_re_s1;
        c5_im_s2 <= c5_im_s1;
        r2_s2 <= r2_q_s1;

        enable_s3 <= enable_s2;
        i_s3 <= i_s2;
        q_s3 <= q_s2;
        c1_re_s3 <= c1_re_s2;
        c1_im_s3 <= c1_im_s2;
        c3r_r2_s3 <= c3_re_s2 * r2_s2;
        c3i_r2_s3 <= c3_im_s2 * r2_s2;
        r4_s3 <= r4_q_s2;
        c5_re_s3 <= c5_re_s2;
        c5_im_s3 <= c5_im_s2;

        enable_s4 <= enable_s3;
        i_s4 <= i_s3;
        q_s4 <= q_s3;
        c1_re_s4 <= {{(ACC_W-COEFF_W){c1_re_s3[COEFF_W-1]}}, c1_re_s3};
        c1_im_s4 <= {{(ACC_W-COEFF_W){c1_im_s3[COEFF_W-1]}}, c1_im_s3};
        c3r_r2_s4 <= c3r_r2_s3;
        c3i_r2_s4 <= c3i_r2_s3;
        c5r_r4_s4 <= c5_re_s3 * r4_s3;
        c5i_r4_s4 <= c5_im_s3 * r4_s3;

        enable_s5 <= enable_s4;
        i_s5 <= i_s4;
        q_s5 <= q_s4;
        gain_re_s5 <= gain_re_s4;
        gain_im_s5 <= gain_im_s4;

        enable_s6 <= enable_s5;
        in_i_wide_s6 <= {{(ACC_W-W){i_s5[W-1]}}, i_s5};
        in_q_wide_s6 <= {{(ACC_W-W){q_s5[W-1]}}, q_s5};
        i_gr_s6 <= i_s5 * gain_re_s5;
        q_gi_s6 <= q_s5 * gain_im_s5;
        i_gi_s6 <= i_s5 * gain_im_s5;
        q_gr_s6 <= q_s5 * gain_re_s5;

        enable_s7 <= enable_s6;
        dpd_i_wide_s7 <= (i_gr_s6 - q_gi_s6) >>> COEFF_FRAC;
        dpd_q_wide_s7 <= (i_gi_s6 + q_gr_s6) >>> COEFF_FRAC;
        in_i_wide_s7 <= in_i_wide_s6;
        in_q_wide_s7 <= in_q_wide_s6;

        if (valid_pipe[7]) begin
          i_out <= sat_i_val;
          q_out <= sat_q_val;
          if (sat_i | sat_q) begin
            saturation_count <= saturation_count + 32'd1;
          end
        end
        if (in_valid) begin
          sample_count <= sample_count + 32'd1;
        end
      end
    end
  end

endmodule

module dpd_sat_signed #(
  parameter integer IN_W = 48,
  parameter integer OUT_W = 16
) (
  input wire signed [IN_W-1:0] din,
  output reg signed [OUT_W-1:0] dout,
  output reg sat
);

  localparam signed [IN_W-1:0] MAX_VAL = ({{(IN_W-OUT_W+1){1'b0}}, {(OUT_W-1){1'b1}}});
  localparam signed [IN_W-1:0] MIN_VAL = -({{(IN_W-OUT_W){1'b0}}, 1'b1, {(OUT_W-1){1'b0}}});

  always @* begin
    if (din > MAX_VAL) begin
      dout = {1'b0, {(OUT_W-1){1'b1}}};
      sat = 1'b1;
    end else if (din < MIN_VAL) begin
      dout = {1'b1, {(OUT_W-1){1'b0}}};
      sat = 1'b1;
    end else begin
      dout = din[OUT_W-1:0];
      sat = 1'b0;
    end
  end

endmodule

`default_nettype wire
