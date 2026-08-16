// Directed register-corner coverage for the frozen Performance SKU.  This
// sequence exercises control-plane state transitions that randomized traffic
// is unlikely to hit deterministically: sticky/W1C behavior, observer
// snapshot lifetime, condition metadata readback, and memory-DPD commit status.
class dsm_register_corner_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_register_corner_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_register_corner_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name, input bit [3:0] wstrb = 4'hf);
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

  task automatic expect_mask(input dsm_reg_addr_t addr, input bit [31:0] expected,
                             input bit [31:0] mask, input string name);
    bit [31:0] value;
    read_reg(addr, value, name);
    if ((value & mask) != (expected & mask))
      `uvm_error("REGISTER_CORNER", $sformatf(
        "%s got=0x%08x expected=0x%08x mask=0x%08x", name, value, expected, mask))
  endtask

  task automatic wait_for_mask(input dsm_reg_addr_t addr, input bit [31:0] expected,
                               input bit [31:0] mask, input string name);
    bit [31:0] value;
    for (int unsigned poll = 0; poll < 8; poll++) begin
      read_reg(addr, value, $sformatf("%s_poll_%0d", name, poll));
      if ((value & mask) == (expected & mask))
        return;
      wait_cycles(2);
    end
    `uvm_error("REGISTER_CORNER", $sformatf(
      "%s timed out waiting for expected=0x%08x mask=0x%08x", name, expected, mask))
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    dsm_axis_single_item_sequence disabled_tx;
    dsm_memory_dpd_virtual_sequence good_package;
    dsm_memory_dpd_safety_virtual_sequence bad_package;
    bit [31:0] status;

    // A compliant source may hold TVALID while the core is disabled.  The IP
    // must retain backpressure, set ERROR.bit0, and implement W1C correctly.
    disabled_tx = dsm_axis_single_item_sequence::type_id::create("disabled_tx");
    disabled_tx.i_sample = 16'sd768;
    disabled_tx.q_sample = -16'sd512;
    disabled_tx.last = 1'b1;
    disabled_tx.user_error = 1'b0;
    disabled_tx.valid_gap_cycles = 0;
    fork
      disabled_tx.start(p_sequencer.tx_sequencer);
      begin
        wait_for_mask(DSM_REG_ERROR, 32'h0000_0001, 32'h0000_0001,
                      "disabled_stream_sets_sticky");
        write_reg(DSM_REG_CTRL, 32'h0000_0001, "enable_after_disabled_stall");
      end
    join

    // The source has handshaken and stopped, so W1C behavior is checked only
    // after the error source is no longer asserted by hardware.
    write_reg(DSM_REG_ERROR, 32'h0000_0000, "w1c_zero_preserves_disabled");
    expect_mask(DSM_REG_ERROR, 32'h0000_0001, 32'h0000_0001,
                "w1c_zero_preserved_disabled");
    write_reg(DSM_REG_ERROR, 32'h0000_0001, "w1c_one_clears_disabled");
    expect_mask(DSM_REG_ERROR, 32'h0000_0000, 32'h0000_0001,
                "w1c_one_cleared_disabled");

    // These fields are calibration metadata.  They have no direct fast-path
    // effect, but PS software must be able to write and read them losslessly.
    write_reg(DSM_REG_CONDITION_CTRL, 32'h0000_3701, "condition_ctrl");
    write_reg(DSM_REG_CONDITION_QAM, 32'h0000_0100, "condition_qam");
    write_reg(DSM_REG_CONDITION_BW, 32'd20000, "condition_bandwidth");
    write_reg(DSM_REG_CONDITION_BACKOFF, 32'd750000, "condition_backoff");
    write_reg(DSM_REG_CONDITION_ENV, 32'h1a2b_0c80, "condition_environment");
    write_reg(DSM_REG_CONDITION_MONITOR, 32'h00aa_5501, "condition_monitor");
    expect_mask(DSM_REG_CONDITION_CTRL, 32'h0000_3701, 32'h0000_ff01,
                "condition_ctrl_readback");
    expect_mask(DSM_REG_CONDITION_QAM, 32'h0000_0100, 32'h0000_ffff,
                "condition_qam_readback");
    expect_mask(DSM_REG_CONDITION_BW, 32'd20000, 32'hffff_ffff,
                "condition_bandwidth_readback");
    expect_mask(DSM_REG_CONDITION_BACKOFF, 32'd750000, 32'hffff_ffff,
                "condition_backoff_readback");
    expect_mask(DSM_REG_CONDITION_ENV, 32'h1a2b_0c80, 32'hffff_ffff,
                "condition_environment_readback");
    expect_mask(DSM_REG_CONDITION_MONITOR, 32'h00aa_5501, 32'hffff_ffff,
                "condition_monitor_readback");

    // AXI-Lite byte enables must preserve bytes whose strobes are deasserted.
    // This covers both the active and inactive sides of the RTL WSTRB guards.
    write_reg(DSM_REG_DPD_C1, 32'h1122_3344, "dpd_c1_full_write");
    write_reg(DSM_REG_DPD_C1, 32'haabb_ccdd, "dpd_c1_low_half_write", 4'b0011);
    expect_mask(DSM_REG_DPD_C1, 32'h1122_ccdd, 32'hffff_ffff,
                "dpd_c1_partial_write_preserves_high_half");
    write_reg(DSM_REG_DPD_C1, 32'h5566_7788, "dpd_c1_high_half_write", 4'b1100);
    expect_mask(DSM_REG_DPD_C1, 32'h5566_ccdd, 32'hffff_ffff,
                "dpd_c1_partial_write_preserves_low_half");
    write_reg(DSM_REG_DPD_C1, 32'hffff_ffff, "dpd_c1_zero_strobe", 4'b0000);
    expect_mask(DSM_REG_DPD_C1, 32'h5566_ccdd, 32'hffff_ffff,
                "dpd_c1_zero_strobe_preserves_value");

    // The frozen SKU deliberately falls back when Poly/LUT execution is
    // requested, but its programmable register interface remains writable.
    write_reg(DSM_REG_DPD_C3, 32'h0102_0304, "disabled_poly_c3_write");
    write_reg(DSM_REG_DPD_C5, 32'h0506_0708, "disabled_poly_c5_write");
    write_reg(DSM_REG_DPD_C7, 32'h090a_0b0c, "disabled_poly_c7_write");
    write_reg(DSM_REG_DPD_LUT_ADDR, 32'h0000_0003, "disabled_lut_addr_write");
    write_reg(DSM_REG_DPD_LUT_DATA, 32'h0d0e_0f10, "disabled_lut_data_write");
    write_reg(DSM_REG_DPD_LUT_COMMIT, 32'h0000_0001, "disabled_lut_commit");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0101, "disabled_poly_request");
    // [1:0] is the software request, [3:2] is the executed mode, and bit[9]
    // marks a compile-time-disabled request that fell back to bypass.
    expect_mask(DSM_REG_EFFECTIVE_STATUS, 32'h0000_0200, 32'h0000_020c,
                "disabled_poly_falls_back_to_bypass");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0102, "disabled_lut_request");
    expect_mask(DSM_REG_EFFECTIVE_STATUS, 32'h0000_0200, 32'h0000_020c,
                "disabled_lut_falls_back_to_bypass");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "restore_bypass_after_disabled_modes");

    // Snapshot is independent of measurement value.  Verify its validity bit
    // and explicit clear behavior before a feedback window is opened.
    write_reg(DSM_REG_OBS_SNAPSHOT, 32'h0000_0001, "observer_snapshot_take");
    expect_mask(DSM_REG_OBS_SNAPSHOT, 32'h0000_0001, 32'h0000_0001,
                "observer_snapshot_valid");
    read_reg(DSM_REG_OBS_SNAPSHOT_ERROR_LO, status, "observer_snapshot_lo_read");
    read_reg(DSM_REG_OBS_SNAPSHOT_ERROR_HI, status, "observer_snapshot_hi_read");
    write_reg(DSM_REG_OBS_SNAPSHOT, 32'h0000_0002, "observer_snapshot_clear");
    expect_mask(DSM_REG_OBS_SNAPSHOT, 32'h0000_0000, 32'h0000_0001,
                "observer_snapshot_cleared");
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_0003, "observer_start");
    wait_cycles(4);
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_0005, "observer_clear");
    expect_mask(DSM_REG_OBS_STATUS, 32'h0000_0000, 32'h0000_0006,
                "observer_clear_returns_idle");

    // An unsafe package is a legal software request whose hardware result is
    // rejection.  FAILED is W1C and the active bank must not change.
    // Run it with the data path quiescent, matching the transaction contract.
    write_reg(DSM_REG_CTRL, 32'h0000_0000, "disable_before_unsafe_package");
    wait_cycles(4);
    bad_package = dsm_memory_dpd_safety_virtual_sequence::type_id::create("bad_package");
    bad_package.start(p_sequencer);
    read_reg(DSM_REG_MP_COMMIT_STATUS, status, "commit_failed_before_w1c");
    if (!status[3])
      `uvm_error("REGISTER_CORNER", "Unsafe memory-DPD commit did not set FAILED")
    write_reg(DSM_REG_MP_COMMIT_STATUS, 32'h0000_0008, "commit_failed_w1c_clear");
    expect_mask(DSM_REG_MP_COMMIT_STATUS, 32'h0000_0000, 32'h0000_0008,
                "commit_failed_w1c_cleared");
    // A rejected inactive-bank update is intentionally retained by the
    // frontend until software explicitly abandons it through safety_clear.
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0200, "discard_rejected_shadow_bank");
    write_reg(DSM_REG_ERROR, 32'h0000_0008, "clear_commit_rejected_error");
    expect_mask(DSM_REG_ERROR, 32'h0000_0000, 32'h0000_0008,
                "commit_rejected_error_cleared");

    // Reuse the validated system package format, then verify ACK is W1C and
    // epoch remains monotonic.  This is a control-plane test, so its test
    // class intentionally disables the RF bit-true scoreboard.
    good_package = dsm_memory_dpd_virtual_sequence::type_id::create("good_package");
    good_package.randomize_axi_timing = 1'b1;
    good_package.start(p_sequencer);
    read_reg(DSM_REG_MP_COMMIT_STATUS, status, "commit_ack_before_w1c");
    if (!status[0])
      `uvm_error("REGISTER_CORNER", "Successful memory-DPD commit did not set ACK")
    write_reg(DSM_REG_MP_COMMIT_STATUS, 32'h0000_0001, "commit_ack_w1c_clear");
    expect_mask(DSM_REG_MP_COMMIT_STATUS, 32'h0000_0000, 32'h0000_0001,
                "commit_ack_w1c_cleared");
  endtask
endclass
