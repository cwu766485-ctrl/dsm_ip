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
  endfunction

  function void publish(thermo5_transaction_event tr);
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
