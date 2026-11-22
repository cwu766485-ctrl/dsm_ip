`timescale 1ns/1ps
module thermo5_compiletime_uvm_tb;
  import uvm_pkg::*;
  import thermo5_runtime_uvm_pkg::*;
`ifdef COMPILETIME_ARCH_0
  localparam int STATIC_ARCH = 0;
`elsif COMPILETIME_ARCH_1
  localparam int STATIC_ARCH = 1;
`elsif COMPILETIME_ARCH_2
  localparam int STATIC_ARCH = 2;
`else
  localparam int STATIC_ARCH = 0;
`endif
  logic src_clk=0,core_clk=0,axil_clk=0;
  wire logic common_aresetn = bus.src_rst_n && bus.core_rst_n && bus.axil_rst_n;
  always #4 src_clk=~src_clk;
  always #2.286 core_clk=~core_clk;
  always #5 axil_clk=~axil_clk;
  thermo5_runtime_if bus(src_clk,core_clk,axil_clk);
`ifdef THERMO5_XPM_FIFO
  localparam bit USE_XPM=1'b1;
`else
  localparam bit USE_XPM=1'b0;
`endif

  tid32_thermo5_compiletime_tx #(
    .DSM_ARCH(STATIC_ARCH),.FPGA_USE_XPM_FIFO(USE_XPM)
  ) dut (
    .s_axil_aclk(axil_clk),.common_aresetn(common_aresetn),
    .s_axil_awaddr(bus.awaddr),.s_axil_awvalid(bus.awvalid),.s_axil_awready(bus.awready),
    .s_axil_wdata(bus.wdata),.s_axil_wstrb(bus.wstrb),.s_axil_wvalid(bus.wvalid),.s_axil_wready(bus.wready),
    .s_axil_bresp(bus.bresp),.s_axil_bvalid(bus.bvalid),.s_axil_bready(bus.bready),
    .s_axil_araddr(bus.araddr),.s_axil_arvalid(bus.arvalid),.s_axil_arready(bus.arready),
    .s_axil_rdata(bus.rdata),.s_axil_rresp(bus.rresp),.s_axil_rvalid(bus.rvalid),.s_axil_rready(bus.rready),
    .s_axis_aclk(src_clk),
    .s_axis_tvalid(bus.src_valid),.s_axis_tready(bus.src_ready),.s_axis_tlast(bus.src_last),
    .s_axis_i_vec(bus.src_i),.s_axis_q_vec(bus.src_q),.s_axis_tuser_frame_start(bus.src_start),
    .s_axis_tuser_frame_gain(bus.src_gain),.s_axis_fifo_full(bus.fifo_full),
    .core_clk(core_clk),
    .core_underflow(bus.underflow),.core_protocol_error(bus.protocol_error),
    .core_run_request(bus.run_request),.core_tx_active(bus.tx_active),
    .pa_valid(bus.pa_valid),.pa_ready(bus.pa_ready),.pa_data(bus.pa_data),
    .cfg_busy(bus.cfg_busy),.cfg_done(bus.cfg_done),.cfg_error(bus.cfg_error),
    .active_dsm_arch(bus.arch),.pa_contract_weighted(bus.weighted),
    .pa_channel_mask(bus.pa_mask),.dsm_switch_busy(bus.mode_busy),
    .pa_frame_start(bus.frame_start),.pa_frame_end(bus.frame_end),.pa_tail(bus.tail),
    .pa_config_id(bus.config_id)
  );

  initial begin
    uvm_config_db#(virtual thermo5_runtime_if)::set(null,"uvm_test_top*","vif",bus);
    uvm_config_db#(int)::set(null,"uvm_test_top","static_arch",STATIC_ARCH);
    run_test("thermo5_compiletime_bittrue_test");
  end
  initial begin #10000000; $fatal(1,"Compile-time product watchdog"); end
endmodule
