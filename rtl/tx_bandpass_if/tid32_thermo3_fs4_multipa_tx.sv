//------------------------------------------------------------------------------
// Thermometer-coded three-level Cartesian TID transmitter.
//
// Two independently stateful L=32 first-order Cartesian TIDSM branches use
// symmetric signed input thresholds. The two 64-bit raw-GT words must be sent
// through phase-aligned serializers and combined by equal-amplitude 1-bit PA
// branches; their normalized sum represents {-1,0,+1}. This wrapper does not
// implement BP-EFDSM2/4 and must not be substituted for either architecture.
//------------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tid32_thermo3_fs4_multipa_tx #(
  parameter int W = 16,
  parameter int CHANNELS = 32,
  parameter int THRESHOLD = 8192
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic signed [CHANNELS*W-1:0] in_i_poly_vec,
  input  wire logic signed [CHANNELS*W-1:0] in_q_poly_vec,
  output wire logic                         pa_p_valid,
  output wire logic [2*CHANNELS-1:0]        pa_p_data,
  input  wire logic                         pa_p_ready,
  output wire logic                         pa_m_valid,
  output wire logic [2*CHANNELS-1:0]        pa_m_data,
  input  wire logic                         pa_m_ready
);
  logic signed [CHANNELS*W-1:0] i_p_vec, q_p_vec, i_m_vec, q_m_vec;
  logic p_in_ready, m_in_ready, common_ready;
  integer lane;

  function automatic logic signed [W-1:0] sat_offset(
    input logic signed [W-1:0] value,
    input logic signed [W:0] offset
  );
    logic signed [W:0] sum;
    begin
      sum = {value[W-1], value} + offset;
      if (sum > $signed({1'b0, {W-1{1'b1}}})) begin
        sat_offset = {1'b0, {W-1{1'b1}}};
      end else if (sum < $signed({1'b1, {W-1{1'b0}}})) begin
        sat_offset = {1'b1, {W-1{1'b0}}};
      end else begin
        sat_offset = sum[W-1:0];
      end
    end
  endfunction

  always_comb begin
    for (lane = 0; lane < CHANNELS; lane = lane + 1) begin
      i_p_vec[lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W], THRESHOLD);
      q_p_vec[lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W], THRESHOLD);
      i_m_vec[lane*W +: W] = sat_offset(in_i_poly_vec[lane*W +: W], -THRESHOLD);
      q_m_vec[lane*W +: W] = sat_offset(in_q_poly_vec[lane*W +: W], -THRESHOLD);
    end
  end

  // Both raw words must advance together so two physical serializer/PA paths
  // retain word and sample alignment even when either downstream path stalls.
  assign common_ready = pa_p_ready && pa_m_ready;
  assign in_ready = p_in_ready && m_in_ready;

  tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_p (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid && in_ready), .in_ready(p_in_ready),
    .in_i_poly_vec(i_p_vec), .in_q_poly_vec(q_p_vec), .gt_valid(pa_p_valid),
    .gt_ready(common_ready), .gt_data(pa_p_data)
  );

  tid32_cartesian_fs4_gt_tx #(.W(W), .CHANNELS(CHANNELS)) u_m (
    .clk(clk), .rst_n(rst_n), .in_valid(in_valid && in_ready), .in_ready(m_in_ready),
    .in_i_poly_vec(i_m_vec), .in_q_poly_vec(q_m_vec), .gt_valid(pa_m_valid),
    .gt_ready(common_ready), .gt_data(pa_m_data)
  );
endmodule

`default_nettype wire
