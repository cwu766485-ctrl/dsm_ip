class thermo5_sku_fifo_boundary_test extends thermo5_sku_bittrue_test;
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

class thermo5_sku_fifo_empty_test extends thermo5_sku_bittrue_test;
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

class thermo5_sku_reset_test extends thermo5_sku_bittrue_test;
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
        env.control.reset_both();
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

class thermo5_sku_reset_sweep_test extends thermo5_sku_bittrue_test;
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

class thermo5_sku_illegal_frame_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_illegal_frame_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.illegal_frame=1;
    cfg.expect_pa=0;
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,1);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(vif.protocol_error===1'b1);
            if (env.coverage.protocol_error_cycles==0) @(posedge vif.core_clk);
            if (env.coverage.protocol_error_cycles==0)
              `uvm_fatal("COVERAGE","Illegal-frame sticky error was not sampled")
            `uvm_info("NEGATIVE","THERMO5_ILLEGAL_FRAME_OBSERVED; expected RTL assertion must also appear",UVM_NONE)
          end
        join_any
        disable fork;
      end
      begin
        repeat(1000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Misaligned frame_start was not rejected")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
