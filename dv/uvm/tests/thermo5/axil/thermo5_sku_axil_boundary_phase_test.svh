// Phase-sweeps a legal AXI-Lite COMMIT against real DPD frame-start
// handshakes. The phase is selected only by delaying the external bus
// transaction relative to an observed public boundary; no DUT state is forced.
class thermo5_sku_axil_boundary_phase_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_boundary_phase_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit boundary_seen;
    int unsigned boundary_offset;
    int unsigned start_after_beats;
    int unsigned aw_gap;
    int unsigned w_gap;
    int signed source_gap_beat;
    int unsigned source_gap_cycles;
    int unsigned cycles;
    int signed commit_after_run_cycles;
    bit commit_on_run;
    bit early_bready;

    if (!$value$plusargs("AXIL_BOUNDARY_OFFSET=%d",boundary_offset))
      boundary_offset=0;
    if (!$value$plusargs("AXIL_START_AFTER_BEATS=%d",start_after_beats))
      start_after_beats=4;
    if (!$value$plusargs("AXIL_BOUNDARY_AW_GAP=%d",aw_gap))
      aw_gap=0;
    if (!$value$plusargs("AXIL_BOUNDARY_W_GAP=%d",w_gap))
      w_gap=0;
    source_gap_beat=-1;
    source_gap_cycles=0;
    void'($value$plusargs("AXIL_BOUNDARY_GAP_BEAT=%d",source_gap_beat));
    void'($value$plusargs("AXIL_BOUNDARY_GAP_CYCLES=%d",source_gap_cycles));
    commit_after_run_cycles=-1;
    void'($value$plusargs("AXIL_COMMIT_AFTER_RUN_CORE_CYCLES=%d",commit_after_run_cycles));
    commit_on_run=$test$plusargs("AXIL_COMMIT_ON_RUN");
    early_bready=$test$plusargs("AXIL_EARLY_BREADY");
    if (boundary_offset>64)
      `uvm_fatal("AXIL_BOUNDARY_OFFSET","Offset must be in [0,64] core cycles")
    if (start_after_beats<1 || start_after_beats>cfg.source_beats)
      `uvm_fatal("AXIL_START_AFTER_BEATS","RUN must wait for at least one and at most all source beats")
    if (aw_gap>16 || w_gap>16)
      `uvm_fatal("AXIL_BOUNDARY_CHANNEL_GAP","AW/W gap must be in [0,16] AXI-Lite cycles")
    if (source_gap_cycles>32 ||
        (source_gap_cycles!=0 && source_gap_beat!=8 && source_gap_beat!=20))
      `uvm_fatal("AXIL_BOUNDARY_SOURCE_GAP","Use 1..32 legal source cycles before frame beat 8 or 20")
    if (commit_after_run_cycles>80 || (commit_on_run && commit_after_run_cycles>=0))
      `uvm_fatal("AXIL_COMMIT_SCHEDULE","Use commit-on-run or a 0..80 core-cycle delay, not both")

    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,0,source_gap_beat,source_gap_cycles);
          begin
            wait(env.source.monitor.accepted_beats>=start_after_beats);
            if (commit_on_run) begin
              // With RUN previously low, the input frame is buffered but no
              // DPD boundary can occur. A legal RUN+COMMIT makes the first
              // boundary race the synchronized request/pending capture; this
              // specifically exercises the request-visible/pending-clear bin.
              axil_write(8'h00,32'h3,aw_gap,w_gap,resp,4'hf,early_bready);
              if (resp!=2'b00)
                `uvm_fatal("AXIL_PHASE_COMMIT_ON_RUN","Could not issue legal RUN+COMMIT")
            end else begin
              axil_write(8'h00,32'h1,0,0,resp,4'hf,early_bready);
              if (resp!=2'b00)
                `uvm_fatal("AXIL_PHASE_RUN","Could not start the legal source stream")

              if (commit_after_run_cycles>=0) begin
                repeat (commit_after_run_cycles) @(posedge vif.core_clk);
                // Schedule a legal COMMIT from the public core-clock timeline,
                // before the first frame marker reaches the DPD boundary.
                axil_write(8'h00,32'h3,aw_gap,w_gap,resp,4'hf,early_bready);
                if (resp!=2'b00)
                  `uvm_fatal("AXIL_PHASE_EARLY_COMMIT","Legal pre-boundary COMMIT was rejected")
              end else begin
                boundary_seen=0;
                for (cycles=0;cycles<2000 && !boundary_seen;cycles++) begin
                  @(posedge vif.core_clk);
                  boundary_seen=(vif.dpd_config_boundary===1'b1);
                end
                if (!boundary_seen)
                  `uvm_fatal("AXIL_PHASE_BOUNDARY","No accepted DPD frame-start boundary was observed")

                repeat (boundary_offset) @(posedge vif.core_clk);
                // Preserve RUN while committing: CONTROL bit 0 is the run request
                // and bit 1 is COMMIT, so a value of 2 would legally stop the core.
                axil_write(8'h00,32'h3,aw_gap,w_gap,resp,4'hf,early_bready);
                if (resp!=2'b00)
                  `uvm_fatal("AXIL_PHASE_COMMIT","Legal identity COMMIT was rejected")
              end
            end

            cycles=0;
            while ((vif.cfg_busy!==1'b0 || vif.cfg_done!==1'b1) && cycles<2000) begin
              @(negedge env.axil.monitor.vif.aclk);
              cycles++;
            end
            if (vif.cfg_busy!==1'b0 || vif.cfg_done!==1'b1 || vif.cfg_error!==1'b0)
              `uvm_fatal("AXIL_PHASE_ACK","COMMIT did not complete cleanly at a legal boundary")

            wait(env.scoreboard.checked==cfg.core_words);
            check_full();
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_PHASE_STOP","Could not stop after the bit-true stream drained")
            `uvm_info("SKU_PASS",
              $sformatf("THERMO5_AXIL_BOUNDARY_PHASE_UVM_PASS offset=%0d aw_gap=%0d w_gap=%0d gap_beat=%0d gap_cycles=%0d start_after_beats=%0d commit_on_run=%0d commit_after_run_cycles=%0d boundary=external-handshake identity=bittrue",
                        boundary_offset,aw_gap,w_gap,source_gap_beat,source_gap_cycles,start_after_beats,commit_on_run,commit_after_run_cycles),UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","AXI-Lite boundary phase test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
