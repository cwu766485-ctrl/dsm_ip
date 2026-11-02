class thermo5_sku_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(thermo5_sku_virtual_sequencer)
  thermo5_source_sequencer source_sequencer;
  thermo5_axil_sequencer axil_sequencer;
  thermo5_pa_sink_agent pa_sink;
  thermo5_pa_monitor pa_monitor;
  thermo5_sku_config cfg;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
endclass
