`timescale 1ns/1ps
`default_nettype none

// Dual-clock asynchronous FIFO for complete AXI-stream beats.
// DATA_W is deliberately unconstrained so one write can carry a vector of
// contiguous complex samples.  The memory has asynchronous read semantics;
// only Gray-coded pointers cross clock domains.
module dsm_async_fifo #(
  parameter int DATA_W = 32,
  parameter int ADDR_W = 4
) (
  input  wire logic              wr_clk,
  input  wire logic              wr_rst_n,
  input  wire logic [DATA_W-1:0] wr_data,
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
  localparam int PTR_W = ADDR_W + 1;

  logic [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];
  logic [PTR_W-1:0] wr_bin_q, wr_gray_q, rd_bin_q, rd_gray_q;
  logic [PTR_W-1:0] rd_gray_wr_sync1_q, rd_gray_wr_sync2_q;
  logic [PTR_W-1:0] wr_gray_rd_sync1_q, wr_gray_rd_sync2_q;
  logic wr_full_q, rd_empty_q;

  function automatic logic [PTR_W-1:0] bin2gray(input logic [PTR_W-1:0] value);
    bin2gray = (value >> 1) ^ value;
  endfunction

  wire wr_push = wr_valid && !wr_full_q;
  wire rd_pop  = rd_ready && !rd_empty_q;
  wire [PTR_W-1:0] wr_bin_next  = wr_bin_q + wr_push;
  wire [PTR_W-1:0] rd_bin_next  = rd_bin_q + rd_pop;
  wire [PTR_W-1:0] wr_gray_next = bin2gray(wr_bin_next);
  wire [PTR_W-1:0] rd_gray_next = bin2gray(rd_bin_next);
  wire wr_full_next = (wr_gray_next ==
                       {~rd_gray_wr_sync2_q[PTR_W-1:PTR_W-2],
                         rd_gray_wr_sync2_q[PTR_W-3:0]});
  wire rd_empty_next = (rd_gray_next == wr_gray_rd_sync2_q);

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      rd_gray_wr_sync1_q <= '0;
      rd_gray_wr_sync2_q <= '0;
    end else begin
      rd_gray_wr_sync1_q <= rd_gray_q;
      rd_gray_wr_sync2_q <= rd_gray_wr_sync1_q;
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      wr_gray_rd_sync1_q <= '0;
      wr_gray_rd_sync2_q <= '0;
    end else begin
      wr_gray_rd_sync1_q <= wr_gray_q;
      wr_gray_rd_sync2_q <= wr_gray_rd_sync1_q;
    end
  end

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_bin_q  <= '0;
      wr_gray_q <= '0;
      wr_full_q <= 1'b0;
    end else begin
      if (wr_push)
        mem[wr_bin_q[ADDR_W-1:0]] <= wr_data;
      wr_bin_q  <= wr_bin_next;
      wr_gray_q <= wr_gray_next;
      wr_full_q <= wr_full_next;
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_bin_q    <= '0;
      rd_gray_q   <= '0;
      rd_empty_q  <= 1'b1;
    end else begin
      rd_bin_q   <= rd_bin_next;
      rd_gray_q  <= rd_gray_next;
      rd_empty_q <= rd_empty_next;
    end
  end

  assign wr_ready = !wr_full_q;
  assign wr_full  = wr_full_q;
  assign rd_valid = !rd_empty_q;
  assign rd_empty = rd_empty_q;
  assign rd_data  = mem[rd_bin_q[ADDR_W-1:0]];

`ifndef SYNTHESIS
  // Local-domain executable CDC invariants.  Only Gray-coded pointers cross
  // domains; a legal local pointer update changes zero or one Gray bit.
  always_ff @(posedge wr_clk) begin
    if (wr_rst_n) begin
      assert ($onehot0(wr_gray_next ^ wr_gray_q))
        else $error("DSM FIFO write Gray pointer changed by more than one bit");
      assert (!(wr_push && wr_full_q))
        else $error("DSM FIFO write accepted while full");
    end
  end

  always_ff @(posedge rd_clk) begin
    if (rd_rst_n) begin
      assert ($onehot0(rd_gray_next ^ rd_gray_q))
        else $error("DSM FIFO read Gray pointer changed by more than one bit");
      assert (!(rd_pop && rd_empty_q))
        else $error("DSM FIFO read accepted while empty");
    end
  end
`endif
endmodule

`default_nettype wire
