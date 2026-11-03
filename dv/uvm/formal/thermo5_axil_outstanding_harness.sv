`timescale 1ns/1ps
`default_nettype none

// Product-bound reachability harness for the AXI-Lite TX outstanding-word
// counter guards at tid32_thermo5_axi_lite_axis_frontend_tx.sv:203-204.
// The source and AXI-Lite master are legal sequencers; PA ready is arbitrary.
module thermo5_axil_outstanding_harness (
  input logic axil_clk,
  input logic source_clk,
  input logic core_clk,
  input logic rst_n,
  input logic [3:0] pa_ready,
  input logic source_valid
);
  logic [7:0] awaddr;
  logic awvalid, awready;
  logic [31:0] wdata;
  logic [3:0] wstrb;
  logic wvalid, wready;
  logic [1:0] bresp;
  logic bvalid;
  logic [7:0] araddr;
  logic arvalid, arready;
  logic [31:0] rdata;
  logic [1:0] rresp;
  logic rvalid;
  logic [223:0] source_i, source_q;
  logic source_ready, source_last, source_frame_start;
  logic signed [15:0] source_gain;
  logic source_fifo_full;
  logic core_underflow, core_protocol_error;
  logic core_run_request, core_tx_active;
  logic [3:0] pa_valid;
  logic [63:0] pa_data [0:3];
  logic cfg_busy, cfg_done, cfg_error;

  logic aw_sent, w_sent, run_write_done;
  logic [4:0] source_phase;
  logic [7:0] outstanding_words_q;
  logic [5:0] pipeline_slots;

  assign awaddr = 8'h00;
  assign wdata = 32'h0000_0001;
  assign wstrb = 4'b0001;
  assign awvalid = !aw_sent;
  assign wvalid = !w_sent;
  assign araddr = '0;
  assign arvalid = 1'b0;

  // One AXI-Lite control write starts RUN. AW and W remain valid until their
  // independent handshakes; BREADY is continuously asserted.
  always_ff @(posedge axil_clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_sent <= 1'b0;
      w_sent <= 1'b0;
      run_write_done <= 1'b0;
    end else begin
      if (awvalid && awready) aw_sent <= 1'b1;
      if (wvalid && wready) w_sent <= 1'b1;
      if (bvalid) run_write_done <= 1'b1;
    end
  end

  // Send an unbounded sequence of legal 32-beat packets. A single packet is
  // too short to assess an 8-bit outstanding counter over sustained traffic.
  // The phase advances only on public AXIS handshakes, so TLAST and frame
  // start remain stable through arbitrary source backpressure.
  assign source_last = (source_phase == 31);
  assign source_frame_start = (source_phase == 0);
  assign source_i = '0;
  assign source_q = '0;
  assign source_gain = 16'sd16384;

  always_ff @(posedge source_clk or negedge rst_n) begin
    if (!rst_n) source_phase <= '0;
    else if (source_valid && source_ready) source_phase <= source_phase + 1'b1;
  end

  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .W(16), .GAIN_W(16), .STEP(5120), .DPD_MAX_TAPS(1),
    .INTERP_TAPS(2), .INTERP_CENTERED_CUBIC(1'b1),
    .BYPASS_DPD(1'b0), .FPGA_USE_XPM_FIFO(1'b0), .TIDSM_ORDER(2)
  ) dut (
    .s_axil_aclk(axil_clk), .s_axil_aresetn(rst_n),
    .s_axil_awaddr(awaddr), .s_axil_awvalid(awvalid), .s_axil_awready(awready),
    .s_axil_wdata(wdata), .s_axil_wstrb(wstrb), .s_axil_wvalid(wvalid), .s_axil_wready(wready),
    .s_axil_bresp(bresp), .s_axil_bvalid(bvalid), .s_axil_bready(1'b1),
    .s_axil_araddr(araddr), .s_axil_arvalid(arvalid), .s_axil_arready(arready),
    .s_axil_rdata(rdata), .s_axil_rresp(rresp), .s_axil_rvalid(rvalid), .s_axil_rready(1'b1),
    .s_axis_aclk(source_clk), .s_axis_aresetn(rst_n),
    .s_axis_tvalid(source_valid), .s_axis_tready(source_ready),
    .s_axis_tlast(source_last), .s_axis_i_vec(source_i), .s_axis_q_vec(source_q),
    .s_axis_tuser_frame_start(source_frame_start),
    .s_axis_tuser_frame_gain(source_gain), .s_axis_fifo_full(source_fifo_full),
    .core_clk(core_clk), .core_aresetn(rst_n),
    .core_underflow(core_underflow), .core_protocol_error(core_protocol_error),
    .core_run_request(core_run_request), .core_tx_active(core_tx_active),
    .pa_valid(pa_valid), .pa_data(pa_data), .pa_ready(pa_ready),
    .cfg_busy(cfg_busy), .cfg_done(cfg_done), .cfg_error(cfg_error)
  );

  assign outstanding_words_q = dut.outstanding_words_q;

  // Count every valid product slot after core_accept and before the four-plane
  // PA handshake. This includes the synthetic centered-interpolator tail, so
  // the total is a conservative upper bound on outstanding real words. This
  // is a structural source-bound invariant, not a source-gap or PA-stall
  // bound. The product chain has at most 29 slots including the tail:
  // ingress FIFO(2) + gain pipeline(3) + interp1 queue(2) + elastic FIFO(2)
  // + DPD pipeline(11) + elastic FIFO(2) + interp2 real queue(2)
  // + elastic FIFO(2) + EF2 input register capacity(1) + GT bridge(1)
  // + interp1 synthetic-tail register(1). The EF2 register capacity is a
  // conservative constant because VC Formal reports the generated-array
  // hierarchical reference as undriven; do not use that reference as proof
  // evidence.
  always_comb begin : p_pipeline_slots
    integer slots;
    slots = 0;
    slots += dut.u_frontend.u_cdc_to_frame_gain_fifo.count_q;
    slots += dut.u_frontend.u_frame_gain.s0_valid;
    slots += dut.u_frontend.u_frame_gain.s1_valid;
    slots += dut.u_frontend.u_frame_gain.out_valid;
    slots += dut.u_frontend.g_interp1_centered.u_interp_1.q_count;
    slots += dut.u_frontend.g_interp1_centered.u_interp_1.tail_pending_q;
    slots += dut.u_frontend.u_interp_to_dpd_elastic.count_q;
    slots += $countones(
      dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[0].u_dpd.valid_pipe);
    slots += dut.u_frontend.u_dpd_to_interp_elastic.count_q;
    slots += dut.u_frontend.g_interp2_centered.u_interp_2.q_count;
    slots += dut.u_frontend.u_interp2_to_tid_fifo.count_q;
    slots += 1;
    slots += pa_valid[0];
    pipeline_slots = slots[5:0];
  end

  // A source may insert arbitrarily long bubbles. The only legal AXIS
  // constraint is to retain VALID until a handshake after presenting a beat;
  // PA_READY is entirely unconstrained.
  as_source_hold_when_stalled:
    assume property (@(posedge source_clk) disable iff (!rst_n)
      source_valid && !source_ready |=> source_valid);

  a_outstanding_not_greater_than_pipeline_slots:
    assert property (@(posedge core_clk) disable iff (!rst_n)
      outstanding_words_q <= pipeline_slots);

  a_outstanding_within_product_capacity:
    assert property (@(posedge core_clk) disable iff (!rst_n)
      outstanding_words_q <= 8'd29);

  a_pa_valid_has_outstanding_word:
    assert property (@(posedge core_clk) disable iff (!rst_n)
      pa_valid[0] |-> outstanding_words_q != 0);

  // These assertions directly negate the two missing Raw branch predicates.
  // A proof is accepted only if legal source/core/output activity is also
  // covered and VC Formal reports non-vacuous goals with no assumptions.
  a_no_counter_saturation_guard:
    assert property (@(posedge core_clk) disable iff (!rst_n)
      (dut.core_accept && !dut.output_accept) |-> (outstanding_words_q != 8'hff));

  a_no_counter_underflow_guard:
    assert property (@(posedge core_clk) disable iff (!rst_n)
      (!dut.core_accept && dut.output_accept) |-> (outstanding_words_q != 0));

  c_source_accept: cover property (@(posedge source_clk) disable iff (!rst_n)
    source_valid && source_ready);
  c_core_accept: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.core_accept);
  c_output_accept: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.output_accept);
  c_arbitrary_source_bubble: cover property (@(posedge source_clk) disable iff (!rst_n)
    !source_valid ##1 !source_valid ##1 source_valid && source_ready);
  c_counter_saturation_guard: cover property (@(posedge core_clk) disable iff (!rst_n)
    dut.core_accept && !dut.output_accept && (outstanding_words_q == 8'hff));
  c_counter_underflow_guard: cover property (@(posedge core_clk) disable iff (!rst_n)
    !dut.core_accept && dut.output_accept && (outstanding_words_q == 0));
endmodule

`default_nettype wire
