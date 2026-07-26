`timescale 1ns/1ps
`default_nettype none

module dpd_poly #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14,
  parameter integer POLY_ORDER = 5
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
  input wire signed [COEFF_W-1:0] c7_re,
  input wire signed [COEFF_W-1:0] c7_im,

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
  reg signed [COEFF_W-1:0] c7_re_s0;
  reg signed [COEFF_W-1:0] c7_im_s0;

  reg enable_s1;
  reg signed [W-1:0] i_s1;
  reg signed [W-1:0] q_s1;
  reg signed [COEFF_W-1:0] c1_re_s1;
  reg signed [COEFF_W-1:0] c1_im_s1;
  reg signed [COEFF_W-1:0] c3_re_s1;
  reg signed [COEFF_W-1:0] c3_im_s1;
  reg signed [COEFF_W-1:0] c5_re_s1;
  reg signed [COEFF_W-1:0] c5_im_s1;
  reg signed [COEFF_W-1:0] c7_re_s1;
  reg signed [COEFF_W-1:0] c7_im_s1;
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
  reg signed [COEFF_W-1:0] c7_re_s2;
  reg signed [COEFF_W-1:0] c7_im_s2;
  reg signed [PWR_W-1:0] r2_s2;

  reg enable_s3;
  reg signed [W-1:0] i_s3;
  reg signed [W-1:0] q_s3;
  reg signed [COEFF_W-1:0] c1_re_s3;
  reg signed [COEFF_W-1:0] c1_im_s3;
  reg signed [ACC_W-1:0] c3r_r2_s3;
  reg signed [ACC_W-1:0] c3i_r2_s3;
  reg signed [PWR_W-1:0] r4_s3;
  reg signed [PWR_W-1:0] r2_s3;
  reg signed [COEFF_W-1:0] c5_re_s3;
  reg signed [COEFF_W-1:0] c5_im_s3;
  reg signed [COEFF_W-1:0] c7_re_s3;
  reg signed [COEFF_W-1:0] c7_im_s3;

  reg enable_s4;
  reg signed [W-1:0] i_s4;
  reg signed [W-1:0] q_s4;
  reg signed [ACC_W-1:0] c1_re_s4;
  reg signed [ACC_W-1:0] c1_im_s4;
  reg signed [ACC_W-1:0] c3r_r2_s4;
  reg signed [ACC_W-1:0] c3i_r2_s4;
  reg signed [ACC_W-1:0] c5r_r4_s4;
  reg signed [ACC_W-1:0] c5i_r4_s4;
  reg signed [COEFF_W-1:0] c7_re_s4;
  reg signed [COEFF_W-1:0] c7_im_s4;
  reg signed [PWR_W-1:0] r6_s4;

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

`ifdef DPD_SIM_TRACE
  // Simulation-only transaction tags make fixed-point mismatches attributable
  // to the exact pipeline sample without changing the synthesized datapath.
  integer trace_next_tag;
  integer trace_tag_s0;
  integer trace_tag_s1;
  integer trace_tag_s2;
  integer trace_tag_s3;
  integer trace_tag_s4;
  integer trace_tag_s5;
  integer trace_tag_s6;
  integer trace_tag_s7;
  reg signed [ACC_W-1:0] trace_gain_re_s6;
  reg signed [ACC_W-1:0] trace_gain_im_s6;
  reg signed [ACC_W-1:0] trace_gain_re_s7;
  reg signed [ACC_W-1:0] trace_gain_im_s7;
`endif

  // Make every fixed-point multiplication width explicit.  Do not rely on
  // expression sizing rules when a narrow source operand is multiplied.
  wire signed [MUL_W-1:0] i_s0_ext = {{W{i_s0[W-1]}}, i_s0};
  wire signed [MUL_W-1:0] q_s0_ext = {{W{q_s0[W-1]}}, q_s0};
  wire signed [(2*MUL_W)-1:0] i_sq_full_s0 = i_s0_ext * i_s0_ext;
  wire signed [(2*MUL_W)-1:0] q_sq_full_s0 = q_s0_ext * q_s0_ext;

  wire signed [MUL_W+1:0] r2_full_s1 =
      {{2{i_sq_s1[MUL_W-1]}}, i_sq_s1} + {{2{q_sq_s1[MUL_W-1]}}, q_sq_s1};
  wire signed [PWR_W-1:0] r2_q_s1 = r2_full_s1 >>> R_FRAC;
  wire signed [(2*PWR_W)-1:0] r2_s2_ext = {{PWR_W{r2_s2[PWR_W-1]}}, r2_s2};
  wire signed [(4*PWR_W)-1:0] r4_prod_s2 = r2_s2_ext * r2_s2_ext;
  wire signed [(2*PWR_W)-1:0] r4_full_s2 = r4_prod_s2[(2*PWR_W)-1:0];
  wire signed [PWR_W-1:0] r4_q_s2 = r4_full_s2 >>> R_FRAC;
  wire signed [(2*PWR_W)-1:0] r4_s3_ext = {{PWR_W{r4_s3[PWR_W-1]}}, r4_s3};
  wire signed [(2*PWR_W)-1:0] r2_s3_ext = {{PWR_W{r2_s3[PWR_W-1]}}, r2_s3};
  wire signed [(4*PWR_W)-1:0] r6_prod_s3 = r4_s3_ext * r2_s3_ext;
  wire signed [(2*PWR_W)-1:0] r6_full_s3 = r6_prod_s3[(2*PWR_W)-1:0];
  wire signed [PWR_W-1:0] r6_q_s3 = r6_full_s3 >>> R_FRAC;
  wire signed [ACC_W-1:0] c3_re_s2_ext = {{(ACC_W-COEFF_W){c3_re_s2[COEFF_W-1]}}, c3_re_s2};
  wire signed [ACC_W-1:0] c3_im_s2_ext = {{(ACC_W-COEFF_W){c3_im_s2[COEFF_W-1]}}, c3_im_s2};
  wire signed [ACC_W-1:0] c5_re_s3_ext = {{(ACC_W-COEFF_W){c5_re_s3[COEFF_W-1]}}, c5_re_s3};
  wire signed [ACC_W-1:0] c5_im_s3_ext = {{(ACC_W-COEFF_W){c5_im_s3[COEFF_W-1]}}, c5_im_s3};
  wire signed [ACC_W-1:0] c7_re_s4_ext = {{(ACC_W-COEFF_W){c7_re_s4[COEFF_W-1]}}, c7_re_s4};
  wire signed [ACC_W-1:0] c7_im_s4_ext = {{(ACC_W-COEFF_W){c7_im_s4[COEFF_W-1]}}, c7_im_s4};
  wire signed [ACC_W-1:0] r2_s2_acc_ext = {{(ACC_W-PWR_W){r2_s2[PWR_W-1]}}, r2_s2};
  wire signed [ACC_W-1:0] r4_s3_acc_ext = {{(ACC_W-PWR_W){r4_s3[PWR_W-1]}}, r4_s3};
  wire signed [ACC_W-1:0] r6_s4_acc_ext = {{(ACC_W-PWR_W){r6_s4[PWR_W-1]}}, r6_s4};
  wire signed [(2*ACC_W)-1:0] c3r_r2_full_s2 = c3_re_s2_ext * r2_s2_acc_ext;
  wire signed [(2*ACC_W)-1:0] c3i_r2_full_s2 = c3_im_s2_ext * r2_s2_acc_ext;
  wire signed [(2*ACC_W)-1:0] c5r_r4_full_s3 = c5_re_s3_ext * r4_s3_acc_ext;
  wire signed [(2*ACC_W)-1:0] c5i_r4_full_s3 = c5_im_s3_ext * r4_s3_acc_ext;
  wire signed [(2*ACC_W)-1:0] c7r_r6_full_s4 = c7_re_s4_ext * r6_s4_acc_ext;
  wire signed [(2*ACC_W)-1:0] c7i_r6_full_s4 = c7_im_s4_ext * r6_s4_acc_ext;
  wire signed [ACC_W-1:0] c7r_r6_s4 = c7r_r6_full_s4[ACC_W-1:0];
  wire signed [ACC_W-1:0] c7i_r6_s4 = c7i_r6_full_s4[ACC_W-1:0];

  wire signed [ACC_W-1:0] i_s5_ext = {{(ACC_W-W){i_s5[W-1]}}, i_s5};
  wire signed [ACC_W-1:0] q_s5_ext = {{(ACC_W-W){q_s5[W-1]}}, q_s5};
  wire signed [(2*ACC_W)-1:0] i_gr_full_s5 = i_s5_ext * gain_re_s5;
  wire signed [(2*ACC_W)-1:0] q_gi_full_s5 = q_s5_ext * gain_im_s5;
  wire signed [(2*ACC_W)-1:0] i_gi_full_s5 = i_s5_ext * gain_im_s5;
  wire signed [(2*ACC_W)-1:0] q_gr_full_s5 = q_s5_ext * gain_re_s5;

  // A part-select and a ternary expression are unsigned by default in
  // Verilog.  Preserve signed Q2.14 gain terms explicitly before summing.
  wire signed [ACC_W-1:0] c3_gain_re_s4 = $signed(c3r_r2_s4) >>> R_FRAC;
  wire signed [ACC_W-1:0] c3_gain_im_s4 = $signed(c3i_r2_s4) >>> R_FRAC;
  wire signed [ACC_W-1:0] c5_gain_re_s4 = (POLY_ORDER >= 5) ?
      $signed(c5r_r4_s4 >>> R_FRAC) : $signed({ACC_W{1'b0}});
  wire signed [ACC_W-1:0] c5_gain_im_s4 = (POLY_ORDER >= 5) ?
      $signed(c5i_r4_s4 >>> R_FRAC) : $signed({ACC_W{1'b0}});
  wire signed [ACC_W-1:0] c7_gain_re_s4 = (POLY_ORDER >= 7) ?
      $signed(c7r_r6_s4 >>> R_FRAC) : $signed({ACC_W{1'b0}});
  wire signed [ACC_W-1:0] c7_gain_im_s4 = (POLY_ORDER >= 7) ?
      $signed(c7i_r6_s4 >>> R_FRAC) : $signed({ACC_W{1'b0}});
  wire signed [ACC_W-1:0] gain_re_s4 = $signed(c1_re_s4) +
      $signed(c3_gain_re_s4) + $signed(c5_gain_re_s4) + $signed(c7_gain_re_s4);
  wire signed [ACC_W-1:0] gain_im_s4 = $signed(c1_im_s4) +
      $signed(c3_gain_im_s4) + $signed(c5_gain_im_s4) + $signed(c7_gain_im_s4);

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
`ifdef DPD_SIM_TRACE
      trace_next_tag <= 0;
      trace_tag_s0 <= -1;
      trace_tag_s1 <= -1;
      trace_tag_s2 <= -1;
      trace_tag_s3 <= -1;
      trace_tag_s4 <= -1;
      trace_tag_s5 <= -1;
      trace_tag_s6 <= -1;
      trace_tag_s7 <= -1;
      trace_gain_re_s6 <= '0;
      trace_gain_im_s6 <= '0;
      trace_gain_re_s7 <= '0;
      trace_gain_im_s7 <= '0;
`endif
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
        c7_re_s0 <= c7_re;
        c7_im_s0 <= c7_im;

`ifdef DPD_SIM_TRACE
        if (in_valid) begin
          trace_tag_s0 <= trace_next_tag;
          trace_next_tag <= trace_next_tag + 1;
        end else begin
          trace_tag_s0 <= -1;
        end
        trace_tag_s1 <= trace_tag_s0;
        trace_tag_s2 <= trace_tag_s1;
        trace_tag_s3 <= trace_tag_s2;
        trace_tag_s4 <= trace_tag_s3;
        trace_tag_s5 <= trace_tag_s4;
        trace_tag_s6 <= trace_tag_s5;
        trace_tag_s7 <= trace_tag_s6;
`endif

        enable_s1 <= enable_s0;
        i_s1 <= i_s0;
        q_s1 <= q_s0;
        c1_re_s1 <= c1_re_s0;
        c1_im_s1 <= c1_im_s0;
        c3_re_s1 <= c3_re_s0;
        c3_im_s1 <= c3_im_s0;
        c5_re_s1 <= c5_re_s0;
        c5_im_s1 <= c5_im_s0;
        c7_re_s1 <= c7_re_s0;
        c7_im_s1 <= c7_im_s0;
        i_sq_s1 <= i_sq_full_s0[MUL_W-1:0];
        q_sq_s1 <= q_sq_full_s0[MUL_W-1:0];

        enable_s2 <= enable_s1;
        i_s2 <= i_s1;
        q_s2 <= q_s1;
        c1_re_s2 <= c1_re_s1;
        c1_im_s2 <= c1_im_s1;
        c3_re_s2 <= c3_re_s1;
        c3_im_s2 <= c3_im_s1;
        c5_re_s2 <= c5_re_s1;
        c5_im_s2 <= c5_im_s1;
        c7_re_s2 <= c7_re_s1;
        c7_im_s2 <= c7_im_s1;
        r2_s2 <= r2_q_s1;

        enable_s3 <= enable_s2;
        i_s3 <= i_s2;
        q_s3 <= q_s2;
        c1_re_s3 <= c1_re_s2;
        c1_im_s3 <= c1_im_s2;
        c3r_r2_s3 <= c3r_r2_full_s2[ACC_W-1:0];
        c3i_r2_s3 <= c3i_r2_full_s2[ACC_W-1:0];
        r4_s3 <= r4_q_s2;
        r2_s3 <= r2_s2;
        c5_re_s3 <= c5_re_s2;
        c5_im_s3 <= c5_im_s2;
        c7_re_s3 <= c7_re_s2;
        c7_im_s3 <= c7_im_s2;

        enable_s4 <= enable_s3;
        i_s4 <= i_s3;
        q_s4 <= q_s3;
        c1_re_s4 <= {{(ACC_W-COEFF_W){c1_re_s3[COEFF_W-1]}}, c1_re_s3};
        c1_im_s4 <= {{(ACC_W-COEFF_W){c1_im_s3[COEFF_W-1]}}, c1_im_s3};
        c3r_r2_s4 <= c3r_r2_s3;
        c3i_r2_s4 <= c3i_r2_s3;
        c5r_r4_s4 <= c5r_r4_full_s3[ACC_W-1:0];
        c5i_r4_s4 <= c5i_r4_full_s3[ACC_W-1:0];
        c7_re_s4 <= c7_re_s3;
        c7_im_s4 <= c7_im_s3;
        r6_s4 <= r6_q_s3;

        enable_s5 <= enable_s4;
        i_s5 <= i_s4;
        q_s5 <= q_s4;
        gain_re_s5 <= gain_re_s4;
        gain_im_s5 <= gain_im_s4;

        enable_s6 <= enable_s5;
        in_i_wide_s6 <= {{(ACC_W-W){i_s5[W-1]}}, i_s5};
        in_q_wide_s6 <= {{(ACC_W-W){q_s5[W-1]}}, q_s5};
        i_gr_s6 <= i_gr_full_s5[ACC_W-1:0];
        q_gi_s6 <= q_gi_full_s5[ACC_W-1:0];
        i_gi_s6 <= i_gi_full_s5[ACC_W-1:0];
        q_gr_s6 <= q_gr_full_s5[ACC_W-1:0];

`ifdef DPD_SIM_TRACE
        trace_gain_re_s6 <= gain_re_s5;
        trace_gain_im_s6 <= gain_im_s5;
`endif

        enable_s7 <= enable_s6;
        dpd_i_wide_s7 <= (i_gr_s6 - q_gi_s6) >>> COEFF_FRAC;
        dpd_q_wide_s7 <= (i_gi_s6 + q_gr_s6) >>> COEFF_FRAC;
        in_i_wide_s7 <= in_i_wide_s6;
        in_q_wide_s7 <= in_q_wide_s6;

`ifdef DPD_SIM_TRACE
        trace_gain_re_s7 <= trace_gain_re_s6;
        trace_gain_im_s7 <= trace_gain_im_s6;
`endif

        if (valid_pipe[7]) begin
          i_out <= sat_i_val;
          q_out <= sat_q_val;
          if (sat_i | sat_q) begin
            saturation_count <= saturation_count + 32'd1;
          end
`ifdef DPD_SIM_TRACE
          if (trace_tag_s7 < 12) begin
            $display("DPD_TRACE n=%0d gain=(%0d,%0d) raw=(%0d,%0d) out=(%0d,%0d)",
                     trace_tag_s7, trace_gain_re_s7, trace_gain_im_s7,
                     sel_i_wide, sel_q_wide, sat_i_val, sat_q_val);
          end
`endif
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
