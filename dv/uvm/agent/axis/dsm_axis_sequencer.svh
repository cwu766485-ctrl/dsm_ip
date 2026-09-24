class dsm_axis_sequencer extends uvm_sequencer #(dsm_axis_item);
  `uvm_component_utils(dsm_axis_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
