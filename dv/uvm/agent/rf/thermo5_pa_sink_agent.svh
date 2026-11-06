// PA sink Agent bundles the output transaction monitor with the sole
// backpressure driver. In passive mode it observes four-plane transfers only.
class thermo5_pa_sink_agent extends uvm_agent;
  `uvm_component_utils(thermo5_pa_sink_agent)
  thermo5_pa_sink_driver driver;
  thermo5_pa_monitor monitor;
  thermo5_sku_config cfg;

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","PA sink agent configuration is missing")
    is_active=cfg.pa_sink_active;
    monitor=thermo5_pa_monitor::type_id::create("monitor",this);
    if (get_is_active()==UVM_ACTIVE)
      driver=thermo5_pa_sink_driver::type_id::create("driver",this);
  endfunction

  task set_ready(input logic [3:0] ready);
    if (get_is_active()!=UVM_ACTIVE || driver==null)
      `uvm_fatal("PA_PASSIVE","Cannot drive PA_READY through a passive PA sink agent")
    driver.set_requested_ready(ready);
  endtask

endclass
