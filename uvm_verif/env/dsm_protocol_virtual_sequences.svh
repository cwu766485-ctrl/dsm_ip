class dsm_protocol_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_protocol_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_protocol_virtual_sequence");
    super.new(name);
  endfunction

  task automatic random_read(
    input dsm_reg_addr_t addr,
    output bit [31:0] value
  );
    dsm_axi_lite_read_sequence rd_seq;
    rd_seq = dsm_axi_lite_read_sequence::type_id::create("rd_seq");
    rd_seq.addr = addr;
    rd_seq.addr_delay_cycles = $urandom_range(0, 5);
    rd_seq.ready_delay_cycles = $urandom_range(0, 8);
    rd_seq.start(p_sequencer.axi_sequencer);
    value = rd_seq.rdata;
    if (rd_seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("read 0x%03x returned %0b", addr, rd_seq.resp))
  endtask

  task automatic random_write(
    input dsm_reg_addr_t addr,
    input bit [31:0] data
  );
    dsm_axi_lite_write_sequence wr_seq;
    wr_seq = dsm_axi_lite_write_sequence::type_id::create("wr_seq");
    wr_seq.addr = addr;
    wr_seq.data = data;
    wr_seq.addr_delay_cycles = $urandom_range(0, 6);
    wr_seq.data_delay_cycles = $urandom_range(0, 6);
    wr_seq.ready_delay_cycles = $urandom_range(1, 8);
    wr_seq.start(p_sequencer.axi_sequencer);
    if (wr_seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("write 0x%03x returned %0b", addr, wr_seq.resp))
  endtask

  task body();
    dsm_axis_random_burst_sequence tx_seq;
    dsm_axis_random_burst_sequence obs_seq;
    bit [31:0] rd;

    random_read(DSM_REG_VERSION, rd);
    random_read(DSM_REG_STATUS, rd);
    random_read(DSM_REG_CAPABILITY, rd);

    random_write(DSM_REG_CTRL, 32'h0000_0001);
    random_write(DSM_REG_OBS_GAIN, 32'h0000_4000);
    random_write(DSM_REG_OBS_WINDOW, 32'd64);
    // bit0 enables, bit1 starts, and bits[12:8] select one reference sample
    // of delay.  The nonzero delay allows an independently paced feedback
    // stream to pair against the captured reference history.
    random_write(DSM_REG_OBS_CTRL, 32'h0000_0103);

    tx_seq = dsm_axis_random_burst_sequence::type_id::create("tx_burst");
    tx_seq.item_count = 64;
    tx_seq.max_valid_gap = 3;
    tx_seq.amplitude = 8192;

    obs_seq = dsm_axis_random_burst_sequence::type_id::create("obs_burst");
    obs_seq.item_count = 64;
    obs_seq.max_valid_gap = 5;
    obs_seq.first_valid_gap = 64;
    obs_seq.amplitude = 7168;

    fork
      tx_seq.start(p_sequencer.tx_sequencer);
      obs_seq.start(p_sequencer.obs_sequencer);
    join

    random_read(DSM_REG_IN_COUNT, rd);
    random_read(DSM_REG_STALL_COUNT, rd);
    random_read(DSM_REG_ERROR, rd);
    random_read(DSM_REG_OBS_STATUS, rd);
    if ((rd & 32'h0000_003c) != 32'h0000_001c)
      `uvm_error("OBS_STATUS", $sformatf("unexpected observer status 0x%08x", rd))
    random_read(DSM_REG_OBS_PAIR_COUNT, rd);
    if (rd != 32'd64)
      `uvm_error("OBS_PAIR", $sformatf("paired_count=%0d expected 64", rd))
    random_read(DSM_REG_OBS_DROP_COUNT, rd);
    if (rd != 32'd0)
      `uvm_error("OBS_DROP", $sformatf("dropped_count=%0d expected 0", rd))
  endtask
endclass
