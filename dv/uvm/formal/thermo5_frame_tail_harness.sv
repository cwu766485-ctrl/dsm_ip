`timescale 1ns/1ps
// Module-level reachability check for the parameter split used by the two
// centered-cubic stages. This proves tail-append reachability at each selected
// parameter value; it does not prove end-to-end composition between stages.
module thermo5_frame_tail_harness (
  input logic clk, rst_n, enable,
  input logic in_valid, in_frame_start, in_frame_end, in_tail,
  input logic signed [127:0] in_i_vec, in_q_vec,
  input logic out_ready
);
  wire append_ready, append_valid, append_start, append_end, append_tail;
  wire signed [255:0] append_i, append_q;
  wire plain_ready, plain_valid, plain_start, plain_end, plain_tail;
  wire signed [255:0] plain_i, plain_q;

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(8), .APPEND_TAIL_VECTOR(1'b1)
  ) append_stage (
    .clk, .rst_n, .enable, .in_valid, .in_ready(append_ready),
    .in_frame_start, .in_frame_end, .in_tail(1'b0), .in_i_vec, .in_q_vec,
    .out_valid(append_valid), .out_frame_start(append_start),
    .out_frame_end(append_end), .out_tail(append_tail), .out_ready,
    .out_i_vec(append_i), .out_q_vec(append_q)
  );

  dsm_interp_x2_centered_cubic_vector #(
    .W(16), .LANES(8), .APPEND_TAIL_VECTOR(1'b0)
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
  a_plain_append_arm_disabled: assert property (disable iff (!rst_n)
    !plain_stage.APPEND_TAIL_VECTOR);
  c_append_tail_head_drop_unreachable: cover property (disable iff (!rst_n)
    append_stage.pop_head && append_stage.q0_tail);
  c_plain_tail_fire_unreachable: cover property (disable iff (!rst_n)
    plain_stage.tail_fire);
  c_plain_append_tail_arm_unreachable: cover property (disable iff (!rst_n)
    plain_stage.APPEND_TAIL_VECTOR && plain_stage.head_final);
endmodule
