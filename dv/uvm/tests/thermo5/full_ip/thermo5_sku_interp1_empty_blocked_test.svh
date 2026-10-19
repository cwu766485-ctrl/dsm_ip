

// Drive only public PA ready, on its inactive clock edge. An upstream bubble
// is observed after the chain has filled: stage 1 is empty while stage 2 and
// the output still carry real transactions. No DUT state is forced.
class thermo5_sku_interp1_empty_blocked_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_interp1_empty_blocked_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.manual_pa_ready=1;
  endfunction
  task run_phase(uvm_phase phase);
    int exact_hits=0;
    phase.raise_objection(this);
    fork
      begin
        fork
          // Let the elastic chain fill before the legal source bubble.  The
          // PA stall is armed from an observed accepted-beat boundary below,
          // rather than from a guessed core-cycle phase.
          send_source(cfg.source_beats,0,24,80);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            do @(negedge vif.core_clk);
              while(env.source.monitor.accepted_beats<24 || !vif.interp1_stall_window);
            vif.pa_ready=4'h0;
            // Bound the legal stall even if this phase does not reach the
            // target; never deadlock the test while waiting for a bin.
            repeat(200) @(negedge vif.core_clk);
            vif.pa_ready=4'hf;
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            if (exact_hits==0 || vif.protocol_error ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.monitor.stall_cycles==0)
              `uvm_fatal("EXACT_BIN","Missing interp1 state, count, or output hold evidence")
            `uvm_info("SKU_PASS",$sformatf("THERMO5_INTERP1_EMPTY_BLOCKED_UVM_PASS hits=%0d source=%0d output=%0d four_planes=bittrue",
              exact_hits,cfg.source_beats,env.scoreboard.checked),UVM_NONE)
          end
        join
      end
      begin
        forever begin
          @(posedge vif.core_clk);
          if(vif.core_rst_n && vif.core_enable && vif.interp1_stage1_empty_blocked)
            exact_hits++;
        end
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Exact interp1 state test did not drain")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
