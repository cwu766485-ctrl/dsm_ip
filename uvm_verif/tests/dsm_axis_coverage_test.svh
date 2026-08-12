class dsm_axis_coverage_test extends dsm_base_test;
  `uvm_component_utils(dsm_axis_coverage_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // This testcase closes AXI-Stream sideband and handshake coverage.  It
    // intentionally uses only four directed TX samples, so the separate RF
    // density/toggle quality criterion belongs to dsm_bp_test and full-chain
    // bit-true tests rather than this protocol-focused test.
    cfg.require_rf_toggle = 1'b0;
    cfg.require_rf_output = 1'b1;
    cfg.post_sequence_cycles = 1024;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_axis_coverage_virtual_sequence seq;
    seq = dsm_axis_coverage_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
