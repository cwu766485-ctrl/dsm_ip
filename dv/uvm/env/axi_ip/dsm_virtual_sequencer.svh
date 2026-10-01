class dsm_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(dsm_virtual_sequencer)
  dsm_axi_lite_sequencer axi_sequencer;
  dsm_axis_sequencer tx_sequencer;
  dsm_axis_sequencer obs_sequencer;
  virtual dsm_axis_if tx_vif;
  virtual dsm_axis_if obs_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass
