// AXI-Lite-controlled EF2 saturation qualification.  This mirrors the
// generic EF2 corner test while controlling the actual AXI-Lite DUT through
// its public RUN register. Each 32-beat packet is also a vector frame.
class thermo5_sku_axil_ef2_corner_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_ef2_corner_test)

  logic signed [19:0] saved_e1_i[0:3], saved_e2_i[0:3];
  logic signed [19:0] saved_e1_q[0:3], saved_e2_q[0:3];

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    integer fd;
    integer scan_result;
    logic [15:0] marker;
    string path;
    super.configure_case();
    cfg.expect_pa=1;
    if (cfg.core_words!=2072)
      `uvm_fatal("EF2_WORDS","Use CORE_WORDS=2072 with the long EF2 corner vectors")
    path=$sformatf("%s/tid32_thermo5_frontend_frame_start.mem",cfg.vector_dir);
    fd=$fopen(path,"r");
    if (fd==0) `uvm_fatal("EF2_FRAME_FILE",$sformatf("Cannot open %s",path))
    scan_result=$fscanf(fd,"%h",marker);
    cfg.frame_starts=0;
    while (scan_result==1) begin
      if (marker[0]) cfg.frame_starts++;
      scan_result=$fscanf(fd,"%h",marker);
    end
    $fclose(fd);
    if (scan_result!=-1 || cfg.frame_starts!=cfg.source_beats/32)
      `uvm_fatal("EF2_FRAME_COUNT",
        $sformatf("Expected one frame start per 32-beat packet, found %0d",cfg.frame_starts))
  endfunction

  task automatic stall_candidate(input bit positive);
    bit candidate;
    candidate=0;
    while (!candidate) begin
      // Sample just after the active edge so the request reaches the sole
      // PA_READY driver before its next falling-edge update. Sampling at the
      // falling edge races the driver's NBA update and can let a one-cycle
      // clamp candidate transfer before backpressure takes effect.
      @(posedge vif.core_clk);
      #1ps;
      candidate=(vif.pa_valid==4'hf) &&
                (positive ? (|vif.ef2_pos_clamp_candidate) :
                            (|vif.ef2_neg_clamp_candidate));
    end

    // Backpressure is asserted before the candidate's next core-clock
    // transfer, then the state and candidate must remain stable.
    env.pa_sink.set_ready(4'h0);
    wait(vif.ef2_clamp_stalled &&
         (positive ? (|vif.ef2_pos_clamp_candidate) :
                     (|vif.ef2_neg_clamp_candidate)));
    for (int branch=0;branch<4;branch++) begin
      saved_e1_i[branch]=vif.ef2_err1_i[branch];
      saved_e2_i[branch]=vif.ef2_err2_i[branch];
      saved_e1_q[branch]=vif.ef2_err1_q[branch];
      saved_e2_q[branch]=vif.ef2_err2_q[branch];
    end
    repeat(8) begin
      @(posedge vif.core_clk);
      #1ps;
      if (!vif.ef2_clamp_stalled ||
          !(positive ? (|vif.ef2_pos_clamp_candidate) :
                       (|vif.ef2_neg_clamp_candidate)))
        `uvm_fatal("EF2_CLAMP_STALL","Selected clamp candidate was not held under PA backpressure")
      for (int branch=0;branch<4;branch++)
        if (vif.ef2_err1_i[branch]!==saved_e1_i[branch] ||
            vif.ef2_err2_i[branch]!==saved_e2_i[branch] ||
            vif.ef2_err1_q[branch]!==saved_e1_q[branch] ||
            vif.ef2_err2_q[branch]!==saved_e2_q[branch])
          `uvm_fatal("EF2_STATE_STALL",
            $sformatf("EF2 branch %0d state advanced under AXIL PA stall",branch))
    end
    @(negedge vif.core_clk);
    env.pa_sink.set_ready(4'hf);
  endtask

  task automatic stall_state_rail();
    bit state_at_rail;
    state_at_rail=0;
    while (!state_at_rail) begin
      // As above, sample before the driver's following falling-edge update
      // so the rail state is held before the next EF2 transfer can advance.
      @(posedge vif.core_clk);
      #1ps;
      state_at_rail=(vif.pa_valid==4'hf) && (|vif.ef2_state_at_rail);
    end
    env.pa_sink.set_ready(4'h0);
    wait(vif.ef2_tidsm_stalled && (|vif.ef2_state_at_rail));
    for (int branch=0;branch<4;branch++) begin
      saved_e1_i[branch]=vif.ef2_err1_i[branch];
      saved_e2_i[branch]=vif.ef2_err2_i[branch];
      saved_e1_q[branch]=vif.ef2_err1_q[branch];
      saved_e2_q[branch]=vif.ef2_err2_q[branch];
    end
    repeat(8) begin
      @(posedge vif.core_clk);
      #1ps;
      if (!vif.ef2_tidsm_stalled || !(|vif.ef2_state_at_rail))
        `uvm_fatal("STATE_RAIL_STALL","State-rail condition was not held during TIDSM backpressure")
      for (int branch=0;branch<4;branch++)
        if (vif.ef2_err1_i[branch]!==saved_e1_i[branch] ||
            vif.ef2_err2_i[branch]!==saved_e2_i[branch] ||
            vif.ef2_err1_q[branch]!==saved_e1_q[branch] ||
            vif.ef2_err2_q[branch]!==saved_e2_q[branch])
          `uvm_fatal("STATE_RAIL_HOLD",
            $sformatf("EF2 branch %0d state changed while a rail was stalled",branch))
    end
    @(negedge vif.core_clk);
    env.pa_sink.set_ready(4'hf);
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit drain_complete;
    phase.raise_objection(this);
    env.pa_sink.set_ready(4'hf);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            if (vif.ef2_order2_enabled!==1'b1)
              `uvm_fatal("EF2_CONFIG","AXI-Lite EF2 qualification requires TIDSM_ORDER=2")
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            // Match the supported AXI-Lite startup contract: prefill the
            // sixteen-beat ingress FIFO before enabling RUN.
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("EF2_RUN","Could not start AXI-Lite EF2 traffic")

            fork
              begin
                stall_candidate(1'b1);
                stall_candidate(1'b0);
                stall_state_rail();
              end
              begin
                // Ask STOP near the final 32-beat packet. The wrapper then
                // accepts through TLAST and drains without leaving RUN active
                // after the finite source stream is exhausted.
                wait(env.source.monitor.accepted_beats>=cfg.source_beats-32);
                axil_write(8'h00,32'd0,0,1,resp);
                if (resp!=2'b00)
                  `uvm_fatal("EF2_STOP","Could not stop the final EF2 packet")
              end
            join
            for (int cycles=0;cycles<100000 &&
                 env.scoreboard.checked!=cfg.core_words;cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("EF2_STREAM_TIMEOUT",
                $sformatf("checked=%0d expected=%0d",env.scoreboard.checked,cfg.core_words))
            if (env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.scoreboard.checked!=cfg.core_words ||
                env.source.monitor.accepted_last_count!=cfg.source_beats/32 ||
                env.coverage.frame_starts!=cfg.frame_starts ||
                env.coverage.pa_words!=cfg.core_words)
              `uvm_fatal("EF2_STREAM_COUNTS",
                $sformatf("source=%0d/%0d source_checked=%0d PA=%0d/%0d TLAST=%0d/%0d frames=%0d/%0d",
                  env.source.monitor.accepted_beats,cfg.source_beats,
                  env.scoreboard.source_checked,env.scoreboard.checked,cfg.core_words,
                  env.source.monitor.accepted_last_count,cfg.source_beats/32,
                  env.coverage.frame_starts,cfg.frame_starts))
            for (int lane=0;lane<16;lane++)
              if (vif.dpd_sample_count[lane]!==cfg.core_words+cfg.frame_starts ||
                  vif.dpd_saturation_count[lane]!==0)
                `uvm_fatal("EF2_DPD_COUNT",
                  $sformatf("lane=%0d samples=%0d expected=%0d saturation=%0d",
                    lane,vif.dpd_sample_count[lane],cfg.core_words+cfg.frame_starts,
                    vif.dpd_saturation_count[lane]))
            if (!env.unified_scoreboard.check_expected_queues_drained("ef2-axil-corner"))
              `uvm_fatal("EF2_QUEUE","Expected queues did not drain after EF2 saturation replay")
            if (env.coverage.ef2_positive_clamp_events==0 ||
                env.coverage.ef2_negative_clamp_events==0 ||
                env.coverage.ef2_clamp_stall_cycles==0 ||
                env.coverage.ef2_state_rail_cycles==0 ||
                env.coverage.ef2_state_rail_stall_cycles==0)
              `uvm_fatal("EF2_COVERAGE",
                "Both clamp polarities, clamp stall, state rail, and rail stall must be observed")
            for (int branch=0;branch<4;branch++)
              if (env.coverage.ef2_positive_clamp_branch[branch]==0 ||
                  env.coverage.ef2_negative_clamp_branch[branch]==0)
                `uvm_fatal("EF2_BRANCH_COVERAGE",
                  $sformatf("Branch %0d did not reach both clamp polarities (+%0d -%0d)",
                    branch,env.coverage.ef2_positive_clamp_branch[branch],
                    env.coverage.ef2_negative_clamp_branch[branch]))

            if (vif.underflow || vif.protocol_error)
              `uvm_fatal("EF2_DIAGNOSTIC",
                $sformatf("Unexpected underflow/protocol error: underflow=%b protocol=%b",
                  vif.underflow,vif.protocol_error))
            drain_complete=0;
            for (int polls=0;polls<1000 && !drain_complete;polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00) `uvm_fatal("EF2_STATUS","Status read failed after drain")
              drain_complete=(rdata[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("EF2_DRAIN","AXI-Lite did not reach drained idle")
            if (env.coverage.underflow_cycles!=0)
              `uvm_fatal("EF2_UNDERFLOW_COUNT",
                $sformatf("Observed %0d underflow cycles during EF2 qualification",
                  env.coverage.underflow_cycles))
            env.control.reset_both();
            wait_axil_reset_release();
            repeat(2) @(posedge vif.core_clk);
            if (vif.ef2_state_zero!==4'hf)
              `uvm_fatal("EF2_RESET","EF2 state did not clear across all four branches")
            `uvm_info("SKU_PASS",
              "THERMO5_AXIL_EF2_CORNER_UVM_PASS positive/negative clamps, state hold, reset and bit-true stream",
              UVM_NONE)
          end
        join
      end
      begin
        repeat(100000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT",
          $sformatf("AXI-Lite EF2 qualification timeout: source=%0d checked=%0d candidates=+%b/-%b",
            env.source.monitor.accepted_beats,env.scoreboard.checked,
            vif.ef2_pos_clamp_candidate,vif.ef2_neg_clamp_candidate))
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
