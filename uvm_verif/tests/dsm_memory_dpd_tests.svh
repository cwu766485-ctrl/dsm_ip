class dsm_memory_dpd_bittrue_test extends dsm_base_test;
  `uvm_component_utils(dsm_memory_dpd_bittrue_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.enable_fullchain_check = 1'b1;
    cfg.fullchain_vector_set = "memory_dpd_system";
    cfg.expected_rf_count = 24 * DSM_SKU_INTERP_RATIO;
    cfg.post_sequence_cycles = 2048;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_memory_dpd_virtual_sequence seq;
    int unsigned drain_cycles;
    seq = dsm_memory_dpd_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    drain_cycles = 0;
    while ((env.scoreboard.rf_count < cfg.expected_rf_count) &&
           (drain_cycles < cfg.drain_timeout_cycles)) begin
      @(posedge env.axi_agent.driver.vif.aclk);
      drain_cycles++;
    end
    if (env.scoreboard.rf_count != cfg.expected_rf_count)
      `uvm_error("DRAIN_TIMEOUT", $sformatf("RF drain %0d/%0d", env.scoreboard.rf_count,
                 cfg.expected_rf_count))
    phase.drop_objection(this);
  endtask
endclass

class dsm_memory_dpd_safety_test extends dsm_base_test;
  `uvm_component_utils(dsm_memory_dpd_safety_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.require_rf_output = 1'b0;
    cfg.require_rf_toggle = 1'b0;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_memory_dpd_safety_virtual_sequence seq;
    seq = dsm_memory_dpd_safety_virtual_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.virtual_sequencer);
    phase.drop_objection(this);
  endtask
endclass
