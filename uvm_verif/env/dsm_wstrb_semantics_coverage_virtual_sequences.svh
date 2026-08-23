// Directed AXI4-Lite byte-strobe testing for the frozen Performance SKU.
// Every write below is a legal software transaction.  The sequence proves
// that selected bytes update while unselected bytes retain their prior value.
class dsm_wstrb_semantics_coverage_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_wstrb_semantics_coverage_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_wstrb_semantics_coverage_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input bit [3:0] wstrb, input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.wstrb = wstrb;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.data_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic expect_value(input dsm_reg_addr_t addr, input bit [31:0] expected,
                              input bit [31:0] mask, input string name);
    bit [31:0] value;
    read_reg(addr, value, name);
    if ((value & mask) != (expected & mask))
      `uvm_error("WSTRB", $sformatf(
        "%s got=0x%08x expected=0x%08x mask=0x%08x", name, value, expected, mask))
  endtask

  task automatic send_tx(input bit signed [15:0] i_sample,
                         input bit signed [15:0] q_sample,
                         input bit last, input string name);
    dsm_axis_single_item_sequence seq;
    seq = dsm_axis_single_item_sequence::type_id::create(name);
    seq.i_sample = i_sample;
    seq.q_sample = q_sample;
    seq.last = last;
    seq.user_error = 1'b0;
    seq.valid_gap_cycles = $urandom_range(0, 8);
    seq.start(p_sequencer.tx_sequencer);
  endtask

  task automatic check_word_bytes(input dsm_reg_addr_t addr,
                                  input bit [31:0] initial_value,
                                  input string name);
    bit [31:0] expected;
    bit [31:0] data;
    bit [3:0] strobe;

    expected = initial_value;
    write_reg(addr, initial_value, 4'hf, {name, "_initial"});
    expect_value(addr, expected, 32'hffff_ffff, {name, "_initial_readback"});

    for (int unsigned lane = 0; lane < 4; lane++) begin
      data = 32'd0;
      // Keep the MP_DATA bytes inside the signed Q2.14 safety limit even
      // after the high byte is selected.  0x261f is below +24576.
      data[(lane * 8) +: 8] = 8'h11 + lane * 8'h07;
      strobe = 4'b0001 << lane;
      expected[(lane * 8) +: 8] = data[(lane * 8) +: 8];
      write_reg(addr, data, strobe, $sformatf("%s_lane%0d", name, lane));
      expect_value(addr, expected, 32'hffff_ffff,
                   $sformatf("%s_lane%0d_readback", name, lane));
    end

    write_reg(addr, 32'hffff_ffff, 4'h0, {name, "_zero_strobe"});
    expect_value(addr, expected, 32'hffff_ffff, {name, "_zero_strobe_hold"});
  endtask

  task body();
    bit [31:0] expected;

    // The four programmable complex coefficient words are readable even
    // when the Poly datapath is disabled in this SKU.  Their AXI semantics
    // remain part of the public control-plane contract.
    check_word_bytes(DSM_REG_DPD_C1, 32'h1020_3040, "dpd_c1");
    check_word_bytes(DSM_REG_DPD_C3, 32'h1122_3344, "dpd_c3");
    check_word_bytes(DSM_REG_DPD_C5, 32'h5566_7788, "dpd_c5");
    check_word_bytes(DSM_REG_DPD_C7, 32'h99aa_bbcc, "dpd_c7");
    check_word_bytes(DSM_REG_OBS_GAIN, 32'h4000_0000, "obs_gain");

    // The Performance SKU prunes LUT execution, but the AXI-Lite wrapper
    // still owns the staging address/data registers.  Exercise every byte
    // guard without claiming that the disabled LUT memory is readable.  The
    // data readback is defined as zero by the disabled implementation, so it
    // cannot be used to prove the internal staging-register value.
    write_reg(DSM_REG_DPD_LUT_ADDR, 32'h0000_000d, 4'b0001, "lut_addr_lane0");
    expect_value(DSM_REG_DPD_LUT_ADDR, 32'h0000_000d, 32'h0000_000f,
                 "lut_addr_lane0_readback");
    write_reg(DSM_REG_DPD_LUT_ADDR, 32'h0000_0002, 4'b0000, "lut_addr_zero_strobe");
    expect_value(DSM_REG_DPD_LUT_ADDR, 32'h0000_000d, 32'h0000_000f,
                 "lut_addr_zero_strobe_hold");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'h1020_3040, 4'b0001, "lut_data_lane0");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'h1020_3040, 4'b0010, "lut_data_lane1");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'h1020_3040, 4'b0100, "lut_data_lane2");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'h1020_3040, 4'b1000, "lut_data_lane3");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'hffff_ffff, 4'b0000, "lut_data_zero_strobe");
    expect_value(DSM_REG_DPD_LUT_DATA, 32'h0000_0000, 32'hffff_ffff,
                 "lut_data_disabled_readback");

    // CTRL byte zero only enables the core here.  Bit one is deliberately
    // kept clear so this byte-enable test does not turn into a reset test.
    write_reg(DSM_REG_CTRL, 32'h0000_0001, 4'b0001, "ctrl_lane0_enable");
    write_reg(DSM_REG_CTRL, 32'h0000_5200, 4'b0010, "ctrl_lane1");
    write_reg(DSM_REG_CTRL, 32'h0063_0000, 4'b0100, "ctrl_lane2");
    write_reg(DSM_REG_CTRL, 32'h7400_0000, 4'b1000, "ctrl_lane3");
    expect_value(DSM_REG_CTRL, 32'h7463_5201, 32'hffff_ffff, "ctrl_byte_readback");

    check_word_bytes(DSM_REG_DPD_CTRL, 32'h0000_0100, "dpd_ctrl");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, 4'hf, "dpd_ctrl_restore_bypass");

    // MP_SELECT has two writable byte lanes.  The selected tap/order and
    // active tap count are both constrained to legal 4-tap memory-DPD values.
    write_reg(DSM_REG_MP_SELECT, 32'h0000_0009, 4'b0001, "mp_select_lane0");
    write_reg(DSM_REG_MP_SELECT, 32'h0000_0300, 4'b0010, "mp_select_lane1");
    // The RTL read mux inserts four reserved bits before order/tap, so the
    // legal values written above are observed as 0x611 in this CSR word.
    expect_value(DSM_REG_MP_SELECT, 32'h0000_0611, 32'h0000_071f,
                 "mp_select_byte_readback");

    // MP_DATA writes the inactive coefficient bank.  No commit is issued,
    // so this test cannot change the active DPD datapath.
    check_word_bytes(DSM_REG_MP_DATA, 32'h0000_0000, "mp_data");

    // OBS_CTRL exposes byte lanes 0, 1 and 2.  Start/clear pulses are kept
    // low; only persistent enable, delay and IRQ-enable fields are checked.
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_0001, 4'b0001, "obs_ctrl_lane0");
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_1a00, 4'b0010, "obs_ctrl_lane1");
    write_reg(DSM_REG_OBS_CTRL, 32'h0001_0000, 4'b0100, "obs_ctrl_lane2");
    expect_value(DSM_REG_OBS_CTRL, 32'h0001_1a01, 32'h0001_1f01,
                 "obs_ctrl_byte_readback");

    write_reg(DSM_REG_CONDITION_CTRL, 32'h0000_0001, 4'b0001, "condition_ctrl_lane0");
    write_reg(DSM_REG_CONDITION_CTRL, 32'h0000_4200, 4'b0010, "condition_ctrl_lane1");
    expect_value(DSM_REG_CONDITION_CTRL, 32'h0000_4201, 32'h0000_ff01,
                 "condition_ctrl_byte_readback");

    // Keep the normal regression completion gate meaningful.  The core is
    // enabled, DPD_CTRL has been restored to bypass, and no MP commit occurred,
    // so this legal sample must reach the frozen BP EFDSM2 RF path.
    send_tx(16'sd30000, -16'sd30000, 1'b0, "post_wstrb_tx_pos");
    send_tx(-16'sd30000, 16'sd30000, 1'b0, "post_wstrb_tx_neg");
    send_tx(16'sd28000, 16'sd28000, 1'b0, "post_wstrb_tx_mix");
    send_tx(-16'sd28000, -16'sd28000, 1'b1, "post_wstrb_tx_last");
  endtask
endclass
