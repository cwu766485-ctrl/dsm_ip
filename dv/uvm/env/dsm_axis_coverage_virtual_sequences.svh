// Directed coverage closure for AXI-Stream packet sidebands.  This sequence
// deliberately exercises every {TLAST, TUSER[0]} combination while preserving
// the same AXI agents and RTL datapath used by system tests.
class dsm_axis_coverage_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_axis_coverage_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_axis_coverage_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(
    input dsm_reg_addr_t addr,
    input bit [31:0] data,
    input string name
  );
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic send_item(
    input uvm_sequencer_base sequencer,
    input bit last,
    input bit user_error,
    input int unsigned gap,
    input int signed i_sample,
    input int signed q_sample,
    input string name
  );
    dsm_axis_single_item_sequence seq;
    seq = dsm_axis_single_item_sequence::type_id::create(name);
    seq.last = last;
    seq.user_error = user_error;
    seq.valid_gap_cycles = gap;
    seq.i_sample = i_sample;
    seq.q_sample = q_sample;
    seq.start(sequencer);
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    // TX covers all sideband combinations and continuous/short/long source
    // gaps.  TUSER is intentionally injected here; the sticky-error outcome
    // is validated by the control test, while this test closes stream bins.
    write_reg(DSM_REG_CTRL, 32'h0000_0001, "enable_tx");
    send_item(p_sequencer.tx_sequencer, 0, 0, 0,  1024, -1024, "tx_00");
    send_item(p_sequencer.tx_sequencer, 0, 1, 3,  2048, -2048, "tx_01");
    send_item(p_sequencer.tx_sequencer, 1, 0, 12, 3072, -3072, "tx_10");
    send_item(p_sequencer.tx_sequencer, 1, 1, 0,  4096, -4096, "tx_11");

    // OBS ready is asserted only after enable+start.  Configure it first to
    // generate zero-ready-stall transfers, then the control-stress test
    // supplies the deliberate waiting case while OBS is inactive.
    write_reg(DSM_REG_OBS_GAIN, 32'h0000_4000, "obs_gain");
    write_reg(DSM_REG_OBS_WINDOW, 32'd16, "obs_window");
    write_reg(DSM_REG_OBS_CTRL, 32'h0000_0103, "obs_enable_start");
    wait_cycles(8);
    send_item(p_sequencer.obs_sequencer, 0, 0, 0,  512, -512, "obs_00");
    send_item(p_sequencer.obs_sequencer, 0, 1, 3, 1024, -1024, "obs_01");
    send_item(p_sequencer.obs_sequencer, 1, 0, 12, 1536, -1536, "obs_10");
    send_item(p_sequencer.obs_sequencer, 1, 1, 0, 2048, -2048, "obs_11");
  endtask
endclass
