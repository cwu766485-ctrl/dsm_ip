// Public reset after a short checked prefix, followed by full oracle replay.
// Delay is measured from accepted traffic, not a free-running absolute cycle.
class thermo5_sku_fifo_reset_phase_test extends thermo5_sku_base_test;
  `uvm_component_utils(thermo5_sku_fifo_reset_phase_test)
  function new(string name,uvm_component parent); super.new(name,parent); endfunction
  task run_phase(uvm_phase phase);
    int delay_cycles=0;
    int prefix_beats=4;
    int fwft_stage1_edges=0;
    int fwft_stage1_reset_edges=0;
    int fwft_stage1_to_invalid=0;
    bit prefetch_only, core_first_release, wait_fwft_stage1;
    void'($value$plusargs("FIFO_RESET_DELAY=%d",delay_cycles));
    prefetch_only=$test$plusargs("FIFO_RESET_PREFETCH_ONLY");
    core_first_release=$test$plusargs("FIFO_RESET_CORE_FIRST");
    wait_fwft_stage1=$test$plusargs("FIFO_RESET_WAIT_FWFT_STAGE1");
    if(prefetch_only) prefix_beats=1;
    // Longer delays drain the deliberately truncated prefix and starve it;
    // that is a separate underflow test, not this pre-empty reset test.
    if(delay_cycles<0 || delay_cycles>(prefetch_only ? 24 : 11))
      `uvm_fatal("RESET_PHASE_RANGE","Use FIFO_RESET_DELAY in 0..11 before prefix starvation")
    phase.raise_objection(this);
    fork
      begin
        send_source(prefix_beats);
        if(wait_fwft_stage1) begin
          if(!prefetch_only)
            `uvm_fatal("FWFT_TARGET","FWFT target requires prefetch-only mode")
          wait(vif.xpm_fwft_state===2'b10);
          if(vif.xpm_rd_rst_i!==1'b0)
            `uvm_fatal("FWFT_TARGET","Target state reached while XPM read reset was active")
          `uvm_info("FWFT_TARGET","Observed stage1_valid with rd_rst_i=0 before common public reset",UVM_NONE)
          // Assert the legal common public reset immediately after observing
          // stage1_valid. Waiting another core edge can let the transient
          // vendor FWFT state advance before the reset reaches rd_rst_i.
          env.control.reset_both(1'b0,core_first_release);
        end
        // A single accepted beat prefetches into vendor FWFT while the
        // public core remains stopped. Reset can target the first stage
        // without starving a running frontend or touching internal state.
        if(!wait_fwft_stage1) begin
          if(!prefetch_only) env.control.core_on();
          repeat(delay_cycles) @(negedge vif.core_clk);
          @(negedge vif.core_clk);
          env.control.reset_both(1'b0,core_first_release);
        end
        // Finish the previous vendor reset sequence before replay traffic.
        repeat(40) @(negedge vif.src_clk);
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=4);
            env.control.core_on();
            wait(env.scoreboard.checked==cfg.core_words);
            env.control.core_off();
            check_full(0);
            if(env.scoreboard.reset_epochs!=1)
              `uvm_fatal("RESET_EPOCH","Expected one public reset epoch")
            `uvm_info("SKU_PASS",$sformatf("THERMO5_FIFO_RESET_PHASE_UVM_PASS delay=%0d core_first_release=%0d output=%0d four_planes=bittrue fwft_stage1_edges=%0d fwft_stage1_reset_edges=%0d fwft_stage1_to_invalid=%0d",delay_cycles,core_first_release,env.scoreboard.checked,fwft_stage1_edges,fwft_stage1_reset_edges,fwft_stage1_to_invalid),UVM_NONE)
          end
        join
      end
      begin
        repeat(10000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","FIFO reset phase replay did not complete")
      end
      begin : fwft_edge_observer
        if($test$plusargs("FIFO_RESET_EDGE_OBSERVE")) begin
          forever begin : sample_fwft_at_core_edge
            logic [1:0] state_before;
            logic [1:0] state_after;
            bit rd_reset_before;
            @(posedge vif.core_clk);
            // Sample pre-NBA state/reset at the active clock edge, then the
            // post-NBA state one precision step later. The target transition
            // is exactly stage1_valid(2) -> invalid(0) with rd_rst_i asserted.
            state_before=vif.xpm_fwft_state;
            rd_reset_before=vif.xpm_rd_rst_i;
            if(state_before===2'b10) fwft_stage1_edges++;
            if(state_before===2'b10 && rd_reset_before===1'b1)
              fwft_stage1_reset_edges++;
            #1ps;
            state_after=vif.xpm_fwft_state;
            if(state_before===2'b10 && rd_reset_before===1'b1 &&
               state_after===2'b00)
              fwft_stage1_to_invalid++;
            if(state_before===2'b10 || rd_reset_before===1'b1 ||
               state_after===2'b00 && state_before===2'b10)
              $display("THERMO5_FWFT_EDGE t=%0t pre_state=%0b rd_rst_i=%0b post_state=%0b public_src_rst_n=%0b public_core_rst_n=%0b",
                $time,state_before,rd_reset_before,state_after,vif.src_rst_n,vif.core_rst_n);
          end
        end else begin
          forever @(posedge vif.core_clk);
        end
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
