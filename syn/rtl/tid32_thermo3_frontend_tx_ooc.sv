`timescale 1ns/1ps
`default_nettype none

module tid32_thermo3_frontend_tx_ooc (
  input  wire logic clk,
  input  wire logic rst_n,
  input  wire logic in_valid,
  input  wire logic signed [127:0] in_i_vec,
  input  wire logic signed [127:0] in_q_vec,
  input  wire logic [2:0] dpd_active_taps,
  input  wire logic signed [63:0] c1_re, c1_im, c3_re, c3_im, c5_re, c5_im,
  output wire logic in_ready,
  output wire logic pa_p_valid,
  output wire logic [63:0] pa_p_data,
  output wire logic pa_m_valid,
  output wire logic [63:0] pa_m_data
);
  tid32_thermo3_frontend_tx u_dut (
    .clk(clk), .rst_n(rst_n), .enable(1'b1), .in_valid(in_valid), .in_ready(in_ready),
    .in_i_vec(in_i_vec), .in_q_vec(in_q_vec), .dpd_active_taps(dpd_active_taps),
    .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im), .c5_re(c5_re), .c5_im(c5_im),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(1'b1),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
  );
endmodule

`default_nettype wire
