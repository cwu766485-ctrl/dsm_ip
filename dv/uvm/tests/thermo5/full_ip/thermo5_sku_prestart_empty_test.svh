

class thermo5_sku_prestart_empty_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_prestart_empty_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);
    env.control.core_on();
    repeat(80) @(negedge vif.core_clk);
    if(vif.underflow || vif.protocol_error || vif.pa_valid!=0)
      `uvm_fatal("PRESTART_EMPTY","Empty pre-frame core must stay quiet without underflow")
    env.control.core_off();
    super.run_phase(phase);
    `uvm_info("SKU_PASS","THERMO5_PRESTART_EMPTY_PASS quiet empty core then complete independent stream",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
