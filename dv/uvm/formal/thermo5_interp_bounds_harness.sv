`timescale 1ns/1ps
// Valid-state accumulator bounds for the 8-lane, 2-tap x2 interpolator.
module thermo5_interp_bounds_harness(input logic clk,rst_n,enable,in_valid,out_ready,
  input logic signed [127:0] in_i_vec,in_q_vec);
  logic in_frame_start = 1'b0;
  wire out_frame_start;
  wire in_ready,out_valid;
  wire signed [255:0] out_i_vec,out_q_vec;
  dsm_interp_x2_polyphase_vector #(.LANES_IN(8),.INTERP_TAPS(2)) dut(.*);
  default clocking cb @(posedge clk); endclocking
  for(genvar lane=0;lane<8;lane++) begin:g_lane
    a_acc_i: assert property (disable iff(!rst_n) dut.s2_valid |-> dut.s2_acc_i[lane] inside {[-33'sd536870912:33'sd536854528]});
    a_acc_q: assert property (disable iff(!rst_n) dut.s2_valid |-> dut.s2_acc_q[lane] inside {[-33'sd536870912:33'sd536854528]});
  end
  c_accept: cover property (in_valid && in_ready);
  c_output: cover property (out_valid && out_ready);
  c_stall: cover property (out_valid && !out_ready);
  c_min: cover property (out_valid && out_i_vec[31:16]==16'h8000);
  c_max: cover property (out_valid && out_i_vec[31:16]==16'h7fff);
endmodule
