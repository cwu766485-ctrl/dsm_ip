`timescale 1ns/1ps
`default_nettype none

module dsm_ip_top #(
  parameter integer W = 16,
  parameter integer DSM_OUT_W = 8,
  parameter integer RF_W = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW = 10,
  parameter integer TW_W = 16,
  parameter integer ALGORITHM = 2,
  parameter integer DUC_MODE = 0,
  parameter integer INTERP_MODE = 0,
  parameter integer INTERP_IMPL = 0,
  parameter integer CLK_FREQ_HZ = 100000000,
  parameter integer BB_SAMPLE_RATE_HZ = 3125000,
  parameter integer SIGNAL_BW_HZ = 2539062,
  parameter integer ACC_W_LP1 = 32,
  parameter integer ACC_W_LP2 = 20,
  parameter integer ACC_W_EF = 28,
  parameter integer ACC_W_MASH = 18,
  parameter integer ACC_W_MB = 16,
  parameter integer MB_Q_BITS = 4,
  parameter integer IN_SHIFT = 0,
  parameter integer SATURATE = 1,
  parameter integer COEFF_W = 8,
  parameter integer B1_NUM = 2,
  parameter integer B2_NUM = -1,
  parameter integer COEFF_SHIFT = 0
) (
  input wire clk,
  input wire rst_n,
  input wire in_valid,
  input wire [PHASE_W-1:0] cfg_phase_inc,
  input wire signed [W-1:0] i_in,
  input wire signed [W-1:0] q_in,

  output wire in_ready,
  output wire dsm_valid,
  output wire i_bit,
  output wire q_bit,
  output wire signed [DSM_OUT_W-1:0] i_yout,
  output wire signed [DSM_OUT_W-1:0] q_yout,

  output wire rf_valid,
  output wire rf_bit,
  output wire signed [RF_W-1:0] rf_signed,
  output wire [PHASE_W-1:0] phase_acc_dbg
);

  // DUC mode 3 is owned by this integration wrapper because it mixes the
  // full-precision interpolated I/Q stream before the one-bit BP DSM.
  localparam integer DUC_MODE_BP_EFDSM2 = 3;

  // TX datapath: optional interpolation followed by either the BP EFDSM2
  // IF route or the reusable DSM/DUC core.
  wire signed [W-1:0] interp_i;
  wire signed [W-1:0] interp_q;
  wire interp_valid;

  dsm_interp_frontend #(
    .W_IN(W),
    .W_OUT(W),
    .INTERP_MODE(INTERP_MODE),
    .INTERP_IMPL(INTERP_IMPL)
  ) u_interp_frontend (
    .clk(clk),
    .rst_n(rst_n),
    .enable(1'b1),
    .i_in(i_in),
    .q_in(q_in),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .i_out(interp_i),
    .q_out(interp_q),
    .out_valid(interp_valid),
    .out_ready(1'b1)
  );

  generate
    if (DUC_MODE == DUC_MODE_BP_EFDSM2) begin : g_bp_ef2_if
      // The BP route mixes the full-precision interpolated I/Q sample before
      // its one-bit quantizer.  It must not reuse the legacy low-pass DSM
      // followed by the one-bit Fs/4 merge.
      wire if_valid;
      wire signed [W-1:0] if_sample;
      wire [1:0] if_phase;

      tx_bp_if_top #(
        .W(W),
        .ACC_W(ACC_W_EF),
        .IN_SHIFT(IN_SHIFT),
        .SATURATE(SATURATE[0]),
        .BP_ALGORITHM(1)
      ) u_bp_ef2_if (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(interp_valid),
        .i_in(interp_i),
        .q_in(interp_q),
        .if_valid(if_valid),
        .if_sample(if_sample),
        .rf_valid(rf_valid),
        .rf_bit(rf_bit),
        .rf_signed(rf_signed),
        .if_phase(if_phase)
      );

      // The BP path has one real IF stream rather than Cartesian DSM lanes.
      assign dsm_valid = if_valid;
      assign i_bit = 1'b0;
      assign q_bit = 1'b0;
      assign i_yout = '0;
      assign q_yout = '0;
      assign phase_acc_dbg = {{(PHASE_W-2){1'b0}}, if_phase};
    end else begin : g_cartesian_dsm
      dsm_ip_core #(
        .W(W),
        .DSM_OUT_W(DSM_OUT_W),
        .RF_W(RF_W),
        .PHASE_W(PHASE_W),
        .LUT_AW(LUT_AW),
        .TW_W(TW_W),
        .ALGORITHM(ALGORITHM),
        .DUC_MODE(DUC_MODE),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BB_SAMPLE_RATE_HZ(BB_SAMPLE_RATE_HZ),
        .SIGNAL_BW_HZ(SIGNAL_BW_HZ),
        .ACC_W_LP1(ACC_W_LP1),
        .ACC_W_LP2(ACC_W_LP2),
        .ACC_W_EF(ACC_W_EF),
        .ACC_W_MASH(ACC_W_MASH),
        .ACC_W_MB(ACC_W_MB),
        .MB_Q_BITS(MB_Q_BITS),
        .IN_SHIFT(IN_SHIFT),
        .SATURATE(SATURATE[0]),
        .COEFF_W(COEFF_W),
        .B1_NUM(B1_NUM),
        .B2_NUM(B2_NUM),
        .COEFF_SHIFT(COEFF_SHIFT)
      ) u_core (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(interp_valid),
        .cfg_phase_inc(cfg_phase_inc),
        .i_in(interp_i),
        .q_in(interp_q),
        .dsm_valid(dsm_valid),
        .i_bit(i_bit),
        .q_bit(q_bit),
        .i_yout(i_yout),
        .q_yout(q_yout),
        .rf_valid(rf_valid),
        .rf_bit(rf_bit),
        .rf_signed(rf_signed),
        .phase_acc_dbg(phase_acc_dbg)
      );
    end
  endgenerate

endmodule

`default_nettype wire
