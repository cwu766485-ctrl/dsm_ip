// Exercise both EF2 saturation polarities, state retention under a blocked
// output, reset-to-zero, and a complete bit-true replay.
class thermo5_sku_ef2_corner_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_ef2_corner_test)
  logic signed [19:0] saved_e1_i[0:3], saved_e2_i[0:3];
  logic signed [19:0] saved_e1_q[0:3], saved_e2_q[0:3];

  function new(string name, uvm_component parent); super.new(name,parent); endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.manual_pa_ready=1;
    cfg.random_pa_ready=0;
    if (cfg.core_words<2072)
      `uvm_fatal("WORDS","EF2 corner test requires at least 2072 oracle words")
  endfunction

  task send_and_check(bit check_saturation);
    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=4);
        env.control.core_on();
        if (check_saturation) begin
          do @(negedge vif.core_clk);
          while ((vif.pa_valid!=4'hf) ||
                 (!(|vif.ef2_pos_clamp_candidate) && !(|vif.ef2_neg_clamp_candidate)));
          vif.pa_ready=4'h0;
          wait(vif.ef2_clamp_stalled);
          for (int branch=0;branch<4;branch++) begin
            saved_e1_i[branch]=vif.ef2_err1_i[branch];
            saved_e2_i[branch]=vif.ef2_err2_i[branch];
            saved_e1_q[branch]=vif.ef2_err1_q[branch];
            saved_e2_q[branch]=vif.ef2_err2_q[branch];
          end
          repeat(8) begin
            @(posedge vif.core_clk);
            if (vif.ef2_clamp_stalled !== 1'b1)
              `uvm_fatal("CLAMP_STALL","Saturation candidate was not held during TIDSM backpressure")
            for (int branch=0;branch<4;branch++)
              if (vif.ef2_err1_i[branch]!==saved_e1_i[branch] ||
                  vif.ef2_err2_i[branch]!==saved_e2_i[branch] ||
                  vif.ef2_err1_q[branch]!==saved_e1_q[branch] ||
                  vif.ef2_err2_q[branch]!==saved_e2_q[branch])
                `uvm_fatal("STATE_STALL",$sformatf("EF2 branch %0d state advanced under PA stall",branch))
          end
          @(negedge vif.core_clk);
          vif.pa_ready=4'hf;
        end
        wait(env.scoreboard.checked==cfg.core_words);
        env.control.core_off();
        check_full(check_saturation);
      end
    join
  endtask

  task qualify();
    if (vif.ef2_order2_enabled !== 1'b1)
      `uvm_fatal("CONFIG","EF2 corner test requires TIDSM_ORDER=2")
    vif.pa_ready=4'hf;
    send_and_check(1'b1);
    if (env.coverage.ef2_positive_clamp_events==0 ||
        env.coverage.ef2_negative_clamp_events==0 ||
        env.coverage.ef2_clamp_stall_cycles==0 ||
        env.coverage.ef2_state_rail_cycles==0)
      `uvm_fatal("EF2_COVERAGE","Both clamp polarities, clamp candidate held, and a state rail must be observed")
    for (int branch=0;branch<4;branch++)
      if ((env.coverage.ef2_positive_clamp_branch[branch] +
           env.coverage.ef2_negative_clamp_branch[branch])==0)
        `uvm_fatal("EF2_BRANCH_COVERAGE",$sformatf("branch %0d did not reach a state clamp (+%0d -%0d)",
          branch,env.coverage.ef2_positive_clamp_branch[branch],
          env.coverage.ef2_negative_clamp_branch[branch]))
    `uvm_info("EF2_CLAMP_DETAIL",$sformatf("branch clamps: b0 +%0d/-%0d b1 +%0d/-%0d b2 +%0d/-%0d b3 +%0d/-%0d",
      env.coverage.ef2_positive_clamp_branch[0],env.coverage.ef2_negative_clamp_branch[0],
      env.coverage.ef2_positive_clamp_branch[1],env.coverage.ef2_negative_clamp_branch[1],
      env.coverage.ef2_positive_clamp_branch[2],env.coverage.ef2_negative_clamp_branch[2],
      env.coverage.ef2_positive_clamp_branch[3],env.coverage.ef2_negative_clamp_branch[3]),UVM_NONE)

    @(negedge vif.core_clk);
    vif.pa_ready=4'hf;
    env.control.reset_both();
    repeat(2) @(posedge vif.core_clk);
    if (vif.ef2_state_zero !== 4'hf)
      `uvm_fatal("EF2_RESET","EF2 state did not return to zero in all four branches")
    send_and_check(1'b0);
    `uvm_info("SKU_PASS","THERMO5_EF2_CORNER_UVM_PASS positive/negative clamps, stall hold, reset, bit-true replay",UVM_NONE)
  endtask

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      qualify();
      begin
        repeat(100000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT",$sformatf("EF2 qualification timed out: source=%0d checked=%0d pa_valid=%b pa_ready=%b candidates=+%b/-%b clamps=+%0d/-%0d",
          env.source.monitor.accepted_beats,env.scoreboard.checked,vif.pa_valid,vif.pa_ready,
          vif.ef2_pos_clamp_candidate,vif.ef2_neg_clamp_candidate,
          env.coverage.ef2_positive_clamp_events,env.coverage.ef2_negative_clamp_events))
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
