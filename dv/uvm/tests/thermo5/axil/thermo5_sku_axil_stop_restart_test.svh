// Exercise two legal packets separated by a software STOP and complete drain.
// The second packet must remain backpressured until software reasserts RUN;
// the datapath is not reset between packets, so the full 112-word oracle also
// checks that the TID/DPD/interpolator state resumes in the correct epoch.
class thermo5_sku_axil_stop_restart_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_stop_restart_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.frame_starts=2;
    if (cfg.core_words!=112 || cfg.source_beats!=64)
      `uvm_fatal("STOP_RESTART_WORDS",
        "Use CORE_WORDS=112 for two independently terminated packets")
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit idle_seen;
    int expected_dpd_words;
    expected_dpd_words=cfg.core_words+cfg.frame_starts;
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_RUN1","First RUN request failed")

            // Stop during packet 1. The already-open packet is accepted
            // through its TLAST at beat 31 and its entire 56-word output drains.
            wait(env.source.monitor.accepted_beats>=20);
            axil_write(8'h00,32'd0,0,1,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_STOP1","First STOP request failed")
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b11)
              `uvm_fatal("AXIL_DRAIN1_STATUS",
                $sformatf("Expected RUN_ACTIVE+DRAINING after first STOP, status=%08x",rdata))
            env.coverage.sample_stop_restart(3'd0);

            for (int cycles=0; cycles<10000 && env.scoreboard.checked<56; cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=56 ||
                env.source.monitor.accepted_beats!=32)
              `uvm_fatal("AXIL_PACKET1_DRAIN",
                $sformatf("first packet boundary mismatch: checked=%0d accepted=%0d",
                  env.scoreboard.checked,env.source.monitor.accepted_beats))
            env.coverage.sample_stop_restart(3'd1);

            idle_seen=0;
            for (int polls=0; polls<1000 && !idle_seen; polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00) `uvm_fatal("AXIL_STATUS1","STATUS read failed after packet 1")
              idle_seen=(rdata[4:3]==2'b00);
            end
            if (!idle_seen)
              `uvm_fatal("AXIL_DRAIN1_TIMEOUT","First packet did not reach drained idle")
            env.coverage.sample_stop_restart(3'd2);

            // Confirm packet 2 has not slipped into the core before RUN.
            repeat (3) @(posedge vif.src_clk);
            if (env.source.monitor.accepted_beats!=32 ||
                env.scoreboard.checked!=56)
              `uvm_fatal("AXIL_RESTART_EARLY_DATA",
                "Second packet advanced before the restart request")
            env.coverage.sample_stop_restart(3'd3);

            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_RUN2","Second RUN request failed")
            env.coverage.sample_stop_restart(3'd4);
            for (int cycles=0; cycles<12000 && env.scoreboard.checked<cfg.core_words; cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("AXIL_RESTART_STREAM_TIMEOUT",
                $sformatf("second packet did not complete: checked=%0d expected=%0d",
                  env.scoreboard.checked,cfg.core_words))

            if (env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.source.monitor.accepted_last_count!=2 ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.coverage.pa_words!=cfg.core_words ||
                env.coverage.frame_starts!=cfg.frame_starts ||
                vif.protocol_error || vif.underflow ||
                env.coverage.underflow_before_last_source!=0)
              `uvm_fatal("AXIL_RESTART_STREAM_CHECK",
                $sformatf("source=%0d TLAST=%0d frames=%0d output=%0d protocol=%b underflow=%b",
                  env.source.monitor.accepted_beats,
                  env.source.monitor.accepted_last_count,
                  env.coverage.frame_starts,env.scoreboard.checked,
                  vif.protocol_error,vif.underflow))
            for (int lane=0;lane<16;lane++)
              if (vif.dpd_sample_count[lane]!==expected_dpd_words ||
                  vif.dpd_saturation_count[lane]!==0)
                `uvm_fatal("AXIL_RESTART_DPD_COUNT",
                  $sformatf("lane=%0d samples=%0d expected=%0d saturation=%0d",
                    lane,vif.dpd_sample_count[lane],expected_dpd_words,
                    vif.dpd_saturation_count[lane]))

            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_STOP2","Final STOP request failed")
            idle_seen=0;
            for (int polls=0; polls<1000 && !idle_seen; polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00) `uvm_fatal("AXIL_STATUS2","Final STATUS read failed")
              idle_seen=(rdata[4:3]==2'b00);
            end
            if (!idle_seen)
              `uvm_fatal("AXIL_DRAIN2_TIMEOUT","Second packet did not drain to idle")
            env.coverage.sample_stop_restart(3'd5);
            if (env.coverage.stop_restart_cg.get_coverage()!=100.0)
              `uvm_fatal("AXIL_STOP_RESTART_COVERAGE",
                $sformatf("STOP/restart event coverage %.1f%%",
                  env.coverage.stop_restart_cg.get_coverage()))
            `uvm_info("SKU_PASS",
              "THERMO5_AXIL_STOP_RESTART_UVM_PASS: STOP drained packet 1; packet 2 stayed blocked until RUN restarted; 112 ordered four-plane words matched oracle",
              UVM_NONE)
          end
        join
      end
      begin
        repeat(24000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 AXI-Lite stop/restart test timed out")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
