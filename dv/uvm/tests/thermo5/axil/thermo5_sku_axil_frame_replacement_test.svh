// Exercise legal back-to-back frames and require the exact centered-cubic
// single-entry pop/push event in both interpolation stages. The base
// scoreboard independently checks all four output planes.
class thermo5_sku_axil_frame_replacement_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_frame_replacement_test)

  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  virtual function void configure_case();
    super.configure_case();
    if (cfg.core_words != 112 || cfg.source_beats != 64)
      `uvm_fatal("FRAME_REPLACEMENT_CONFIG",
        "Use CORE_WORDS=112 for two complete 32-beat packets")
    cfg.expect_pa=1;
    cfg.frame_starts=2;
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit drain_complete;
    int interp1_hits=0;
    int interp2_hits=0;
    int interp1_single_end=0;
    int interp2_single_end=0;
    int interp1_single_end_pop=0;
    int interp2_single_end_pop=0;
    int run_phase_cycles=0;
    int source_start_delay_cycles=0;
    int expected_dpd_words;
    expected_dpd_words=cfg.core_words+cfg.frame_starts;
    void'($value$plusargs("THERMO5_RUN_PHASE_CYCLES=%d",run_phase_cycles));
    void'($value$plusargs("THERMO5_SOURCE_START_DELAY_CYCLES=%d",
                          source_start_delay_cycles));
    if (run_phase_cycles<0 || run_phase_cycles>16)
      `uvm_fatal("FRAME_REPLACEMENT_PHASE",
        $sformatf("THERMO5_RUN_PHASE_CYCLES must be in [0,16], got %0d",run_phase_cycles))
    if (source_start_delay_cycles<0 || source_start_delay_cycles>8)
      `uvm_fatal("FRAME_REPLACEMENT_SOURCE_PHASE",
        $sformatf("THERMO5_SOURCE_START_DELAY_CYCLES must be in [0,8], got %0d",
                  source_start_delay_cycles))
    phase.raise_objection(this);
    fork
      begin
        fork
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            repeat(source_start_delay_cycles) @(negedge vif.src_clk);
            send_source(cfg.source_beats);
          end
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            // The AXI-Lite product requires ingress prefill before RUN.
            wait(env.source.monitor.accepted_beats>=16);
            repeat(run_phase_cycles) @(posedge vif.core_clk);
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_RUN","RUN request failed")
            for (int cycles=0;cycles<12000 && env.scoreboard.checked<cfg.core_words;cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("FRAME_REPLACEMENT_TIMEOUT",
                $sformatf("output=%0d/%0d source=%0d underflow=%0d protocol=%0b",
                  env.scoreboard.checked,cfg.core_words,
                  env.source.monitor.accepted_beats,
                  env.coverage.underflow_before_last_source,vif.protocol_error))
            if (env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.source.monitor.accepted_last_count!=2 ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.coverage.pa_words!=cfg.core_words ||
                env.coverage.frame_starts!=cfg.frame_starts ||
                vif.protocol_error || env.coverage.underflow_before_last_source!=0)
              `uvm_fatal("FRAME_REPLACEMENT_STREAM",
                $sformatf("source=%0d TLAST=%0d frames=%0d output=%0d protocol=%0b early_underflow=%0d",
                  env.source.monitor.accepted_beats,
                  env.source.monitor.accepted_last_count,
                  env.coverage.frame_starts,env.scoreboard.checked,
                  vif.protocol_error,env.coverage.underflow_before_last_source))
            for (int lane=0;lane<16;lane++)
              if (vif.dpd_sample_count[lane]!==expected_dpd_words ||
                  vif.dpd_saturation_count[lane]!==0)
                `uvm_fatal("FRAME_REPLACEMENT_DPD_COUNT",
                  $sformatf("lane=%0d samples=%0d expected=%0d saturation=%0d",
                    lane,vif.dpd_sample_count[lane],expected_dpd_words,
                    vif.dpd_saturation_count[lane]))
            if (interp1_hits==0 || interp2_hits==0)
              `uvm_info("FRAME_REPLACEMENT_BIN_OPEN",
                $sformatf("Stream oracle passed but target pop/push remains unhit: stage1=%0d/%0d/%0d stage2=%0d/%0d/%0d run_phase=%0d source_phase=%0d",
                  interp1_hits,interp1_single_end_pop,interp1_single_end,
                  interp2_hits,interp2_single_end_pop,interp2_single_end,
                  run_phase_cycles,source_start_delay_cycles),UVM_NONE)
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_STOP","RUN clear failed")
            drain_complete=0;
            for (int polls=0;polls<1000 && !drain_complete;polls++) begin
              axil_read(8'h04,status,resp);
              if (resp!=2'b00) `uvm_fatal("AXIL_STATUS","STATUS read failed")
              drain_complete=(status[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("AXIL_DRAIN","Back-to-back frames did not drain")
            `uvm_info("SKU_PASS",
              $sformatf("THERMO5_AXIL_FRAME_REPLACEMENT_UVM_PASS stage1=%0d stage2=%0d source=%0d output=%0d four_planes=bittrue",
                interp1_hits,interp2_hits,cfg.source_beats,env.scoreboard.checked),
              UVM_NONE)
          end
        join
      end
      begin
        forever begin
          @(posedge vif.core_clk);
          if (vif.core_rst_n) begin
            if (vif.interp1_centered_pop_push) interp1_hits++;
            if (vif.interp2_centered_pop_push) interp2_hits++;
            if (vif.interp1_centered_state[7:5]==3'b011)
              interp1_single_end++;
            if (vif.interp1_centered_state[7:5]==3'b011 &&
                vif.interp1_centered_state[4]) interp1_single_end_pop++;
            if (vif.interp2_centered_state[7:5]==3'b011)
              interp2_single_end++;
            if (vif.interp2_centered_state[7:5]==3'b011 &&
                vif.interp2_centered_state[4]) interp2_single_end_pop++;
          end
        end
      end
      begin
        repeat(24000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","AXI-Lite centered frame replacement test timed out")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
