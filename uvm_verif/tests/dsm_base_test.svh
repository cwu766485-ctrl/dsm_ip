class dsm_base_test extends uvm_test;
  `uvm_component_utils(dsm_base_test)
  dsm_uvm_config cfg;
  dsm_env env;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg = dsm_uvm_config::type_id::create("cfg");
    uvm_config_db#(dsm_uvm_config)::set(this, "env", "cfg", cfg);
    env = dsm_env::type_id::create("env", this);
  endfunction
endclass
