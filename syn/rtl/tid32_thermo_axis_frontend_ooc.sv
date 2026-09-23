`timescale 1ns/1ps
`default_nettype none

// Full, two-clock OOC tops.  DPD coefficient ports are intentionally top
// level ports so the result includes the programmable identity-DPD hardware,
// rather than letting synthesis collapse it into a bypass.
module tid32_thermo3_axis_frontend_tx_ooc (
  input wire logic clk125, rst125_n, s_valid, s_frame_start,
  input wire logic clk218, rst218_n,
  input wire logic signed [223:0] s_i_vec, s_q_vec,
  input wire logic signed [15:0] s_frame_gain,
  input wire logic [2:0] dpd_active_taps,
  input wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic s_ready, s_fifo_full, core_underflow, core_protocol_error,
  output wire logic pa_p_valid, output wire logic [63:0] pa_p_data,
  output wire logic pa_m_valid, output wire logic [63:0] pa_m_data
);
  tid32_thermo3_axis_frontend_tx u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n), .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec), .s_axis_tuser_frame_start(s_frame_start),
    .s_axis_tuser_frame_gain(s_frame_gain), .s_axis_fifo_full(s_fifo_full),
    .core_clk(clk218), .core_aresetn(rst218_n), .core_enable(1'b1),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(1'b1),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
  );
endmodule

module tid32_thermo5_axis_frontend_tx_ooc (
  input wire logic clk125, rst125_n, s_valid, s_frame_start,
  input wire logic clk218, rst218_n,
  input wire logic signed [223:0] s_i_vec, s_q_vec,
  input wire logic signed [15:0] s_frame_gain,
  input wire logic [2:0] dpd_active_taps,
  input wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic s_ready, s_fifo_full, core_underflow, core_protocol_error,
  output wire logic [3:0] pa_valid,
  output wire logic [63:0] pa0_data, pa1_data, pa2_data, pa3_data
);
  wire logic [63:0] pa_data [0:3];
  tid32_thermo5_axis_frontend_tx #(.BYPASS_DPD(1'b0)) u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n), .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec), .s_axis_tuser_frame_start(s_frame_start),
    .s_axis_tuser_frame_gain(s_frame_gain), .s_axis_fifo_full(s_fifo_full),
    .core_clk(clk218), .core_aresetn(rst218_n), .core_enable(1'b1),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .dpd_active_taps(dpd_active_taps), .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(4'hf)
  );
  assign pa0_data = pa_data[0]; assign pa1_data = pa_data[1];
  assign pa2_data = pa_data[2]; assign pa3_data = pa_data[3];
endmodule

`default_nettype wire
