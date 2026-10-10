`timescale 1ns/1ps
`default_nettype none

// Small generic-FIFO reset probe used only by the isolated fault experiment.
// It proves that a partially consumed pre-reset epoch cannot reappear after
// both local reset inputs are reasserted.
module thermo5_fault_stale_fifo_tb;
  localparam int DATA_W = 16;
  logic wr_clk = 1'b0, rd_clk = 1'b0;
  logic wr_rst_n = 1'b0, rd_rst_n = 1'b0;
  logic [DATA_W-1:0] wr_data = '0;
  logic wr_valid = 1'b0, rd_ready = 1'b0;
  wire wr_ready, wr_full, rd_valid, rd_empty;
  wire [DATA_W-1:0] rd_data;

  always #4.000000 wr_clk = ~wr_clk;
  always #2.285714 rd_clk = ~rd_clk;

  dsm_async_fifo #(.DATA_W(DATA_W), .ADDR_W(3)) dut (
    .wr_clk, .wr_rst_n, .wr_data, .wr_valid, .wr_ready, .wr_full,
    .rd_clk, .rd_rst_n, .rd_data, .rd_valid, .rd_ready, .rd_empty
  );

  task automatic write_word(input logic [DATA_W-1:0] value);
    @(negedge wr_clk);
    wr_data = value;
    wr_valid = 1'b1;
    do @(posedge wr_clk); while (!wr_ready);
    @(negedge wr_clk);
    wr_valid = 1'b0;
  endtask

  initial begin
    repeat (5) @(negedge wr_clk);
    wr_rst_n = 1'b1;
    rd_rst_n = 1'b1;
    repeat (4) @(posedge rd_clk);

    write_word(16'h1357);
    write_word(16'h2468);
    @(negedge rd_clk);
    rd_ready = 1'b1;
    do @(posedge rd_clk); while (!rd_valid);
    if (rd_data !== 16'h1357) $fatal(1, "pre-reset first word mismatch");
    @(negedge rd_clk);
    rd_ready = 1'b0;

    // Leave 0x2468 unread, then clear the FIFO epoch from both domains.
    @(negedge wr_clk);
    wr_rst_n = 1'b0;
    rd_rst_n = 1'b0;
    repeat (4) @(negedge wr_clk);
    wr_rst_n = 1'b1;
    rd_rst_n = 1'b1;
    repeat (5) @(posedge rd_clk);
    if (rd_valid !== 1'b0 || rd_empty !== 1'b1)
      $fatal(1, "stale FIFO word visible after reset: valid=%b empty=%b data=%h",
             rd_valid, rd_empty, rd_data);

    $display("THERMO5_FAULT_STALE_FIFO_BASELINE_PASS");
    $finish;
  end

  initial begin
    repeat (500) @(posedge rd_clk);
    $fatal(1, "stale FIFO probe timeout");
  end
endmodule

`default_nettype wire
