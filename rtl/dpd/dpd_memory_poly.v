`timescale 1ns/1ps
`default_nettype none

module dpd_memory_poly #(
  parameter integer W = 16,
  parameter integer COEFF_W = 16,
  parameter integer COEFF_FRAC = 14,
  parameter integer MAX_TAPS = 4,
  // When set, each tap window is supplied by a vector wrapper.  This is
  // required for a packed stream: lane k must see samples k, k-1, ... rather
  // than the history of lane k from preceding words.
  parameter integer USE_EXTERNAL_TAPS = 0
) (
  input wire clk,
  input wire rst_n,
  input wire [2:0] active_taps,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c1_re,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c1_im,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c3_re,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c3_im,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c5_re,
  input wire signed [(MAX_TAPS*COEFF_W)-1:0] c5_im,
  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,
  input wire signed [(MAX_TAPS*W)-1:0] i_tap_vec,
  input wire signed [(MAX_TAPS*W)-1:0] q_tap_vec,
  input wire in_valid,
  output wire in_ready,
  output wire signed [W-1:0] i_out,
  output wire signed [W-1:0] q_out,
  output wire out_valid,
  input wire out_ready,
  output reg [31:0] sample_count,
  output reg [31:0] saturation_count
);

  localparam integer R_FRAC = W - 1;
  localparam integer MUL_W = 2 * W;
  localparam integer PWR_W = 32;
  localparam integer ACC_W = 64;
  // The extra register after the complex products gives Vivado a dedicated
  // DSP output stage before the subtract/add and Q2.14 rescale stage.
  // Stage the four-tap reduction as a balanced registered tree.  This changes
  // latency only; arithmetic, rounding, saturation and sample ordering remain
  // identical to the scalar fixed-point model.
  localparam integer PIPE_STAGES = 11;
  // Keep a legal declaration for the compile-time one-tap configuration.
  localparam integer HISTORY_TAPS = (MAX_TAPS > 1) ? (MAX_TAPS - 1) : 1;

  reg signed [W-1:0] i_history [0:HISTORY_TAPS-1];
  reg signed [W-1:0] q_history [0:HISTORY_TAPS-1];
  reg [PIPE_STAGES-1:0] valid_pipe;

  reg signed [W-1:0] i_s0 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_re_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_im_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_re_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_im_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_re_s0 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_im_s0 [0:MAX_TAPS-1];
  reg tap_enable_s0 [0:MAX_TAPS-1];

  reg signed [W-1:0] i_s1 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_re_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_im_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_re_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_im_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_re_s1 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_im_s1 [0:MAX_TAPS-1];
  reg signed [MUL_W-1:0] i_sq_s1 [0:MAX_TAPS-1];
  reg signed [MUL_W-1:0] q_sq_s1 [0:MAX_TAPS-1];
  reg tap_enable_s1 [0:MAX_TAPS-1];

  reg signed [W-1:0] i_s2 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_re_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_im_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_re_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c3_im_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_re_s2 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_im_s2 [0:MAX_TAPS-1];
  reg signed [PWR_W-1:0] r2_s2 [0:MAX_TAPS-1];
  reg tap_enable_s2 [0:MAX_TAPS-1];

  reg signed [W-1:0] i_s3 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s3 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_re_s3 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c1_im_s3 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_re_s3 [0:MAX_TAPS-1];
  reg signed [COEFF_W-1:0] c5_im_s3 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c3r_r2_s3 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c3i_r2_s3 [0:MAX_TAPS-1];
  reg signed [PWR_W-1:0] r4_s3 [0:MAX_TAPS-1];
  reg tap_enable_s3 [0:MAX_TAPS-1];

  reg signed [W-1:0] i_s4 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c1_re_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c1_im_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c3r_r2_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c3i_r2_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c5r_r4_s4 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] c5i_r4_s4 [0:MAX_TAPS-1];
  reg tap_enable_s4 [0:MAX_TAPS-1];

  reg signed [W-1:0] i_s5 [0:MAX_TAPS-1];
  reg signed [W-1:0] q_s5 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] gain_re_s5 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] gain_im_s5 [0:MAX_TAPS-1];
  reg tap_enable_s5 [0:MAX_TAPS-1];

  reg signed [ACC_W-1:0] i_gr_s6 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] q_gi_s6 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] i_gi_s6 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] q_gr_s6 [0:MAX_TAPS-1];
  reg tap_enable_s6 [0:MAX_TAPS-1];

  reg signed [ACC_W-1:0] i_gr_s7 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] q_gi_s7 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] i_gi_s7 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] q_gr_s7 [0:MAX_TAPS-1];
  reg tap_enable_s7 [0:MAX_TAPS-1];

  reg signed [ACC_W-1:0] term_i_s8 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] term_q_s8 [0:MAX_TAPS-1];
  reg signed [ACC_W-1:0] sum_i_pair0_s8;
  reg signed [ACC_W-1:0] sum_q_pair0_s8;
  reg signed [ACC_W-1:0] sum_i_pair1_s8;
  reg signed [ACC_W-1:0] sum_q_pair1_s8;
  reg signed [ACC_W-1:0] sum_i_pair0_comb;
  reg signed [ACC_W-1:0] sum_q_pair0_comb;
  reg signed [ACC_W-1:0] sum_i_pair1_comb;
  reg signed [ACC_W-1:0] sum_q_pair1_comb;
  reg signed [ACC_W-1:0] sum_i_s9;
  reg signed [ACC_W-1:0] sum_q_s9;
  wire signed [(2*PWR_W)-1:0] r4_full_s2 [0:MAX_TAPS-1];

  wire pipe_ce = out_ready | !valid_pipe[PIPE_STAGES-1];
  wire sat_i;
  wire sat_q;
  wire signed [W-1:0] sat_i_val;
  wire signed [W-1:0] sat_q_val;

  assign in_ready = pipe_ce;
  assign out_valid = valid_pipe[PIPE_STAGES-1];
  assign i_out = sat_i_val;
  assign q_out = sat_q_val;

  function signed [ACC_W-1:0] shift_acc_rfrac;
    input signed [ACC_W-1:0] value;
    begin
      shift_acc_rfrac = value >>> R_FRAC;
    end
  endfunction

  function signed [ACC_W-1:0] shift_acc_coeff;
    input signed [ACC_W-1:0] value;
    begin
      shift_acc_coeff = value >>> COEFF_FRAC;
    end
  endfunction

  genvar product_tap;
  generate
    for (product_tap = 0; product_tap < MAX_TAPS; product_tap = product_tap + 1) begin : g_r4_product
      assign r4_full_s2[product_tap] = r2_s2[product_tap] * r2_s2[product_tap];
    end
  endgenerate

  dpd_sat_signed #(.IN_W(ACC_W), .OUT_W(W)) u_sat_i (
    .din(sum_i_s9), .dout(sat_i_val), .sat(sat_i)
  );
  dpd_sat_signed #(.IN_W(ACC_W), .OUT_W(W)) u_sat_q (
    .din(sum_q_s9), .dout(sat_q_val), .sat(sat_q)
  );

  integer comb_tap;
  always @* begin
    sum_i_pair0_comb = {ACC_W{1'b0}};
    sum_q_pair0_comb = {ACC_W{1'b0}};
    sum_i_pair1_comb = {ACC_W{1'b0}};
    sum_q_pair1_comb = {ACC_W{1'b0}};
    for (comb_tap = 0; comb_tap < MAX_TAPS; comb_tap = comb_tap + 1) begin
      if (comb_tap < ((MAX_TAPS + 1) / 2)) begin
        sum_i_pair0_comb = sum_i_pair0_comb + term_i_s8[comb_tap];
        sum_q_pair0_comb = sum_q_pair0_comb + term_q_s8[comb_tap];
      end else begin
        sum_i_pair1_comb = sum_i_pair1_comb + term_i_s8[comb_tap];
        sum_q_pair1_comb = sum_q_pair1_comb + term_q_s8[comb_tap];
      end
    end
  end

  integer tap;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_pipe <= {PIPE_STAGES{1'b0}};
      sample_count <= 32'd0;
      saturation_count <= 32'd0;
      sum_i_pair0_s8 <= {ACC_W{1'b0}};
      sum_q_pair0_s8 <= {ACC_W{1'b0}};
      sum_i_pair1_s8 <= {ACC_W{1'b0}};
      sum_q_pair1_s8 <= {ACC_W{1'b0}};
      sum_i_s9 <= {ACC_W{1'b0}};
      sum_q_s9 <= {ACC_W{1'b0}};
      for (tap = 0; tap < MAX_TAPS-1; tap = tap + 1) begin
        i_history[tap] <= {W{1'b0}};
        q_history[tap] <= {W{1'b0}};
      end
      for (tap = 0; tap < MAX_TAPS; tap = tap + 1) begin
        tap_enable_s0[tap] <= 1'b0;
        tap_enable_s1[tap] <= 1'b0;
        tap_enable_s2[tap] <= 1'b0;
        tap_enable_s3[tap] <= 1'b0;
        tap_enable_s4[tap] <= 1'b0;
        tap_enable_s5[tap] <= 1'b0;
        tap_enable_s6[tap] <= 1'b0;
        tap_enable_s7[tap] <= 1'b0;
        term_i_s8[tap] <= {ACC_W{1'b0}};
        term_q_s8[tap] <= {ACC_W{1'b0}};
      end
    end else if (pipe_ce) begin
      valid_pipe <= {valid_pipe[PIPE_STAGES-2:0], in_valid};
      sum_i_pair0_s8 <= sum_i_pair0_comb;
      sum_q_pair0_s8 <= sum_q_pair0_comb;
      sum_i_pair1_s8 <= sum_i_pair1_comb;
      sum_q_pair1_s8 <= sum_q_pair1_comb;
      sum_i_s9 <= sum_i_pair0_s8 + sum_i_pair1_s8;
      sum_q_s9 <= sum_q_pair0_s8 + sum_q_pair1_s8;

      for (tap = 0; tap < MAX_TAPS; tap = tap + 1) begin
        if (USE_EXTERNAL_TAPS != 0) begin
          i_s0[tap] <= i_tap_vec[(tap*W) +: W];
          q_s0[tap] <= q_tap_vec[(tap*W) +: W];
        end else if (tap == 0) begin
          i_s0[tap] <= i_in;
          q_s0[tap] <= q_in;
        end else begin
          i_s0[tap] <= i_history[tap-1];
          q_s0[tap] <= q_history[tap-1];
        end
        c1_re_s0[tap] <= c1_re[(tap*COEFF_W) +: COEFF_W];
        c1_im_s0[tap] <= c1_im[(tap*COEFF_W) +: COEFF_W];
        c3_re_s0[tap] <= c3_re[(tap*COEFF_W) +: COEFF_W];
        c3_im_s0[tap] <= c3_im[(tap*COEFF_W) +: COEFF_W];
        c5_re_s0[tap] <= c5_re[(tap*COEFF_W) +: COEFF_W];
        c5_im_s0[tap] <= c5_im[(tap*COEFF_W) +: COEFF_W];
        tap_enable_s0[tap] <= in_valid && (tap < active_taps);

        i_s1[tap] <= i_s0[tap];
        q_s1[tap] <= q_s0[tap];
        c1_re_s1[tap] <= c1_re_s0[tap];
        c1_im_s1[tap] <= c1_im_s0[tap];
        c3_re_s1[tap] <= c3_re_s0[tap];
        c3_im_s1[tap] <= c3_im_s0[tap];
        c5_re_s1[tap] <= c5_re_s0[tap];
        c5_im_s1[tap] <= c5_im_s0[tap];
        i_sq_s1[tap] <= i_s0[tap] * i_s0[tap];
        q_sq_s1[tap] <= q_s0[tap] * q_s0[tap];
        tap_enable_s1[tap] <= tap_enable_s0[tap];

        i_s2[tap] <= i_s1[tap];
        q_s2[tap] <= q_s1[tap];
        c1_re_s2[tap] <= c1_re_s1[tap];
        c1_im_s2[tap] <= c1_im_s1[tap];
        c3_re_s2[tap] <= c3_re_s1[tap];
        c3_im_s2[tap] <= c3_im_s1[tap];
        c5_re_s2[tap] <= c5_re_s1[tap];
        c5_im_s2[tap] <= c5_im_s1[tap];
        r2_s2[tap] <= $signed({{2{i_sq_s1[tap][MUL_W-1]}}, i_sq_s1[tap]} +
                              {{2{q_sq_s1[tap][MUL_W-1]}}, q_sq_s1[tap]}) >>> R_FRAC;
        tap_enable_s2[tap] <= tap_enable_s1[tap];

        i_s3[tap] <= i_s2[tap];
        q_s3[tap] <= q_s2[tap];
        c1_re_s3[tap] <= c1_re_s2[tap];
        c1_im_s3[tap] <= c1_im_s2[tap];
        c5_re_s3[tap] <= c5_re_s2[tap];
        c5_im_s3[tap] <= c5_im_s2[tap];
        c3r_r2_s3[tap] <= c3_re_s2[tap] * r2_s2[tap];
        c3i_r2_s3[tap] <= c3_im_s2[tap] * r2_s2[tap];
        r4_s3[tap] <= $signed(r4_full_s2[tap]) >>> R_FRAC;
        tap_enable_s3[tap] <= tap_enable_s2[tap];

        i_s4[tap] <= i_s3[tap];
        q_s4[tap] <= q_s3[tap];
        c1_re_s4[tap] <= {{(ACC_W-COEFF_W){c1_re_s3[tap][COEFF_W-1]}}, c1_re_s3[tap]};
        c1_im_s4[tap] <= {{(ACC_W-COEFF_W){c1_im_s3[tap][COEFF_W-1]}}, c1_im_s3[tap]};
        c3r_r2_s4[tap] <= c3r_r2_s3[tap];
        c3i_r2_s4[tap] <= c3i_r2_s3[tap];
        c5r_r4_s4[tap] <= c5_re_s3[tap] * r4_s3[tap];
        c5i_r4_s4[tap] <= c5_im_s3[tap] * r4_s3[tap];
        tap_enable_s4[tap] <= tap_enable_s3[tap];

        i_s5[tap] <= i_s4[tap];
        q_s5[tap] <= q_s4[tap];
        gain_re_s5[tap] <= c1_re_s4[tap] +
                           shift_acc_rfrac(c3r_r2_s4[tap]) +
                           shift_acc_rfrac(c5r_r4_s4[tap]);
        gain_im_s5[tap] <= c1_im_s4[tap] +
                           shift_acc_rfrac(c3i_r2_s4[tap]) +
                           shift_acc_rfrac(c5i_r4_s4[tap]);
        tap_enable_s5[tap] <= tap_enable_s4[tap];

        i_gr_s6[tap] <= i_s5[tap] * gain_re_s5[tap];
        q_gi_s6[tap] <= q_s5[tap] * gain_im_s5[tap];
        i_gi_s6[tap] <= i_s5[tap] * gain_im_s5[tap];
        q_gr_s6[tap] <= q_s5[tap] * gain_re_s5[tap];
        tap_enable_s6[tap] <= tap_enable_s5[tap];

        i_gr_s7[tap] <= i_gr_s6[tap];
        q_gi_s7[tap] <= q_gi_s6[tap];
        i_gi_s7[tap] <= i_gi_s6[tap];
        q_gr_s7[tap] <= q_gr_s6[tap];
        tap_enable_s7[tap] <= tap_enable_s6[tap];

        term_i_s8[tap] <= tap_enable_s7[tap] ?
                          shift_acc_coeff(i_gr_s7[tap] - q_gi_s7[tap]) :
                          {ACC_W{1'b0}};
        term_q_s8[tap] <= tap_enable_s7[tap] ?
                          shift_acc_coeff(i_gi_s7[tap] + q_gr_s7[tap]) :
                          {ACC_W{1'b0}};
      end

      if (in_valid) begin
        i_history[0] <= i_in;
        q_history[0] <= q_in;
        for (tap = 1; tap < MAX_TAPS-1; tap = tap + 1) begin
          i_history[tap] <= i_history[tap-1];
          q_history[tap] <= q_history[tap-1];
        end
        sample_count <= sample_count + 32'd1;
      end
      if (valid_pipe[PIPE_STAGES-1] && (sat_i || sat_q)) begin
        saturation_count <= saturation_count + 32'd1;
      end
    end
  end

endmodule

`default_nettype wire
