`timescale 1ns/1ps
// Product-bound proof for the 14:8 CDC gearbox's outer case default.
// A legal source sends aligned 32-beat packets through the production
// Generic FIFO. The default branch is covered only when advance is true and
// rem_count_q is outside the legal 14:8 residual set.
module thermo5_cdc_default_branch_harness(
  input logic s_axis_aclk,
  input logic core_clk,
  input logic rst_n
);
  logic [4:0] packet_beat_q;
  wire source_ready;
  wire source_valid = 1'b1;
  wire signed [223:0] source_i = '0;
  wire signed [223:0] source_q = '0;
  wire source_last = source_valid && (packet_beat_q == 5'd31);
  wire source_start = source_valid && (packet_beat_q == 5'd0);
  wire fifo_full, core_valid, core_frame_start, core_frame_end;
  wire signed [127:0] core_i, core_q;
  wire signed [15:0] core_gain;
  wire core_underflow, core_protocol_error;

  always_ff @(posedge s_axis_aclk or negedge rst_n) begin
    if (!rst_n)
      packet_beat_q <= '0;
    else if (source_valid && source_ready) begin
      if (packet_beat_q == 5'd31)
        packet_beat_q <= '0;
      else
        packet_beat_q <= packet_beat_q + 1'b1;
    end
  end

  dsm_axis14_to_core8_cdc #(
    .W(16), .GAIN_W(16), .FIFO_ADDR_W(4),
    .SRC_LANES(14), .CORE_LANES(8), .USE_XPM_FIFO(1'b0)
  ) dut (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(source_valid), .s_axis_tready(source_ready),
    .s_axis_i_vec(source_i), .s_axis_q_vec(source_q),
    .s_axis_tuser_frame_start(source_start), .s_axis_tlast(source_last),
    .s_axis_tuser_frame_gain(16'sd16384), .s_axis_fifo_full(fifo_full),
    .core_clk(core_clk), .core_aresetn(rst_n),
    .core_enable(1'b1), .core_drain(1'b0), .core_valid(core_valid),
    .core_data_empty(), .core_ready(1'b1), .core_i_vec(core_i),
    .core_q_vec(core_q), .core_frame_start(core_frame_start),
    .core_frame_end(core_frame_end), .core_frame_gain(core_gain),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error)
  );

  default clocking cb @(posedge core_clk); endclocking

  wire residual_legal = dut.rem_count_q inside {0, 2, 4, 6, 8, 10, 12};
  wire exact_default_path = dut.advance && !residual_legal;

  a_product_residual_legal: assert property (
    disable iff (!dut.c_rst_n) residual_legal);
  a_exact_default_path_unreachable: assert property (
    disable iff (!dut.c_rst_n) !exact_default_path);

  c_exact_default_path: cover property (
    disable iff (!dut.c_rst_n) exact_default_path);
  c_product_advance: cover property (
    disable iff (!dut.c_rst_n) dut.advance && residual_legal);
  c_completed_legal_frame: cover property (
    disable iff (!dut.c_rst_n) core_valid && core_frame_end);
endmodule
