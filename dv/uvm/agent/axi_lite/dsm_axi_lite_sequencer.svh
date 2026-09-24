class dsm_axi_lite_sequencer extends uvm_sequencer #(dsm_axi_lite_item);
  `uvm_component_utils(dsm_axi_lite_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
