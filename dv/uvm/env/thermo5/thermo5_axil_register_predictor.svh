// Independent AXI-Lite shadow-register and sampled-read predictor.
// The model advances on monitor write-fire events, not the later B response.
class thermo5_axil_register_predictor extends uvm_component;
  `uvm_component_utils(thermo5_axil_register_predictor)
  uvm_analysis_imp_src#(thermo5_source_item,thermo5_axil_register_predictor) source_imp;
  uvm_analysis_imp_pa#(thermo5_pa_word,thermo5_axil_register_predictor) pa_imp;
  uvm_analysis_imp_axil_fire#(thermo5_axil_item,thermo5_axil_register_predictor) write_fire_imp;
  uvm_analysis_imp_axil_addr#(thermo5_axil_item,thermo5_axil_register_predictor) read_addr_imp;
  uvm_analysis_imp_axil_done#(thermo5_axil_item,thermo5_axil_register_predictor) completion_imp;
  uvm_analysis_imp_axil_cycle#(thermo5_axil_item,thermo5_axil_register_predictor) cycle_imp;
  virtual thermo5_axil_if axil_vif;
  virtual thermo5_sku_if sku_vif;

  typedef struct packed {
    int unsigned id;
    bit [1:0] response;
  } write_expectation_t;
  typedef struct packed {
    int unsigned id;
    bit [1:0] response;
    bit [31:0] data;
    bit [31:0] mask;
  } read_expectation_t;
  write_expectation_t write_expected[$];
  read_expectation_t read_expected[$];

  bit [63:0] shadow_coeff[0:5];
  bit [2:0] shadow_taps;
  bit run_request_model, busy_model, done_model, error_model;
  bit cfg_ack_sync1_model, cfg_ack_sync2_model, cfg_seen_ack_model;
  bit ever_run_model, drain_output_complete_model;
  int unsigned accepted_packet_beats_model, expected_pa_words_model;
  int unsigned accepted_pa_words_model, prefill_beats_model;
  int unsigned run_request_cycle_model, stop_request_cycle_model;
  int unsigned drain_complete_cycle_model, last_axil_cycle_model;
  bit [31:0] sampled_status_model;
  int unsigned sampled_status_cycle;
  bit sampled_status_valid, sampled_lifecycle_stable;
  bit axil_reset_active;
  int unsigned max_taps = 4;
  int unsigned checked_reads, checked_write_responses, mismatches;
  int unsigned expected_early_tlasts, observed_early_tlasts;
  int unsigned source_gap_events_model, source_gap_cycles_model;
  int unsigned status_lifecycle_masked, status_lifecycle_checked;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_imp = new("source_imp",this);
    pa_imp = new("pa_imp",this);
    write_fire_imp = new("write_fire_imp",this);
    read_addr_imp = new("read_addr_imp",this);
    completion_imp = new("completion_imp",this);
    cycle_imp = new("cycle_imp",this);
    checked_reads=0;
    checked_write_responses=0;
    mismatches=0;
    expected_early_tlasts=0;
    observed_early_tlasts=0;
    source_gap_events_model=0;
    source_gap_cycles_model=0;
    status_lifecycle_masked=0;
    status_lifecycle_checked=0;
    axil_reset_active=0;
    reset_model();
  endfunction

  // Negative protocol tests may deliberately inject early TLAST. Keep this
  // expectation explicit and count only the requested events; all other
  // predictor mismatches remain errors.
  function void expect_early_tlasts(input int unsigned count);
    expected_early_tlasts=count;
    observed_early_tlasts=0;
  endfunction

  function void reset_model();
    shadow_taps = 3'd1;
    shadow_coeff[0] = 64'h0000_0000_0000_4000;
    for (int index=1; index<6; index++) shadow_coeff[index] = '0;
    run_request_model = 0;
    busy_model = 0;
    done_model = 0;
    error_model = 0;
    cfg_ack_sync1_model = 0;
    cfg_ack_sync2_model = 0;
    cfg_seen_ack_model = 0;
    ever_run_model = 0;
    drain_output_complete_model = 0;
    accepted_packet_beats_model = 0;
    expected_pa_words_model = 0;
    accepted_pa_words_model = 0;
    prefill_beats_model = 0;
    run_request_cycle_model = 0;
    stop_request_cycle_model = 0;
    drain_complete_cycle_model = 0;
    last_axil_cycle_model = 0;
    sampled_status_model = 0;
    sampled_status_cycle = 0;
    sampled_status_valid = 0;
    sampled_lifecycle_stable = 0;
    write_expected.delete();
    read_expected.delete();
  endfunction

  function void build_phase(uvm_phase phase);
    int configured_max_taps;
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_axil_if)::get(this,"","axil_vif",axil_vif) ||
        !uvm_config_db#(virtual thermo5_sku_if)::get(this,"","sku_vif",sku_vif))
      `uvm_fatal("PREDICTOR_VIF","AXI-Lite predictor interfaces are missing")
    if (uvm_config_db#(int)::get(this,"","max_taps",configured_max_taps))
      max_taps = configured_max_taps;
  endfunction

  function automatic int coeff_index(bit [7:0] address);
    case (address & 8'hf8)
      8'h10: return 0;
      8'h18: return 1;
      8'h20: return 2;
      8'h28: return 3;
      8'h30: return 4;
      8'h38: return 5;
      default: return -1;
    endcase
  endfunction

  function automatic bit is_coeff_addr(bit [7:0] address);
    int index;
    index=coeff_index(address);
    return index >= 0 && ((address & 8'h03) == 0);
  endfunction

  function automatic bit [31:0] merge_bytes(bit [31:0] old_value,
                                             bit [31:0] new_value,
                                             bit [3:0] strobe);
    bit [31:0] merged;
    merged=old_value;
    for (int byte_index=0; byte_index<4; byte_index++)
      if (strobe[byte_index]) merged[byte_index*8+:8]=new_value[byte_index*8+:8];
    return merged;
  endfunction

  function automatic bit [1:0] predict_write_response(thermo5_axil_item tr);
    if (tr.addr==8'h00) begin
      if (tr.strb[0] && tr.data[1] &&
          (busy_model || shadow_taps < 1 || shadow_taps > max_taps))
        return 2'b10;
      return 2'b00;
    end
    if (tr.addr==8'h04 || tr.addr==8'h08 || is_coeff_addr(tr.addr)) return 2'b00;
    return 2'b11;
  endfunction

  function void write_axil_fire(thermo5_axil_item tr);
    write_expectation_t expected;
    int index;
    bit [31:0] old_word, new_word;
    expected.id=tr.txn_id;
    expected.response=predict_write_response(tr);
    write_expected.push_back(expected);
    if (expected.response != 2'b00) begin
      if (tr.addr==8'h00) error_model=1;
      return;
    end

    case (tr.addr)
      8'h00: if (tr.strb[0]) begin
        bit old_run_request;
        old_run_request=run_request_model;
        run_request_model=tr.data[0];
        if (run_request_model) begin
          ever_run_model=1;
          if (!old_run_request) run_request_cycle_model=tr.event_cycle;
        end else if (old_run_request || ever_run_model) begin
          stop_request_cycle_model=tr.event_cycle;
          drain_output_complete_model=
            (accepted_pa_words_model >= expected_pa_words_model) &&
            (accepted_packet_beats_model == 0);
          if (drain_output_complete_model)
            drain_complete_cycle_model=tr.event_cycle;
        end
        if (tr.data[1]) begin
          busy_model=1;
          done_model=0;
          cfg_seen_ack_model=0;
        end
      end
      8'h04: if (tr.strb[0]) begin
        if (tr.data[1]) done_model=0;
        if (tr.data[2]) error_model=0;
      end
      8'h08: if (tr.strb[0]) shadow_taps=tr.data[2:0];
      default: begin
        index=coeff_index(tr.addr);
        if (index>=0 && is_coeff_addr(tr.addr)) begin
          old_word=tr.addr[2] ? shadow_coeff[index][63:32] : shadow_coeff[index][31:0];
          new_word=merge_bytes(old_word,tr.data,tr.strb);
          if (tr.addr[2]) shadow_coeff[index][63:32]=new_word;
          else shadow_coeff[index][31:0]=new_word;
        end
      end
    endcase
  endfunction

  // Independent lifecycle inputs: accepted source packet boundaries and PA
  // handshakes. The DUT core_tx_active/core_draining pins are not predictors.
  function void write_src(thermo5_source_item tr);
    accepted_packet_beats_model++;
    if (prefill_beats_model < 2) prefill_beats_model++;
    if (tr.valid_gap_cycles != 0) begin
      source_gap_events_model++;
      source_gap_cycles_model += tr.valid_gap_cycles;
    end
    if (tr.tlast) begin
      if ((accepted_packet_beats_model % 32) != 0) begin
        observed_early_tlasts++;
        if (observed_early_tlasts > expected_early_tlasts) begin
          mismatches++;
          `uvm_error("AXIL_STATUS_MODEL",
            $sformatf("unexpected accepted TLAST after %0d packet beats; expected a multiple of 32",
              accepted_packet_beats_model))
        end
      end
      expected_pa_words_model += (accepted_packet_beats_model * 14) / 8;
      accepted_packet_beats_model=0;
      if (!run_request_model)
        drain_output_complete_model=
          (accepted_pa_words_model >= expected_pa_words_model);
    end
  endfunction

  function void write_pa(thermo5_pa_word tr);
    accepted_pa_words_model++;
    if (!run_request_model && ever_run_model &&
        accepted_packet_beats_model == 0 &&
        accepted_pa_words_model >= expected_pa_words_model) begin
      drain_output_complete_model=1;
      drain_complete_cycle_model=last_axil_cycle_model;
    end
  endfunction

  function automatic bit [1:0] predict_lifecycle_status(
      input int unsigned cycle, output bit stable);
    bit active, draining;
    active=0;
    draining=0;
    stable=1;
    if (run_request_model) begin
      active=1;
      stable=(cycle >= run_request_cycle_model + 4);
    end else if (ever_run_model && !drain_output_complete_model) begin
      active=1;
      draining=1;
      stable=(cycle >= stop_request_cycle_model + 4);
    end else if (ever_run_model) begin
      active=0;
      draining=0;
      stable=(cycle >= drain_complete_cycle_model + 4);
    end
    return {draining,active};
  endfunction

  // Called once per AXI-Lite rising edge before same-edge AR/write events.
  // STATUS read prediction uses the pre-NBA value that the RTL samples on AR.
  function void write_axil_cycle(thermo5_axil_item tr);
    bit old_ack_sync2;
    bit lifecycle_stable;
    bit [1:0] lifecycle_status;
    if (!tr.reset_n) begin
      // AXIS source reset may release before the AXI-Lite/core reset. Keep
      // any beats legally accepted into the source FIFO during that release
      // skew; repeatedly clearing this epoch on every AXI reset clock loses
      // those independently observed transactions.
      if (!axil_reset_active) begin
        reset_model();
        axil_reset_active=1;
      end
      return;
    end
    axil_reset_active=0;

    last_axil_cycle_model=tr.event_cycle;
    lifecycle_status=predict_lifecycle_status(tr.event_cycle,lifecycle_stable);
    sampled_status_model={27'd0,lifecycle_status,
                          error_model,done_model,busy_model};
    sampled_status_cycle=tr.event_cycle;
    sampled_status_valid=1;
    sampled_lifecycle_stable=lifecycle_stable;

    old_ack_sync2=cfg_ack_sync2_model;
    cfg_ack_sync2_model=cfg_ack_sync1_model;
    cfg_ack_sync1_model=sku_vif.cfg_ack_core;

    if (busy_model) begin
      if (old_ack_sync2) cfg_seen_ack_model=1;
      else if (cfg_seen_ack_model) begin
        busy_model=0;
        done_model=1;
        cfg_seen_ack_model=0;
      end
    end
  endfunction

  function bit [31:0] predict_read_data(bit [7:0] address,
                                        output bit [1:0] response,
                                        output bit [31:0] compare_mask);
    int index;
    bit [31:0] value;
    response=2'b00;
    compare_mask=32'hffff_ffff;
    value='0;
    case (address)
      8'h00: value={31'd0,run_request_model};
      8'h04: begin
        if (!sampled_status_valid || sampled_status_cycle==0) begin
          `uvm_error("AXIL_STATUS_SAMPLE","STATUS read has no AXI-cycle predictor snapshot")
        end
        value=sampled_status_model;
        compare_mask=sampled_lifecycle_stable ? 32'h0000_001f : 32'h0000_0007;
      end
      8'h08: value={29'd0,shadow_taps};
      8'h0c: value=32'h5448_3501;
      default: begin
        index=coeff_index(address);
        if (is_coeff_addr(address))
          value=address[2] ? shadow_coeff[index][63:32] : shadow_coeff[index][31:0];
        else begin
          response=2'b11;
          compare_mask='0;
        end
      end
    endcase
    return value;
  endfunction

  function void write_axil_addr(thermo5_axil_item tr);
    read_expectation_t expected;
    expected.id=tr.txn_id;
    if (tr.addr==8'h04 && sampled_status_cycle!=tr.event_cycle) begin
      mismatches++;
      `uvm_error("AXIL_STATUS_CYCLE",
        $sformatf("STATUS predictor snapshot cycle=%0d AR cycle=%0d",
          sampled_status_cycle,tr.event_cycle))
    end
    expected.data=predict_read_data(tr.addr,expected.response,expected.mask);
    if (tr.addr==8'h04) begin
      if (sampled_lifecycle_stable) status_lifecycle_checked++;
      else status_lifecycle_masked++;
    end
    read_expected.push_back(expected);
  endfunction

  function void write_axil_done(thermo5_axil_item tr);
    if (tr.is_write) begin
      write_expectation_t expected;
      if (write_expected.size()==0) begin
        mismatches++;
        `uvm_error("AXIL_PREDICTOR","B response has no matching write-fire event")
      end else begin
        expected=write_expected.pop_front();
        checked_write_responses++;
        if (expected.id!=tr.txn_id || expected.response!=tr.resp) begin
          mismatches++;
          `uvm_error("AXIL_PREDICTOR_WRITE",
            $sformatf("write id=%0d expected id=%0d response=%b got=%b addr=%02x",
              tr.txn_id,expected.id,expected.response,tr.resp,tr.addr))
        end
      end
    end else begin
      read_expectation_t expected;
      if (read_expected.size()==0) begin
        mismatches++;
        `uvm_error("AXIL_PREDICTOR","R response has no matching AR sample event")
      end else begin
        expected=read_expected.pop_front();
        checked_reads++;
        if (expected.id!=tr.txn_id || expected.response!=tr.resp ||
            ((expected.data ^ tr.rdata) & expected.mask)!=0) begin
          mismatches++;
          `uvm_error("AXIL_PREDICTOR_READ",
            $sformatf("read id=%0d addr=%02x expected=%08x/%b mask=%08x got=%08x/%b",
              tr.txn_id,tr.addr,expected.data,expected.response,expected.mask,tr.rdata,tr.resp))
        end
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("AXIL_REGISTER_PREDICTOR",
      $sformatf("read_checks=%0d write_response_checks=%0d mismatches=%0d pending_reads=%0d pending_writes=%0d status_stable=%0d status_masked=%0d source_gaps=%0d gap_cycles=%0d",
        checked_reads,checked_write_responses,mismatches,read_expected.size(),write_expected.size(),
        status_lifecycle_checked,status_lifecycle_masked,source_gap_events_model,source_gap_cycles_model),
      UVM_NONE)
  endfunction
endclass
