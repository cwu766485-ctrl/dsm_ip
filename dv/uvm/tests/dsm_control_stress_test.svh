class dsm_control_stress_test extends dsm_base_test;
  `uvm_component_utils(dsm_control_stress_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.post_sequence_cycles = 4096;
    cfg.drain_timeout_cycles = 16384;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_control_stress_virtual_sequence seq;
    seq = dsm_control_stress_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
