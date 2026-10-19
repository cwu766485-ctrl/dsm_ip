

class thermo5_sku_reset_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_reset_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
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
          end
        join
        @(negedge vif.core_clk);
        // Assert both resets while enable is high to exercise the two
        // reset-with-enable condition bins at each interpolation instance.
        env.control.reset_both(1'b1);
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
            `uvm_info("SKU_PASS","THERMO5_RESET_UVM_PASS reset discards partial frame; replay is bittrue",UVM_NONE)
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
