`timescale 1ns/1ps
// Product-bound TLAST/end_remaining proof. The source may end a frame only
// after any positive number of 32-beat quanta, matching the AXI-Lite contract.
module thermo5_cdc_end_remaining_harness #(
  parameter bit VARIABLE_CORE_CONTROL = 1'b0,
  parameter bit ALLOW_SOURCE_GAPS = 1'b0
) (
  input logic s_axis_aclk,
  input logic core_clk,
  input logic rst_n,
  input logic permit_core_advance,
  input logic core_enable,
  input logic core_drain,
  input logic close_quantum,
  input logic source_offer
);
  logic [4:0] beat_in_quantum_q;
  logic [1:0] prior_quanta_q;
  logic packet_start_q;
  logic close_quantum_q;
  logic source_valid_after_first_reset_cycle_q;
  logic hold_source_valid_q;
  wire source_ready;
  wire source_valid = source_valid_after_first_reset_cycle_q &&
    (!ALLOW_SOURCE_GAPS || source_offer || hold_source_valid_q);
  // AXI4-Stream requires TVALID low for the first cycle after ARESETn rises;
  // it may assert in the next cycle, before a two-flop local reset synchronizer
  // has released the FIFO. Exercise that legal reset-start window.
  always_ff @(posedge s_axis_aclk or negedge rst_n) begin
    if (!rst_n) begin
      source_valid_after_first_reset_cycle_q <= 1'b0;
      hold_source_valid_q <= 1'b0;
    end else begin
      source_valid_after_first_reset_cycle_q <= 1'b1;
      hold_source_valid_q <= source_valid && !source_ready;
    end
  end
  wire source_last = (beat_in_quantum_q == 5'd31) && close_quantum_q;
  wire source_start = packet_start_q && (beat_in_quantum_q == 5'd0);
  wire fifo_full, core_valid, core_frame_start, core_frame_end;
  wire signed [127:0] core_i, core_q;
  wire signed [15:0] core_gain;
  wire core_underflow, core_protocol_error;

  always_ff @(posedge s_axis_aclk or negedge rst_n) begin
    if (!rst_n) begin
      beat_in_quantum_q <= '0;
      prior_quanta_q <= '0;
      packet_start_q <= 1'b1;
      close_quantum_q <= 1'b0;
    end else if (source_valid && source_ready) begin
      if (beat_in_quantum_q == 5'd0)
        close_quantum_q <= close_quantum;
      if (beat_in_quantum_q == 5'd31) begin
        beat_in_quantum_q <= '0;
        if (close_quantum_q) begin
          prior_quanta_q <= '0;
          packet_start_q <= 1'b1;
        end else begin
          prior_quanta_q <= prior_quanta_q + 1'b1;
        end
      end else begin
        beat_in_quantum_q <= beat_in_quantum_q + 1'b1;
        if (beat_in_quantum_q == 5'd0)
          packet_start_q <= 1'b0;
      end
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
    .core_enable(VARIABLE_CORE_CONTROL ? core_enable : 1'b1),
    .core_drain(VARIABLE_CORE_CONTROL ? core_drain : 1'b0),
    .core_valid(core_valid), .core_data_empty(),
    .core_ready(VARIABLE_CORE_CONTROL ? permit_core_advance : 1'b1), .core_i_vec(core_i),
    .core_q_vec(core_q), .core_frame_start(core_frame_start),
    .core_frame_end(core_frame_end), .core_frame_gain(core_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  default clocking cb @(posedge core_clk); endclocking

  wire residual_legal = dut.rem_count_q inside {0, 2, 4, 6, 8, 10, 12};
  wire source_reset_active = !dut.s_rst_n;
  wire frame_start_pop = dut.fifo_rd_valid && dut.fifo_rd_ready &&
                         dut.fifo_frame_start;
  wire end_check_context = dut.advance &&
    (dut.rem_count_q >= dut.CORE_LANES) && dut.end_pending_q;
  wire target_false_arm = end_check_context &&
    (dut.end_remaining_q > dut.CORE_LANES);

  a_product_residual_legal: assert property (
    disable iff (!dut.c_rst_n) residual_legal);
  a_source_ready_low_during_internal_reset: assert property (
    @(posedge s_axis_aclk) disable iff (!rst_n)
      source_reset_active |-> !source_ready);
  a_no_product_protocol_error: assert property (
    disable iff (!dut.c_rst_n) !core_protocol_error);
  a_product_frame_start_aligned: assert property (
    disable iff (!dut.c_rst_n) frame_start_pop |->
      (dut.rem_count_q == 0));
  a_end_remaining_false_arm_unreachable: assert property (
    disable iff (!dut.c_rst_n) !target_false_arm);

  if (ALLOW_SOURCE_GAPS) begin : g_source_gaps
    c_gap_mid_packet: cover property (@(posedge s_axis_aclk)
      disable iff (!rst_n) (beat_in_quantum_q != 0) && !source_valid);
  end

  if (VARIABLE_CORE_CONTROL) begin : g_variable_control
    wire [1:0] read_phase = dut.g_generic_fifo.u_async_fifo.rd_bin_q[1:0];
    wire [1:0] write_phase = dut.g_generic_fifo.u_async_fifo.wr_bin_q[1:0];
    wire fifo_pop = dut.fifo_rd_valid && dut.fifo_rd_ready;
    a_write_phase: assert property (@(posedge s_axis_aclk)
      disable iff (!dut.s_rst_n) write_phase == beat_in_quantum_q[1:0]);
    a_residual_at_pop: assert property (
      disable iff (!dut.c_rst_n) fifo_pop |->
      (dut.rem_count_q == {1'b0, (2'd0 - read_phase), 1'b0}));
    a_tlast_pop_phase: assert property (
      disable iff (!dut.c_rst_n) fifo_pop && dut.fifo_frame_end |-> read_phase == 2'd3);
    c_end_pending_stall: cover property (
      disable iff (!dut.c_rst_n) dut.end_pending_q &&
        dut.out_valid_q && core_enable && !permit_core_advance);
    c_end_pending_disabled: cover property (
      disable iff (!dut.c_rst_n) dut.end_pending_q && !core_enable);
    c_end_during_drain: cover property (
      disable iff (!dut.c_rst_n) end_check_context && core_drain);
  end

  c_target_false_arm: cover property (
    disable iff (!dut.c_rst_n) target_false_arm);
  c_target_false_arm_protocol_clean: cover property (
    disable iff (!dut.c_rst_n) target_false_arm && !core_protocol_error);
  c_product_frame_start_pop: cover property (
    disable iff (!dut.c_rst_n) frame_start_pop);
  c_valid_during_internal_source_reset: cover property (
    @(posedge s_axis_aclk) disable iff (!rst_n)
      source_valid && source_reset_active);
  c_legal_end_arm: cover property (
    disable iff (!dut.c_rst_n) end_check_context &&
      (dut.end_remaining_q <= dut.CORE_LANES));
  c_64beat_packet_end: cover property (@(posedge s_axis_aclk)
    disable iff (!rst_n) source_valid && source_ready && source_last &&
      (prior_quanta_q == 2'd1));
  c_completed_legal_frame: cover property (
    disable iff (!dut.c_rst_n) core_valid && core_frame_end);
endmodule

// Existing TLAST source contract with arbitrary core-side control.
module thermo5_v14_cdc_end_with_stall_harness (
  input logic s_axis_aclk, core_clk, rst_n, close_quantum,
  input logic permit_core_advance, core_enable, core_drain
);
  thermo5_cdc_end_remaining_harness #(.VARIABLE_CORE_CONTROL(1)) check_end (
    .source_offer(1'b1), .*
  );
endmodule

module thermo5_v14_cdc_end_with_gaps_harness (
  input logic s_axis_aclk, core_clk, rst_n, close_quantum,
  input logic permit_core_advance, core_enable, core_drain, source_offer
);
  thermo5_cdc_end_remaining_harness #(
    .VARIABLE_CORE_CONTROL(1), .ALLOW_SOURCE_GAPS(1)
  ) check_end (.*);
endmodule
