

// A continuous accepted stream spans frame markers without resetting the
// datapath or counters. Every output still comes from the independent oracle.
class thermo5_sku_long_counter_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_long_counter_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    if(cfg.core_words<2072)
      `uvm_fatal("WORDS","Counter test requires at least 2072 golden words")
    cfg.random_pa_ready=1;
    cfg.pa_stall_percent=25;
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    // Finish the full independent stream check before discarding any state.
    super.run_phase(phase);
    env.control.reset_both();
    repeat(3) @(negedge vif.core_clk);
    for(int lane=0;lane<16;lane++)
      if(vif.dpd_sample_count[lane] !== 0 || vif.dpd_saturation_count[lane] !== 0)
        `uvm_fatal("DPD_RESET_COUNT",$sformatf("lane=%0d counters failed reset",lane))
    `uvm_info("SKU_PASS","THERMO5_LONG_COUNTER_RESET_PASS all 16 lane counters cleared after checked stream",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
