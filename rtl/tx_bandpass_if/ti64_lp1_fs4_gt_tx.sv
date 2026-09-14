//------------------------------------------------------------------------------
// 64-lane TI LP1 Fs/4 DSM FPGA prototype with raw GT user-data boundary.
//
// This is a separately specified time-interleaved DSM research path, informed
// by the TIDSM implementation methodology in Firmansyah (2026). It is NOT
// bit-true equivalent to dsm_core_bp_ef2 or the exact temporal64 architecture.
//
// With continuous handshakes at 218.75 MHz, lane 0 through lane 63 form a
// 14-GS/s one-bit stream. The fixed +,+,-,- mixing pattern maps its center to
// Fs/4 = 3.5 GHz. gt_data[0] is the earliest sample in a GT word.
//
// A production RF stream must keep gt_ready asserted. Backpressure is exposed
// only for protocol-safe simulation and startup; a stalled upstream source is
// not a continuous-time RF waveform.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module ti64_lp1_fs4_gt_tx #(
  parameter int W_IN = 16,
  parameter int ACC_W = 28,
  parameter bit SATURATE = 1'b1
) (
  input  wire logic                      clk,
  input  wire logic                      rst_n,
  input  wire logic                      in_valid,
  output wire logic                      in_ready,
  input  wire logic signed [64*W_IN-1:0] in_x_vec,
  output wire logic                      gt_valid,
  input  wire logic                      gt_ready,
  output wire logic [63:0]               gt_data
);
  wire logic [63:0] dsm_y_vec;
  wire logic        dsm_valid;
  wire logic        dsm_enable;
  wire logic        dsm_to_gt_ready;

  // A new 64-sample word may update the lane contexts only if the preceding
  // word can transfer to the GT boundary in this cycle.
  assign in_ready = dsm_to_gt_ready;
  assign dsm_enable = in_valid && in_ready;

  ti32_lp1_fs4_dsm #(
    .LANES(64), .W_IN(W_IN), .ACC_W(ACC_W), .SATURATE(SATURATE)
  ) u_ti64_dsm (
    .clk(clk), .rst_n(rst_n), .enable(dsm_enable), .x_vec(in_x_vec),
    .y_vec(dsm_y_vec), .out_valid(dsm_valid)
  );

  gt_tx_raw64_boundary #(.DATA_W(64)) u_raw_boundary (
    .clk(clk), .rst_n(rst_n), .in_valid(dsm_valid),
    .in_ready(dsm_to_gt_ready), .in_data(dsm_y_vec),
    .gt_valid(gt_valid), .gt_ready(gt_ready), .gt_data(gt_data)
  );
endmodule

`default_nettype wire
