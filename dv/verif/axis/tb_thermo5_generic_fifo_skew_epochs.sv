`timescale 1ns/1ps
// Real default-depth Generic FIFO. Clock-local reset syncs match product CDC.
module tb_thermo5_generic_fifo_skew_epochs;
 reg wc=0,rc=0,rst=1,wv=0,rr=0;reg[31:0]wd=0;
 reg wa=0,ra=0;
 wire ws,rs,wr,full,rv,empty;wire[31:0]rd;wire[4:0]rd_count;
 integer received=0,expected=0,epoch=0,full_seen=0;
 always #4 wc=~wc;
 always #2.286 rc=~rc;
 dsm_reset_sync wsync(.clk(wc),.arst_n(wa),.srst_n(ws));
 dsm_reset_sync rsync(.clk(rc),.arst_n(ra),.srst_n(rs));
 dsm_async_fifo #(.DATA_W(32),.ADDR_W(4)) dut(.wr_clk(wc),.wr_rst_n(ws),.wr_data(wd),.wr_valid(wv&&ws),.wr_ready(wr),.wr_full(full),.rd_clk(rc),.rd_rst_n(rs),.rd_data(rd),.rd_valid(rv),.rd_ready(rr&&rs),.rd_empty(empty),.rd_count(rd_count));
 always @(posedge rc) if(rs && rr && rv)begin
  if(rd!==32'h10000000+expected)$fatal(1,"epoch leak/data mismatch epoch%0d index%0d got%h",epoch,expected,rd);
  expected++;received++;
 end
 task automatic push(input[31:0]v);
  @(negedge wc);wv=1;wd=v;
  do @(posedge wc);while(!wr||!ws);
  @(negedge wc);wv=0;
 endtask
 task automatic reset_epoch(input integer order);
  wa=0;ra=0;wv=0;rr=0;
  #1ps;if(ws||rs)$fatal(1,"common assertion failed");
  repeat(4)@(negedge wc);
  // Local synchronizers independently release; no single-domain assertion.
  if(order==0)begin wa=1;repeat(7)@(negedge rc);ra=1;end
  else begin ra=1;repeat(7)@(negedge wc);wa=1;end
  wait(ws&&rs);repeat(4)@(negedge rc);
  if(rv||!empty||rd_count!=0)$fatal(1,"old epoch became valid during skew release");
 endtask
 initial begin
  #1;wa=1;ra=1;#1;reset_epoch(0);
  for(integer e=0;e<6;e++)begin
   // Fresh epoch must overwrite old memory before any accepted read.
   received=0;expected=0;epoch=e;rr=1;
   for(integer i=0;i<64;i++)push(32'h10000000+i);
   wait(received==64);repeat(4)@(negedge rc);
   rr=0;
   for(integer i=0;i<16;i++)push(32'hdead0000+i);
   if(!full)$fatal(1,"full predecessor missing");
   full_seen++;wv=1;wd=32'hdeadffff;
   repeat(3)@(negedge wc);
   reset_epoch(e%2);
  end
  $display("GENERIC_FIFO_SKEW_EPOCH_PASS epochs=6 recovered_words=384 both_release_orders=1 old_epoch_excluded=1 full_pending_reset=6");
  $finish;
 end
 initial begin #20000;$fatal(1,"FIFO progress watchdog");end
endmodule
