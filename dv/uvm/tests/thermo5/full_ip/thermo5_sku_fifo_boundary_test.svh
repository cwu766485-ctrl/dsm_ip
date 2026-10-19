

class thermo5_sku_fifo_boundary_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_fifo_boundary_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.fifo_full && !vif.src_ready);
            repeat(3) @(posedge vif.src_clk);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full();
            if (env.coverage.fifo_full_cycles==0 ||
                env.source.monitor.stall_cycles==0)
              `uvm_fatal("COVERAGE","FIFO full/backpressure was not observed")
            `uvm_info("SKU_PASS","THERMO5_FIFO_BOUNDARY_UVM_PASS full backpressure and 56 bittrue words",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","FIFO boundary test did not drain")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
