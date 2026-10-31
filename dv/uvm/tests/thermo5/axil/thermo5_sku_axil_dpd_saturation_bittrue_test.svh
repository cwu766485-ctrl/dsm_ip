// Legal one-tap AXI-Lite coefficient stress for both DPD saturation rails.
// The Python oracle uses the same signed Q2.14 coefficient image and checks
// all four downstream output planes bit-for-bit.
class thermo5_sku_axil_dpd_saturation_bittrue_test extends thermo5_sku_axil_nonlinear_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_dpd_saturation_bittrue_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function int unsigned configured_active_taps();
    return 1;
  endfunction

  virtual function bit [386:0] configured_payload();
    return {3'd1,64'h0000_0000_0000_7fff,64'd0,
            64'd0,64'd0,64'd0,64'd0};
  endfunction

  virtual function string scenario_pass_message();
    return $sformatf("THERMO5_AXIL_DPD_SATURATION_BITTRUE_UVM_PASS: one-tap Q2.14 stress image matched all four planes; %0d output words; every DPD lane saturated",cfg.core_words);
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00) `uvm_fatal("AXIL_TAPS","Could not select one active DPD tap")
    for (int word=0; word<12; word++) begin
      bit [7:0] addr;
      bit [31:0] coeff_word;
      addr=8'h10+8'(4*word);
      coeff_word=(word==0) ? 32'h0000_7fff : 32'd0;
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("AXIL_DPD_SATURATION_COEFF",
          $sformatf("Coefficient write failed addr=%02x",addr))
    end
  endtask

  virtual task check_scenario_stream();
    super.check_scenario_stream();
    if (env.scoreboard.checked!=cfg.core_words ||
        env.coverage.frame_starts!=cfg.frame_starts ||
        env.source.monitor.accepted_last_count!=expected_tlast_count)
      `uvm_fatal("AXIL_DPD_SATURATION_COUNTS",
        $sformatf("checked=%0d/%0d frame_starts=%0d/%0d TLAST=%0d/%0d",
          env.scoreboard.checked,cfg.core_words,env.coverage.frame_starts,
          cfg.frame_starts,env.source.monitor.accepted_last_count,
          expected_tlast_count))
    for (int lane=0; lane<16; lane++) begin
      if (vif.dpd_sample_count[lane]!==cfg.core_words+cfg.frame_starts)
        `uvm_fatal("AXIL_DPD_SATURATION_SAMPLE_COUNT",
          $sformatf("lane=%0d samples=%0d expected=%0d",lane,
            vif.dpd_sample_count[lane],cfg.core_words+cfg.frame_starts))
      if (vif.dpd_saturation_count[lane]===0)
        `uvm_fatal("AXIL_DPD_SATURATION_NOT_REACHED",
          $sformatf("lane=%0d had no DPD saturation events",lane))
    end
  endtask
endclass
