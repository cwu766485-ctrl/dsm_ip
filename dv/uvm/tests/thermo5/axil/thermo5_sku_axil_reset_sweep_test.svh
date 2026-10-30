// Product-configured AXI-Lite reset sweep for the 14:8 CDC residual counter.
// Each reset is initiated through the common reset BFM after a legal source
// prefix and a public RUN-register write; a complete oracle replay checks the
// post-reset datapath.
class thermo5_sku_axil_reset_sweep_test extends thermo5_sku_axil_base_test;
  `uvm_component_utils(thermo5_sku_axil_reset_sweep_test)

  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction

  task run_phase(uvm_phase phase);
    int target_residual[5]='{2,4,6,10,12};
    bit [1:0] resp;

    phase.raise_objection(this);
    vif.pa_ready=4'hf;
    wait(vif.src_rst_n && vif.core_rst_n);
    if (vif.dpd_active_taps!==3'd1)
      `uvm_fatal("PRODUCT_DPD_CONFIG",
        $sformatf("Expected product identity DPD with one active tap, got %0d",
          vif.dpd_active_taps))

    for (int epoch=0;epoch<5;epoch++) begin
      fork
        send_source(24);
        begin
          wait(env.source.monitor.accepted_beats>=4);
          axil_write(8'h00,32'h1,0,0,resp);
          if (resp!=2'b00)
            `uvm_fatal("RESET_SWEEP_RUN",
              $sformatf("Could not start product stream for epoch %0d",epoch))
          wait(env.source.monitor.accepted_beats==24);
        end
      join

      begin
        bit target_seen;
        target_seen=0;
        for (int cycles=0;cycles<20000 && !target_seen;cycles++) begin
          @(negedge vif.core_clk);
          target_seen=(vif.cdc_residual==target_residual[epoch]);
        end
        if (!target_seen)
          `uvm_fatal("RESET_SWEEP_TIMEOUT",
            $sformatf("Did not reach residual state %0d",target_residual[epoch]))
      end
      env.control.reset_both();
      if (vif.cdc_residual!=0)
        `uvm_fatal("RESET_SWEEP_CLEAR",
          $sformatf("Residual did not clear for epoch %0d",epoch))
    end

    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=4);
        axil_write(8'h00,32'h1,0,0,resp);
        if (resp!=2'b00)
          `uvm_fatal("RESET_SWEEP_REPLAY_RUN",
            "Could not start the complete post-reset product replay")
        wait(env.source.monitor.accepted_beats>=20);
        axil_write(8'h00,32'h0,0,1,resp);
        if (resp!=2'b00)
          `uvm_fatal("RESET_SWEEP_REPLAY_STOP",
            "Could not request graceful drain for the complete replay")
        for (int cycles=0;cycles<20000 &&
             env.scoreboard.checked!=cfg.core_words;cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("RESET_SWEEP_REPLAY_TIMEOUT",
            $sformatf("Replay ended at %0d/%0d output words",
              env.scoreboard.checked,cfg.core_words))
      end
    join

    check_full(0);
    if (env.scoreboard.reset_epochs!=5 || env.coverage.reset_reassertions!=5)
      `uvm_fatal("RESET_SWEEP_COUNT",
        $sformatf("Expected five reset epochs; scoreboard=%0d monitor=%0d",
          env.scoreboard.reset_epochs,env.coverage.reset_reassertions))
    if (vif.protocol_error || vif.underflow)
      `uvm_fatal("RESET_SWEEP_DIAGNOSTIC",
        "Protocol error or underflow observed during reset sweep/replay")
    `uvm_info("SKU_PASS",
      "THERMO5_AXIL_RESET_SWEEP_UVM_PASS five legal residual resets and complete four-plane bit-true replay",
      UVM_NONE)
    phase.drop_objection(this);
  endtask
endclass
