`timescale 1ns/1ps
`default_nettype none
// Directed product-mode FIFO contract: common assertion, independent local
// release, reset with unread words, then a fresh prefill before any read.
module tb_thermo5_xpm_prefill_reset;
  logic wr_clk=0, rd_clk=0, common_n=0;
  always #4 wr_clk=~wr_clk;
  always #2.286 rd_clk=~rd_clk;
  wire wn,rn,wr_ready,wr_full,rd_valid,rd_empty;
  logic wr_valid=0,rd_ready=0;
  localparam int FIFO_W = 2*14*16 + 2 + 16;
  logic [FIFO_W-1:0] wr_data=0;
  wire [FIFO_W-1:0] rd_data;
  wire [4:0] rd_count;
  int written=0, read_n=0, epoch=0, threshold_seen=0;
  dsm_reset_sync ws(.clk(wr_clk),.arst_n(common_n),.srst_n(wn));
  dsm_reset_sync rs(.clk(rd_clk),.arst_n(common_n),.srst_n(rn));
  dsm_xpm_async_fifo #(.DATA_W(FIFO_W),.ADDR_W(4),.COMMON_RESET_EPOCH(1)) dut(
    .wr_clk(wr_clk),.wr_rst_n(wn),.wr_data_vec(wr_data),.wr_valid(wr_valid),
    .wr_ready(wr_ready),.wr_full(wr_full),.rd_clk(rd_clk),.rd_rst_n(rn),
    .rd_data(rd_data),.rd_valid(rd_valid),.rd_ready(rd_ready),
    .rd_empty(rd_empty),.rd_count(rd_count));
  always @(posedge wr_clk) if (wn && wr_valid && wr_ready) written++;
  always @(posedge rd_clk) if (rn && !rd_ready && rd_count>=2) begin
    if (written<2) $fatal(1,"prefill threshold before two fresh accepted writes epoch=%0d count=%0d written=%0d",epoch,rd_count,written);
    threshold_seen++;
  end
  always @(posedge rd_clk) if (rn && rd_ready && rd_valid) begin
    if (rd_data !== FIFO_W'(32'h12340000 + epoch*32 + read_n))
      $fatal(1,"unexpected/old FIFO data epoch=%0d index=%0d got=%h",epoch,read_n,rd_data);
    read_n++;
  end
  task automatic push(input logic [FIFO_W-1:0] value);
    @(negedge wr_clk); wr_data=value; wr_valid=1;
    do @(posedge wr_clk); while (!wr_ready || !wn);
    @(negedge wr_clk); wr_valid=0;
  endtask
  initial begin
    #1; common_n=1; #1; common_n=0;
    for (int e=0;e<4;e++) begin
      epoch=e; written=0; read_n=0; rd_ready=0; wr_valid=0;
      repeat(6) @(negedge wr_clk); common_n=1;
      wait(wn && rn && wr_ready);
      for(int k=0;k<8;k++) push(32'h12340000 + epoch*32 + k);
      wait(rd_count>=2); repeat(2) @(negedge rd_clk);
      rd_ready=1; wait(read_n==8);
      @(negedge rd_clk); rd_ready=0;
      // Leave accepted data in the FIFO, then abort it with common reset.
      push(32'hdead0000+e); push(32'hdead1000+e);
      @(negedge wr_clk); common_n=0;
      #0.001; if(wn || rn) $fatal(1,"common reset assertion failed");
    end
    if(threshold_seen==0) $fatal(1,"prefill did not occur");
    $display("XPM_PREFILL_RESET_PASS epochs=4 checked_words=32 threshold_samples=%0d",threshold_seen);
    $finish;
  end
  initial begin #100000; $fatal(1,"watchdog"); end
endmodule
`default_nettype wire
