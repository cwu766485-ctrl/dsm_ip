`default_nettype none
module crfb_smash2_temporal8_ooc #(
  parameter int STEPS=8
) (
  input wire logic clk,input wire logic rst_n,input wire logic enable,
  input wire logic signed [127:0] x_word,output wire logic [7:0] y1_word,output wire logic [7:0] y2_word
);
  wire logic signed [251:0] unused_state;
  crfb_smash2_temporal8 #(.STEPS(STEPS)) u_dut(.clk(clk),.rst_n(rst_n),.enable(enable),.x_word(x_word),.y1_word(y1_word),.y2_word(y2_word),.state_word(unused_state));
endmodule
`default_nettype wire
