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
  // Read-only vendor FIFO observation for the qualified FWFT reset test.
  logic [1:0] xpm_fwft_state;
  logic xpm_rd_rst_i;
  // Observation only: named pipeline combinations, never driven by UVM.
  logic interp1_empty_blocked, interp2_empty_blocked, dpd_empty_blocked;
  logic interp1_stage1_empty_blocked;
  logic interp1_stall_window;
  logic interp1_stage1_held, interp1_stage0_held, interp2_stage1_held;
  logic interp1_output_held, interp2_output_held;
  logic interp1_output_empty_blocked, interp2_stage1_empty_blocked;
  wire [31:0] dpd_sample_count[0:15], dpd_saturation_count[0:15];
endinterface
