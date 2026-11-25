// Reset the real public input FIFO while full and the selected DSM is still at
// reset state, then replay one complete product stream against the golden
// four-plane oracle. No internal occupancy or state is forced.
class thermo5_sku_fifo_full_reset_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_fifo_full_reset_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);

    send_source(16);
    wait(env.source.monitor.accepted_beats==16);
    for (int cycles=0;cycles<16 && !vif.fifo_full;cycles++) begin
      @(posedge vif.src_clk);
      #1ps;
    end
    if (!vif.fifo_full || vif.src_ready || vif.tidsm_state_zero!==4'hf)
      `uvm_fatal("FULL_FIFO_RESET_SETUP",
        $sformatf("Expected public full FIFO and reset DSM state; full=%b ready=%b tidsm_zero=%h accepted=%0d",
          vif.fifo_full,vif.src_ready,vif.tidsm_state_zero,
          env.source.monitor.accepted_beats))

    // Assert immediately after an observed source-clock edge to exercise the
    // source_edge_recent phase using the real public reset interface.
    @(posedge vif.src_clk);
    #1ps;
    env.control.reset_both();
    if (!vif.fifo_empty || vif.tidsm_state_zero!==4'hf)
      `uvm_fatal("FULL_FIFO_RESET_CLEAR",
        $sformatf("Reset did not flush FIFO/DSM: empty=%b tidsm_zero=%h",
          vif.fifo_empty,vif.tidsm_state_zero))

    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=4);
        env.control.core_on();
        for (int cycles=0;cycles<10000 && env.scoreboard.checked<cfg.core_words;cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("FULL_FIFO_RESET_REPLAY_TIMEOUT",
            $sformatf("Bit-true replay reached %0d/%0d output words",
              env.scoreboard.checked,cfg.core_words))
        env.control.core_off();
      end
    join

    // The pre-reset fill is deliberately discarded, so event counters that
    // span reset epochs are not compared with the post-reset stream totals.
    check_full(0);
    if (env.scoreboard.reset_epochs!=1 || env.coverage.reset_reassertions<1)
      `uvm_fatal("FULL_FIFO_RESET_EPOCH",
        $sformatf("Expected one full-FIFO reset epoch, scoreboard=%0d coverage=%0d",
          env.scoreboard.reset_epochs,env.coverage.reset_reassertions))
    `uvm_info("SKU_PASS",
      "THERMO5_FULL_FIFO_RESET_UVM_PASS full FIFO reset from zero DSM followed by complete four-plane bit-true replay",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
