class dsm_commit_during_stream_test extends dsm_base_test;
  `uvm_component_utils(dsm_commit_during_stream_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.enable_fullchain_check = 1'b0;
    cfg.post_sequence_cycles = 4096;
    cfg.drain_timeout_cycles = 32768;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_commit_during_stream_virtual_sequence seq;
    phase.raise_objection(this);
    seq = dsm_commit_during_stream_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass


class dsm_commit_reset_interlock_test extends dsm_base_test;
  `uvm_component_utils(dsm_commit_reset_interlock_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.enable_fullchain_check = 1'b0;
    cfg.post_sequence_cycles = 4096;
    cfg.drain_timeout_cycles = 32768;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_commit_reset_interlock_virtual_sequence seq;
    phase.raise_objection(this);
    seq = dsm_commit_reset_interlock_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass


class dsm_axi_lite_channel_backpressure_test extends dsm_base_test;
  `uvm_component_utils(dsm_axi_lite_channel_backpressure_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.require_rf_output = 1'b0;
    cfg.require_rf_toggle = 1'b0;
    cfg.post_sequence_cycles = 64;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_axi_lite_channel_backpressure_virtual_sequence seq;
    phase.raise_objection(this);
    seq = dsm_axi_lite_channel_backpressure_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
