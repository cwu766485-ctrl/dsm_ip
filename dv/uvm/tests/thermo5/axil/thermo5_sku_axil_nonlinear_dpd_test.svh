class thermo5_sku_axil_nonlinear_dpd_test extends thermo5_sku_axil_config_test;
  `uvm_component_utils(thermo5_sku_axil_nonlinear_dpd_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    // This is a control-plane payload/commit test. The generic MATLAB vectors
    // are for identity DPD, so do not miscompare nonlinear output against them.
    // A dedicated nonlinear bit-true oracle is a separate future test.
    cfg.expect_pa=0;
  endfunction

  virtual function int unsigned configured_active_taps();
    return 1;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd1,64'h0000_0000_0000_bfff,64'h0000_0000_0000_ffff,
            64'h0000_0000_0000_ffff,64'h0000_0000_0000_ffff,
            64'h0000_0000_0000_ffff,64'h0000_0000_0000_ffff};
  endfunction

  virtual function bit check_pending_payload();
    return 1;
  endfunction

  virtual function bit scenario_stream_complete();
    return env.coverage.pa_words==cfg.core_words;
  endfunction

  virtual task check_scenario_stream();
    int expected_dpd_words;
`ifdef THERMO5_CENTERED_CUBIC
    // The centered FIR emits one look-ahead DPD vector for each start marker;
    // those vectors are consumed by DPD even though only core_words PA words
    // belong to the checked output frame.
    expected_dpd_words=cfg.core_words+cfg.frame_starts;
`else
    expected_dpd_words=cfg.core_words;
`endif
    if (env.source.monitor.accepted_beats!=cfg.source_beats ||
        env.scoreboard.source_checked!=cfg.source_beats ||
        env.coverage.pa_words!=cfg.core_words || vif.protocol_error ||
        env.coverage.underflow_before_last_source!=0)
      `uvm_fatal("AXIL_NONLINEAR_STREAM",
        $sformatf("source=%0d checked_source=%0d output_words=%0d protocol_error=%0b",
          env.source.monitor.accepted_beats,env.scoreboard.source_checked,
          env.coverage.pa_words,vif.protocol_error))
    for (int lane=0;lane<16;lane++)
      if (vif.dpd_sample_count[lane]!==expected_dpd_words)
        `uvm_fatal("AXIL_NONLINEAR_DPD_COUNT",
          $sformatf("lane=%0d samples=%0d expected=%0d",lane,
            vif.dpd_sample_count[lane],expected_dpd_words))
  endtask

  virtual function string scenario_pass_message();
    return $sformatf("THERMO5_AXIL_NONLINEAR_DPD_CONFIG_UVM_PASS: non-identity coefficient image crossed mailbox atomically; %0d output words observed; arithmetic bit-true oracle not enabled for this scenario",cfg.core_words);
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select one active DPD tap")
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      bit [31:0] coeff_word;
      addr=8'h10+8'(4*word);
      case (word)
        0: coeff_word=32'h0000_bfff;
        2: coeff_word=32'h0000_ffff;
        4: coeff_word=32'h0000_ffff;
        6: coeff_word=32'h0000_ffff;
        8: coeff_word=32'h0000_ffff;
        10: coeff_word=32'h0000_ffff;
        default: coeff_word=32'd0;
      endcase
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("AXIL_NONLINEAR_COEFF_WRITE",$sformatf("Coefficient write failed addr=%02x",addr))
    end
  endtask
endclass
