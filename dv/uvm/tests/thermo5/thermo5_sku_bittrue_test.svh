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
            request_stream_enable(1'b1);
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
`ifdef THERMO5_AXIL_CONTROL
            request_stream_enable(1'b0);
`endif
            wait(env.scoreboard.checked==cfg.core_words);
`ifndef THERMO5_AXIL_CONTROL
            request_stream_enable(1'b0);
`endif
            check_full();
            #1ps;
            if (env.event_bus.source_beats!=cfg.source_beats ||
                env.event_bus.cdc_words!=cfg.core_words ||
                env.event_bus.ef2_words!=cfg.core_words ||
                env.event_bus.pa_words!=cfg.core_words)
              `uvm_fatal("EVENT_BUS_COUNTS",
                $sformatf("event stream counts source=%0d/%0d CDC=%0d/%0d EF2=%0d/%0d PA=%0d/%0d",
                  env.event_bus.source_beats,cfg.source_beats,
                  env.event_bus.cdc_words,cfg.core_words,
                  env.event_bus.ef2_words,cfg.core_words,
                  env.event_bus.pa_words,cfg.core_words))
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
        int unsigned cycles;
        cycles=0;
        while (cycles < 10000+8*cfg.core_words) begin
          repeat(1000) @(posedge vif.core_clk);
          cycles+=1000;
          `uvm_info("PROGRESS",
            $sformatf("cycle=%0d source=%0d/%0d checked_source=%0d CDC=%0d DSP=%0d EF2=%0d PA=%0d checked_PA=%0d src_v/r=%b/%b cdc_v/r=%b/%b pa_v/r=%b/%b active/drain=%b/%b underflow/protocol=%b/%b",
              cycles,env.source.monitor.accepted_beats,cfg.source_beats,
              env.scoreboard.source_checked,env.event_bus.cdc_words,
              env.event_bus.dsp_observations,env.event_bus.ef2_words,
              env.event_bus.pa_words,env.scoreboard.checked,
              vif.src_valid,vif.src_ready,vif.cdc_core_valid,vif.cdc_core_ready,
              vif.pa_valid,vif.pa_ready,vif.core_tx_active,vif.core_draining,
              vif.underflow,vif.protocol_error),UVM_NONE)
        end
        `uvm_fatal("TIMEOUT",
          $sformatf("Thermo5 full-stream test did not complete: source=%0d/%0d checked_source=%0d CDC=%0d DSP=%0d EF2=%0d PA=%0d checked_PA=%0d src_v/r=%b/%b cdc_v/r=%b/%b pa_v/r=%b/%b active/drain=%b/%b underflow/protocol=%b/%b",
            env.source.monitor.accepted_beats,cfg.source_beats,
            env.scoreboard.source_checked,env.event_bus.cdc_words,
            env.event_bus.dsp_observations,env.event_bus.ef2_words,
            env.event_bus.pa_words,env.scoreboard.checked,
            vif.src_valid,vif.src_ready,vif.cdc_core_valid,vif.cdc_core_ready,
            vif.pa_valid,vif.pa_ready,vif.core_tx_active,vif.core_draining,
            vif.underflow,vif.protocol_error))
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
