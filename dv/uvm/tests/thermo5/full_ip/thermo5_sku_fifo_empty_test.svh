

class thermo5_sku_fifo_empty_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_fifo_empty_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(4);
          begin
            wait(env.source.monitor.accepted_beats==4);
            env.control.core_on();
            wait(env.scoreboard.checked==7);
            wait(vif.underflow===1'b1);
            if (vif.protocol_error) `uvm_fatal("FIFO_EMPTY","Starvation corrupted frame protocol")
            if (env.coverage.underflow_cycles==0) @(posedge vif.core_clk);
            if (env.coverage.underflow_cycles==0)
              `uvm_fatal("COVERAGE","FIFO empty/underflow was not observed")
            `uvm_info("SKU_PASS","THERMO5_FIFO_EMPTY_UVM_PASS 7 bittrue words then sticky underflow",UVM_NONE)
          end
        join
      end
      begin
        repeat(1000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","FIFO starvation did not assert underflow")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
