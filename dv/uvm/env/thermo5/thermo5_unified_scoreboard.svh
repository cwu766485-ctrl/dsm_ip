// Monitor-only transaction checker. It reconstructs the 14:8 CDC gearbox
// stream from accepted AXIS beats and compares it with accepted CDC words.
// The PA oracle remains the independent static bit-true scoreboard; this
// component never uses DUT observations to synthesize expected PA values.
class thermo5_unified_scoreboard extends uvm_component;
  `uvm_component_utils(thermo5_unified_scoreboard)

  uvm_analysis_imp_event#(thermo5_transaction_event,
                          thermo5_unified_scoreboard) event_imp;
  thermo5_sku_config cfg;

  logic signed [15:0] expected_i_samples[$];
  logic signed [15:0] expected_q_samples[$];
  bit expected_start_samples[$];
  bit expected_end_samples[$];
  logic signed [15:0] expected_gain_samples[$];
  int unsigned expected_frame_ids[$];
  logic signed [15:0] expected_ef2_i_samples[$];
  logic signed [15:0] expected_ef2_q_samples[$];

  longint unsigned expected_event_id;
  int unsigned active_epoch;
  int unsigned expected_source_index, expected_cdc_index;
  int unsigned source_frame_id, expected_cdc_frame_id;
  int unsigned next_expected_config_id, active_config_id, pending_config_id;
  int unsigned expected_commit_ids[$];
  bit have_source_frame_id, have_expected_cdc_frame_id;
  bit config_pending_model, config_applied_model, config_ack_model;
  bit previous_cfg_pending, previous_cfg_ack_core, previous_cfg_done;
  int unsigned source_samples, cdc_samples, reset_discarded_samples;
  int unsigned source_beats, cdc_words, pa_words, axil_writes, axil_reads;
  int unsigned dsp_snapshots, ef2_words, ef2_stalls, reset_events;
  int unsigned cdc_data_mismatches, cdc_metadata_mismatches;
  int unsigned ef2_data_mismatches;
  bit ef2_reference_loaded;
  int unsigned negative_frame_metadata_skips;
  int unsigned event_id_gaps, epoch_mismatches, index_mismatches;
  bit have_epoch, have_event_id;
  bit have_dpd_snapshot;
  int unsigned previous_dpd_samples[16];
  int unsigned previous_dpd_saturations[16];

  function new(string name, uvm_component parent);
    super.new(name,parent);
    event_imp=new("event_imp",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(thermo5_sku_config)::get(this,"","cfg",cfg))
      `uvm_fatal("UNIFIED_SCOREBOARD_CFG","Unified scoreboard requires SKU configuration")
    if (cfg.ef2_reference_enable) load_ef2_reference();
  endfunction

  function void load_ef2_reference();
    integer fd;
    integer scan_result;
    logic [15:0] word;
    string path;
    int unsigned expected_samples;
    expected_samples=cfg.core_words*32;

    path=$sformatf("%s/tid32_thermo5_frontend_ef2_i.mem",cfg.vector_dir);
    fd=$fopen(path,"r");
    if (fd==0) `uvm_fatal("EF2_REFERENCE_OPEN",$sformatf("Cannot open %s",path))
    scan_result=$fscanf(fd,"%h",word);
    while (scan_result==1) begin
      expected_ef2_i_samples.push_back($signed(word));
      scan_result=$fscanf(fd,"%h",word);
    end
    $fclose(fd);
    if (scan_result!=-1)
      `uvm_fatal("EF2_REFERENCE_FORMAT",$sformatf("Invalid hex data in %s",path))

    path=$sformatf("%s/tid32_thermo5_frontend_ef2_q.mem",cfg.vector_dir);
    fd=$fopen(path,"r");
    if (fd==0) `uvm_fatal("EF2_REFERENCE_OPEN",$sformatf("Cannot open %s",path))
    scan_result=$fscanf(fd,"%h",word);
    while (scan_result==1) begin
      expected_ef2_q_samples.push_back($signed(word));
      scan_result=$fscanf(fd,"%h",word);
    end
    $fclose(fd);
    if (scan_result!=-1)
      `uvm_fatal("EF2_REFERENCE_FORMAT",$sformatf("Invalid hex data in %s",path))

    if (expected_ef2_i_samples.size()!=expected_samples ||
        expected_ef2_q_samples.size()!=expected_samples)
      `uvm_fatal("EF2_REFERENCE_SIZE",
        $sformatf("Expected %0d EF2 samples per component, got I=%0d Q=%0d",
          expected_samples,expected_ef2_i_samples.size(),
          expected_ef2_q_samples.size()))
    ef2_reference_loaded=1;
    `uvm_info("EF2_REFERENCE",
      $sformatf("Loaded %0d independently modeled I/Q samples from %s",
        expected_samples,cfg.vector_dir),UVM_LOW)
  endfunction

  function void clear_epoch_state(input int unsigned next_epoch);
    reset_discarded_samples += expected_i_samples.size();
    expected_i_samples.delete();
    expected_q_samples.delete();
    expected_start_samples.delete();
    expected_end_samples.delete();
    expected_gain_samples.delete();
    expected_frame_ids.delete();
    active_epoch=next_epoch;
    expected_source_index=0;
    expected_cdc_index=0;
    source_frame_id=0;
    expected_cdc_frame_id=0;
    have_source_frame_id=0;
    have_expected_cdc_frame_id=0;
    next_expected_config_id=1;
    active_config_id=0;
    pending_config_id=0;
    expected_commit_ids.delete();
    config_pending_model=0;
    config_applied_model=0;
    config_ack_model=0;
    previous_cfg_pending=0;
    previous_cfg_ack_core=0;
    previous_cfg_done=0;
    source_samples=0;
    cdc_samples=0;
    source_beats=0;
    cdc_words=0;
    pa_words=0;
    axil_writes=0;
    axil_reads=0;
    dsp_snapshots=0;
    ef2_words=0;
    ef2_stalls=0;
    have_dpd_snapshot=0;
  endfunction

  function void check_epoch(input int unsigned observed_epoch,
                            input string event_name);
    if (!have_epoch) begin
      active_epoch=observed_epoch;
      have_epoch=1;
    end else if (observed_epoch!=active_epoch) begin
      epoch_mismatches++;
      `uvm_error("UNIFIED_EPOCH",
        $sformatf("%s event epoch=%0d expected current epoch=%0d",
          event_name,observed_epoch,active_epoch))
    end
  endfunction

  function void write_event(thermo5_transaction_event tr);
    if (have_event_id && tr.event_id!=expected_event_id) begin
      event_id_gaps++;
      `uvm_error("UNIFIED_EVENT_ID",
        $sformatf("event ID=%0d expected=%0d kind=%0d",
          tr.event_id,expected_event_id,tr.kind))
    end
    have_event_id=1;
    expected_event_id=tr.event_id+1;

    if (tr.kind==THERMO5_EVENT_RESET) begin
      if (have_epoch && tr.epoch!=active_epoch+1) begin
        epoch_mismatches++;
        `uvm_error("UNIFIED_RESET_EPOCH",
          $sformatf("reset announced epoch=%0d after epoch=%0d",
            tr.epoch,active_epoch))
      end
      reset_events++;
      clear_epoch_state(tr.epoch);
      have_epoch=1;
      return;
    end

    check_epoch(tr.epoch,$sformatf("kind=%0d",tr.kind));
    check_config_event(tr);
    case (tr.kind)
      THERMO5_EVENT_SOURCE_BEAT: check_source(tr);
      THERMO5_EVENT_CDC_WORD: check_cdc(tr);
      THERMO5_EVENT_PA_WORD: begin
        if (tr.local_index!=pa_words)
          index_error("PA",tr.local_index,pa_words);
        pa_words++;
      end
      THERMO5_EVENT_AXIL_WRITE: axil_writes++;
      THERMO5_EVENT_AXIL_READ: axil_reads++;
      THERMO5_EVENT_DSP_OBSERVATION: check_dsp(tr);
      THERMO5_EVENT_EF2_WORD: begin
        check_ef2(tr);
      end
      THERMO5_EVENT_EF2_STALL: ef2_stalls++;
      default: begin end
    endcase
  endfunction

  function void check_ef2(thermo5_transaction_event tr);
    logic signed [15:0] expected_i, expected_q;
    logic signed [15:0] observed_i, observed_q;
    int unsigned sample_index;
    int first_bad_lane;
    bit word_mismatch;
    if (tr.local_index!=ef2_words)
      index_error("EF2",tr.local_index,ef2_words);
    word_mismatch=0;
    first_bad_lane=-1;
    if (cfg.ef2_reference_enable) begin
      if (!ef2_reference_loaded)
        `uvm_fatal("EF2_REFERENCE_MISSING","Online EF2 comparison enabled without a loaded reference")
      for (int lane=0;lane<32;lane++) begin
        sample_index=tr.local_index*32+lane;
        if (sample_index>=expected_ef2_i_samples.size() ||
            sample_index>=expected_ef2_q_samples.size()) begin
          ef2_data_mismatches++;
          `uvm_error("UNIFIED_EF2_INDEX",
            $sformatf("epoch=%0d word=%0d lane=%0d sample index=%0d exceeds sidecar I/Q sizes %0d/%0d",
              active_epoch,tr.local_index,lane,sample_index,
              expected_ef2_i_samples.size(),expected_ef2_q_samples.size()))
          return;
        end
        expected_i=expected_ef2_i_samples[sample_index];
        expected_q=expected_ef2_q_samples[sample_index];
        observed_i=$signed(tr.ef2_i[lane*16+:16]);
        observed_q=$signed(tr.ef2_q[lane*16+:16]);
        if (observed_i!==expected_i || observed_q!==expected_q) begin
          ef2_data_mismatches++;
          if (!word_mismatch) first_bad_lane=lane;
          word_mismatch=1;
        end
      end
      if (word_mismatch) begin
        sample_index=tr.local_index*32+first_bad_lane;
        `uvm_error("UNIFIED_EF2_DATA",
          $sformatf("epoch=%0d word=%0d lane=%0d I=%0d expected=%0d Q=%0d expected=%0d",
            active_epoch,tr.local_index,first_bad_lane,
            $signed(tr.ef2_i[first_bad_lane*16+:16]),
            expected_ef2_i_samples[sample_index],
            $signed(tr.ef2_q[first_bad_lane*16+:16]),
            expected_ef2_q_samples[sample_index]))
      end
    end
    ef2_words++;
  endfunction

  function void check_source(thermo5_transaction_event tr);
    if (tr.frame_start) begin
      if (have_source_frame_id) source_frame_id++;
      else have_source_frame_id=1;
    end
    if (!tr.frame_id_valid || tr.frame_id!=source_frame_id)
      frame_id_error("AXIS",tr.frame_id,source_frame_id);
    if (tr.local_index!=expected_source_index)
      index_error("AXIS",tr.local_index,expected_source_index);
    expected_source_index++;
    source_beats++;
    for (int lane=0;lane<14;lane++) begin
      expected_i_samples.push_back($signed(tr.source_i[lane*16+:16]));
      expected_q_samples.push_back($signed(tr.source_q[lane*16+:16]));
      expected_start_samples.push_back((lane==0) && tr.frame_start);
      expected_end_samples.push_back((lane==13) && tr.tlast);
      expected_gain_samples.push_back(tr.frame_gain);
      expected_frame_ids.push_back(tr.frame_id);
    end
    source_samples+=14;
  endfunction

  function void check_cdc(thermo5_transaction_event tr);
    logic [127:0] expected_i, expected_q;
    logic [15:0] expected_gain;
    bit expected_start, expected_end;

    if (tr.local_index!=expected_cdc_index)
      index_error("CDC",tr.local_index,expected_cdc_index);
    expected_cdc_index++;
    cdc_words++;
    if (expected_i_samples.size()<8) begin
      cdc_data_mismatches++;
      `uvm_error("UNIFIED_CDC_UNDERFLOW",
        $sformatf("CDC word %0d has only %0d independently queued source samples",
          tr.local_index,expected_i_samples.size()))
      return;
    end

    expected_i='0;
    expected_q='0;
    expected_start=0;
    expected_end=0;
    expected_gain='0;
    for (int lane=0;lane<8;lane++) begin
      logic signed [15:0] expected_i_sample, expected_q_sample;
      logic signed [15:0] sample_gain;
      bit sample_start, sample_end;
      int unsigned sample_frame_id;
      expected_i_sample=expected_i_samples.pop_front();
      expected_q_sample=expected_q_samples.pop_front();
      sample_start=expected_start_samples.pop_front();
      sample_end=expected_end_samples.pop_front();
      sample_gain=expected_gain_samples.pop_front();
      sample_frame_id=expected_frame_ids.pop_front();
      expected_i[lane*16+:16]=expected_i_sample;
      expected_q[lane*16+:16]=expected_q_sample;
      if (sample_start) begin
        if (lane==0) begin
          expected_start=1;
          expected_gain=sample_gain;
          expected_cdc_frame_id=sample_frame_id;
          have_expected_cdc_frame_id=1;
        end else if (!cfg.illegal_frame) begin
          cdc_metadata_mismatches++;
          $error("source frame %0d starts inside CDC word %0d at lane %0d",
            sample_frame_id,tr.local_index,lane);
        end
      end
      if (!cfg.illegal_frame && have_expected_cdc_frame_id &&
          sample_frame_id!=expected_cdc_frame_id) begin
        cdc_metadata_mismatches++;
        $error("epoch=%0d CDC word=%0d lane=%0d source frame=%0d expected frame=%0d",
          active_epoch,tr.local_index,lane,sample_frame_id,
          expected_cdc_frame_id);
      end
      if (sample_end) expected_end=1;
    end
    cdc_samples+=8;

    if (tr.cdc_i!==expected_i || tr.cdc_q!==expected_q) begin
      cdc_data_mismatches++;
      `uvm_error("UNIFIED_CDC_DATA",
        $sformatf("epoch=%0d cdc_word=%0d I got=%032h expected=%032h; Q got=%032h expected=%032h",
          active_epoch,tr.local_index,tr.cdc_i,expected_i,tr.cdc_q,expected_q))
    end
    if (cfg.illegal_frame) begin
      // This explicitly negative scenario violates the product's 56-sample
      // frame contract. Keep checking accepted CDC sample payloads above, but
      // leave boundary metadata to the dedicated assertion/sticky-error and
      // reset-recovery checker instead of treating the expected violation as
      // a normal-stream scoreboard failure.
      negative_frame_metadata_skips++;
    end else if (tr.cdc_frame_start!==expected_start ||
        tr.cdc_frame_end!==expected_end ||
        (expected_start && tr.cdc_frame_gain!==expected_gain) ||
        !tr.frame_id_valid ||
        (have_expected_cdc_frame_id && tr.frame_id!=expected_cdc_frame_id)) begin
      cdc_metadata_mismatches++;
      `uvm_error("UNIFIED_CDC_METADATA",
        $sformatf("epoch=%0d word=%0d frame=%0d expected_frame=%0d start=%b/%b end=%b/%b gain=%0d/%0d",
          active_epoch,tr.local_index,tr.frame_id,expected_cdc_frame_id,
          tr.cdc_frame_start,expected_start,
          tr.cdc_frame_end,expected_end,$signed(tr.cdc_frame_gain),
          $signed(expected_gain)))
    end
  endfunction

  function void frame_id_error(input string stage,
                               input int unsigned observed,
                               input int unsigned expected);
    cdc_metadata_mismatches++;
    `uvm_error("UNIFIED_FRAME_ID",
      $sformatf("%s frame_id=%0d expected=%0d in epoch=%0d",
        stage,observed,expected,active_epoch))
  endfunction

  function void check_config_event(thermo5_transaction_event tr);
    int index;
    if (tr.kind==THERMO5_EVENT_AXIL_WRITE && tr.axil_addr==8'h00 &&
        tr.axil_strb[0] && tr.axil_data[1]) begin
      if (tr.config_id!=next_expected_config_id) begin
        `uvm_error("UNIFIED_CONFIG_ID",
          $sformatf("COMMIT config_id=%0d expected=%0d",
            tr.config_id,next_expected_config_id))
      end
      expected_commit_ids.push_back(tr.config_id);
      next_expected_config_id++;
    end else if (tr.kind==THERMO5_EVENT_AXIL_RESPONSE && tr.is_write &&
                 tr.axil_resp!=2'b00 && tr.config_id!=0) begin
      for (index=0;index<expected_commit_ids.size();index++)
        if (expected_commit_ids[index]==tr.config_id) break;
      if (index==expected_commit_ids.size()) begin
        `uvm_error("UNIFIED_CONFIG_REJECT",
          $sformatf("Rejected COMMIT config_id=%0d has no unmatched request",
            tr.config_id))
      end else begin
        expected_commit_ids.delete(index);
      end
    end else if (tr.kind==THERMO5_EVENT_DSP_OBSERVATION) begin
      if (tr.cfg_pending && !previous_cfg_pending) begin
        if (expected_commit_ids.size()==0) begin
          `uvm_error("UNIFIED_CONFIG_PENDING",
            "CDC pending asserted without a preceding accepted COMMIT request")
        end else begin
          pending_config_id=expected_commit_ids.pop_front();
          config_pending_model=1;
          if (tr.pending_config_id!=pending_config_id) begin
            `uvm_error("UNIFIED_CONFIG_PENDING_ID",
              $sformatf("pending config_id=%0d expected=%0d",
                tr.pending_config_id,pending_config_id))
          end
        end
      end
      if (tr.dpd_config_boundary && tr.cfg_pending) begin
        if (!config_pending_model) begin
          `uvm_error("UNIFIED_CONFIG_APPLY",
            "DPD applied pending configuration with no modeled CDC pending event")
        end else begin
          active_config_id=pending_config_id;
          config_pending_model=0;
          config_applied_model=1;
          if (!tr.config_applied || tr.config_id!=active_config_id) begin
            `uvm_error("UNIFIED_CONFIG_APPLY_ID",
              $sformatf("applied config_id=%0d expected=%0d applied_flag=%b",
                tr.config_id,active_config_id,tr.config_applied))
          end
        end
      end
      if (tr.cfg_ack_core && !previous_cfg_ack_core) begin
        if (!config_applied_model || tr.config_id!=active_config_id) begin
          `uvm_error("UNIFIED_CONFIG_ACK",
            $sformatf("core ACK config_id=%0d before matching frame apply id=%0d",
              tr.config_id,active_config_id))
        end else begin
          config_ack_model=1;
        end
      end
      if (tr.cfg_done && !previous_cfg_done) begin
        if (!config_ack_model || tr.config_id!=active_config_id) begin
          `uvm_error("UNIFIED_CONFIG_DONE",
            $sformatf("STATUS DONE config_id=%0d before matching core ACK id=%0d",
              tr.config_id,active_config_id))
        end else begin
          config_ack_model=0;
          config_applied_model=0;
        end
      end
      previous_cfg_pending=tr.cfg_pending;
      previous_cfg_ack_core=tr.cfg_ack_core;
      previous_cfg_done=tr.cfg_done;
    end
  endfunction

  function void check_dsp(thermo5_transaction_event tr);
    dsp_snapshots++;
    for (int lane=0;lane<16;lane++) begin
      if (have_dpd_snapshot &&
          (tr.dpd_samples[lane]<previous_dpd_samples[lane] ||
           tr.dpd_saturations[lane]<previous_dpd_saturations[lane])) begin
        `uvm_error("UNIFIED_DPD_COUNTER",
          $sformatf("epoch=%0d lane=%0d sample/saturation counter decreased",
            active_epoch,lane))
      end
      previous_dpd_samples[lane]=tr.dpd_samples[lane];
      previous_dpd_saturations[lane]=tr.dpd_saturations[lane];
    end
    if (tr.dpd_active_taps<1 || tr.dpd_active_taps>4)
      `uvm_error("UNIFIED_DPD_TAPS",
        $sformatf("observed active DPD taps outside RTL legal range: %0d",
          tr.dpd_active_taps))
    have_dpd_snapshot=1;
  endfunction

  function void index_error(input string stage,
                            input int unsigned observed,
                            input int unsigned expected);
    index_mismatches++;
    `uvm_error("UNIFIED_STAGE_INDEX",
      $sformatf("%s local index=%0d expected=%0d in epoch=%0d",
        stage,observed,expected,active_epoch))
  endfunction

  function bit check_expected_queues_drained(input string checkpoint);
    bit clean;
    clean=(expected_i_samples.size()==0 && expected_q_samples.size()==0 &&
           expected_start_samples.size()==0 && expected_end_samples.size()==0 &&
           expected_gain_samples.size()==0 && expected_frame_ids.size()==0 &&
           expected_commit_ids.size()==0 && !config_pending_model &&
           !config_applied_model && !config_ack_model);
    if (!clean)
      `uvm_error("UNIFIED_DRAIN",
        $sformatf("%s expected source queues=%0d/%0d/%0d/%0d/%0d/%0d commits=%0d pending=%b applied=%b ack=%b",
          checkpoint,expected_i_samples.size(),expected_q_samples.size(),
          expected_start_samples.size(),expected_end_samples.size(),
          expected_gain_samples.size(),expected_frame_ids.size(),
          expected_commit_ids.size(),config_pending_model,
          config_applied_model,config_ack_model))
    return clean;
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("THERMO5_UNIFIED_SCOREBOARD",
      $sformatf("epoch=%0d source_beats=%0d source_samples=%0d cdc_words=%0d cdc_samples=%0d queued_samples=%0d discarded_on_reset=%0d pa_words=%0d axil_wr=%0d axil_rd=%0d dsp_snapshots=%0d ef2_words=%0d ef2_stalls=%0d ef2_reference_loaded=%b ef2_data_mismatches=%0d resets=%0d cdc_data_mismatch=%0d cdc_metadata_mismatch=%0d negative_frame_metadata_skips=%0d event_id_gaps=%0d epoch_mismatch=%0d index_mismatch=%0d",
        active_epoch,source_beats,source_samples,cdc_words,cdc_samples,
        expected_i_samples.size(),reset_discarded_samples,pa_words,
        axil_writes,axil_reads,dsp_snapshots,ef2_words,ef2_stalls,
        ef2_reference_loaded,ef2_data_mismatches,reset_events,
        cdc_data_mismatches,cdc_metadata_mismatches,
        negative_frame_metadata_skips,event_id_gaps,
        epoch_mismatches,index_mismatches),UVM_NONE)
  endfunction
endclass
