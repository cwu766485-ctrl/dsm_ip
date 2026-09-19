`timescale 1ns/1ps
`default_nettype none

module tid32_thermo3_fs4_multipa_tx_ooc (
  input wire logic clk,
  input wire logic rst_n,
  input wire logic in_valid,
  input wire logic signed [511:0] in_i_poly_vec,
  input wire logic signed [511:0] in_q_poly_vec,
  output wire logic pa_p_valid,
  output wire logic [63:0] pa_p_data,
  output wire logic pa_m_valid,
  output wire logic [63:0] pa_m_data
);
  tid32_thermo3_fs4_multipa_tx #(.W(16), .CHANNELS(32), .THRESHOLD(8192)) u_dut (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid), .in_ready(),
    .in_i_poly_vec(in_i_poly_vec), .in_q_poly_vec(in_q_poly_vec),
    .pa_p_valid(pa_p_valid), .pa_p_data(pa_p_data), .pa_p_ready(1'b1),
    .pa_m_valid(pa_m_valid), .pa_m_data(pa_m_data), .pa_m_ready(1'b1)
  );
endmodule

`default_nettype wire
