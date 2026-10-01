`timescale 1ns/1ps

module thermo5_sku_uvm_tb;
  import uvm_pkg::*;
  import thermo5_sku_uvm_pkg::*;
  logic src_clk=0, core_clk=0;
  always #4 src_clk=~src_clk;
  always #2.286 core_clk=~core_clk;
  thermo5_sku_if bus(src_clk,core_clk);
  logic [15:0] identity_c1 = 16'd16384;
  tid32_thermo5_axis_frontend_tx #(
    .INTERP_TAPS(2),.DPD_MAX_TAPS(1),.BYPASS_DPD(1'b0),.FPGA_USE_XPM_FIFO(1'b0)
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
  assign bus.cdc_residual = dut.u_cdc.rem_count_q;
  initial begin
    string testname;
    uvm_config_db#(virtual thermo5_sku_if)::set(null,"uvm_test_top*","vif",bus);
    if (!$value$plusargs("UVM_TESTNAME=%s",testname)) testname="thermo5_sku_bittrue_test";
    run_test(testname);
  end
endmodule
