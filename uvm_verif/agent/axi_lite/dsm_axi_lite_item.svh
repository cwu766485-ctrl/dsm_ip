class dsm_axi_lite_item extends uvm_sequence_item;
  rand bit is_write;
  rand dsm_reg_addr_t addr;
  rand bit [31:0] data;
  rand int unsigned addr_delay_cycles;
  rand int unsigned data_delay_cycles;
  rand int unsigned ready_delay_cycles;
  int unsigned observed_channel_skew_cycles;
  int unsigned observed_response_stall_cycles;
  bit [31:0] rdata;
  bit [1:0] resp;

  constraint c_protocol_delays {
    addr_delay_cycles inside {[0:8]};
    data_delay_cycles inside {[0:8]};
    ready_delay_cycles inside {[0:8]};
  }

  `uvm_object_utils_begin(dsm_axi_lite_item)
    `uvm_field_int(is_write, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(data, UVM_DEFAULT)
    `uvm_field_int(addr_delay_cycles, UVM_DEFAULT)
    `uvm_field_int(data_delay_cycles, UVM_DEFAULT)
    `uvm_field_int(ready_delay_cycles, UVM_DEFAULT)
    `uvm_field_int(observed_channel_skew_cycles, UVM_DEFAULT)
    `uvm_field_int(observed_response_stall_cycles, UVM_DEFAULT)
    `uvm_field_int(rdata, UVM_DEFAULT)
    `uvm_field_int(resp, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dsm_axi_lite_item");
    super.new(name);
  endfunction
endclass
