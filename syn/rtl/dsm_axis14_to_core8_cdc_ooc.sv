`timescale 1ns/1ps
`default_nettype none

module dsm_axis14_to_core8_cdc_ooc (
  input  wire logic clk125,
  input  wire logic rst125_n,
  input  wire logic in_valid,
  input  wire logic signed [223:0] in_i_vec,
  input  wire logic signed [223:0] in_q_vec,
  input  wire logic in_frame_start,
  input  wire logic signed [15:0] in_frame_gain,
  input  wire logic clk218,
  input  wire logic rst218_n,
  output wire logic out_valid,
  output wire logic signed [127:0] out_i_vec,
  output wire logic signed [127:0] out_q_vec,
  output wire logic out_frame_start,
  output wire logic signed [15:0] out_frame_gain,
  output wire logic underflow,
  output wire logic protocol_error
);
  dsm_axis14_to_core8_cdc #(.W(16), .GAIN_W(16), .FIFO_ADDR_W(4), .USE_XPM_FIFO(1'b1)) u_dut (
    .s_axis_aclk(clk125), .s_axis_aresetn(rst125_n), .s_axis_tvalid(in_valid), .s_axis_tready(),
    .s_axis_i_vec(in_i_vec), .s_axis_q_vec(in_q_vec), .s_axis_tuser_frame_start(in_frame_start),
    .s_axis_tuser_frame_gain(in_frame_gain), .s_axis_fifo_full(),
    .core_clk(clk218), .core_aresetn(rst218_n), .core_enable(1'b1), .core_drain(1'b0),
    .core_valid(out_valid), .core_ready(1'b1), .core_i_vec(out_i_vec), .core_q_vec(out_q_vec),
    .core_frame_start(out_frame_start), .core_frame_gain(out_frame_gain),
    .core_underflow(underflow), .core_protocol_error(protocol_error)
  );
endmodule

`default_nettype wire
