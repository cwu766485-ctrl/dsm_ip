`timescale 1ns/1ps
`default_nettype none

// Negative elaboration test for the configuration module's parameter guard.
// The two $error messages are expected and are checked by the Make target.
module thermo5_axil_parameter_guard_tb;
  logic axil_clk = 1'b0;
  logic core_clk = 1'b0;
  logic resetn = 1'b0;
  always #5 axil_clk = ~axil_clk;
  always #3 core_clk = ~core_clk;

  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(0)) u_below_minimum (
    .s_axil_aclk(axil_clk),.s_axil_aresetn(resetn),
    .s_axil_awaddr(8'd0),.s_axil_awvalid(1'b0),.s_axil_awready(),
    .s_axil_wdata(32'd0),.s_axil_wstrb(4'd0),.s_axil_wvalid(1'b0),.s_axil_wready(),
    .s_axil_bresp(),.s_axil_bvalid(),.s_axil_bready(1'b0),
    .s_axil_araddr(8'd0),.s_axil_arvalid(1'b0),.s_axil_arready(),
    .s_axil_rdata(),.s_axil_rresp(),.s_axil_rvalid(),.s_axil_rready(1'b0),
    .core_clk(core_clk),.core_aresetn(resetn),.dpd_config_boundary(1'b0),
    .core_tx_active(1'b0),.core_draining(1'b0),.core_enable(),.run_request(),
    .dpd_active_taps(),.c1_re(),.c1_im(),.c3_re(),.c3_im(),
    .c5_re(),.c5_im(),.cfg_busy(),.cfg_done(),.cfg_error()
  );
  thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(5)) u_above_maximum (
    .s_axil_aclk(axil_clk),.s_axil_aresetn(resetn),
    .s_axil_awaddr(8'd0),.s_axil_awvalid(1'b0),.s_axil_awready(),
    .s_axil_wdata(32'd0),.s_axil_wstrb(4'd0),.s_axil_wvalid(1'b0),.s_axil_wready(),
    .s_axil_bresp(),.s_axil_bvalid(),.s_axil_bready(1'b0),
    .s_axil_araddr(8'd0),.s_axil_arvalid(1'b0),.s_axil_arready(),
    .s_axil_rdata(),.s_axil_rresp(),.s_axil_rvalid(),.s_axil_rready(1'b0),
    .core_clk(core_clk),.core_aresetn(resetn),.dpd_config_boundary(1'b0),
    .core_tx_active(1'b0),.core_draining(1'b0),.core_enable(),.run_request(),
    .dpd_active_taps(),.c1_re(),.c1_im(),.c3_re(),.c3_im(),
    .c5_re(),.c5_im(),.cfg_busy(),.cfg_done(),.cfg_error()
  );

  initial begin
    #1;
    $display("THERMO5_AXIL_PARAMETER_GUARD_TEST_COMPLETE");
    $finish;
  end
endmodule

`default_nettype wire
