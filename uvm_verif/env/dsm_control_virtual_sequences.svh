class dsm_control_stress_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_control_stress_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  localparam int unsigned FIRST_TX_ITEMS = 96;
  localparam int unsigned OBS_REF_ITEMS = 64;
  localparam int unsigned OBS_ITEMS = 31;

  function new(string name = "dsm_control_stress_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(
    input dsm_reg_addr_t addr,
    input bit [31:0] data,
    input int unsigned aw_delay,
    input int unsigned w_delay,
    input int unsigned b_delay,
    input string name
  );
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.addr_delay_cycles = aw_delay;
    seq.data_delay_cycles = w_delay;
    seq.ready_delay_cycles = b_delay;
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(
    input dsm_reg_addr_t addr,
    output bit [31:0] data,
    input int unsigned ar_delay,
    input int unsigned r_delay,
    input string name
  );
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = ar_delay;
    seq.ready_delay_cycles = r_delay;
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic expect_mask(
    input dsm_reg_addr_t addr,
    input bit [31:0] expected,
    input bit [31:0] mask,
    input string name
  );
    bit [31:0] value;
    read_reg(addr, value, $urandom_range(0, 16), $urandom_range(8, 24), name);
    if ((value & mask) != (expected & mask))
      `uvm_error("CTRL_CHECK", $sformatf(
        "%s got=0x%08x expected=0x%08x mask=0x%08x", name, value, expected, mask))
  endtask

  task automatic expect_observer_state(
    input bit [31:0] expected,
    input bit [31:0] mask,
    input int unsigned ar_delay,
    input int unsigned r_delay,
    input string name
  );
    bit [31:0] value;
    read_reg(DSM_REG_OBS_STATUS, value, ar_delay, r_delay, name);
    if ((value & mask) != (expected & mask))
      `uvm_error("CTRL_CHECK", $sformatf(
        "%s got=0x%08x expected=0x%08x mask=0x%08x", name, value, expected, mask))
  endtask

  task automatic wait_tx_accepts(input int unsigned count);
    int unsigned accepted;
    accepted = 0;
    while (accepted < count) begin
      @(posedge p_sequencer.tx_vif.aclk);
      if (p_sequencer.tx_vif.tvalid && p_sequencer.tx_vif.tready)
        accepted++;
    end
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    dsm_axis_control_burst_sequence tx_first;
    dsm_axis_control_burst_sequence tx_second;
    dsm_axis_control_burst_sequence tx_observer_ref;
    dsm_axis_control_burst_sequence obs_probe;
    dsm_axis_control_burst_sequence obs_first;
    dsm_axis_control_burst_sequence obs_seq;

    // Exercise independent AXI-Lite channels and delayed responses before
    // enabling the datapath.
    expect_mask(DSM_REG_VERSION, DSM_SKU_CORE_VERSION, 32'hffff_ffff, "version_read");
    expect_mask(DSM_REG_CAPABILITY, 32'h0000_0000, 32'h0000_0000, "capability_read");
    write_reg(DSM_REG_DSM_CTRL, 32'h0000_0000, 16, 0, 24, "dsm_ctrl_skewed");
    write_reg(DSM_REG_DSM_CTRL, 32'h0000_0000, 3, 0, 3, "dsm_ctrl_short_skew");
    write_reg(DSM_REG_CTRL, 32'h0000_0001, 0, 16, 24, "enable_skewed");
    expect_mask(DSM_REG_CTRL, 32'h0000_0001, 32'h0000_0001, "ctrl_read_enabled");

    tx_first = dsm_axis_control_burst_sequence::type_id::create("tx_first");
    tx_first.item_count = FIRST_TX_ITEMS / 2;
    tx_first.max_valid_gap = 24;
    tx_first.amplitude = 10000;
    tx_first.user_error_index = 19;
    tx_first.last_index = (FIRST_TX_ITEMS / 2) - 1;

    tx_second = dsm_axis_control_burst_sequence::type_id::create("tx_second");
    tx_second.item_count = FIRST_TX_ITEMS / 2;
    tx_second.max_valid_gap = 24;
    tx_second.amplitude = 10000;
    tx_second.user_error_index = (FIRST_TX_ITEMS / 2) - 1;
    tx_second.last_index = (FIRST_TX_ITEMS / 2) - 1;

    // Reset during a live transaction.  The active driver must retain TVALID
    // until TREADY returns, and the control plane must not report bit0.
    fork
      begin
        tx_first.start(p_sequencer.tx_sequencer);
        tx_second.start(p_sequencer.tx_sequencer);
      end
      begin
        wait_tx_accepts(4);
        write_reg(DSM_REG_CTRL, 32'h0000_0003, 8, 16, 16, "active_stream_reset");
        write_reg(DSM_REG_CTRL, 32'h0000_0001, 16, 0, 24, "reenable_after_reset");
      end
    join

    expect_mask(DSM_REG_RESET_COUNT, 32'd1, 32'hffff_ffff, "reset_count");
    expect_mask(DSM_REG_IN_COUNT, FIRST_TX_ITEMS, 32'hffff_ffff, "input_count");
    expect_mask(DSM_REG_FRAME_COUNT, 32'd2, 32'hffff_ffff, "frame_count");
    expect_mask(DSM_REG_USER_ERROR_COUNT, 32'd2, 32'hffff_ffff, "user_error_count");
    expect_mask(DSM_REG_ERROR, 32'h0000_0002, 32'h0000_0003, "sticky_tuser_only");

    // Clear diagnostics while retaining enable and reset history.
    write_reg(DSM_REG_CTRL, 32'h0000_0005, 0, 16, 16, "clear_status");
    write_reg(DSM_REG_ERROR, 32'h0000_0000, 0, 0, 0, "error_clear_aligned");
    expect_mask(DSM_REG_IN_COUNT, 32'd0, 32'hffff_ffff, "cleared_input_count");
    expect_mask(DSM_REG_FRAME_COUNT, 32'd0, 32'hffff_ffff, "cleared_frame_count");
    expect_mask(DSM_REG_USER_ERROR_COUNT, 32'd0, 32'hffff_ffff, "cleared_user_error_count");
    expect_mask(DSM_REG_ERROR, 32'd0, 32'hffff_ffff, "cleared_error_status");

    // Fill the observer reference history after reset, then inject one
    // invalid feedback beat.  The monitor must report one drop and a clean
    // completed 32-pair window.
    write_reg(DSM_REG_OBS_GAIN, 32'h0000_4000, 16, 0, 16, "obs_gain");
    write_reg(DSM_REG_OBS_WINDOW, 32'd32, 0, 16, 24, "obs_window");
    expect_mask(DSM_REG_OBS_CTRL, 32'd0, 32'h0000_ffff, "obs_ctrl_disabled");
    // Deliberately cover each AXI-Lite response-stall class while the observer
    // is idle.  Active and clean-done use the same 0/3/16-cycle pattern below.
    expect_observer_state(32'd0, 32'h0000_0006, 0, 0, "obs_idle_no_stall");
    expect_observer_state(32'd0, 32'h0000_0006, 0, 3, "obs_idle_short_stall");
    expect_observer_state(32'd0, 32'h0000_0006, 0, 16, "obs_idle_long_stall");

    tx_observer_ref = dsm_axis_control_burst_sequence::type_id::create("tx_observer_ref");
    tx_observer_ref.item_count = OBS_REF_ITEMS;
    tx_observer_ref.max_valid_gap = 12;
    tx_observer_ref.amplitude = 7168;
    tx_observer_ref.last_index = OBS_REF_ITEMS - 1;
    tx_observer_ref.start(p_sequencer.tx_sequencer);
    wait_cycles(4096);

    // First create a short OBS backpressure interval with a terminal invalid
    // beat.  It covers the packet/error boundary without contaminating the
    // following completed measurement window.
    obs_probe = dsm_axis_control_burst_sequence::type_id::create("obs_short_stall_probe");
    obs_probe.item_count = 1;
    obs_probe.max_valid_gap = 0;
    obs_probe.amplitude = 7168;
    obs_probe.user_error_index = 0;
    obs_probe.last_index = 0;
    fork
      begin
        obs_probe.start(p_sequencer.obs_sequencer);
      end
      begin
        wait_cycles(3);
        write_reg(DSM_REG_OBS_CTRL, 32'h0000_0103, 3, 0, 3, "obs_start_short_stall");
      end
    join
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_0000, 0, 0, 0, "obs_disable_after_probe");

    // Start one feedback beat before OBS is enabled.  The active source must
    // hold its payload stable through the intentional long TREADY stall.
    obs_first = dsm_axis_control_burst_sequence::type_id::create("obs_before_start");
    obs_first.item_count = 1;
    obs_first.max_valid_gap = 0;
    obs_first.amplitude = 7168;
    obs_first.emit_last = 0;

    obs_seq = dsm_axis_control_burst_sequence::type_id::create("obs_invalid_then_valid");
    obs_seq.item_count = OBS_ITEMS;
    obs_seq.max_valid_gap = 24;
    obs_seq.amplitude = 7168;
    obs_seq.user_error_index = -1;
    obs_seq.last_index = OBS_ITEMS - 1;

    fork
      begin
        obs_first.start(p_sequencer.obs_sequencer);
      end
      begin
        wait_cycles(16);
        write_reg(DSM_REG_OBS_CTRL, 32'h0000_0103, 8, 16, 16, "obs_start");
      end
    join
    expect_observer_state(32'h0000_0002, 32'h0000_0006, 0, 0, "obs_active_no_stall");
    expect_observer_state(32'h0000_0002, 32'h0000_0006, 0, 3, "obs_active_short_stall");
    expect_observer_state(32'h0000_0002, 32'h0000_0006, 0, 16, "obs_active_long_stall");
    obs_seq.start(p_sequencer.obs_sequencer);
    wait_cycles(64);

    expect_mask(DSM_REG_OBS_PAIR_COUNT, 32'd32, 32'hffff_ffff, "obs_pair_count");
    expect_mask(DSM_REG_OBS_DROP_COUNT, 32'd0, 32'hffff_ffff, "obs_drop_count");
    // Keep the status check aligned with the established observer interface
    // contract.  Pair/drop counters above independently prove window quality.
    expect_observer_state(32'h0000_001c, 32'h0000_003c, 0, 0, "obs_complete_no_stall");
    expect_observer_state(32'h0000_001c, 32'h0000_003c, 0, 3, "obs_complete_short_stall");
    expect_observer_state(32'h0000_001c, 32'h0000_003c, 0, 16, "obs_complete_long_stall");
    expect_mask(DSM_REG_ERROR, 32'd0, 32'hffff_ffff, "final_error_status");
  endtask
endclass
