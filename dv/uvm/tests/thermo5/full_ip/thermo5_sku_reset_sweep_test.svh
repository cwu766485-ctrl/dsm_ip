

class thermo5_sku_reset_sweep_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_reset_sweep_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    int target_residual[5]='{2,4,6,10,12};
    phase.raise_objection(this);
    fork
      begin
        for (int epoch=0;epoch<5;epoch++) begin
          fork
            send_source(24);
            begin
              wait(env.source.monitor.accepted_beats>=4);
              env.control.core_on();
              wait(env.source.monitor.accepted_beats==24);
            end
          join
          wait(vif.cdc_residual==target_residual[epoch]);
          @(negedge vif.core_clk);
          if (vif.cdc_residual!=target_residual[epoch])
            `uvm_fatal("RESET_STATE","CDC residual changed before reset edge")
          env.control.reset_both();
          if (vif.cdc_residual!=0)
            `uvm_fatal("RESET_STATE","CDC residual did not reset to zero")
        end
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full(0);
            if (env.scoreboard.reset_epochs!=5 || env.coverage.reset_reassertions!=5)
              `uvm_fatal("RESET_SWEEP","Five reset epochs were not observed")
            `uvm_info("SKU_PASS","THERMO5_RESET_SWEEP_UVM_PASS five residual resets and 56-word replay",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Reset residual sweep did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
