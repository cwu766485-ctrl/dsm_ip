class thermo5_axil_sequencer extends uvm_sequencer #(thermo5_axil_item);
  `uvm_component_utils(thermo5_axil_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
