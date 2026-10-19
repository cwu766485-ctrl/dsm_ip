// Nominal full-IP MATLAB bit-true stream test.
class thermo5_sku_bittrue_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_bittrue_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
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
            if (require_signed_extremes &&
                (env.coverage.signed_min_beats==0 || env.coverage.signed_max_beats==0))
              `uvm_fatal("COVERAGE",$sformatf("Signed endpoint bins missed: min=%0d max=%0d",
                env.coverage.signed_min_beats,env.coverage.signed_max_beats))
            if (cfg.random_pa_ready && env.monitor.stall_cycles==0)
              `uvm_fatal("COVERAGE","No four-plane output stall was exercised")
            `uvm_info("SKU_PASS",$sformatf("THERMO5_SKU_UVM_PASS source=%0d output=%0d four_planes=bittrue",
              cfg.source_beats,cfg.core_words),UVM_NONE)
          end
        join
      end
      begin
        repeat(10000+8*cfg.core_words) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 full-stream test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
