`timescale 1ns/1ps
`default_nettype none

module tb_dsm_xpm_async_fifo_reset;
  localparam int DATA_W = 16;
  // XPM_FIFO_ASYNC requires at least 16 entries per side.
  localparam int ADDR_W = 4;

  logic wr_clk = 1'b0, rd_clk = 1'b0;
  logic wr_rst_n = 1'b0, rd_rst_n = 1'b0;
  logic [DATA_W-1:0] wr_data = '0;
  logic wr_valid = 1'b0, rd_ready = 1'b0;
  wire wr_ready, wr_full, rd_valid, rd_empty;
  wire [DATA_W-1:0] rd_data;
  integer wr_edge_time = 0;

  always #4.000000 wr_clk = ~wr_clk;
  always #2.285714 rd_clk = ~rd_clk;

  dsm_xpm_async_fifo #(.DATA_W(DATA_W), .ADDR_W(ADDR_W)) dut (
    .wr_clk, .wr_rst_n, .wr_data_vec(wr_data), .wr_valid, .wr_ready, .wr_full,
    .rd_clk, .rd_rst_n, .rd_data, .rd_valid, .rd_ready, .rd_empty
  );

  always @(posedge wr_clk) wr_edge_time = $time;
  always @(dut.fifo_rst) begin
    if ($time != wr_edge_time)
      $fatal(1, "XPM rst changed outside wr_clk: t=%0t last_wr_edge=%0d",
             $time, wr_edge_time);
  end

  task automatic wait_fifo_ready;
    begin
      wait (!dut.wr_rst_busy && !dut.rd_rst_busy);
      repeat (3) @(posedge wr_clk);
    end
  endtask

  task automatic write_word(input logic [DATA_W-1:0] value);
    begin
      @(negedge wr_clk);
      wr_data = value;
      wr_valid = 1'b1;
      do @(posedge wr_clk); while (!wr_ready);
      @(negedge wr_clk);
      wr_valid = 1'b0;
    end
  endtask

  task automatic check_word(input logic [DATA_W-1:0] expected);
    begin
      @(negedge rd_clk);
      rd_ready = 1'b1;
      do @(posedge rd_clk); while (!rd_valid);
      if (rd_data !== expected)
        $fatal(1, "FIFO data mismatch got=%h expected=%h", rd_data, expected);
      @(negedge rd_clk);
      rd_ready = 1'b0;
    end
  endtask

  task automatic check_remote_reset(input bit reset_read_domain);
    begin
      if (reset_read_domain) begin
        @(negedge rd_clk); rd_rst_n = 1'b0;
      end else begin
        @(negedge wr_clk); wr_rst_n = 1'b0;
      end
      #1;
      if (wr_ready || rd_valid)
        $fatal(1, "a reset request did not immediately block both FIFO handshakes");
      // Hold a write request across the synchronization window. It must not
      // be accepted in the unaffected domain before the common reset arrives.
      wr_data = 16'hDEAD;
      wr_valid = 1'b1;
      repeat (3) @(posedge wr_clk);
      @(negedge wr_clk); wr_valid = 1'b0;
      wait (dut.fifo_rst);
      wait_fifo_ready_after_release(reset_read_domain);
      if (!rd_empty || rd_valid)
        $fatal(1, "FIFO retained stale data after reset_read_domain=%0d",
               reset_read_domain);
    end
  endtask

  task automatic wait_fifo_ready_after_release(input bit reset_read_domain);
    begin
      if (reset_read_domain) begin
        repeat (5) @(negedge rd_clk);
        rd_rst_n = 1'b1;
      end else begin
        repeat (5) @(negedge wr_clk);
        wr_rst_n = 1'b1;
      end
      wait_fifo_ready();
      if (dut.fifo_rst)
        $fatal(1, "FIFO reset did not release after the local reset request");
    end
  endtask

  initial begin
    repeat (8) @(negedge wr_clk);
    wr_rst_n = 1'b1;
    repeat (5) @(negedge rd_clk);
    rd_rst_n = 1'b1;
    wait_fifo_ready();
    if (!rd_empty) $fatal(1, "FIFO was not empty after initial reset");

    // Write data, reset from the read side only, and prove common FIFO state
    // is cleared before traffic resumes.
    write_word(16'h1357);
    check_remote_reset(1'b1);
    write_word(16'h2468);
    check_word(16'h2468);

    // Repeat from the write side to exercise both reset inputs independently.
    write_word(16'h369a);
    check_remote_reset(1'b0);
    write_word(16'h5abc);
    check_word(16'h5abc);

    if (!rd_empty || rd_valid || wr_full)
      $fatal(1, "FIFO flags incorrect after reset recovery");
    $display("DSM_XPM_ASYNC_FIFO_RESET_PASS async reset sources and wr_clk-synchronous XPM reset");
    $finish;
  end

  initial begin
    repeat (2000) @(posedge wr_clk);
    $fatal(1, "XPM async FIFO reset test timeout");
  end
endmodule

`default_nettype wire
