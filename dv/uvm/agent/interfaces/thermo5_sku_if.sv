`timescale 1ns/1ps

interface thermo5_sku_if(input logic src_clk, core_clk);
  logic src_rst_n = 0;
  logic core_rst_n = 0;
  logic src_valid = 0;
  logic src_ready;
  logic signed [223:0] src_i = '0, src_q = '0;
  logic frame_start = 0;
  logic signed [15:0] frame_gain = 16'sd16384;
  logic fifo_full;
  logic core_enable = 0;
  logic underflow, protocol_error;
  logic [3:0] pa_valid;
  logic [63:0] pa_data [0:3];
  logic [3:0] pa_ready = 4'hf;
  int accepted_beats = 0;
  logic restart_source = 0;
  int restart_epoch = 0;
  logic [3:0] cdc_residual;
endinterface
