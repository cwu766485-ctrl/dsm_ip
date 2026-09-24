// Negative control-plane cases for the frozen Performance SKU.  These are
// legal AXI-Lite transactions whose requested feature is unavailable or whose
// side effect must be controlled.  They verify safe fallback rather than
// expecting every software request to succeed.
class dsm_negative_control_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_negative_control_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_negative_control_virtual_sequence");
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
    seq.addr_delay_cycles = $urandom_range(0, 16);
    seq.data_delay_cycles = $urandom_range(0, 16);
    seq.ready_delay_cycles = $urandom_range(0, 24);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(
    input dsm_reg_addr_t addr,
    output bit [31:0] data,
    input string name
  );
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

  task automatic expect_effective(
    input bit [1:0] requested,
    input bit [1:0] effective,
    input bit fallback,
    input string name
  );
    bit [31:0] value;
    read_reg(DSM_REG_EFFECTIVE_STATUS, value, name);
    if ((value[1:0] != requested) || (value[3:2] != effective) ||
        (value[9] != fallback))
      `uvm_error("DPD_FALLBACK", $sformatf(
        "%s status=0x%08x requested=%0d effective=%0d fallback=%0b",
        name, value, requested, effective, fallback))
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    dsm_axis_single_item_sequence tx_error;
    bit [31:0] value;

    // Poly and LUT are deliberately compiled out of the Performance SKU.
    // The request remains readable, but the datapath must use bypass and set
    // the status fallback indicator rather than selecting absent hardware.
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0101, "request_disabled_poly");
    expect_effective(2'd1, 2'd0, 1'b1, "disabled_poly_falls_back");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0102, "request_disabled_lut");
    expect_effective(2'd2, 2'd0, 1'b1, "disabled_lut_falls_back");
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "restore_bypass");
    expect_effective(2'd0, 2'd0, 1'b0, "bypass_has_no_fallback");

    // Generate ERROR.bit1 through a legal TX TUSER event.  ERROR is W1C:
    // writing zero must preserve the sticky flag, while writing one clears it.
    write_reg(DSM_REG_CTRL, 32'h0000_0001, "enable_core");
    tx_error = dsm_axis_single_item_sequence::type_id::create("tx_tuser_error");
    tx_error.i_sample = 16'sd1024;
    tx_error.q_sample = -16'sd1024;
    tx_error.last = 1'b1;
    tx_error.user_error = 1'b1;
    tx_error.valid_gap_cycles = 0;
    tx_error.start(p_sequencer.tx_sequencer);
    wait_cycles(128);
    read_reg(DSM_REG_ERROR, value, "tuser_error_set");
    if (!value[1])
      `uvm_error("STICKY_ERROR", $sformatf("TUSER did not set ERROR.bit1: 0x%08x", value))

    write_reg(DSM_REG_ERROR, 32'h0000_0000, "w1c_zero_preserves_error");
    read_reg(DSM_REG_ERROR, value, "tuser_error_after_zero_write");
    if (!value[1])
      `uvm_error("STICKY_ERROR", "ERROR.bit1 cleared by a zero W1C write")

    write_reg(DSM_REG_ERROR, 32'h0000_0002, "w1c_clear_tuser_error");
    read_reg(DSM_REG_ERROR, value, "tuser_error_after_one_write");
    if (value[1])
      `uvm_error("STICKY_ERROR", "ERROR.bit1 did not clear after its W1C write")
  endtask
endclass
