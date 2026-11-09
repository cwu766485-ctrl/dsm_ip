// Legal one-tap AXI-Lite coefficient stress for both DPD saturation rails.
// The Python oracle uses the same signed Q2.14 coefficient image and checks
// all four downstream output planes bit-for-bit.
class thermo5_sku_axil_dpd_saturation_bittrue_test extends thermo5_sku_axil_nonlinear_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_dpd_saturation_bittrue_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function bit allow_extended_frame_count();
    return 1;
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
    int expected_fd;
    int expected_count;
    int scan_result;
    string expected_path;
    super.check_scenario_stream();
    if (env.scoreboard.checked!=cfg.core_words ||
        env.coverage.frame_starts!=cfg.frame_starts ||
        env.source.monitor.accepted_last_count!=expected_tlast_count)
      `uvm_fatal("AXIL_DPD_SATURATION_COUNTS",
        $sformatf("checked=%0d/%0d frame_starts=%0d/%0d TLAST=%0d/%0d",
          env.scoreboard.checked,cfg.core_words,env.coverage.frame_starts,
          cfg.frame_starts,env.source.monitor.accepted_last_count,
          expected_tlast_count))
    expected_path=$sformatf("%s/thermo5_dpd_saturation_count.mem",cfg.vector_dir);
    expected_fd=$fopen(expected_path,"r");
    if (expected_fd==0)
      `uvm_fatal("AXIL_DPD_SATURATION_ORACLE",
        $sformatf("Could not open independent lane-count oracle %s",expected_path))
    for (int lane=0; lane<16; lane++) begin
      expected_count=-1;
      scan_result=$fscanf(expected_fd,"%d",expected_count);
      if (scan_result!=1)
        `uvm_fatal("AXIL_DPD_SATURATION_ORACLE",
          $sformatf("Missing Python saturation count for lane=%0d",lane))
      if (vif.dpd_sample_count[lane]!==cfg.core_words+cfg.frame_starts)
        `uvm_fatal("AXIL_DPD_SATURATION_SAMPLE_COUNT",
          $sformatf("lane=%0d samples=%0d expected=%0d",lane,
            vif.dpd_sample_count[lane],cfg.core_words+cfg.frame_starts))
      if (vif.dpd_saturation_count[lane]!==expected_count)
        `uvm_fatal("AXIL_DPD_SATURATION_COUNT_MISMATCH",
          $sformatf("lane=%0d actual=%0d Python_expected=%0d",lane,
            vif.dpd_saturation_count[lane],expected_count))
      $display("THERMO5_DPD_COUNTER lane=%0d sample_count=%0d saturation_count=%0d",
        lane,vif.dpd_sample_count[lane],vif.dpd_saturation_count[lane]);
    end
    $fclose(expected_fd);
    $display("THERMO5_DPD_SATURATION_COUNTS_MATCH_PYTHON lanes=16");
  endtask
endclass
