// Long-run bit-true traffic.  The vector is deterministic so Python produces
// a fixed expected RF queue; UVM seed variation changes legal AXI timing only.
class dsm_longrun_bittrue_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_longrun_bittrue_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_longrun_bittrue_virtual_sequence");
    super.new(name);
  endfunction

  task body();
    dsm_axi_lite_write_sequence enable_seq;
    dsm_axis_csv_sequence tx_seq;

    enable_seq = dsm_axi_lite_write_sequence::type_id::create("enable");
    enable_seq.addr = DSM_REG_CTRL;
    enable_seq.data = 32'h0000_0001;
    enable_seq.addr_delay_cycles = $urandom_range(0, 16);
    enable_seq.data_delay_cycles = $urandom_range(0, 16);
    enable_seq.ready_delay_cycles = $urandom_range(0, 24);
    enable_seq.start(p_sequencer.axi_sequencer);
    if (enable_seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("CTRL enable response %0b", enable_seq.resp))

    tx_seq = dsm_axis_csv_sequence::type_id::create({vector_set, "_input"});
    tx_seq.vector_set = vector_set;
    tx_seq.max_random_valid_gap = 8;
    tx_seq.start(p_sequencer.tx_sequencer);
  endtask
endclass

class dsm_qam_ofdm_bittrue_virtual_sequence extends dsm_longrun_bittrue_virtual_sequence;
  `uvm_object_utils(dsm_qam_ofdm_bittrue_virtual_sequence)

  function new(string name = "dsm_qam_ofdm_bittrue_virtual_sequence");
    super.new(name);
    vector_set = "qam_ofdm";
  endfunction
endclass
  string vector_set = "longrun_prbs";
