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
  logic s1_valid, s2_valid;
  logic s1_start, s1_end, s1_tail;
  logic s2_start, s2_end, s2_tail;
  logic signed [2*LANES*W-1:0] s1_even_i, s1_even_q;
  logic signed [W:0] s1_a_i [0:LANES-1];
  logic signed [W:0] s1_a_q [0:LANES-1];
  logic signed [W:0] s1_b_i [0:LANES-1];
  logic signed [W:0] s1_b_q [0:LANES-1];
  logic s1_ready, s2_ready;
  logic signed [2*LANES*W-1:0] s1_input_even_i, s1_input_even_q;
  logic signed [W:0] s1_input_a_i [0:LANES-1];
  logic signed [W:0] s1_input_a_q [0:LANES-1];
  logic signed [W:0] s1_input_b_i [0:LANES-1];
  logic signed [W:0] s1_input_b_q [0:LANES-1];
  logic signed [2*LANES*W-1:0] s2_i, s2_q;

  wire logic tail_output = APPEND_TAIL_VECTOR && tail_pending_q;
  wire logic have_head = (q_count != 0);
  wire logic next_is_boundary = (q_count == 2) && q1_start;
  wire logic can_emit_head = ((q_count == 2) || ((q_count == 1) && q0_end)) &&
                             have_head && !q0_tail;
  wire logic drop_head_tail = have_head && q0_tail && !APPEND_TAIL_VECTOR;
  wire logic pop_head = drop_head_tail ||
                        (can_emit_head && !tail_output && out_ready && s1_ready && enable);
  wire logic push_input = in_valid && in_ready;
  wire logic tail_fire = tail_output && out_ready && s1_ready && enable;
  wire logic s1_load = tail_fire ||
                       (can_emit_head && !tail_output && out_ready && enable);
  wire logic head_final = q0_end || next_is_boundary;
  wire logic same_frame_next = (q_count == 2) && !q1_start;

  // Permit a full queue to accept its replacement word on the same edge that
  // the current head is consumed. Without this look-ahead credit the two-entry
  // queue alternates pop and push, limiting a no-stall stream to one vector
  // every two clocks after it fills.
  assign s2_ready = !s2_valid || out_ready;
  assign s1_ready = !s1_valid || s2_ready;
  assign in_ready = enable && ((q_count < 2) || pop_head);
  assign out_valid = enable && s2_valid;
  assign out_tail = out_valid && s2_tail;
  assign out_frame_start = out_valid && s2_start;
  assign out_frame_end = out_valid && s2_end;
  assign out_i_vec = s2_i;
  assign out_q_vec = s2_q;

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

  always_comb begin : p_stage1_inputs
    logic signed [W-1:0] xm1_i, xm1_q, xp1_i, xp1_q, xp2_i, xp2_q;
    xm1_i = '0;
    xm1_q = '0;
    xp1_i = '0;
    xp1_q = '0;
    xp2_i = '0;
    xp2_q = '0;
    s1_input_even_i = '0;
    s1_input_even_q = '0;
    for (int lane = 0; lane < LANES; lane = lane + 1) begin
      s1_input_a_i[lane] = '0;
      s1_input_a_q[lane] = '0;
      s1_input_b_i[lane] = '0;
      s1_input_b_q[lane] = '0;
    end

    if (tail_output) begin
      s1_input_b_i[0] = {tail_sample_i_q[W-1], tail_sample_i_q};
      s1_input_b_q[0] = {tail_sample_q_q[W-1], tail_sample_q_q};
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

        s1_input_even_i[(2*lane)*W +: W] = q0_i[lane];
        s1_input_even_q[(2*lane)*W +: W] = q0_q[lane];
        s1_input_a_i[lane] = {q0_i[lane][W-1], q0_i[lane]} + {xp1_i[W-1], xp1_i};
        s1_input_a_q[lane] = {q0_q[lane][W-1], q0_q[lane]} + {xp1_q[W-1], xp1_q};
        s1_input_b_i[lane] = {xm1_i[W-1], xm1_i} + {xp2_i[W-1], xp2_i};
        s1_input_b_q[lane] = {xm1_q[W-1], xm1_q} + {xp2_q[W-1], xp2_q};
      end
    end
  end

  function automatic logic signed [ACC_W-1:0] cubic_acc(
    input logic signed [W:0] a,
    input logic signed [W:0] b
  );
    logic signed [ACC_W-1:0] sa, sb;
    begin
      sa = {{(ACC_W-W-1){a[W]}},a};
      sb = {{(ACC_W-W-1){b[W]}},b};
      cubic_acc = ((sa <<< 3) + sa - sb) <<< 10;
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin : p_pipeline
    if (!rst_n) begin
      s1_valid <= 1'b0;
      s2_valid <= 1'b0;
      s1_start <= 1'b0;
      s1_end <= 1'b0;
      s1_tail <= 1'b0;
      s2_start <= 1'b0;
      s2_end <= 1'b0;
      s2_tail <= 1'b0;
      s1_even_i <= '0;
      s1_even_q <= '0;
      s2_i <= '0;
      s2_q <= '0;
      for (int lane = 0; lane < LANES; lane = lane + 1) begin
        s1_a_i[lane] <= '0;
        s1_a_q[lane] <= '0;
        s1_b_i[lane] <= '0;
        s1_b_q[lane] <= '0;
      end
    end else if (!enable) begin
      s1_valid <= 1'b0;
      s2_valid <= 1'b0;
      s1_start <= 1'b0;
      s1_end <= 1'b0;
      s1_tail <= 1'b0;
      s2_start <= 1'b0;
      s2_end <= 1'b0;
      s2_tail <= 1'b0;
      s1_even_i <= '0;
      s1_even_q <= '0;
      s2_i <= '0;
      s2_q <= '0;
    end else begin
      if (s2_ready) begin
        s2_valid <= s1_valid;
        if (s1_valid) begin
          s2_start <= s1_start;
          s2_end <= s1_end;
          s2_tail <= s1_tail;
          s2_i <= '0;
          s2_q <= '0;
          if (s1_tail) begin
            s2_i[W +: W] <= round_sat(cubic_acc(s1_a_i[0], s1_b_i[0]));
            s2_q[W +: W] <= round_sat(cubic_acc(s1_a_q[0], s1_b_q[0]));
          end else begin
            for (int lane = 0; lane < LANES; lane = lane + 1) begin
              s2_i[(2*lane)*W +: W] <= s1_even_i[(2*lane)*W +: W];
              s2_q[(2*lane)*W +: W] <= s1_even_q[(2*lane)*W +: W];
              s2_i[(2*lane+1)*W +: W] <= round_sat(cubic_acc(s1_a_i[lane], s1_b_i[lane]));
              s2_q[(2*lane+1)*W +: W] <= round_sat(cubic_acc(s1_a_q[lane], s1_b_q[lane]));
            end
          end
        end
      end
      if (s1_ready) begin
        s1_valid <= s1_load;
        if (s1_load) begin
          s1_start <= !tail_output && q0_start;
          s1_end <= tail_output || (!APPEND_TAIL_VECTOR &&
                    (q_count == 2) && q1_tail && !q0_tail);
          s1_tail <= tail_output;
          s1_even_i <= s1_input_even_i;
          s1_even_q <= s1_input_even_q;
          for (int lane = 0; lane < LANES; lane = lane + 1) begin
            s1_a_i[lane] <= s1_input_a_i[lane];
            s1_a_q[lane] <= s1_input_a_q[lane];
            s1_b_i[lane] <= s1_input_b_i[lane];
            s1_b_q[lane] <= s1_input_b_q[lane];
          end
        end
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

  property p_stage1_holds_while_stage2_stalls;
    @(posedge clk) disable iff (!rst_n || !enable)
      (s1_valid && !s2_ready) |=>
        (s1_valid && $stable({s1_start,s1_end,s1_tail,s1_even_i,s1_even_q}));
  endproperty
  assert property (p_stage1_holds_while_stage2_stalls)
    else $error("centered cubic stage 1 changed while stage 2 was stalled");

  property p_stage1_transfer_is_not_dropped;
    @(posedge clk) disable iff (!rst_n || !enable)
      (s1_valid && s2_ready) |=> s2_valid;
  endproperty
  assert property (p_stage1_transfer_is_not_dropped)
    else $error("centered cubic pipeline dropped a valid stage 1 transaction");

  property p_pipeline_flushes_on_disable;
    @(posedge clk) disable iff (!rst_n)
      !enable |=> (!s1_valid && !s2_valid);
  endproperty
  assert property (p_pipeline_flushes_on_disable)
    else $error("centered cubic pipeline did not flush on disable");

  property p_consumed_stage2_does_not_repeat;
    @(posedge clk) disable iff (!rst_n || !enable)
      (s2_valid && out_ready && !s1_valid) |=> !s2_valid;
  endproperty
  assert property (p_consumed_stage2_does_not_repeat)
    else $error("centered cubic pipeline duplicated a consumed transaction");

  for (genvar lane = 0; lane < LANES; lane = lane + 1) begin : g_pipe_hold_assert
    assert property (@(posedge clk) disable iff (!rst_n || !enable)
      (s1_valid && !s2_ready) |=>
        $stable({s1_a_i[lane],s1_a_q[lane],s1_b_i[lane],s1_b_q[lane]}))
      else $error("centered cubic stage 1 arithmetic changed while stalled");
  end
`endif
endmodule

`default_nettype wire
