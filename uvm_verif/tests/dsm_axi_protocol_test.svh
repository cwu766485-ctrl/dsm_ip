class dsm_axi_protocol_test extends dsm_base_test;
  `uvm_component_utils(dsm_axi_protocol_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.expected_rf_count = 64 * DSM_SKU_INTERP_RATIO;
    cfg.post_sequence_cycles = 256;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_protocol_virtual_sequence seq;
    int unsigned drain_cycles;
    seq = dsm_protocol_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    drain_cycles = 0;
    while ((env.scoreboard.rf_count < cfg.expected_rf_count) &&
           (drain_cycles < cfg.drain_timeout_cycles)) begin
      @(posedge env.axi_agent.driver.vif.aclk);
      drain_cycles++;
    end
    if (env.scoreboard.rf_count != cfg.expected_rf_count)
      `uvm_error("DRAIN_TIMEOUT",
                 $sformatf("RF drain stopped at %0d/%0d after %0d cycles",
                           env.scoreboard.rf_count, cfg.expected_rf_count,
                           drain_cycles))
    phase.drop_objection(this);
  endtask
endclass
