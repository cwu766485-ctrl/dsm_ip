// Optional JSONL sink for real monitor transactions. Enabled with
// +THERMO5_TRACE_JSONL=<path>; never drives a DUT signal.
class thermo5_trace_recorder extends uvm_component;
  `uvm_component_utils(thermo5_trace_recorder)
  uvm_analysis_imp_event#(thermo5_transaction_event,thermo5_trace_recorder) event_imp;
  uvm_analysis_imp_trace_src#(thermo5_source_item,thermo5_trace_recorder) source_imp;
  uvm_analysis_imp_trace_pa#(thermo5_pa_word,thermo5_trace_recorder) pa_imp;
  uvm_analysis_imp_trace_axil_fire#(thermo5_axil_item,thermo5_trace_recorder) axil_fire_imp;
  uvm_analysis_imp_trace_axil_addr#(thermo5_axil_item,thermo5_trace_recorder) axil_addr_imp;
  uvm_analysis_imp_trace_axil_done#(thermo5_axil_item,thermo5_trace_recorder) axil_done_imp;
  uvm_analysis_imp_trace_axil_cycle#(thermo5_axil_item,thermo5_trace_recorder) axil_cycle_imp;
  virtual thermo5_sku_if sku_vif;
  virtual thermo5_axil_if axil_vif;
  integer fd;
  string path;
  int unsigned sequence_id, epoch, next_commit_id, pending_commit_id, frame_id;
  int unsigned pa_word_index;
  int unsigned current_axil_cycle;
  int unsigned source_packet_id, source_packet_beat, source_frame_id;
  bit enabled, reset_active, released_once, pending_seen, underflow_seen;
  bit source_frame_seen;
  bit previous_ack_core, previous_cfg_busy, previous_cfg_done;
  bit last_run_request, last_tx_active;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    event_imp=new("event_imp",this);
    source_imp=new("source_imp",this);
    pa_imp=new("pa_imp",this);
    axil_fire_imp=new("axil_fire_imp",this);
    axil_addr_imp=new("axil_addr_imp",this);
    axil_done_imp=new("axil_done_imp",this);
    axil_cycle_imp=new("axil_cycle_imp",this);
    fd=0;
    sequence_id=0;
    epoch=0;
    frame_id=0;
    pa_word_index=0;
    current_axil_cycle=0;
    source_packet_id=0;
    source_packet_beat=0;
    source_frame_id=0;
    source_frame_seen=0;
    previous_ack_core=0;
    previous_cfg_busy=0;
    previous_cfg_done=0;
    reset_active=1;
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!$value$plusargs("THERMO5_TRACE_JSONL=%s",path)) begin
      enabled=0;
      return;
    end
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","sku_vif",sku_vif))
      `uvm_fatal("TRACE_VIF","Trace recorder needs the thermo5 SKU interface")
    if (!uvm_config_db#(virtual thermo5_axil_if)::get(this,"","axil_vif",axil_vif))
      `uvm_fatal("TRACE_VIF","Trace recorder needs the AXI-Lite interface")
    fd=$fopen(path,"w");
    if (fd==0) `uvm_fatal("TRACE_OPEN",$sformatf("Could not open %s",path))
    enabled=1;
    `uvm_info("THERMO5_TRACE",$sformatf("Writing accepted monitor events to %s",path),UVM_LOW)
  endfunction

  function void write_trace_src(thermo5_source_item tr);
    string i_json, q_json;
    int signed i_value, q_value;
    if (!enabled) return;
    if (tr.frame_start) begin
      if (source_frame_seen) source_frame_id++;
      source_frame_seen=1;
    end
    i_json="["; q_json="[";
    for (int lane=0; lane<14; lane++) begin
      i_value=$signed(tr.i_vec[lane*16+:16]);
      q_value=$signed(tr.q_vec[lane*16+:16]);
      i_json={i_json,$sformatf("%s%0d",lane==0 ? "" : ",",i_value)};
      q_json={q_json,$sformatf("%s%0d",lane==0 ? "" : ",",q_value)};
    end
    i_json={i_json,"]"}; q_json={q_json,"]"};
    $fdisplay(fd,
      "{\"seq\":%0d,\"type\":\"source_beat\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"beat_index\":%0d,\"packet_id\":%0d,\"packet_beat_index\":%0d,\"source_frame_id\":%0d,\"source_gap_cycles\":%0d,\"i\":%s,\"q\":%s,\"frame_start\":%s,\"frame_gain\":%0d,\"tlast\":%s}",
      sequence_id++,epoch,current_axil_cycle,$realtime,tr.beat_index,source_packet_id,
      source_packet_beat,source_frame_id,tr.valid_gap_cycles,i_json,q_json,
      tr.frame_start ? "true" : "false",$signed(tr.frame_gain),
      tr.tlast ? "true" : "false");
    source_packet_beat++;
    if (tr.tlast) begin
      source_packet_id++;
      source_packet_beat=0;
    end
  endfunction

  function void write_trace_pa(thermo5_pa_word tr);
    if (!enabled) return;
    $fdisplay(fd,
      "{\"seq\":%0d,\"type\":\"pa_word\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"word_index\":%0d,\"planes\":[\"0x%016h\",\"0x%016h\",\"0x%016h\",\"0x%016h\"]}",
      sequence_id++,epoch,current_axil_cycle,$realtime,pa_word_index++,
      tr.plane[0],tr.plane[1],tr.plane[2],tr.plane[3]);
  endfunction

  function void write_trace_axil_fire(thermo5_axil_item tr);
    if (!enabled) return;
    if (tr.addr==8'h00 && tr.strb[0] && tr.data[1]) begin
      next_commit_id++;
      pending_commit_id=next_commit_id;
    end
    $fdisplay(fd,
      "{\"seq\":%0d,\"type\":\"axil_write_fire\",\"epoch\":%0d,\"event_cycle\":%0d,\"time_ns\":%0.3f,\"txn_id\":%0d,\"addr\":\"0x%02h\",\"data\":\"0x%08h\",\"strb\":\"0x%01h\"}",
      sequence_id++,epoch,tr.event_cycle,$realtime,tr.txn_id,tr.addr,tr.data,tr.strb);
  endfunction

  function void write_trace_axil_addr(thermo5_axil_item tr);
    if (!enabled) return;
    $fdisplay(fd,
      "{\"seq\":%0d,\"type\":\"axil_read\",\"epoch\":%0d,\"event_cycle\":%0d,\"time_ns\":%0.3f,\"txn_id\":%0d,\"addr\":\"0x%02h\"}",
      sequence_id++,epoch,tr.event_cycle,$realtime,tr.txn_id,tr.addr);
  endfunction

  function void write_trace_axil_done(thermo5_axil_item tr);
    if (!enabled) return;
    if (tr.is_write)
      $fdisplay(fd,
        "{\"seq\":%0d,\"type\":\"axil_write_response\",\"epoch\":%0d,\"event_cycle\":%0d,\"time_ns\":%0.3f,\"txn_id\":%0d,\"addr\":\"0x%02h\",\"resp\":%0d}",
        sequence_id++,epoch,tr.event_cycle,$realtime,tr.txn_id,tr.addr,tr.resp);
    else
      $fdisplay(fd,
        "{\"seq\":%0d,\"type\":\"axil_read_response\",\"epoch\":%0d,\"event_cycle\":%0d,\"time_ns\":%0.3f,\"txn_id\":%0d,\"addr\":\"0x%02h\",\"rdata\":\"0x%08h\",\"resp\":%0d}",
        sequence_id++,epoch,tr.event_cycle,$realtime,tr.txn_id,tr.addr,tr.rdata,tr.resp);
  endfunction

  function void write_trace_axil_cycle(thermo5_axil_item tr);
    if (!enabled || !tr.reset_n) return;
    current_axil_cycle=tr.event_cycle;
  endfunction

  function void write_event(thermo5_transaction_event event_tr);
    string i_json, q_json, samples_json, saturations_json, event_type;
    int signed value;
    thermo5_source_item source_tr;
    thermo5_pa_word pa_tr;
    thermo5_axil_item axil_tr;
    if (!enabled) return;
    case (event_tr.kind)
      THERMO5_EVENT_SOURCE_BEAT: begin
        source_tr=thermo5_source_item::type_id::create("trace_source_event");
        source_tr.i_vec=event_tr.source_i;
        source_tr.q_vec=event_tr.source_q;
        source_tr.frame_start=event_tr.frame_start;
        source_tr.frame_gain=event_tr.frame_gain;
        source_tr.tlast=event_tr.tlast;
        source_tr.beat_index=event_tr.local_index;
        source_tr.valid_gap_cycles=event_tr.valid_gap_cycles;
        write_trace_src(source_tr);
      end
      THERMO5_EVENT_PA_WORD: begin
        pa_tr=thermo5_pa_word::type_id::create("trace_pa_event");
        for (int p=0;p<4;p++) pa_tr.plane[p]=event_tr.pa_plane[p];
        write_trace_pa(pa_tr);
      end
      THERMO5_EVENT_AXIL_WRITE: begin
        axil_tr=thermo5_axil_item::type_id::create("trace_axil_write_event");
        axil_tr.is_write=1;
        axil_tr.addr=event_tr.axil_addr;
        axil_tr.data=event_tr.axil_data;
        axil_tr.strb=event_tr.axil_strb;
        axil_tr.txn_id=event_tr.axil_txn_id;
        axil_tr.event_cycle=event_tr.event_cycle;
        write_trace_axil_fire(axil_tr);
      end
      THERMO5_EVENT_AXIL_READ: begin
        axil_tr=thermo5_axil_item::type_id::create("trace_axil_read_event");
        axil_tr.addr=event_tr.axil_addr;
        axil_tr.txn_id=event_tr.axil_txn_id;
        axil_tr.event_cycle=event_tr.event_cycle;
        write_trace_axil_addr(axil_tr);
      end
      THERMO5_EVENT_AXIL_RESPONSE: begin
        axil_tr=thermo5_axil_item::type_id::create("trace_axil_response_event");
        axil_tr.is_write=event_tr.is_write;
        axil_tr.addr=event_tr.axil_addr;
        axil_tr.data=event_tr.axil_data;
        axil_tr.rdata=event_tr.axil_rdata;
        axil_tr.strb=event_tr.axil_strb;
        axil_tr.resp=event_tr.axil_resp;
        axil_tr.txn_id=event_tr.axil_txn_id;
        axil_tr.event_cycle=event_tr.event_cycle;
        write_trace_axil_done(axil_tr);
      end
      THERMO5_EVENT_CDC_WORD: begin
        i_json="["; q_json="[";
        for (int lane=0;lane<8;lane++) begin
          value=$signed(event_tr.cdc_i[lane*16+:16]);
          i_json={i_json,$sformatf("%s%0d",lane==0 ? "" : ",",value)};
          value=$signed(event_tr.cdc_q[lane*16+:16]);
          q_json={q_json,$sformatf("%s%0d",lane==0 ? "" : ",",value)};
        end
        i_json={i_json,"]"}; q_json={q_json,"]"};
        $fdisplay(fd,
          "{\"seq\":%0d,\"type\":\"cdc_core_word\",\"epoch\":%0d,\"monitor_epoch\":%0d,\"time_ns\":%0.3f,\"word_index\":%0d,\"i\":%s,\"q\":%s,\"frame_start\":%s,\"frame_end\":%s,\"frame_gain\":%0d,\"residual\":%0d,\"end_pending\":%s,\"end_false_arm\":%s}",
          sequence_id++,epoch,event_tr.epoch,event_tr.time_ns,event_tr.local_index,i_json,q_json,
          event_tr.cdc_frame_start ? "true" : "false",
          event_tr.cdc_frame_end ? "true" : "false",$signed(event_tr.cdc_frame_gain),
          event_tr.cdc_residual,event_tr.cdc_end_pending ? "true" : "false",
          event_tr.cdc_end_false_arm ? "true" : "false");
      end
      THERMO5_EVENT_DSP_OBSERVATION: begin
        samples_json="["; saturations_json="[";
        for (int lane=0;lane<16;lane++) begin
          samples_json={samples_json,$sformatf("%s%0d",lane==0 ? "" : ",",event_tr.dpd_samples[lane])};
          saturations_json={saturations_json,$sformatf("%s%0d",lane==0 ? "" : ",",event_tr.dpd_saturations[lane])};
        end
        samples_json={samples_json,"]"}; saturations_json={saturations_json,"]"};
        $fdisplay(fd,
          "{\"seq\":%0d,\"type\":\"dsp_observation\",\"epoch\":%0d,\"monitor_epoch\":%0d,\"time_ns\":%0.3f,\"core_cycle\":%0d,\"probe_state\":\"0x%04h\",\"dpd_active_taps\":%0d,\"cfg_pending\":%s,\"dpd_samples\":%s,\"dpd_saturations\":%s}",
          sequence_id++,epoch,event_tr.epoch,event_tr.time_ns,event_tr.event_cycle,
          event_tr.dsp_probe_state,event_tr.dpd_active_taps,
          event_tr.cfg_pending ? "true" : "false",samples_json,saturations_json);
      end
      THERMO5_EVENT_EF2_WORD, THERMO5_EVENT_EF2_STALL: begin
        if (event_tr.kind==THERMO5_EVENT_EF2_WORD)
          event_type="ef2_input_word";
        else
          event_type="ef2_input_stall";
        i_json="["; q_json="[";
        for (int lane=0;lane<32;lane++) begin
          value=$signed(event_tr.ef2_i[lane*16+:16]);
          i_json={i_json,$sformatf("%s%0d",lane==0 ? "" : ",",value)};
          value=$signed(event_tr.ef2_q[lane*16+:16]);
          q_json={q_json,$sformatf("%s%0d",lane==0 ? "" : ",",value)};
        end
        i_json={i_json,"]"}; q_json={q_json,"]"};
        $fdisplay(fd,
          "{\"seq\":%0d,\"type\":\"%s\",\"epoch\":%0d,\"monitor_epoch\":%0d,\"time_ns\":%0.3f,\"core_cycle\":%0d,\"word_index\":%0d,\"i\":%s,\"q\":%s,\"pos_clamp\":\"0x%01h\",\"neg_clamp\":\"0x%01h\",\"state_rail\":\"0x%01h\"}",
          sequence_id++,event_type,
          epoch,event_tr.epoch,event_tr.time_ns,event_tr.event_cycle,event_tr.local_index,
          i_json,q_json,event_tr.ef2_pos_clamp_mask,event_tr.ef2_neg_clamp_mask,
          event_tr.ef2_state_rail_mask);
      end
      THERMO5_EVENT_RESET: begin
        $fdisplay(fd,
          "{\"seq\":%0d,\"type\":\"observer_reset_epoch\",\"epoch\":%0d,\"monitor_epoch\":%0d,\"core_cycle\":%0d,\"time_ns\":%0.3f}",
          sequence_id++,epoch,event_tr.epoch,event_tr.event_cycle,event_tr.time_ns);
      end
      default: `uvm_error("TRACE_EVENT_KIND","Unknown Thermo5 transaction event")
    endcase
  endfunction

  task run_phase(uvm_phase phase);
    bit previous_pending;
    bit previous_fifo_full;
    fork
      begin : core_event_capture
        forever begin
          @(posedge sku_vif.core_clk);
          if (!sku_vif.core_rst_n) begin
            if (!reset_active && released_once) begin
              epoch++;
              frame_id=0;
              pa_word_index=0;
              source_packet_id=0;
              source_packet_beat=0;
              source_frame_id=0;
              source_frame_seen=0;
              previous_ack_core=0;
              previous_cfg_busy=0;
              previous_cfg_done=0;
              pending_seen=0;
              underflow_seen=0;
              if (enabled)
                $fdisplay(fd,
                  "{\"seq\":%0d,\"type\":\"reset\",\"epoch\":%0d,\"next_epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f}",
                  sequence_id++,epoch-1,epoch,current_axil_cycle,$realtime);
            end
            reset_active=1;
            previous_pending=0;
          end else begin
            reset_active=0;
            released_once=1;
            if (sku_vif.cfg_pending_valid && !previous_pending && enabled) begin
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"config_pending\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"commit_id\":%0d}",
                sequence_id++,epoch,current_axil_cycle,$realtime,pending_commit_id);
              pending_seen=1;
            end
            previous_pending=sku_vif.cfg_pending_valid;
            if (sku_vif.cfg_ack_core && !previous_ack_core && enabled)
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"config_ack_core\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f}",
                sequence_id++,epoch,current_axil_cycle,$realtime);
            previous_ack_core=sku_vif.cfg_ack_core;
            if (sku_vif.dpd_config_boundary && enabled) begin
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"frame_boundary\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"frame_id\":%0d,\"config_pending\":%s}",
                sequence_id++,epoch,current_axil_cycle,$realtime,frame_id,
                sku_vif.cfg_pending_valid ? "true" : "false");
              frame_id++;
              pending_seen=0;
            end
            if (sku_vif.underflow && !underflow_seen && enabled) begin
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"underflow\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f}",
                sequence_id++,epoch,current_axil_cycle,$realtime);
              underflow_seen=1;
            end
            if (sku_vif.pa_valid==4'hf && sku_vif.pa_ready!=4'hf && enabled)
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"pa_stall\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"ready\":\"0x%01h\"}",
                sequence_id++,epoch,current_axil_cycle,$realtime,sku_vif.pa_ready);
            if ((sku_vif.core_run_request!=last_run_request ||
                 sku_vif.core_tx_active!=last_tx_active) && enabled)
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"stop_state\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"run\":%s,\"active\":%s,\"draining\":%s}",
                sequence_id++,epoch,current_axil_cycle,$realtime,
                sku_vif.core_run_request ? "true" : "false",
                sku_vif.core_tx_active ? "true" : "false",
                (sku_vif.core_tx_active && !sku_vif.core_run_request) ? "true" : "false");
            last_run_request=sku_vif.core_run_request;
            last_tx_active=sku_vif.core_tx_active;
          end
        end
      end
      begin : fifo_full_event_capture
        previous_fifo_full=0;
        forever begin
          @(posedge sku_vif.src_clk);
          if (!sku_vif.src_rst_n) begin
            previous_fifo_full=0;
          end else begin
            if (enabled && sku_vif.fifo_full!=previous_fifo_full)
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"fifo_full\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f,\"full\":%s}",
                sequence_id++,epoch,current_axil_cycle,$realtime,
                sku_vif.fifo_full ? "true" : "false");
            previous_fifo_full=sku_vif.fifo_full;
          end
        end
      end
      begin : axil_config_completion_capture
        forever begin
          @(posedge axil_vif.aclk);
          if (!axil_vif.aresetn) begin
            previous_cfg_busy=0;
            previous_cfg_done=0;
          end else begin
            if (previous_cfg_busy && !sku_vif.cfg_busy && sku_vif.cfg_done && enabled)
              $fdisplay(fd,
                "{\"seq\":%0d,\"type\":\"commit_done\",\"epoch\":%0d,\"axil_cycle\":%0d,\"time_ns\":%0.3f}",
                sequence_id++,epoch,current_axil_cycle,$realtime);
            previous_cfg_busy=sku_vif.cfg_busy;
            previous_cfg_done=sku_vif.cfg_done;
          end
        end
      end
    join
  endtask

  function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    if (fd!=0) begin
      $fflush(fd);
      $fclose(fd);
      fd=0;
    end
  endfunction
endclass
