class dsm_env extends uvm_env;
  `uvm_component_utils(dsm_env)
  dsm_uvm_config cfg;
  dsm_axi_lite_agent axi_agent;
  dsm_axis_agent tx_agent;
  dsm_axis_agent obs_agent;
  dsm_rf_agent rf_agent;
  dsm_scoreboard scoreboard;
  dsm_virtual_sequencer virtual_sequencer;

  function new(string name, uvm_component parent); super.new(name, parent); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dsm_uvm_config)::get(this, "", "cfg", cfg))
      cfg = dsm_uvm_config::type_id::create("cfg");
    uvm_config_db#(dsm_uvm_config)::set(this, "scoreboard", "cfg", cfg);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "axi_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "tx_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "obs_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "rf_agent", "is_active", UVM_PASSIVE);
    axi_agent = dsm_axi_lite_agent::type_id::create("axi_agent", this);
    tx_agent = dsm_axis_agent::type_id::create("tx_agent", this);
    obs_agent = dsm_axis_agent::type_id::create("obs_agent", this);
    rf_agent = dsm_rf_agent::type_id::create("rf_agent", this);
    scoreboard = dsm_scoreboard::type_id::create("scoreboard", this);
    virtual_sequencer = dsm_virtual_sequencer::type_id::create("virtual_sequencer", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    rf_agent.monitor.ap.connect(scoreboard.analysis_export);
    tx_agent.monitor.ap.connect(scoreboard.tx_export);
    axi_agent.monitor.ap.connect(scoreboard.axil_export);
    obs_agent.monitor.ap.connect(scoreboard.obs_export);
    virtual_sequencer.axi_sequencer = axi_agent.sequencer;
    virtual_sequencer.tx_sequencer = tx_agent.sequencer;
    virtual_sequencer.obs_sequencer = obs_agent.sequencer;
    virtual_sequencer.tx_vif = tx_agent.driver.vif;
    virtual_sequencer.obs_vif = obs_agent.driver.vif;
  endfunction
endclass
