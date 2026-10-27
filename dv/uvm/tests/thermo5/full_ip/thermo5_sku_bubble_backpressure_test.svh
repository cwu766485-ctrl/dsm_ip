

// Full-chain AXI valid gap: creates legal pipeline bubbles without forcing
// DUT internals. The original four-plane MATLAB oracle remains active.
class thermo5_sku_bubble_backpressure_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_bubble_backpressure_test)
  int interp1_hits, interp2_hits, dpd_hits, interp1_hold_hits, interp1_stage0_hits;
  int interp2_hold_hits, interp1_output_hold_hits, interp2_output_hold_hits;
  int interp1_output_empty_hits, interp1_stage1_empty_hits, interp2_stage1_empty_hits;
  int partial_ready_hits;
  int gap_beat=4, gap_length=80;
  bit require_interp1_stage1_empty=0;
  // A zero-length initial hold lets the source bubble meet partial PA
  // backpressure. A long 100% hold masks two legal empty/blocked states.
  int hold_pa_cycles=0;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  virtual function void configure_case();
    super.configure_case();
    cfg.random_pa_ready=1;
    cfg.manual_pa_ready=1;
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
            if (partial_ready_hits==0 || env.coverage.pa_partial_ready_stall_cycles==0 ||
                env.coverage.plane_atomic_cg.get_coverage()<100.0)
              `uvm_fatal("PLANE_ATOMICITY_COVERAGE",
                $sformatf("partial_ready=%0d partial_stalls=%0d atomic_cross=%.1f",
                  partial_ready_hits,env.coverage.pa_partial_ready_stall_cycles,
                  env.coverage.plane_atomic_cg.get_coverage()))
`ifdef THERMO5_CENTERED_CUBIC
            // The centered-cubic implementation is a two-entry look-ahead
            // queue, not the causal FIR's s0/s1/s2/s3 pipeline. Its meaningful
            // stall bins are the externally visible held output words; internal
            // causal-stage empty/hold bins are intentionally not fabricated.
            if (interp2_hits==0 || interp1_output_hold_hits==0 ||
                interp2_output_hold_hits==0 || env.coverage.pa_stall_cycles==0)
`else
            if (interp1_hits==0 || interp2_hits==0 || dpd_hits==0 ||
                interp1_hold_hits==0 || interp1_stage0_hits==0 || interp2_hold_hits==0 ||
                interp1_output_hold_hits==0 || interp2_output_hold_hits==0 ||
                interp1_output_empty_hits==0 ||
                (require_interp1_stage1_empty && interp1_stage1_empty_hits==0) ||
                interp2_stage1_empty_hits==0)
`endif
              `uvm_fatal("BUBBLE_COVERAGE",$sformatf("missing state i1=%0d i2=%0d dpd=%0d i1_s1=%0d i1_s0=%0d i2_s1=%0d i1_out=%0d i2_out=%0d i1_out_empty=%0d i1_s1_empty=%0d i2_s1_empty=%0d",
                interp1_hits,interp2_hits,dpd_hits,interp1_hold_hits,interp1_stage0_hits,interp2_hold_hits,interp1_output_hold_hits,interp2_output_hold_hits,interp1_output_empty_hits,interp1_stage1_empty_hits,interp2_stage1_empty_hits))
            `uvm_info("SKU_PASS",$sformatf("THERMO5_BUBBLE_BACKPRESSURE_UVM_PASS i1=%0d i2=%0d dpd=%0d i1_s1=%0d i1_s0=%0d i2_s1=%0d i1_out=%0d i2_out=%0d i1_out_empty=%0d i1_s1_empty=%0d i2_s1_empty=%0d words=%0d",
              interp1_hits,interp2_hits,dpd_hits,interp1_hold_hits,interp1_stage0_hits,interp2_hold_hits,interp1_output_hold_hits,interp2_output_hold_hits,interp1_output_empty_hits,interp1_stage1_empty_hits,interp2_stage1_empty_hits,env.scoreboard.checked),UVM_NONE)
          end
        join
      end
      begin
        int ready_phase;
        ready_phase=0;
        wait(vif.core_rst_n);
        forever begin
          @(negedge vif.core_clk);
          case (ready_phase % 4)
            0: vif.pa_ready=4'hf;
            1: vif.pa_ready=4'b1110;
            2: vif.pa_ready=4'h0;
            default: vif.pa_ready=4'b1011;
          endcase
          ready_phase++;
        end
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
            if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf && vif.pa_ready!=4'h0)
              partial_ready_hits++;
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
