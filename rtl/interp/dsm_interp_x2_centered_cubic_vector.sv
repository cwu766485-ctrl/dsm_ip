`timescale 1ns/1ps
`default_nettype none

//------------------------------------------------------------------------------
// Streaming x2 centered cubic interpolator for packed complex-sample vectors.
//
// Lane 0 is earliest. Each input vector produces one output vector containing
// phase-0 exact samples followed by phase-1 midpoint estimates. Phase 1 uses
// x[n-1], x[n], x[n+1], x[n+2] with Q14 coefficients [-1,9,9,-1]/16.
//
// Two input vectors are retained so the last two lanes can use future samples
// from the following transaction. `in_frame_start` selects zero history at a
// new frame. A frame boundary is either `in_frame_end` or the next vector's
// `in_frame_start`. The first-stage instance appends a synthetic zero-source
// vector after each frame so the following x2 stage can reconstruct its last
// two real outputs; `out_tail` identifies that lookahead-only vector. A later
// stage consumes and drops the tail after using it as lookahead.
//
// Arithmetic rounds to nearest with ties away from zero and saturates to W
// bits, matching the Python fixed-point model. This module adds transaction
// latency but sustains one vector per cycle when downstream remains ready.
//------------------------------------------------------------------------------
module dsm_interp_x2_centered_cubic_vector #(
  parameter int W = 16,
  parameter int LANES = 8,
  parameter int COEFF_FRAC = 14,
  parameter bit APPEND_TAIL_VECTOR = 1'b0,
  parameter bit HOLD_STATE_ON_DISABLE = 1'b0
) (
  input  wire logic                         clk,
  input  wire logic                         rst_n,
  input  wire logic                         enable,
  input  wire logic                         in_valid,
  output wire logic                         in_ready,
  input  wire logic                         in_frame_start,
  input  wire logic                         in_frame_end,
  input  wire logic                         in_tail,
  input  wire logic signed [LANES*W-1:0]    in_i_vec,
  input  wire logic signed [LANES*W-1:0]    in_q_vec,
  output wire logic                         out_valid,
  output wire logic                         out_frame_start,
  output wire logic                         out_frame_end,
  output wire logic                         out_tail,
  input  wire logic                         out_ready,
  output logic signed [2*LANES*W-1:0]      out_i_vec,
  output logic signed [2*LANES*W-1:0]      out_q_vec
);
  localparam int ACC_W = W + COEFF_FRAC + 3;
  localparam logic signed [ACC_W-1:0] C_M1 = -1024;
  localparam logic signed [ACC_W-1:0] C_0  =  9216;
  localparam logic signed [ACC_W-1:0] C_P1 =  9216;
  localparam logic signed [ACC_W-1:0] C_P2 = -1024;

  logic [1:0] q_count;
  logic q0_start, q0_end, q0_tail;
  logic q1_start, q1_end, q1_tail;
  logic signed [W-1:0] q0_i [0:LANES-1];
  logic signed [W-1:0] q0_q [0:LANES-1];
  logic signed [W-1:0] q1_i [0:LANES-1];
  logic signed [W-1:0] q1_q [0:LANES-1];
  logic signed [W-1:0] history_i, history_q;
  logic tail_pending_q;
  logic signed [W-1:0] tail_sample_i_q, tail_sample_q_q;

  wire logic tail_output = APPEND_TAIL_VECTOR && tail_pending_q;
  wire logic have_head = (q_count != 0);
  wire logic next_is_boundary = (q_count == 2) && q1_start;
  wire logic can_emit_head = ((q_count == 2) || ((q_count == 1) && q0_end)) &&
                             have_head && !q0_tail;
  wire logic drop_head_tail = have_head && q0_tail && !APPEND_TAIL_VECTOR;
  wire logic pop_head = drop_head_tail ||
                        (can_emit_head && !tail_output && out_ready && enable);
  wire logic push_input = in_valid && in_ready;
  wire logic tail_fire = tail_output && out_ready && enable;
  wire logic head_final = q0_end || next_is_boundary;
  wire logic same_frame_next = (q_count == 2) && !q1_start;

  // Permit a full queue to accept its replacement word on the same edge that
  // the current head is consumed. Without this look-ahead credit the two-entry
  // queue alternates pop and push, limiting a no-stall stream to one vector
  // every two clocks after it fills.
  assign in_ready = enable && ((q_count < 2) || pop_head);
  assign out_valid = enable && (tail_output || can_emit_head);
  assign out_tail = out_valid && tail_output;
  assign out_frame_start = out_valid && !tail_output && q0_start;
  assign out_frame_end = out_valid &&
                         (tail_output || (!APPEND_TAIL_VECTOR &&
                          (q_count == 2) && q1_tail && !q0_tail));

  function automatic logic signed [W-1:0] round_sat(
    input logic signed [ACC_W-1:0] value
  );
    logic signed [ACC_W-1:0] rounded, maxv, minv;
    begin
      if (value >= 0)
        rounded = (value + ({{(ACC_W-1){1'b0}},1'b1} <<< (COEFF_FRAC-1))) >>> COEFF_FRAC;
      else
        rounded = -(((-value) + ({{(ACC_W-1){1'b0}},1'b1} <<< (COEFF_FRAC-1))) >>> COEFF_FRAC);
      maxv = ({{(ACC_W-1){1'b0}},1'b1} <<< (W-1)) - 1;
      minv = -({{(ACC_W-1){1'b0}},1'b1} <<< (W-1));
      if (rounded > maxv) round_sat = maxv[W-1:0];
      else if (rounded < minv) round_sat = minv[W-1:0];
      else round_sat = rounded[W-1:0];
    end
  endfunction

  function automatic logic signed [W-1:0] cubic_midpoint(
    input logic signed [W-1:0] xm1,
    input logic signed [W-1:0] x0,
    input logic signed [W-1:0] xp1,
    input logic signed [W-1:0] xp2
  );
    logic signed [ACC_W-1:0] sxm1, sx0, sxp1, sxp2, acc;
    begin
      sxm1 = {{(ACC_W-W){xm1[W-1]}},xm1};
      sx0  = {{(ACC_W-W){x0[W-1]}},x0};
      sxp1 = {{(ACC_W-W){xp1[W-1]}},xp1};
      sxp2 = {{(ACC_W-W){xp2[W-1]}},xp2};
      acc = sxm1*C_M1 + sx0*C_0 + sxp1*C_P1 + sxp2*C_P2;
      cubic_midpoint = round_sat(acc);
    end
  endfunction

  always_comb begin : p_output_data
    logic signed [W-1:0] xm1_i, xm1_q, xp1_i, xp1_q, xp2_i, xp2_q;
    out_i_vec = '0;
    out_q_vec = '0;

    if (tail_output) begin
      // One synthetic zero-source vector has only one nonzero interpolated
      // sample: the midpoint immediately following the real frame's tail.
      out_i_vec[W +: W] = cubic_midpoint(tail_sample_i_q, '0, '0, '0);
      out_q_vec[W +: W] = cubic_midpoint(tail_sample_q_q, '0, '0, '0);
    end else if (can_emit_head) begin
      for (int lane = 0; lane < LANES; lane = lane + 1) begin
        if (lane == 0) begin
          xm1_i = q0_start ? '0 : history_i;
          xm1_q = q0_start ? '0 : history_q;
        end else begin
          xm1_i = q0_i[lane-1];
          xm1_q = q0_q[lane-1];
        end

        if (lane + 1 < LANES) begin
          xp1_i = q0_i[lane+1];
          xp1_q = q0_q[lane+1];
        end else if (same_frame_next) begin
          xp1_i = q1_i[0];
          xp1_q = q1_q[0];
        end else begin
          xp1_i = '0;
          xp1_q = '0;
        end

        if (lane + 2 < LANES) begin
          xp2_i = q0_i[lane+2];
          xp2_q = q0_q[lane+2];
        end else if (same_frame_next) begin
          if (lane + 2 == LANES) begin
            xp2_i = q1_i[0];
            xp2_q = q1_q[0];
          end else begin
            xp2_i = q1_i[1];
            xp2_q = q1_q[1];
          end
        end else begin
          xp2_i = '0;
          xp2_q = '0;
        end

        out_i_vec[(2*lane)*W +: W] = q0_i[lane];
        out_q_vec[(2*lane)*W +: W] = q0_q[lane];
        out_i_vec[(2*lane+1)*W +: W] = cubic_midpoint(
          xm1_i, q0_i[lane], xp1_i, xp2_i);
        out_q_vec[(2*lane+1)*W +: W] = cubic_midpoint(
          xm1_q, q0_q[lane], xp1_q, xp2_q);
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin : p_queue
    if (!rst_n) begin
      q_count <= 0;
      q0_start <= 1'b0;
      q0_end <= 1'b0;
      q0_tail <= 1'b0;
      q1_start <= 1'b0;
      q1_end <= 1'b0;
      q1_tail <= 1'b0;
      history_i <= '0;
      history_q <= '0;
      tail_pending_q <= 1'b0;
      tail_sample_i_q <= '0;
      tail_sample_q_q <= '0;
      for (int lane = 0; lane < LANES; lane = lane + 1) begin
        q0_i[lane] <= '0;
        q0_q[lane] <= '0;
        q1_i[lane] <= '0;
        q1_q[lane] <= '0;
      end
    end else if (!enable) begin
      q_count <= 0;
      q0_start <= 1'b0;
      q0_end <= 1'b0;
      q0_tail <= 1'b0;
      q1_start <= 1'b0;
      q1_end <= 1'b0;
      q1_tail <= 1'b0;
      tail_pending_q <= 1'b0;
      if (!HOLD_STATE_ON_DISABLE) begin
        history_i <= '0;
        history_q <= '0;
        tail_sample_i_q <= '0;
        tail_sample_q_q <= '0;
      end
    end else begin
      if (tail_fire)
        tail_pending_q <= 1'b0;

      if (pop_head && !q0_tail) begin
        history_i <= q0_i[LANES-1];
        history_q <= q0_q[LANES-1];
        if (APPEND_TAIL_VECTOR && head_final) begin
          tail_pending_q <= 1'b1;
          tail_sample_i_q <= q0_i[LANES-1];
          tail_sample_q_q <= q0_q[LANES-1];
        end
      end
      if (pop_head && q0_tail) begin
        history_i <= '0;
        history_q <= '0;
      end

      if (pop_head) begin
        if (q_count == 2) begin
          q0_start <= q1_start;
          q0_end <= q1_end;
          q0_tail <= q1_tail;
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            q0_i[lane] <= q1_i[lane];
            q0_q[lane] <= q1_q[lane];
          end
          if (push_input) begin
            q1_start <= in_frame_start;
            q1_end <= in_frame_end;
            q1_tail <= in_tail;
            for (int lane = 0; lane < LANES; lane = lane + 1) begin
              q1_i[lane] <= in_i_vec[lane*W +: W];
              q1_q[lane] <= in_q_vec[lane*W +: W];
            end
            q_count <= 2;
          end else begin
            q_count <= 1;
          end
        end else if (push_input) begin
          q0_start <= in_frame_start;
          q0_end <= in_frame_end;
          q0_tail <= in_tail;
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            q0_i[lane] <= in_i_vec[lane*W +: W];
            q0_q[lane] <= in_q_vec[lane*W +: W];
          end
          q_count <= 1;
        end else begin
          q_count <= 0;
        end
      end else if (push_input) begin
        if (q_count == 0) begin
          q0_start <= in_frame_start;
          q0_end <= in_frame_end;
          q0_tail <= in_tail;
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            q0_i[lane] <= in_i_vec[lane*W +: W];
            q0_q[lane] <= in_q_vec[lane*W +: W];
          end
          q_count <= 1;
        end else begin
          q1_start <= in_frame_start;
          q1_end <= in_frame_end;
          q1_tail <= in_tail;
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            q1_i[lane] <= in_i_vec[lane*W +: W];
            q1_q[lane] <= in_q_vec[lane*W +: W];
          end
          q_count <= 2;
        end
      end
    end
  end

`ifndef SYNTHESIS
  logic stalled_last;
  initial begin
    if (LANES < 2) $error("centered cubic interpolator requires LANES >= 2");
    if (COEFF_FRAC != 14) $error("centered cubic coefficients require Q14");
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) stalled_last <= 1'b0;
    else stalled_last <= enable && out_valid && !out_ready;
  end

  always_ff @(posedge clk) begin
    if (rst_n && stalled_last) begin
      assert ($stable(out_i_vec) && $stable(out_q_vec) &&
              $stable(out_frame_start) && $stable(out_frame_end) && $stable(out_tail))
        else $error("centered cubic output changed while backpressured");
    end
    if (rst_n && q_count == 2 && q0_end && !q1_start)
      assert (q1_tail)
        else $error("centered cubic frame-end vector was followed by same-frame data");
  end
`endif
endmodule

`default_nettype wire
