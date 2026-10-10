`timescale 1ns/1ps
`default_nettype none

// Legal AXI-Lite transactions reproduce the two defects fixed in 6deb799.
// Hierarchical references observe state; no DUT state or handshake is forced.
module tb_dsm_commit_bug_repro;
  logic aclk=0, aresetn=0;
  always #5 aclk=~aclk;
  logic [8:0] s_axi_awaddr=0, s_axi_araddr=0;
  logic s_axi_awvalid=0, s_axi_wvalid=0, s_axi_arvalid=0;
  logic [31:0] s_axi_wdata=0;
  logic [3:0] s_axi_wstrb=4'hf;
  wire s_axi_awready, s_axi_wready, s_axi_bvalid, s_axi_arready, s_axi_rvalid;
  wire [1:0] s_axi_bresp, s_axi_rresp;
  wire [31:0] s_axi_rdata;
  logic s_axi_bready=1, s_axi_rready=1;
  integer reset_completion_overlap=0;
  logic tx_valid=0;
  wire tx_ready;
  string scenario;

  dsm_ip_axi_top #(.ALGORITHM(3),.DUC_MODE(3),.INTERP_MODE(0),
    .ENABLE_DPD_MEMORY(1),.ENABLE_DPD_POLY(1),.ENABLE_DPD_LUT(0),
    .DPD_MP_MAX_TAPS(4)) dut (
    .aclk(aclk),.aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),.s_axi_bvalid(s_axi_bvalid),.s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),.s_axi_rresp(s_axi_rresp),.s_axi_rvalid(s_axi_rvalid),.s_axi_rready(s_axi_rready),
    .s_axis_tdata(32'h00010001),.s_axis_tlast(1'b1),.s_axis_tuser(1'b0),.s_axis_tvalid(tx_valid),.s_axis_tready(tx_ready),
    .s_axis_obs_tdata(32'd0),.s_axis_obs_tlast(1'b0),.s_axis_obs_tuser(1'b0),.s_axis_obs_tvalid(1'b0),
    .s_axis_obs_tready(),.obs_irq(),.dsm_valid(),.i_bit(),.q_bit(),.i_yout(),.q_yout(),
    .rf_valid(),.rf_bit(),.rf_signed(),.phase_acc_dbg()
  );

  task automatic write_reg(input logic [8:0] addr,input logic [31:0] data);
    bit aw_done=0,w_done=0;
    @(negedge aclk);
    s_axi_awaddr=addr; s_axi_wdata=data;
    s_axi_awvalid=1; s_axi_wvalid=1;
    while(!aw_done || !w_done) begin
      @(posedge aclk);
      if(s_axi_awvalid && s_axi_awready) aw_done=1;
      if(s_axi_wvalid && s_axi_wready) w_done=1;
      @(negedge aclk);
      if(aw_done) s_axi_awvalid=0;
      if(w_done) s_axi_wvalid=0;
    end
    wait(s_axi_bvalid); #1;
    if(s_axi_bresp!==0) $fatal(1,"AXI_WRITE_RESPONSE");
  endtask

  always @(posedge aclk)
    if(aresetn && dut.soft_reset && (dut.mp_commit_pending || dut.mp_commit_inflight))
      reset_completion_overlap++;
  always @(posedge aclk)
    if($test$plusargs("DEBUG_COMMIT") && aresetn)
      $display("COMMIT_TRACE t=%0t write=%b addr=%h pending=%b inflight=%b pulse=%b bank=%b target=%b soft=%b epoch=%0d",
        $time,dut.axi_write_fire,dut.axi_aw_word_addr,dut.mp_commit_pending,dut.mp_commit_inflight,
        dut.mp_commit_pulse,dut.mp_active_bank,dut.mp_commit_target_bank,dut.soft_reset,dut.mp_commit_epoch);

  initial begin
    if(!$value$plusargs("CASE=%s",scenario)) $fatal(1,"Pass +CASE=stale_reject or reset_completion");
    repeat(5) @(negedge aclk); aresetn=1;
    repeat(3) @(negedge aclk);
    if(scenario=="stale_reject") begin
      write_reg(9'h040,32'h100); // safety on
      write_reg(9'h090,32'h400); // tap zero, c1, four active taps
      write_reg(9'h094,32'h6001); // unsafe update
      write_reg(9'h098,1);
      wait(dut.mp_commit_failed); repeat(2) @(negedge aclk);
      if(!dut.dpd_mp_commit_rejected || dut.mp_active_bank!==0)
        $fatal(1,"STALE_REJECT_PRECONDITION");
      write_reg(9'h040,0); // safety off: stale rejection intentionally stays set
      write_reg(9'h094,32'h4000);
      write_reg(9'h098,1);
      repeat(8) @(negedge aclk);
      if(dut.mp_commit_ack!==1 || dut.mp_commit_failed!==0 ||
         dut.mp_commit_epoch!==1 || dut.mp_active_bank!==1)
        $fatal(1,"BUG_STALE_REJECTION ack=%b failed=%b epoch=%0d bank=%b",
          dut.mp_commit_ack,dut.mp_commit_failed,dut.mp_commit_epoch,dut.mp_active_bank);
      $display("COMMIT_BUG_REPRO_PASS case=stale_reject ack=1 failed=0 epoch=1 bank=1");
    end else if(scenario=="reset_completion") begin
      write_reg(9'h098,1);
      wait(dut.mp_commit_ack);
      repeat(2) @(negedge aclk);
      if(dut.mp_active_bank!==1 || dut.mp_commit_epoch!==1)
        $fatal(1,"RESET_COMPLETION_INITIAL_BANK");
      write_reg(9'h040,3); // select memory DPD
      write_reg(9'h000,1); // enable data flow
      @(negedge aclk); tx_valid=1;
      @(posedge aclk); while(!tx_ready) @(posedge aclk);
      @(negedge aclk); tx_valid=0;
      write_reg(9'h098,1);
      write_reg(9'h000,2); // earliest following legal write cancels completion
      repeat(8) @(negedge aclk);
      if(reset_completion_overlap!=1) $fatal(1,"RESET_COMPLETION_PRECONDITION overlap=%0d",reset_completion_overlap);
      if(dut.mp_commit_epoch!==1 || dut.mp_commit_ack!==0 ||
         dut.mp_commit_pending!==0 || dut.mp_commit_inflight!==0 || dut.mp_active_bank!==0)
        $fatal(1,"BUG_RESET_COMPLETION epoch=%0d ack=%b pending=%b inflight=%b bank=%b",
          dut.mp_commit_epoch,dut.mp_commit_ack,dut.mp_commit_pending,dut.mp_commit_inflight,dut.mp_active_bank);
      $display("COMMIT_BUG_REPRO_PASS case=reset_completion overlap=1 epoch=1 transaction_cancelled=1 bank=0");
    end else $fatal(1,"Unknown CASE");
    $finish;
  end
  initial begin
    repeat(1000) @(posedge aclk);
    $fatal(1,"COMMIT_BUG_REPRO_TIMEOUT");
  end
endmodule
`default_nettype wire
