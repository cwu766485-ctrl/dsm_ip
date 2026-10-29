`timescale 1ns/1ps

module thermo5_sku_uvm_tb;
  import uvm_pkg::*;
  import thermo5_sku_uvm_pkg::*;
`ifdef THERMO5_XPM_FIFO
  localparam bit USE_XPM_FIFO = 1'b1;
`else
  localparam bit USE_XPM_FIFO = 1'b0;
`endif
`ifdef THERMO5_CENTERED_CUBIC
  localparam bit USE_CENTERED_CUBIC = 1'b1;
`else
  localparam bit USE_CENTERED_CUBIC = 1'b1;
`endif
`ifdef THERMO5_LOW_POWER
  localparam bit USE_LOW_POWER_CTRL = 1'b1;
`else
  localparam bit USE_LOW_POWER_CTRL = 1'b0;
`endif
`ifdef THERMO5_TIDSM_ORDER
  localparam int USE_TIDSM_ORDER = `THERMO5_TIDSM_ORDER;
`else
  localparam int USE_TIDSM_ORDER = 2;
`endif
`ifdef THERMO5_STEP
  localparam int USE_STEP = `THERMO5_STEP;
`else
  localparam int USE_STEP = 5120;
`endif
`ifdef THERMO5_DPD_MAX_TAPS
  localparam int USE_DPD_MAX_TAPS = `THERMO5_DPD_MAX_TAPS;
`else
  localparam int USE_DPD_MAX_TAPS = 4;
`endif
  logic src_clk=0, core_clk=0;
  logic axil_clk=0;
  logic axil_rst_n;
  initial begin
    int unsigned source_phase_ps;
    source_phase_ps=0;
    void'($value$plusargs("SOURCE_CLOCK_PHASE_PS=%d",source_phase_ps));
    if (source_phase_ps>=8000) $fatal(1,"SOURCE_CLOCK_PHASE_PS must be in [0,7999]");
    #(source_phase_ps * 1ps);
    forever #4 src_clk=~src_clk;
  end
  always #2.286 core_clk=~core_clk;
  initial begin
    int unsigned axil_phase_ps;
    axil_phase_ps=0;
    void'($value$plusargs("AXIL_CLOCK_PHASE_PS=%d",axil_phase_ps));
    if (axil_phase_ps>=10000) $fatal(1,"AXIL_CLOCK_PHASE_PS must be in [0,9999]");
    #(axil_phase_ps * 1ps);
    forever #5 axil_clk=~axil_clk;
  end
  // Share the common reset assertion epoch, but release AXI-Lite reset
  // synchronously to its own clock domain.
  always_ff @(posedge axil_clk or negedge bus.core_rst_n) begin
    if (!bus.core_rst_n) axil_rst_n <= 1'b0;
    else axil_rst_n <= 1'b1;
  end
  thermo5_sku_if bus(src_clk,core_clk);
  thermo5_axil_if axil_bus(axil_clk,axil_rst_n);
  logic [15:0] identity_c1 = 16'd16384;
`ifdef THERMO5_AXIL_CONTROL
  tid32_thermo5_axi_lite_axis_frontend_tx #(
    .STEP(USE_STEP),.TIDSM_ORDER(USE_TIDSM_ORDER),
    .INTERP_TAPS(2),.INTERP_CENTERED_CUBIC(USE_CENTERED_CUBIC),
    .DPD_MAX_TAPS(USE_DPD_MAX_TAPS),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO)
  ) dut (
    .s_axil_aclk(axil_clk),.s_axil_aresetn(axil_rst_n),
    .s_axil_awaddr(axil_bus.awaddr),.s_axil_awvalid(axil_bus.awvalid),.s_axil_awready(axil_bus.awready),
    .s_axil_wdata(axil_bus.wdata),.s_axil_wstrb(axil_bus.wstrb),.s_axil_wvalid(axil_bus.wvalid),.s_axil_wready(axil_bus.wready),
    .s_axil_bresp(axil_bus.bresp),.s_axil_bvalid(axil_bus.bvalid),.s_axil_bready(axil_bus.bready),
    .s_axil_araddr(axil_bus.araddr),.s_axil_arvalid(axil_bus.arvalid),.s_axil_arready(axil_bus.arready),
    .s_axil_rdata(axil_bus.rdata),.s_axil_rresp(axil_bus.rresp),.s_axil_rvalid(axil_bus.rvalid),.s_axil_rready(axil_bus.rready),
    .s_axis_aclk(src_clk),.s_axis_aresetn(bus.src_rst_n),
    .s_axis_tvalid(bus.src_valid),.s_axis_tready(bus.src_ready),
    .s_axis_tlast(bus.src_last),
    .s_axis_i_vec(bus.src_i),.s_axis_q_vec(bus.src_q),
    .s_axis_tuser_frame_start(bus.frame_start),.s_axis_tuser_frame_gain(bus.frame_gain),
    .s_axis_fifo_full(bus.fifo_full),.core_clk(core_clk),.core_aresetn(bus.core_rst_n),
    .core_underflow(bus.underflow),.core_protocol_error(bus.protocol_error),
    .core_run_request(bus.core_run_request),.core_tx_active(bus.core_tx_active),
    .pa_valid(bus.pa_valid),.pa_data(bus.pa_data),.pa_ready(bus.pa_ready),
    .cfg_busy(bus.cfg_busy),.cfg_done(bus.cfg_done),.cfg_error(bus.cfg_error)
  );
  assign bus.dpd_active_taps=dut.dpd_active_taps;
  assign bus.dpd_config_boundary=dut.dpd_config_boundary;
  assign bus.cfg_mailbox_payload=dut.u_cfg.cfg_mailbox_q;
  assign bus.cfg_pending_payload=dut.u_cfg.cfg_pending_core;
  assign bus.cfg_pending_valid=dut.u_cfg.cfg_pending_valid;
  assign bus.cfg_active_payload=dut.u_cfg.cfg_active_core;
`else
  tid32_thermo5_axis_frontend_tx #(
    .STEP(USE_STEP),.TIDSM_ORDER(USE_TIDSM_ORDER),
    .INTERP_TAPS(2),.INTERP_CENTERED_CUBIC(USE_CENTERED_CUBIC),
    .DPD_MAX_TAPS(1),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO),
    .ENABLE_LOW_POWER_CTRL(USE_LOW_POWER_CTRL)
  ) dut (
    .s_axis_aclk(src_clk),.s_axis_aresetn(bus.src_rst_n),
    .s_axis_tvalid(bus.src_valid),.s_axis_tready(bus.src_ready),
    .s_axis_tlast(bus.src_last),
    .s_axis_i_vec(bus.src_i),.s_axis_q_vec(bus.src_q),
    .s_axis_tuser_frame_start(bus.frame_start),.s_axis_tuser_frame_gain(bus.frame_gain),
    .s_axis_fifo_full(bus.fifo_full),
    .core_clk(core_clk),.core_aresetn(bus.core_rst_n),.core_enable(bus.core_enable),
    .core_underflow(bus.underflow),.core_protocol_error(bus.protocol_error),
    .dpd_active_taps(3'd1),.c1_re({48'd0,identity_c1}),.c1_im(64'd0),
    .c3_re(64'd0),.c3_im(64'd0),.c5_re(64'd0),.c5_im(64'd0),
    .pa_valid(bus.pa_valid),.pa_data(bus.pa_data),.pa_ready(bus.pa_ready)
  );
  assign bus.cfg_busy=1'b0;
  assign bus.cfg_done=1'b0;
  assign bus.cfg_error=1'b0;
  assign bus.dpd_active_taps=3'd1;
  assign bus.dpd_config_boundary=1'b0;
  assign bus.cfg_mailbox_payload='0;
  assign bus.cfg_pending_payload='0;
  assign bus.cfg_active_payload='0;
  assign bus.cfg_pending_valid=1'b0;
  assign bus.core_run_request=1'b0;
  assign bus.core_tx_active=1'b0;
`endif
  assign bus.centered_cubic_enabled = USE_CENTERED_CUBIC;
  assign bus.ef2_order2_enabled = (USE_TIDSM_ORDER == 2);
  generate
    if (USE_TIDSM_ORDER == 2) begin : g_ef2_observe
      for (genvar b = 0; b < 4; b = b + 1) begin : g_branch_observe
        wire ef2_valid = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.in_valid;
        wire ef2_ready = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.in_ready;
        wire ef2_pos = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.clamp_positive_comb;
        wire ef2_neg = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.clamp_negative_comb;
        wire [19:0] e1i = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.err1_i_q;
        wire [19:0] e2i = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.err2_i_q;
        wire [19:0] e1q = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.err1_q_q;
        wire [19:0] e2q = dut.u_frontend.u_tid.g_branch[b].g_order2.u_tid.err2_q_q;
        assign bus.ef2_pos_clamp_event[b] = ef2_valid && ef2_ready && ef2_pos;
        assign bus.ef2_neg_clamp_event[b] = ef2_valid && ef2_ready && ef2_neg;
        assign bus.ef2_pos_clamp_candidate[b] =
          dut.u_frontend.u_tid.in_valid && ef2_pos;
        assign bus.ef2_neg_clamp_candidate[b] =
          dut.u_frontend.u_tid.in_valid && ef2_neg;
        assign bus.ef2_state_at_rail[b] =
          (e1i == 20'sh7ffff) || (e1i == -20'sh80000) ||
          (e2i == 20'sh7ffff) || (e2i == -20'sh80000) ||
          (e1q == 20'sh7ffff) || (e1q == -20'sh80000) ||
          (e2q == 20'sh7ffff) || (e2q == -20'sh80000);
        assign bus.ef2_state_zero[b] = (e1i == 0) && (e2i == 0) &&
                                       (e1q == 0) && (e2q == 0);
        assign bus.ef2_err1_i[b] = e1i;
        assign bus.ef2_err2_i[b] = e2i;
        assign bus.ef2_err1_q[b] = e1q;
        assign bus.ef2_err2_q[b] = e2q;
      end
      assign bus.ef2_tidsm_stalled =
        dut.u_frontend.u_tid.in_valid && !dut.u_frontend.u_tid.in_ready &&
        (bus.pa_valid == 4'hf) && (bus.pa_ready != 4'hf);
      assign bus.ef2_clamp_stalled =
        (|bus.ef2_pos_clamp_candidate || |bus.ef2_neg_clamp_candidate) &&
        bus.ef2_tidsm_stalled;
    end else begin : g_no_ef2_observe
      assign bus.ef2_pos_clamp_event = '0;
      assign bus.ef2_neg_clamp_event = '0;
      assign bus.ef2_pos_clamp_candidate = '0;
      assign bus.ef2_neg_clamp_candidate = '0;
      assign bus.ef2_state_at_rail = '0;
      assign bus.ef2_state_zero = '1;
      assign bus.ef2_clamp_stalled = 1'b0;
      assign bus.ef2_tidsm_stalled = 1'b0;
      for (genvar b = 0; b < 4; b = b + 1) begin : g_zero_state
        assign bus.ef2_err1_i[b] = '0;
        assign bus.ef2_err2_i[b] = '0;
        assign bus.ef2_err1_q[b] = '0;
        assign bus.ef2_err2_q[b] = '0;
      end
    end
  endgenerate
`ifdef THERMO5_LOW_POWER
  assign bus.low_power_state=dut.lp_state;
  assign bus.low_power_active=dut.lp_datapath_enable;
  assign bus.low_power_outstanding=dut.lp_outstanding;
`else
  assign bus.low_power_state='0;
  assign bus.low_power_active=1'b0;
  assign bus.low_power_outstanding='0;
`endif
`ifdef THERMO5_AXIL_CONTROL
  int unsigned axil_phase_trace_cycle = 0;
  always @(posedge core_clk) begin
    axil_phase_trace_cycle <= axil_phase_trace_cycle + 1;
    if ($test$plusargs("THERMO5_AXIL_PHASE_TRACE") &&
        (dut.u_cfg.cfg_req_sync2 || dut.u_cfg.cfg_pending_valid || bus.dpd_config_boundary))
      $display("THERMO5_AXIL_PHASE_TRACE t=%0t cycle=%0d req_sync2=%b pending=%b boundary=%b",
        $time,axil_phase_trace_cycle,dut.u_cfg.cfg_req_sync2,
        dut.u_cfg.cfg_pending_valid,bus.dpd_config_boundary);
  end
`endif
  // Verification-only observation point for reset-state closure.
  for(genvar lane=0;lane<16;lane++) begin : g_dpd_observe
    assign bus.dpd_sample_count[lane]=dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.sample_count;
    assign bus.dpd_saturation_count[lane]=dut.u_frontend.g_memory_dpd.u_memory_dpd.g_lane[lane].u_dpd.saturation_count;
  end
  assign bus.cdc_residual = dut.u_cdc.rem_count_q;
`ifdef THERMO5_XPM_FIFO
  // Monitor only: expose the exact XPM FWFT state and synchronous read reset.
  assign bus.xpm_fwft_state = dut.u_cdc.g_xpm_fifo.u_async_fifo.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.curr_fwft_state;
  assign bus.xpm_rd_rst_i = dut.u_cdc.g_xpm_fifo.u_async_fifo.u_xpm_fifo_async.gnuram_async_fifo.xpm_fifo_base_inst.rd_rst_i;
`else
  assign bus.xpm_fwft_state = '0;
  assign bus.xpm_rd_rst_i = 1'b0;
`endif
`ifdef THERMO5_CENTERED_CUBIC
  assign bus.interp1_empty_blocked = !dut.u_frontend.i1_valid && !dut.u_frontend.i1_ready;
  assign bus.interp1_stage1_held = 1'b0;
  assign bus.interp1_stage1_empty_blocked = 1'b0;
  assign bus.interp1_stall_window = 1'b0;
  assign bus.interp1_stage0_held = 1'b0;
  assign bus.interp2_stage1_held = 1'b0;
  assign bus.interp1_output_held = dut.u_frontend.i1_valid && !dut.u_frontend.i1_ready;
  assign bus.interp2_output_held = dut.u_frontend.i2_valid && !dut.u_frontend.i2_ready;
  assign bus.interp1_output_empty_blocked = !dut.u_frontend.i1_valid && !dut.u_frontend.i1_ready;
  assign bus.interp2_stage1_empty_blocked = 1'b0;
  assign bus.interp2_empty_blocked = !dut.u_frontend.i2_valid && !dut.u_frontend.i2_ready;
`else
  assign bus.interp1_empty_blocked = !dut.u_frontend.g_interp1_causal.u_interp_1.s2_valid &&
                                     !dut.u_frontend.g_interp1_causal.u_interp_1.s3_ready;
  assign bus.interp1_stage1_held = dut.u_frontend.g_interp1_causal.u_interp_1.s1_valid &&
                                   !dut.u_frontend.g_interp1_causal.u_interp_1.s2_ready;
  assign bus.interp1_stage1_empty_blocked = !dut.u_frontend.g_interp1_causal.u_interp_1.s1_valid &&
                                            !dut.u_frontend.g_interp1_causal.u_interp_1.s2_ready;
  assign bus.interp1_stall_window = !dut.u_frontend.g_interp1_causal.u_interp_1.s1_valid &&
                                    dut.u_frontend.g_interp1_causal.u_interp_1.s2_valid &&
                                    dut.u_frontend.g_interp1_causal.u_interp_1.out_valid;
  assign bus.interp1_stage0_held = dut.u_frontend.g_interp1_causal.u_interp_1.s0_valid &&
                                   !dut.u_frontend.g_interp1_causal.u_interp_1.s1_ready;
  assign bus.interp2_stage1_held = dut.u_frontend.g_interp2_causal.u_interp_2.s1_valid &&
                                   !dut.u_frontend.g_interp2_causal.u_interp_2.s2_ready;
  assign bus.interp1_output_held = dut.u_frontend.g_interp1_causal.u_interp_1.out_valid &&
                                   !dut.u_frontend.g_interp1_causal.u_interp_1.out_ready;
  assign bus.interp2_output_held = dut.u_frontend.g_interp2_causal.u_interp_2.out_valid &&
                                   !dut.u_frontend.g_interp2_causal.u_interp_2.out_ready;
  assign bus.interp1_output_empty_blocked = !dut.u_frontend.g_interp1_causal.u_interp_1.out_valid &&
                                            !dut.u_frontend.g_interp1_causal.u_interp_1.out_ready;
  assign bus.interp2_stage1_empty_blocked = !dut.u_frontend.g_interp2_causal.u_interp_2.s1_valid &&
                                            !dut.u_frontend.g_interp2_causal.u_interp_2.s2_ready;
  assign bus.interp2_empty_blocked = !dut.u_frontend.g_interp2_causal.u_interp_2.s2_valid &&
                                     !dut.u_frontend.g_interp2_causal.u_interp_2.s3_ready;
  assign bus.dpd_empty_blocked = !dut.u_frontend.dpd_valid &&
                                 !dut.u_frontend.dpd_ready;
`endif
  initial begin
    string testname;
    uvm_config_db#(virtual thermo5_sku_if)::set(null,"uvm_test_top*","vif",bus);
`ifdef THERMO5_AXIL_CONTROL
    uvm_config_db#(virtual thermo5_axil_if)::set(null,"uvm_test_top.env.axil.*","vif",axil_bus);
    // The helper's default arm is defensive: normal register decode must
    // reject these addresses before calling coeff_read_word().  An opt-in
    // unit probe records that arm without corrupting internal mailbox state.
    if ($test$plusargs("THERMO5_AXIL_INTERNAL_COVERAGE_PROBE")) begin
      if (dut.u_cfg.coeff_read_word(8'h40) !== 32'd0)
        $fatal(1,"AXI-Lite coefficient read helper default arm returned nonzero");
      $display("THERMO5_AXIL_HELPER_DEFAULT_PROBE_PASS");
    end
`endif
    if (!$value$plusargs("UVM_TESTNAME=%s",testname)) begin
`ifdef THERMO5_AXIL_CONTROL
      testname="thermo5_sku_axil_config_test";
`else
      testname="thermo5_sku_bittrue_test";
`endif
    end
    run_test(testname);
  end
endmodule
