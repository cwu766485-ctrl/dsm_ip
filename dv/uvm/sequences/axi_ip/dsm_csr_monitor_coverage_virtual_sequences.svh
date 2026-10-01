// Directed CSR and monitor coverage for the frozen Performance SKU.  It
// reuses the system control scenario to create a completed observer window,
// then exercises every implemented AXI-Lite read mux arm with legal traffic.
class dsm_csr_monitor_coverage_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_csr_monitor_coverage_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_csr_monitor_coverage_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.data_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.addr_delay_cycles = $urandom_range(0, 8);
    seq.ready_delay_cycles = $urandom_range(0, 12);
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_implemented_csrs();
    bit [31:0] value;
    dsm_reg_addr_t addr;
    for (int unsigned word = 0; word <= 7'h47; word++) begin
      addr = dsm_reg_addr_t'(word << 2);
      read_reg(addr, value, $sformatf("csr_read_0x%03x", addr));
    end
    read_reg(9'h1fc, value, "csr_read_unmapped");
    if (value != 32'd0)
      `uvm_error("CSR_DEFAULT", $sformatf("Unmapped read returned 0x%08x", value))
  endtask

  task automatic send_tx(input bit signed [15:0] i_sample,
                         input bit signed [15:0] q_sample,
                         input bit last, input string name);
    dsm_axis_single_item_sequence seq;
    seq = dsm_axis_single_item_sequence::type_id::create(name);
    seq.i_sample = i_sample;
    seq.q_sample = q_sample;
    seq.last = last;
    seq.user_error = 1'b0;
    seq.valid_gap_cycles = $urandom_range(0, 8);
    seq.start(p_sequencer.tx_sequencer);
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.tx_vif.aclk);
  endtask

  task body();
    dsm_control_stress_virtual_sequence control_seq;
    bit [31:0] value;

    // This established scenario leaves a completed observer measurement
    // window, nonzero TX/monitor state, and AXI response-stall coverage.
    control_seq = dsm_control_stress_virtual_sequence::type_id::create("control_seq");
    control_seq.start(p_sequencer);

    // PHASE_W is 24 in the frozen SKU.  This legal write/read pair reaches
    // the configurable phase-increment data path without changing its width.
    write_reg(DSM_REG_PHASE_INC, 32'h0055_aa55, "phase_inc_write");
    read_reg(DSM_REG_PHASE_INC, value, "phase_inc_read");
    if (value != 32'h0055_aa55)
      `uvm_error("CSR_PHASE", $sformatf("PHASE_INC got 0x%08x", value))

    // 0x7ff8 is the RTL MON_CLIP_LEVEL for W=16.  This is a legal Q1.15
    // input and must increment the diagnostic clip counter.  This system
    // test intentionally checks the monitor threshold branch, not the
    // separate signed-minimum absolute-value corner case.
    send_tx(16'sh7ff8, -16'sh7ff8, 1'b0, "clip_positive");
    send_tx(16'sd1024, -16'sd1024, 1'b1, "clip_below_threshold");
    wait_cycles(4096);
    read_reg(DSM_REG_MON_CLIP_COUNT, value, "clip_count_read");
    if (value == 0)
      `uvm_error("CSR_MONITOR", "Legal full-scale input did not increment MON_CLIP_COUNT")

    // Read every decoded word in the implemented 0x000..0x11c CSR window.
    // Values that are dynamic counters are checked by their owning scenarios;
    // this sweep verifies AXI response and read-mux reachability.
    read_implemented_csrs();
  endtask
endclass
