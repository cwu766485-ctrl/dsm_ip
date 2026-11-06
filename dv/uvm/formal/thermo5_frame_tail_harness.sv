`timescale 1ns/1ps
// Module-level reachability check for the product parameter split used by the
// two centered-cubic stages: stage 1 is W=16/LANES=8 with tail append enabled;
// stage 2 is W=16/LANES=16 with tail append disabled. This does not prove
// end-to-end composition between stages.
module thermo5_frame_tail_harness (
  input logic clk, rst_n, enable,
  input logic in_valid, in_frame_start, in_frame_end, in_tail,
  input logic signed [255:0] in_i_vec, in_q_vec,
  input logic out_ready
);
  wire append_ready, append_valid, append_start, append_end, append_tail;
  wire signed [255:0] append_i, append_q;
  wire plain_ready, plain_valid, plain_start, plain_end, plain_tail;
  wire signed [511:0] plain_i, plain_q;

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(8), .APPEND_TAIL_VECTOR(1'b1)
  ) append_stage (
    .clk, .rst_n, .enable, .in_valid, .in_ready(append_ready),
    .in_frame_start, .in_frame_end, .in_tail(1'b0),
    .in_i_vec(in_i_vec[127:0]), .in_q_vec(in_q_vec[127:0]),
    .out_valid(append_valid), .out_frame_start(append_start),
    .out_frame_end(append_end), .out_tail(append_tail), .out_ready,
    .out_i_vec(append_i), .out_q_vec(append_q)
  );

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(16), .APPEND_TAIL_VECTOR(1'b0)
  ) plain_stage (
    .clk, .rst_n, .enable, .in_valid, .in_ready(plain_ready),
    .in_frame_start, .in_frame_end, .in_tail, .in_i_vec, .in_q_vec,
    .out_valid(plain_valid), .out_frame_start(plain_start),
    .out_frame_end(plain_end), .out_tail(plain_tail), .out_ready,
    .out_i_vec(plain_i), .out_q_vec(plain_q)
  );

  default clocking cb @(posedge clk); endclocking

  // Hold payload while either instance is stalled.
  asm_source_stable: assume property (disable iff (!rst_n)
    in_valid && (!append_ready || !plain_ready)
      |=> in_valid && $stable({in_frame_start,in_frame_end,in_tail,in_i_vec,in_q_vec}));

  a_append_tail_consistent: assert property (disable iff (!rst_n)
    append_tail == (append_valid && append_stage.tail_output));
  a_append_tail_clears: assert property (disable iff (!rst_n)
    append_stage.tail_output && enable && out_ready |=> !append_stage.tail_pending_q);
  a_plain_tail_disabled: assert property (disable iff (!rst_n)
    !plain_stage.tail_output && !plain_tail);

  c_append_frame_end: cover property (disable iff (!rst_n)
    in_valid && append_ready && in_frame_end);
  c_append_tail_transfer: cover property (disable iff (!rst_n)
    append_valid && append_tail && out_ready);
  c_plain_frame_end: cover property (disable iff (!rst_n)
    in_valid && plain_ready && in_frame_end);
  c_plain_tail_unreachable: cover property (disable iff (!rst_n)
    plain_stage.tail_output);
  // These covers target the line-182 single-entry queue transition in both
  // elaborated product stage configurations. They require a real accepted
  // input on the same edge that a legal frame-ending head is consumed.
  c_append_single_pop_push: cover property (disable iff (!rst_n)
    append_stage.q_count == 1 && append_stage.pop_head &&
    append_stage.push_input);
  c_plain_single_pop_push: cover property (disable iff (!rst_n)
    plain_stage.q_count == 1 && plain_stage.pop_head &&
    plain_stage.push_input);
  a_append_no_input_tail: assert property (disable iff (!rst_n)
    !append_stage.q0_tail);
  a_plain_tail_fire_disabled: assert property (disable iff (!rst_n)
    !plain_stage.tail_fire);
  // Check the sequential consequence of APPEND_TAIL_VECTOR=0 instead of
  // asserting the constant parameter itself (which Formal reports as tautology).
  a_plain_tail_pending_never_set: assert property (disable iff (!rst_n)
    !plain_stage.tail_pending_q);
  c_append_tail_head_drop_unreachable: cover property (disable iff (!rst_n)
    append_stage.pop_head && append_stage.q0_tail);
  c_plain_tail_fire_unreachable: cover property (disable iff (!rst_n)
    plain_stage.tail_fire);
  c_plain_append_tail_arm_unreachable: cover property (disable iff (!rst_n)
    plain_stage.pop_head && !plain_stage.q0_tail &&
    plain_stage.APPEND_TAIL_VECTOR && plain_stage.head_final);
endmodule

// Legal metadata schedules for the two product centered-cubic stages. This
// harness targets the line-309 assertion antecedent without constraining data,
// bubble length, or output backpressure. Stage 1 accepts 7 vectors per
// 56-sample frame, with frame_start on each frame's first vector. An AXI packet
// contains 8 such frames (56 stage-1 vectors), so frame_end is asserted only
// on the final vector of that packet. The stage appends one synthetic tail at
// each frame_start boundary and at the packet end. Stage 2 therefore accepts
// 7 real 16-lane vectors plus one stage-1 tail for each DSP frame; frame_end
// and in_tail coincide on its eighth accepted vector.
// The stage-1 output markers feed the production stage-2 RTL directly. This
// composes the two interpolation blocks and their backpressure; the intervening
// elastic FIFOs and identity DPD metadata pass-through are not instantiated.
module thermo5_frame_tail_legal_metadata_harness (
  input logic clk, rst_n, in_valid, out_ready
);
  logic [2:0] append_frame_phase;
  logic [2:0] append_packet_frame;
  wire append_in_ready, append_out_valid, append_out_start, append_out_end, append_out_tail;
  wire plain_in_ready, plain_out_valid, plain_out_start, plain_out_end, plain_out_tail;
  wire [255:0] append_out_i, append_out_q;
  wire [511:0] plain_out_i, plain_out_q;
  wire append_start = (append_frame_phase == 0);
  wire append_end = (append_frame_phase == 6) && (append_packet_frame == 7);
  wire append_fire = in_valid && append_in_ready;

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(8), .APPEND_TAIL_VECTOR(1'b1)
  ) append_stage (
    .clk, .rst_n, .enable(1'b1),
    .in_valid, .in_ready(append_in_ready),
    .in_frame_start(append_start), .in_frame_end(append_end), .in_tail(1'b0),
    .in_i_vec(128'b0), .in_q_vec(128'b0),
    .out_valid(append_out_valid), .out_frame_start(append_out_start),
    .out_frame_end(append_out_end), .out_tail(append_out_tail),
    .out_ready(plain_in_ready), .out_i_vec(append_out_i), .out_q_vec(append_out_q)
  );

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(16), .APPEND_TAIL_VECTOR(1'b0)
  ) plain_stage (
    .clk, .rst_n, .enable(1'b1),
    .in_valid(append_out_valid), .in_ready(plain_in_ready),
    .in_frame_start(append_out_start), .in_frame_end(append_out_tail),
    .in_tail(append_out_tail),
    .in_i_vec(256'b0), .in_q_vec(256'b0),
    .out_valid(plain_out_valid), .out_frame_start(plain_out_start),
    .out_frame_end(plain_out_end), .out_tail(plain_out_tail),
    .out_ready, .out_i_vec(plain_out_i), .out_q_vec(plain_out_q)
  );

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      append_frame_phase <= 0;
      append_packet_frame <= 0;
    end else begin
      if (append_fire) begin
        if (append_frame_phase == 6) begin
          append_frame_phase <= 0;
          append_packet_frame <= (append_packet_frame == 7) ? 0 : append_packet_frame + 1'b1;
        end else begin
          append_frame_phase <= append_frame_phase + 1'b1;
        end
      end
    end
  end

  default clocking cb @(posedge clk); endclocking

  // The sole environment assumption is the legal source ready/valid contract.
  // Both interpolator stages are composed; downstream ready exercises stalls
  // through the chain without imposing a source-gap bound.
  asm_source_valid_stable: assume property (disable iff (!rst_n)
    in_valid && !append_in_ready |=> in_valid);

  a_append_legal_frame_end_context: assert property (rst_n |->
    !(append_stage.q_count == 2 && append_stage.q0_end && !append_stage.q1_start));
  a_plain_legal_frame_end_context: assert property (rst_n |->
    !(plain_stage.q_count == 2 && plain_stage.q0_end && !plain_stage.q1_start));

  c_append_subframe_start: cover property (disable iff (!rst_n)
    append_fire && append_start && append_packet_frame == 1);
  c_append_packet_end: cover property (disable iff (!rst_n)
    append_fire && append_end);
  c_append_tail_transfer: cover property (disable iff (!rst_n)
    append_out_valid && append_out_tail && plain_in_ready);
  c_plain_tail_consumed: cover property (disable iff (!rst_n)
    plain_stage.drop_head_tail);
  c_append_output_transfer: cover property (disable iff (!rst_n)
    append_out_valid && plain_in_ready);
  c_plain_output_transfer: cover property (disable iff (!rst_n)
    plain_out_valid && out_ready);
  c_append_active_bin: cover property (disable iff (!rst_n)
    append_stage.q_count == 2 && append_stage.q0_end && !append_stage.q1_start);
  c_plain_active_bin: cover property (disable iff (!rst_n)
    plain_stage.q_count == 2 && plain_stage.q0_end && !plain_stage.q1_start);
endmodule

// Runtime asynchronous-reset reachability for the reset-low condition vectors
// at line 309. boot_n supplies the initial formal reset; reset_request is a
// separate unconstrained runtime request sampled on the inactive clock edge,
// so reset assertion cannot race the line-309 active-edge sample.
module thermo5_frame_tail_reset_condition_harness (
  input logic clk, boot_n, reset_request,
  input logic enable, in_valid, in_frame_start, in_frame_end, in_tail,
  input logic out_ready
);
  logic rst_n;
  wire append_ready, append_valid, append_start, append_end, append_tail;
  wire plain_ready, plain_valid, plain_start, plain_end, plain_tail;
  wire [255:0] append_i, append_q;
  wire [511:0] plain_i, plain_q;

  always @(negedge clk or negedge boot_n) begin
    if (!boot_n) rst_n <= 1'b0;
    else rst_n <= !reset_request;
  end

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(8), .APPEND_TAIL_VECTOR(1'b1)
  ) append_stage (
    .clk, .rst_n, .enable, .in_valid, .in_ready(append_ready),
    .in_frame_start, .in_frame_end, .in_tail(1'b0),
    .in_i_vec(128'b0), .in_q_vec(128'b0),
    .out_valid(append_valid), .out_frame_start(append_start),
    .out_frame_end(append_end), .out_tail(append_tail), .out_ready,
    .out_i_vec(append_i), .out_q_vec(append_q)
  );

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(16), .APPEND_TAIL_VECTOR(1'b0)
  ) plain_stage (
    .clk, .rst_n, .enable, .in_valid, .in_ready(plain_ready),
    .in_frame_start, .in_frame_end, .in_tail, .in_i_vec(256'b0), .in_q_vec(256'b0),
    .out_valid(plain_valid), .out_frame_start(plain_start),
    .out_frame_end(plain_end), .out_tail(plain_tail), .out_ready,
    .out_i_vec(plain_i), .out_q_vec(plain_q)
  );

  default clocking cb @(posedge clk); endclocking

  a_append_reset_empty: assert property (!rst_n |-> append_stage.q_count == 0);
  a_plain_reset_empty: assert property (!rst_n |-> plain_stage.q_count == 0);

  c_append_queue_nonempty: cover property (rst_n && append_stage.q_count == 2);
  c_append_runtime_reset: cover property (
    rst_n && append_stage.q_count == 2 ##1 !rst_n);
  c_append_reset_empty: cover property (!rst_n && append_stage.q_count == 0);
  c_append_reset_bin: cover property (!rst_n && append_stage.q_count == 2 &&
    append_stage.q0_end && !append_stage.q1_start);

  c_plain_queue_nonempty: cover property (rst_n && plain_stage.q_count == 2);
  c_plain_runtime_reset: cover property (
    rst_n && plain_stage.q_count == 2 ##1 !rst_n);
  c_plain_reset_empty: cover property (!rst_n && plain_stage.q_count == 0);
  c_plain_reset_bin: cover property (!rst_n && plain_stage.q_count == 2 &&
    plain_stage.q0_end && !plain_stage.q1_start);
endmodule
