`timescale 1ns/1ps
module thermo5_rdc_async_epoch_harness(
 input logic wc,rc,boot_n,epoch_n,wvalid,rready,
 input logic [7:0] wdata
);
 wire common_n=boot_n&&epoch_n;
 wire wn,rn,ready,valid,full,empty;
 wire [7:0] data;
 logic [15:0] initialized;
 dsm_reset_sync ws(.clk(wc),.arst_n(common_n),.srst_n(wn));
 dsm_reset_sync rs(.clk(rc),.arst_n(common_n),.srst_n(rn));
 dsm_async_fifo #(.DATA_W(8),.ADDR_W(4)) dut(
 .wr_clk(wc),.wr_rst_n(wn),.wr_data(wdata),.wr_valid(wvalid&&wn),
 .wr_ready(ready),.wr_full(full),.rd_clk(rc),.rd_rst_n(rn),
 .rd_data(data),.rd_valid(valid),.rd_ready(rready&&rn),.rd_empty(empty));
 always @(posedge wc or negedge common_n)
  if(!common_n) initialized<=0;
  else if(wn&&wvalid&&ready)initialized[dut.wr_bin_q[3:0]]<=1;
 // Inductive strengthening: accepted writes initialize a contiguous cyclic
 // prefix; synchronized pointer observations cannot outrun that frontier.
 function automatic [4:0] gray2bin(input [4:0] g);
  integer j; begin gray2bin[4]=g[4];
  for(j=3;j>=0;j=j-1)gray2bin[j]=gray2bin[j+1]^g[j];end
 endfunction
 wire [4:0] observed_wr=gray2bin(dut.wr_gray_rd_sync2_q);
 a_true_capacity: assert property(@(posedge wc) disable iff(!common_n)
   wn && rn |-> (5'(dut.wr_bin_q-dut.rd_bin_q) <= 16));
 a_read_frontier: assert property(@(posedge rc) disable iff(!common_n)
   rn |-> (5'(observed_wr-dut.rd_bin_q) <= 16));
 a_epoch_initialized: assert property(@(posedge rc) disable iff(!common_n) rn&&valid |-> initialized[dut.rd_bin_q[3:0]]);
 a_no_pop_reset: assert property(@(posedge rc) !rn |-> !dut.rd_pop);
 a_no_push_reset: assert property(@(posedge wc) !wn |-> !dut.wr_push);
 a_wgray: assert property(@(posedge wc) disable iff(!wn) $onehot0(dut.wr_gray_next^dut.wr_gray_q));
 a_rgray: assert property(@(posedge rc) disable iff(!rn) $onehot0(dut.rd_gray_next^dut.rd_gray_q));
 c_transfer: cover property(@(posedge rc) rn&&valid&&rready);
 c_live_reset: cover property(@(posedge rc) valid ##1 !epoch_n ##1 epoch_n ##[1:12] valid);
endmodule
