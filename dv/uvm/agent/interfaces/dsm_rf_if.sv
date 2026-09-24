`timescale 1ns/1ps

interface dsm_rf_if #(parameter int DSM_OUT_W = 8, parameter int RF_W = 16,
                      parameter int PHASE_W = 24) (input logic aclk, input logic aresetn);
  logic dsm_valid;
  logic i_bit;
  logic q_bit;
  logic signed [DSM_OUT_W-1:0] i_yout;
  logic signed [DSM_OUT_W-1:0] q_yout;
  logic rf_valid;
  logic rf_bit;
  logic signed [RF_W-1:0] rf_signed;
  logic [PHASE_W-1:0] phase_acc_dbg;
  logic obs_irq;
endinterface
