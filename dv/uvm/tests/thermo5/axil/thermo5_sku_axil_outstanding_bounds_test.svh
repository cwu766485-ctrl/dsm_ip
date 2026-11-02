// Legal two-packet public-interface stress for the outstanding-word counter.
// The test observes, but never forces, the DUT counter and checks the full
// four-plane bit-true stream after sustained PA backpressure is released.
class thermo5_sku_axil_outstanding_bounds_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_outstanding_bounds_test)

  int max_outstanding;
  int core_accepts;
  int output_accepts;
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
    if (cfg.core_words != 112 || cfg.source_beats != 64)
      `uvm_fatal("OUTSTANDING_CONFIG",
        "Use CORE_WORDS=112 for two complete 32-beat packets")
    cfg.expect_pa=1;
    cfg.frame_starts=2;
    cfg.manual_pa_ready=1;
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit drain_complete;
    logic [7:0] counter_sample;
    bit core_accept_sample, output_accept_sample;
    int wait_cycles;
    phase.raise_objection(this);
    max_outstanding=0;
    core_accepts=0;
    output_accepts=0;
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

        // Keep the bounded queue under load long enough to reach a stable
        // backpressured state, then drain through the independent scoreboard.
        repeat(128) @(posedge vif.core_clk);
        if (read_outstanding_words()==8'hff)
          `uvm_fatal("OUTSTANDING_SATURATION","counter reached the saturation value")
        env.pa_sink.set_ready(4'hf);
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
            env.source.monitor.accepted_last_count!=2 ||
            env.source.monitor.accepted_beats!=64 || env.scoreboard.source_checked!=64 ||
            env.scoreboard.checked!=112 || env.coverage.frame_starts!=2 ||
            env.coverage.pa_words!=112 || output_accepts!=112)
          `uvm_fatal("OUTSTANDING_STREAM",
            $sformatf("source=%0d/%0d TLAST=%0d/2 frame=%0d/2 output=%0d/112 output_accepts=%0d underflow=%0d protocol=%0b",
              env.source.monitor.accepted_beats,env.scoreboard.source_checked,
              env.source.monitor.accepted_last_count,env.coverage.frame_starts,
              env.scoreboard.checked,output_accepts,
              env.coverage.underflow_before_last_source,vif.protocol_error))
        for (int lane=0;lane<16;lane++) begin
          if (vif.dpd_sample_count[lane]!==114 || vif.dpd_saturation_count[lane]!==0)
            `uvm_fatal("OUTSTANDING_DPD_COUNT",
              $sformatf("lane=%0d samples=%0d expected=114 saturation=%0d",
                lane,vif.dpd_sample_count[lane],vif.dpd_saturation_count[lane]))
        end

        axil_write(8'h00,32'd0,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_STOP","RUN clear failed")
        drain_complete=0;
        for (int polls=0;polls<1000 && !drain_complete;polls++) begin
          axil_read(8'h04,status,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_STATUS","STATUS read failed")
          drain_complete=(status[4:3]==2'b00);
        end
        if (!drain_complete) `uvm_fatal("AXIL_DRAIN","TX did not drain after STOP")
        if (read_outstanding_words()!=0)
          `uvm_fatal("OUTSTANDING_DRAIN",
            $sformatf("counter did not return to zero after completed drain: %0d",
              read_outstanding_words()))
        if (max_outstanding>=255)
          `uvm_fatal("OUTSTANDING_MAX","legal traffic reached the counter saturation value")
        monitor_done=1;
        `uvm_info("SKU_PASS",
          $sformatf("THERMO5_AXIL_OUTSTANDING_BOUNDS_UVM_PASS max=%0d core_accepts=%0d output_accepts=%0d source_stall=%0d pa_stall=%0d; bit-true 112-word drain",
            max_outstanding,core_accepts,output_accepts,source_stall_cycles,pa_stall_cycles),
          UVM_NONE)
      end
      begin : independent_counter_checker
        forever begin
          @(posedge vif.core_clk);
          if (vif.core_rst_n && !monitor_done) begin
            counter_sample=read_outstanding_words();
            core_accept_sample=read_counter_event("thermo5_sku_uvm_tb.dut.core_accept");
            output_accept_sample=read_counter_event("thermo5_sku_uvm_tb.dut.output_accept");
            if (core_accept_sample && !output_accept_sample && counter_sample==8'hff)
              `uvm_fatal("COUNTER_SATURATION_GUARD",
                "legal public traffic reached the outstanding counter saturation guard")
            if (!core_accept_sample && output_accept_sample && counter_sample==0)
              `uvm_fatal("COUNTER_UNDERFLOW_GUARD",
                "legal public traffic reached the outstanding counter underflow guard")
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
        repeat(20000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Outstanding counter stress test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
