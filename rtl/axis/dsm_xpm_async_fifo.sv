`timescale 1ns/1ps
`default_nettype none

// FPGA-only implementation of the vector-beat asynchronous FIFO.
// XPM has one reset, synchronous to wr_clk, for both pointer domains. The
// legacy independent-reset mode combines both requests in wr_clk; the
// compile-time product mode relies on its shared reset epoch and removes the
// redundant reset-to-reset handshake.
module dsm_xpm_async_fifo #(
  parameter int DATA_W = 32,
  parameter int ADDR_W = 4,
  // Set only when wr_rst_n and rd_rst_n have one shared asynchronous
  // assertion epoch and each is synchronously released in its own domain.
  // This removes the redundant reset-to-reset crossings around XPM.
  parameter bit COMMON_RESET_EPOCH = 1'b0
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
  output wire logic              rd_empty,
  output wire logic [ADDR_W:0]    rd_count
);
  localparam int FIFO_DEPTH = 1 << ADDR_W;
  logic fifo_rst, full, empty, wr_rst_busy, rd_rst_busy;

  generate
    if (COMMON_RESET_EPOCH) begin : g_common_reset_epoch
      // The product top gives both domains the same async reset assertion and
      // independently synchronized local release. Therefore a second sampled
      // copy of rd_rst_n and cross-domain reset guard flops are redundant and
      // create reset crossings that do not exist in the product contract.
      // XPM's single reset is generated synchronously in wr_clk. Both public
      // handshakes are immediately blocked by their local reset and then by
      // XPM's reset-busy flags. Keep the source-reset release synchronizer in
      // rd_clk so read-valid cannot expose a pre-reset FWFT word when the
      // source clock is slower and the read-domain reset releases first.
      (* ASYNC_REG = "TRUE" *) logic [1:0] wr_reset_sync = 2'b00;
      (* ASYNC_REG = "TRUE" *) logic [1:0] wr_reset_in_rd = 2'b00;
      always @(posedge wr_clk)
        wr_reset_sync <= {wr_reset_sync[0], !wr_rst_n};
      always @(posedge rd_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) wr_reset_in_rd <= 2'b00;
        else wr_reset_in_rd <= {wr_reset_in_rd[0], 1'b1};
      end
      assign fifo_rst = wr_reset_sync[1];
      assign wr_ready = !full && !wr_rst_busy && wr_rst_n;
      assign rd_valid = !empty && !rd_rst_busy && rd_rst_n && wr_reset_in_rd[1];
    end else begin : g_independent_resets
      // Legacy/runtime contract: either reset may assert independently, so
      // synchronize both reset levels into the XPM reset clock and guard each
      // public handshake until the opposite domain has observed reset release.
      (* ASYNC_REG = "TRUE" *) logic [1:0] wr_reset_sync = 2'b00;
      (* ASYNC_REG = "TRUE" *) logic [1:0] rd_reset_sync = 2'b00;
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
      assign wr_ready = !full && !wr_rst_busy && wr_rst_n && rd_reset_in_wr[1];
      assign rd_valid = !empty && !rd_rst_busy && rd_rst_n && wr_reset_in_rd[1];
    end
  endgenerate

  assign wr_full = full;
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
    // EN_RDC is bit10: the CDC startup controller consumes rd_count.
    // With 0000 XPM drives that port to zero and RUN cannot prefill.
    .USE_ADV_FEATURES("0400"),
    .READ_MODE("fwft"),
    .FIFO_READ_LATENCY(0),
    .READ_DATA_WIDTH(DATA_W),
    .RD_DATA_COUNT_WIDTH(ADDR_W+1),
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
    .empty(empty), .prog_empty(), .rd_data_count(rd_count), .underflow(),
    .rd_rst_busy(rd_rst_busy), .almost_empty(), .data_valid(),
    .injectsbiterr(1'b0), .injectdbiterr(1'b0), .sbiterr(), .dbiterr()
  );
endmodule

`default_nettype wire
