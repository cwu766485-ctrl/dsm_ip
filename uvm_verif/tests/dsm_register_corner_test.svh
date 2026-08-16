class dsm_register_corner_test extends dsm_base_test;
  `uvm_component_utils(dsm_register_corner_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // This is a control-plane coverage test.  It deliberately injects a
    // disabled-stream transaction before the known bit-true vector, so the
    // full-chain queue is intentionally not enabled here.
    cfg.enable_fullchain_check = 1'b0;
    cfg.post_sequence_cycles = 2048;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_register_corner_virtual_sequence seq;
    seq = dsm_register_corner_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
