// AXI-Lite register/protocol verification without starting the thermo5 stream.
// End-to-end commit application and four-plane bit-true behavior are checked
// separately by thermo5_sku_axil_config_test and its image variants.
class thermo5_sku_axil_register_access_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_register_access_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task probe_write_during_bstall();
    virtual thermo5_axil_if avif;
    bit [31:0] data;
    bit [1:0] resp;
    avif=env.axil.monitor.vif;
    @(negedge avif.aclk);
    avif.bready<=0;
    avif.awaddr<=8'h08;
    avif.wdata<=32'd1;
    avif.wstrb<=4'hf;
    avif.awvalid<=1;
    avif.wvalid<=1;
    @(posedge avif.aclk);
    if (!avif.awready || !avif.wready)
      `uvm_fatal("AXIL_BSTALL_FIRST","First AW/W not accepted")
    @(negedge avif.aclk);
    // Present the next transaction while retaining the first B response.
    avif.awaddr<=8'h00;
    avif.wdata<=0;
    repeat (3) begin
      @(posedge avif.aclk);
      if (!avif.bvalid || avif.bresp!=0 || avif.awready || avif.wready)
        `uvm_fatal("AXIL_BSTALL_HOLD","B response or AW/W backpressure changed")
    end
    @(negedge avif.aclk);
    avif.bready<=1;
    @(posedge avif.aclk); // First response accepted; AW/W must remain held.
    @(posedge avif.aclk);
    if (!avif.awready || !avif.wready)
      `uvm_fatal("AXIL_BSTALL_RELEASE","Second AW/W not accepted after B")
    @(negedge avif.aclk);
    avif.awvalid<=0;
    avif.wvalid<=0;
    @(posedge avif.aclk);
    if (!avif.bvalid || avif.bresp!=0)
      `uvm_fatal("AXIL_BSTALL_SECOND","Second B response missing or incorrect")
    @(negedge avif.aclk);
    avif.bready<=0;
    axil_read(8'h08,data,resp);
    if (resp!=0 || data[2:0]!=1)
      `uvm_fatal("AXIL_BSTALL_READBACK","TAPS write/readback mismatch")
    axil_read(8'h00,data,resp);
    if (resp!=0 || data[0]!=0)
      `uvm_fatal("AXIL_BSTALL_CONTROL","CONTROL write/readback mismatch")
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);
    wait_axil_reset_release();
    run_register_access_checks();
    // Return both high-address and low alignment bits to zero after DECERR.
    // Delay W so AW is captured in awaddr_q before write_addr selects it.
    axil_write(8'h83,32'd0,0,2,resp,4'hf,1'b1);
    if (resp!=2'b11)
      `uvm_fatal("AXIL_ADDRESS_RETURN","Unmapped unaligned write must return DECERR")
    axil_write(8'h00,32'd0,0,2,resp,4'hf,1'b1);
    if (resp!=2'b00)
      `uvm_fatal("AXIL_ADDRESS_RETURN","Legal CONTROL write after DECERR failed")
    probe_write_during_bstall();
    `uvm_info("SKU_PASS",
      "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS: ID/STATUS/TAPS/coefficient map, AW/W skew, WSTRB, DECERR, response backpressure checked without stream traffic",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
