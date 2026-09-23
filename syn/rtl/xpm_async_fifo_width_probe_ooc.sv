`timescale 1ns/1ps
`default_nettype none

// Minimal dual-clock XPM probe.  It deliberately contains no CDC gearbox,
// reset synchronizer, or DSM logic, so a routed result isolates FIFO mapping.
module xpm_async_fifo_width_probe_ooc #(
  parameter int DATA_W = 32,
  parameter int FIFO_ADDR_W = 4
) (
  input  wire logic              clk125,
  input  wire logic              clk218,
  input  wire logic              rst,
  input  wire logic              wr_en,
  input  wire logic [DATA_W-1:0] din,
  input  wire logic              rd_en,
  output wire logic [DATA_W-1:0] dout,
  // Retaining these ports makes the probe include the XPM reset controller.
  // This distinguishes FIFO-width timing from reset-busy implementation.
  output wire logic              wr_rst_busy_out,
  output wire logic              rd_rst_busy_out
);
  localparam int FIFO_DEPTH = 1 << FIFO_ADDR_W;
  wire full, empty, wr_rst_busy, rd_rst_busy;

  assign wr_rst_busy_out = wr_rst_busy;
  assign rd_rst_busy_out = rd_rst_busy;

  xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("block"),
    .ECC_MODE("no_ecc"),
    .RELATED_CLOCKS(0),
    .FIFO_WRITE_DEPTH(FIFO_DEPTH),
    .WRITE_DATA_WIDTH(DATA_W),
    .WR_DATA_COUNT_WIDTH(1),
    .PROG_FULL_THRESH(FIFO_DEPTH-2),
    .USE_ADV_FEATURES("0000"),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(DATA_W),
    .RD_DATA_COUNT_WIDTH(1),
    .PROG_EMPTY_THRESH(2),
    .CDC_SYNC_STAGES(2),
    .WAKEUP_TIME(0)
  ) u_fifo (
    .sleep(1'b0), .rst(rst),
    .wr_clk(clk125), .wr_en(wr_en && !full), .din(din),
    .full(full), .prog_full(), .wr_data_count(), .overflow(),
    .wr_rst_busy(wr_rst_busy), .almost_full(), .wr_ack(),
    .rd_clk(clk218), .rd_en(rd_en && !empty), .dout(dout),
    .empty(empty), .prog_empty(), .rd_data_count(), .underflow(),
    .rd_rst_busy(rd_rst_busy), .almost_empty(), .data_valid(),
    .injectsbiterr(1'b0), .injectdbiterr(1'b0), .sbiterr(), .dbiterr()
  );
endmodule

`default_nettype wire
