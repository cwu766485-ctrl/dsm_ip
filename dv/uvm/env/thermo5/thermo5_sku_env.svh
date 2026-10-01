class thermo5_sku_env extends uvm_env;
  `uvm_component_utils(thermo5_sku_env)
  thermo5_source_agent source;
  thermo5_pa_monitor monitor;
  thermo5_pa_scoreboard scoreboard;
  thermo5_sku_coverage coverage;
  thermo5_control_bfm control;
  thermo5_sku_config cfg;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","Thermo5 environment configuration missing")
    uvm_config_db#(thermo5_sku_config)::set(this,"*","cfg",cfg);
    source=thermo5_source_agent::type_id::create("source",this);
    monitor=thermo5_pa_monitor::type_id::create("monitor",this);
    scoreboard=thermo5_pa_scoreboard::type_id::create("scoreboard",this);
    coverage=thermo5_sku_coverage::type_id::create("coverage",this);
    control=thermo5_control_bfm::type_id::create("control",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    source.monitor.ap.connect(scoreboard.source_imp);
    monitor.ap.connect(scoreboard.pa_imp);
  endfunction
endclass
