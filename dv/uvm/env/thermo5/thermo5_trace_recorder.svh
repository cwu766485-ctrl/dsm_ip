// Optional JSONL sink for real monitor transactions. Enabled with
// +THERMO5_TRACE_JSONL=<path>; never drives a DUT signal.
class thermo5_trace_recorder extends uvm_component;
  `uvm_component_utils(thermo5_trace_recorder)
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

  task run_phase(uvm_phase phase);
    bit previous_pending;
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
