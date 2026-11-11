// P0 overlap uses only public drivers; hierarchical reads are observation only.
class thermo5_sku_axil_p0_overlap_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_p0_overlap_test)
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  virtual function void configure_case();
    super.configure_case();
    if(cfg.core_words!=112) `uvm_fatal("P0_CONFIG","Use112 words/two56-word frames")
    cfg.frame_starts=2;
    cfg.ef2_reference_enable=1;
  endfunction
  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit target, drained;
    uvm_hdl_data_t start_bit,valid_bit;
    phase.raise_objection(this);
    fork
      begin
        env.pa_sink.set_ready(4'h0);
        fork
          send_source(cfg.source_beats);
          begin
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            wait(env.source.monitor.accepted_beats>=16);
            axil_write(8'h00,32'h1,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_RUN","RUN rejected")
            target=0;
            for(int n=0;n<2000 && !target;n++) begin
              @(negedge vif.core_clk);
              target=vif.pa_valid==4'hf && vif.pa_ready==0 && vif.dpd_sample_count[0]>0;
            end
            if(!target || env.scoreboard.checked!=0)
              `uvm_fatal("P0_OLD_DATA","Old Identity output did not become blocked")
            axil_write(8'h10,32'd12288,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_COEFF","Nonidentity coefficient rejected")
            axil_write(8'h00,32'h3,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_COMMIT","RUN+COMMIT rejected")
            target=0;
            for(int n=0;n<100 && !target;n++) begin
              @(negedge vif.core_clk);target=vif.cfg_pending_valid;
            end
            if(!target || vif.cfg_ack_core) `uvm_fatal("P0_PENDING","New config did not wait for second boundary")
            env.pa_sink.set_ready(4'hf);
            target=0;
            for(int n=0;n<4000 && !target;n++) begin
              @(negedge vif.core_clk);
              if(!uvm_hdl_read("thermo5_sku_uvm_tb.dut.u_frontend.i1_frame_start",start_bit) ||
                 !uvm_hdl_read("thermo5_sku_uvm_tb.dut.u_frontend.i1_valid",valid_bit))
                `uvm_fatal("P0_OBSERVE","Read-only DPD boundary probe unavailable")
              target=(start_bit[0]===1'b1 && valid_bit[0]===1'b1 && vif.cfg_pending_valid);
            end
            if(!target) `uvm_fatal("P0_BOUNDARY_WAIT","Second pending boundary not presented")
            // At the falling edge, stop PA before the upcoming real boundary.
            // Internal elasticity allows the DPD input handshake to proceed.
            env.pa_sink.set_ready(4'h0);
            // set_ready returns on the first posedge observing requested ready;
            // that edge itself may be the accepted boundary (do not skip it).
            target=vif.dpd_config_boundary;
            for(int n=0;n<32 && !target;n++) begin
              @(posedge vif.core_clk);target=vif.dpd_config_boundary;
            end
            if(!(target && vif.dpd_config_boundary && vif.cfg_pending_valid &&
                 vif.pa_valid==4'hf && vif.pa_ready==0 && env.scoreboard.checked<56 &&
                 vif.cfg_active_payload[383:320]==64'd16384))
              `uvm_fatal("P0_OVERLAP_MISS","Boundary/pending/stalled old-config data did not actually overlap")
            `uvm_info("P0_OVERLAP_WITNESS",$sformatf("boundary=1 pending=1 pa_valid=f pa_ready=0 old_pa_accepted=%0d old_frame_words=56 dpd_accepted=%0d active_c1=16384 new_c1=12288",env.scoreboard.checked,vif.dpd_sample_count[0]),UVM_NONE)
            repeat(4) @(negedge vif.core_clk);
            env.pa_sink.set_ready(4'hf);
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            axil_write(8'h00,32'd0,0,0,resp);
            if(resp!=0) `uvm_fatal("P0_STOP","STOP rejected")
            for(int n=0;n<12000 && env.scoreboard.checked!=cfg.core_words;n++) @(posedge vif.core_clk);
            check_full();
            drained=0;
            for(int n=0;n<1000 && !drained;n++) begin
              axil_read(8'h04,status,resp);drained=(resp==0 && status[4:3]==0);
            end
            if(!drained || vif.underflow || vif.protocol_error ||
               vif.cfg_active_payload[383:320]!=64'd12288)
              `uvm_fatal("P0_RESULT","Configuration/diagnostic/drain failure")
            `uvm_info("SKU_PASS","P0_OVERLAP_PASS old/new config boundary overlaps stalled old output;112 four-plane words checked",UVM_NONE)
          end
        join
      end
      begin repeat(20000) @(posedge vif.core_clk);`uvm_fatal("TIMEOUT","P0 overlap progress watchdog") end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
