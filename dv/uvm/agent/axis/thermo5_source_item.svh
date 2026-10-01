class thermo5_source_item extends uvm_sequence_item;
  `uvm_object_utils(thermo5_source_item)
  logic [223:0] i_vec, q_vec;
  logic frame_start;
  logic signed [15:0] frame_gain;
  int beat_index;
  function new(string name = "thermo5_source_item"); super.new(name); endfunction
endclass
