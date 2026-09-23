`timescale 1ns/1ps
`default_nettype none

// Multi-clock integration wrapper for the two-plane thermometric frontend.
// 125 MHz AXI-S carries fourteen contiguous complex samples; the XPM FIFO and
// exact 14:8 gearbox supply the existing 218.75 MHz / eight-complex core.
// The DPD interface is present and intended to run identity coefficients
// until an independently qualified calibration is available.
module tid32_thermo3_axis_frontend_tx #(
  parameter int W = 16,
  parameter int GAIN_W = 16,
  parameter int THRESHOLD = 8192,
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
  output wire logic                            pa_p_valid,
  output wire logic [63:0]                     pa_p_data,
  input  wire logic                            pa_p_ready,
  output wire logic                            pa_m_valid,
  output wire logic [63:0]                     pa_m_data,
  input  wire logic                            pa_m_ready
);
  logic core_valid, core_ready, core_frame_start;
  logic signed [8*W-1:0] core_i_vec, core_q_vec;
  logic signed [GAIN_W-1:0] core_frame_gain;
  logic gain_valid, gain_ready;
  logic signed [8*W-1:0] gain_i_vec, gain_q_vec;

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

  dsm_frame_gain_vector #(.W(W), .LANES(8), .GAIN_W(GAIN_W)) u_frame_gain (
    .clk(core_clk), .rst_n(core_aresetn), .enable(core_enable),
    .in_valid(core_valid), .in_ready(core_ready), .in_frame_start(core_frame_start),
    .in_frame_gain(core_frame_gain), .in_i_vec(core_i_vec), .in_q_vec(core_q_vec),
    .out_valid(gain_valid), .out_ready(gain_ready), .out_i_vec(gain_i_vec), .out_q_vec(gain_q_vec)
  );

  tid32_thermo3_frontend_tx #(.W(W), .IN_LANES(8), .DPD_LANES(16), .THRESHOLD(THRESHOLD)) u_frontend (
    .clk(core_clk), .rst_n(core_aresetn), .enable(core_enable),
    .in_valid(gain_valid), .in_ready(gain_ready), .in_i_vec(gain_i_vec), .in_q_vec(gain_q_vec),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im),
    .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(pa_p_ready),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(pa_m_ready)
  );
endmodule

`default_nettype wire
