class dsm_bp_test extends dsm_base_test;
  `uvm_component_utils(dsm_bp_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.expected_rf_count = 24 * DSM_SKU_INTERP_RATIO;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_bp_virtual_sequence seq;
    seq = dsm_bp_virtual_sequence::type_id::create("seq");
    seq.cfg = cfg;
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
