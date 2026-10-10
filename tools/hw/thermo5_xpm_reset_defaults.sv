`timescale 1ns/1ps
// Actual vendor controller and legal reset contract. No state assumptions.
module thermo5_xpm_reset_defaults(input logic wr_clk,rd_clk,boot_n,request);
  logic rst;
  wire wr_rst,rd_rst,wr_rst_busy,rd_rst_busy;
  always @(negedge wr_clk or negedge boot_n)
    if(!boot_n) rst<=1;
    else if(!rst && wr_rst_busy) rst<=0;
    else rst<=request;
  xpm_fifo_rst #(.COMMON_CLOCK(0),.CDC_DEST_SYNC_FF(2)) dut(.*);
  default clocking cb @(posedge wr_clk); endclocking
  a_wstate: assert property (dut.gen_rst_ic.curr_wrst_state inside {3'b000,3'b010,3'b111,3'b110,3'b100});
  a_rstate: assert property (@(posedge rd_clk) dut.gen_rst_ic.curr_rrst_state inside {2'b00,2'b10,2'b11,2'b01});
  a_exit_not_hold: assert property (dut.gen_rst_ic.curr_wrst_state==3'b110 |-> !dut.rst_i && (!rst || dut.gen_rst_ic.rst_seq_reentered));
  c_request: cover property ($rose(rst));
  c_exit: cover property (dut.gen_rst_ic.curr_wrst_state==3'b110);
  c_recovery: cover property (wr_rst_busy ##1 !wr_rst_busy);
endmodule
