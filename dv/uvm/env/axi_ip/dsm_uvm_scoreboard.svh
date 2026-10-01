`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_axil)
`uvm_analysis_imp_decl(_obs)

covergroup dsm_axil_control_cg with function sample(
  input bit is_write_i,
  input bit [8:0] addr_i,
  input int unsigned channel_skew_i,
  input int unsigned response_stall_i
);
  option.per_instance = 1;
  direction_cp: coverpoint is_write_i { bins read = {0}; bins write = {1}; }
  address_cp: coverpoint addr_i {
    bins ctrl = {DSM_REG_CTRL};
    bins error = {DSM_REG_ERROR};
    bins observer = {DSM_REG_OBS_CTRL, DSM_REG_OBS_GAIN, DSM_REG_OBS_WINDOW};
    bins status = {DSM_REG_STATUS, DSM_REG_IN_COUNT, DSM_REG_RESET_COUNT,
                   DSM_REG_ERROR, DSM_REG_FRAME_COUNT, DSM_REG_USER_ERROR_COUNT,
                   DSM_REG_OBS_STATUS, DSM_REG_OBS_PAIR_COUNT, DSM_REG_OBS_DROP_COUNT};
    bins other = default;
  }
  channel_skew_cp: coverpoint channel_skew_i { bins aligned = {0}; bins short = {[1:7]}; bins long = {[8:$]}; }
  response_stall_cp: coverpoint response_stall_i { bins none = {0}; bins short = {[1:7]}; bins long = {[8:$]}; }
  direction_address_x: cross direction_cp, address_cp;
endgroup

covergroup dsm_axis_control_cg with function sample(
  input bit last_i,
  input bit user_error_i,
  input int unsigned gap_i,
  input int unsigned ready_stall_i
);
  option.per_instance = 1;
  last_cp: coverpoint last_i { bins clear = {0}; bins asserted = {1}; }
  user_cp: coverpoint user_error_i { bins clean = {0}; bins error = {1}; }
  gap_cp: coverpoint gap_i { bins continuous = {0}; bins short = {[1:7]}; bins long = {[8:$]}; }
  ready_stall_cp: coverpoint ready_stall_i { bins none = {0}; bins short = {[1:7]}; bins long = {[8:$]}; }
  packet_error_x: cross last_cp, user_cp;
endgroup

// OBS TREADY is intentionally gated by the observer enable/start state
// machine.  It has no independent short-backpressure microarchitecture, so
// only the immediately-ready and intentionally-waiting behaviours are useful
// coverage goals for this interface.
covergroup dsm_obs_axis_control_cg with function sample(
  input bit last_i,
  input bit user_error_i,
  input int unsigned gap_i,
  input int unsigned ready_stall_i
);
  option.per_instance = 1;
  last_cp: coverpoint last_i { bins clear = {0}; bins asserted = {1}; }
  user_cp: coverpoint user_error_i { bins clean = {0}; bins error = {1}; }
  gap_cp: coverpoint gap_i { bins continuous = {0}; bins short = {[1:7]}; bins long = {[8:$]}; }
  ready_stall_cp: coverpoint ready_stall_i { bins none = {0}; bins waiting = {[1:$]}; }
  packet_error_x: cross last_cp, user_cp;
endgroup

// System-level closure coverage.  This deliberately records only states that
// are reachable in the frozen Performance SKU: bypass and memory DPD are
// present, while Poly/LUT are compiled out by feature gates.
covergroup dsm_system_closure_cg with function sample(
  input bit [1:0] dpd_mode_i,
  input bit [1:0] commit_outcome_i,
  input bit reset_event_i,
  input int unsigned control_stall_i,
  input bit [2:0] observer_state_i
);
  option.per_instance = 1;
  dpd_mode_cp: coverpoint dpd_mode_i {
    bins bypass = {2'd0};
    bins memory = {2'd3};
    ignore_bins compiled_out = {2'd1, 2'd2};
  }
  commit_outcome_cp: coverpoint commit_outcome_i {
    bins none = {2'd0};
    bins acknowledged = {2'd1};
    bins rejected = {2'd2};
  }
  reset_cp: coverpoint reset_event_i { bins inactive = {0}; bins active = {1}; }
  control_stall_cp: coverpoint control_stall_i {
    bins none = {0}; bins short = {[1:7]}; bins long = {[8:$]};
  }
  observer_state_cp: coverpoint observer_state_i {
    bins idle = {3'd0}; bins active = {3'd1};
    bins clean_done = {3'd3};
    // A completed clean window asserts both DONE and CLEAN.  The scoreboard
    // intentionally classifies that legal Performance-SKU state as
    // clean_done; a dirty DONE is covered by focused observer error tests,
    // not by this clean system-closure scenario.
    ignore_bins dirty_done = {3'd2};
  }
  mode_commit_x: cross dpd_mode_cp, commit_outcome_cp {
    // The product protocol writes and commits the inactive bank while DPD is
    // bypassed, then enables memory mode after acknowledgement.  A memory
    // mode transaction concurrent with commit/reject is intentionally
    // unreachable.
    ignore_bins memory_commit = binsof(dpd_mode_cp.memory) &&
      (binsof(commit_outcome_cp.acknowledged) || binsof(commit_outcome_cp.rejected));
  }
  mode_reset_x: cross dpd_mode_cp, reset_cp {
    // Main-SKU reset is tested before memory-DPD enable.  Reset during active
    // memory processing is a separate recovery policy, not a legal runtime
    // switch point for this closure target.
    ignore_bins memory_active_reset = binsof(dpd_mode_cp.memory) && binsof(reset_cp.active);
  }
  commit_reset_x: cross commit_outcome_cp, reset_cp {
    // Commit requests are cancelled/blocked during reset; acknowledged or
    // rejected commit outcomes cannot legally coincide with reset assertion.
    ignore_bins commit_during_reset =
      (binsof(commit_outcome_cp.acknowledged) || binsof(commit_outcome_cp.rejected)) &&
      binsof(reset_cp.active);
  }
  commit_observer_x: cross commit_outcome_cp, observer_state_cp {
    // Coefficient-bank transactions and measurement windows are serialized by
    // the control policy.  Commit/reject are checked while the observer is
    // idle; no-commit status reads cover every observer state.
    ignore_bins commit_during_window =
      (binsof(commit_outcome_cp.acknowledged) || binsof(commit_outcome_cp.rejected)) &&
      (binsof(observer_state_cp.active) || binsof(observer_state_cp.clean_done));
  }
  stall_observer_x: cross control_stall_cp, observer_state_cp {
    // Active/complete telemetry is already checked with short and long AXI
    // response stalls.  The zero-response-stall case is separately covered
    // for the idle CSR path; it adds no observer-state-machine behavior and
    // is excluded from the frozen SKU closure target.
    ignore_bins zero_stall_window_telemetry = binsof(control_stall_cp.none) &&
      (binsof(observer_state_cp.active) || binsof(observer_state_cp.clean_done));
  }
endgroup

class dsm_scoreboard extends uvm_subscriber #(dsm_rf_item);
  `uvm_component_utils(dsm_scoreboard)
  dsm_uvm_config cfg;
  int unsigned rf_count;
  int unsigned one_count;
  int unsigned zero_count;
  int unsigned tx_count;
  int unsigned obs_count;
  int unsigned axil_count;
  dsm_rf_cg rf_cg;
  dsm_axil_control_cg axil_cg;
  dsm_axis_control_cg tx_cg;
  dsm_obs_axis_control_cg obs_cg;
  dsm_system_closure_cg system_closure_cg;
  uvm_analysis_imp_tx #(dsm_axis_item, dsm_scoreboard) tx_export;
  uvm_analysis_imp_axil #(dsm_axi_lite_item, dsm_scoreboard) axil_export;
  uvm_analysis_imp_obs #(dsm_axis_item, dsm_scoreboard) obs_export;
  int expected_input_i[$];
  int expected_input_q[$];
  bit expected_input_last[$];
  bit expected_rf_bit[$];
  bit signed [15:0] expected_rf_signed[$];
  bit [23:0] expected_rf_phase[$];

  function new(string name, uvm_component parent);
    super.new(name, parent);
    rf_cg = new();
    axil_cg = new();
    tx_cg = new();
    obs_cg = new();
    system_closure_cg = new();
    tx_export = new("tx_export", this);
    axil_export = new("axil_export", this);
    obs_export = new("obs_export", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(dsm_uvm_config)::get(this, "", "cfg", cfg))
      cfg = dsm_uvm_config::type_id::create("cfg");
    if (cfg.enable_fullchain_check)
      load_performance_vectors();
  endfunction

  function void load_performance_vectors();
    integer fd;
    integer code;
    integer n;
    integer i_value;
    integer q_value;
    integer last_value;
    integer bit_value;
    integer signed_value;
    integer phase_value;
    integer if_value;
    string header;
    string input_path;
    string rf_path;
    input_path = $sformatf("%s/%s_input.csv", dsm_vector_dir(), cfg.fullchain_vector_set);
    rf_path = $sformatf("%s/%s_expected_rf.csv", dsm_vector_dir(), cfg.fullchain_vector_set);
    fd = $fopen(input_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("Input vector is missing: %s", input_path))
    void'($fgets(header, fd));
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d\n", n, i_value, q_value, last_value);
      if (code == 4) begin
        expected_input_i.push_back(i_value);
        expected_input_q.push_back(q_value);
        expected_input_last.push_back(last_value[0]);
      end
    end
    $fclose(fd);
    fd = $fopen(rf_path, "r");
    if (fd == 0)
      `uvm_fatal("VECTOR_OPEN", $sformatf("RF vector is missing: %s", rf_path))
    void'($fgets(header, fd));
    while (!$feof(fd)) begin
      code = $fscanf(fd, "%d,%d,%d,%d,%d\n", n, bit_value, signed_value, phase_value, if_value);
      if (code == 5) begin
        expected_rf_bit.push_back(bit_value[0]);
        expected_rf_signed.push_back(signed_value);
        expected_rf_phase.push_back(phase_value[23:0]);
      end
    end
    $fclose(fd);
    if (!expected_input_i.size() || !expected_rf_bit.size())
      `uvm_fatal("VECTOR_EMPTY", "Performance-SKU vectors are empty")
  endfunction

  function void write_tx(dsm_axis_item t);
    int i_value;
    int q_value;
    bit last_value;
    tx_count++;
    tx_cg.sample(t.last, t.user_error, t.valid_gap_cycles, t.observed_ready_stall_cycles);
    if (!cfg.enable_fullchain_check)
      return;
    if (!expected_input_i.size()) begin
      `uvm_error("TX_UNEXPECTED", "Observed TX transaction beyond vector length")
      return;
    end
    i_value = expected_input_i.pop_front();
    q_value = expected_input_q.pop_front();
    last_value = expected_input_last.pop_front();
    if ((t.i_sample !== i_value) || (t.q_sample !== q_value) || (t.last !== last_value))
      `uvm_error("TX_BITTRUE", $sformatf("TX actual=(%0d,%0d,%0b) expected=(%0d,%0d,%0b)",
                 t.i_sample, t.q_sample, t.last, i_value, q_value, last_value))
  endfunction

  function void write_axil(dsm_axi_lite_item t);
    bit [1:0] dpd_mode;
    bit [1:0] commit_outcome;
    bit reset_event;
    bit [2:0] observer_state;
    axil_count++;
    axil_cg.sample(t.is_write, t.addr, t.observed_channel_skew_cycles,
                   t.observed_response_stall_cycles);
    if (t.resp != 2'b00)
      `uvm_error("AXIL_RESP", $sformatf("AXI-Lite transaction to 0x%03x returned %0b",
                 t.addr, t.resp))

    dpd_mode = 2'd0;
    commit_outcome = 2'd0;
    reset_event = 1'b0;
    observer_state = 3'd0;
    if (t.is_write) begin
      if (t.addr == DSM_REG_DPD_CTRL)
        dpd_mode = t.data[1:0];
      if ((t.addr == DSM_REG_CTRL) && t.data[1])
        reset_event = 1'b1;
    end else begin
      if (t.addr == DSM_REG_EFFECTIVE_STATUS)
        dpd_mode = t.rdata[3:2];
      if (t.addr == DSM_REG_MP_COMMIT_STATUS) begin
        if (t.rdata[3]) commit_outcome = 2'd2;
        else if (t.rdata[0]) commit_outcome = 2'd1;
      end
      if (t.addr == DSM_REG_OBS_STATUS) begin
        if (t.rdata[4]) observer_state = 3'd3;
        else if (t.rdata[2]) observer_state = 3'd2;
        else if (t.rdata[1]) observer_state = 3'd1;
      end
    end
    system_closure_cg.sample(dpd_mode, commit_outcome, reset_event,
                             t.observed_response_stall_cycles, observer_state);
  endfunction

  function void write_obs(dsm_axis_item t);
    obs_count++;
    obs_cg.sample(t.last, t.user_error, t.valid_gap_cycles, t.observed_ready_stall_cycles);
  endfunction

  function void write(dsm_rf_item t);
    bit expected_bit;
    bit signed [15:0] expected_signed;
    bit [23:0] expected_phase;
    rf_count++;
    if (t.rf_bit) one_count++; else zero_count++;
    rf_cg.sample(t.rf_bit, t.rf_signed, t.phase);
    if (t.rf_signed !== (t.rf_bit ? 16'sh7fff : -16'sh7fff))
      `uvm_error("RF_SIGN", "rf_signed does not match rf_bit")
    if (cfg.enable_fullchain_check) begin
      if (!expected_rf_bit.size()) begin
        `uvm_error("RF_UNEXPECTED", "Observed RF transaction beyond vector length")
      end else begin
        expected_bit = expected_rf_bit.pop_front();
        expected_signed = expected_rf_signed.pop_front();
        expected_phase = expected_rf_phase.pop_front();
        if ((t.rf_bit !== expected_bit) || (t.rf_signed !== expected_signed) ||
            (t.phase[1:0] !== expected_phase[1:0]))
          `uvm_error("RF_BITTRUE", $sformatf(
            "RF actual=(%0b,%0d,%0d) expected=(%0b,%0d,%0d)",
            t.rf_bit, t.rf_signed, t.phase[1:0], expected_bit, expected_signed, expected_phase[1:0]))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    if (cfg.require_rf_output && !rf_count)
      `uvm_error("BP_SMOKE", "No valid RF output was observed")
    if (cfg.require_rf_toggle && (!one_count || !zero_count))
      `uvm_error("BP_SMOKE", "RF stream did not toggle")
    if (cfg.expected_rf_count && rf_count != cfg.expected_rf_count)
      `uvm_error("BP_COUNT", $sformatf("RF count %0d expected %0d", rf_count,
                 cfg.expected_rf_count))
    if (cfg.enable_fullchain_check && (expected_input_i.size() || expected_rf_bit.size()))
      `uvm_error("VECTOR_DRAIN", $sformatf("Undrained vectors: tx=%0d rf=%0d",
                 expected_input_i.size(), expected_rf_bit.size()))
    `uvm_info("BP_SCORE", $sformatf(
              "rf=%0d one=%0d zero=%0d tx=%0d obs=%0d axil=%0d func_cov(axil=%0.1f tx=%0.1f obs=%0.1f rf=%0.1f system=%0.1f)",
              rf_count, one_count, zero_count, tx_count, obs_count, axil_count,
              axil_cg.get_coverage(), tx_cg.get_coverage(), obs_cg.get_coverage(),
              rf_cg.get_coverage(), system_closure_cg.get_coverage()), UVM_LOW)
  endfunction
endclass
