`timescale 1ns/1ps
`default_nettype none
module thermo5_gain_metadata_v2_harness (
  input logic clk, rst_n, enable, in_valid, in_start, in_end, out_ready,
  input logic signed [15:0] gain,
  input logic signed [127:0] in_i, in_q
);
  dsm_frame_gain_vector #(.W(16), .LANES(8), .GAIN_W(16), .GAIN_FRAC(14),
    .HOLD_STATE_ON_DISABLE(1'b0)) dut (
    .clk(clk), .rst_n(rst_n), .enable(enable), .in_valid(in_valid), .in_ready(),
    .in_frame_start(in_start), .in_frame_end(in_end), .in_frame_gain(gain),
    .in_i_vec(in_i), .in_q_vec(in_q), .out_valid(), .out_frame_start(),
    .out_frame_end(), .out_ready(out_ready), .out_i_vec(), .out_q_vec()
  );
  // Metadata and corresponding valid are updated together, or held together;
  // reset/disable clear both. No input-side metadata assumption is imposed.
  a_s0_start_valid: assert property (@(posedge clk) disable iff (!rst_n)
    dut.s0_frame_start |-> dut.s0_valid);
  a_s0_end_valid: assert property (@(posedge clk) disable iff (!rst_n)
    dut.s0_frame_end |-> dut.s0_valid);
  a_s1_start_valid: assert property (@(posedge clk) disable iff (!rst_n)
    dut.s1_frame_start |-> dut.s1_valid);
  a_s1_end_valid: assert property (@(posedge clk) disable iff (!rst_n)
    dut.s1_frame_end |-> dut.s1_valid);
  c_line112: cover property (@(posedge clk) disable iff (!rst_n)
    !dut.s1_valid && dut.s1_frame_start);
  c_line113: cover property (@(posedge clk) disable iff (!rst_n)
    !dut.s1_valid && dut.s1_frame_end);
  c_line123: cover property (@(posedge clk) disable iff (!rst_n)
    !dut.s0_valid && dut.s0_frame_start);
  c_line124: cover property (@(posedge clk) disable iff (!rst_n)
    !dut.s0_valid && dut.s0_frame_end);
  c_live_metadata: cover property (@(posedge clk) disable iff (!rst_n)
    dut.s1_valid && dut.s1_frame_start && dut.s1_frame_end);
  // These input tuples ARE reachable in this overapproximation. Therefore
  // lines136/137 require upstream FIFO composition, not this local proof.
  c_invalid_input_metadata: cover property (@(posedge clk) disable iff (!rst_n)
    enable && dut.s0_ready && !in_valid && in_start && in_end);
endmodule
`default_nettype wire
