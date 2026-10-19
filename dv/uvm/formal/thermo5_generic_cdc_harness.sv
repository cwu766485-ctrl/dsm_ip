`timescale 1ns/1ps
// Generic-FIFO AXIS CDC and 14:8 gearbox residual legality under independent
// clocks and a legal registered public source.
module thermo5_cdc_residual_harness(
  input logic s_axis_aclk, core_clk, rst_n,
  input logic in_valid, core_enable, core_ready,
  input logic signed [223:0] in_i, in_q,
  input logic frame_start,
  input logic signed [15:0] frame_gain
);
  wire in_ready, fifo_full, core_valid, core_frame_start;
  wire signed [127:0] core_i,core_q;
  wire signed [15:0] core_frame_gain;
  wire underflow,protocol_error;
  logic axis_valid,axis_frame_start;
  logic signed [223:0] axis_i,axis_q;
  logic signed [15:0] axis_frame_gain;
  always @(posedge s_axis_aclk or negedge rst_n) begin
    if(!rst_n) begin
      axis_valid<=0; axis_i<=0; axis_q<=0;
      axis_frame_start<=0; axis_frame_gain<=0;
    end else if(!axis_valid || in_ready) begin
      axis_valid<=in_valid; axis_i<=in_i; axis_q<=in_q;
      axis_frame_start<=frame_start; axis_frame_gain<=frame_gain;
    end
  end
  dsm_axis14_to_core8_cdc #(.USE_XPM_FIFO(1'b0)) dut(
    .s_axis_aclk(s_axis_aclk),.s_axis_aresetn(rst_n),
    .s_axis_tvalid(axis_valid),.s_axis_tready(in_ready),
    .s_axis_i_vec(axis_i),.s_axis_q_vec(axis_q),
    .s_axis_tuser_frame_start(axis_frame_start),.s_axis_tuser_frame_gain(axis_frame_gain),
    .s_axis_fifo_full(fifo_full),.core_clk(core_clk),.core_aresetn(rst_n),
    .core_enable(core_enable),.core_drain(1'b0),.core_ready(core_ready),
    .core_valid(core_valid),.core_i_vec(core_i),.core_q_vec(core_q),
    .core_frame_start(core_frame_start),.core_frame_gain(core_frame_gain),
    .core_underflow(underflow),.core_protocol_error(protocol_error));
  a_axis_stable: assert property (@(posedge s_axis_aclk) disable iff(!rst_n)
    axis_valid && !in_ready |=> axis_valid && $stable({axis_i,axis_q,axis_frame_start,axis_frame_gain}));
  default clocking cb @(posedge core_clk); endclocking
  a_residual_legal: assert property (disable iff(!dut.c_rst_n)
    dut.rem_count_q inside {0,2,4,6,8,10,12});
  a_residual_even: assert property (disable iff(!dut.c_rst_n) !dut.rem_count_q[0]);
  a_residual_bound: assert property (disable iff(!dut.c_rst_n) dut.rem_count_q<=12);
  a_frame_marker_has_valid: assert property (disable iff(!dut.c_rst_n)
    dut.out_frame_start_q |-> dut.out_valid_q);
  a_unused_residual_i_zero: assert property (disable iff(!dut.c_rst_n)
    dut.rem_i_q[223:192]==0);
  a_unused_residual_q_zero: assert property (disable iff(!dut.c_rst_n)
    dut.rem_q_q[223:192]==0);
  for(genvar r=0;r<7;r++) begin : g_residual
    c_residual: cover property (disable iff(!dut.c_rst_n) dut.rem_count_q==2*r);
  end
  c_core_stall: cover property (disable iff(!dut.c_rst_n) core_valid && !core_ready);
  c_core_accept: cover property (disable iff(!dut.c_rst_n) core_valid && core_ready);
endmodule
