class dsm_axis_item extends uvm_sequence_item;
  rand bit signed [15:0] i_sample;
  rand bit signed [15:0] q_sample;
  rand bit last;
  rand bit user_error;
  rand int unsigned valid_gap_cycles;

  constraint c_valid_gap {
    valid_gap_cycles inside {[0:8]};
  }

  `uvm_object_utils_begin(dsm_axis_item)
    `uvm_field_int(i_sample, UVM_DEFAULT)
    `uvm_field_int(q_sample, UVM_DEFAULT)
    `uvm_field_int(last, UVM_DEFAULT)
    `uvm_field_int(user_error, UVM_DEFAULT)
    `uvm_field_int(valid_gap_cycles, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dsm_axis_item");
    super.new(name);
  endfunction
endclass
