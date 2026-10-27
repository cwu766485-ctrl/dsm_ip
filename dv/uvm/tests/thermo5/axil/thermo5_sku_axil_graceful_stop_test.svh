// RUN deassertion is exercised independently from DPD commit tests. The
// source fills the 16-beat ingress FIFO before RUN, then continues streaming
// while STOP is requested mid-packet. CORE_WORDS=112 exercises a 64-beat
// AXIS packet (two stop-safe quanta) against a MATLAB golden vector.
class thermo5_sku_axil_graceful_stop_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_graceful_stop_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function string scenario_pass_message();
    return $sformatf("THERMO5_AXIL_GRACEFUL_STOP_UVM_PASS: mid-packet STOP completed %0d source beats, drained %0d four-plane words, and reported no underflow",
                     cfg.source_beats,cfg.core_words);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit drain_complete;
    bit partial_stall_seen;
    phase.raise_objection(this);
    fork
      begin
        fork
          begin
            send_source(cfg.source_beats);
          end
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();

            // The asynchronous FIFO is 16 source beats deep. Starting RUN
            // only after this prefill avoids testing startup starvation
            // instead of the requested graceful-stop behavior.
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,2,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_RUN","RUN request failed")

            // Request STOP with twelve beats left in the first 32-beat
            // quantum. The source must continue accepting through packet TLAST.
            wait(env.source.monitor.accepted_beats>=20);
            axil_write(8'h00,32'd0,0,1,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_STOP","Graceful STOP request failed")

            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b11)
              `uvm_fatal("AXIL_DRAIN_STATUS",
                $sformatf("Expected RUN_ACTIVE+DRAINING after STOP, status=%08x",rdata))

            // Stall one PA plane while STOP is draining. The four planes
            // share one handshake, so partial ready must hold every plane.
            @(negedge vif.core_clk);
            vif.pa_ready=4'hd;
            partial_stall_seen=0;
            for (int cycles=0; cycles<2000 && !partial_stall_seen; cycles++) begin
              @(posedge vif.core_clk);
              partial_stall_seen=(vif.pa_valid==4'hf && vif.pa_ready!=4'hf);
            end
            if (!partial_stall_seen)
              `uvm_fatal("AXIL_STOP_PA_STALL_TIMEOUT","No PA word appeared under partial-ready STOP drain")
            for (int cycles=0; cycles<1000 &&
                 env.source.monitor.accepted_last_count==0; cycles++)
              @(posedge vif.src_clk);
            if (env.source.monitor.accepted_last_count!=1)
              `uvm_fatal("AXIL_STOP_TLAST_TIMEOUT","Source did not reach TLAST during PA backpressure")
            repeat (4) begin
              @(posedge vif.core_clk);
              if (vif.pa_valid!=4'hf || vif.pa_ready!=4'hd)
                `uvm_fatal("AXIL_STOP_PA_STALL","PA planes did not remain valid under partial ready")
            end
            @(negedge vif.core_clk);
            vif.pa_ready=4'hf;
            repeat (2) @(posedge vif.core_clk);
            if (env.coverage.stop_partial_pa_stall_cycles==0 ||
                env.coverage.tlast_pa_stall_cycles==0)
              `uvm_fatal("AXIL_STOP_CROSS_COVERAGE",
                $sformatf("STOP/TLAST partial-PA crosses missed: stop=%0d tlast=%0d",
                  env.coverage.stop_partial_pa_stall_cycles,
                  env.coverage.tlast_pa_stall_cycles))

            for (int cycles=0; cycles<10000 && !scenario_stream_complete(); cycles++)
              @(posedge vif.core_clk);
            if (!scenario_stream_complete())
              `uvm_fatal("AXIL_STREAM_TIMEOUT","Graceful-stop stream did not produce all expected words")
            check_scenario_stream();
            if (vif.underflow || vif.protocol_error)
              `uvm_fatal("AXIL_STOP_DIAGNOSTIC",
                $sformatf("Unexpected underflow/protocol error under graceful STOP: underflow=%b protocol=%b",
                  vif.underflow,vif.protocol_error))

            drain_complete=0;
            for (int polls=0; polls<1000 && !drain_complete; polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00)
                `uvm_fatal("AXIL_DRAIN_POLL","STATUS read failed while polling drain")
              drain_complete=(rdata[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("AXIL_DRAIN_TIMEOUT","RUN_ACTIVE/DRAINING did not clear after final output handshake")

            axil_read(8'h00,rdata,resp);
            if (resp!=2'b00 || rdata[0])
              `uvm_fatal("AXIL_STOP_READBACK","RUN request did not remain cleared")
            `uvm_info("SKU_PASS",scenario_pass_message(),UVM_NONE)
          end
        join
      end
      begin
        repeat(12000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 AXI-Lite graceful-stop test timeout")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
