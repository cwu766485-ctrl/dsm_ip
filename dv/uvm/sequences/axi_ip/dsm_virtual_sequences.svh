class dsm_bp_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_bp_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)
  dsm_uvm_config cfg;

  function new(string name = "dsm_bp_virtual_sequence");
    super.new(name);
  endfunction

  task automatic axil_read_check(
    input dsm_reg_addr_t addr,
    input bit [31:0] expected,
    input bit [31:0] mask,
    input string field_name
  );
    dsm_axi_lite_read_sequence rd_seq;
    rd_seq = dsm_axi_lite_read_sequence::type_id::create({"read_", field_name});
    rd_seq.addr = addr;
    rd_seq.start(p_sequencer.axi_sequencer);
    if (rd_seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("%s read returned response %0b", field_name,
                 rd_seq.resp))
    if ((rd_seq.rdata & mask) != (expected & mask))
      `uvm_error("SKU_DRIFT", $sformatf(
        "%s readback 0x%08x expected 0x%08x mask 0x%08x",
        field_name, rd_seq.rdata, expected, mask))
  endtask

  task body();
    dsm_axi_lite_write_sequence wr_seq;
    dsm_axis_single_item_sequence tx_seq;
    if (cfg == null)
      cfg = dsm_uvm_config::type_id::create("cfg");

    if (cfg.check_sku_readback) begin
      axil_read_check(DSM_REG_VERSION, DSM_SKU_CORE_VERSION, 32'hffff_ffff, "version");
      axil_read_check(DSM_REG_ALGORITHM, DSM_SKU_ALGORITHM, 32'hffff_ffff, "algorithm");
      axil_read_check(DSM_REG_DUC_MODE, DSM_SKU_DUC_MODE, 32'hffff_ffff, "duc_mode");
      axil_read_check(DSM_REG_INTERP_MODE, DSM_SKU_INTERP_MODE, 32'hffff_ffff,
                      "interp_mode");
    end

    wr_seq = dsm_axi_lite_write_sequence::type_id::create("enable");
    wr_seq.addr = DSM_REG_CTRL;
    wr_seq.data = 32'h0000_0001;
    wr_seq.start(p_sequencer.axi_sequencer);
    if (wr_seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("CTRL write returned response %0b", wr_seq.resp))

    for (int n = 0; n < 24; n++) begin
      tx_seq = dsm_axis_single_item_sequence::type_id::create($sformatf("tx_%0d", n));
      tx_seq.i_sample = (n < 12) ? 16'sd4096 : -16'sd4096;
      tx_seq.q_sample = n[0] ? 16'sd2048 : -16'sd2048;
      tx_seq.last = (n == 23);
      tx_seq.user_error = 1'b0;
      tx_seq.start(p_sequencer.tx_sequencer);
    end
  endtask
endclass
