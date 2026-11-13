// Reset through public reset pins while genuine downstream backpressure holds
// the product. Then replay a complete independent Identity oracle epoch.
class thermo5_sku_axil_stalled_reset_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_stalled_reset_test)
  function new(string name,uvm_component parent);super.new(name,parent);endfunction
  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit stalled;
    uvm_hdl_data_t tail_output, tail_ready;
    bit tail_reset;
    tail_reset=$test$plusargs("THERMO5_RESET_AT_READY_TAIL");
    phase.raise_objection(this);
    wait(vif.src_rst_n && vif.core_rst_n);
    env.pa_sink.set_ready(tail_reset ? 4'hf : 4'h0);
    fork
      begin
        send_source(24);
      end
      begin
        wait(env.source.monitor.accepted_beats>=16);
        axil_write(8'h00,32'h1,0,0,resp);
        if(resp!=0) `uvm_fatal("STALL_RESET_RUN","RUN rejected")
      end
    join
    stalled=0;
    for(int cycles=0;cycles<2000 && !stalled;cycles++) begin
      @(negedge vif.core_clk);
      if (tail_reset) begin
        // Read-only observation; all stimulus uses public product ports.
        if (!uvm_hdl_read("thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.tail_output",tail_output) ||
            !uvm_hdl_read("thermo5_sku_uvm_tb.dut.u_frontend.g_interp1_centered.u_interp_1.out_ready",tail_ready))
          `uvm_fatal("TAIL_RESET_OBSERVE","Cannot observe target tail handshake")
        stalled=(tail_output[0]===1'b1 && tail_ready[0]===1'b1);
      end else stalled=vif.pa_valid==4'hf && vif.pa_ready==0;
    end
    if(!stalled) `uvm_fatal("STALL_RESET_TARGET","Requested public-reset precondition not reached")
    if (!tail_reset) repeat(40) @(negedge vif.core_clk);
    else `uvm_info("TAIL_RESET_TARGET","Stage1 tail_output=1 out_ready=1 before public reset",UVM_NONE)
    env.control.reset_both();
    wait_axil_reset_release();
    env.pa_sink.set_ready(4'hf);
    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=16);
        axil_write(8'h00,32'h1,0,0,resp);
        if(resp!=0) `uvm_fatal("STALL_RESET_REPLAY_RUN","RUN rejected")
        wait(env.source.monitor.accepted_beats==cfg.source_beats);
        axil_write(8'h00,32'h0,0,0,resp);
        if(resp!=0) `uvm_fatal("STALL_RESET_STOP","STOP rejected")
        for(int cycles=0;cycles<12000 && env.scoreboard.checked!=cfg.core_words;cycles++)
          @(posedge vif.core_clk);
        if(env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("STALL_RESET_TIMEOUT","Post-reset oracle replay incomplete")
      end
    join
    check_full(0);
    if(vif.protocol_error || vif.underflow)
      `uvm_fatal("STALL_RESET_DIAGNOSTIC","Unexpected product diagnostic")
    `uvm_info("SKU_PASS","THERMO5_STALLED_RESET_PASS: public stalled reset and complete four-plane replay",UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
