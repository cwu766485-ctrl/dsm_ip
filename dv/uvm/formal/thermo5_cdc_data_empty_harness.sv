`timescale 1ns/1ps
`default_nettype none

// Reachability audit for the Generic-FIFO product's core_data_empty condition.
// The source is a registered legal AXI-stream producer; the production CDC and
// asynchronous FIFO RTL are instantiated without modeling internal state.
module thermo5_cdc_data_empty_harness(
  input logic s_axis_aclk,
  input logic core_clk,
  input logic rst_n,
  input logic in_valid,
  input logic core_enable,
  input logic core_ready,
  input logic signed [223:0] in_i,
  input logic signed [223:0] in_q,
  input logic frame_start,
  input logic signed [15:0] frame_gain
);
  wire in_ready, fifo_full, core_valid, core_data_empty;
  wire signed [127:0] core_i, core_q;
  wire core_frame_start, core_frame_end, underflow, protocol_error;
  wire signed [15:0] core_frame_gain;
  logic axis_valid, axis_frame_start;
  logic signed [223:0] axis_i, axis_q;
  logic signed [15:0] axis_frame_gain;

  // A conventional registered source: once valid is presented while blocked,
  // payload and metadata remain unchanged until the public ready handshake.
  always_ff @(posedge s_axis_aclk or negedge rst_n) begin
    if (!rst_n) begin
      axis_valid <= 1'b0;
      axis_i <= '0;
      axis_q <= '0;
      axis_frame_start <= 1'b0;
      axis_frame_gain <= '0;
    end else if (!axis_valid || in_ready) begin
      axis_valid <= in_valid;
      axis_i <= in_i;
      axis_q <= in_q;
      axis_frame_start <= frame_start;
      axis_frame_gain <= frame_gain;
    end
  end

  dsm_axis14_to_core8_cdc #(.USE_XPM_FIFO(1'b0)) u_cdc (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(axis_valid), .s_axis_tready(in_ready),
    .s_axis_i_vec(axis_i), .s_axis_q_vec(axis_q),
    .s_axis_tuser_frame_start(axis_frame_start), .s_axis_tlast(1'b0),
    .s_axis_tuser_frame_gain(axis_frame_gain), .s_axis_fifo_full(fifo_full),
    .core_clk(core_clk), .core_aresetn(rst_n),
    .core_enable(core_enable), .core_drain(1'b0),
    .core_data_empty(core_data_empty), .core_ready(core_ready),
    .core_valid(core_valid), .core_i_vec(core_i), .core_q_vec(core_q),
    .core_frame_start(core_frame_start), .core_frame_end(core_frame_end),
    .core_frame_gain(core_frame_gain), .core_underflow(underflow),
    .core_protocol_error(protocol_error)
  );

  // In the elaborated Generic FIFO, rd_valid is defined as !rd_empty. This
  // is the product-configuration fact that excludes Raw condition 0/1/1/1/1.
  a_nonempty_implies_valid: assert property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n) !u_cdc.fifo_rd_empty |-> u_cdc.fifo_rd_valid);
  a_empty_excludes_valid: assert property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n) u_cdc.fifo_rd_empty |-> !u_cdc.fifo_rd_valid);
  a_public_empty_uses_all_stages: assert property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n)
    core_data_empty == (u_cdc.fifo_rd_empty && !u_cdc.fifo_rd_valid &&
                         (u_cdc.rem_count_q == 0) && !u_cdc.out_valid_q &&
                         !u_cdc.end_pending_q));

  c_source_accept: cover property (@(posedge s_axis_aclk)
    disable iff (!u_cdc.s_rst_n) axis_valid && in_ready);
  c_fifo_nonempty_valid: cover property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n) !u_cdc.fifo_rd_empty && u_cdc.fifo_rd_valid);
  c_core_data_empty: cover property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n) core_data_empty);
  c_exact_raw_bin: cover property (@(posedge core_clk)
    disable iff (!u_cdc.c_rst_n)
    !u_cdc.fifo_rd_empty && !u_cdc.fifo_rd_valid &&
    (u_cdc.rem_count_q == 0) && !u_cdc.out_valid_q && !u_cdc.end_pending_q);
endmodule

`default_nettype wire
