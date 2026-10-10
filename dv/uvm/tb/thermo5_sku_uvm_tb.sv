`timescale 1ns/1ps

module thermo5_sku_uvm_tb;
  import uvm_pkg::*;
  import thermo5_sku_uvm_pkg::*;
`ifdef THERMO5_XPM_FIFO
  localparam bit USE_XPM_FIFO = 1'b1;
`else
  localparam bit USE_XPM_FIFO = 1'b0;
`endif
  logic src_clk=0, core_clk=0;
  always #4 src_clk=~src_clk;
  always #2.286 core_clk=~core_clk;
  thermo5_sku_if bus(src_clk,core_clk);
  logic [15:0] identity_c1 = 16'd16384;
  tid32_thermo5_axis_frontend_tx #(
    .INTERP_TAPS(2),.DPD_MAX_TAPS(1),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(USE_XPM_FIFO)
  ) dut (
    .s_axis_aclk(src_clk),.s_axis_aresetn(bus.src_rst_n),
    .s_axis_tvalid(bus.src_valid),.s_axis_tready(bus.src_ready),
    .s_axis_i_vec(bus.src_i),.s_axis_q_vec(bus.src_q),
    .s_axis_tuser_frame_start(bus.frame_start),.s_axis_tuser_frame_gain(bus.frame_gain),
    .s_axis_fifo_full(bus.fifo_full),
    .core_clk(core_clk),.core_aresetn(bus.core_rst_n),.core_enable(bus.core_enable),
    .core_underflow(bus.underflow),.core_protocol_error(bus.protocol_error),
    .dpd_active_taps(3'd1),.c1_re({48'd0,identity_c1}),.c1_im(64'd0),
    .c3_re(64'd0),.c3_im(64'd0),.c5_re(64'd0),.c5_im(64'd0),
    .pa_valid(bus.pa_valid),.pa_data(bus.pa_data),.pa_ready(bus.pa_ready)
  );
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
  assign bus.interp1_empty_blocked = !dut.u_frontend.u_interp_1.s2_valid &&
                                     !dut.u_frontend.u_interp_1.s3_ready;
  assign bus.interp1_stage1_held = dut.u_frontend.u_interp_1.s1_valid &&
                                   !dut.u_frontend.u_interp_1.s2_ready;
  assign bus.interp1_stage1_empty_blocked = !dut.u_frontend.u_interp_1.s1_valid &&
                                            !dut.u_frontend.u_interp_1.s2_ready;
  assign bus.interp1_stall_window = !dut.u_frontend.u_interp_1.s1_valid &&
                                    dut.u_frontend.u_interp_1.s2_valid &&
                                    dut.u_frontend.u_interp_1.out_valid;
  assign bus.interp1_stage0_held = dut.u_frontend.u_interp_1.s0_valid &&
                                   !dut.u_frontend.u_interp_1.s1_ready;
  assign bus.interp2_stage1_held = dut.u_frontend.u_interp_2.s1_valid &&
                                   !dut.u_frontend.u_interp_2.s2_ready;
  assign bus.interp1_output_held = dut.u_frontend.u_interp_1.out_valid &&
                                   !dut.u_frontend.u_interp_1.out_ready;
  assign bus.interp2_output_held = dut.u_frontend.u_interp_2.out_valid &&
                                   !dut.u_frontend.u_interp_2.out_ready;
  assign bus.interp1_output_empty_blocked = !dut.u_frontend.u_interp_1.out_valid &&
                                            !dut.u_frontend.u_interp_1.out_ready;
  assign bus.interp2_stage1_empty_blocked = !dut.u_frontend.u_interp_2.s1_valid &&
                                            !dut.u_frontend.u_interp_2.s2_ready;
  assign bus.interp2_empty_blocked = !dut.u_frontend.u_interp_2.s2_valid &&
                                     !dut.u_frontend.u_interp_2.s3_ready;
  assign bus.dpd_empty_blocked = !dut.u_frontend.dpd_valid &&
                                 !dut.u_frontend.dpd_ready;
  initial begin
    string testname;
    uvm_config_db#(virtual thermo5_sku_if)::set(null,"uvm_test_top*","vif",bus);
    if (!$value$plusargs("UVM_TESTNAME=%s",testname)) testname="thermo5_sku_bittrue_test";
    run_test(testname);
  end
endmodule
