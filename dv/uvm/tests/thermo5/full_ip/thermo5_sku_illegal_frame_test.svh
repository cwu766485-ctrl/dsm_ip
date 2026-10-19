

class thermo5_sku_illegal_frame_test extends thermo5_sku_base_test;
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
            // Finish the legal bus sequence before opening a new reset epoch;
            // otherwise the driver resumes a partial old frame after reset.
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            @(negedge vif.core_clk);
            env.control.reset_both();
            repeat(3) @(negedge vif.core_clk);
            if (vif.protocol_error !== 1'b0)
              `uvm_fatal("PROTOCOL_RESET","Sticky protocol error failed public reset")
            `uvm_info("NEGATIVE","THERMO5_PROTOCOL_ERROR_RESET_PASS sticky error cleared by public reset",UVM_NONE)
          end
        join
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
