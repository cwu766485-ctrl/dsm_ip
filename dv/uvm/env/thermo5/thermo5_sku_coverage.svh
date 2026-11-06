// Functional event coverage is kept separate from VCS code coverage.  A test
// must check its required event counts; a sampled bin alone is not a PASS.
class thermo5_sku_coverage extends uvm_component;
  `uvm_component_utils(thermo5_sku_coverage)
  typedef struct packed {
    int unsigned epoch;
    int unsigned packet_id;
    int unsigned source_beats;
    bit source_gap;
    bit fifo_full;
    bit pa_stall;
    bit run_seen;
    bit prefill_before_run;
    bit source_gap_after_run;
    bit tlast_seen;
    bit stop_before_tlast;
    bit tlast_after_stop;
    bit drain_after_tlast;
    bit finalized;
    longint unsigned stop_event_id;
    longint unsigned tlast_event_id;
    longint unsigned drain_event_id;
  } packet_cross_record_t;

  uvm_analysis_imp_event#(thermo5_transaction_event,thermo5_sku_coverage) event_imp;
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  int unsigned event_counts[10];
  int fifo_full_cycles, source_stall_cycles, frame_starts;
  int reset_reassertions, underflow_cycles, protocol_error_cycles;
  int underflow_before_last_source;
  int pa_stall_cycles, pa_words;
  int pa_partial_ready_stall_cycles;
  int accepted_tlast_markers, packet_beats_since_boundary;
  int signed_min_beats, signed_max_beats;
  int ef2_positive_clamp_events, ef2_negative_clamp_events;
  int ef2_clamp_stall_cycles, ef2_tidsm_stall_cycles, ef2_state_rail_cycles;
  int ef2_state_rail_stall_cycles;
  int tlast_pa_stall_cycles, stop_partial_pa_stall_cycles;
  int commit_pending_while_stopped_cycles, reset_nonzero_ef2_state_events;
  int ef2_positive_clamp_branch[0:3], ef2_negative_clamp_branch[0:3];
  int unsigned accepted_source_beats_epoch, accepted_output_words_epoch;
  int unsigned accepted_cdc_output_words_epoch, cdc_frame_end_events;
  int unsigned cdc_end_remaining_false_arm_events;
  int unsigned pending_tlast_output_targets[$];
  int unsigned pending_tlast_cdc_output_targets[$];
  bit seen_src_release, last_src_rst_n, ef2_state_nonzero_seen;
  packet_cross_record_t packet_cross[longint unsigned];
  longint unsigned packet_cross_keys[$];
  int unsigned last_source_epoch, last_source_packet_id;
  bit last_source_packet_valid;
  bit run_active;
  longint unsigned stop_candidate_key;
  bit stop_candidate_valid;
  int unsigned output_words_per_packet;
  int unsigned source_gap_pa_fifo_full_hits, run_prefill_gap_hits;
  int unsigned stop_tlast_drain_hits;

  function automatic longint unsigned packet_key(int unsigned epoch,
                                                   int unsigned packet_id);
    return {epoch,packet_id};
  endfunction

  function automatic packet_cross_record_t get_packet_record(
      int unsigned epoch, int unsigned packet_id, bit create_if_missing=1'b1);
    packet_cross_record_t record;
    longint unsigned key;
    key=packet_key(epoch,packet_id);
    if (packet_cross.exists(key)) return packet_cross[key];
    record='0;
    record.epoch=epoch;
    record.packet_id=packet_id;
    if (create_if_missing) begin
      packet_cross[key]=record;
      packet_cross_keys.push_back(key);
    end
    return record;
  endfunction

  // This is a packet-scenario cross: all three facts must be observed in the
  // same accepted packet and its test must pass its independent integrity
  // checks before sampling. They are not required to be simultaneous cycles.
  covergroup source_gap_pa_fifo_cg with function sample(bit source_gap,
                                                         bit fifo_full,
                                                         bit pa_stall);
    option.per_instance = 1;
    cp_source_gap: coverpoint source_gap iff (source_gap) { bins observed={1}; }
    cp_fifo_full: coverpoint fifo_full iff (fifo_full) { bins observed={1}; }
    cp_pa_stall: coverpoint pa_stall iff (pa_stall) { bins observed={1}; }
    x_source_gap_pa_stall_fifo_full: cross cp_source_gap, cp_fifo_full, cp_pa_stall;
  endgroup

  covergroup run_prefill_gap_cg with function sample(bit run_seen,
                                                      bit prefill_seen,
                                                      bit source_gap);
    option.per_instance = 1;
    cp_run: coverpoint run_seen iff (run_seen) { bins observed={1}; }
    cp_prefill: coverpoint prefill_seen iff (prefill_seen) { bins observed={1}; }
    cp_source_gap: coverpoint source_gap iff (source_gap) { bins observed={1}; }
    x_run_prefill_source_gap: cross cp_run, cp_prefill, cp_source_gap;
  endgroup

  covergroup stop_tlast_drain_cg with function sample(bit stop_seen,
                                                       bit tlast_seen,
                                                       bit drain_seen);
    option.per_instance = 1;
    cp_stop: coverpoint stop_seen iff (stop_seen) { bins observed={1}; }
    cp_tlast: coverpoint tlast_seen iff (tlast_seen) { bins observed={1}; }
    cp_drain: coverpoint drain_seen iff (drain_seen) { bins observed={1}; }
    x_stop_tlast_drain: cross cp_stop, cp_tlast, cp_drain;
  endgroup

  covergroup source_cg with function sample(bit full, bit stalled, bit start,
                                              bit reset_low, bit signed_min,
                                              bit signed_max, bit packet_end,
                                              int unsigned packet_quanta);
    option.per_instance = 1;
    cp_full: coverpoint full { bins not_full={0}; bins full={1}; }
    cp_stalled: coverpoint stalled { bins flowing={0}; bins backpressured={1}; }
    cp_start: coverpoint start { bins ordinary={0}; bins frame={1}; }
    cp_reset: coverpoint reset_low { bins active={0}; bins reset={1}; }
    cp_signed_min: coverpoint signed_min { bins absent={0}; bins present={1}; }
    cp_signed_max: coverpoint signed_max { bins absent={0}; bins present={1}; }
    cp_packet_end: coverpoint packet_end { bins no_end={0}; bins accepted_end={1}; }
    cp_packet_quanta: coverpoint packet_quanta iff (packet_end) {
      bins malformed_early={0}; bins one_quantum={1};
      bins extended={[2:$]};
    }
    x_frame_packet_end: cross cp_start, cp_packet_end {
      bins ordinary_word = binsof(cp_start.ordinary) && binsof(cp_packet_end.no_end);
      bins frame_start_word = binsof(cp_start.frame) && binsof(cp_packet_end.no_end);
      bins frame_end_word = binsof(cp_start.ordinary) && binsof(cp_packet_end.accepted_end);
      ignore_bins start_and_end_same_beat =
        binsof(cp_start.frame) && binsof(cp_packet_end.accepted_end);
    }
  endgroup

  covergroup core_cg with function sample(bit underflow, bit illegal, bit pa_stall, bit pa_word);
    option.per_instance = 1;
    cp_underflow: coverpoint underflow { bins normal={0}; bins empty={1}; }
    cp_illegal: coverpoint illegal { bins legal={0}; bins bad_frame={1}; }
    cp_pa_stall: coverpoint pa_stall { bins ready={0}; bins stalled={1}; }
    cp_pa_word: coverpoint pa_word { bins no_word={0}; bins four_plane_word={1}; }
  endgroup

  covergroup ef2_cg with function sample(bit positive_clamp, bit negative_clamp,
                                         bit positive_candidate, bit negative_candidate,
                                         bit clamp_stalled, bit tidsm_stalled,
                                         bit at_state_rail);
    option.per_instance = 1;
    cp_positive: coverpoint positive_clamp { bins absent={0}; bins observed={1}; }
    cp_negative: coverpoint negative_clamp { bins absent={0}; bins observed={1}; }
    cp_positive_candidate: coverpoint positive_candidate { bins absent={0}; bins observed={1}; }
    cp_negative_candidate: coverpoint negative_candidate { bins absent={0}; bins observed={1}; }
    cp_clamp_stall: coverpoint clamp_stalled { bins no={0}; bins held={1}; }
    cp_tidsm_stall: coverpoint tidsm_stalled { bins ready={0}; bins stalled={1}; }
    cp_state_rail: coverpoint at_state_rail { bins below_rail={0}; bins at_rail={1}; }
    positive_candidate_x_stall: cross cp_positive_candidate, cp_tidsm_stall;
    negative_candidate_x_stall: cross cp_negative_candidate, cp_tidsm_stall;
    positive_x_rail: cross cp_positive, cp_state_rail;
    negative_x_rail: cross cp_negative, cp_state_rail;
    state_rail_x_stall: cross cp_state_rail, cp_tidsm_stall;
  endgroup

  // All four planes represent one thermometric symbol. Partial READY is legal,
  // but must hold all four data planes together until every sink is ready.
  covergroup plane_atomic_cg with function sample(logic [3:0] valid_mask,
                                                   logic [3:0] ready_mask);
    option.per_instance = 1;
    cp_valid_mask: coverpoint valid_mask {
      bins none = {4'h0};
      bins all = {4'hf};
      illegal_bins partial = default;
    }
    cp_ready_mask: coverpoint ready_mask {
      bins blocked = {4'h0};
      bins all = {4'hf};
      bins partial = default;
    }
    x_valid_ready_atomicity: cross cp_valid_mask, cp_ready_mask;
  endgroup

  // The AXI-Lite STOP/restart test calls this only after it has checked the
  // corresponding externally visible condition (draining STATUS, first
  // packet completion, blocked second packet, RUN restart, and final drain).
  covergroup stop_restart_cg with function sample(bit [2:0] event_code);
    option.per_instance = 1;
    cp_stop_restart_event: coverpoint event_code {
      bins stop_while_packet_open = {0};
      bins first_packet_drained = {1};
      bins drained_idle_observed = {2};
      bins second_packet_blocked = {3};
      bins run_reasserted = {4};
      bins second_packet_drained = {5};
      illegal_bins invalid_event = default;
    }
  endgroup

  covergroup transaction_event_cg with function sample(bit [3:0] event_kind);
    option.per_instance = 1;
    cp_kind: coverpoint event_kind {
      bins source_beat = {THERMO5_EVENT_SOURCE_BEAT};
      bins pa_word = {THERMO5_EVENT_PA_WORD};
      bins axil_write = {THERMO5_EVENT_AXIL_WRITE};
      bins axil_read = {THERMO5_EVENT_AXIL_READ};
      bins axil_response = {THERMO5_EVENT_AXIL_RESPONSE};
      bins cdc_word = {THERMO5_EVENT_CDC_WORD};
      bins dsp_observation = {THERMO5_EVENT_DSP_OBSERVATION};
      bins ef2_word = {THERMO5_EVENT_EF2_WORD};
      bins ef2_stall = {THERMO5_EVENT_EF2_STALL};
      bins reset = {THERMO5_EVENT_RESET};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_cg=new(); core_cg=new(); plane_atomic_cg=new(); ef2_cg=new();
    stop_restart_cg=new(); transaction_event_cg=new();
    source_gap_pa_fifo_cg=new(); run_prefill_gap_cg=new();
    stop_tlast_drain_cg=new();
    event_imp=new("event_imp",this);
  endfunction

  function void write_event(thermo5_transaction_event tr);
    int unsigned index;
    longint unsigned key;
    packet_cross_record_t record;
    index=tr.kind;
    if (index<10) event_counts[index]++;
    transaction_event_cg.sample(tr.kind);
    case (tr.kind)
      THERMO5_EVENT_RESET: begin
        packet_cross.delete();
        packet_cross_keys.delete();
        last_source_packet_valid=0;
        run_active=0;
        stop_candidate_valid=0;
      end
      THERMO5_EVENT_SOURCE_BEAT: begin
        if (!tr.packet_id_valid)
          `uvm_error("PACKET_ID_MISSING","Accepted AXIS transaction has no packet ID")
        key=packet_key(tr.epoch,tr.packet_id);
        record=get_packet_record(tr.epoch,tr.packet_id);
        record.source_beats++;
        if (run_active) record.run_seen=1;
        if (tr.valid_gap_cycles!=0) record.source_gap=1;
        if (tr.valid_gap_cycles!=0 && record.run_seen &&
            record.prefill_before_run)
          record.source_gap_after_run=1;
        if (tr.tlast) begin
          record.tlast_seen=1;
          if (stop_candidate_valid && key==stop_candidate_key &&
              record.stop_before_tlast && tr.event_id>record.stop_event_id) begin
            record.tlast_after_stop=1;
            record.tlast_event_id=tr.event_id;
          end
        end
        packet_cross[key]=record;
        last_source_epoch=tr.epoch;
        last_source_packet_id=tr.packet_id;
        last_source_packet_valid=1;
      end
      THERMO5_EVENT_AXIL_WRITE: begin
        if (tr.axil_addr==8'h00 && tr.axil_strb[0]) begin
          if (last_source_packet_valid) begin
            key=packet_key(last_source_epoch,last_source_packet_id);
            record=get_packet_record(last_source_epoch,last_source_packet_id);
            if (tr.axil_data[0]) begin
              run_active=1;
              if (!record.run_seen && record.source_beats!=0 && !record.tlast_seen)
                record.prefill_before_run=1;
              record.run_seen=1;
            end else begin
              if (record.run_seen && record.source_beats!=0 &&
                  !record.tlast_seen) begin
              // The cross is specifically STOP-before-TLAST. A TLAST that
              // was already observed can never be retroactively paired with
              // a later STOP write.
                record.stop_before_tlast=1;
                record.stop_event_id=tr.event_id;
                stop_candidate_key=key;
                stop_candidate_valid=1;
              end
              run_active=0;
            end
            packet_cross[key]=record;
          end
        end
      end
      THERMO5_EVENT_AXIL_RESPONSE: begin
        if (!tr.is_write && tr.axil_addr==8'h04 &&
            tr.axil_resp==2'b00 && tr.axil_rdata[4:3]==2'b00 &&
            stop_candidate_valid) begin
          key=stop_candidate_key;
          if (packet_cross.exists(key)) begin
            record=packet_cross[key];
            if (record.stop_before_tlast && record.tlast_after_stop &&
                tr.event_id>record.tlast_event_id) begin
              record.drain_after_tlast=1;
              record.drain_event_id=tr.event_id;
              packet_cross[key]=record;
            end
          end
        end
      end
      default: begin end
    endcase
  endfunction

  function void sample_stop_restart(bit [2:0] event_code);
    stop_restart_cg.sample(event_code);
  endfunction

  function void finalize_packet_crosses(bit integrity_pass);
    packet_cross_record_t record;
    longint unsigned key;
    int sampled_gap_fifo_pa=0, sampled_run_prefill_gap=0;
    int sampled_stop_tlast_drain=0;
    if (!integrity_pass) begin
      `uvm_error("COVERAGE_INTEGRITY","Scenario crosses cannot be finalized without a passing DUT integrity check")
      return;
    end
    for (int unsigned index=0;index<packet_cross_keys.size();index++) begin
      key=packet_cross_keys[index];
      if (!packet_cross.exists(key)) continue;
      record=packet_cross[key];
      if (record.finalized) continue;
      record.finalized=1;
      packet_cross[key]=record;
      if (record.source_gap && record.fifo_full && record.pa_stall) begin
        source_gap_pa_fifo_cg.sample(1'b1,1'b1,1'b1);
        source_gap_pa_fifo_full_hits++;
        sampled_gap_fifo_pa++;
      end
      if (record.run_seen && record.prefill_before_run &&
          record.source_gap_after_run) begin
        run_prefill_gap_cg.sample(1'b1,1'b1,1'b1);
        run_prefill_gap_hits++;
        sampled_run_prefill_gap++;
      end
      if (record.stop_before_tlast && record.tlast_after_stop &&
          record.drain_after_tlast) begin
        stop_tlast_drain_cg.sample(1'b1,1'b1,1'b1);
        stop_tlast_drain_hits++;
        sampled_stop_tlast_drain++;
      end
      `uvm_info("PACKET_CROSS_AUDIT",
        $sformatf("epoch=%0d packet=%0d source_gap=%b fifo_full=%b pa_stall=%b run=%b prefill=%b gap_after_run=%b stop_before_tlast=%b tlast_after_stop=%b drain_after_tlast=%b integrity=PASS",
          record.epoch,record.packet_id,record.source_gap,record.fifo_full,
          record.pa_stall,record.run_seen,record.prefill_before_run,
          record.source_gap_after_run,record.stop_before_tlast,
          record.tlast_after_stop,record.drain_after_tlast),UVM_MEDIUM)
    end
    `uvm_info("PACKET_CROSS_FINALIZE",
      $sformatf("integrity=PASS packet_records=%0d gap_fifo_pa=%0d run_prefill_gap=%0d stop_tlast_drain=%0d",
        packet_cross_keys.size(),sampled_gap_fifo_pa,sampled_run_prefill_gap,
        sampled_stop_tlast_drain),UVM_LOW)
  endfunction

  function void sample_random_packet_crosses();
    // Legacy call site retained: it occurs only after the test has completed
    // its independent source/CDC/EF2/PA and STATUS checks.
    finalize_packet_crosses(1'b1);
  endfunction

  function bit has_source_gap_fifo_pa_packet();
    return source_gap_pa_fifo_full_hits!=0;
  endfunction

  function int unsigned split_packet_cross_count();
    packet_cross_record_t record;
    int unsigned count;
    for (int unsigned index=0;index<packet_cross_keys.size();index++) begin
      if (packet_cross.exists(packet_cross_keys[index])) begin
        record=packet_cross[packet_cross_keys[index]];
        if ((record.source_gap || record.fifo_full || record.pa_stall) &&
            !(record.source_gap && record.fifo_full && record.pa_stall))
          count++;
      end
    end
    return count;
  endfunction

  function bit audit_split_packet_negative();
    packet_cross_record_t record;
    longint unsigned key;
    packet_cross.delete();
    packet_cross_keys.delete();
    source_gap_pa_fifo_full_hits=0;
    run_prefill_gap_hits=0;
    stop_tlast_drain_hits=0;
    record='0;
    record.epoch=32'hffff_fffe;
    record.packet_id=0;
    record.source_gap=1;
    key=packet_key(record.epoch,record.packet_id);
    packet_cross[key]=record;
    packet_cross_keys.push_back(key);
    record='0;
    record.epoch=32'hffff_fffe;
    record.packet_id=1;
    record.fifo_full=1;
    record.pa_stall=1;
    key=packet_key(record.epoch,record.packet_id);
    packet_cross[key]=record;
    packet_cross_keys.push_back(key);
    finalize_packet_crosses(1'b1);
    if (source_gap_pa_fifo_full_hits!=0 ||
        source_gap_pa_fifo_cg.get_coverage()!=0.0) begin
      `uvm_error("CROSS_PACKET_FALSE_HIT",
        "Source gap from packet 0 combined with FIFO-full/PA-stall from packet 1")
      return 0;
    end
    packet_cross.delete();
    packet_cross_keys.delete();
    last_source_packet_valid=0;
    run_active=0;
    stop_candidate_valid=0;
    `uvm_info("CROSS_PACKET_NEGATIVE_PASS",
      "packet 0 source gap and packet 1 FIFO-full/PA-stall did not hit the same-packet Cross",
      UVM_NONE)
    return 1;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","thermo5 coverage interface is missing")
    if (!uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","thermo5 coverage configuration is missing")
  endfunction

  task run_phase(uvm_phase phase);
    bit accepted_min, accepted_max;
    bit accepted_last;
    int unsigned sampled_packet_quanta;
    packet_cross_record_t packet_record;
    longint unsigned packet_record_key;
    fork
      forever begin
        @(posedge vif.src_clk);
        accepted_min=0;
        accepted_max=0;
        accepted_last=vif.src_valid && vif.src_ready && vif.src_last;
        sampled_packet_quanta=0;
        if (accepted_last && ((packet_beats_since_boundary+1)%32)==0)
          sampled_packet_quanta=(packet_beats_since_boundary+1)/32;
        if (vif.src_valid && vif.src_ready) begin
          for (int lane=0;lane<14;lane++) begin
            if (vif.src_i[lane*16+:16]===16'h8000 ||
                vif.src_q[lane*16+:16]===16'h8000) accepted_min=1;
            if (vif.src_i[lane*16+:16]===16'h7fff ||
                vif.src_q[lane*16+:16]===16'h7fff) accepted_max=1;
          end
        end
        source_cg.sample(vif.fifo_full, vif.src_valid && !vif.src_ready,
                         vif.src_valid && vif.src_ready && vif.frame_start,
                         !vif.src_rst_n, accepted_min, accepted_max,
                         accepted_last, sampled_packet_quanta);
        if (seen_src_release && last_src_rst_n && !vif.src_rst_n) reset_reassertions++;
        if (!vif.src_rst_n) packet_beats_since_boundary=0;
        if (!vif.src_rst_n) begin
          accepted_source_beats_epoch=0;
          pending_tlast_output_targets.delete();
          pending_tlast_cdc_output_targets.delete();
        end
        else if (vif.src_valid && vif.src_ready) begin
          accepted_source_beats_epoch++;
          // Every accepted frame tail has an exact 14:8 output position,
          // including short Generic-FIFO frames used by the starvation test.
          // Packet-quantum coverage remains separately gated by the legal
          // 32-beat boundary in source_cg above.
          if (accepted_last) begin
            pending_tlast_output_targets.push_back(
              (accepted_source_beats_epoch*7)/4);
            pending_tlast_cdc_output_targets.push_back(
              (accepted_source_beats_epoch*7)/4);
          end
          packet_beats_since_boundary++;
          if (vif.src_last && packet_beats_since_boundary%32==0)
            packet_beats_since_boundary=0;
        end
        if (vif.src_rst_n) seen_src_release=1;
        last_src_rst_n=vif.src_rst_n;
        if (vif.src_rst_n) begin
          if (vif.fifo_full) begin
            fifo_full_cycles++;
            if (last_source_packet_valid) begin
              packet_record_key=packet_key(last_source_epoch,last_source_packet_id);
              packet_record=get_packet_record(last_source_epoch,last_source_packet_id);
              packet_record.fifo_full=1;
              packet_cross[packet_record_key]=packet_record;
            end
          end
          if (vif.src_valid && !vif.src_ready) source_stall_cycles++;
          if (vif.src_valid && vif.src_ready && vif.frame_start) frame_starts++;
          if (accepted_min) signed_min_beats++;
          if (accepted_max) signed_max_beats++;
          if (accepted_last) accepted_tlast_markers++;
        end
      end
      forever begin
        @(posedge vif.core_clk);
        plane_atomic_cg.sample(vif.pa_valid, vif.pa_ready);
        ef2_cg.sample(|vif.ef2_pos_clamp_event, |vif.ef2_neg_clamp_event,
                      |vif.ef2_pos_clamp_candidate, |vif.ef2_neg_clamp_candidate,
                      vif.ef2_clamp_stalled, vif.ef2_tidsm_stalled,
                      |vif.ef2_state_at_rail);
        core_cg.sample(vif.underflow, vif.protocol_error,
                       vif.pa_valid==4'hf && vif.pa_ready!=4'hf,
                       vif.pa_valid==4'hf && vif.pa_ready==4'hf);
        if (vif.core_rst_n) begin
          if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf &&
              last_source_packet_valid && output_words_per_packet!=0) begin
            int unsigned output_packet_id;
            output_packet_id=accepted_output_words_epoch/output_words_per_packet;
            packet_record_key=packet_key(last_source_epoch,output_packet_id);
            packet_record=get_packet_record(last_source_epoch,output_packet_id);
            packet_record.pa_stall=1;
            packet_cross[packet_record_key]=packet_record;
          end
          if (!cfg.illegal_frame) begin
            if (vif.cdc_end_false_arm)
              cdc_end_remaining_false_arm_events++;
            if (vif.cdc_core_valid && vif.cdc_core_ready) begin
              int unsigned next_cdc_output_word;
              bit expected_cdc_frame_end;
              next_cdc_output_word=accepted_cdc_output_words_epoch+1;
              expected_cdc_frame_end=0;
              if (pending_tlast_cdc_output_targets.size()!=0 &&
                  next_cdc_output_word==pending_tlast_cdc_output_targets[0])
                expected_cdc_frame_end=1;
              if (vif.cdc_frame_end !== expected_cdc_frame_end)
                `uvm_error("CDC_FRAME_END",
                  $sformatf("CDC word=%0d frame_end=%b expected=%b pending_target=%0d",
                    next_cdc_output_word,vif.cdc_frame_end,expected_cdc_frame_end,
                    pending_tlast_cdc_output_targets.size()!=0 ?
                      pending_tlast_cdc_output_targets[0] : 0))
              if (expected_cdc_frame_end) begin
                cdc_frame_end_events++;
                void'(pending_tlast_cdc_output_targets.pop_front());
              end
              accepted_cdc_output_words_epoch=next_cdc_output_word;
            end
          end
          if (cfg.axil_control && vif.cfg_pending_valid && !vif.core_run_request)
            commit_pending_while_stopped_cycles++;
          if (cfg.axil_control && !vif.core_run_request && vif.core_tx_active &&
              vif.pa_valid==4'hf && vif.pa_ready!=4'hf)
            stop_partial_pa_stall_cycles++;
          // Count this cross only while a legal accepted TLAST still has
          // corresponding output words outstanding. The target is cumulative
          // (7 output words per four 14-sample AXIS beats), and the PA word
          // progress is observed independently in this clock domain.
          if (pending_tlast_output_targets.size()!=0 &&
              accepted_output_words_epoch<pending_tlast_output_targets[0] &&
              vif.pa_valid==4'hf && vif.pa_ready!=4'hf)
            tlast_pa_stall_cycles++;
          if (|vif.ef2_pos_clamp_event) ef2_positive_clamp_events++;
          if (|vif.ef2_neg_clamp_event) ef2_negative_clamp_events++;
          for (int branch=0;branch<4;branch++) begin
            if (vif.ef2_pos_clamp_event[branch]) ef2_positive_clamp_branch[branch]++;
            if (vif.ef2_neg_clamp_event[branch]) ef2_negative_clamp_branch[branch]++;
          end
          if (vif.ef2_clamp_stalled) ef2_clamp_stall_cycles++;
          if (vif.ef2_tidsm_stalled) ef2_tidsm_stall_cycles++;
          if ((|vif.ef2_state_at_rail) && vif.ef2_tidsm_stalled)
            ef2_state_rail_stall_cycles++;
          if (|vif.ef2_state_at_rail) ef2_state_rail_cycles++;
          if (vif.underflow) begin
            underflow_cycles++;
            if (vif.accepted_beats<cfg.source_beats) underflow_before_last_source++;
          end
          if (vif.protocol_error) protocol_error_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf) pa_stall_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf && vif.pa_ready!=4'h0)
            pa_partial_ready_stall_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready==4'hf) begin
            pa_words++;
            accepted_output_words_epoch++;
            while (pending_tlast_output_targets.size()!=0 &&
                   accepted_output_words_epoch>=pending_tlast_output_targets[0])
              void'(pending_tlast_output_targets.pop_front());
          end
          if (vif.ef2_state_zero !== 4'hf) ef2_state_nonzero_seen=1'b1;
        end
      end
      forever begin
        @(negedge vif.core_rst_n);
        accepted_output_words_epoch=0;
        pending_tlast_output_targets.delete();
        accepted_cdc_output_words_epoch=0;
        pending_tlast_cdc_output_targets.delete();
        if (ef2_state_nonzero_seen && vif.ef2_order2_enabled)
          reset_nonzero_ef2_state_events++;
        ef2_state_nonzero_seen=1'b0;
      end
    join
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SKU_COVERAGE",$sformatf("full=%0d source_stall=%0d frame=%0d accepted_tlast=%0d cdc_words=%0d cdc_frame_end=%0d cdc_end_false_arm=%0d tlast_pa_stall=%0d stop_partial_pa_stall=%0d commit_pending_stopped=%0d reset_nonzero_ef2=%0d reset=%0d underflow=%0d early_underflow=%0d illegal=%0d pa_stall=%0d pa_partial_ready_stall=%0d pa_words=%0d signed_min_beats=%0d signed_max_beats=%0d ef2_pos_clamp=%0d ef2_neg_clamp=%0d ef2_clamp_stall=%0d ef2_tidsm_stall=%0d ef2_rail=%0d ef2_rail_stall=%0d source_gap_pa_fifo_hits=%0d run_prefill_gap_hits=%0d stop_tlast_drain_hits=%0d source_gap_pa_fifo_cg=%.1f run_prefill_gap_cg=%.1f stop_tlast_drain_cg=%.1f source_cg=%.1f core_cg=%.1f plane_atomic_cg=%.1f stop_restart_cg=%.1f ef2_cg=%.1f",
      fifo_full_cycles,source_stall_cycles,frame_starts,accepted_tlast_markers,
      accepted_cdc_output_words_epoch,cdc_frame_end_events,
      cdc_end_remaining_false_arm_events,
      tlast_pa_stall_cycles,stop_partial_pa_stall_cycles,
      commit_pending_while_stopped_cycles,reset_nonzero_ef2_state_events,reset_reassertions,
      underflow_cycles,underflow_before_last_source,protocol_error_cycles,pa_stall_cycles,
      pa_partial_ready_stall_cycles,pa_words,
      signed_min_beats,signed_max_beats,
      ef2_positive_clamp_events,ef2_negative_clamp_events,
      ef2_clamp_stall_cycles,ef2_tidsm_stall_cycles,ef2_state_rail_cycles,
      ef2_state_rail_stall_cycles,source_gap_pa_fifo_full_hits,run_prefill_gap_hits,
      stop_tlast_drain_hits,source_gap_pa_fifo_cg.get_coverage(),
      run_prefill_gap_cg.get_coverage(),stop_tlast_drain_cg.get_coverage(),
      source_cg.get_coverage(),core_cg.get_coverage(),
      plane_atomic_cg.get_coverage(),stop_restart_cg.get_coverage(),
      ef2_cg.get_coverage()),UVM_NONE)
    `uvm_info("THERMO5_EVENT_COVERAGE",
      $sformatf("stream=%.1f%% src=%0d pa=%0d axil_wr=%0d axil_rd=%0d axil_rsp=%0d cdc=%0d dsp=%0d ef2=%0d ef2_stall=%0d reset=%0d",
        transaction_event_cg.get_coverage(),
        event_counts[THERMO5_EVENT_SOURCE_BEAT],event_counts[THERMO5_EVENT_PA_WORD],
        event_counts[THERMO5_EVENT_AXIL_WRITE],event_counts[THERMO5_EVENT_AXIL_READ],
        event_counts[THERMO5_EVENT_AXIL_RESPONSE],event_counts[THERMO5_EVENT_CDC_WORD],
        event_counts[THERMO5_EVENT_DSP_OBSERVATION],event_counts[THERMO5_EVENT_EF2_WORD],
        event_counts[THERMO5_EVENT_EF2_STALL],event_counts[THERMO5_EVENT_RESET]),UVM_NONE)
  endfunction

  function void connect_phase(uvm_phase phase);
    int unsigned packet_count;
    super.connect_phase(phase);
    if (cfg.source_beats>=32 && cfg.source_beats%32==0) begin
      packet_count=cfg.source_beats/32;
      if (packet_count!=0 && cfg.core_words%packet_count==0)
        output_words_per_packet=cfg.core_words/packet_count;
      else
        `uvm_error("PACKET_OUTPUT_RATIO",
          $sformatf("Cannot map PA output words to AXIS packets: source=%0d output=%0d",
            cfg.source_beats,cfg.core_words))
    end else begin
      `uvm_error("PACKET_LENGTH_CONTRACT",
        $sformatf("Packet-scoped coverage requires 32-beat packets, source_beats=%0d",
          cfg.source_beats))
    end
  endfunction
endclass
