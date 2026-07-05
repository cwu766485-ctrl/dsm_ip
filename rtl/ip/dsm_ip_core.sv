`timescale 1ns/1ps
`default_nettype none

// Reusable streaming DSM transmitter IP core.
//
// ALGORITHM:
//   0 LPDSM, 1 LPDSM2, 2 EFDSM, 3 EFDSM2, 4 MASH11, 5 MASH111, 6 MASH22
//
// The input and output sample rate is the IP clock rate. DUC_MODE selects the
// real IF/RF output mixer:
//   0 fixed Fs/4 mixer
//   1 NCO mixer, fc = cfg_phase_inc / 2^PHASE_W * clk
module dsm_ip_core #(
  parameter int W = 16,
  parameter int DSM_OUT_W = 8,
  parameter int RF_W = 16,
  parameter int PHASE_W = 24,
  parameter int LUT_AW = 10,
  parameter int TW_W = 16,
  parameter int ALGORITHM = 2,
  parameter int DUC_MODE = 0,
  parameter int CLK_FREQ_HZ = 100000000,
  parameter int BB_SAMPLE_RATE_HZ = 3125000,
  parameter int SIGNAL_BW_HZ = 2539062,
  parameter int ACC_W_LP1 = 32,
  parameter int ACC_W_LP2 = 20,
  parameter int ACC_W_EF = 28,
  parameter int ACC_W_MASH = 18,
  parameter int ACC_W_MB = 16,
  parameter int MB_Q_BITS = 4,
  parameter int IN_SHIFT = 0,
  parameter bit SATURATE = 1'b1,
  parameter int COEFF_W = 8,
  parameter int signed B1_NUM = 2,
  parameter int signed B2_NUM = -1,
  parameter int COEFF_SHIFT = 0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic [PHASE_W-1:0] cfg_phase_inc,
  input  wire logic signed [W-1:0] i_in,
  input  wire logic signed [W-1:0] q_in,

  output logic dsm_valid,
  output logic i_bit,
  output logic q_bit,
  output logic signed [DSM_OUT_W-1:0] i_yout,
  output logic signed [DSM_OUT_W-1:0] q_yout,

  output logic rf_valid,
  output logic rf_bit,
  output logic signed [RF_W-1:0] rf_signed,
  output logic [PHASE_W-1:0] phase_acc_dbg
);

  localparam logic signed [DSM_OUT_W-1:0] DSM_POS_ONE = {{(DSM_OUT_W-1){1'b0}}, 1'b1};
  localparam logic signed [DSM_OUT_W-1:0] DSM_NEG_ONE = -DSM_POS_ONE;

  assign dsm_valid = in_valid;

  generate
    if (ALGORITHM == 0) begin : g_lp1
      logic signed [W-1:0] yi_signed, yq_signed;
      dsm_core #(.W_IN(W), .ACC_W(ACC_W_LP1), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y_signed(yi_signed), .v_state());
      dsm_core #(.W_IN(W), .ACC_W(ACC_W_LP1), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y_signed(yq_signed), .v_state());
      assign i_yout = i_bit ? DSM_POS_ONE : DSM_NEG_ONE;
      assign q_yout = q_bit ? DSM_POS_ONE : DSM_NEG_ONE;
    end else if (ALGORITHM == 1) begin : g_lp2
      logic signed [W-1:0] yi_signed, yq_signed;
      dsm_core_dsm2 #(.W_IN(W), .ACC_W(ACC_W_LP2), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y_signed(yi_signed), .v1_state(), .v2_state());
      dsm_core_dsm2 #(.W_IN(W), .ACC_W(ACC_W_LP2), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y_signed(yq_signed), .v1_state(), .v2_state());
      assign i_yout = i_bit ? DSM_POS_ONE : DSM_NEG_ONE;
      assign q_yout = q_bit ? DSM_POS_ONE : DSM_NEG_ONE;
    end else if (ALGORITHM == 2) begin : g_ef1
      logic signed [W-1:0] yi_signed, yq_signed;
      dsm_core_ef1 #(.W_IN(W), .ACC_W(ACC_W_EF), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y_signed(yi_signed), .v_state());
      dsm_core_ef1 #(.W_IN(W), .ACC_W(ACC_W_EF), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y_signed(yq_signed), .v_state());
      assign i_yout = i_bit ? DSM_POS_ONE : DSM_NEG_ONE;
      assign q_yout = q_bit ? DSM_POS_ONE : DSM_NEG_ONE;
    end else if (ALGORITHM == 3) begin : g_ef2
      logic signed [W-1:0] yi_signed, yq_signed;
      dsm_core_ef2 #(.W_IN(W), .ACC_W(ACC_W_EF), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y_signed(yi_signed), .v_state());
      dsm_core_ef2 #(.W_IN(W), .ACC_W(ACC_W_EF), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y_signed(yq_signed), .v_state());
      assign i_yout = i_bit ? DSM_POS_ONE : DSM_NEG_ONE;
      assign q_yout = q_bit ? DSM_POS_ONE : DSM_NEG_ONE;
    end else if (ALGORITHM == 4) begin : g_mash11
      logic y1i, y2i, y1q, y2q;
      logic signed [2:0] yi3, yq3;
      dsm_core_mash11 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y1_bit(y1i), .y2_bit(y2i), .y_mash_signed(yi3), .v1_state(), .v2_state());
      dsm_core_mash11 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y1_bit(y1q), .y2_bit(y2q), .y_mash_signed(yq3), .v1_state(), .v2_state());
      assign i_yout = {{(DSM_OUT_W-3){yi3[2]}}, yi3};
      assign q_yout = {{(DSM_OUT_W-3){yq3[2]}}, yq3};
    end else if (ALGORITHM == 5) begin : g_mash111
      logic y1i, y2i, y3i, y1q, y2q, y3q;
      logic signed [3:0] yi4, yq4;
      dsm_core_mash111 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y1_bit(y1i), .y2_bit(y2i), .y3_bit(y3i),
        .y_mash_signed(yi4), .v1_state(), .v2_state(), .v3_state());
      dsm_core_mash111 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y1_bit(y1q), .y2_bit(y2q), .y3_bit(y3q),
        .y_mash_signed(yq4), .v1_state(), .v2_state(), .v3_state());
      assign i_yout = {{(DSM_OUT_W-4){yi4[3]}}, yi4};
      assign q_yout = {{(DSM_OUT_W-4){yq4[3]}}, yq4};
    end else if (ALGORITHM == 6) begin : g_mash22
      logic y1i, y2i, y1q, y2q;
      logic signed [3:0] yi4, yq4;
      dsm_core_mash22 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in),
        .y_bit(i_bit), .y1_bit(y1i), .y2_bit(y2i), .y_mash_signed(yi4), .v1_state(), .v2_state());
      dsm_core_mash22 #(.W_IN(W), .ACC_W(ACC_W_MASH), .IN_SHIFT(IN_SHIFT), .SATURATE(SATURATE),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in),
        .y_bit(q_bit), .y1_bit(y1q), .y2_bit(y2q), .y_mash_signed(yq4), .v1_state(), .v2_state());
      assign i_yout = {{(DSM_OUT_W-4){yi4[3]}}, yi4};
      assign q_yout = {{(DSM_OUT_W-4){yq4[3]}}, yq4};
    end else if (ALGORITHM == 7) begin : g_mb_lp1
      dsm_core_multibit_lp1 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_lp1 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else if (ALGORITHM == 8) begin : g_mb_lp2
      dsm_core_multibit_lp2 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_lp2 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else if (ALGORITHM == 9) begin : g_mb_ef1
      dsm_core_multibit_ef1 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_ef1 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else if (ALGORITHM == 10) begin : g_mb_ef2
      dsm_core_multibit_ef2 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_ef2 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else if (ALGORITHM == 11) begin : g_mb_mash11
      dsm_core_multibit_mash11 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_mash11 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else if (ALGORITHM == 12) begin : g_mb_mash111
      dsm_core_multibit_mash111 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_mash111 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end else begin : g_mb_mash22
      dsm_core_multibit_mash22 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_i (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(i_in), .y_bit(i_bit), .y_code(i_yout), .v1_state(), .v2_state());
      dsm_core_multibit_mash22 #(.W_IN(W), .ACC_W(ACC_W_MB), .OUT_W(DSM_OUT_W), .Q_BITS(MB_Q_BITS), .IN_SHIFT(IN_SHIFT), .SATURATE(1'b0),
        .COEFF_W(COEFF_W), .B1_NUM(B1_NUM), .B2_NUM(B2_NUM), .COEFF_SHIFT(COEFF_SHIFT)) u_q (
        .clk(clk), .rst_n(rst_n), .enable(in_valid), .x_in(q_in), .y_bit(q_bit), .y_code(q_yout), .v1_state(), .v2_state());
    end
  endgenerate

  generate
    if (DUC_MODE == 0) begin : g_fixed_fs4_duc
      logic [1:0] fs4_phase;

      if (ALGORITHM < 4) begin : g_1bit_fs4
        duc_fs4_merge #(.W_OUT(RF_W)) u_duc (
          .clk(clk),
          .rst_n(rst_n),
          .in_valid(in_valid),
          .i_bit(i_bit),
          .q_bit(q_bit),
          .rf_valid(rf_valid),
          .rf_bit(rf_bit),
          .rf_signed(rf_signed),
          .phase(fs4_phase)
        );
      end else begin : g_multibit_fs4
        duc_fs4_merge_signed #(.W_IN(DSM_OUT_W), .W_OUT(RF_W)) u_duc (
          .clk(clk),
          .rst_n(rst_n),
          .in_valid(in_valid),
          .i_data(i_yout),
          .q_data(q_yout),
          .rf_valid(rf_valid),
          .rf_signed(rf_signed),
          .phase(fs4_phase)
        );
        assign rf_bit = ~rf_signed[RF_W-1];
      end

      assign phase_acc_dbg = {{(PHASE_W-2){1'b0}}, fs4_phase};
    end else begin : g_nco_duc
      duc_nco_mix_signed #(
        .W_IN(DSM_OUT_W),
        .W_OUT(RF_W),
        .PHASE_W(PHASE_W),
        .LUT_AW(LUT_AW),
        .TW_W(TW_W)
      ) u_duc (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(in_valid),
        .phase_inc(cfg_phase_inc),
        .i_data(i_yout),
        .q_data(q_yout),
        .rf_valid(rf_valid),
        .rf_signed(rf_signed),
        .phase_acc_dbg(phase_acc_dbg)
      );

      assign rf_bit = ~rf_signed[RF_W-1];
    end
  endgenerate

endmodule

`default_nettype wire
