class thermo5_sku_prestart_empty_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_prestart_empty_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);
    env.control.core_on();
    repeat(80) @(negedge vif.core_clk);
    if(vif.underflow || vif.protocol_error || vif.pa_valid!=0)
      `uvm_fatal("PRESTART_EMPTY","Empty pre-frame core must stay quiet without underflow")
    env.control.core_off();
    super.run_phase(phase);
    `uvm_info("SKU_PASS","THERMO5_PRESTART_EMPTY_PASS quiet empty core then complete independent stream",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

class thermo5_sku_fifo_boundary_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_fifo_boundary_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.fifo_full && !vif.src_ready);
            repeat(3) @(posedge vif.src_clk);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full();
            if (env.coverage.fifo_full_cycles==0 ||
                env.source.monitor.stall_cycles==0)
              `uvm_fatal("COVERAGE","FIFO full/backpressure was not observed")
            `uvm_info("SKU_PASS","THERMO5_FIFO_BOUNDARY_UVM_PASS full backpressure and 56 bittrue words",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","FIFO boundary test did not drain")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

// Full-chain AXI valid gap: creates legal pipeline bubbles without forcing
// DUT internals. The original four-plane MATLAB oracle remains active.
class thermo5_sku_bubble_backpressure_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_bubble_backpressure_test)
  int interp1_hits, interp2_hits, dpd_hits, interp1_hold_hits, interp1_stage0_hits;
  int interp2_hold_hits, interp1_output_hold_hits, interp2_output_hold_hits;
  int interp1_output_empty_hits, interp1_stage1_empty_hits, interp2_stage1_empty_hits;
  int gap_beat=4, gap_length=80;
  bit require_interp1_stage1_empty=0;
  // A zero-length initial hold lets the source bubble meet partial PA
  // backpressure. A long 100% hold masks two legal empty/blocked states.
  int hold_pa_cycles=0;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.random_pa_ready=1;
    cfg.pa_stall_percent=100;
    void'($value$plusargs("BUBBLE_GAP_BEAT=%d",gap_beat));
    void'($value$plusargs("BUBBLE_GAP_CYCLES=%d",gap_length));
    void'($value$plusargs("BUBBLE_STALL_PERCENT=%d",cfg.pa_stall_percent));
    void'($value$plusargs("BUBBLE_HOLD_PA_CYCLES=%d",hold_pa_cycles));
    require_interp1_stage1_empty=$test$plusargs("CHECK_I1_STAGE1_EMPTY");
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,0,gap_beat,gap_length);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            repeat (hold_pa_cycles) @(posedge vif.core_clk);
            cfg.pa_stall_percent=90;
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            if (env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.scoreboard.source_checked!=cfg.source_beats || vif.protocol_error)
              `uvm_fatal("BUBBLE_COUNT","Source count or protocol error after valid gap")
            if (interp1_hits==0 || interp2_hits==0 || dpd_hits==0 ||
                interp1_hold_hits==0 || interp1_stage0_hits==0 || interp2_hold_hits==0 ||
                interp1_output_hold_hits==0 || interp2_output_hold_hits==0 ||
                interp1_output_empty_hits==0 ||
                (require_interp1_stage1_empty && interp1_stage1_empty_hits==0) ||
                interp2_stage1_empty_hits==0)
              `uvm_fatal("BUBBLE_COVERAGE",$sformatf("missing state i1=%0d i2=%0d dpd=%0d i1_s1=%0d i1_s0=%0d i2_s1=%0d i1_out=%0d i2_out=%0d i1_out_empty=%0d i1_s1_empty=%0d i2_s1_empty=%0d",
                interp1_hits,interp2_hits,dpd_hits,interp1_hold_hits,interp1_stage0_hits,interp2_hold_hits,interp1_output_hold_hits,interp2_output_hold_hits,interp1_output_empty_hits,interp1_stage1_empty_hits,interp2_stage1_empty_hits))
            `uvm_info("SKU_PASS",$sformatf("THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS i1=%0d i2=%0d dpd=%0d i1_s1=%0d i1_s0=%0d i2_s1=%0d i1_out=%0d i2_out=%0d i1_out_empty=%0d i1_s1_empty=%0d i2_s1_empty=%0d words=%0d",
              interp1_hits,interp2_hits,dpd_hits,interp1_hold_hits,interp1_stage0_hits,interp2_hold_hits,interp1_output_hold_hits,interp2_output_hold_hits,interp1_output_empty_hits,interp1_stage1_empty_hits,interp2_stage1_empty_hits,env.scoreboard.checked),UVM_NONE)
          end
        join
      end
      begin
        forever begin
          @(posedge vif.core_clk);
          if (vif.core_rst_n) begin
            if (vif.interp1_empty_blocked) interp1_hits++;
            if (vif.interp2_empty_blocked) interp2_hits++;
            if (vif.dpd_empty_blocked) dpd_hits++;
            if (vif.interp1_stage1_held) interp1_hold_hits++;
            if (vif.interp1_stage0_held) interp1_stage0_hits++;
            if (vif.interp2_stage1_held) interp2_hold_hits++;
            if (vif.interp1_output_held) interp1_output_hold_hits++;
            if (vif.interp2_output_held) interp2_output_hold_hits++;
            if (vif.interp1_output_empty_blocked) interp1_output_empty_hits++;
            if (vif.interp1_stage1_empty_blocked) interp1_stage1_empty_hits++;
            if (vif.interp2_stage1_empty_blocked) interp2_stage1_empty_hits++;
          end
        end
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Full-chain valid-gap test did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

// Drive only public PA ready, on its inactive clock edge. An upstream bubble
// is observed after the chain has filled: stage 1 is empty while stage 2 and
// the output still carry real transactions. No DUT state is forced.
class thermo5_sku_interp1_empty_blocked_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_interp1_empty_blocked_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.manual_pa_ready=1;
  endfunction
  task run_phase(uvm_phase phase);
    int exact_hits=0;
    phase.raise_objection(this);
    fork
      begin
        fork
          // Let the elastic chain fill before the legal source bubble.  The
          // PA stall is armed from an observed accepted-beat boundary below,
          // rather than from a guessed core-cycle phase.
          send_source(cfg.source_beats,0,24,80);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            do @(negedge vif.core_clk);
              while(env.source.monitor.accepted_beats<24 || !vif.interp1_stall_window);
            vif.pa_ready=4'h0;
            // Bound the legal stall even if this phase does not reach the
            // target; never deadlock the test while waiting for a bin.
            repeat(200) @(negedge vif.core_clk);
            vif.pa_ready=4'hf;
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            if (exact_hits==0 || vif.protocol_error ||
                env.scoreboard.source_checked!=cfg.source_beats ||
                env.source.monitor.accepted_beats!=cfg.source_beats ||
                env.monitor.stall_cycles==0)
              `uvm_fatal("EXACT_BIN","Missing interp1 state, count, or output hold evidence")
            `uvm_info("SKU_PASS",$sformatf("THERMO5_INTERP1_EMPTY_BLOCKED_UVM_PASS hits=%0d source=%0d output=%0d four_planes=bittrue",
              exact_hits,cfg.source_beats,env.scoreboard.checked),UVM_NONE)
          end
        join
      end
      begin
        forever begin
          @(posedge vif.core_clk);
          if(vif.core_rst_n && vif.core_enable && vif.interp1_stage1_empty_blocked)
            exact_hits++;
        end
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Exact interp1 state test did not drain")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

// A continuous accepted stream spans frame markers without resetting the
// datapath or counters. Every output still comes from the independent oracle.
class thermo5_sku_long_counter_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_long_counter_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    if(cfg.core_words<2072)
      `uvm_fatal("WORDS","Counter test requires at least 2072 golden words")
    cfg.random_pa_ready=1;
    cfg.pa_stall_percent=25;
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    // Finish the full independent stream check before discarding any state.
    super.run_phase(phase);
    env.control.reset_both();
    repeat(3) @(negedge vif.core_clk);
    for(int lane=0;lane<16;lane++)
      if(vif.dpd_sample_count[lane] !== 0 || vif.dpd_saturation_count[lane] !== 0)
        `uvm_fatal("DPD_RESET_COUNT",$sformatf("lane=%0d counters failed reset",lane))
    `uvm_info("SKU_PASS","THERMO5_LONG_COUNTER_RESET_PASS all 16 lane counters cleared after checked stream",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass

class thermo5_sku_fifo_empty_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_fifo_empty_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(4);
          begin
            wait(env.source.monitor.accepted_beats==4);
            env.control.core_on();
            wait(env.scoreboard.checked==7);
            wait(vif.underflow===1'b1);
            if (vif.protocol_error) `uvm_fatal("FIFO_EMPTY","Starvation corrupted frame protocol")
            if (env.coverage.underflow_cycles==0) @(posedge vif.core_clk);
            if (env.coverage.underflow_cycles==0)
              `uvm_fatal("COVERAGE","FIFO empty/underflow was not observed")
            `uvm_info("SKU_PASS","THERMO5_FIFO_EMPTY_UVM_PASS 7 bittrue words then sticky underflow",UVM_NONE)
          end
        join
      end
      begin
        repeat(1000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","FIFO starvation did not assert underflow")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

class thermo5_sku_reset_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_reset_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(24);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.source.monitor.accepted_beats==24 && env.scoreboard.checked>=4);
          end
        join
        @(negedge vif.core_clk);
        // Assert both resets while enable is high to exercise the two
        // reset-with-enable condition bins at each interpolation instance.
        env.control.reset_both(1'b1);
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            if (env.scoreboard.reset_epochs!=1 || env.coverage.reset_reassertions==0)
              `uvm_fatal("RESET_REPLAY","Reset epoch was not observed")
            check_full(0);
            `uvm_info("SKU_PASS","THERMO5_RESET_UVM_PASS reset discards partial frame; replay is bittrue",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Reset replay did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

class thermo5_sku_reset_sweep_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_reset_sweep_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    int target_residual[5]='{2,4,6,10,12};
    phase.raise_objection(this);
    fork
      begin
        for (int epoch=0;epoch<5;epoch++) begin
          fork
            send_source(24);
            begin
              wait(env.source.monitor.accepted_beats>=4);
              env.control.core_on();
              wait(env.source.monitor.accepted_beats==24);
            end
          join
          wait(vif.cdc_residual==target_residual[epoch]);
          @(negedge vif.core_clk);
          if (vif.cdc_residual!=target_residual[epoch])
            `uvm_fatal("RESET_STATE","CDC residual changed before reset edge")
          env.control.reset_both();
          if (vif.cdc_residual!=0)
            `uvm_fatal("RESET_STATE","CDC residual did not reset to zero")
        end
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full(0);
            if (env.scoreboard.reset_epochs!=5 || env.coverage.reset_reassertions!=5)
              `uvm_fatal("RESET_SWEEP","Five reset epochs were not observed")
            `uvm_info("SKU_PASS","THERMO5_RESET_SWEEP_UVM_PASS five residual resets and 56-word replay",UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Reset residual sweep did not complete")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass

class thermo5_sku_illegal_frame_test extends thermo5_sku_bittrue_test;
  `uvm_component_utils(thermo5_sku_illegal_frame_test)
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.illegal_frame=1;
    cfg.expect_pa=0;
  endfunction
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats,1);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(vif.protocol_error===1'b1);
            if (env.coverage.protocol_error_cycles==0) @(posedge vif.core_clk);
            if (env.coverage.protocol_error_cycles==0)
              `uvm_fatal("COVERAGE","Illegal-frame sticky error was not sampled")
            `uvm_info("NEGATIVE","THERMO5_ILLEGAL_FRAME_OBSERVED; expected RTL assertion must also appear",UVM_NONE)
            // Finish the legal bus sequence before opening a new reset epoch;
            // otherwise the driver resumes a partial old frame after reset.
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            @(negedge vif.core_clk);
            env.control.reset_both();
            repeat(3) @(negedge vif.core_clk);
            if (vif.protocol_error !== 1'b0)
              `uvm_fatal("PROTOCOL_RESET","Sticky protocol error failed public reset")
            `uvm_info("NEGATIVE","THERMO5_PROTOCOL_ERROR_RESET_PASS sticky error cleared by public reset",UVM_NONE)
          end
        join
      end
      begin
        repeat(1000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Misaligned frame_start was not rejected")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
