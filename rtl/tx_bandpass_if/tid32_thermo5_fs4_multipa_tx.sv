//------------------------------------------------------------------------------
// Four-branch thermometer-coded five-level Cartesian TID transmitter.
//
// Four symmetric, independently stateful L=32 first-order Cartesian TIDSM
// branches receive offsets {+3,+1,-1,-3}*STEP.  Their phase-aligned raw
// 64-bit words are equal-weight code planes for four switching PA branches:
// normalized summation represents {-1,-0.5,0,+0.5,+1}.  Each word remains a
// 14-GS/s Fs/4 stream at a 218.75-MHz fabric clock; this module does not make
// a 14-GHz RF carrier and is not a BP/EFDSM recurrence.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_thermo5_fs4_multipa_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  parameter int STEP = 6144
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_poly_vec,
  output wire logic [3:0]                   pa_valid,
  output wire logic [2*CHANNELS-1:0]        pa_data [0:3],
  input  wire logic [3:0]                   pa_ready
);
  logic signed [CHANNELS*W-1:0] i_vec [0:3];
  logic signed [CHANNELS*W-1:0] q_vec [0:3];
  logic [3:0] branch_in_ready;
  logic common_ready;
  integer lane;

  function automatic logic signed [W-1:0] sat_offset(
    input logic signed [W-1:0] value,
    input logic signed [W:0] offset
  );
    logic signed [W:0] sum;
    begin
      sum = {value[W-1], value} + offset;
      if (sum > $signed({1'b0, {W-1{1'b1}}}))
        sat_offset = {1'b0, {W-1{1'b1}}};
      else if (sum < $signed({1'b1, {W-1{1'b0}}}))
        sat_offset = {1'b1, {W-1{1'b0}}};
      else
        sat_offset = sum[W-1:0];
    end
  endfunction

  always_comb begin
    for (lane = 0; lane < CHANNELS; lane = lane + 1) begin
      i_vec[0][lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W],  3*STEP);
      q_vec[0][lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W],  3*STEP);
      i_vec[1][lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W],    STEP);
      q_vec[1][lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W],    STEP);
      i_vec[2][lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W],   -STEP);
      q_vec[2][lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W],   -STEP);
      i_vec[3][lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W], -3*STEP);
      q_vec[3][lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W], -3*STEP);
    end
  end

  // All code planes are one thermometric symbol.  They may only advance or
  // stall together, otherwise PA timing skew changes the output level.
  assign common_ready = &pa_ready;
  assign in_ready = &branch_in_ready;

  genvar b;
  generate
    for (b = 0; b < 4; b = b + 1) begin : g_branch
      tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_tid (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid && in_ready),
        .in_ready(branch_in_ready[b]), .in_i_poly_vec(i_vec[b]),
        .in_q_poly_vec(q_vec[b]), .gt_valid(pa_valid[b]),
        .gt_ready(common_ready), .gt_data(pa_data[b])
      );
    end
  endgenerate
endmodule

`default_nettype wire
