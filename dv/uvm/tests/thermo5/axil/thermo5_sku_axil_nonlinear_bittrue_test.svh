// Full-chain oracle test for a non-identity polynomial DPD image. Run with
// centered-cubic RTL and matching Python-generated vectors.
class thermo5_sku_axil_nonlinear_bittrue_test extends thermo5_sku_axil_nonlinear_dpd_test;
  `uvm_component_utils(thermo5_sku_axil_nonlinear_bittrue_test)

  int expected_tlast_count;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function bit allow_extended_frame_count();
    return 0;
  endfunction

  virtual function void configure_case();
    int packet_beats;
    super.configure_case();
    cfg.expect_pa=1;
    cfg.frame_starts=cfg.core_words/56;
    if (cfg.core_words<56 || (cfg.core_words%56)!=0)
      `uvm_fatal("NONLINEAR_WORDS","CORE_WORDS must be a positive multiple of 56")
    if (!allow_extended_frame_count() &&
        (cfg.core_words!=56) && (cfg.core_words!=112))
      `uvm_fatal("NONLINEAR_WORDS","Use CORE_WORDS=56 or CORE_WORDS=112")
    packet_beats=0;
    void'($value$plusargs("PACKET_BEATS=%d",packet_beats));
    if (packet_beats==0) packet_beats=cfg.source_beats;
    if (packet_beats<1 || (cfg.source_beats%packet_beats)!=0)
      `uvm_fatal("NONLINEAR_PACKET","PACKET_BEATS must divide the source beat count")
    expected_tlast_count=cfg.source_beats/packet_beats;
  endfunction

  virtual function int unsigned configured_active_taps();
    return 2;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd2,64'h0000_0000_0400_4000,64'd0,
            64'h0000_0000_0200_0800,64'd0,64'd0,64'd0};
  endfunction

  virtual function string scenario_pass_message();
    return $sformatf("THERMO5_AXIL_NONLINEAR_BITTRUE_UVM_PASS: polynomial DPD image matched all four planes across %0d packet(s), %0d frame(s)",
                     expected_tlast_count,cfg.frame_starts);
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd2,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select two active DPD taps")
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      bit [31:0] coeff_word;
      addr=8'h10+8'(4*word);
      case (word)
        0: coeff_word=32'h0400_4000; // c1_re tap 0 and memory tap 1
        4: coeff_word=32'h0200_0800; // nonlinear c3_re taps 0 and 1
        default: coeff_word=32'd0;
      endcase
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("AXIL_NONLINEAR_COEFF_WRITE",
          $sformatf("Coefficient write failed addr=%02x",addr))
    end
  endtask

  virtual task check_scenario_stream();
    int expected_dpd_words;
    expected_dpd_words=cfg.core_words+cfg.frame_starts;
    if (env.source.monitor.accepted_beats!=cfg.source_beats ||
        env.source.monitor.accepted_last_count!=expected_tlast_count ||
        env.scoreboard.source_checked!=cfg.source_beats ||
        env.scoreboard.checked!=cfg.core_words ||
        env.coverage.pa_words!=cfg.core_words ||
        env.coverage.frame_starts!=cfg.frame_starts ||
        vif.protocol_error || env.coverage.underflow_before_last_source!=0)
      `uvm_fatal("AXIL_NONLINEAR_BITTRUE_STREAM",
        $sformatf("source=%0d/%0d TLAST=%0d/%0d starts=%0d/%0d output=%0d/%0d protocol=%b",
          env.source.monitor.accepted_beats,cfg.source_beats,
          env.source.monitor.accepted_last_count,expected_tlast_count,
          env.coverage.frame_starts,cfg.frame_starts,
          env.scoreboard.checked,cfg.core_words,vif.protocol_error))
    for (int lane=0;lane<16;lane++)
      if (vif.dpd_sample_count[lane]!==expected_dpd_words)
        `uvm_fatal("AXIL_NONLINEAR_DPD_COUNT",
          $sformatf("lane=%0d samples=%0d expected=%0d",lane,
            vif.dpd_sample_count[lane],expected_dpd_words))
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit [386:0] expected_cfg_payload;
    bit drain_complete;
    int unsigned stream_timeout_cycles, overall_timeout_cycles, drain_polls;
    expected_cfg_payload=configured_payload();
    stream_timeout_cycles=12000;
    overall_timeout_cycles=20000;
    if (allow_extended_frame_count()) begin
      stream_timeout_cycles+=2*cfg.core_words;
      overall_timeout_cycles+=3*cfg.core_words;
    end
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            program_dpd_image(resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_NONLINEAR_PROGRAM","DPD image programming failed")
            axil_write(8'h00,32'h2,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_NONLINEAR_COMMIT","DPD image commit failed")
            for (int cycles=0; cycles<100 &&
                 vif.cfg_pending_payload!==expected_cfg_payload; cycles++)
              @(posedge vif.core_clk);
            if (vif.cfg_pending_payload!==expected_cfg_payload)
              `uvm_fatal("AXIL_NONLINEAR_PENDING_IMAGE",
                $sformatf("pending=%097x expected=%097x mailbox=%097x",
                  vif.cfg_pending_payload,expected_cfg_payload,vif.cfg_mailbox_payload))
            `uvm_info("AXIL_NONLINEAR_PROGRESS","coefficient image is pending",UVM_LOW)

            // Let the source fill the ingress FIFO before RUN. The pending
            // coefficient image is therefore guaranteed to precede the first
            // centered-frame DPD boundary.
            wait(env.source.monitor.accepted_beats>=16);
            `uvm_info("AXIL_NONLINEAR_PROGRESS","ingress prefill reached 16 accepted beats",UVM_LOW)
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_RUN","RUN request failed")
            `uvm_info("AXIL_NONLINEAR_PROGRESS","RUN asserted",UVM_LOW)
            // Stop ingress as soon as the complete packet stream is accepted.
            // Keeping RUN asserted until the much larger PA stream finishes
            // creates a finite-source starvation window unrelated to DPD
            // saturation and obscures the intended graceful-drain contract.
            for (int cycles=0; cycles<stream_timeout_cycles &&
                 env.source.monitor.accepted_beats<cfg.source_beats; cycles++)
              @(posedge vif.core_clk);
            if (env.source.monitor.accepted_beats!=cfg.source_beats)
              `uvm_fatal("AXIL_NONLINEAR_SOURCE_TIMEOUT",
                $sformatf("accepted %0d/%0d source beats before STOP",
                  env.source.monitor.accepted_beats,cfg.source_beats))
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("AXIL_STOP","RUN clear failed after source packet completion")
            for (int cycles=0; cycles<stream_timeout_cycles && !scenario_stream_complete(); cycles++)
              @(posedge vif.core_clk);
            if (!scenario_stream_complete())
              `uvm_fatal("AXIL_NONLINEAR_TIMEOUT","Nonlinear bit-true stream did not complete")
            `uvm_info("AXIL_NONLINEAR_PROGRESS","all expected PA words were checked",UVM_LOW)
            check_scenario_stream();
            wait(vif.cfg_done);
            `uvm_info("AXIL_NONLINEAR_PROGRESS","DPD configuration acknowledgement completed",UVM_LOW)
            if (vif.cfg_active_payload!==expected_cfg_payload)
              `uvm_fatal("AXIL_NONLINEAR_ACTIVE","Active nonlinear DPD image did not match the programmed image")
            if (vif.underflow || env.coverage.underflow_before_last_source!=0)
              `uvm_fatal("AXIL_NONLINEAR_UNDERFLOW",
                $sformatf("underflow=%0b early_underflow=%0d",vif.underflow,
                  env.coverage.underflow_before_last_source))
            drain_complete=0;
            for (drain_polls=0; drain_polls<1000 && !drain_complete; drain_polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00) `uvm_fatal("AXIL_STATUS","Could not read drain status")
              drain_complete=(rdata[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("AXIL_DRAIN_TIMEOUT","Frontend did not finish nonlinear packet drain")
            $display("THERMO5_DPD_DRAIN_STATUS_CLEAR status=%08x polls=%0d",
              rdata,drain_polls);
            // Exercise the independently predicted lifecycle bits after the
            // core-to-AXI synchronizer has had time to settle. Drain polling
            // above checks the externally visible completion condition; this
            // read also makes the predictor's active/draining comparison live.
            repeat(16) @(posedge env.axil.monitor.vif.aclk);
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[4:3]!=2'b00)
              `uvm_fatal("AXIL_STATUS_SETTLED",
                $sformatf("settled STATUS must be inactive: resp=%b status=%08x",resp,rdata))
            $display("THERMO5_AXIL_STATUS_SETTLED_CHECK status=%08x",rdata);
            if (!env.unified_scoreboard.check_expected_queues_drained("nonlinear-bittrue"))
              `uvm_fatal("AXIL_NONLINEAR_EXPECTED_QUEUE",
                "Independent expectations remained after nonlinear STOP/drain")
            `uvm_info("SKU_PASS",scenario_pass_message(),UVM_NONE)
          end
        join
      end
      begin
        repeat(overall_timeout_cycles) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 nonlinear bit-true test timeout")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
