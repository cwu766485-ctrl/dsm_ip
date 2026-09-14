// Protocol-level bridge from the temporal64 parallel word to a GT user port.
// This module is not a GT primitive and does not claim to serialize pins.
`timescale 1ns/1ps
`default_nettype none

module gt_tx_user_bridge #(
  parameter int PARALLEL_W = 64,
  parameter int GT_USER_W = 64
) (
  input  wire logic                    clk,
  input  wire logic                    rst_n,
  input  wire logic                    in_valid,
  output wire logic                    in_ready,
  input  wire logic [PARALLEL_W-1:0]   in_data,
  output logic                         gt_valid,
  input  wire logic                    gt_ready,
  output logic [GT_USER_W-1:0]         gt_data
);
  initial begin
    if (PARALLEL_W != GT_USER_W)
      $error("Current bridge requires PARALLEL_W == GT_USER_W; use a dedicated gearbox otherwise");
  end

  assign in_ready = !gt_valid || gt_ready;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gt_valid <= 1'b0;
      gt_data <= '0;
    end else if (in_ready) begin
      gt_valid <= in_valid;
      if (in_valid) gt_data <= in_data;
    end
  end
endmodule

`default_nettype wire
