// Fan-in for accepted interface transactions and passive internal observations.
// The bus preserves the observed payload and never derives expected DUT data.
class thermo5_transaction_event_bus extends uvm_component;
  `uvm_component_utils(thermo5_transaction_event_bus)

  uvm_analysis_imp_src#(thermo5_source_item,thermo5_transaction_event_bus) source_imp;
  uvm_analysis_imp_pa#(thermo5_pa_word,thermo5_transaction_event_bus) pa_imp;
  uvm_analysis_imp_axil_fire#(thermo5_axil_item,thermo5_transaction_event_bus) axil_fire_imp;
  uvm_analysis_imp_axil_addr#(thermo5_axil_item,thermo5_transaction_event_bus) axil_addr_imp;
  uvm_analysis_imp_axil_done#(thermo5_axil_item,thermo5_transaction_event_bus) axil_done_imp;
  uvm_analysis_imp_cdc_evt#(thermo5_transaction_event,thermo5_transaction_event_bus) cdc_imp;
  uvm_analysis_imp_dsp_evt#(thermo5_transaction_event,thermo5_transaction_event_bus) dsp_imp;
  uvm_analysis_imp_ef2_evt#(thermo5_transaction_event,thermo5_transaction_event_bus) ef2_imp;
  uvm_analysis_port#(thermo5_transaction_event) event_ap;

  longint unsigned next_event_id;
  int unsigned next_source_frame_id, next_cdc_frame_id;
  int unsigned active_config_id, next_config_id;
  bit have_source_frame_id, have_cdc_frame_id;
  bit previous_cfg_pending, previous_cfg_ack_core, previous_cfg_done;
  thermo5_config_lifecycle_t config_lifecycle[$];
  int unsigned source_beats, pa_words, axil_writes, axil_reads, axil_responses;
  int unsigned cdc_words, dsp_observations, ef2_words, ef2_stalls, reset_events;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_imp=new("source_imp",this);
    pa_imp=new("pa_imp",this);
    axil_fire_imp=new("axil_fire_imp",this);
    axil_addr_imp=new("axil_addr_imp",this);
    axil_done_imp=new("axil_done_imp",this);
    cdc_imp=new("cdc_imp",this);
    dsp_imp=new("dsp_imp",this);
    ef2_imp=new("ef2_imp",this);
    event_ap=new("event_ap",this);
    next_config_id=1;
  endfunction

  function int find_config_state(thermo5_config_state_e state);
    for (int index=0;index<config_lifecycle.size();index++)
      if (config_lifecycle[index].state==state) return index;
    return -1;
  endfunction

  function int find_config_txn(int unsigned txn_id);
    for (int index=0;index<config_lifecycle.size();index++)
      if (config_lifecycle[index].txn_id==txn_id) return index;
    return -1;
  endfunction

  function void observe_config_lifecycle(thermo5_transaction_event tr);
    int index;
    if (tr.kind==THERMO5_EVENT_RESET) begin
      config_lifecycle.delete();
      active_config_id=0;
      next_config_id=1;
      previous_cfg_pending=0;
      previous_cfg_ack_core=0;
      previous_cfg_done=0;
      return;
    end

    if (tr.kind==THERMO5_EVENT_AXIL_WRITE && tr.axil_addr==8'h00 &&
        tr.axil_strb[0] && tr.axil_data[1]) begin
      thermo5_config_lifecycle_t record;
      record.txn_id=tr.axil_txn_id;
      record.config_id=next_config_id++;
      record.state=THERMO5_CFG_CANDIDATE;
      config_lifecycle.push_back(record);
      tr.config_id=record.config_id;
    end else if (tr.kind==THERMO5_EVENT_AXIL_RESPONSE && tr.is_write) begin
      index=find_config_txn(tr.axil_txn_id);
      if (index>=0 && tr.axil_resp!=2'b00) begin
        if (config_lifecycle[index].state!=THERMO5_CFG_CANDIDATE)
          $error("COMMIT txn=%0d was rejected after CDC accepted it",tr.axil_txn_id);
        config_lifecycle[index].state=THERMO5_CFG_REJECTED;
        tr.config_id=config_lifecycle[index].config_id;
      end else if (index>=0) begin
        tr.config_id=config_lifecycle[index].config_id;
      end
    end else if (tr.kind==THERMO5_EVENT_DSP_OBSERVATION) begin
      if (tr.cfg_pending && !previous_cfg_pending) begin
        index=find_config_state(THERMO5_CFG_CANDIDATE);
        if (index<0) begin
          $error("CDC pending became active without an accepted COMMIT transaction");
        end else begin
          config_lifecycle[index].state=THERMO5_CFG_PENDING;
          tr.pending_config_id=config_lifecycle[index].config_id;
        end
      end else if (tr.cfg_pending) begin
        index=find_config_state(THERMO5_CFG_PENDING);
        if (index>=0) tr.pending_config_id=config_lifecycle[index].config_id;
      end

      if (tr.dpd_config_boundary && tr.cfg_pending) begin
        index=find_config_state(THERMO5_CFG_PENDING);
        if (index<0) begin
          $error("DPD frame boundary applied a pending payload with no tracked COMMIT");
        end else begin
          config_lifecycle[index].state=THERMO5_CFG_APPLIED;
          active_config_id=config_lifecycle[index].config_id;
          tr.config_id=active_config_id;
          tr.pending_config_id=active_config_id;
          tr.config_applied=1;
        end
      end else begin
        tr.config_id=active_config_id;
      end

      if (tr.cfg_ack_core && !previous_cfg_ack_core) begin
        index=find_config_state(THERMO5_CFG_APPLIED);
        if (index<0) begin
          $error("Core configuration ACK occurred before a tracked frame-boundary apply");
        end else begin
          config_lifecycle[index].state=THERMO5_CFG_ACKED;
          tr.config_id=config_lifecycle[index].config_id;
        end
      end
      if (tr.cfg_done && !previous_cfg_done) begin
        index=find_config_state(THERMO5_CFG_ACKED);
        if (index<0) begin
          $error("AXI-Lite configuration DONE occurred before core ACK");
        end else begin
          config_lifecycle[index].state=THERMO5_CFG_DONE;
          tr.config_id=config_lifecycle[index].config_id;
        end
      end
      previous_cfg_pending=tr.cfg_pending;
      previous_cfg_ack_core=tr.cfg_ack_core;
      previous_cfg_done=tr.cfg_done;
    end
  endfunction

  function void publish(thermo5_transaction_event tr);
    observe_config_lifecycle(tr);
    case (tr.kind)
      THERMO5_EVENT_SOURCE_BEAT: begin
        if (tr.frame_start) begin
          if (have_source_frame_id) next_source_frame_id++;
          else have_source_frame_id=1;
        end
        tr.frame_id=next_source_frame_id;
        tr.frame_id_valid=1;
        tr.config_id=active_config_id;
      end
      THERMO5_EVENT_CDC_WORD: begin
        if (tr.cdc_frame_start) begin
          if (have_cdc_frame_id) next_cdc_frame_id++;
          else have_cdc_frame_id=1;
        end
        tr.frame_id=next_cdc_frame_id;
        tr.frame_id_valid=1;
        tr.config_id=active_config_id;
      end
      THERMO5_EVENT_RESET: begin
        next_source_frame_id=0;
        next_cdc_frame_id=0;
        have_source_frame_id=0;
        have_cdc_frame_id=0;
        tr.frame_id=0;
        tr.frame_id_valid=1;
        tr.config_id=0;
      end
      default: begin
        if (tr.config_id==0) tr.config_id=active_config_id;
      end
    endcase
    tr.event_id=next_event_id++;
    tr.time_ns=$realtime;
    case (tr.kind)
      THERMO5_EVENT_SOURCE_BEAT: source_beats++;
      THERMO5_EVENT_PA_WORD: pa_words++;
      THERMO5_EVENT_AXIL_WRITE: axil_writes++;
      THERMO5_EVENT_AXIL_READ: axil_reads++;
      THERMO5_EVENT_AXIL_RESPONSE: axil_responses++;
      THERMO5_EVENT_CDC_WORD: cdc_words++;
      THERMO5_EVENT_DSP_OBSERVATION: dsp_observations++;
      THERMO5_EVENT_EF2_WORD: ef2_words++;
      THERMO5_EVENT_EF2_STALL: ef2_stalls++;
      THERMO5_EVENT_RESET: reset_events++;
      default: `uvm_error("EVENT_KIND","Unknown Thermo5 event kind")
    endcase
    event_ap.write(tr);
  endfunction

  function void write_src(thermo5_source_item source);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("source_event");
    tr.kind=THERMO5_EVENT_SOURCE_BEAT;
    tr.epoch=source.epoch;
    tr.event_cycle=source.beat_index;
    tr.local_index=source.beat_index;
    tr.packet_id=source.packet_id;
    tr.packet_id_valid=1'b1;
    tr.source_i=source.i_vec;
    tr.source_q=source.q_vec;
    tr.frame_start=source.frame_start;
    tr.frame_gain=source.frame_gain;
    tr.tlast=source.tlast;
    tr.valid_gap_cycles=source.valid_gap_cycles;
    publish(tr);
  endfunction

  function void write_pa(thermo5_pa_word pa);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("pa_event");
    tr.kind=THERMO5_EVENT_PA_WORD;
    tr.epoch=pa.epoch;
    tr.event_cycle=pa.word_index;
    tr.local_index=pa.word_index;
    for (int plane=0;plane<4;plane++) tr.pa_plane[plane]=pa.plane[plane];
    publish(tr);
  endfunction

  function void write_axil_fire(thermo5_axil_item axil);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("axil_write_event");
    tr.kind=THERMO5_EVENT_AXIL_WRITE;
    tr.epoch=axil.reset_epoch;
    tr.event_cycle=axil.event_cycle;
    tr.local_index=axil.txn_id;
    tr.axil_txn_id=axil.txn_id;
    tr.is_write=1;
    tr.axil_addr=axil.addr;
    tr.axil_data=axil.data;
    tr.axil_strb=axil.strb;
    publish(tr);
  endfunction

  function void write_axil_addr(thermo5_axil_item axil);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("axil_read_event");
    tr.kind=THERMO5_EVENT_AXIL_READ;
    tr.epoch=axil.reset_epoch;
    tr.event_cycle=axil.event_cycle;
    tr.local_index=axil.txn_id;
    tr.axil_txn_id=axil.txn_id;
    tr.is_write=0;
    tr.axil_addr=axil.addr;
    publish(tr);
  endfunction

  function void write_axil_done(thermo5_axil_item axil);
    thermo5_transaction_event tr;
    tr=thermo5_transaction_event::type_id::create("axil_response_event");
    tr.kind=THERMO5_EVENT_AXIL_RESPONSE;
    tr.epoch=axil.reset_epoch;
    tr.event_cycle=axil.event_cycle;
    tr.local_index=axil.txn_id;
    tr.axil_txn_id=axil.txn_id;
    tr.is_write=axil.is_write;
    tr.axil_addr=axil.addr;
    tr.axil_data=axil.data;
    tr.axil_rdata=axil.rdata;
    tr.axil_strb=axil.strb;
    tr.axil_resp=axil.resp;
    publish(tr);
  endfunction

  function void write_cdc_evt(thermo5_transaction_event tr);
    publish(tr);
  endfunction

  function void write_dsp_evt(thermo5_transaction_event tr);
    publish(tr);
  endfunction

  function void write_ef2_evt(thermo5_transaction_event tr);
    publish(tr);
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("THERMO5_EVENT_BUS",
      $sformatf("source=%0d cdc=%0d dsp=%0d ef2=%0d ef2_stall=%0d pa=%0d axil_write=%0d axil_read=%0d axil_response=%0d reset=%0d",
        source_beats,cdc_words,dsp_observations,ef2_words,ef2_stalls,pa_words,
        axil_writes,axil_reads,axil_responses,reset_events),UVM_NONE)
  endfunction
endclass
