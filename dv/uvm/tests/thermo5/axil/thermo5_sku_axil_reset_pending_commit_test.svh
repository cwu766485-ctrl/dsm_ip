// Verify that common reset aborts a legal, un-applied non-identity COMMIT.
// The next reset epoch is checked against the product Identity static vectors
// and the independent transaction-derived Python trace model.
class thermo5_sku_axil_reset_pending_commit_test extends thermo5_sku_axil_product_identity_test;
  `uvm_component_utils(thermo5_sku_axil_reset_pending_commit_test)

  int unsigned prefix_beats;
  int signed pending_c1_re_q14;

  covergroup reset_pending_cg with function sample(int prefix_class,
                                                    int coeff_class,
                                                    bit reset_while_pending);
    option.per_instance = 1;
    cp_prefix_class: coverpoint prefix_class {
      bins short_prefix = {0};
      bins long_prefix = {1};
    }
    cp_coeff_class: coverpoint coeff_class {
      bins attenuate = {0};
      bins boost = {1};
    }
    cp_reset_while_pending: coverpoint reset_while_pending {
      bins observed = {1};
      illegal_bins missed = {0};
    }
    x_reset_pending_config: cross cp_prefix_class, cp_coeff_class,
                                  cp_reset_while_pending;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name,parent);
    reset_pending_cg = new();
  endfunction

  virtual function void configure_case();
    super.configure_case();
    prefix_beats=8;
    pending_c1_re_q14=12288;
    void'($value$plusargs("THERMO5_RESET_PREFIX_BEATS=%d",prefix_beats));
    void'($value$plusargs("THERMO5_PENDING_C1_RE_Q14=%d",pending_c1_re_q14));
    if (prefix_beats<1 || prefix_beats>15 ||
        (pending_c1_re_q14!=12288 && pending_c1_re_q14!=20480))
      `uvm_fatal("RESET_PENDING_CONFIG",
        "Use a 1..15 beat prefix and a prequalified attenuating/boosting one-tap image")
  endfunction

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] status;
    bit drained;
    int prefix_class;
    int coeff_class;
    bit pending_before_reset;

    prefix_class=(prefix_beats<8) ? 0 : 1;
    coeff_class=(pending_c1_re_q14<16384) ? 0 : 1;
    phase.raise_objection(this);
    env.pa_sink.set_ready(4'hf);
    wait(vif.src_rst_n && vif.core_rst_n);
    wait_axil_reset_release();

    send_source(prefix_beats);
    if (env.source.monitor.accepted_beats!=prefix_beats)
      `uvm_fatal("RESET_PENDING_PREFIX","Source prefix was not fully accepted")
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("RESET_PENDING_TAPS","One-tap product setting was rejected")
    axil_write(8'h10,{16'd0,pending_c1_re_q14[15:0]},0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("RESET_PENDING_COEFF","Legal non-identity coefficient write failed")
    axil_write(8'h14,32'd0,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("RESET_PENDING_COEFF_HIGH","Coefficient high-word write failed")
    axil_write(8'h00,32'h2,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("RESET_PENDING_COMMIT","Legal COMMIT was rejected")

    pending_before_reset=0;
    for (int cycles=0;cycles<100 && !pending_before_reset;cycles++) begin
      @(posedge vif.core_clk);
      pending_before_reset=(vif.cfg_pending_valid===1'b1);
    end
    if (!pending_before_reset || vif.dpd_config_boundary)
      `uvm_fatal("RESET_PENDING_NOT_HELD",
        "COMMIT did not remain pending without a RUN-driven frame boundary")

    env.control.reset_both();
    wait_axil_reset_release();
    if (vif.cfg_pending_valid!==1'b0 || vif.cfg_busy!==1'b0 ||
        vif.cfg_active_payload!==configured_payload())
      `uvm_fatal("RESET_PENDING_CLEAR",
        "Reset did not clear pending COMMIT and restore the product Identity image")
    reset_pending_cg.sample(prefix_class,coeff_class,pending_before_reset);

    fork
      send_source(cfg.source_beats);
      begin
        wait(env.source.monitor.accepted_beats>=16);
        axil_write(8'h00,32'h1,0,0,resp);
        if (resp!=2'b00)
          `uvm_fatal("RESET_PENDING_RUN","Post-reset RUN request was rejected")
        wait(env.source.monitor.accepted_beats==cfg.source_beats);
        axil_write(8'h00,32'd0,0,0,resp);
        if (resp!=2'b00)
          `uvm_fatal("RESET_PENDING_STOP","Post-reset STOP request was rejected")
        for (int cycles=0;cycles<12000 &&
             env.scoreboard.checked!=cfg.core_words;cycles++)
          @(posedge vif.core_clk);
        if (env.scoreboard.checked!=cfg.core_words)
          `uvm_fatal("RESET_PENDING_REPLAY_TIMEOUT",
            $sformatf("Post-reset replay ended at %0d/%0d PA words",
              env.scoreboard.checked,cfg.core_words))
        check_full(0);
        drained=0;
        for (int polls=0;polls<1000 && !drained;polls++) begin
          axil_read(8'h04,status,resp);
          if (resp!=2'b00)
            `uvm_fatal("RESET_PENDING_STATUS","Post-reset STATUS read failed")
          drained=(status[4:3]==2'b00);
        end
        if (!drained || vif.protocol_error || vif.underflow)
          `uvm_fatal("RESET_PENDING_RESULT",
            "Post-reset product replay failed drain or protocol/underflow checks")
        `uvm_info("SKU_PASS",
          "THERMO5_AXIL_RESET_PENDING_COMMIT_UVM_PASS: reset aborted pending non-identity COMMIT; post-reset four-plane Identity replay matched",
          UVM_NONE)
      end
    join
    phase.drop_objection(this);
  endtask
endclass
