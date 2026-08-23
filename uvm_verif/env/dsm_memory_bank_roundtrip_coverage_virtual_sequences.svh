// Legal two-bank memory-DPD coverage.  One commit fills bank 1, the second
// fills bank 0, and a full-amplitude 4-tap burst exercises the selected path.
class dsm_memory_bank_roundtrip_coverage_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_memory_bank_roundtrip_coverage_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_memory_bank_roundtrip_coverage_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.addr_delay_cycles = $urandom_range(0, 12);
    seq.data_delay_cycles = $urandom_range(0, 12);
    seq.ready_delay_cycles = $urandom_range(0, 16);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = $urandom_range(0, 12);
    seq.ready_delay_cycles = $urandom_range(0, 16);
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic wait_for_commit(input bit expected_bank, input string name);
    bit [31:0] status;
    bit [31:0] bank;
    for (int unsigned poll = 0; poll < 64; poll++) begin
      read_reg(DSM_REG_MP_COMMIT_STATUS, status, $sformatf("%s_status_%0d", name, poll));
      if (status[3]) begin
        `uvm_error("MP_COMMIT", $sformatf("%s was rejected: 0x%08x", name, status))
        return;
      end
      if (status[0]) begin
        read_reg(DSM_REG_MP_COMMIT, bank, {name, "_bank"});
        if (bank[0] != expected_bank)
          `uvm_error("MP_COMMIT", $sformatf("%s bank=%0b expected=%0b", name, bank[0], expected_bank))
        write_reg(DSM_REG_MP_COMMIT_STATUS, 32'h0000_0001, {name, "_ack_clear"});
        return;
      end
    end
    `uvm_error("MP_COMMIT", $sformatf("%s acknowledgement timeout", name))
  endtask

  task automatic load_identity_package(input string name);
    bit [31:0] select_data;
    bit [31:0] coeff_data;
    for (int unsigned tap = 0; tap < 4; tap++) begin
      for (int unsigned order = 0; order < 3; order++) begin
        select_data = tap | (order << 2) | (4 << 8);
        // Q2.14: C1(tap0)=1+j0; all remaining memory-polynomial terms are 0.
        coeff_data = ((tap == 0) && (order == 0)) ? 32'h0000_4000 : 32'h0000_0000;
        write_reg(DSM_REG_MP_SELECT, select_data,
                  $sformatf("%s_select_t%0d_o%0d", name, tap, order));
        write_reg(DSM_REG_MP_DATA, coeff_data,
                  $sformatf("%s_data_t%0d_o%0d", name, tap, order));
      end
    end
  endtask

  virtual function int unsigned expected_burst_items();
    return 256;
  endfunction

  virtual task send_memory_burst();
    dsm_axis_random_burst_sequence seq;
    seq = dsm_axis_random_burst_sequence::type_id::create("memory_entropy_burst");
    seq.item_count = expected_burst_items();
    seq.max_valid_gap = 9;
    seq.amplitude = 32767;
    seq.start(p_sequencer.tx_sequencer);
  endtask

  task body();
    bit [31:0] status;

    // Exercise the wrapper clamps before programming the real 4-tap package.
    write_reg(DSM_REG_MP_SELECT, 32'h0000_0000, "taps_zero_clamp");
    read_reg(DSM_REG_EFFECTIVE_STATUS, status, "taps_zero_effective");
    if (status[7:5] != 3'd1)
      `uvm_error("MP_TAPS", $sformatf("zero taps did not clamp to one: 0x%08x", status))
    write_reg(DSM_REG_MP_SELECT, 32'h0000_0700, "taps_high_clamp");
    read_reg(DSM_REG_EFFECTIVE_STATUS, status, "taps_high_effective");
    if (status[7:5] != 3'd4)
      `uvm_error("MP_TAPS", $sformatf("high taps did not clamp to four: 0x%08x", status))

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "safety_enable");

    // Reset starts with bank 0 active, so this fills inactive bank 1.
    load_identity_package("bank1");
    write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "bank1_commit");
    wait_for_commit(1'b1, "bank1");

    // Bank 1 is now active; the same legal writes target inactive bank 0.
    load_identity_package("bank0");
    write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "bank0_commit");
    wait_for_commit(1'b0, "bank0");

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0103, "memory_mode_enable");
    write_reg(DSM_REG_CTRL, 32'h0000_0001, "core_enable");
    send_memory_burst();
    read_reg(DSM_REG_IN_COUNT, status, "memory_burst_input_count");
    if (status != expected_burst_items())
      `uvm_error("MEMORY_BURST", $sformatf(
        "Accepted input count=%0d expected=%0d", status, expected_burst_items()))
  endtask
endclass


// Keep tvalid asserted after the first beat.  This is a legal AXI-Stream
// source behavior and drives the enabled memory-DPD pipeline into the
// in_ready/out_ready boundary without forcing internal DUT state.
class dsm_memory_pipe_stall_coverage_virtual_sequence extends
    dsm_memory_bank_roundtrip_coverage_virtual_sequence;
  `uvm_object_utils(dsm_memory_pipe_stall_coverage_virtual_sequence)

  function new(string name = "dsm_memory_pipe_stall_coverage_virtual_sequence");
    super.new(name);
  endfunction

  virtual function int unsigned expected_burst_items();
    return 2048;
  endfunction

  virtual task send_memory_burst();
    dsm_axis_random_burst_sequence seq;
    seq = dsm_axis_random_burst_sequence::type_id::create("memory_pipe_stall_burst");
    seq.item_count = expected_burst_items();
    seq.max_valid_gap = 0;
    seq.first_valid_gap = 0;
    seq.amplitude = 32767;
    seq.start(p_sequencer.tx_sequencer);
  endtask
endclass
