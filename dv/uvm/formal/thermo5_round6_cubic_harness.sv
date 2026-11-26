`timescale 1ns/1ps
`default_nettype none

module thermo5_round6_cubic_harness (
  input logic clk, rst_n, enable, in_valid, out_ready,
  input logic in_frame_start, in_frame_end, in_tail
);
  // Only stage 1 ties off the input tail. Leave stage 2 metadata and both
  // downstream ready inputs unrestricted in this local control proof.
  for (genvar stage = 1; stage <= 2; stage++) begin : g_stage
    localparam int LANES = 8 * stage;
    localparam bit APPEND = stage == 1;

    dsm_interp_x2_centered_cubic_vector #(
      .W(16), .LANES(LANES), .COEFF_FRAC(14), .APPEND_TAIL_VECTOR(APPEND)
    ) dut (
      .clk(clk), .rst_n(rst_n), .enable(enable), .in_valid(in_valid),
      .in_ready(), .in_frame_start(in_frame_start), .in_frame_end(in_frame_end),
      .in_tail(APPEND ? 1'b0 : in_tail),
      .in_i_vec({LANES*16{1'b0}}), .in_q_vec({LANES*16{1'b0}}),
      .out_valid(), .out_frame_start(), .out_frame_end(), .out_tail(),
      .out_ready(out_ready), .out_i_vec(), .out_q_vec()
    );

    if (APPEND) begin : g_append
      a_input_tail_never_latched: assert property (@(posedge clk) disable iff (!rst_n)
        !dut.q0_tail && !dut.q1_tail);
      c_tail_emit: cover property (@(posedge clk) disable iff (!rst_n)
        dut.tail_fire);
    end else begin : g_consume
      a_no_generated_tail: assert property (@(posedge clk) disable iff (!rst_n)
        !dut.tail_output);
      c_tail_drop: cover property (@(posedge clk) disable iff (!rst_n)
        dut.pop_head && dut.q0_tail);
      c_tail_lookahead: cover property (@(posedge clk) disable iff (!rst_n)
        dut.out_valid && dut.out_frame_end && dut.q1_tail);
    end

    c_retained_frame_start: cover property (@(posedge clk) disable iff (!rst_n)
      dut.q_count != 2 && dut.q1_start);
    c_disabled_emit_candidate: cover property (@(posedge clk) disable iff (!rst_n)
      !enable && dut.can_emit_head && !dut.tail_output && out_ready);
    c_nonempty: cover property (@(posedge clk) disable iff (!rst_n) dut.have_head);
  end
endmodule

`default_nettype wire
