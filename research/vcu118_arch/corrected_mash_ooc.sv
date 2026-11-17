`timescale 1ns/1ps
`default_nettype none
// Standalone corrected MASH comparison; handshaked weighted output differs
// from the historical uncorrected q1/q2 wrapper and is not a product top.
module corrected_mash_ooc(
  input wire logic clk,rst_n,in_valid,out_ready,
  input wire logic signed [511:0] in_i_poly_vec,in_q_poly_vec,
  output wire logic in_ready,out_valid,overflow,
  output wire logic [63:0] pa0,pa1
);
  thermo5_mash_backend #(.USE_ACCUMULATOR_RESIDUE(1'b1)) dut(
    .clk(clk),.rst_n(rst_n),.stop_req(1'b0),.drain_done(),
    .in_valid(in_valid),.in_ready(in_ready),.in_i_poly_vec(in_i_poly_vec),.in_q_poly_vec(in_q_poly_vec),
    .in_config_id(16'd0),.in_epoch(16'd0),.in_frame_start(1'b0),.in_frame_end(1'b0),.in_tail(1'b0),
    .out_valid(out_valid),.out_ready(out_ready),.out_stage1_data(),.out_stage2_data(),
    .out_pa0_data(pa0),.out_pa1_data(pa1),.out_config_id(),.out_epoch(),
    .out_frame_start(),.out_frame_end(),.out_tail(),.overflow_error(overflow),.inflight_count());
endmodule
`default_nettype wire
