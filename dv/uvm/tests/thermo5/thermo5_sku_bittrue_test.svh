class thermo5_sku_bittrue_test extends uvm_test;
  `uvm_component_utils(thermo5_sku_bittrue_test)
  virtual thermo5_sku_if vif;
  thermo5_sku_env env;
  thermo5_sku_config cfg;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    cfg.random_pa_ready=$test$plusargs("STRESS_PA_READY");
  endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","thermo5 test interface is missing")
    cfg=thermo5_sku_config::type_id::create("cfg");
    if (!$value$plusargs("VEC_DIR=%s",cfg.vector_dir))
      `uvm_fatal("NOVEC","Pass +VEC_DIR=<MATLAB vector directory>")
    configure_case();
    uvm_config_db#(thermo5_sku_config)::set(this,"env","cfg",cfg);
    env=thermo5_sku_env::type_id::create("env",this);
  endfunction
  task send_source(int beats, bit illegal=0);
    thermo5_source_sequence seq;
    seq=thermo5_source_sequence::type_id::create("source_sequence");
    seq.cfg=cfg; seq.beat_count=beats; seq.illegal_frame=illegal;
    seq.start(env.source.sequencer);
  endtask
  task check_full(bit check_event_totals=1);
    if (env.source.monitor.accepted_beats!=cfg.source_beats ||
        env.scoreboard.source_checked!=cfg.source_beats ||
        env.scoreboard.checked!=cfg.core_words)
      `uvm_fatal("COUNT",$sformatf("source=%0d checked_source=%0d PA=%0d",
        env.source.monitor.accepted_beats,env.scoreboard.source_checked,
        env.scoreboard.checked))
    if (vif.protocol_error || env.coverage.underflow_before_last_source!=0)
      `uvm_fatal("CDC","Protocol error or early FIFO starvation")
    if (check_event_totals &&
        (env.coverage.frame_starts!=cfg.frame_starts ||
         env.coverage.pa_words!=cfg.core_words))
      `uvm_fatal("COVERAGE","Frame/PA event counts did not reach the SKU contract")
  endtask
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full();
            if (cfg.random_pa_ready && env.monitor.stall_cycles==0)
              `uvm_fatal("COVERAGE","No four-plane output stall was exercised")
            `uvm_info("SKU_PASS","THERMO5_SKU_UVM_PASS source=32 output=56 four_planes=bittrue",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 full-stream test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
