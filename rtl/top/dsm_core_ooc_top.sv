`timescale 1ns/1ps
`default_nettype none

module dsm_core_ooc_top #(
  parameter int ALGORITHM = 2
) (
  input  wire                   clk,
  input  wire                   rst_n,
  input  wire                   in_valid,
  input  wire [23:0]            cfg_phase_inc,
  input  wire signed [15:0]     i_in,
  input  wire signed [15:0]     q_in,
  output wire                   dsm_valid,
  output wire                   i_bit,
  output wire                   q_bit,
  output wire signed [7:0]      i_yout,
  output wire signed [7:0]      q_yout,
  output wire                   rf_valid,
  output wire                   rf_bit,
  output wire signed [15:0]     rf_signed,
  output wire [23:0]            phase_acc_dbg
);

  dsm_ip_core #(
    .W(16), .DSM_OUT_W(8), .RF_W(16), .PHASE_W(24), .LUT_AW(10), .TW_W(16),
    .ALGORITHM(ALGORITHM), .DUC_MODE(0)
  ) u_core (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .cfg_phase_inc(cfg_phase_inc),
    .i_in(i_in), .q_in(q_in), .dsm_valid(dsm_valid), .i_bit(i_bit), .q_bit(q_bit),
    .i_yout(i_yout), .q_yout(q_yout), .rf_valid(rf_valid), .rf_bit(rf_bit),
    .rf_signed(rf_signed), .phase_acc_dbg(phase_acc_dbg)
  );
endmodule

`default_nettype wire
