`timescale 1ns/1ps
interface thermo5_runtime_if(input logic src_clk,core_clk,axil_clk);
  logic src_rst_n=0,core_rst_n=0,axil_rst_n=0;
  logic src_valid=0,src_ready,src_last=0,src_start=0;
  logic signed [223:0] src_i=0,src_q=0;
  logic signed [15:0] src_gain=16384;
  logic fifo_full,underflow,protocol_error,run_request,tx_active;
  logic [3:0] pa_valid,pa_ready=0,pa_mask;
  logic [63:0] pa_data[0:3];
  logic [1:0] arch;
  logic weighted,mode_busy,frame_start,frame_end,tail;
  logic [15:0] config_id;
  logic cfg_busy,cfg_done,cfg_error;
  logic [7:0] awaddr=0,araddr=0;
  logic awvalid=0,awready,wvalid=0,wready,bvalid,bready=0;
  logic [31:0] wdata=0,rdata;
  logic [3:0] wstrb=0;
  logic [1:0] bresp,rresp;
  logic arvalid=0,arready,rvalid,rready=0;
  clocking sample @(posedge core_clk);
    default input #1step;
    input core_rst_n,pa_valid,pa_ready,pa_mask,pa_data,arch,weighted;
    input frame_start,frame_end,tail,config_id,tx_active,underflow,protocol_error;
  endclocking
endinterface
