`timescale 1ns/1ps
`default_nettype none

module thermo5_v14_frontend_control_harness (
  input logic s_axis_aclk, core_clk, rst_n,
  input logic source_valid, source_start, source_last,
  input logic core_enable, core_drain, core_ready,
  input logic ingress_valid, ingress_ready, dpd_valid, dpd_ready,
  input logic [1:0] ingress_frame_flags, dpd_frame_flags
);
  wire core_valid, core_start, core_end;
  dsm_axis14_to_core8_cdc #(
    .W(16), .GAIN_W(16), .FIFO_ADDR_W(4), .SRC_LANES(14), .CORE_LANES(8),
    .USE_XPM_FIFO(1'b0)
  ) gearbox (
    .s_axis_aclk(s_axis_aclk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(source_valid), .s_axis_tready(),
    .s_axis_i_vec(224'b0), .s_axis_q_vec(224'b0),
    .s_axis_tuser_frame_start(source_start), .s_axis_tlast(source_last),
    .s_axis_tuser_frame_gain(16'sd16384), .s_axis_fifo_full(),
    .core_clk(core_clk), .core_aresetn(rst_n), .core_enable(core_enable),
    .core_drain(core_drain), .core_valid(core_valid), .core_data_empty(),
    .core_ready(core_ready), .core_i_vec(), .core_q_vec(),
    .core_frame_start(core_start), .core_frame_end(core_end), .core_frame_gain(),
    .core_underflow(), .core_protocol_error()
  );

  wire gain_input_valid, interp_input_valid;
  wire [17:0] gain_input_meta;
  wire [1:0] interp_input_meta;
  // Exercise the production FIFO module at both metadata widths. Arbitrary
  // flag traffic and backpressure make the empty-output implications local.
  thermo5_vector_registered_ready_fifo #(.W(16), .LANES(8), .META_W(18)) gain_fifo (
    .clk(core_clk), .rst_n(rst_n),
    .in_valid(ingress_valid), .in_ready(),
    .in_meta({16'd16384, ingress_frame_flags}), .in_i_vec(128'b0), .in_q_vec(128'b0),
    .out_valid(gain_input_valid), .out_ready(ingress_ready),
    .out_meta(gain_input_meta), .out_i_vec(), .out_q_vec()
  );
  thermo5_vector_registered_ready_fifo #(.W(16), .LANES(16), .META_W(2)) interp_fifo (
    .clk(core_clk), .rst_n(rst_n),
    .in_valid(dpd_valid), .in_ready(), .in_meta(dpd_frame_flags),
    .in_i_vec(256'b0), .in_q_vec(256'b0),
    .out_valid(interp_input_valid), .out_ready(dpd_ready),
    .out_meta(interp_input_meta), .out_i_vec(), .out_q_vec()
  );

  default clocking cb @(posedge core_clk); endclocking
  a_read_empty_complements_valid: assert property (disable iff (!gearbox.c_rst_n)
    gearbox.fifo_rd_empty != gearbox.fifo_rd_valid);
  a_residual_stays_in_range: assert property (disable iff (!gearbox.c_rst_n)
    gearbox.rem_count_q inside {0, 2, 4, 6, 8, 10, 12});
  a_gain_empty_has_no_flags: assert property (disable iff (!rst_n)
    !gain_input_valid |-> gain_input_meta[1:0] == 2'b00);
  a_interp_empty_has_no_start: assert property (disable iff (!rst_n)
    !interp_input_valid |-> !interp_input_meta[0]);

  c_read_empty: cover property (disable iff (!gearbox.c_rst_n) gearbox.fifo_rd_empty);
  c_read_valid: cover property (disable iff (!gearbox.c_rst_n) gearbox.fifo_rd_valid);
  c_gain_start_end: cover property (disable iff (!rst_n)
    gain_input_valid && gain_input_meta[1:0] == 2'b11);
  c_interp_has_start: cover property (disable iff (!rst_n)
    interp_input_valid && interp_input_meta[0]);
  c_pending_short_residual: cover property (disable iff (!gearbox.c_rst_n)
    gearbox.advance && gearbox.rem_count_q < 8 && gearbox.end_pending_q);
endmodule

`default_nettype wire
