`timescale 1ns/1ps
`default_nettype none
// Explicit portfolio SKU. Original configurable ASIC tops remain unchanged.
module thermo5_frozen_asic (
  input wire clk125, rst125_n, clk218, rst218_n,
  input wire s_valid, s_frame_start, core_enable,
  input wire signed [223:0] s_i_vec, s_q_vec,
  input wire signed [15:0] s_frame_gain,
  input wire [3:0] pa_ready,
  output wire s_ready, s_fifo_full, core_underflow, core_protocol_error,
  output wire [3:0] pa_valid,
  output wire [63:0] pa0_data, pa1_data, pa2_data, pa3_data
);
  wire [63:0] pa_data [0:3];
  tid32_thermo5_axis_frontend_tx #(
    .INTERP_TAPS(2), .DPD_MAX_TAPS(1), .BYPASS_DPD(1'b0),
    .FPGA_USE_XPM_FIFO(1'b0), .ENABLE_LOW_POWER_CTRL(1'b0)
  ) u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n),
    .s_axis_tvalid(s_valid), .s_axis_tready(s_ready),
    .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec),
    .s_axis_tuser_frame_start(s_frame_start), .s_axis_tuser_frame_gain(s_frame_gain),
    .s_axis_fifo_full(s_fifo_full), .core_clk(clk218), .core_aresetn(rst218_n),
    .core_enable(core_enable), .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error), .dpd_active_taps(3'd1),
    .c1_re(64'h4000), .c1_im(64'd0), .c3_re(64'd0), .c3_im(64'd0),
    .c5_re(64'd0), .c5_im(64'd0),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready)
  );
  assign pa0_data = pa_data[0];
  assign pa1_data = pa_data[1];
  assign pa2_data = pa_data[2];
  assign pa3_data = pa_data[3];
endmodule
`default_nettype wire
