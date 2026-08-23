// Directed system-level scenarios for reachable frozen-SKU control corners.
// They use only legal software transactions and verify the defined hardware
// behavior rather than forcing unsupported state combinations.

class dsm_commit_during_stream_virtual_sequence extends dsm_memory_dpd_virtual_sequence;
  `uvm_object_utils(dsm_commit_during_stream_virtual_sequence)

  localparam int unsigned TX_ITEMS = 192;

  function new(string name = "dsm_commit_during_stream_virtual_sequence");
    super.new(name);
  endfunction

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
    dsm_axis_control_burst_sequence tx_seq;
    bit [31:0] value;

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "safety_enable");
    load_memory_coefficients();
    // Select the implemented memory-DPD path before starting TX.  The bank
    // swap below must hold the stream at a safe boundary without losing it.
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0103, "memory_mode_enable");
    write_reg(DSM_REG_CTRL, 32'h0000_0001, "core_enable");

    tx_seq = dsm_axis_control_burst_sequence::type_id::create("commit_live_tx");
    tx_seq.item_count = TX_ITEMS;
    tx_seq.max_valid_gap = 0;
    tx_seq.amplitude = 12000;
    tx_seq.last_index = TX_ITEMS - 1;

    fork
      tx_seq.start(p_sequencer.tx_sequencer);
      begin
        wait_tx_accepts(8);
        write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "commit_while_streaming");
      end
    join

    // A commit requested during a continuous stream is intentionally deferred
    // until the stream stops and the DPD/DSM pipeline drains.  Polling during
    // the burst is a testbench error: there is no safe boundary yet.
    wait_for_commit_ack(4096);
    wait_cycles(64);

    read_reg(DSM_REG_IN_COUNT, value, "input_count_after_live_commit");
    if (value != TX_ITEMS)
      `uvm_error("COMMIT_STREAM", $sformatf(
        "Live commit lost or duplicated TX data: got=%0d expected=%0d", value, TX_ITEMS))
    read_reg(DSM_REG_MP_COMMIT_STATUS, value, "live_commit_status");
    if (!value[0] || value[3])
      `uvm_error("COMMIT_STREAM", $sformatf(
        "Live commit did not complete cleanly: status=0x%08x", value))
  endtask
endclass


class dsm_commit_reset_interlock_virtual_sequence extends dsm_memory_dpd_virtual_sequence;
  `uvm_object_utils(dsm_commit_reset_interlock_virtual_sequence)

  localparam int unsigned TX_ITEMS = 192;

  function new(string name = "dsm_commit_reset_interlock_virtual_sequence");
    super.new(name);
  endfunction

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
    dsm_axis_control_burst_sequence tx_seq;
    dsm_axis_single_item_sequence recovery_tx;
    bit [31:0] value;

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "safety_enable");
    load_memory_coefficients();
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0103, "memory_mode_enable");
    write_reg(DSM_REG_CTRL, 32'h0000_0001, "core_enable");

    tx_seq = dsm_axis_control_burst_sequence::type_id::create("commit_reset_live_tx");
    tx_seq.item_count = TX_ITEMS;
    tx_seq.max_valid_gap = 0;
    tx_seq.amplitude = 10000;
    tx_seq.last_index = TX_ITEMS - 1;

    fork
      tx_seq.start(p_sequencer.tx_sequencer);
      begin
        wait_tx_accepts(8);
        write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "commit_before_soft_reset");
        // The single-entry AXI-Lite slave serializes this request after the
        // commit write response.  The test validates the specified reset
        // cancellation/recovery contract, not an impossible simultaneous
        // double-write condition.
        write_reg(DSM_REG_CTRL, 32'h0000_0003, "soft_reset_after_commit_request");
      end
    join
    wait_cycles(64);

    read_reg(DSM_REG_RESET_COUNT, value, "reset_count_after_commit_interlock");
    if (value != 32'd1)
      `uvm_error("COMMIT_RESET", $sformatf("Expected one software reset, got %0d", value))
    read_reg(DSM_REG_MP_COMMIT_STATUS, value, "commit_status_after_soft_reset");
    if (value[3:0] != 4'd0)
      `uvm_error("COMMIT_RESET", $sformatf(
        "Soft reset did not clear wrapper commit state: status=0x%08x", value))
    read_reg(DSM_REG_MP_COMMIT, value, "active_bank_after_soft_reset");
    if (value[0] != 1'b0)
      `uvm_error("COMMIT_RESET", "Soft reset did not restore memory-DPD bank zero")

    recovery_tx = dsm_axis_single_item_sequence::type_id::create("post_reset_recovery_tx");
    recovery_tx.i_sample = 16'sd1536;
    recovery_tx.q_sample = -16'sd768;
    recovery_tx.last = 1'b1;
    recovery_tx.user_error = 1'b0;
    recovery_tx.valid_gap_cycles = 0;
    recovery_tx.start(p_sequencer.tx_sequencer);
    wait_cycles(4096);
    read_reg(DSM_REG_FRONT_COUNT, value, "frontend_count_after_reset_recovery");
    if (value == 0)
      `uvm_error("COMMIT_RESET", "TX datapath did not recover after commit/reset interlock")
  endtask
endclass


class dsm_axi_lite_channel_backpressure_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_axi_lite_channel_backpressure_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_axi_lite_channel_backpressure_virtual_sequence");
    super.new(name);
  endfunction

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task body();
    dsm_axi_lite_write_sequence first_seq;
    dsm_axi_lite_write_sequence second_seq;
    bit [31:0] c1;
    bit [31:0] c3;

    // First transaction proves W may arrive after AW while B remains stalled.
    first_seq = dsm_axi_lite_write_sequence::type_id::create("write_aw_first_b_stalled");
    first_seq.addr = DSM_REG_DPD_C1;
    first_seq.data = 32'h1122_3344;
    first_seq.wstrb = 4'hf;
    first_seq.addr_delay_cycles = 0;
    first_seq.data_delay_cycles = 7;
    first_seq.ready_delay_cycles = 16;
    first_seq.start(p_sequencer.axi_sequencer);
    if (first_seq.resp != 2'b00)
      `uvm_error("AXIL_BACKPRESSURE", $sformatf(
        "Unexpected AW-first response %0b", first_seq.resp))

    // Second transaction proves AW may arrive after W with an independent
    // B-channel delay.  The RTL contract is one outstanding write, so these
    // are deliberately serialized rather than driving an unsupported burst.
    second_seq = dsm_axi_lite_write_sequence::type_id::create("write_w_first_b_stalled");
    second_seq.addr = DSM_REG_DPD_C3;
    second_seq.data = 32'h5566_7788;
    second_seq.wstrb = 4'hf;
    second_seq.addr_delay_cycles = 7;
    second_seq.data_delay_cycles = 0;
    second_seq.ready_delay_cycles = 8;
    second_seq.start(p_sequencer.axi_sequencer);
    if (second_seq.resp != 2'b00)
      `uvm_error("AXIL_BACKPRESSURE", $sformatf(
        "Unexpected W-first response %0b", second_seq.resp))

    read_reg(DSM_REG_DPD_C1, c1, "readback_stalled_c1");
    read_reg(DSM_REG_DPD_C3, c3, "readback_stalled_c3");
    if (c1 != 32'h1122_3344 || c3 != 32'h5566_7788)
      `uvm_error("AXIL_BACKPRESSURE", $sformatf(
        "Channel-stalled writes corrupted payload: c1=0x%08x c3=0x%08x", c1, c3))
  endtask
endclass
