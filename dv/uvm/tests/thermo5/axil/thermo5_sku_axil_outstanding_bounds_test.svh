// Legal long-stream public-interface stress for the outstanding-word counter.
// The test observes, but never forces, the DUT counter and checks the full
// four-plane bit-true stream after sustained PA backpressure is released.
class thermo5_sku_axil_outstanding_bounds_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_outstanding_bounds_test)

  int max_outstanding;
  int core_accepts;
  int output_accepts;
  int saturation_guard_events;
  int underflow_guard_events;
  logic [7:0] expected_outstanding;
  int source_stall_cycles;
  int pa_stall_cycles;
  bit monitor_done;
  uvm_hdl_data_t hdl_value;

  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  function automatic logic [7:0] read_outstanding_words();
    if (!uvm_hdl_read("thermo5_sku_uvm_tb.dut.outstanding_words_q",hdl_value))
      `uvm_fatal("OUTSTANDING_HDL_READ","cannot read DUT outstanding_words_q")
    return hdl_value[7:0];
  endfunction

  function automatic bit read_counter_event(input string path);
    if (!uvm_hdl_read(path,hdl_value))
      `uvm_fatal("OUTSTANDING_HDL_READ",$sformatf("cannot read DUT event %s",path))
    return hdl_value[0];
  endfunction

  virtual function void configure_case();
    super.configure_case();
    if (cfg.core_words < 112 || cfg.core_words % 56 != 0 ||
        cfg.source_beats % 32 != 0)
      `uvm_fatal("OUTSTANDING_CONFIG",
        "CORE_WORDS must contain complete 56-word frames / 32-beat packets")
    cfg.expect_pa=1;
    cfg.frame_starts=cfg.source_beats/32;
    cfg.manual_pa_ready=1;
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit drain_complete;
    logic [7:0] counter_sample;
    bit core_accept_sample, output_accept_sample;
    int wait_cycles;
    int expected_dpd_samples;
    phase.raise_objection(this);
    max_outstanding=0;
    core_accepts=0;
    output_accepts=0;
    saturation_guard_events=0;
    underflow_guard_events=0;
    expected_outstanding=0;
    expected_dpd_samples=cfg.core_words+cfg.frame_starts;
    source_stall_cycles=0;
    pa_stall_cycles=0;
    monitor_done=0;
    fork
      begin : public_traffic
        wait(vif.src_rst_n && vif.core_rst_n);
        env.pa_sink.set_ready(4'h0);
        fork
          send_source(cfg.source_beats);
        join_none

        // Startup prefill is part of the public AXI-Lite contract. RUN is
        // requested only after 16 source handshakes, while PA is stalled.
        wait(env.source.monitor.accepted_beats>=16);
        wait_axil_reset_release();
        axil_write(8'h00,32'h1,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_RUN","RUN request failed")

        wait_cycles=0;
        while ((source_stall_cycles==0 || pa_stall_cycles==0) && wait_cycles<3000) begin
          @(posedge vif.core_clk);
          wait_cycles++;
        end
        if (source_stall_cycles==0 || pa_stall_cycles==0 ||
            core_accepts==0 || max_outstanding==0)
          `uvm_fatal("OUTSTANDING_STRESS",
            $sformatf("missing legal stall witness source=%0d pa=%0d core=%0d max=%0d",
              source_stall_cycles,pa_stall_cycles,core_accepts,max_outstanding))

        // Hold all PA lanes not-ready to accumulate real in-flight work. The
        // source FIFO will apply public AXIS backpressure when full; keep the
        // source running so the monitor can observe that bounded condition.
        wait_cycles=0;
        while (env.source.monitor.accepted_beats<cfg.source_beats && wait_cycles<12000) begin
          @(posedge vif.core_clk);
          wait_cycles++;
        end
        if (env.source.monitor.accepted_beats<cfg.source_beats &&
            source_stall_cycles==0)
          `uvm_fatal("OUTSTANDING_SOURCE_TIMEOUT",
            $sformatf("source stalled without an observed public handshake stall: %0d/%0d",
              env.source.monitor.accepted_beats,cfg.source_beats))
        repeat(128) @(posedge vif.core_clk);
        env.pa_sink.set_ready(4'hf);
        wait_cycles=0;
        while (env.source.monitor.accepted_beats<cfg.source_beats && wait_cycles<12000) begin
          @(posedge vif.core_clk);
          wait_cycles++;
        end
        if (env.source.monitor.accepted_beats!=cfg.source_beats)
          `uvm_fatal("OUTSTANDING_SOURCE_DRAIN",
            $sformatf("source=%0d/%0d after PA release",
              env.source.monitor.accepted_beats,cfg.source_beats))
        // STOP as soon as the complete legal source packet set is accepted;
        // the running core then drains already accepted data without treating
        // the finite test vector tail as an unexpected source starvation.
        axil_write(8'h00,32'd0,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_STOP","RUN clear failed")
        wait_cycles=0;
        while (env.scoreboard.checked<cfg.core_words && wait_cycles<12000) begin
          @(posedge vif.core_clk);
          wait_cycles++;
        end
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("OUTSTANDING_DRAIN_TIMEOUT",
            $sformatf("output=%0d/%0d source=%0d",env.scoreboard.checked,
              cfg.core_words,env.source.monitor.accepted_beats))
        if (vif.protocol_error || env.coverage.underflow_before_last_source!=0 ||
            vif.underflow || env.coverage.underflow_cycles!=0 ||
            saturation_guard_events!=0 || underflow_guard_events!=0 ||
            env.source.monitor.accepted_last_count!=cfg.frame_starts ||
            env.source.monitor.accepted_beats!=cfg.source_beats ||
            env.scoreboard.source_checked!=cfg.source_beats ||
            env.scoreboard.checked!=cfg.core_words ||
            env.coverage.frame_starts!=cfg.frame_starts ||
            env.coverage.pa_words!=cfg.core_words || output_accepts!=cfg.core_words)
          `uvm_fatal("OUTSTANDING_STREAM",
            $sformatf("source=%0d/%0d TLAST=%0d/%0d frame=%0d/%0d output=%0d/%0d output_accepts=%0d underflow=%0d saturation_guard=%0d underflow_guard=%0d protocol=%0b",
              env.source.monitor.accepted_beats,env.scoreboard.source_checked,
              env.source.monitor.accepted_last_count,cfg.frame_starts,
              env.coverage.frame_starts,cfg.frame_starts,env.scoreboard.checked,
              cfg.core_words,output_accepts,env.coverage.underflow_cycles,
              saturation_guard_events,underflow_guard_events,vif.protocol_error))
        for (int lane=0;lane<16;lane++) begin
          if (vif.dpd_sample_count[lane]!==expected_dpd_samples ||
              vif.dpd_saturation_count[lane]!==0)
            `uvm_fatal("OUTSTANDING_DPD_COUNT",
              $sformatf("lane=%0d samples=%0d expected=%0d saturation=%0d",
                lane,vif.dpd_sample_count[lane],expected_dpd_samples,
                vif.dpd_saturation_count[lane]))
        end

        drain_complete=0;
        for (int polls=0;polls<1000 && !drain_complete;polls++) begin
          axil_read(8'h04,status,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_STATUS","STATUS read failed")
          drain_complete=(status[4:3]==2'b00);
        end
        if (!drain_complete) `uvm_fatal("AXIL_DRAIN","TX did not drain after STOP")
        if (read_outstanding_words()!=0 || expected_outstanding!=0)
          `uvm_fatal("OUTSTANDING_DRAIN",
            $sformatf("counter did not return to zero after completed drain: %0d",
              read_outstanding_words()))
        monitor_done=1;
        `uvm_info("SKU_PASS",
          $sformatf("THERMO5_AXIL_OUTSTANDING_BOUNDS_UVM_PASS words=%0d packets=%0d max=%0d saturation_guard=%0d underflow_guard=%0d core_accepts=%0d output_accepts=%0d source_stall=%0d pa_stall=%0d; bit-true drain",
            cfg.core_words,cfg.frame_starts,max_outstanding,saturation_guard_events,
            underflow_guard_events,core_accepts,output_accepts,source_stall_cycles,pa_stall_cycles),
          UVM_NONE)
      end
      begin : independent_counter_checker
        forever begin
          @(posedge vif.core_clk);
          if (vif.core_rst_n && !monitor_done) begin
            counter_sample=read_outstanding_words();
            core_accept_sample=read_counter_event("thermo5_sku_uvm_tb.dut.core_accept");
            output_accept_sample=read_counter_event("thermo5_sku_uvm_tb.dut.output_accept");
            if (counter_sample!==expected_outstanding)
              `uvm_fatal("OUTSTANDING_ORACLE",
                $sformatf("counter=%0d expected=%0d core_accept=%0b output_accept=%0b",
                  counter_sample,expected_outstanding,core_accept_sample,output_accept_sample))
            if (core_accept_sample && !output_accept_sample) begin
              if (counter_sample==8'hff) saturation_guard_events++;
              else expected_outstanding=expected_outstanding+1'b1;
            end else if (!core_accept_sample && output_accept_sample) begin
              if (counter_sample==0) underflow_guard_events++;
              else expected_outstanding=expected_outstanding-1'b1;
            end
            if (core_accept_sample) core_accepts++;
            if (output_accept_sample) output_accepts++;
            if (counter_sample>max_outstanding)
              max_outstanding=counter_sample;
            if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf) pa_stall_cycles++;
          end
        end
      end
      begin : source_backpressure_checker
        forever begin
          @(posedge vif.src_clk);
          if (vif.src_rst_n && vif.src_valid && !vif.src_ready)
            source_stall_cycles++;
        end
      end
      begin
        repeat(60000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Outstanding counter long-stream stress test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
