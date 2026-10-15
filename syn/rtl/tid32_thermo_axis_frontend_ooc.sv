`timescale 1ns/1ps
`default_nettype none

// Full two-clock thermo3 OOC top. Coefficient ports remain top-level so the
// mapped result includes programmable identity-DPD hardware.
module tid32_thermo3_axis_frontend_tx_ooc #(
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 4,
  parameter int DPD_ACTIVE_TAPS = 1,
  parameter bit DPD_ACTIVE_TAPS_RUNTIME = 1'b1
) (
  input wire logic clk125, rst125_n, s_valid, s_frame_start,
  input wire logic clk218, rst218_n, run_request,
  input wire logic signed [223:0] s_i_vec, s_q_vec,
  input wire logic signed [15:0] s_frame_gain,
  input wire logic [2:0] dpd_active_taps,
  input wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic s_ready, s_fifo_full, core_underflow, core_protocol_error,
  output wire logic pa_p_valid, output wire logic [63:0] pa_p_data,
  output wire logic pa_m_valid, output wire logic [63:0] pa_m_data
);
  wire logic [2:0] dpd_taps_cfg = DPD_ACTIVE_TAPS_RUNTIME ? dpd_active_taps : DPD_ACTIVE_TAPS[2:0];
  tid32_thermo3_axis_frontend_tx #(
    .DPD_MAX_TAPS(DPD_MAX_TAPS), .INTERP_TAPS(INTERP_TAPS)
  ) u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n), .s_axis_tvalid(s_valid),
    .s_axis_tready(s_ready), .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec),
    .s_axis_tuser_frame_start(s_frame_start), .s_axis_tuser_frame_gain(s_frame_gain),
    .s_axis_fifo_full(s_fifo_full), .core_clk(clk218), .core_aresetn(rst218_n),
    .core_enable(run_request), .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error), .dpd_active_taps(dpd_taps_cfg),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data),
    .pa_p_ready(1'b1), .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
  );
endmodule

// Low-power OOC top shares the thermo3 boundary and only enables the
// frame-safe activity controller.
module tid32_thermo3_axis_frontend_tx_lp_ooc #(
  parameter int DPD_MAX_TAPS = 4,
  parameter int INTERP_TAPS = 4,
  parameter int DPD_ACTIVE_TAPS = 1,
  parameter bit DPD_ACTIVE_TAPS_RUNTIME = 1'b1
) (
  input wire logic clk125, rst125_n, s_valid, s_frame_start,
  input wire logic clk218, rst218_n, run_request,
  input wire logic signed [223:0] s_i_vec, s_q_vec,
  input wire logic signed [15:0] s_frame_gain,
  input wire logic [2:0] dpd_active_taps,
  input wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic s_ready, s_fifo_full, core_underflow, core_protocol_error,
  output wire logic pa_p_valid, output wire logic [63:0] pa_p_data,
  output wire logic pa_m_valid, output wire logic [63:0] pa_m_data
);
  wire logic [2:0] dpd_taps_cfg = DPD_ACTIVE_TAPS_RUNTIME ? dpd_active_taps : DPD_ACTIVE_TAPS[2:0];
  tid32_thermo3_axis_frontend_tx #(
    .ENABLE_LOW_POWER_CTRL(1'b1), .DPD_MAX_TAPS(DPD_MAX_TAPS), .INTERP_TAPS(INTERP_TAPS)
  ) u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n), .s_axis_tvalid(s_valid),
    .s_axis_tready(s_ready), .s_axis_i_vec(s_i_vec), .s_axis_q_vec(s_q_vec),
    .s_axis_tuser_frame_start(s_frame_start), .s_axis_tuser_frame_gain(s_frame_gain),
    .s_axis_fifo_full(s_fifo_full), .core_clk(clk218), .core_aresetn(rst218_n),
    .core_enable(run_request), .core_underflow(core_underflow),
    .core_protocol_error(core_protocol_error), .dpd_active_taps(dpd_taps_cfg),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
    .c5_re(c5_re), .c5_im(c5_im), .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data),
    .pa_p_ready(1'b1), .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
  );
endmodule

`default_nettype wire
