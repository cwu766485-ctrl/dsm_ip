class thermo5_sku_env extends uvm_env;
  `uvm_component_utils(thermo5_sku_env)
  thermo5_source_agent source;
  thermo5_pa_sink_agent pa_sink;
  thermo5_pa_monitor monitor;
  thermo5_cdc_core_monitor cdc_monitor;
  thermo5_dsp_boundary_monitor dsp_monitor;
  thermo5_ef2_input_monitor ef2_monitor;
  thermo5_transaction_event_bus event_bus;
  thermo5_unified_scoreboard unified_scoreboard;
  thermo5_pa_scoreboard scoreboard;
  thermo5_sku_coverage coverage;
  thermo5_control_agent control;
  thermo5_axil_agent axil;
  thermo5_sku_virtual_sequencer virtual_sequencer;
  thermo5_axil_register_predictor register_predictor;
  thermo5_trace_recorder trace_recorder;
  thermo5_sku_config cfg;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","Thermo5 environment configuration missing")
    uvm_config_db#(thermo5_sku_config)::set(this,"*","cfg",cfg);
    source=thermo5_source_agent::type_id::create("source",this);
    pa_sink=thermo5_pa_sink_agent::type_id::create("pa_sink",this);
    cdc_monitor=thermo5_cdc_core_monitor::type_id::create("cdc_monitor",this);
    dsp_monitor=thermo5_dsp_boundary_monitor::type_id::create("dsp_monitor",this);
    ef2_monitor=thermo5_ef2_input_monitor::type_id::create("ef2_monitor",this);
    event_bus=thermo5_transaction_event_bus::type_id::create("event_bus",this);
    unified_scoreboard=thermo5_unified_scoreboard::type_id::create(
      "unified_scoreboard",this);
    scoreboard=thermo5_pa_scoreboard::type_id::create("scoreboard",this);
    coverage=thermo5_sku_coverage::type_id::create("coverage",this);
    control=thermo5_control_agent::type_id::create("control",this);
    virtual_sequencer=thermo5_sku_virtual_sequencer::type_id::create(
      "virtual_sequencer",this);
    if (cfg.axil_control) begin
      axil=thermo5_axil_agent::type_id::create("axil",this);
      register_predictor=thermo5_axil_register_predictor::type_id::create(
        "register_predictor",this);
      begin
        string trace_path;
        if ($value$plusargs("THERMO5_TRACE_JSONL=%s",trace_path))
          trace_recorder=thermo5_trace_recorder::type_id::create("trace_recorder",this);
      end
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    monitor=pa_sink.monitor;
    source.monitor.ap.connect(scoreboard.source_imp);
    monitor.ap.connect(scoreboard.pa_imp);
    source.monitor.ap.connect(event_bus.source_imp);
    monitor.ap.connect(event_bus.pa_imp);
    cdc_monitor.ap.connect(event_bus.cdc_imp);
    dsp_monitor.ap.connect(event_bus.dsp_imp);
    ef2_monitor.ap.connect(event_bus.ef2_imp);
    event_bus.event_ap.connect(coverage.event_imp);
    event_bus.event_ap.connect(unified_scoreboard.event_imp);
    if (cfg.axil_control) begin
      source.monitor.ap.connect(register_predictor.source_imp);
      monitor.ap.connect(register_predictor.pa_imp);
      axil.monitor.write_fire_ap.connect(register_predictor.write_fire_imp);
      axil.monitor.read_address_ap.connect(register_predictor.read_addr_imp);
      axil.monitor.ap.connect(register_predictor.completion_imp);
      axil.monitor.cycle_ap.connect(register_predictor.cycle_imp);
      axil.monitor.write_fire_ap.connect(event_bus.axil_fire_imp);
      axil.monitor.read_address_ap.connect(event_bus.axil_addr_imp);
      axil.monitor.ap.connect(event_bus.axil_done_imp);
      if (trace_recorder!=null) begin
        event_bus.event_ap.connect(trace_recorder.event_imp);
        axil.monitor.cycle_ap.connect(trace_recorder.axil_cycle_imp);
      end
    end
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    virtual_sequencer.source_sequencer=source.sequencer;
    virtual_sequencer.axil_sequencer=(axil==null) ? null : axil.sequencer;
    virtual_sequencer.pa_sink=pa_sink;
    virtual_sequencer.pa_monitor=monitor;
    virtual_sequencer.control=control;
    virtual_sequencer.cfg=cfg;
  endfunction
endclass
