`timescale 1ns/1ps
`default_nettype none

// Static Weighted MASH SKU. The existing four-equal-plane product wrapper is
// intentionally unchanged; this top exposes the historical MASH 1:2 PA pair.
// Each accepted output word contains 32 chronological Fs/4 samples per PA.
module tid32_thermo5_mash_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int DPD_MAX_TAPS = 1,
  parameter int INTERP_TAPS = 2,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1,
  parameter logic [15:0] CONFIG_ID = 16'h0000,
  parameter logic [15:0] RESET_EPOCH = 16'h0000,
  parameter bit USE_ACCUMULATOR_RESIDUE = 1'b1
) (
  input  wire logic                           s_axis_aclk,
  input  wire logic                           s_axis_aresetn,
  input  wire logic                           s_axis_tvalid,
  output wire logic                           s_axis_tready,
  input  wire logic signed [14*W-1:0]         s_axis_i_vec,
  input  wire logic signed [14*W-1:0]         s_axis_q_vec,
  input  wire logic                           s_axis_tuser_frame_start,
  input  wire logic                           s_axis_tlast,
  input  wire logic signed [GAIN_W-1:0]       s_axis_tuser_frame_gain,
  output wire logic                           s_axis_fifo_full,
  input  wire logic                           core_clk,
  input  wire logic                           core_aresetn,
  input  wire logic                           core_drain,
  output wire logic                           core_underflow,
  output wire logic                           core_protocol_error,
  input  wire logic [2:0]                     dpd_active_taps,
  input  wire logic signed [DPD_MAX_TAPS*16-1:0] c1_re, c1_im,
  input  wire logic signed [DPD_MAX_TAPS*16-1:0] c3_re, c3_im,
  input  wire logic signed [DPD_MAX_TAPS*16-1:0] c5_re, c5_im,
  output wire logic [1:0]                     mash_pa_valid,
  input  wire logic [1:0]                     mash_pa_ready,
  output wire logic [63:0]                    mash_pa0_data,
  output wire logic [63:0]                    mash_pa1_data,
  output wire logic                           out_frame_start,
  output wire logic                           out_frame_end,
  output wire logic                           out_tail,
  output wire logic [15:0]                    out_config_id,
  output wire logic [15:0]                    out_reset_epoch,
  output wire logic                           adapter_overflow
);
  logic core_valid, core_ready, core_frame_start, core_frame_end;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic pre_valid, pre_ready;
  logic signed [512-1:0] pre_i_vec, pre_q_vec;
  logic pre_frame_start, pre_frame_end, pre_tail;
  logic [15:0] pre_config_id, pre_reset_epoch;
  logic [3:0] unused_pa_valid;
  logic [63:0] unused_pa_data [0:3];
  logic [3:0] backend_pa_valid;
  logic [63:0] backend_weighted0, backend_weighted1;

  dsm_axis14_to_core8_cdc #(
    .W(W), .GAIN_W(GAIN_W), .USE_XPM_FIFO(FPGA_USE_XPM_FIFO)
  ) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(s_axis_aresetn),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tuser_frame_gain(s_axis_tuser_frame_gain),
    .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_aresetn), .core_enable(1'b1),
    .core_drain(core_drain), .core_valid(core_valid), .core_data_empty(),
    .core_prefill_ready(), .core_ready(core_ready),
    .core_i_vec(core_i_vec), .core_q_vec(core_q_vec),
    .core_frame_start(core_frame_start), .core_frame_end(core_frame_end),
    .core_frame_gain(core_frame_gain), .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error)
  );

  tid32_thermo5_frontend_tx #(
    .W(W), .IN_LANES(8), .DPD_LANES(16), .MAX_TAPS(DPD_MAX_TAPS),
    .INTERP_TAPS(INTERP_TAPS), .INTERP_CENTERED_CUBIC(1'b1),
    .STEP(5120), .TIDSM_ORDER(1), .USE_EXTERNAL_DSM(1'b1)
  ) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(1'b1),
    .in_valid(core_valid), .in_ready(core_ready),
    .in_frame_start(core_frame_start), .in_frame_end(core_frame_end),
    .in_config_id(CONFIG_ID), .in_reset_epoch(RESET_EPOCH),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .pa_valid(unused_pa_valid), .pa_data(unused_pa_data), .pa_ready(4'b0000),
    .pre_dsm_valid(pre_valid), .pre_dsm_ready(pre_ready),
    .pre_dsm_i_vec(pre_i_vec), .pre_dsm_q_vec(pre_q_vec),
    .pre_dsm_frame_start(pre_frame_start), .pre_dsm_frame_end(pre_frame_end),
    .pre_dsm_tail(pre_tail), .pre_dsm_config_id(pre_config_id),
    .pre_dsm_reset_epoch(pre_reset_epoch), .dpd_config_boundary()
  );

  thermo5_unified_dsm_backend #(
    .W(W), .CHANNELS(32), .STEP(5120), .DSM_ARCH(2),
    .MASH_USE_ACCUMULATOR_RESIDUE(USE_ACCUMULATOR_RESIDUE)
  ) u_mash_backend (
    .clk(core_clk), .rst_n(core_aresetn), .stop_req(1'b0), .drain_done(),
    .in_valid(pre_valid), .in_ready(pre_ready),
    .in_i_vec(pre_i_vec), .in_q_vec(pre_q_vec),
    .in_config_id(pre_config_id), .in_reset_epoch(pre_reset_epoch),
    .in_frame_start(pre_frame_start), .in_frame_end(pre_frame_end), .in_tail(pre_tail),
    .pa_valid(backend_pa_valid),
    .pa_ready({2'b00, mash_pa_ready}),
    .pa_data(), .pa_weighted0(backend_weighted0),
    .pa_weighted1(backend_weighted1), .pa_contract_weighted(),
    .out_frame_start(out_frame_start), .out_frame_end(out_frame_end),
    .out_tail(out_tail), .out_config_id(out_config_id),
    .out_reset_epoch(out_reset_epoch), .overflow_error(adapter_overflow)
  );

  assign mash_pa_valid = backend_pa_valid[1:0];
  assign mash_pa0_data = backend_weighted0;
  assign mash_pa1_data = backend_weighted1;
endmodule

`default_nettype wire
