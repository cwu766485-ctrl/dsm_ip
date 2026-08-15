`timescale 1ns/1ps
module dsm_uvm_tb;
  import uvm_pkg::*;
  import dsm_uvm_pkg::*;
  logic aclk = 0; logic aresetn = 0;
  always #5 aclk = ~aclk;
  dsm_axi_lite_if axi_if(aclk, aresetn);
  dsm_axis_if tx_if(aclk, aresetn); dsm_axis_if obs_if(aclk, aresetn);
  dsm_rf_if rf_if(aclk, aresetn);
  dsm_ip_axi_top #(
    .ALGORITHM(DSM_SKU_ALGORITHM),
    .DUC_MODE(DSM_SKU_DUC_MODE),
    .INTERP_MODE(DSM_SKU_INTERP_MODE),
    .INTERP_IMPL(DSM_SKU_INTERP_IMPL),
    .ENABLE_DPD_POLY(DSM_SKU_ENABLE_DPD_POLY),
    .ENABLE_DPD_LUT(DSM_SKU_ENABLE_DPD_LUT),
    .ENABLE_DPD_MEMORY(DSM_SKU_ENABLE_DPD_MEMORY),
    .DPD_MP_MAX_TAPS(DSM_SKU_DPD_MP_MAX_TAPS),
    .DPD_POLY_ORDER(DSM_SKU_DPD_POLY_ORDER),
    .CLK_FREQ_HZ(DSM_SKU_ACLK_HZ)
  ) dut (
    .aclk(aclk), .aresetn(aresetn),
    .s_axi_awaddr(axi_if.awaddr), .s_axi_awvalid(axi_if.awvalid), .s_axi_awready(axi_if.awready),
    .s_axi_wdata(axi_if.wdata), .s_axi_wstrb(axi_if.wstrb), .s_axi_wvalid(axi_if.wvalid), .s_axi_wready(axi_if.wready),
    .s_axi_bresp(axi_if.bresp), .s_axi_bvalid(axi_if.bvalid), .s_axi_bready(axi_if.bready),
    .s_axi_araddr(axi_if.araddr), .s_axi_arvalid(axi_if.arvalid), .s_axi_arready(axi_if.arready),
    .s_axi_rdata(axi_if.rdata), .s_axi_rresp(axi_if.rresp), .s_axi_rvalid(axi_if.rvalid), .s_axi_rready(axi_if.rready),
    .s_axis_tdata(tx_if.tdata), .s_axis_tlast(tx_if.tlast), .s_axis_tuser(tx_if.tuser), .s_axis_tvalid(tx_if.tvalid), .s_axis_tready(tx_if.tready),
    .s_axis_obs_tdata(obs_if.tdata), .s_axis_obs_tlast(obs_if.tlast), .s_axis_obs_tuser(obs_if.tuser), .s_axis_obs_tvalid(obs_if.tvalid), .s_axis_obs_tready(obs_if.tready),
    .obs_irq(rf_if.obs_irq), .dsm_valid(rf_if.dsm_valid), .i_bit(rf_if.i_bit), .q_bit(rf_if.q_bit),
    .i_yout(rf_if.i_yout), .q_yout(rf_if.q_yout), .rf_valid(rf_if.rf_valid), .rf_bit(rf_if.rf_bit), .rf_signed(rf_if.rf_signed), .phase_acc_dbg(rf_if.phase_acc_dbg));

  dsm_axi_lite_protocol_sva axi_lite_sva (
    .aclk(aclk), .aresetn(aresetn),
    .awaddr(axi_if.awaddr), .awvalid(axi_if.awvalid), .awready(axi_if.awready),
    .wdata(axi_if.wdata), .wstrb(axi_if.wstrb), .wvalid(axi_if.wvalid),
    .wready(axi_if.wready), .bresp(axi_if.bresp), .bvalid(axi_if.bvalid),
    .bready(axi_if.bready), .araddr(axi_if.araddr), .arvalid(axi_if.arvalid),
    .arready(axi_if.arready), .rdata(axi_if.rdata), .rresp(axi_if.rresp),
    .rvalid(axi_if.rvalid), .rready(axi_if.rready));
  dsm_axis_protocol_sva tx_axis_sva (
    .aclk(aclk), .aresetn(aresetn), .tx_tdata(tx_if.tdata), .tx_tuser(tx_if.tuser),
    .tx_tvalid(tx_if.tvalid), .tx_tready(tx_if.tready), .tx_tlast(tx_if.tlast));
  dsm_axis_protocol_sva obs_axis_sva (
    .aclk(aclk), .aresetn(aresetn), .tx_tdata(obs_if.tdata), .tx_tuser(obs_if.tuser),
    .tx_tvalid(obs_if.tvalid), .tx_tready(obs_if.tready), .tx_tlast(obs_if.tlast));
  dsm_rf_protocol_sva rf_sva (
    .aclk(aclk), .aresetn(aresetn), .rf_valid(rf_if.rf_valid),
    .rf_bit(rf_if.rf_bit), .rf_signed(rf_if.rf_signed));
  dsm_ip_control_sva control_sva (
    .aclk(aclk), .aresetn(aresetn), .soft_reset(dut.soft_reset),
    .s_axis_tready(tx_if.tready), .axis_buf_valid(dut.axis_buf_valid), .rf_valid(rf_if.rf_valid),
    .mp_commit_pending(dut.mp_commit_pending), .mp_commit_inflight(dut.mp_commit_inflight),
    .mp_commit_pulse(dut.mp_commit_pulse),
    .mp_commit_success_event(dut.mp_commit_success_event),
    .mp_commit_ack(dut.mp_commit_ack), .mp_commit_failed(dut.mp_commit_failed),
    .mp_commit_epoch(dut.mp_commit_epoch), .mp_active_bank(dut.mp_active_bank),
    .obs_enable(dut.obs_enable_reg), .obs_active(dut.obs_active),
    .obs_ready(obs_if.tready));
  initial begin
    axi_if.awvalid=0; axi_if.wvalid=0; axi_if.arvalid=0; axi_if.bready=1; axi_if.rready=1;
    tx_if.tvalid=0; obs_if.tvalid=0; aresetn=0;
    repeat(8) @(posedge aclk);
    aresetn=1;
  end

  initial begin
    string test_name;
    // Configure the actual consumer instances.  The drivers call get(this,
    // "", "vif"), so these paths must include the driver/monitor leaf.
    uvm_config_db#(virtual dsm_axi_lite_if)::set(null, "uvm_test_top.env.axi_agent.*", "vif", axi_if);
    uvm_config_db#(virtual dsm_axis_if)::set(null, "uvm_test_top.env.tx_agent.*", "vif", tx_if);
    uvm_config_db#(virtual dsm_axis_if)::set(null, "uvm_test_top.env.obs_agent.*", "vif", obs_if);
    uvm_config_db#(virtual dsm_rf_if)::set(null, "uvm_test_top.env.rf_agent.monitor", "vif", rf_if);
    if (!$value$plusargs("UVM_TESTNAME=%s", test_name)) begin
      if (!$value$plusargs("UVM_TESTNAME+%s", test_name))
        test_name = "dsm_bp_test";
    end
    run_test(test_name);
  end

`ifdef DSM_ENABLE_FSDB
  initial begin
    string fsdb_file;
    if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
      fsdb_file = "dsm_uvm.fsdb";
    $fsdbDumpfile(fsdb_file);
    $fsdbDumpvars(0, dsm_uvm_tb);
  end
`endif
endmodule
