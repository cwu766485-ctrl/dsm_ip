// Diagnostic reproducer for RUN reassertion before STOP drain completes. The
// held PA sink creates real partial/full ingress occupancy; this test is kept
// outside the passing regression matrix because the RTL stream checker reports
// a four-plane mismatch for the early-restart sequence.
class thermo5_sku_axil_early_restart_reproducer_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_early_restart_reproducer_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.frame_starts=2;
    if (cfg.core_words!=112 || cfg.source_beats!=64)
      `uvm_fatal("RESTART_FIFO_WORDS",
        "Use the two-packet 112-word/64-beat oracle for restart occupancy tests")
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    string requested_state;
    bit target_seen;
    int target_code;

    if (!$value$plusargs("RESTART_FIFO_TARGET=%s",requested_state))
      `uvm_fatal("RESTART_FIFO_TARGET","Set RESTART_FIFO_TARGET=partial or full")
    if (requested_state=="partial") target_code=1;
    else if (requested_state=="full") target_code=2;
    else `uvm_fatal("RESTART_FIFO_TARGET",
      $sformatf("Unsupported restart FIFO target '%s'",requested_state))

    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();

            // Prefill before RUN, then stop during packet 1 while keeping its
            // packet-open ingress legal through TLAST. Hold PA to build the
            // requested real FIFO occupancy before reasserting RUN.
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00) `uvm_fatal("RESTART_FIFO_RUN1","Initial RUN failed")
            wait(env.source.monitor.accepted_beats>=20);
            axil_write(8'h00,32'd0,0,1,resp);
            if (resp!=2'b00) `uvm_fatal("RESTART_FIFO_STOP1","Initial STOP failed")
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b11)
              `uvm_fatal("RESTART_FIFO_DRAIN_STATUS",
                $sformatf("STOP did not enter graceful drain: status=%08x",rdata))
            env.pa_sink.set_ready(4'h0);

            target_seen=0;
            for (int cycles=0;cycles<12000 && !target_seen;cycles++) begin
              @(posedge vif.core_clk);
              if (target_code==1)
                target_seen=!vif.fifo_empty && !vif.fifo_full;
              else
                target_seen=vif.fifo_full;
            end
            if (!target_seen)
              `uvm_fatal("RESTART_FIFO_OCCUPANCY_TIMEOUT",
                $sformatf("FIFO never reached requested %s occupancy (empty=%b full=%b accepted=%0d)",
                  requested_state,vif.fifo_empty,vif.fifo_full,
                  env.source.monitor.accepted_beats))
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b11)
              `uvm_fatal("RESTART_FIFO_NOT_DRAINING",
                $sformatf("Reproducer requires RUN reassertion during DRAINING: status=%08x",rdata))

            // The coverage monitor samples empty/partial/full directly from
            // the interface on this write; verify the same state immediately
            // before the transaction is launched.
            if ((target_code==1 && (vif.fifo_empty || vif.fifo_full)) ||
                (target_code==2 && !vif.fifo_full))
              `uvm_fatal("RESTART_FIFO_STATE_RACE",
                "Requested FIFO state changed before RUN reassertion")
            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00) `uvm_fatal("RESTART_FIFO_RUN2","RUN reassertion failed")
            env.pa_sink.set_ready(4'hf);

            // Stop again inside packet 2. Let the legal packet tail drain and
            // check the full output stream and conservation through the UVM
            // scoreboard before reporting the coverage witness.
            wait(env.source.monitor.accepted_beats>=36);
            axil_write(8'h00,32'd0,0,1,resp);
            if (resp!=2'b00) `uvm_fatal("RESTART_FIFO_STOP2","Final STOP failed")
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b11)
              `uvm_fatal("RESTART_FIFO_FINAL_DRAIN",
                $sformatf("Final STOP did not enter graceful drain: status=%08x",rdata))

            for (int cycles=0;cycles<16000 && env.scoreboard.checked<112;cycles++)
              @(posedge vif.core_clk);
            if (env.source.monitor.accepted_beats!=64 ||
                env.source.monitor.accepted_last_count!=2 ||
                env.scoreboard.source_checked!=64 ||
                env.scoreboard.checked!=112 || env.coverage.pa_words!=112 ||
                vif.protocol_error || vif.underflow ||
                env.coverage.underflow_before_last_source!=0)
              `uvm_fatal("RESTART_FIFO_STREAM_CHECK",
                $sformatf("state=%s source=%0d TLAST=%0d checked=%0d PA=%0d protocol=%b underflow=%b",
                  requested_state,env.source.monitor.accepted_beats,
                  env.source.monitor.accepted_last_count,
                  env.scoreboard.checked,env.coverage.pa_words,
                  vif.protocol_error,vif.underflow))

            if (!env.unified_scoreboard.check_expected_queues_drained(
                  $sformatf("restart-fifo-%s",requested_state)))
              `uvm_fatal("RESTART_FIFO_QUEUE","Expected queues remained after drain")
            `uvm_info("SKU_PASS",
              $sformatf("THERMO5_AXIL_RESTART_FIFO_STATE_PASS: %s FIFO was observed on RUN reassertion; all 112 ordered four-plane words matched the independent oracle",
                requested_state),UVM_NONE)
          end
        join
      end
      begin
        repeat(32000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 restart FIFO state test timed out")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
