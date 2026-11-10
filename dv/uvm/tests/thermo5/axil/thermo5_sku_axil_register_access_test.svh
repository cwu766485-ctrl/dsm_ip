// AXI-Lite register/protocol verification without starting the thermo5 stream.
// End-to-end commit application and four-plane bit-true behavior are checked
// separately by thermo5_sku_axil_config_test and its image variants.
class thermo5_sku_axil_register_access_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_register_access_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

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
    `uvm_info("SKU_PASS",
      "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS: ID/STATUS/TAPS/coefficient map, AW/W skew, WSTRB, DECERR, response backpressure checked without stream traffic",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
