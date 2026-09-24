class dsm_qam_ofdm_bittrue_test extends dsm_base_test;
  `uvm_component_utils(dsm_qam_ofdm_bittrue_test)

  localparam int unsigned QAM_OFDM_INPUT_COUNT = 10_240;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.enable_fullchain_check = 1'b1;
    cfg.fullchain_vector_set = "qam_ofdm";
    cfg.expected_rf_count = QAM_OFDM_INPUT_COUNT * DSM_SKU_INTERP_RATIO;
    cfg.post_sequence_cycles = 64;
    cfg.drain_timeout_cycles = 2_000_000;
  endfunction

  task run_phase(uvm_phase phase);
    dsm_qam_ofdm_bittrue_virtual_sequence seq;
    int unsigned drain_cycles;
    phase.raise_objection(this);
    seq = dsm_qam_ofdm_bittrue_virtual_sequence::type_id::create("seq");
    seq.start(env.virtual_sequencer);
    drain_cycles = 0;
    while ((env.scoreboard.rf_count < cfg.expected_rf_count) &&
           (drain_cycles < cfg.drain_timeout_cycles)) begin
      @(posedge env.axi_agent.driver.vif.aclk);
      drain_cycles++;
    end
    if (env.scoreboard.rf_count != cfg.expected_rf_count)
      `uvm_error("DRAIN_TIMEOUT", $sformatf("RF drain %0d/%0d after %0d cycles",
                 env.scoreboard.rf_count, cfg.expected_rf_count, drain_cycles))
    repeat (cfg.post_sequence_cycles) @(posedge env.axi_agent.driver.vif.aclk);
    phase.drop_objection(this);
  endtask
endclass
