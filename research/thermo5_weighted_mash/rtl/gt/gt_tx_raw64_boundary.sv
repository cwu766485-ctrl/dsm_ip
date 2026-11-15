// Raw 64-bit GT user-data boundary.
//
// This module is intentionally vendor-neutral. A Xilinx GT Wizard generated
// GTH wrapper connects to gt_valid/gt_ready/gt_data. No 8b/10b, 64b/66b,
// scrambling or framing is inserted here because those transformations would
// change a one-bit RF waveform.
`timescale 1ns/1ps
`default_nettype none

module gt_tx_raw64_boundary #(
  parameter int DATA_W = 64
) (
  input  wire logic               clk,
  input  wire logic               rst_n,
  input  wire logic               in_valid,
  output wire logic               in_ready,
  input  wire logic [DATA_W-1:0]  in_data,
  output wire logic               gt_valid,
  input  wire logic               gt_ready,
  output wire logic [DATA_W-1:0]  gt_data
);
  gt_tx_user_bridge #(
    .PARALLEL_W(DATA_W),
    .GT_USER_W(DATA_W)
  ) u_bridge (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .in_data(in_data),
    .gt_valid(gt_valid),
    .gt_ready(gt_ready),
    .gt_data(gt_data)
  );
endmodule

`default_nettype wire
