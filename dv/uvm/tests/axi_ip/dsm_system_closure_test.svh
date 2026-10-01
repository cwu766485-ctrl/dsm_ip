class dsm_system_closure_test extends dsm_base_test;
  `uvm_component_utils(dsm_system_closure_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // This is a protocol/control closure test.  Exact full-chain RF vectors
    // are separately signed off by dsm_memory_dpd_bittrue_test.
    cfg.enable_fullchain_check = 1'b0;
    cfg.post_sequence_cycles = 2048;
    cfg.drain_timeout_cycles = 65536;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_system_closure_virtual_sequence seq;
    phase.raise_objection(this);
    seq = dsm_system_closure_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
