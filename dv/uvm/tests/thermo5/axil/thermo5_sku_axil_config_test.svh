class thermo5_sku_axil_base_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_base_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.axil_control = 1'b1;
    cfg.random_pa_ready = 0;
    cfg.manual_pa_ready = 1;
  endfunction

  // Scenario-specific DPD images are supplied by small derived tests. The
  // integrated default scenario focuses on commit, datapath, boundary and
  // reset behavior; register-map/protocol-only checks live in a separate test.
  virtual function int unsigned configured_active_taps();
    return 2;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd2,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
  endfunction

  virtual function bit check_pending_payload();
    return 0;
  endfunction

  virtual function string scenario_pass_message();
    return "THERMO5_AXIL_CONFIG_UVM_PASS: illegal tap rejected; mailbox waited for DPD frame boundary; legal identity-equivalent two-tap config applied; all four planes bit-true";
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd2,0,3,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Legal tap-count write failed")
    axil_write(8'h10,32'h0000_4000,2,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_COEFF","Unity c1 coefficient write failed")
    axil_write(8'h14,32'd0,0,2,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_COEFF","c1 high-word write failed")
  endtask

  virtual function bit scenario_stream_complete();
    return env.scoreboard.checked==cfg.core_words;
  endfunction

  virtual task check_scenario_stream();
    check_full();
  endtask

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

  // Pure control-plane test body. It intentionally does not launch AXI-Stream
  // traffic; end-to-end commit/data-path behavior stays in config_test.
  task run_register_access_checks();
    bit [1:0] resp;
    bit [31:0] rdata;

    axil_read(8'h0c,rdata,resp,1'b1);
    if (resp!=2'b00 || rdata!=32'h5448_3501)
      `uvm_fatal("AXIL_ID",$sformatf("ID read resp=%b data=%08x",resp,rdata))
    axil_write(8'h0c,32'hdead_beef,0,0,resp);
    if (resp!=2'b11) `uvm_fatal("AXIL_ID_WRITE","Read-only IP_ID write did not return DECERR")
    axil_read(8'h0c,rdata,resp);
    if (resp!=2'b00 || rdata!=32'h5448_3501)
      `uvm_fatal("AXIL_ID_WRITE_PROTECT","IP_ID changed after rejected write")

    axil_write(8'h08,32'd0,0,2,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Shadow tap write unexpectedly failed")
    axil_write(8'h00,32'h2,0,0,resp,4'h0);
    if (resp!=2'b00) `uvm_fatal("AXIL_CONTROL_ZERO_STROBE","Zero-strobe commit was not ignored")
    axil_read(8'h04,rdata,resp);
    if (resp!=2'b00 || rdata[4:0]!=5'b0)
      `uvm_fatal("AXIL_CONTROL_ZERO_STROBE_STATUS","Zero-strobe commit changed status")
    axil_write(8'h00,32'h2,3,0,resp);
    if (resp!=2'b10) `uvm_fatal("AXIL_BAD_TAP","Illegal tap-count commit was not rejected")
    axil_read(8'h04,rdata,resp);
    if (resp!=2'b00 || !rdata[2] || rdata[1:0]!=2'b00 || rdata[4:3]!=2'b00)
      `uvm_fatal("AXIL_ERROR_STATUS",$sformatf("Expected sticky error only, status=%08x",rdata))
    axil_write(8'h04,32'h2,0,0,resp,4'h0);
    if (resp!=2'b00) `uvm_fatal("AXIL_DONE_ZERO_STROBE","Zero-strobe DONE W1C failed")
    axil_write(8'h04,32'h4,0,0,resp,4'h0);
    if (resp!=2'b00) `uvm_fatal("AXIL_ERROR_ZERO_STROBE","Zero-strobe ERROR W1C failed")
    axil_read(8'h04,rdata,resp);
    if (resp!=2'b00 || !rdata[2])
      `uvm_fatal("AXIL_ZERO_STROBE_STATUS","Zero-strobe W1C unexpectedly cleared error")
    axil_write(8'h04,32'h4,0,1,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_W1C","STATUS W1C write failed")

    axil_write(8'h08,32'd5,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_UPPER","Upper-bound tap shadow write failed")
    axil_write(8'h00,32'h2,0,0,resp);
    if (resp!=2'b10) `uvm_fatal("AXIL_BAD_TAP_UPPER","Tap count above MAX_TAPS was not rejected")
    axil_write(8'h04,32'h4,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_UPPER_W1C","Could not clear upper-bound error")
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_RESTORE","Could not restore legal tap count")

    // Exercise all coefficient shadow words and byte strobes without starting
    // the datapath. Alternating patterns catch address/packing/read-mux errors.
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      addr=8'h10+8'(4*word);
      axil_write(addr,32'hffff_ffff,0,0,resp);
      if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_WRITE","All-one coefficient write failed")
      axil_read(addr,rdata,resp);
      if (resp!=2'b00 || rdata!==32'hffff_ffff)
        `uvm_fatal("AXIL_COEFF_TOGGLE_READBACK","All-one coefficient readback failed")
      axil_write(addr,32'h0000_0000,0,0,resp);
      if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_WRITE","Zero coefficient write failed")
      axil_read(addr,rdata,resp);
      if (resp!=2'b00 || rdata!==32'h0000_0000)
        `uvm_fatal("AXIL_COEFF_TOGGLE_READBACK","Zero coefficient readback failed")
      axil_write(addr,32'h1234_5678,0,0,resp,4'h1);
      if (resp!=2'b00) `uvm_fatal("AXIL_COEFF_STRB","Partial-byte coefficient write failed")
      axil_read(addr,rdata,resp);
      if (resp!=2'b00 || rdata[7:0]!=8'h78 || rdata[31:8]!=0)
        `uvm_fatal("AXIL_COEFF_READBACK","WSTRB/readback behavior mismatch")
    end
    axil_write(8'h08,32'd4,0,0,resp,4'h0);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS_ZERO_STROBE","Zero-strobe TAPS response failed")
    axil_read(8'h08,rdata,resp);
    if (resp!=2'b00 || rdata[2:0]!=3'd1)
      `uvm_fatal("AXIL_TAPS_ZERO_STROBE","Zero-strobe write changed TAPS")
    axil_write(8'h00,32'h2,0,0,resp,4'h0);
    if (resp!=2'b00) `uvm_fatal("AXIL_CONTROL_ZERO_STROBE","Zero-strobe CONTROL response failed")

    axil_write(8'h40,32'd0,0,0,resp,4'hf,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_WRITE","Unmapped write did not return DECERR")
    axil_write(8'h41,32'd0,0,2,resp,4'hf,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_UNALIGNED_WRITE","Unaligned write did not return DECERR")
    axil_write(8'h82,32'd0,0,2,resp,4'hf,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_HIGH_WRITE","High unmapped write did not return DECERR")
    axil_read(8'h40,rdata,resp,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_READ","Unmapped read did not return DECERR")
    axil_read(8'h41,rdata,resp,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_UNALIGNED_READ","Unaligned read did not return DECERR")
    axil_read(8'h82,rdata,resp,1'b1);
    if (resp!=2'b11) `uvm_fatal("AXIL_DECERR_HIGH_READ","High unmapped read did not return DECERR")
    if (env.axil.monitor.writes<8 || env.axil.monitor.reads<3)
      `uvm_fatal("AXIL_MONITOR","AXI-Lite monitor missed expected register traffic")
    probe_arvalid_during_rstall(3'd1);
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit boundary_seen;
    bit [386:0] expected_cfg_payload;
    int unsigned expected_active_taps;
    int unsigned pa_stall_cycles;
    expected_active_taps=configured_active_taps();
    expected_cfg_payload=configured_payload();
    pa_stall_cycles=4;
    void'($value$plusargs("AXIL_PA_STALL_CYCLES=%d",pa_stall_cycles));
    if (pa_stall_cycles<4 || pa_stall_cycles>4096)
      `uvm_fatal("AXIL_PA_STALL_ARGUMENT",
        $sformatf("AXIL_PA_STALL_CYCLES must be in [4,4096], got %0d",pa_stall_cycles))
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

        program_dpd_image(resp);
        axil_write(8'h00,32'h2,0,3,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_COMMIT","Valid commit request failed")
        if (vif.cfg_mailbox_payload!==expected_cfg_payload)
          `uvm_fatal("AXIL_MAILBOX_PAYLOAD","Committed mailbox payload did not match the legal shadow-register image")
        if (check_pending_payload()) begin
          wait (vif.cfg_pending_payload===expected_cfg_payload);
          `uvm_info("AXIL_COEFF_PENDING","Legal coefficient image observed atomically in core pending bank",UVM_MEDIUM)
        end
        for (int cycles=0; cycles<100 &&
             env.coverage.commit_pending_while_stopped_cycles==0; cycles++)
          @(posedge vif.core_clk);
        if (env.coverage.commit_pending_while_stopped_cycles==0)
          `uvm_fatal("AXIL_PENDING_STOP_COVERAGE",
            "Independent monitor did not observe a pending commit while RUN was stopped")
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
        repeat (pa_stall_cycles) begin
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

        for (int cycles=0; cycles<10000 && !scenario_stream_complete(); cycles++)
          @(posedge vif.core_clk);
        if (!scenario_stream_complete())
          `uvm_fatal("AXIL_STREAM_TIMEOUT","AXI-Lite-controlled bit-true stream did not drain")
        check_scenario_stream();

        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b010)
          `uvm_fatal("AXIL_DONE",$sformatf("Expected DONE with no BUSY/ERROR, status=%08x",rdata))
        axil_write(8'h04,32'h2,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_DONE_W1C","Could not clear DONE status")
        axil_read(8'h04,rdata,resp);
        if (resp!=2'b00 || rdata[2:0]!=3'b000)
          `uvm_fatal("AXIL_DONE_CLEAR","DONE did not clear through STATUS W1C")

        axil_read(8'h00,rdata,resp);
        if (resp!=2'b00 || !rdata[0])
          `uvm_fatal("AXIL_CONTROL","run_request did not read back as one")
        axil_write(8'h00,32'd0,0,0,resp);
        if (resp!=2'b00) `uvm_fatal("AXIL_STOP","run_request clear failed after the stream drained")
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

            `uvm_info("SKU_PASS",scenario_pass_message(),UVM_NONE)
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

class thermo5_sku_axil_config_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_config_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
endclass

// Actual GT-parent product setting: one active tap with the reset-default
// unity coefficient. The broader MAX_TAPS=4 test remains a separate candidate
// configuration and is not part of product coverage.
class thermo5_sku_axil_product_identity_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_product_identity_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function int unsigned configured_active_taps();
    return 1;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd1,64'h0000_0000_0000_4000,64'd0,64'd0,64'd0,64'd0,64'd0};
  endfunction

  virtual function string scenario_pass_message();
    return "THERMO5_AXIL_PRODUCT_IDENTITY_UVM_PASS: one-tap GT-parent product image committed atomically; all four planes matched the identity oracle";
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_PRODUCT_TAPS","Product one-tap setting was rejected")
    axil_write(8'h10,32'h0000_4000,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_PRODUCT_COEFF","Product unity coefficient write failed")
    axil_write(8'h14,32'd0,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_PRODUCT_COEFF","Product coefficient high-word write failed")
  endtask
endclass
