`timescale 1ns/1ps
// Real default-depth Generic FIFO. Clock-local reset syncs match product CDC.
module tb_thermo5_generic_fifo_epochs;
 reg wc=0,rc=0,rst=1,wv=0,rr=0;reg[31:0]wd=0;
 wire ws,rs,wr,full,rv,empty;wire[31:0]rd;
 integer received=0,expected=0,epoch=0,full_seen=0;
 always #4 wc=~wc;
 always #2.286 rc=~rc;
 dsm_reset_sync wsync(.clk(wc),.arst_n(rst),.srst_n(ws));
 dsm_reset_sync rsync(.clk(rc),.arst_n(rst),.srst_n(rs));
 dsm_async_fifo #(.DATA_W(32),.ADDR_W(4)) dut(.wr_clk(wc),.wr_rst_n(ws),.wr_data(wd),.wr_valid(wv&&ws),.wr_ready(wr),.wr_full(full),.rd_clk(rc),.rd_rst_n(rs),.rd_data(rd),.rd_valid(rv),.rd_ready(rr&&rs),.rd_empty(empty));
 always @(posedge rc) if(rs && rr && rv)begin
  if(rd!==32'h10000000+expected)$fatal(1,"epoch leak/data mismatch epoch%0d index%0d got%h",epoch,expected,rd);
  expected++;received++;
 end
 task automatic push(input[31:0]v);
  @(negedge wc);wv=1;wd=v;
  do @(posedge wc);while(!wr||!ws);
  @(negedge wc);wv=0;
 endtask
 initial begin
  #1;rst=0;#40;rst=1;wait(ws&&rs);
  // Fill without reads. All accepted old words are intentionally discarded.
  for(integer i=0;i<16;i++)push(32'hdead0000+i);
  @(negedge wc);if(!full)$fatal(1,"FIFO full predecessor missing");full_seen++;
  wv=1;wd=32'hdeadffff;
  repeat(3)begin @(posedge wc);if(wr)$fatal(1,"full FIFO acknowledged pending write");end
  #1.137;rst=0;wv=0;epoch++;
  #1ps;if(ws||rs)$fatal(1,"reset sync assertion delayed");
  #40;rst=1;wait(ws&&rs);
  if(!empty||rv)$fatal(1,"FIFO not empty after reset");
  rr=1;
  for(integer i=0;i<64;i++)push(32'h10000000+i);
  wait(received==64);repeat(6)@(posedge rc);
  if(rv||!empty||expected!=64)$fatal(1,"FIFO failed final drain");
  $display("GENERIC_FIFO_EPOCH_PASS full_events=%0d reset_pending_write=1 recovered_words=%0d epoch=%0d independent_scoreboard=PASS",full_seen,received,epoch);
  $finish;
 end
 initial begin #20000;$fatal(1,"FIFO progress watchdog");end
endmodule
