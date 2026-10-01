class dsm_performance_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_performance_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_performance_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axi_lite_write_sequence wr_seq;
    dsm_axis_csv_sequence tx_seq;
    wr_seq = dsm_axi_lite_write_sequence::type_id::create("enable");
    wr_seq.addr = DSM_REG_CTRL;
    wr_seq.data = 32'h0000_0001;
    wr_seq.start(p_sequencer.axi_sequencer);
    if (wr_seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("CTRL write response %0b", wr_seq.resp))
    tx_seq = dsm_axis_csv_sequence::type_id::create("performance_input");
    tx_seq.vector_set = "performance_sku";
    tx_seq.start(p_sequencer.tx_sequencer);
  endtask
endclass
