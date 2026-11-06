class thermo5_cdc_core_monitor extends uvm_monitor;
  `uvm_component_utils(thermo5_cdc_core_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port #(thermo5_transaction_event) ap;
  int unsigned epoch, cycle_count, accepted_words;
  bit reset_active;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap=new("ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("CDC_MON_VIF","CDC observer needs the Thermo5 interface")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_transaction_event tr;
    forever begin
      @(posedge vif.core_clk);
      if (!vif.core_rst_n) begin
        if (!reset_active) begin
          tr=thermo5_transaction_event::type_id::create("cdc_reset");
          tr.kind=THERMO5_EVENT_RESET;
          tr.epoch=epoch+1;
          tr.event_cycle=cycle_count;
          tr.time_ns=$realtime;
          ap.write(tr);
          epoch++;
        end
        reset_active=1;
        cycle_count=0;
        accepted_words=0;
      end else begin
        reset_active=0;
        cycle_count++;
        if (vif.cdc_core_valid && vif.cdc_core_ready) begin
          tr=thermo5_transaction_event::type_id::create("cdc_core_word");
          tr.kind=THERMO5_EVENT_CDC_WORD;
          tr.epoch=epoch;
          tr.event_cycle=cycle_count;
          tr.local_index=accepted_words++;
          tr.time_ns=$realtime;
          tr.cdc_i=vif.cdc_core_i_vec;
          tr.cdc_q=vif.cdc_core_q_vec;
          tr.cdc_frame_gain=vif.cdc_core_frame_gain;
          tr.cdc_frame_start=vif.cdc_frame_start;
          tr.cdc_frame_end=vif.cdc_frame_end;
          tr.cdc_residual=vif.cdc_residual;
          tr.cdc_end_pending=vif.cdc_end_pending;
          tr.cdc_end_false_arm=vif.cdc_end_false_arm;
          ap.write(tr);
        end
      end
    end
  endtask
endclass
