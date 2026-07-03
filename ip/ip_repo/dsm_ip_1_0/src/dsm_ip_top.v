`timescale 1ns/1ps
`default_nettype none

module dsm_ip_top #(
  parameter integer W = 16,
  parameter integer RF_W = 16,
  parameter integer PHASE_W = 24,
  parameter integer LUT_AW = 10,
  parameter integer TW_W = 16,
  parameter integer ALGORITHM = 2,
  parameter integer DUC_MODE = 0,
  parameter integer CLK_FREQ_HZ = 100000000,
  parameter integer BB_SAMPLE_RATE_HZ = 3125000,
  parameter integer SIGNAL_BW_HZ = 2539062,
  parameter integer ACC_W_LP1 = 32,
  parameter integer ACC_W_LP2 = 40,
  parameter integer ACC_W_EF = 28,
  parameter integer ACC_W_MASH = 18,
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

  output wire dsm_valid,
  output wire i_bit,
  output wire q_bit,
  output wire signed [3:0] i_yout,
  output wire signed [3:0] q_yout,

  output wire rf_valid,
  output wire rf_bit,
  output wire signed [RF_W-1:0] rf_signed,
  output wire [PHASE_W-1:0] phase_acc_dbg
);

  dsm_ip_core #(
    .W(W),
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
    .IN_SHIFT(IN_SHIFT),
    .SATURATE(SATURATE[0]),
    .COEFF_W(COEFF_W),
    .B1_NUM(B1_NUM),
    .B2_NUM(B2_NUM),
    .COEFF_SHIFT(COEFF_SHIFT)
  ) u_core (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .cfg_phase_inc(cfg_phase_inc),
    .i_in(i_in),
    .q_in(q_in),
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

endmodule

`default_nettype wire
