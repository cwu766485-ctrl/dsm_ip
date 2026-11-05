

class thermo5_sku_fifo_empty_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_fifo_empty_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
`ifdef THERMO5_CENTERED_CUBIC
          // Flush the short Generic-FIFO test frame before checking the empty
          // input condition. This non-AXI-Lite block test is not a 32-beat SKU
          // packet test; the monitor checks its exact frame-tail output word.
          send_source(4,0,-1,0,-1,1);
`else
          send_source(4);
`endif
          begin
            wait(env.source.monitor.accepted_beats==4);
            env.control.core_on();
            wait(env.scoreboard.checked==7);
            wait(vif.underflow===1'b1);
            if (vif.protocol_error) `uvm_fatal("FIFO_EMPTY","Starvation corrupted frame protocol")
            if (env.scoreboard.checked!=7)
              `uvm_fatal("FIFO_EMPTY","Short test frame did not match its seven-word bit-true oracle")
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
