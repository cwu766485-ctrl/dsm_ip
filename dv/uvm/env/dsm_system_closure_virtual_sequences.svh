// End-to-end system closure scenario for the frozen Performance SKU.  It
// composes already signed-off directed flows, then adds a long randomized TX
// burst so control, observer, monitor and memory-DPD safety states are seen
// in one VCS/UVM run.
class dsm_system_closure_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_system_closure_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  localparam int unsigned LONG_TX_ITEMS = 4096;

  function new(string name = "dsm_system_closure_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.addr_delay_cycles = $urandom_range(0, 16);
    seq.data_delay_cycles = $urandom_range(0, 16);
    seq.ready_delay_cycles = $urandom_range(0, 24);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = $urandom_range(0, 16);
    seq.ready_delay_cycles = $urandom_range(0, 24);
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    dsm_control_stress_virtual_sequence control_seq;
    dsm_memory_dpd_virtual_sequence memory_seq;
    dsm_memory_dpd_safety_virtual_sequence safety_seq;
    dsm_axis_control_burst_sequence long_tx;
    bit [31:0] value;
    bit [31:0] bank_before;
    bit [31:0] epoch_before;

    // Reset while streaming, clear counters, and complete a clean observer
    // window.  This is also the source of the reset/observer coverage bins.
    control_seq = dsm_control_stress_virtual_sequence::type_id::create("control_seq");
    control_seq.start(p_sequencer);

    // Write an inactive memory bank, wait for an atomic commit acknowledgement
    // and select the only non-bypass DPD mode compiled into the Performance SKU.
    memory_seq = dsm_memory_dpd_virtual_sequence::type_id::create("memory_seq");
    memory_seq.randomize_axi_timing = 1'b1;
    memory_seq.start(p_sequencer);
    read_reg(DSM_REG_MP_COMMIT, bank_before, "active_bank_after_good_commit");
    read_reg(DSM_REG_MP_COMMIT_STATUS, epoch_before, "epoch_after_good_commit");

    // Long source burst has randomized gaps, a terminal TLAST and one TUSER
    // error.  Its high amplitude intentionally exercises power/peak/clip
    // monitors rather than treating those registers as physical RF metrics.
    long_tx = dsm_axis_control_burst_sequence::type_id::create("long_random_tx");
    long_tx.item_count = LONG_TX_ITEMS;
    long_tx.max_valid_gap = 64;
    long_tx.amplitude = 24500;
    long_tx.user_error_index = LONG_TX_ITEMS / 2;
    long_tx.last_index = LONG_TX_ITEMS - 1;
    long_tx.start(p_sequencer.tx_sequencer);
    wait_cycles(32768);

    read_reg(DSM_REG_DPD_COUNT, value, "dpd_count_after_long_tx");
    if (value == 0)
      `uvm_error("SYSTEM_MON", "DPD sample counter did not advance")
    read_reg(DSM_REG_MON_IN_POWER, value, "mon_input_power_after_long_tx");
    if (value == 0)
      `uvm_error("SYSTEM_MON", "Input-power proxy did not advance")
    read_reg(DSM_REG_MON_OUT_POWER, value, "mon_output_power_after_long_tx");
    if (value == 0)
      `uvm_error("SYSTEM_MON", "Output-power proxy did not advance")
    read_reg(DSM_REG_MON_CLIP_COUNT, value, "mon_clip_after_long_tx");
    // Clip count is a diagnostic counter.  Whether this random stream crosses
    // the configured threshold is SKU-dependent, so only verify that the
    // register is readable here; threshold-hit coverage belongs to its block
    // test.
    read_reg(DSM_REG_ERROR, value, "sticky_tuser_after_long_tx");
    if (!value[1])
      `uvm_error("SYSTEM_STICKY", "TUSER did not set ERROR.bit1")

    // Invalid coefficient package must not change bank or epoch.  It must set
    // the sticky reject indicator, which software can later clear explicitly.
    safety_seq = dsm_memory_dpd_safety_virtual_sequence::type_id::create("safety_seq");
    safety_seq.start(p_sequencer);
    read_reg(DSM_REG_MP_COMMIT, value, "active_bank_after_reject");
    if (value[0] != bank_before[0])
      `uvm_error("SYSTEM_BANK", "Rejected commit changed the active bank")
    read_reg(DSM_REG_MP_COMMIT_STATUS, value, "epoch_after_reject");
    if (value[15:8] != epoch_before[15:8])
      `uvm_error("SYSTEM_BANK", "Rejected commit changed the commit epoch")
    read_reg(DSM_REG_ERROR, value, "sticky_errors_after_reject");
    if ((value & 32'h0000_000a) != 32'h0000_000a)
      `uvm_error("SYSTEM_STICKY", $sformatf("Expected TUSER+reject sticky errors, got 0x%08x", value))

    // Clear the DPD-side latches first.  ERROR is write-one-to-clear, so a
    // zero write would intentionally leave all sticky bits asserted.
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0300, "clear_dpd_safety_latches");
    wait_cycles(8);
    write_reg(DSM_REG_CTRL, 32'h0000_0005, "clear_system_counters");
    write_reg(DSM_REG_ERROR, 32'hffff_ffff, "clear_system_errors");
    wait_cycles(8);
    read_reg(DSM_REG_IN_COUNT, value, "input_count_after_clear");
    if (value != 0)
      `uvm_error("SYSTEM_CLEAR", "Input counter did not clear")
    read_reg(DSM_REG_MON_IN_POWER, value, "mon_input_power_after_clear");
    if (value != 0)
      `uvm_error("SYSTEM_CLEAR", "Monitor input-power proxy did not clear")
    read_reg(DSM_REG_ERROR, value, "error_after_clear");
    if (value != 0)
      `uvm_error("SYSTEM_CLEAR", "Sticky error register did not clear")
  endtask
endclass
