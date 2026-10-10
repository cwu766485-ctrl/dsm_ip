`timescale 1ns/1ps
module thermo5_xpm_fwft_transition(input logic wr_clk,rd_clk,boot_n,request,
  input logic valid_request,rd_ready,input logic [464:0] payload);
  logic rst_n;
  logic [3:0] held;
  logic wr_valid;
  logic [464:0] wr_data_vec;
  wire wr_ready,wr_full,rd_valid,rd_empty;
  wire [464:0] rd_data;
  logic seen_busy=0;
  logic [7:0] accepted=0;
  always @(posedge wr_clk) begin
    if(dut.wr_rst_busy) seen_busy<=1;
    if(!rst_n) accepted<=0;
    else if(wr_valid && wr_ready) accepted<=accepted+1;
  end
  dsm_xpm_async_fifo #(.DATA_W(465),.ADDR_W(4)) dut(
    .wr_clk,.rd_clk,.wr_rst_n(rst_n),.rd_rst_n(rst_n),.*);
  always @(negedge wr_clk or negedge boot_n)
    if(!boot_n) begin rst_n<=0;held<=0;end
    else if(!rst_n && held<8) held<=held+1;
    else if(!rst_n) rst_n<=1;
    else if(request && !dut.wr_rst_busy && !dut.rd_rst_busy) begin rst_n<=0;held<=0;end
  always @(posedge wr_clk or negedge rst_n)
    if(!rst_n) begin wr_valid<=0;wr_data_vec<=0;end
    else if(!wr_valid || wr_ready) begin wr_valid<=valid_request;wr_data_vec<=payload;end
  default clocking cb @(posedge rd_clk); endclocking
  a_fwft_legal: assert property (dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state inside {0,1,2,3});
  c_stage1: cover property (seen_busy && accepted>0 && dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==2);
  a_no_reset_transition: assert property (seen_busy && accepted>0 && dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==2 |=> dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state!=0);
  c_reset_transition: cover property (seen_busy && accepted>0 && dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==2 ##1 dut.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state==0);
  c_read: cover property (rd_valid && rd_ready);
endmodule
