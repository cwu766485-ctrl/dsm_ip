// Product MAX_TAPS=1 system-random DPD qualification. The Python vector
// generator and this AXI-Lite programming sequence receive the same explicit
// Q2.14 coefficient, gain class, and input profile for each replayable seed.
class thermo5_sku_axil_random_dpd_bittrue_test extends thermo5_sku_axil_nonlinear_bittrue_test;
  `uvm_component_utils(thermo5_sku_axil_random_dpd_bittrue_test)

  int signed c1_re_q14;
  int signed c1_im_q14;
  int signed c3_re_q14;
  int signed c5_re_q14;
  int unsigned dpd_class_id;
  int unsigned gain_class_id;
  int unsigned input_profile_id;
  bit commit_after_first_boundary;
  bit require_commit_boundary_stall;
  bit commit_apply_seen;
  bit commit_stall_seen;
  bit commit_issued;
  bit stop_issued;
  bit status_checked;

  covergroup commit_boundary_stall_cg with function sample(int commit_timing,
                                                            bit boundary_apply,
                                                            bit pa_stall);
    option.per_instance = 1;
    cp_commit_timing: coverpoint commit_timing {
      bins before_run = {0};
      bins after_first_boundary = {1};
    }
    cp_boundary_apply: coverpoint boundary_apply {
      bins applied = {1};
      illegal_bins not_applied = {0};
    }
    cp_pa_stall: coverpoint pa_stall {
      bins observed = {1};
      illegal_bins absent = {0};
    }
    x_commit_boundary_stall: cross cp_commit_timing,
                                  cp_boundary_apply, cp_pa_stall;
  endgroup

  covergroup status_commit_stop_cg with function sample(bit commit_seen,
                                                         bit stop_seen,
                                                         bit status_seen);
    option.per_instance = 1;
    cp_commit: coverpoint commit_seen {
      bins observed = {1}; illegal_bins absent = {0};
    }
    cp_stop: coverpoint stop_seen {
      bins observed = {1}; illegal_bins absent = {0};
    }
    cp_status: coverpoint status_seen {
      bins observed = {1}; illegal_bins absent = {0};
    }
    x_status_commit_stop: cross cp_status, cp_commit, cp_stop;
  endgroup

  covergroup random_cfg_cg with function sample(int dpd_class,
                                                 int gain_class,
                                                 int input_profile);
    option.per_instance = 1;
    cp_dpd_class: coverpoint dpd_class {
      bins attenuation = {0};
      bins identity = {1};
      bins boost = {2};
      bins cubic = {3};
      bins quintic = {4};
    }
    cp_gain_class: coverpoint gain_class {
      bins low = {0};
      bins nominal = {1};
      bins high = {2};
    }
    cp_input_profile: coverpoint input_profile {
      bins random = {0};
      bins extreme = {1};
      bins range_stress = {2};
      bins ef2_saturation = {3};
    }
    x_dpd_gain_profile: cross cp_dpd_class, cp_gain_class, cp_input_profile;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name,parent);
    random_cfg_cg = new();
    commit_boundary_stall_cg = new();
    status_commit_stop_cg = new();
  endfunction

  virtual function void configure_case();
    super.configure_case();
    cfg.ef2_reference_enable=1'b1;
    // Vector sets may describe one or multiple DSP frame starts inside one
    // packet. Keep the test expectation explicit and tied to that vector set.
    void'($value$plusargs("THERMO5_EXPECT_FRAME_STARTS=%d",cfg.frame_starts));
    cfg.expect_pa = 1'b1;
    cfg.random_pa_ready = 1'b0;
    cfg.random_partial_pa_ready = 1'b0;
    cfg.manual_pa_ready = 1'b1;
    cfg.pa_stall_percent = 25;
    void'($value$plusargs("THERMO5_DPD_C1_RE_Q14=%d",c1_re_q14));
    void'($value$plusargs("THERMO5_DPD_C1_IM_Q14=%d",c1_im_q14));
    void'($value$plusargs("THERMO5_DPD_C3_RE_Q14=%d",c3_re_q14));
    void'($value$plusargs("THERMO5_DPD_C5_RE_Q14=%d",c5_re_q14));
    if (!$value$plusargs("THERMO5_DPD_CLASS_ID=%d",dpd_class_id)) begin
      if (c3_re_q14 != 0 && c5_re_q14 == 0) dpd_class_id=3;
      else if (c5_re_q14 != 0 && c3_re_q14 == 0) dpd_class_id=4;
      else if (c1_re_q14 < 16384) dpd_class_id=0;
      else if (c1_re_q14 == 16384) dpd_class_id=1;
      else dpd_class_id=2;
    end
    void'($value$plusargs("THERMO5_GAIN_CLASS_ID=%d",gain_class_id));
    void'($value$plusargs("THERMO5_INPUT_PROFILE_ID=%d",input_profile_id));
    commit_after_first_boundary=$test$plusargs("THERMO5_COMMIT_AFTER_FIRST_BOUNDARY");
    require_commit_boundary_stall=$test$plusargs("THERMO5_REQUIRE_COMMIT_BOUNDARY_STALL");
    if (c1_re_q14 < 8192 || c1_re_q14 > 20480 || c1_im_q14 != 0 ||
        c3_re_q14 < -2048 || c3_re_q14 > 2048 ||
        c5_re_q14 < -8192 || c5_re_q14 > 8192 || dpd_class_id > 4)
      `uvm_fatal("RANDOM_DPD_COEFF",
        "One-tap C1/C3/C5 coefficients exceed the prequalified real Q2.14 ranges")
    case (dpd_class_id)
      0: if (c1_re_q14 >= 16384 || c3_re_q14 != 0 || c5_re_q14 != 0)
        `uvm_fatal("RANDOM_DPD_CLASS","Attenuation class has inconsistent coefficients")
      1: if (c1_re_q14 != 16384 || c3_re_q14 != 0 || c5_re_q14 != 0)
        `uvm_fatal("RANDOM_DPD_CLASS","Identity class has inconsistent coefficients")
      2: if (c1_re_q14 <= 16384 || c3_re_q14 != 0 || c5_re_q14 != 0)
        `uvm_fatal("RANDOM_DPD_CLASS","Boost class has inconsistent coefficients")
      3: if (c1_re_q14 != 16384 || c3_re_q14 == 0 || c5_re_q14 != 0)
        `uvm_fatal("RANDOM_DPD_CLASS","C3 class has inconsistent coefficients")
      4: if (c1_re_q14 != 16384 || c3_re_q14 != 0 || c5_re_q14 == 0)
        `uvm_fatal("RANDOM_DPD_CLASS","C5 class has inconsistent coefficients")
    endcase
    if (gain_class_id > 2 || input_profile_id > 3)
      `uvm_fatal("RANDOM_CFG_CLASS","Gain/profile class ID is outside the declared coverage bins")
    cfg.pa_stall_percent = 25;
  endfunction

  virtual function int unsigned configured_active_taps();
    return 1;
  endfunction

  virtual function bit [386:0] configured_payload();
    bit [63:0] c1_re_image;
    bit [63:0] c1_im_image;
    bit [63:0] c3_re_image;
    bit [63:0] c5_re_image;
    c1_re_image = {48'd0,c1_re_q14[15:0]};
    c1_im_image = {48'd0,c1_im_q14[15:0]};
    c3_re_image = {48'd0,c3_re_q14[15:0]};
    c5_re_image = {48'd0,c5_re_q14[15:0]};
    return {3'd1,c1_re_image,c1_im_image,c3_re_image,64'd0,
            c5_re_image,64'd0};
  endfunction

  virtual task check_scenario_stream();
    int unsigned expected_dpd_samples;
    expected_dpd_samples=cfg.core_words+cfg.frame_starts;
    if (env.source.monitor.accepted_beats!=cfg.source_beats ||
        env.source.monitor.accepted_last_count!=expected_tlast_count ||
        env.scoreboard.source_checked!=cfg.source_beats ||
        env.scoreboard.checked!=cfg.core_words ||
        env.coverage.pa_words!=cfg.core_words ||
        env.coverage.frame_starts!=cfg.frame_starts ||
        vif.protocol_error || env.coverage.underflow_before_last_source!=0)
      `uvm_fatal("RANDOM_DPD_STREAM",
        $sformatf("source=%0d/%0d TLAST=%0d/%0d starts=%0d/%0d output=%0d/%0d protocol=%b underflow=%0d",
          env.source.monitor.accepted_beats,cfg.source_beats,
          env.source.monitor.accepted_last_count,cfg.source_beats/32,
          env.coverage.frame_starts,cfg.frame_starts,
          env.scoreboard.checked,cfg.core_words,vif.protocol_error,
          env.coverage.underflow_before_last_source))
    for (int lane=0; lane<16; lane++)
      if (vif.dpd_sample_count[lane]!==expected_dpd_samples)
        `uvm_fatal("RANDOM_DPD_SAMPLE_COUNT",
          $sformatf("lane=%0d samples=%0d expected=%0d",lane,
            vif.dpd_sample_count[lane],expected_dpd_samples))
  endtask

  virtual function string scenario_pass_message();
    return $sformatf(
      "THERMO5_AXIL_RANDOM_DPD_BITTRUE_UVM_PASS dpd_class=%0d c1_re_q14=%0d c3_re_q14=%0d c5_re_q14=%0d gain_class=%0d input_profile=%0d; four-plane Python oracle matched",
      dpd_class_id,c1_re_q14,c3_re_q14,c5_re_q14,gain_class_id,input_profile_id);
  endfunction

  virtual task program_dpd_image(output bit [1:0] resp);
    bit [7:0] addr;
    bit [31:0] coeff_word;
    axil_write(8'h08,32'd1,0,0,resp);
    if (resp!=2'b00)
      `uvm_fatal("RANDOM_DPD_TAPS","Could not select the product one-tap DPD setting")
    for (int word=0; word<12; word++) begin
      case (word)
        0: coeff_word={16'd0,c1_re_q14[15:0]};
        2: coeff_word={16'd0,c1_im_q14[15:0]};
        4: coeff_word={16'd0,c3_re_q14[15:0]};
        8: coeff_word={16'd0,c5_re_q14[15:0]};
        default: coeff_word=32'd0;
      endcase
      addr=8'h10+8'(4*word);
      axil_write(addr,coeff_word,0,0,resp);
      if (resp!=2'b00)
        `uvm_fatal("RANDOM_DPD_WRITE",
          $sformatf("Legal one-tap coefficient write failed at %02x",addr))
    end
  endtask

  task run_phase(uvm_phase phase);
    bit [1:0] resp;
    bit [31:0] rdata;
    bit [386:0] expected_cfg_payload;
    bit drain_complete;
    random_cfg_cg.sample(dpd_class_id,gain_class_id,input_profile_id);
    expected_cfg_payload=configured_payload();
    phase.raise_objection(this);
    fork
      begin
        fork
          send_source(cfg.source_beats);
          begin
            int unsigned stall_count_before;
            bit first_boundary_seen;
            bit applied;
            bit stalled;
            wait(vif.src_rst_n && vif.core_rst_n);
            wait_axil_reset_release();
            program_dpd_image(resp);
            if (resp!=2'b00)
              `uvm_fatal("RANDOM_DPD_PROGRAM","One-tap coefficient programming failed")
            wait(env.source.monitor.accepted_beats>=16);
            if (!commit_after_first_boundary) begin
              axil_write(8'h00,32'h2,0,0,resp);
              if (resp!=2'b00)
                `uvm_fatal("RANDOM_DPD_COMMIT","One-tap product COMMIT was rejected")
              commit_issued=1;
              for (int cycles=0; cycles<100 &&
                   vif.cfg_pending_payload!==expected_cfg_payload; cycles++)
                @(posedge vif.core_clk);
              if (vif.cfg_pending_payload!==expected_cfg_payload)
                `uvm_fatal("RANDOM_DPD_PENDING",
                  "The DPD pending image did not match the independently configured coefficient")
            end
            axil_write(8'h00,32'h1,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("RANDOM_DPD_RUN","RUN request was rejected")
            if (commit_after_first_boundary) begin
              first_boundary_seen=0;
              for (int cycles=0; cycles<2000 && !first_boundary_seen; cycles++) begin
                @(negedge vif.core_clk);
                first_boundary_seen=(vif.dpd_config_boundary===1'b1);
              end
              if (!first_boundary_seen)
                `uvm_fatal("RANDOM_DPD_FIRST_BOUNDARY",
                  "No public DPD frame boundary was observed before the scheduled COMMIT")
              axil_write(8'h00,32'h3,0,0,resp);
              if (resp!=2'b00)
                `uvm_fatal("RANDOM_DPD_LATE_COMMIT",
                  "Legal RUN+COMMIT after the first frame boundary was rejected")
              commit_issued=1;
              for (int cycles=0; cycles<100 &&
                   vif.cfg_pending_payload!==expected_cfg_payload; cycles++)
                @(posedge vif.core_clk);
              if (vif.cfg_pending_payload!==expected_cfg_payload)
                `uvm_fatal("RANDOM_DPD_LATE_PENDING",
                  "Post-boundary COMMIT did not expose the expected pending image")
            end

            if (require_commit_boundary_stall) begin
              stall_count_before=env.monitor.stall_cycles;
              env.pa_sink.set_ready(4'h0);
            end
            applied=0;
            for (int cycles=0; cycles<2000 && !applied; cycles++) begin
              @(negedge vif.core_clk);
              applied=(vif.cfg_done===1'b1 && vif.cfg_pending_valid===1'b0 &&
                       vif.cfg_active_payload===expected_cfg_payload);
            end
            if (!applied)
              `uvm_fatal("RANDOM_DPD_ACTIVE",
                "COMMIT was not acknowledged at a DPD boundary with the expected active image")
            commit_apply_seen=1;

            // Exercise the product-reachable DONE W1C path after a legal
            // one-tap COMMIT. The AXI-Lite predictor independently predicts
            // the sampled STATUS value from observed transactions and the
            // request/ack lifecycle; this explicit check also guards the
            // externally visible register behavior.
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[2:0]!==3'b010)
              `uvm_fatal("RANDOM_DPD_DONE_STATUS",
                $sformatf("COMMIT completion STATUS expected DONE only, got %08x/%b",rdata,resp))
            axil_write(8'h04,32'h2,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("RANDOM_DPD_DONE_W1C",
                "Legal STATUS DONE write-one-to-clear was rejected")
            axil_read(8'h04,rdata,resp);
            if (resp!=2'b00 || rdata[2:0]!==3'b000)
              `uvm_fatal("RANDOM_DPD_DONE_CLEAR",
                $sformatf("STATUS DONE did not clear, got %08x/%b",rdata,resp))

            if (require_commit_boundary_stall) begin
              stalled=0;
              for (int cycles=0; cycles<2000 && !stalled; cycles++) begin
                @(posedge vif.core_clk);
                stalled=(env.monitor.stall_cycles>stall_count_before);
              end
              env.pa_sink.set_ready(4'hf);
              if (!stalled)
                `uvm_fatal("RANDOM_DPD_COMMIT_STALL",
                  "The PA sink did not observe a real four-plane stall while checking the COMMIT scenario")
              commit_stall_seen=1;
              commit_boundary_stall_cg.sample(commit_after_first_boundary,
                                               commit_apply_seen,
                                               commit_stall_seen);
            end
            wait(env.source.monitor.accepted_beats==cfg.source_beats);
            // Close the packet promptly so the DUT enters its documented
            // drain state before any post-packet source starvation can occur.
            axil_write(8'h00,32'd0,0,0,resp);
            if (resp!=2'b00)
              `uvm_fatal("RANDOM_DPD_STOP","STOP request was rejected")
            stop_issued=1;
            for (int cycles=0; cycles<12000 && !scenario_stream_complete(); cycles++)
              @(posedge vif.core_clk);
            if (!scenario_stream_complete())
              `uvm_fatal("RANDOM_DPD_TIMEOUT","The bit-true output stream did not complete")
            check_scenario_stream();
            if (!env.unified_scoreboard.ef2_reference_loaded ||
                env.unified_scoreboard.ef2_data_mismatches!=0)
              `uvm_fatal("RANDOM_DPD_EF2_ORACLE",
                $sformatf("independent online EF2 reference loaded=%b mismatches=%0d",
                  env.unified_scoreboard.ef2_reference_loaded,
                  env.unified_scoreboard.ef2_data_mismatches))
            drain_complete=0;
            for (int polls=0; polls<1000 && !drain_complete; polls++) begin
              axil_read(8'h04,rdata,resp);
              if (resp!=2'b00)
                `uvm_fatal("RANDOM_DPD_STATUS","Could not read product STATUS")
              status_checked=1;
              drain_complete=(rdata[4:3]==2'b00);
            end
            if (!drain_complete)
              `uvm_fatal("RANDOM_DPD_DRAIN","Product STOP did not reach drained idle")
            if (!env.unified_scoreboard.check_expected_queues_drained("random-dpd-matrix"))
              `uvm_fatal("RANDOM_DPD_EXPECTED_QUEUE",
                "Independent expectations remained after randomized DPD STOP/drain")
            if (commit_issued && stop_issued && status_checked)
              status_commit_stop_cg.sample(commit_issued,stop_issued,status_checked);
            else
              `uvm_fatal("RANDOM_DPD_STATUS_COMMIT_STOP",
                "Expected a checked COMMIT, STOP, and STATUS drain sequence")
            `uvm_info("SKU_PASS",scenario_pass_message(),UVM_NONE)
          end
        join
      end
      begin
        repeat(20000) @(posedge vif.core_clk);
        `uvm_fatal("TIMEOUT","Random one-tap DPD product test timed out")
      end
    join_any
    disable fork;
    phase.drop_objection(this);
  endtask
endclass
