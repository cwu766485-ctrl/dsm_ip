// Product-top constrained-random stream test. It deliberately runs without
// the optional AXI-Lite wrapper so Product and AXI-Lite coverage stay in
// separate elaboration databases.
class thermo5_sku_product_random_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_product_random_test)

  int unsigned random_gap_max_cycles;
  int unsigned prefill_beats;
  bit reset_case;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    if (cfg.core_words%56!=0)
      `uvm_fatal("PRODUCT_RANDOM_WORDS",
        "Product random vectors must contain complete 56-word frame quanta")
    cfg.frame_starts=(cfg.core_words/56)*3;
    reset_case=$test$plusargs("THERMO5_RANDOM_RESET_CASE");
    cfg.random_pa_ready=!reset_case;
    cfg.random_partial_pa_ready=1'b1;
    cfg.manual_pa_ready=reset_case;
    cfg.pa_stall_percent=25;
    cfg.ef2_reference_enable=1'b1;
    prefill_beats=16;
    void'($value$plusargs("THERMO5_RANDOM_PA_STALL_PERCENT=%d",cfg.pa_stall_percent));
    void'($value$plusargs("THERMO5_RANDOM_SOURCE_GAP_MAX=%d",random_gap_max_cycles));
    void'($value$plusargs("THERMO5_RANDOM_PREFILL_BEATS=%d",prefill_beats));
    if (cfg.pa_stall_percent>80 || random_gap_max_cycles>8 ||
        prefill_beats==0 || prefill_beats>=cfg.source_beats)
      `uvm_fatal("PRODUCT_RANDOM_LIMIT",
        "Random PA stall/gap/prefill setting exceeds the qualified bound")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_source_sequence source_seq;
    phase.raise_objection(this);

    if (reset_case) begin
      run_reset_context();
      phase.drop_objection(this);
      return;
    end

    source_seq=thermo5_source_sequence::type_id::create("product_random_source");
    source_seq.cfg=cfg;
    source_seq.beat_count=cfg.source_beats;
    source_seq.mark_last=1'b1;
    source_seq.random_gap_max_cycles=random_gap_max_cycles;
    source_seq.random_gap_limit_beats=prefill_beats;

    fork
      begin
        fork
          source_seq.start(env.source.sequencer);
          begin
          // Fill the real public input FIFO before starting the core. The
          // packet coverage model can then observe one legal packet that had
          // a source gap, reached FIFO-full, and later stalled at parallel PA.
          // Do not force an internal FIFO count or manufacture a coverage hit.
          wait(vif.fifo_full===1'b1);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
          end
        join
      end
      begin
        repeat(10000+8*cfg.core_words) @(posedge vif.core_clk);
        `uvm_fatal("PRODUCT_RANDOM_TIMEOUT",
          "Product random stream did not drain before the bounded timeout")
      end
    join_any
    disable fork;

    #1ps;
    check_full();
    // Finalize packet-scoped crosses only after the source/PA conservation,
    // bit-true scoreboard, and expected-queue checks have passed.
    env.coverage.finalize_packet_crosses(1'b1);
    if (env.event_bus.source_beats!=cfg.source_beats ||
        env.event_bus.cdc_words!=cfg.core_words ||
        env.event_bus.ef2_words!=cfg.core_words ||
        env.event_bus.pa_words!=cfg.core_words)
      `uvm_fatal("PRODUCT_RANDOM_EVENT_COUNTS",
        $sformatf("source=%0d/%0d CDC=%0d/%0d EF2=%0d/%0d PA=%0d/%0d",
          env.event_bus.source_beats,cfg.source_beats,
          env.event_bus.cdc_words,cfg.core_words,
          env.event_bus.ef2_words,cfg.core_words,
          env.event_bus.pa_words,cfg.core_words))
    if (!reset_case && env.monitor.stall_cycles==0)
      `uvm_fatal("PRODUCT_RANDOM_PA_STALL",
        "Random partial PA readiness did not stall a Product output")
    if (!reset_case && env.coverage.source_gap_pa_fifo_full_hits==0)
      `uvm_fatal("PRODUCT_RANDOM_FIFO_FULL_CROSS",
        "No integrity-checked packet covered source gap, real FIFO full, and PA stall")
    if (!env.unified_scoreboard.check_expected_queues_drained("product-random"))
      `uvm_fatal("PRODUCT_RANDOM_QUEUE",
        "Independent reference scoreboard left an expected transaction pending")

    `uvm_info("SKU_PASS",
      $sformatf("DSM_V13_PRODUCT_RANDOM_PASS source=%0d PA=%0d TLAST=%0d source_gap_max=%0d PA_stall=%0d",
        env.source.monitor.accepted_beats,env.scoreboard.checked,
        env.source.monitor.accepted_last_count,random_gap_max_cycles,
        env.monitor.stall_cycles),UVM_NONE)
    phase.drop_objection(this);
  endtask

  task run_reset_context();
    thermo5_source_sequence prefix_seq, replay_seq;
    prefix_seq=thermo5_source_sequence::type_id::create("reset_prefix_source");
    prefix_seq.cfg=cfg;
    prefix_seq.beat_count=prefill_beats;
    prefix_seq.mark_last=1'b0;
    prefix_seq.random_gap_max_cycles=random_gap_max_cycles;
    prefix_seq.random_gap_limit_beats=prefill_beats;
    prefix_seq.start(env.source.sequencer);
    if (vif.fifo_empty)
      `uvm_fatal("PRODUCT_RESET_PREFILL","FIFO did not reach a nonempty public state")

    env.control.core_on();
    wait(vif.pa_valid==4'hf);
    env.pa_sink.set_ready(4'h0);
    repeat(2) @(posedge vif.core_clk);
    #1ps;
    if (vif.pa_valid!==4'hf || vif.pa_ready!==4'h0)
      `uvm_fatal("PRODUCT_RESET_HELD_OUTPUT",
        "Reset scenario failed to hold a valid four-plane output")
    env.control.reset_both();
    #1ps;
    if (vif.pa_valid!==4'h0)
      `uvm_fatal("PRODUCT_RESET_STALE_OUTPUT",
        "Public reset left a stale PA output valid")
    env.pa_sink.set_ready(4'hf);

    replay_seq=thermo5_source_sequence::type_id::create("reset_replay_source");
    replay_seq.cfg=cfg;
    replay_seq.beat_count=cfg.source_beats;
    replay_seq.mark_last=1'b1;
    replay_seq.random_gap_max_cycles=0;
    replay_seq.random_gap_limit_beats=prefill_beats;
    fork
      replay_seq.start(env.source.sequencer);
      begin
        wait(env.source.monitor.accepted_beats>=prefill_beats);
        env.control.core_on();
        wait(env.scoreboard.checked==cfg.core_words);
        env.control.core_off();
      end
    join
    #1ps;
    check_full(0);
    if (env.scoreboard.reset_epochs<1 || env.coverage.reset_reassertions<1)
      `uvm_fatal("PRODUCT_RESET_EPOCH",
        $sformatf("Reset evidence missing: epochs=%0d reset_events=%0d",
          env.scoreboard.reset_epochs,env.coverage.reset_reassertions))
    if (!env.unified_scoreboard.check_expected_queues_drained("product-reset-context"))
      `uvm_fatal("PRODUCT_RESET_QUEUE",
        "Post-reset replay did not drain independent expected transactions")
    `uvm_info("SKU_PASS",
      $sformatf("DSM_V13_PRODUCT_RESET_RANDOM_PASS source=%0d PA=%0d TLAST=%0d reset_epochs=%0d held_output=1 fifo_nonempty=1",
        env.source.monitor.accepted_beats,env.scoreboard.checked,
        env.source.monitor.accepted_last_count,env.scoreboard.reset_epochs),UVM_NONE)
  endtask
endclass
