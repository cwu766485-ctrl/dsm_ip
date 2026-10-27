

class thermo5_sku_reset_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_reset_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.manual_pa_ready=1'b1;
  endfunction

  task run_centered_tail_reset_and_replay();
    bit tail_held;
    env.control.reset_both();
    vif.pa_ready=4'hf;
    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=4);
        env.control.core_on();
        for (int cycles=0; cycles<10000 && env.scoreboard.checked<cfg.core_words-1; cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words-1)
          `uvm_fatal("RESET_TAIL_SETUP",
            $sformatf("Could not reach last expected output: words=%0d",
              env.scoreboard.checked))

        // Stall the final four-plane output (the centered frame-tail word)
        // by deasserting readiness on one PA plane, then reset while held.
        @(negedge vif.core_clk);
        vif.pa_ready=4'hd;
        tail_held=0;
        for (int cycles=0; cycles<1000 && !tail_held; cycles++) begin
          @(posedge vif.core_clk);
          tail_held=(vif.pa_valid==4'hf && vif.pa_ready==4'hd);
        end
        if (!tail_held)
          `uvm_fatal("RESET_TAIL_STALL","Final frame-tail PA word did not stall")
        for (int cycles=0; cycles<1000 &&
             env.source.monitor.accepted_last_count==0; cycles++)
          @(posedge vif.src_clk);
        if (env.source.monitor.accepted_last_count!=1)
          `uvm_fatal("RESET_TAIL_TLAST","Final frame-end marker was not accepted before reset")
        repeat (4) begin
          @(posedge vif.core_clk);
          if (vif.pa_valid!=4'hf || vif.pa_ready!=4'hd)
            `uvm_fatal("RESET_TAIL_HOLD","Final PA word did not remain held")
        end
        env.control.reset_both(1'b1);
        if (vif.ef2_state_zero!==4'hf)
          `uvm_fatal("RESET_TAIL_EF2_STATE","EF2 state did not clear with the centered tail")
      end
    join

    vif.pa_ready=4'hf;
    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=4);
        env.control.core_on();
        wait(env.scoreboard.checked==cfg.core_words);
        env.control.core_off();
        check_full(0);
      end
    join
    if (env.coverage.reset_nonzero_ef2_state_events<2)
      `uvm_fatal("RESET_EF2_COVERAGE",
        $sformatf("Expected two resets from nonzero EF2 state, observed %0d",
          env.coverage.reset_nonzero_ef2_state_events))
    `uvm_info("SKU_PASS","THERMO5_CENTERED_TAIL_RESET_PASS final PA tail held under partial ready, reset cleared EF2, bit-true replay passed",UVM_NONE)
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(24);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.source.monitor.accepted_beats==24 && env.scoreboard.checked>=4);
            for (int cycles=0; cycles<1000 && vif.ef2_state_zero==4'hf; cycles++)
              @(posedge vif.core_clk);
            if (vif.ef2_state_zero==4'hf)
              `uvm_fatal("RESET_EF2_SETUP","EF2 state did not become nonzero before reset")
          end
        join
        @(negedge vif.core_clk);
        // Assert both resets while enable is high to exercise the two
        // reset-with-enable condition bins at each interpolation instance.
        env.control.reset_both(1'b1);
        if (vif.ef2_state_zero!==4'hf)
          `uvm_fatal("RESET_EF2_STATE","EF2 state did not clear after active-stream reset")
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            if (env.scoreboard.reset_epochs!=1 || env.coverage.reset_reassertions==0)
              `uvm_fatal("RESET_REPLAY","Reset epoch was not observed")
            check_full(0);
`ifdef THERMO5_CENTERED_CUBIC
            run_centered_tail_reset_and_replay();
`endif
            `uvm_info("SKU_PASS","THERMO5_RESET_UVM_PASS reset discards partial state; frame-tail reset and replay are bittrue",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Reset replay did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
