class thermo5_source_sequencer extends uvm_sequencer#(thermo5_source_item);
  `uvm_component_utils(thermo5_source_sequencer)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
endclass
