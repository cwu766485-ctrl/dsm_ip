// AXI-Lite register/protocol verification without starting the thermo5 stream.
// End-to-end commit application and four-plane bit-true behavior are checked
// separately by thermo5_sku_axil_config_test and its image variants.
class thermo5_sku_axil_register_access_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_register_access_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);
    wait_axil_reset_release();
    run_register_access_checks();
    `uvm_info("SKU_PASS",
      "THERMO5_AXIL_REGISTER_ACCESS_UVM_PASS: ID/STATUS/TAPS/coefficient map, AW/W skew, WSTRB, DECERR, response backpressure checked without stream traffic",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
