`timescale 1ns/1ps
`default_nettype none
module tid32_mash11_fs4_multipa_tx_ooc(
  input wire logic clk,input wire logic rst_n,input wire logic in_valid,
  input wire logic signed [511:0] in_i_poly_vec,input wire logic signed [511:0] in_q_poly_vec,
  output wire logic pa_valid,output wire logic [63:0] pa_stage1_data,output wire logic [63:0] pa_stage2_data
);
  tid32_mash11_fs4_multipa_tx #(.W(16),.CHANNELS(32)) u_dut(
    .clk(clk),.rst_n(rst_n),.in_valid(in_valid),.in_ready(),.in_i_poly_vec(in_i_poly_vec),.in_q_poly_vec(in_q_poly_vec),
    .pa_valid(pa_valid),.pa_stage1_data(pa_stage1_data),.pa_stage2_data(pa_stage2_data));
endmodule
`default_nettype wire
