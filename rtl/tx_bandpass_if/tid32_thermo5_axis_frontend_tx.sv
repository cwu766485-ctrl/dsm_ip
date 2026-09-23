`timescale 1ns/1ps
`default_nettype none

// Multi-clock FPGA integration wrapper.  AXI-stream ingress is 125 MHz and
// carries 14 contiguous complex samples per beat.  The TID frontend remains
// unchanged at 218.75 MHz and consumes eight contiguous complex samples.
module tid32_thermo5_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int STEP = 7168,
  // Identity-configured memory-DPD remains structurally present by default.
  parameter bit BYPASS_DPD = 1'b0,
  parameter bit FPGA_USE_XPM_FIFO = 1'b1
) (
  input  wire logic                            s_axis_aclk,
  input  wire logic                            s_axis_aresetn,
  input  wire logic                            s_axis_tvalid,
  output wire logic                            s_axis_tready,
  input  wire logic signed [14*W-1:0]          s_axis_i_vec,
  input  wire logic signed [14*W-1:0]          s_axis_q_vec,
  input  wire logic                            s_axis_tuser_frame_start,
  input  wire logic signed [GAIN_W-1:0]        s_axis_tuser_frame_gain,
  output wire logic                            s_axis_fifo_full,

  input  wire logic                            core_clk,
  input  wire logic                            core_aresetn,
  input  wire logic                            core_enable,
  output wire logic                            core_underflow,
  output wire logic                            core_protocol_error,
  input  wire logic [2:0]                      dpd_active_taps,
  input  wire logic signed [63:0]              c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic [3:0]                      pa_valid,
  output wire logic [63:0]                     pa_data [0:3],
  input  wire logic [3:0]                      pa_ready
);
  logic core_valid, core_ready, core_frame_start;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;

  dsm_axis14_to_core8_cdc #(.W(W), .GAIN_W(GAIN_W), .USE_XPM_FIFO(FPGA_USE_XPM_FIFO)) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(s_axis_aresetn),
    .s_axis_tvalid(s_axis_tvalid), .s_axis_tready(s_axis_tready),
    .s_axis_i_vec(s_axis_i_vec), .s_axis_q_vec(s_axis_q_vec),
    .s_axis_tuser_frame_start(s_axis_tuser_frame_start),
    .s_axis_tuser_frame_gain(s_axis_tuser_frame_gain), .s_axis_fifo_full(s_axis_fifo_full),
    .core_clk(core_clk), .core_aresetn(core_aresetn), .core_enable(core_enable),
    .core_valid(core_valid), .core_ready(core_ready), .core_i_vec(core_i_vec), .core_q_vec(core_q_vec),
    .core_frame_start(core_frame_start), .core_frame_gain(core_frame_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  tid32_thermo5_frontend_tx #(.W(W), .IN_LANES(8), .DPD_LANES(16), .GAIN_W(GAIN_W),
    .STEP(STEP), .BYPASS_DPD(BYPASS_DPD)) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(core_enable),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
endmodule

`default_nettype wire
