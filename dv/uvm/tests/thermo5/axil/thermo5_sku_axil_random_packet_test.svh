// Reproducible product-path packet test. Python generates the bit-true input
// vectors for the seed; UVM randomizes bounded source gaps and four-plane PA
// readiness. Runtime DPD remains at the frozen identity reset image.
class thermo5_sku_axil_random_packet_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_random_packet_test)

  int unsigned random_gap_max_cycles;
  int unsigned expected_last_count;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    if (cfg.core_words!=56 && cfg.core_words!=112)
      `uvm_fatal("RANDOM_WORDS","System random test supports 56 or 112 output words")
    cfg.frame_starts=(cfg.core_words/56)*3;
    expected_last_count=cfg.source_beats/32;
    cfg.pa_sink_active=UVM_ACTIVE;
    cfg.random_pa_ready=1'b1;
    cfg.manual_pa_ready=1'b0;
    cfg.random_partial_pa_ready=1'b1;
    cfg.pa_stall_percent=25;
    void'($value$plusargs("THERMO5_RANDOM_PA_STALL_PERCENT=%d",cfg.pa_stall_percent));
    void'($value$plusargs("THERMO5_RANDOM_SOURCE_GAP_MAX=%d",random_gap_max_cycles));
    if (cfg.pa_stall_percent>80 || random_gap_max_cycles>8)
      `uvm_fatal("RANDOM_LIMIT","Random PA stall/gap setting exceeds the qualified bound")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_sku_axil_packet_vseq vseq;
    int unsigned source_beats;
    phase.raise_objection(this);
    vseq=thermo5_sku_axil_packet_vseq::type_id::create("random_packet_vseq");
    vseq.prefill_beats=16;
    vseq.random_gap_max_cycles=random_gap_max_cycles;
    vseq.packet_beats=32;
    vseq.start(env.virtual_sequencer);

    source_beats=env.source.monitor.accepted_beats;
    if (source_beats!=cfg.source_beats ||
        env.scoreboard.source_checked!=cfg.source_beats ||
        env.scoreboard.checked!=cfg.core_words ||
        env.coverage.pa_words!=cfg.core_words ||
        env.coverage.frame_starts!=cfg.frame_starts ||
        env.source.monitor.accepted_last_count!=expected_last_count)
      `uvm_fatal("RANDOM_COUNTS",
        $sformatf("source=%0d/%0d checked_source=%0d PA=%0d/%0d frame_starts=%0d/%0d TLAST=%0d/%0d",
          source_beats,cfg.source_beats,env.scoreboard.source_checked,
          env.scoreboard.checked,cfg.core_words,env.coverage.frame_starts,
          cfg.frame_starts,env.source.monitor.accepted_last_count,expected_last_count))
    if (vif.protocol_error || vif.underflow ||
        env.coverage.protocol_error_cycles!=0 ||
        env.coverage.underflow_cycles!=0 ||
        env.register_predictor.mismatches!=0)
      `uvm_fatal("RANDOM_INTEGRITY",
        $sformatf("protocol=%b underflow=%b underflow_cycles=%0d predictor_mismatches=%0d",
          vif.protocol_error,vif.underflow,env.coverage.underflow_cycles,
          env.register_predictor.mismatches))
    if (env.monitor.stall_cycles==0)
      `uvm_fatal("RANDOM_PA_STALL","Random PA readiness did not create a stall")
    for (int lane=0;lane<16;lane++) begin
      if (vif.dpd_sample_count[lane]!==cfg.core_words+cfg.frame_starts ||
          vif.dpd_saturation_count[lane]!==0)
        `uvm_fatal("RANDOM_DPD_IDENTITY",
          $sformatf("lane=%0d samples=%0d expected=%0d saturation=%0d",lane,
            vif.dpd_sample_count[lane],cfg.core_words+cfg.frame_starts,
            vif.dpd_saturation_count[lane]))
    end
    `uvm_info("SKU_PASS",
      $sformatf("THERMO5_TX_RANDOM_PACKET_PASS source=%0d PA=%0d TLAST=%0d source_stall=%0d PA_stall=%0d FIFO_full=%0d",
        source_beats,env.scoreboard.checked,expected_last_count,
        env.source.monitor.stall_cycles,env.monitor.stall_cycles,
        env.coverage.fifo_full_cycles),UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
