`timescale 1ns/1ps
`default_nettype none
// Composition of the unchanged product ingress FIFO and Gain. No assumptions
// on valid, metadata, data, enable or ready; only the initialized reset epoch.
module thermo5_gain_fifo_v5_harness (
 input logic clk, rst_n, enable, in_valid, out_ready,
 input logic [17:0] in_meta,
 input logic signed [127:0] in_i, in_q
);
 wire valid, ready;
 wire [17:0] meta;
 wire signed [127:0] fi, fq;
 thermo5_vector_registered_ready_fifo #(.W(16),.LANES(8),.META_W(18)) fifo (
 .clk(clk),.rst_n(rst_n),.in_valid(in_valid && enable),.in_ready(),
 .in_meta(in_meta),.in_i_vec(in_i),.in_q_vec(in_q),
 .out_valid(valid),.out_ready(ready),.out_meta(meta),.out_i_vec(fi),.out_q_vec(fq));
 dsm_frame_gain_vector #(.W(16),.LANES(8),.GAIN_W(16),.GAIN_FRAC(14),
 .HOLD_STATE_ON_DISABLE(1'b0)) gain (
 .clk(clk),.rst_n(rst_n),.enable(enable),.in_valid(valid),.in_ready(ready),
 .in_frame_start(meta[0]),.in_frame_end(meta[1]),.in_frame_gain(meta[17:2]),
 .in_i_vec(fi),.in_q_vec(fq),.out_valid(),.out_ready(out_ready),
 .out_frame_start(),.out_frame_end(),.out_i_vec(),.out_q_vec());
 a_fifo_capacity: assert property (@(posedge clk) disable iff(!rst_n) fifo.count_q <= 2);
 a_fifo_empty_meta: assert property (@(posedge clk) !valid |-> meta == 0);
 a_gain_start_operand: assert property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready |-> !( !valid && meta[0] ));
 a_gain_end_operand: assert property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready |-> !( !valid && meta[1] ));
 c_line136_missing: cover property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready && !valid && meta[0]);
 c_line137_missing: cover property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready && !valid && meta[1]);
 c_live_start: cover property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready && valid && meta[0]);
 c_live_end: cover property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready && valid && meta[1]);
 c_empty_enabled: cover property (@(posedge clk) disable iff(!rst_n)
 enable && gain.s0_ready && !valid);
endmodule
`default_nettype wire
