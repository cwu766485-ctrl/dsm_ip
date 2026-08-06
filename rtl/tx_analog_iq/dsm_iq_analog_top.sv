//------------------------------------------------------------------------------
// Analog-IQ transmitter route wrapper.
//
// This route deliberately has no digital real-IF/RF output.  It exposes the
// low-pass one-bit I/Q DSM streams for external reconstruction filters and an
// analog IQ mixer.  It preserves the reusable dsm_ip_top streaming interface.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module dsm_iq_analog_top #(
  parameter int W = 16,
  parameter int DSM_OUT_W = 8,
  parameter int RF_W = 16,
  parameter int PHASE_W = 24,
  parameter int ALGORITHM = 1,
  parameter int INTERP_MODE = 0
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [W-1:0] i_in,
  input  wire logic signed [W-1:0] q_in,
  output wire logic in_ready,
  output wire logic dsm_valid,
  output wire logic i_bit,
  output wire logic q_bit,
  output wire logic signed [DSM_OUT_W-1:0] i_yout,
  output wire logic signed [DSM_OUT_W-1:0] q_yout
);

  logic unused_rf_valid;
  logic unused_rf_bit;
  logic signed [RF_W-1:0] unused_rf_signed;
  logic [PHASE_W-1:0] unused_phase_acc;

  dsm_ip_top #(
    .W(W),
    .DSM_OUT_W(DSM_OUT_W),
    .RF_W(RF_W),
    .PHASE_W(PHASE_W),
    .ALGORITHM(ALGORITHM),
    .DUC_MODE(2),
    .INTERP_MODE(INTERP_MODE)
  ) u_dsm_ip_top (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .cfg_phase_inc('0),
    .i_in(i_in),
    .q_in(q_in),
    .in_ready(in_ready),
    .dsm_valid(dsm_valid),
    .i_bit(i_bit),
    .q_bit(q_bit),
    .i_yout(i_yout),
    .q_yout(q_yout),
    .rf_valid(unused_rf_valid),
    .rf_bit(unused_rf_bit),
    .rf_signed(unused_rf_signed),
    .phase_acc_dbg(unused_phase_acc)
  );

endmodule

`default_nettype wire
