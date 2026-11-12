`timescale 1ns/1ps
// Actual configuration block, legal external AXI-Lite operations only.
// Boundary is an environment input at this block level, not a product witness.
module tb_thermo5_mailbox_reset_contract;
 reg ac=0, cc=0,rst=0,axrst=0;
 always #5 ac=~ac;
 always #2.286 cc=~cc;
 reg [7:0] awaddr=0,araddr=0;
 reg [31:0] wd=0;reg [3:0] ws=15;
 reg awv=0,wv=0,br=1,arv=0,rr=1,boundary=0;
 wire awr,wr,bv,arready,rv,busy,done,err;
 wire [1:0] bp,rp;wire [31:0] rd;
 integer collisions=0;
 bit event_w1c,event_return,event_set;
 thermo5_dpd_axi_lite_cfg #(.MAX_TAPS(1)) dut(
 .s_axil_aclk(ac),.s_axil_aresetn(axrst),.s_axil_awaddr(awaddr),.s_axil_awvalid(awv),.s_axil_awready(awr),
 .s_axil_wdata(wd),.s_axil_wstrb(ws),.s_axil_wvalid(wv),.s_axil_wready(wr),.s_axil_bresp(bp),.s_axil_bvalid(bv),.s_axil_bready(br),
 .s_axil_araddr(araddr),.s_axil_arvalid(arv),.s_axil_arready(arready),.s_axil_rdata(rd),.s_axil_rresp(rp),.s_axil_rvalid(rv),.s_axil_rready(rr),
 .core_clk(cc),.core_aresetn(rst),.dpd_config_boundary(boundary),.core_tx_active(1'b0),.core_draining(1'b0),
 .core_enable(),.run_request(),.dpd_active_taps(),.c1_re(),.c1_im(),.c3_re(),.c3_im(),.c5_re(),.c5_im(),.cfg_busy(busy),.cfg_done(done),.cfg_error(err));

 task automatic write_reg(input [7:0] addr,input [31:0] data);
  @(negedge ac);awaddr=addr;wd=data;awv=1;wv=1;
  @(posedge ac);if(!awr||!wr)$fatal(1,"AW/W unexpectedly blocked");
  @(negedge ac);awv=0;wv=0;
  wait(bv);if(bp!==0)$fatal(1,"BRESP error");
  @(posedge ac);@(negedge ac);
 endtask
 initial begin
  $dumpfile("mailbox_reset.vcd");$dumpvars(0,tb_thermo5_mailbox_reset_contract);
  #1;rst=0;axrst=0;#22;rst=1;axrst=1;
  write_reg(8'h10,32'h2000);
  write_reg(0,2);
  wait(dut.cfg_pending_valid);
  if(dut.cfg_pending_core[383:320] !== 64'h2000)$fatal(1,"pending predecessor missing");
  // Deliberately OUTSIDE common-epoch reset contract: reset AXIL only,
  // after pending capture, while core continues to accept a boundary.
  @(negedge ac);axrst=0;
  @(negedge cc);boundary=1;
  @(posedge cc);#1ps;
  if(dut.c1_re !== 64'h2000 || dut.cfg_mailbox_q[383:320] !== 64'h4000)
    $fatal(1,"expected epoch split absent");
  $display("MAILBOX_RESET_CONTRACT_WITNESS time_ps=%0t axil_reset=0 core_reset=1 active_old=2000 mailbox_reset=4000 outside_contract=1",$time);
  @(negedge cc);boundary=0;rst=0;
  #22;rst=1;axrst=1;
  repeat(5) @(posedge cc);
  if(dut.c1_re !== 64'h4000 || busy || dut.cfg_pending_valid)$fatal(1,"common reset recovery failed");
  $display("MAILBOX_RESET_CONTRACT_REPRO_PASS common_epoch_recovery=PASS independent_reset_supported=0");
  $finish;
 end
 initial begin #20000;$fatal(1,"watchdog");end
endmodule
