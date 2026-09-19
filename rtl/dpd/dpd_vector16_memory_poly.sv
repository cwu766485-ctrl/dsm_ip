`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// 16-consecutive-sample memory-polynomial DPD.
//
// Each lane receives its actual temporal input window.  The shared three
// sample history is updated only when a whole word is accepted.  Therefore
// lane 0 consumes the preceding word history, while lane k consumes lanes
// k-1, k-2, ... from the current word.  This is the exact packed equivalent
// of one scalar memory-polynomial stream, not 16 independent DPDs.
//------------------------------------------------------------------------------
module dpd_vector16_memory_poly #(
  parameter int W = 16,
  parameter int LANES = 16,
  parameter int COEFF_W = 16,
  parameter int COEFF_FRAC = 14,
  parameter int MAX_TAPS = 4
) (
  input  wire logic                                      clk,
  input  wire logic                                      rst_n,
  input  wire logic [2:0]                                active_taps,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c1_re, c1_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c3_re, c3_im,
  input  wire logic signed [MAX_TAPS*COEFF_W-1:0]        c5_re, c5_im,
  input  wire logic                                      in_valid,
  output wire logic                                      in_ready,
  input  wire logic signed [LANES*W-1:0]                 in_i_vec,
  input  wire logic signed [LANES*W-1:0]                 in_q_vec,
  output wire logic                                      out_valid,
  input  wire logic                                      out_ready,
  output wire logic signed [LANES*W-1:0]                 out_i_vec,
  output wire logic signed [LANES*W-1:0]                 out_q_vec
);
  localparam int HISTORY = (MAX_TAPS > 1) ? MAX_TAPS-1 : 1;
  logic signed [W-1:0] history_i [0:HISTORY-1];
  logic signed [W-1:0] history_q [0:HISTORY-1];
  logic [LANES-1:0] lane_in_ready, lane_out_valid;
  logic signed [LANES*MAX_TAPS*W-1:0] lane_i_taps, lane_q_taps;

  assign in_ready = &lane_in_ready;
  assign out_valid = &lane_out_valid;

  always_comb begin
    for (int lane = 0; lane < LANES; lane = lane + 1) begin
      for (int tap = 0; tap < MAX_TAPS; tap = tap + 1) begin
        if (tap <= lane) begin
          lane_i_taps[(lane*MAX_TAPS+tap)*W +: W] = in_i_vec[(lane-tap)*W +: W];
          lane_q_taps[(lane*MAX_TAPS+tap)*W +: W] = in_q_vec[(lane-tap)*W +: W];
        end else begin
          lane_i_taps[(lane*MAX_TAPS+tap)*W +: W] = history_i[tap-lane-1];
          lane_q_taps[(lane*MAX_TAPS+tap)*W +: W] = history_q[tap-lane-1];
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int h = 0; h < HISTORY; h = h + 1) begin
        history_i[h] <= '0;
        history_q[h] <= '0;
      end
    end else if (in_valid && in_ready) begin
      for (int h = 0; h < HISTORY; h = h + 1) begin
        if (h < LANES) begin
          history_i[h] <= in_i_vec[(LANES-1-h)*W +: W];
          history_q[h] <= in_q_vec[(LANES-1-h)*W +: W];
        end else begin
          history_i[h] <= history_i[h-LANES];
          history_q[h] <= history_q[h-LANES];
        end
      end
    end
  end

  for (genvar lane = 0; lane < LANES; lane = lane + 1) begin : g_lane
    dpd_memory_poly #(
      .W(W), .COEFF_W(COEFF_W), .COEFF_FRAC(COEFF_FRAC),
      .MAX_TAPS(MAX_TAPS), .USE_EXTERNAL_TAPS(1)
    ) u_dpd (
      .clk(clk), .rst_n(rst_n), .active_taps(active_taps),
      .c1_re(c1_re), .c1_im(c1_im), .c3_re(c3_re), .c3_im(c3_im),
      .c5_re(c5_re), .c5_im(c5_im),
      .i_in(in_i_vec[lane*W +: W]), .q_in(in_q_vec[lane*W +: W]),
      .i_tap_vec(lane_i_taps[(lane*MAX_TAPS)*W +: MAX_TAPS*W]),
      .q_tap_vec(lane_q_taps[(lane*MAX_TAPS)*W +: MAX_TAPS*W]),
      .in_valid(in_valid && in_ready), .in_ready(lane_in_ready[lane]),
      .i_out(out_i_vec[lane*W +: W]), .q_out(out_q_vec[lane*W +: W]),
      .out_valid(lane_out_valid[lane]), .out_ready(out_ready),
      .sample_count(), .saturation_count()
    );
  end
endmodule

`default_nettype wire
