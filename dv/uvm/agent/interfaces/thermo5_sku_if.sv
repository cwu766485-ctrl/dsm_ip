`timescale 1ns/1ps

interface thermo5_sku_if(input logic src_clk, core_clk);
  logic src_rst_n = 0;
  logic core_rst_n = 0;
  logic src_valid = 0;
  logic src_ready;
  logic src_last = 0;
  logic signed [223:0] src_i = '0, src_q = '0;
  logic frame_start = 0;
  logic signed [15:0] frame_gain = 16'sd16384;
  logic fifo_full;
  logic core_enable = 0;
  logic underflow, protocol_error;
  logic cfg_busy, cfg_done, cfg_error;
  logic cfg_pending_valid;
  logic core_run_request, core_tx_active;
  logic [2:0] dpd_active_taps;
  logic dpd_config_boundary;
  // Read-only AXI-Lite CDC payload observation for atomic-commit checking.
  logic [386:0] cfg_mailbox_payload, cfg_pending_payload, cfg_active_payload;
  logic [3:0] pa_valid;
  logic [63:0] pa_data [0:3];
  logic [3:0] pa_ready = 4'hf;
  int accepted_beats = 0;
  logic restart_source = 0;
  int restart_epoch = 0;
  logic [3:0] cdc_residual;
  logic [2:0] low_power_state;
  logic low_power_active;
  logic [7:0] low_power_outstanding;
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
  // Read-only exact event probes for the centered-cubic two-entry queues.
  logic interp1_centered_pop_push, interp2_centered_pop_push;
  logic [7:0] interp1_centered_state, interp2_centered_state;
  wire [31:0] dpd_sample_count[0:15], dpd_saturation_count[0:15];
  // Read-only observation of real EF2 saturation, held input, and state.
  logic centered_cubic_enabled;
  logic ef2_order2_enabled;
  logic [3:0] ef2_pos_clamp_event, ef2_neg_clamp_event;
  logic [3:0] ef2_pos_clamp_candidate, ef2_neg_clamp_candidate;
  logic [3:0] ef2_state_at_rail, ef2_state_zero;
  logic ef2_clamp_stalled, ef2_tidsm_stalled;
  logic signed [19:0] ef2_err1_i[0:3], ef2_err2_i[0:3];
  logic signed [19:0] ef2_err1_q[0:3], ef2_err2_q[0:3];
endinterface
