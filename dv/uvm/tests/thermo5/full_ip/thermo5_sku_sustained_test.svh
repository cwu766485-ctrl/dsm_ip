// Verify that the complete centered-cubic + EF2 transmitter sustains one
// accepted four-plane word per core clock after its initial pipeline fill.
class thermo5_sku_sustained_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_sustained_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.frame_starts=1;
    cfg.manual_pa_ready=1;
    cfg.random_pa_ready=0;
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    vif.pa_ready=4'hf;
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full();
            `uvm_info("THROUGHPUT_STATS",$sformatf("accepted=%0d output_gaps=%0d source_stalls=%0d",
              env.monitor.accepted_words,env.monitor.output_gap_cycles,
              env.source.monitor.stall_cycles),UVM_NONE)
            if (env.monitor.output_gap_cycles!=0)
              `uvm_fatal("THROUGHPUT",$sformatf("steady output had %0d empty cycles",
                env.monitor.output_gap_cycles))
            `uvm_info("SKU_PASS",$sformatf("THERMO5_SUSTAINED_UVM_PASS words=%0d output_gaps=0",
              cfg.core_words),UVM_NONE)
          end
        join
      end
      begin
        repeat(20000+8*cfg.core_words) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Sustained-stream test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
