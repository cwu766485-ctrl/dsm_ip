class dsm_rf_agent extends uvm_agent;
  `uvm_component_utils(dsm_rf_agent)
  dsm_rf_monitor monitor;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    is_active = UVM_PASSIVE;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = dsm_rf_monitor::type_id::create("monitor", this);
  endfunction
endclass
