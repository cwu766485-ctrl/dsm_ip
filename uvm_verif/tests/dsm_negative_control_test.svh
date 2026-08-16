class dsm_negative_control_test extends dsm_base_test;
  `uvm_component_utils(dsm_negative_control_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.require_rf_toggle = 1'b0;
    cfg.post_sequence_cycles = 512;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_negative_control_virtual_sequence seq;
    phase.raise_objection(this);
    seq = dsm_negative_control_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
