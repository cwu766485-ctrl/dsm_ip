`timescale 1ns/1ps
`default_nettype none

// Product-bound final-word threshold proof for two back-to-back legal
// 32-beat packets through the production 14:8 CDC and Generic FIFO.
module thermo5_cdc_frame_end_threshold_harness (
  input logic s_axis_aclk,
  input logic core_clk,
  input logic rst_n
);
  logic [6:0] accepted_beats_q;
  logic source_valid_after_reset_q;
  logic [1:0] frame_start_pops_q;
  logic [1:0] frame_end_pops_q;

  wire source_ready;
  wire source_valid = source_valid_after_reset_q && (accepted_beats_q < 7'd64);
  wire source_last = source_valid && (accepted_beats_q[4:0] == 5'd31);
  wire source_start = source_valid && (accepted_beats_q[4:0] == 5'd0);
  wire fifo_full, core_valid, core_frame_start, core_frame_end;
  wire signed [127:0] core_i, core_q;
  wire signed [15:0] core_gain;
  wire core_underflow, core_protocol_error;
  wire frame_start_pop = dut.fifo_rd_valid && dut.fifo_rd_ready &&
                         dut.fifo_frame_start;
  wire frame_end_pop = dut.fifo_rd_valid && dut.fifo_rd_ready &&
                       dut.fifo_frame_end;

  // VALID is low through the first source-clock cycle after reset release.
  // The source advances only on handshakes, so packet markers remain stable
  // under backpressure. Two legal 32-beat packets are sent with no inserted
  // idle beat; each packet yields exactly 56 core words.
  always_ff @(posedge s_axis_aclk or negedge rst_n) begin
    if (!rst_n) begin
      accepted_beats_q <= '0;
      source_valid_after_reset_q <= 1'b0;
    end else begin
      source_valid_after_reset_q <= 1'b1;
      if (source_valid && source_ready)
        accepted_beats_q <= accepted_beats_q + 1'b1;
    end
  end

  dsm_axis14_to_core8_cdc #(
    .W(16), .GAIN_W(16), .FIFO_ADDR_W(4),
    .SRC_LANES(14), .CORE_LANES(8), .USE_XPM_FIFO(1'b0)
  ) dut (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(source_valid), .s_axis_tready(source_ready),
    .s_axis_i_vec('0), .s_axis_q_vec('0),
    .s_axis_tuser_frame_start(source_start), .s_axis_tlast(source_last),
    .s_axis_tuser_frame_gain(16'sd16384), .s_axis_fifo_full(fifo_full),
    .core_clk(core_clk), .core_aresetn(rst_n),
    .core_enable(1'b1), .core_drain(1'b0), .core_valid(core_valid),
    .core_data_empty(), .core_ready(1'b1), .core_i_vec(core_i),
    .core_q_vec(core_q), .core_frame_start(core_frame_start),
    .core_frame_end(core_frame_end), .core_frame_gain(core_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  always_ff @(posedge core_clk or negedge rst_n) begin
    if (!rst_n) begin
      frame_start_pops_q <= '0;
      frame_end_pops_q <= '0;
    end else begin
      if (frame_start_pop && frame_start_pops_q != 2'd3)
        frame_start_pops_q <= frame_start_pops_q + 1'b1;
      if (frame_end_pop && frame_end_pops_q != 2'd3)
        frame_end_pops_q <= frame_end_pops_q + 1'b1;
    end
  end

  default clocking cb @(posedge core_clk); endclocking

  a_frame_start_pop_aligned: assert property (
    disable iff (!dut.c_rst_n) frame_start_pop |-> (dut.rem_count_q == 0));
  a_no_product_protocol_error: assert property (
    disable iff (!dut.c_rst_n) !core_protocol_error);
  // The exact 14:8 product geometry cannot emit a short final source word;
  // all frame ends must use the pending-tail drain path.
  a_frame_end_requires_tail_drain: assert property (
    disable iff (!dut.c_rst_n) frame_end_pop |=> dut.end_pending_q);

  c_first_frame_start_pop: cover property (
    disable iff (!dut.c_rst_n) frame_start_pop && (frame_start_pops_q == 0));
  c_second_frame_start_pop: cover property (
    disable iff (!dut.c_rst_n) frame_start_pop && (frame_start_pops_q == 1));
  c_second_frame_end_pop: cover property (
    disable iff (!dut.c_rst_n) frame_end_pop && (frame_end_pops_q == 1));
  c_second_frame_output_end: cover property (
    disable iff (!dut.c_rst_n) core_valid && core_frame_end &&
      (frame_end_pops_q == 1));
  c_short_final_word_branch_target: cover property (
    disable iff (!dut.c_rst_n) frame_end_pop &&
      (dut.rem_count_q + dut.SRC_LANES <= dut.CORE_LANES));
  c_misaligned_frame_start_target: cover property (
    disable iff (!dut.c_rst_n) frame_start_pop && (dut.rem_count_q != 0));

endmodule

`default_nettype wire
