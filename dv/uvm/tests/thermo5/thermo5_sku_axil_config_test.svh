class thermo5_sku_axil_config_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_config_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.axil_control = 1'b1;
    cfg.random_pa_ready = 0;
    cfg.manual_pa_ready = 1;
  endfunction

  task automatic axil_write(input bit [7:0] addr, input bit [31:0] data,
                            input int unsigned aw_gap, input int unsigned w_gap,
                            output bit [1:0] resp,
                            input bit [3:0] strb=4'hf,
                            input bit ready_early=1'b0);
    thermo5_axil_access_sequence seq;
    seq=thermo5_axil_access_sequence::type_id::create("axil_write_seq");
    seq.is_write=1;
    seq.addr=addr;
    seq.data=data;
    seq.strb=strb;
    seq.aw_delay=aw_gap;
    seq.w_delay=w_gap;
    seq.response_delay=2;
    seq.ready_before_response=ready_early;
    seq.start(env.axil.sequencer);
    resp=seq.resp;
  endtask

  task automatic axil_read(input bit [7:0] addr,
                           output bit [31:0] data, output bit [1:0] resp,
                           input bit ready_early=1'b0);
    thermo5_axil_access_sequence seq;
    seq=thermo5_axil_access_sequence::type_id::create("axil_read_seq");
    seq.is_write=0;
    seq.addr=addr;
    seq.data='0;
    seq.strb=4'hf;
    seq.aw_delay=0;
    seq.w_delay=0;
    seq.response_delay=1;
    seq.ready_before_response=ready_early;
    seq.start(env.axil.sequencer);
    data=seq.rdata;
    resp=seq.resp;
  endtask

  task automatic probe_arvalid_during_rstall(input logic [2:0] expected_taps);
    virtual thermo5_axil_if avif;
    avif=env.axil.monitor.vif;

    // Hold the first response, then legally present the next address while
    // the slave deasserts ARREADY. Retain ARVALID until the first response is
    // accepted and the second address handshakes.
    @(negedge avif.aclk);
    avif.rready<=1'b0;
    avif.araddr<=8'h0c;
    avif.arvalid<=1'b1;
    @(posedge avif.aclk);
    if (avif.arready!==1'b1)
      `uvm_fatal("AXIL_AR_PROBE","First AR was not accepted")
    @(negedge avif.aclk);
    avif.araddr<=8'h08;
    @(posedge avif.aclk);
    if (avif.rvalid!==1'b1 || avif.arready!==1'b0 || avif.rdata!==32'h5448_3501)
      `uvm_fatal("AXIL_AR_STALL","Second AR was not backpressured behind the ID response")

    @(negedge avif.aclk);
    avif.rready<=1'b1;
    @(posedge avif.aclk); // consume ID response
    @(negedge avif.aclk);
    avif.rready<=1'b0;
    @(posedge avif.aclk); // accept the still-pending TAPS address
    if (avif.arready!==1'b1)
      `uvm_fatal("AXIL_AR_RELEASE","ARREADY did not return after the first response")
    @(negedge avif.aclk);
    avif.arvalid<=1'b0;
    @(posedge avif.aclk);
    if (avif.rvalid!==1'b1 || avif.rdata[2:0]!==expected_taps)
      `uvm_fatal("AXIL_AR_SECOND_RESPONSE","Second read response was not the TAPS value")
    @(negedge avif.aclk);
    avif.rready<=1'b1;
    @(posedge avif.aclk); // consume TAPS response
    @(negedge avif.aclk);
    avif.rready<=1'b0;
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit boundary_seen;
    bit coeff_transport_test;
    bit [386:0] expected_cfg_payload;
    int unsigned expected_active_taps;
    coeff_transport_test=$test$plusargs("AXIL_COEFF_TRANSPORT");
    expected_active_taps=coeff_transport_test ? 1 : 2;
    expected_cfg_payload=coeff_transport_test ?
      {3'd1,64'hffff_ffff_ffff_4000,64'hffff_ffff_ffff_0000,
       64'hffff_ffff_ffff_0000,64'hffff_ffff_ffff_0000,
       64'hffff_ffff_ffff_0000,64'hffff_ffff_ffff_0000} :
      {3'd2,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
    phase.raise_objection(this);
    fork
      begin
        // The source sequence and control/check flow are concurrent, but the
        // test must not finish merely because the source has sent its last
        // beat. Keep both workers joined before dropping the objection.
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait(env.source.monitor.accepted_beats>=4);

        // READY is legally asserted before VALID on both response channels.
        axil_read(8'h0c,rdata,resp,1'b1);
        if (resp!=2'b00 || rdata!=32'h5448_3501)
          `uvm_fatal("AXIL_ID",$sformatf("ID read resp=%b data=%08x",resp,rdata))

        axil_write(8'h08,32'd0,0,2,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Shadow tap write unexpectedly failed")
        axil_write(8'h00,32'h2,0,0,resp,4'h0);
        if (resp!=2'b00) `uvm_fatal("AXIL_CONTROL_ZERO_STROBE","Zero-strobe invalid commit was not ignored")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b000)
          `uvm_fatal("AXIL_CONTROL_ZERO_STROBE_STATUS","Zero-strobe invalid commit changed status")
        axil_write(8'h00,32'h2,3,0,resp);
        if (resp!=2'b10) `uvm_fatal("AXIL_BAD_TAP","Illegal tap-count commit was not rejected with SLVERR")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || !rdata[2] || rdata[0] || rdata[1])
          `uvm_fatal("AXIL_ERROR_STATUS",$sformatf("Expected sticky error only, status=%08x",rdata))
        axil_write(8'h04,32'h2,0,0,resp,4'h0);
        if (resp!=2'b00) `uvm_fatal("AXIL_DONE_ZERO_STROBE","Zero-strobe DONE W1C failed")
        axil_write(8'h04,32'h4,0,0,resp,4'h0);
        if (resp!=2'b00) `uvm_fatal("AXIL_ERROR_ZERO_STROBE","Zero-strobe ERROR W1C failed")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || !rdata[2])
          `uvm_fatal("AXIL_ZERO_STROBE_STATUS","Zero-strobe W1C unexpectedly cleared sticky error")
        axil_write(8'h04,32'h4,0,1,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_W1C","STATUS W1C write failed")

        // Exercise the upper illegal tap bound separately from tap_count=0.
        axil_write(8'h08,32'd5,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_UPPER","Upper-bound tap shadow write failed")
        axil_write(8'h00,32'h2,0,0,resp);
        if (resp!=2'b10) `uvm_fatal("AXIL_BAD_TAP_UPPER","Tap count above MAX_TAPS was not rejected")
        axil_write(8'h04,32'h4,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_UPPER_W1C","Could not clear upper-bound error")
        axil_write(8'h08,32'd1,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_RESTORE","Could not restore legal tap count")

        if (coeff_transport_test) begin
          // Keep one tap active (tap0 remains unity); program taps1..3 in all
          // six banks to distinct nonzero values. The inactive taps exercise
          // legal payload CDC without changing the frozen bit-true data path.
          // A later public reset supplies the reverse coefficient-bank toggles.
          axil_write(8'h08,32'd1,0,0,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select one active tap")
          for (int word=0; word<12; word++) begin
            bit [7:0] addr;
            bit [31:0] coeff_word;
            addr=8'h10+8'(4*word);
            coeff_word=(word==0) ? 32'hffff_4000 :
                       ((word==2 || word==4 || word==6 || word==8 || word==10) ?
                         32'hffff_0000 : 32'hffff_ffff);
            axil_write(addr,coeff_word,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_COEFF_TRANSPORT_WRITE",$sformatf("Coefficient write failed addr=%02x",addr))
          end
        end else begin
          // Two enabled taps are mathematically identity: tap0 is unity and
          // tap1 plus all nonlinear coefficients are zero.
          axil_write(8'h08,32'd2,0,3,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Legal tap-count write failed")
          axil_write(8'h10,32'h0000_4000,2,0,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_COEFF","Unity c1 coefficient write failed")
          axil_write(8'h14,32'd0,0,2,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_COEFF","c1 high-word write failed")
        end
        axil_write(8'h00,32'h2,0,3,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_COMMIT","Valid commit request failed")
        if (vif.cfg_mailbox_payload!==expected_cfg_payload)
          `uvm_fatal("AXIL_MAILBOX_PAYLOAD","Committed mailbox payload did not match the legal shadow-register image")
        if (coeff_transport_test) begin
          wait (vif.cfg_pending_payload===expected_cfg_payload);
          `uvm_info("AXIL_COEFF_PENDING","Legal coefficient image observed atomically in core pending bank",UVM_MEDIUM)
        end
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || !rdata[0] || rdata[1] || rdata[2])
          `uvm_fatal("AXIL_BUSY",$sformatf("Commit should wait for DPD frame boundary, status=%08x",rdata))
        // A second commit while the mailbox is occupied must be rejected.
        axil_write(8'h00,32'h2,0,0,resp);
        if (resp!=2'b10)
          `uvm_fatal("AXIL_BUSY_COMMIT","Commit while BUSY was not rejected with SLVERR")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b101)
          `uvm_fatal("AXIL_BUSY_ERROR",$sformatf("Expected BUSY+ERROR, status=%08x",rdata))
        axil_write(8'h04,32'h4,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_BUSY_ERROR_W1C","Could not clear busy-reject sticky error")
        if (vif.dpd_active_taps!=3'd1 || vif.dpd_config_boundary ||
            vif.cfg_active_payload!={3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0})
          `uvm_fatal("AXIL_EARLY_APPLY","DPD config changed before a valid DPD frame-boundary transfer")

        // Start only after the input FIFO is prefilled. AXI-Lite and core
        // clocks are asynchronous (100 MHz and 218.75 MHz respectively).
        // Hold the PA side, then release it after observing a real four-plane
        // valid. This closes the ready/valid stall bin without changing data.
        @(negedge vif.core_clk);
        vif.pa_ready=4'h0;
        axil_write(8'h00,32'h1,2,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_RUN","run_request write failed")

        boundary_seen=0;
        for (int cycles=0; cycles<2000 && !boundary_seen; cycles++) begin
          @(posedge vif.core_clk);
          if (vif.pa_valid==4'hf && vif.pa_ready==4'h0)
            boundary_seen=1;
        end
        if (!boundary_seen)
          `uvm_fatal("AXIL_PA_STALL_TIMEOUT","PA did not present a four-plane word under backpressure")
        repeat (4) begin
          @(posedge vif.core_clk);
          if (vif.pa_valid!=4'hf || vif.pa_ready!=4'h0)
            `uvm_fatal("AXIL_PA_STALL","PA valid was not held during backpressure")
        end
        @(negedge vif.core_clk);
        vif.pa_ready=4'hf;

        boundary_seen=0;
        for (int cycles=0; cycles<2000 && !boundary_seen; cycles++) begin
          @(posedge vif.core_clk);
          if (vif.dpd_config_boundary && vif.dpd_active_taps==expected_active_taps)
            boundary_seen=1;
        end
        if (!boundary_seen)
          `uvm_fatal("AXIL_APPLY_TIMEOUT","Pending DPD config was not selected on a marked DPD input transfer")
        @(posedge vif.core_clk);
        if (vif.dpd_active_taps!=expected_active_taps)
          `uvm_fatal("AXIL_APPLY_PERSIST","Applied DPD config did not remain active after the boundary")
        wait (vif.cfg_done);
        if (vif.cfg_active_payload!==expected_cfg_payload)
          `uvm_fatal("AXIL_PAYLOAD_ATOMIC",$sformatf("Active payload mismatch got=%097x expected=%097x",
                    vif.cfg_active_payload,expected_cfg_payload))

        for (int cycles=0; cycles<10000 && env.scoreboard.checked<cfg.core_words; cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("AXIL_STREAM_TIMEOUT","AXI-Lite-controlled bit-true stream did not drain")
        check_full();

        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b010)
          `uvm_fatal("AXIL_DONE",$sformatf("Expected DONE with no BUSY/ERROR, status=%08x",rdata))
        axil_write(8'h04,32'h2,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_DONE_W1C","Could not clear DONE status")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b000)
          `uvm_fatal("AXIL_DONE_CLEAR","DONE did not clear through STATUS W1C")

        // Exercise every byte-addressed shadow coefficient register and the
        // coefficient read mux. These are shadow-only writes after the
        // bit-true frame has drained, so they cannot alter the checked output.
        axil_read(8'h08,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=expected_active_taps)
          `uvm_fatal("AXIL_TAPS_READ","TAPS readback mismatch")
        for (int word=0; word<12; word++) begin
          bit [7:0] addr;
          addr=8'h10+8'(4*word);
          axil_write(addr,32'hffff_ffff,0,0,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_WRITE","Coefficient all-ones write failed")
          axil_write(addr,32'h0000_0000,0,0,resp);
          if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_WRITE","Coefficient clear write failed")
          axil_write(addr,32'h1234_5678,0,0,resp,4'h1);
          if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_STRB","Partial-byte coefficient write failed")
          axil_read(addr,rdata,resp);
          if (resp!=2'b00 || rdata[7:0]!=8'h78 || rdata[31:8]!=0)
            `uvm_fatal("AXIL_COEFF_READBACK",$sformatf("Coefficient readback addr=%02x data=%08x resp=%b",addr,rdata,resp))
        end
        axil_write(8'h08,32'd1,0,0,resp,4'h0);
        if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_ZERO_STROBE","Zero-strobe TAPS write response failed")
        axil_read(8'h08,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=expected_active_taps)
          `uvm_fatal("AXIL_TAPS_ZERO_STROBE","Zero-strobe TAPS write changed shadow value")
        axil_write(8'h00,32'h2,0,0,resp,4'h0);
        if (resp!=2'b00) `uvm_fatal("AXIL_CONTROL_ZERO_STROBE","Zero-strobe CONTROL write response failed")
        axil_write(8'h40,32'd0,0,0,resp,4'hf,1'b1);
        if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_WRITE","Unmapped write did not return DECERR")
        axil_read(8'h40,rdata,resp,1'b1);
        if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_READ","Unmapped read did not return DECERR")
        if (env.axil.monitor.writes<8 || env.axil.monitor.reads<3)
          `uvm_fatal("AXIL_MONITOR","AXI-Lite monitor did not observe the expected register traffic")
        axil_read(8'h00,rdata,resp);
        if (resp!=2'b00 || !rdata[0])
          `uvm_fatal("AXIL_CONTROL","run_request did not read back as one")
        axil_write(8'h00,32'd0,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_STOP","run_request clear failed after the stream drained")
        probe_arvalid_during_rstall(3'(expected_active_taps));

        // Reassert both public resets after traffic and verify the AXI-Lite
        // register bank/mailbox return to documented reset defaults.
        env.control.reset_both();
        wait_axil_reset_release();
        if (env.coverage.reset_reassertions==0 || vif.dpd_active_taps!=3'd1 ||
            vif.cfg_busy || vif.cfg_done || vif.cfg_error ||
            vif.cfg_mailbox_payload!=={3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0} ||
            vif.cfg_pending_payload!=={3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0} ||
            vif.cfg_active_payload!=={3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0})
          `uvm_fatal("AXIL_RESET_DEFAULTS","Post-traffic reset did not restore reset state")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b000)
          `uvm_fatal("AXIL_RESET_STATUS","STATUS did not reset to zero")
        axil_read(8'h00,rdata,resp);
        if (resp!=2'b00 || rdata[0])
          `uvm_fatal("AXIL_RESET_CONTROL","run_request did not reset to zero")

            `uvm_info("SKU_PASS",coeff_transport_test ?
              "THERMO5_AXIL_COEFF_TRANSPORT_UVM_PASS: legal AXI coefficient payload crossed mailbox atomically with inactive taps; 56 four-plane words bit-true" :
              "THERMO5_AXIL_CONFIG_UVM_PASS: illegal tap rejected; mailbox waited for DPD frame boundary; legal identity-equivalent two-tap config applied; all four planes bit-true",UVM_NONE)
          end
        join
      end
      begin
        repeat(20000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 AXI-Lite config test timeout")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask

  task wait_axil_reset_release();
    repeat (3) @(posedge env.axil.monitor.vif.aclk);
    if (env.axil.monitor.vif.aresetn!==1'b1)
      `uvm_fatal("AXIL_RESET_RELEASE","AXI-Lite reset did not synchronously release")
  endtask
endclass

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

// Verification-only fault injection: corrupt the bundled payload while the
// request/acknowledge mailbox is busy. This is a deliberate expected $error,
// isolated from the legal bit-true test and merged only as a named negative
// test database.
class thermo5_sku_axil_mailbox_fault_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_mailbox_fault_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit injected;
    uvm_hdl_data_t corrupt_bundle;
    uvm_hdl_data_t released_bundle;
    string mailbox_path = "thermo5_sku_uvm_tb.dut.u_cfg.cfg_mailbox_q";

    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n && env.axil.monitor.vif.aresetn);
    // No source data is sent, so the committed bundle remains pending and the
    // public datapath boundary cannot acknowledge it.
    axil_write(8'h00,32'h2,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("AXIL_FAULT_COMMIT","Could not create a pending mailbox request")
    repeat (3) @(posedge env.axil.monitor.vif.aclk);

    corrupt_bundle='1;
    injected=uvm_hdl_force(mailbox_path,corrupt_bundle);
    if (!injected)
      `uvm_fatal("AXIL_FAULT_INJECT","Could not force the internal mailbox payload")
    @(posedge env.axil.monitor.vif.aclk);
    @(negedge env.axil.monitor.vif.aclk);
`ifdef THERMO5_XSIM
    if (!uvm_hdl_release(mailbox_path,released_bundle))
`else
    if (!uvm_hdl_release(mailbox_path))
`endif
      `uvm_fatal("AXIL_FAULT_RELEASE","Could not release the mailbox fault injection")
    `uvm_info("NEGATIVE","THERMO5_AXIL_MAILBOX_CORRUPTION_OBSERVED; expected RTL $error must also appear",UVM_NONE)

    env.control.reset_both();
    wait_axil_reset_release();
    `uvm_info("SKU_PASS","THERMO5_AXIL_MAILBOX_FAULT_UVM_PASS fault detected and public reset recovered",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

// Deliberate protocol-negative test for the AXI-Lite-controlled integration.
// The RTL $error is expected and is checked by the dedicated Make target;
// this test also checks sticky-error recovery through the public reset.
class thermo5_sku_axil_illegal_frame_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_illegal_frame_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.illegal_frame=1'b1;
    cfg.expect_pa=0;
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,1'b1);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_NEG_RUN","Could not start AXI-Lite-controlled negative stream")
            wait(vif.protocol_error===1'b1);
            repeat(2) @(posedge vif.core_clk);
            if (env.coverage.protocol_error_cycles==0)
              `uvm_fatal("AXIL_NEG_COVERAGE","Illegal-frame functional bin was not sampled")
            `uvm_info("NEGATIVE","THERMO5_AXIL_ILLEGAL_FRAME_OBSERVED; expected RTL assertion must also appear",UVM_NONE)
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("AXIL_NEG_STOP","Could not stop after illegal-frame detection")
            env.control.reset_both();
            wait_axil_reset_release();
            if (vif.protocol_error!==1'b0)
              `uvm_fatal("AXIL_NEG_RESET","Public reset did not clear sticky protocol error")
            `uvm_info("SKU_PASS","THERMO5_AXIL_ILLEGAL_FRAME_UVM_PASS sticky error cleared by public reset",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","AXI-Lite illegal-frame scenario did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
