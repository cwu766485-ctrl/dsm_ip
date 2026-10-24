// Centered-cubic low-power closure: STOP mid-packet, accept through TLAST,
// bit-true drain all real words, then verify the datapath reaches IDLE.
class thermo5_sku_low_power_drain_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_low_power_drain_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.frame_starts=1;
    if (cfg.core_words!=56)
      `uvm_fatal("LOW_POWER_WORDS","low-power closure expects one 56-word packet")
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            env.control.core_on();
            wait(env.source.monitor.accepted_beats>=20);
            env.control.core_off();
            for (int cycles=0; cycles<12000 &&
                 env.scoreboard.checked<cfg.core_words; cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("LOW_POWER_OUTPUT_TIMEOUT",
                $sformatf("received %0d of %0d bit-true words",
                  env.scoreboard.checked,cfg.core_words))
            check_full();
            for (int cycles=0; cycles<1000 &&
                 (vif.low_power_outstanding!=0 || vif.low_power_active ||
                  vif.low_power_state!=3'd1); cycles++)
              @(posedge vif.core_clk);
            if (env.source.monitor.accepted_last_count!=1 ||
                vif.low_power_outstanding!=0 || vif.low_power_active ||
                vif.low_power_state!=3'd1 || vif.underflow || vif.protocol_error)
              `uvm_fatal("LOW_POWER_DRAIN_STATE",
                $sformatf("TLAST=%0d outstanding=%0d active=%b state=%0d underflow=%b protocol=%b",
                  env.source.monitor.accepted_last_count,vif.low_power_outstanding,
                  vif.low_power_active,vif.low_power_state,vif.underflow,vif.protocol_error))
            `uvm_info("SKU_PASS",
              "THERMO5_LOW_POWER_CENTERED_DRAIN_UVM_PASS: STOP finished the open TLAST packet, all 56 four-plane words matched, and the frontend returned to IDLE",
              UVM_NONE)
          end
        join
      end
      begin
        repeat(16000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Thermo5 centered low-power drain did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
