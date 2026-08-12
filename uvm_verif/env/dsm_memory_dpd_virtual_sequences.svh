class dsm_memory_dpd_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_memory_dpd_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  string coeff_path = "";
  string vector_set = "memory_dpd_system";

  function new(string name = "dsm_memory_dpd_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic wait_for_commit_ack();
    bit [31:0] status;
    for (int unsigned poll = 0; poll < 32; poll++) begin
      read_reg(DSM_REG_MP_COMMIT_STATUS, status, $sformatf("mp_status_%0d", poll));
      if (status[3]) begin
        `uvm_fatal("MP_COMMIT", "Valid memory-DPD package was rejected")
      end
      if (status[0])
        return;
    end
    `uvm_fatal("MP_COMMIT", "Timed out waiting for memory-DPD commit acknowledgement")
  endtask

  task automatic load_memory_coefficients();
    integer fd;
    integer code;
    integer tap;
    integer order_code;
    integer real_value;
    integer imag_value;
    integer write_count;
    bit [31:0] select_data;
    bit [31:0] coeff_data;
    string header;
    if (coeff_path == "")
      coeff_path = $sformatf("%s/memory_dpd_system_coeff.csv", dsm_vector_dir());
    fd = $fopen(coeff_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("Cannot open %s", coeff_path))
    void'($fgets(header, fd));
    write_count = 0;
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d\n", tap, order_code, real_value, imag_value);
      if (code == 4) begin
        select_data = ((tap & 3) << 0) | ((order_code & 3) << 2) |
                      (((tap >> 2) & 1) << 4) | (4 << 8);
        coeff_data = (real_value & 16'hffff) | ((imag_value & 16'hffff) << 16);
        write_reg(DSM_REG_MP_SELECT, select_data, $sformatf("mp_select_t%0d_o%0d", tap, order_code));
        write_reg(DSM_REG_MP_DATA, coeff_data, $sformatf("mp_data_t%0d_o%0d", tap, order_code));
        write_count++;
      end else if (code != -1) begin
        `uvm_fatal("VECTOR_PARSE", $sformatf("Malformed coefficient row in %s", coeff_path))
      end
    end
    $fclose(fd);
    if (write_count != 12)
      `uvm_fatal("VECTOR_PARSE", $sformatf("Expected 12 memory-DPD coefficients, got %0d", write_count))
  endtask

  task body();
    dsm_axis_csv_sequence tx_seq;
    bit [31:0] effective_status;

    // Enable coefficient bounds checking before touching the inactive bank.
    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "dpd_safety_enable");
    load_memory_coefficients();
    write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "mp_commit_request");
    wait_for_commit_ack();

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0103, "dpd_memory_mode_enable");
    read_reg(DSM_REG_EFFECTIVE_STATUS, effective_status, "effective_status");
    if ((effective_status[3:2] != 2'd3) || !effective_status[4] || effective_status[9])
      `uvm_error("DPD_EFFECTIVE", $sformatf("Unexpected effective status 0x%08x", effective_status))

    write_reg(DSM_REG_CTRL, 32'h0000_0001, "core_enable");
    tx_seq = dsm_axis_csv_sequence::type_id::create("memory_dpd_input");
    tx_seq.vector_set = vector_set;
    tx_seq.start(p_sequencer.tx_sequencer);
  endtask
endclass

class dsm_memory_dpd_safety_virtual_sequence extends uvm_sequence;
  `uvm_object_utils(dsm_memory_dpd_safety_virtual_sequence)
  `uvm_declare_p_sequencer(dsm_virtual_sequencer)

  function new(string name = "dsm_memory_dpd_safety_virtual_sequence");
    super.new(name);
  endfunction

  task automatic write_reg(input dsm_reg_addr_t addr, input bit [31:0] data,
                           input string name);
    dsm_axi_lite_write_sequence seq;
    seq = dsm_axi_lite_write_sequence::type_id::create(name);
    seq.addr = addr;
    seq.data = data;
    seq.start(p_sequencer.axi_sequencer);
    if (seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task automatic read_reg(input dsm_reg_addr_t addr, output bit [31:0] data,
                          input string name);
    dsm_axi_lite_read_sequence seq;
    seq = dsm_axi_lite_read_sequence::type_id::create(name);
    seq.addr = addr;
    seq.start(p_sequencer.axi_sequencer);
    data = seq.rdata;
    if (seq.resp != 2'b00)
      `uvm_error("AXI_RESP", $sformatf("%s response %0b", name, seq.resp))
  endtask

  task body();
    bit [31:0] status;
    bit [31:0] active_bank;
    bit [31:0] error_status;
    bit failed;

    write_reg(DSM_REG_DPD_CTRL, 32'h0000_0100, "dpd_safety_enable");
    write_reg(DSM_REG_MP_SELECT, 32'h0000_0400, "unsafe_mp_select");
    write_reg(DSM_REG_MP_DATA, 32'h0000_6001, "unsafe_mp_data");
    write_reg(DSM_REG_MP_COMMIT, 32'h0000_0001, "unsafe_mp_commit");

    failed = 1'b0;
    for (int unsigned poll = 0; poll < 32; poll++) begin
      read_reg(DSM_REG_MP_COMMIT_STATUS, status, $sformatf("unsafe_status_%0d", poll));
      if (status[3]) begin
        failed = 1'b1;
        break;
      end
    end
    if (!failed)
      `uvm_error("MP_SAFETY", "Unsafe memory-DPD package was not rejected")
    read_reg(DSM_REG_MP_COMMIT, active_bank, "unsafe_active_bank");
    if (active_bank[0] != 1'b0)
      `uvm_error("MP_SAFETY", "Unsafe package changed the active coefficient bank")
    read_reg(DSM_REG_ERROR, error_status, "unsafe_error_status");
    if (!error_status[3])
      `uvm_error("MP_SAFETY", "Commit rejection did not set ERROR.bit3")
  endtask
endclass
