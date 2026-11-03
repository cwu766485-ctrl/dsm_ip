// Expected starvation is separate from normal-stream signoff. Keep RUN active
// after one complete legal packet, check every PA word against the independent
// scoreboard, then require the sticky underflow event caused by an empty FIFO.
class thermo5_sku_axil_starvation_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_starvation_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    int underflow_wait;

    phase.raise_objection(this);
    env.pa_sink.set_ready(4'hf);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();

            // Prefill the 16-beat ingress FIFO before enabling RUN. The 32-beat
            // AXIS packet is legal; starvation begins only after its TLAST.
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("STARVE_RUN","RUN request failed")

            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            for (int cycles=0; cycles<12000 &&
                 env.scoreboard.checked!=cfg.core_words; cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("STARVE_DATA_TIMEOUT",
                $sformatf("Independent PA scoreboard checked %0d/%0d words",
                  env.scoreboard.checked,cfg.core_words))

            underflow_wait=0;
            while (!vif.underflow && underflow_wait<4000) begin
              @(posedge vif.core_clk);
              underflow_wait++;
            end
            if (!vif.underflow)
              `uvm_fatal("STARVE_TIMEOUT","Expected FIFO starvation was not reported")
            if (vif.protocol_error || env.coverage.protocol_error_cycles!=0)
              `uvm_fatal("STARVE_PROTOCOL","Legal AXIS packet produced a framing error")
            if (env.coverage.underflow_cycles==0)
              `uvm_fatal("STARVE_COVERAGE","Underflow event did not reach the coverage monitor")
            if (env.coverage.underflow_before_last_source!=0)
              `uvm_fatal("STARVE_EARLY","Underflow occurred before packet TLAST")
            if (env.source.monitor.accepted_last_count!=1 ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("STARVE_COUNTS",
                $sformatf("source=%0d/%0d TLAST=%0d PA=%0d/%0d",
                  env.scoreboard.source_checked,cfg.source_beats,
                  env.source.monitor.accepted_last_count,
                  env.scoreboard.checked,cfg.core_words))
            `uvm_info("SKU_PASS",
              $sformatf("THERMO5_AXIL_STARVATION_PASS complete_packet=%0d PA_words=%0d expected_underflow=1",
                cfg.source_beats,env.scoreboard.checked),UVM_NONE)
          end
        join
      end
      begin
        repeat(20000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","AXI-Lite starvation test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
