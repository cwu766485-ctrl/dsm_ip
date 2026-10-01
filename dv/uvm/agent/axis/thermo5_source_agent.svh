class thermo5_source_agent extends uvm_agent;
  `uvm_component_utils(thermo5_source_agent)
  thermo5_source_sequencer sequencer;
  thermo5_source_driver driver;
  thermo5_source_monitor monitor;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer=thermo5_source_sequencer::type_id::create("sequencer",this);
    driver=thermo5_source_driver::type_id::create("driver",this);
    monitor=thermo5_source_monitor::type_id::create("monitor",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
