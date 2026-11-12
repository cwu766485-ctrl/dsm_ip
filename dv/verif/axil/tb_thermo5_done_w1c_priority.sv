`timescale 1ns/1ps
// Actual configuration block, legal external AXI-Lite operations only.
// Boundary is an environment input at this block level, not a product witness.
module tb_thermo5_done_w1c_priority;
 reg ac=0, cc=0,rst=0;
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
 .s_axil_aclk(ac),.s_axil_aresetn(rst),.s_axil_awaddr(awaddr),.s_axil_awvalid(awv),.s_axil_awready(awr),
 .s_axil_wdata(wd),.s_axil_wstrb(ws),.s_axil_wvalid(wv),.s_axil_wready(wr),.s_axil_bresp(bp),.s_axil_bvalid(bv),.s_axil_bready(br),
 .s_axil_araddr(araddr),.s_axil_arvalid(arv),.s_axil_arready(arready),.s_axil_rdata(rd),.s_axil_rresp(rp),.s_axil_rvalid(rv),.s_axil_rready(rr),
 .core_clk(cc),.core_aresetn(rst),.dpd_config_boundary(boundary),.core_tx_active(1'b0),.core_draining(1'b0),
 .core_enable(),.run_request(),.dpd_active_taps(),.c1_re(),.c1_im(),.c3_re(),.c3_im(),.c5_re(),.c5_im(),.cfg_busy(busy),.cfg_done(done),.cfg_error(err));
 covergroup priority_cg;
  option.per_instance=1;
  cp_w1c: coverpoint event_w1c {bins asserted={1};}
  cp_return: coverpoint event_return {bins asserted={1};}
  cp_expected_set: coverpoint event_set {bins asserted={1};}
  same_edge_priority: cross cp_w1c,cp_return,cp_expected_set;
 endgroup
 priority_cg cov=new;
 task automatic write_reg(input [7:0] addr,input [31:0] data,input [1:0] expected);
  @(negedge ac);awaddr=addr;wd=data;awv=1;wv=1;
  @(posedge ac);if(!awr||!wr)$fatal(1,"AW/W blocked unexpectedly");
  @(negedge ac);awv=0;wv=0;
  wait(bv);if(bp!==expected)$fatal(1,"BRESP expected%0d got%0d",expected,bp);
  @(posedge ac);@(negedge ac);
 endtask
 task automatic read_status(input bit expected_done);
  @(negedge ac);araddr=4;arv=1;
  @(posedge ac);if(!arready)$fatal(1,"AR blocked");
  @(negedge ac);arv=0;wait(rv);
  if(rp!==0 || rd[1]!==expected_done)$fatal(1,"STATUS read mismatch %h",rd);
  @(posedge ac);@(negedge ac);
 endtask
 initial begin
  #1;rst=0;#22;rst=1;
  // Independent boundary scheduler: apply only after the real pending capture.
  fork
   begin wait(dut.cfg_pending_valid);@(negedge cc);boundary=1;@(negedge cc);boundary=0;end
   begin
    write_reg(0,2,0); // identity COMMIT, RUN off
    // New hypothesis: issue W1C on the first AXIL edge after ack_sync2
    // falls, while cfg_seen_ack is still high. Read-only state observation.
    wait(dut.cfg_ack_sync2===1'b1);
    @(negedge dut.cfg_ack_sync2);
    @(negedge ac);awaddr=4;wd=2;awv=1;wv=1;
    @(posedge ac);
    if(!(dut.write_fire && busy && dut.cfg_seen_ack_q && !dut.cfg_ack_sync2))
      $fatal(1,"exact DONE/W1C conjunction absent");
    collisions++;event_w1c=dut.write_fire;event_return=busy&&dut.cfg_seen_ack_q&&!dut.cfg_ack_sync2;event_set=1;cov.sample();
    $display("DONE_W1C_EVENT time_ps=%0t epoch=0 write_fire=1 seen_ack=1 ack_sync2=0 expected_set_wins=1",$time);
    #1ps;if(!done||busy)$fatal(1,"DONE set did not win W1C");
    @(negedge ac);awv=0;wv=0;
    @(posedge ac);@(negedge ac);
    read_status(1);
    write_reg(4,2,0);read_status(0);
    // Existing error contract: unmapped address, illegal taps then commit.
    write_reg(8'h83,0,3);
    write_reg(8,2,0);write_reg(0,2,2);
    if(!err)$fatal(1,"illegal taps did not set error");
    $display("DONE_W1C_PRIORITY_PASS collisions=%0d functional_cross=%0.2f clear_readback=PASS DECERR=PASS SLVERR=PASS",collisions,cov.get_inst_coverage());
    $finish;
   end
  join
 end
 initial begin #20000;$fatal(1,"priority watchdog");end
endmodule
