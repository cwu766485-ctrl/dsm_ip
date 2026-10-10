`timescale 1ns/1ps
`default_nettype none

// FPGA-only implementation of the vector-beat asynchronous FIFO.
// XPM has one reset, synchronous to wr_clk, for both pointer domains. The
// two reset requests are independently synchronized into wr_clk before they
// are combined, so the XPM reset changes only on wr_clk edges.
module dsm_xpm_async_fifo #(
  parameter int DATA_W = 32,
  parameter int ADDR_W = 4
) (
  input  wire logic              wr_clk,
  input  wire logic              wr_rst_n,
  input  wire logic [DATA_W-1:0] wr_data_vec,
  input  wire logic              wr_valid,
  output wire logic              wr_ready,
  output wire logic              wr_full,

  input  wire logic              rd_clk,
  input  wire logic              rd_rst_n,
  output wire logic [DATA_W-1:0] rd_data,
  output wire logic              rd_valid,
  input  wire logic              rd_ready,
  output wire logic              rd_empty
);
  localparam int FIFO_DEPTH = 1 << ADDR_W;
  logic fifo_rst, full, empty, wr_rst_busy, rd_rst_busy;
  // XPM_FIFO_ASYNC requires rst to be synchronous to wr_clk. Synchronize
  // each local reset level separately so the asynchronous reset inputs do
  // not form combinational logic in front of a synchronizer. INIT keeps the
  // XPM reset inactive until the parent asserts reset; the parent contract
  // requires reset after configuration and before traffic.
  (* ASYNC_REG = "TRUE" *) logic [1:0] wr_reset_sync = 2'b00;
  (* ASYNC_REG = "TRUE" *) logic [1:0] rd_reset_sync = 2'b00;
  // Cross-domain handshake guards assert asynchronously with the remote
  // reset, then release only after two destination-clock edges. Keep these
  // separate from fifo_rst because XPM requires its reset to be wr_clk-sync.
  (* ASYNC_REG = "TRUE" *) logic [1:0] rd_reset_in_wr = 2'b00;
  (* ASYNC_REG = "TRUE" *) logic [1:0] wr_reset_in_rd = 2'b00;
  always @(posedge wr_clk) begin
    wr_reset_sync <= {wr_reset_sync[0], !wr_rst_n};
    rd_reset_sync <= {rd_reset_sync[0], !rd_rst_n};
  end
  always @(posedge wr_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) rd_reset_in_wr <= 2'b00;
    else rd_reset_in_wr <= {rd_reset_in_wr[0], 1'b1};
  end
  always @(posedge rd_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) wr_reset_in_rd <= 2'b00;
    else wr_reset_in_rd <= {wr_reset_in_rd[0], 1'b1};
  end
  assign fifo_rst = wr_reset_sync[1] || rd_reset_sync[1];

  // Any side's reset request immediately blocks both public handshakes, so
  // the unaffected domain cannot transfer a beat during the two wr_clk
  // cycles before the common XPM reset is asserted.
  assign wr_ready = !full && !wr_rst_busy && wr_rst_n && rd_reset_in_wr[1];
  assign wr_full = full;
  assign rd_valid = !empty && !rd_rst_busy && rd_rst_n && wr_reset_in_rd[1];
  assign rd_empty = empty;

  xpm_fifo_async #(
    .FIFO_MEMORY_TYPE("block"),
    .ECC_MODE("no_ecc"),
    .RELATED_CLOCKS(0),
    .FIFO_WRITE_DEPTH(FIFO_DEPTH),
    .WRITE_DATA_WIDTH(DATA_W),
    .WR_DATA_COUNT_WIDTH(1),
    .PROG_FULL_THRESH(FIFO_DEPTH-2),
    .FULL_RESET_VALUE(0),
    .USE_ADV_FEATURES("0000"),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(DATA_W),
    .RD_DATA_COUNT_WIDTH(1),
    .PROG_EMPTY_THRESH(2),
    .DOUT_RESET_VALUE("0"),
    .CDC_SYNC_STAGES(2),
    .WAKEUP_TIME(0)
  ) u_xpm_fifo_async (
    .sleep(1'b0), .rst(fifo_rst),
    .wr_clk(wr_clk), .wr_en(wr_valid && wr_ready), .din(wr_data_vec),
    .full(full), .prog_full(), .wr_data_count(), .overflow(),
    .wr_rst_busy(wr_rst_busy), .almost_full(), .wr_ack(),
    .rd_clk(rd_clk), .rd_en(rd_ready && rd_valid), .dout(rd_data),
    .empty(empty), .prog_empty(), .rd_data_count(), .underflow(),
    .rd_rst_busy(rd_rst_busy), .almost_empty(), .data_valid(),
    .injectsbiterr(1'b0), .injectdbiterr(1'b0), .sbiterr(), .dbiterr()
  );
endmodule

`default_nettype wire
