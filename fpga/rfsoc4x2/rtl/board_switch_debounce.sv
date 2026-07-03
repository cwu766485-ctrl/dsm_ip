//------------------------------------------------------------------------------
// File: board_switch_debounce.sv
// Description:
//   Synchronize and debounce a board-level mechanical switch into a clean
//   single-clock level signal.
//------------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module board_switch_debounce #(
  parameter int unsigned DEBOUNCE_CYCLES = 500_000
) (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic sw_in,
  output logic sw_level
);

  localparam int COUNT_W = (DEBOUNCE_CYCLES > 1) ? $clog2(DEBOUNCE_CYCLES) : 1;
  localparam logic [COUNT_W-1:0] DB_MAX = DEBOUNCE_CYCLES - 1;

  logic sw_meta;
  logic sw_sync;
  logic [COUNT_W-1:0] db_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sw_meta  <= 1'b0;
      sw_sync  <= 1'b0;
      sw_level <= 1'b0;
      db_cnt   <= '0;
    end else begin
      sw_meta <= sw_in;
      sw_sync <= sw_meta;

      if (sw_sync == sw_level) begin
        db_cnt <= '0;
      end else if (db_cnt == DB_MAX) begin
        sw_level <= sw_sync;
        db_cnt   <= '0;
      end else begin
        db_cnt <= db_cnt + 1'b1;
      end
    end
  end

endmodule

`default_nettype wire
