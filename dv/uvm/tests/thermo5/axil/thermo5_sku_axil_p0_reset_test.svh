class thermo5_sku_axil_p0_reset_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_p0_reset_test)
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  virtual function void configure_case();
    super.configure_case();cfg.frame_starts=1;cfg.ef2_reference_enable=1;
    if(cfg.core_words!=56) `uvm_fatal("P0_RESET_CONFIG","Use56 words/single frame")
  endfunction
  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit target,drained;
    phase.raise_objection(this);
    fork
      begin
        wait(vif.src_rst_n && vif.core_rst_n);
        wait_axil_reset_release();
        env.pa_sink.set_ready(4'h0);
        fork
          send_source(24);
          begin
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_RESET_RUN","RUN rejected")
          end
        join
        target=0;
        for(int n=0;n<2000 && !target;n++) begin
          @(negedge vif.core_clk);
          target=(vif.pa_valid==4'hf && vif.pa_ready==0 && vif.ef2_state_zero!=4'hf);
        end
        if(!target) `uvm_fatal("P0_RESET_STATE","No stalled output with nonzero EF2 state")
        axil_write(8'h10,32'd12288,0,0,resp);
        if(resp!=0) `uvm_fatal("P0_RESET_COEFF","Coefficient rejected")
        axil_write(8'h00,32'h3,0,0,resp);
        if(resp!=0) `uvm_fatal("P0_RESET_COMMIT","COMMIT rejected")
        target=0;
        for(int n=0;n<100 && !target;n++) begin
          @(negedge vif.core_clk);target=vif.cfg_pending_valid;
        end
        if(!(target && vif.pa_valid==4'hf && vif.pa_ready==0 &&
             vif.ef2_state_zero!=4'hf && !vif.dpd_config_boundary && !vif.cfg_ack_core))
          `uvm_fatal("P0_RESET_OVERLAP","Pending/state/stall conjunction missing before reset")
        `uvm_info("P0_RESET_WITNESS",$sformatf("pending=1 pa_valid=f pa_ready=0 ef2_zero_mask=%h e1i0=%0d e2i0=%0d e1q0=%0d e2q0=%0d",vif.ef2_state_zero,vif.ef2_err1_i[0],vif.ef2_err2_i[0],vif.ef2_err1_q[0],vif.ef2_err2_q[0]),UVM_NONE)
        env.control.reset_both();
        wait_axil_reset_release();
        if(vif.cfg_pending_valid || vif.cfg_busy || vif.ef2_state_zero!=4'hf ||
           vif.cfg_active_payload[383:320]!=64'd16384)
          `uvm_fatal("P0_RESET_CLEAR","Reset did not clear pending/state or restore Identity")
        env.pa_sink.set_ready(4'hf);
        fork
          send_source(cfg.source_beats);
          begin
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_RESET_REPLAY_RUN","RUN rejected")
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            axil_write(8'h00,32'd0,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_RESET_STOP","STOP rejected")
            for(int n=0;n<12000 && env.scoreboard.checked!=cfg.core_words;n++) @(posedge vif.core_clk);
            check_full(0);
            drained=0;
            for(int n=0;n<1000 && !drained;n++) begin
              axil_read(8'h04,status,resp);drained=resp==0 && status[4:3]==0;
            end
            if(!drained || vif.underflow || vif.protocol_error) `uvm_fatal("P0_RESET_RESULT","Postreset drain/diagnostic failure")
          end
        join
        `uvm_info("SKU_PASS","P0_RESET_PASS pending config/nonzero EF2/stalled PA reset;56-word independent replay",UVM_NONE)
      end
      begin repeat(20000) @(posedge vif.core_clk);`uvm_fatal("TIMEOUT","P0 reset progress watchdog") end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
