class thermo5_axil_item extends uvm_sequence_item;
  rand bit is_write;
  rand bit [7:0] addr;
  rand bit [31:0] data;
  rand bit [3:0] strb;
  rand int unsigned aw_delay;
  rand int unsigned w_delay;
  rand int unsigned response_delay;
  bit ready_before_response;
  bit [31:0] rdata;
  bit [1:0] resp;

  constraint c_delays {
    aw_delay inside {[0:4]};
    w_delay inside {[0:4]};
    response_delay inside {[0:4]};
  }

  `uvm_object_utils_begin(thermo5_axil_item)
    `uvm_field_int(is_write, UVM_DEFAULT)
    `uvm_field_int(addr, UVM_DEFAULT)
    `uvm_field_int(data, UVM_DEFAULT)
    `uvm_field_int(strb, UVM_DEFAULT)
    `uvm_field_int(aw_delay, UVM_DEFAULT)
    `uvm_field_int(w_delay, UVM_DEFAULT)
    `uvm_field_int(response_delay, UVM_DEFAULT)
    `uvm_field_int(ready_before_response, UVM_DEFAULT)
    `uvm_field_int(rdata, UVM_DEFAULT)
    `uvm_field_int(resp, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "thermo5_axil_item");
    super.new(name);
    strb = 4'hf;
    aw_delay = 0;
    w_delay = 0;
    response_delay = 0;
  endfunction
endclass
