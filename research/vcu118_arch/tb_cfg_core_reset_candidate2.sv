`timescale 1ps/1ps
`default_nettype none
// Witness only: reset AXI-Lite independently after the pending bundle was
// captured. A downstream boundary can still apply that pre-reset bundle.
module tb_cfg_core_reset_candidate2;
  logic axil_clk=0,core_clk=0, axil_rstn=0,core_rstn=0,boundary=0;
  always #5000 axil_clk=~axil_clk;
  always #2286 core_clk=~core_clk;
  logic [7:0] awaddr=0; logic awvalid=0,wvalid=0; logic [31:0] wdata=0;
  wire awready,wready,bvalid; wire [1:0] bresp; wire signed [63:0] c1_re;
  thermo5_dpd_axi_lite_cfg_epoch_candidate2 #(.MAX_TAPS(1),.ENABLE_RUNTIME_DSM(1)) dut(
    .s_axil_aclk(axil_clk),.s_axil_aresetn(axil_rstn),.s_axil_awaddr(awaddr),
    .s_axil_awvalid(awvalid),.s_axil_awready(awready),.s_axil_wdata(wdata),
    .s_axil_wstrb(4'hf),.s_axil_wvalid(wvalid),.s_axil_wready(wready),
    .s_axil_bresp(bresp),.s_axil_bvalid(bvalid),.s_axil_bready(1'b1),
    .s_axil_araddr(8'b0),.s_axil_arvalid(1'b0),.s_axil_rready(1'b1),
    .core_clk(core_clk),.core_aresetn(core_rstn),.dpd_config_boundary(boundary),
    .core_tx_active(1'b0),.core_draining(1'b0),.c1_re(c1_re),
    .dsm_switch_idle(1'b1),.dsm_source_locked(1'b0));
  task automatic write_reg(input [7:0] addr,input [31:0] data);
    @(negedge axil_clk);awaddr=addr;wdata=data;awvalid=1;wvalid=1;
    do @(posedge axil_clk); while (!(awready && wready));
    @(negedge axil_clk);awvalid=0;wvalid=0;
    wait(bvalid);if(bresp!==0)$fatal(1,"unexpected AXI response");
    @(posedge axil_clk);
  endtask
  initial begin
    $dumpfile("core_reset_candidate2.vcd");$dumpvars(0,tb_cfg_core_reset_candidate2);
    #17000;axil_rstn=1;core_rstn=1;
    write_reg(8'h10,32'h00001234);
    write_reg(8'h00,32'h00000002);
    wait(dut.cfg_pending_valid===1'b1);
    @(negedge core_clk);core_rstn=0;boundary=1;
    repeat(4) @(negedge core_clk);core_rstn=1;
    repeat(12) @(posedge axil_clk);#1;
    if(c1_re!==64'h4000 || dut.cfg_req_q!==1'b0 || dut.cfg_ack_core!==1'b0 || dut.cfg_error_q!==1'b1)
      $fatal(1,"core reset failed to abort old request or report status");
    boundary=0;
    write_reg(8'h10,32'h00005678);write_reg(8'h00,32'h00000002);
    wait(dut.cfg_pending_valid===1'b1);@(negedge core_clk);boundary=1;@(posedge core_clk);#1;
    if(c1_re!==64'h5678 || dut.cfg_ack_core!==1'b1)$fatal(1,"new request after core reset failed");
    $display("CORE_RESET_CANDIDATE2_ABORT_STATUS_PASS new_c1=%h time_ps=%0t",c1_re,$time);
    $finish;
  end
  initial begin #1000000;$fatal(1,"timeout");end
endmodule
`default_nettype wire
