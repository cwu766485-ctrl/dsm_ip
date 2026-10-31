// AXI-Lite-controlled EF2 saturation qualification.  This mirrors the
// generic EF2 corner test while starting/stopping the actual AXI-Lite DUT
// through its public control register.
class thermo5_sku_axil_ef2_corner_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_ef2_corner_test)

  logic signed [19:0] saved_e1_i[0:3], saved_e2_i[0:3];
  logic signed [19:0] saved_e1_q[0:3], saved_e2_q[0:3];

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.frame_starts=3;
    cfg.expect_pa=1;
    if (cfg.core_words!=2072)
      `uvm_fatal("EF2_WORDS","Use CORE_WORDS=2072 with the long EF2 corner vectors")
  endfunction

  task automatic stall_candidate(input bit positive);
    bit candidate;
    candidate=0;
    while (!candidate) begin
      @(negedge vif.core_clk);
      candidate=(vif.pa_valid==4'hf) &&
                (positive ? (|vif.ef2_pos_clamp_candidate) :
                            (|vif.ef2_neg_clamp_candidate));
    end

    // Backpressure is asserted before the candidate's next core-clock
    // transfer, then the state and candidate must remain stable.
    vif.pa_ready=4'h0;
    wait(vif.ef2_clamp_stalled &&
         (positive ? (|vif.ef2_pos_clamp_candidate) :
                     (|vif.ef2_neg_clamp_candidate)));
    for (int branch=0;branch<4;branch++) begin
      saved_e1_i[branch]=vif.ef2_err1_i[branch];
      saved_e2_i[branch]=vif.ef2_err2_i[branch];
      saved_e1_q[branch]=vif.ef2_err1_q[branch];
      saved_e2_q[branch]=vif.ef2_err2_q[branch];
    end
    repeat(8) begin
      @(posedge vif.core_clk);
      #1ps;
      if (!vif.ef2_clamp_stalled ||
          !(positive ? (|vif.ef2_pos_clamp_candidate) :
                       (|vif.ef2_neg_clamp_candidate)))
        `uvm_fatal("EF2_CLAMP_STALL","Selected clamp candidate was not held under PA backpressure")
      for (int branch=0;branch<4;branch++)
        if (vif.ef2_err1_i[branch]!==saved_e1_i[branch] ||
            vif.ef2_err2_i[branch]!==saved_e2_i[branch] ||
            vif.ef2_err1_q[branch]!==saved_e1_q[branch] ||
            vif.ef2_err2_q[branch]!==saved_e2_q[branch])
          `uvm_fatal("EF2_STATE_STALL",
            $sformatf("EF2 branch %0d state advanced under AXIL PA stall",branch))
    end
    @(negedge vif.core_clk);
    vif.pa_ready=4'hf;
  endtask

  task automatic stall_state_rail();
    bit state_at_rail;
    state_at_rail=0;
    while (!state_at_rail) begin
      @(negedge vif.core_clk);
      state_at_rail=(vif.pa_valid==4'hf) && (|vif.ef2_state_at_rail);
    end
    vif.pa_ready=4'h0;
    wait(vif.ef2_tidsm_stalled && (|vif.ef2_state_at_rail));
    for (int branch=0;branch<4;branch++) begin
      saved_e1_i[branch]=vif.ef2_err1_i[branch];
      saved_e2_i[branch]=vif.ef2_err2_i[branch];
      saved_e1_q[branch]=vif.ef2_err1_q[branch];
      saved_e2_q[branch]=vif.ef2_err2_q[branch];
    end
    repeat(8) begin
      @(posedge vif.core_clk);
      #1ps;
      if (!vif.ef2_tidsm_stalled || !(|vif.ef2_state_at_rail))
        `uvm_fatal("STATE_RAIL_STALL","State-rail condition was not held during TIDSM backpressure")
      for (int branch=0;branch<4;branch++)
        if (vif.ef2_err1_i[branch]!==saved_e1_i[branch] ||
            vif.ef2_err2_i[branch]!==saved_e2_i[branch] ||
            vif.ef2_err1_q[branch]!==saved_e1_q[branch] ||
            vif.ef2_err2_q[branch]!==saved_e2_q[branch])
          `uvm_fatal("STATE_RAIL_HOLD",
            $sformatf("EF2 branch %0d state changed while a rail was stalled",branch))
    end
    @(negedge vif.core_clk);
    vif.pa_ready=4'hf;
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit drain_complete;
    phase.raise_objection(this);
    vif.pa_ready=4'hf;
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            if (vif.ef2_order2_enabled!==1'b1)
              `uvm_fatal("EF2_CONFIG","AXI-Lite EF2 qualification requires TIDSM_ORDER=2")
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            wait(env.source.monitor.accepted_beats>=4);
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00) `uvm_fatal("EF2_RUN","Could not start AXI-Lite EF2 traffic")

            // STOP while the packet is open. The wrapper must accept through
            // TLAST and drain the remaining EF2 stream without underflow.
            wait(env.source.monitor.accepted_beats>=20);
            axil_write(8'h00,32'd0,0,1,resp);
            if (resp!=2'b00) `uvm_fatal("EF2_STOP","Could not request graceful AXI-Lite drain")

            stall_candidate(1'b1);
            stall_candidate(1'b0);
            stall_state_rail();
            for (int cycles=0;cycles<100000 &&
                 env.scoreboard.checked!=cfg.core_words;cycles++)
              @(posedge vif.core_clk);
            if (env.scoreboard.checked!=cfg.core_words)
              `uvm_fatal("EF2_STREAM_TIMEOUT",
                $sformatf("checked=%0d expected=%0d",env.scoreboard.checked,cfg.core_words))
            check_full();
            if (env.coverage.ef2_positive_clamp_events==0 ||
                env.coverage.ef2_negative_clamp_events==0 ||
                env.coverage.ef2_clamp_stall_cycles==0 ||
                env.coverage.ef2_state_rail_cycles==0 ||
                env.coverage.ef2_state_rail_stall_cycles==0)
              `uvm_fatal("EF2_COVERAGE",
                "Both clamp polarities, clamp stall, state rail, and rail stall must be observed")
            for (int branch=0;branch<4;branch++)
              if (env.coverage.ef2_positive_clamp_branch[branch]==0 ||
                  env.coverage.ef2_negative_clamp_branch[branch]==0)
                `uvm_fatal("EF2_BRANCH_COVERAGE",
                  $sformatf("Branch %0d did not reach both clamp polarities (+%0d -%0d)",
                    branch,env.coverage.ef2_positive_clamp_branch[branch],
                    env.coverage.ef2_negative_clamp_branch[branch]))

            if (vif.underflow || vif.protocol_error)
              `uvm_fatal("EF2_DIAGNOSTIC",
                $sformatf("Unexpected underflow/protocol error: underflow=%b protocol=%b",
                  vif.underflow,vif.protocol_error))
            drain_complete=0;
            for (int polls=0;polls<1000 && !drain_complete;polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00) `uvm_fatal("EF2_STATUS","Status read failed after drain")
              drain_complete=(rdata[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("EF2_DRAIN","AXI-Lite did not reach drained idle")
            if (env.coverage.underflow_cycles!=0)
              `uvm_fatal("EF2_UNDERFLOW_COUNT",
                $sformatf("Observed %0d underflow cycles during EF2 qualification",
                  env.coverage.underflow_cycles))
            env.control.reset_both();
            wait_axil_reset_release();
            repeat(2) @(posedge vif.core_clk);
            if (vif.ef2_state_zero!==4'hf)
              `uvm_fatal("EF2_RESET","EF2 state did not clear across all four branches")
            `uvm_info("SKU_PASS",
              "THERMO5_AXIL_EF2_CORNER_UVM_PASS positive/negative clamps, state hold, reset and bit-true stream",
              UVM_NONE)
          end
        join
      end
      begin
        repeat(100000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT",
          $sformatf("AXI-Lite EF2 qualification timeout: source=%0d checked=%0d candidates=+%b/-%b",
            env.source.monitor.accepted_beats,env.scoreboard.checked,
            vif.ef2_pos_clamp_candidate,vif.ef2_neg_clamp_candidate))
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
