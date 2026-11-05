class thermo5_ef2_input_monitor extends uvm_monitor;
  `uvm_component_utils(thermo5_ef2_input_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port #(thermo5_transaction_event) ap;
  int unsigned epoch, cycle_count, accepted_words;
  bit reset_active, stalled;
  logic [511:0] held_i, held_q;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap=new("ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("EF2_MON_VIF","EF2 observer needs the Thermo5 interface")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_transaction_event tr;
    forever begin
      @(posedge vif.core_clk);
      if (!vif.core_rst_n) begin
        if (!reset_active) epoch++;
        reset_active=1;
        cycle_count=0;
        accepted_words=0;
        stalled=0;
      end else begin
        reset_active=0;
        cycle_count++;
        if (stalled && (vif.ef2_input_valid!==1'b1 ||
            vif.ef2_input_i_vec!==held_i || vif.ef2_input_q_vec!==held_q))
          `uvm_error("EF2_INPUT_HOLD",
            "32-lane EF2 input changed or lost VALID while downstream was stalled")
        if (vif.ef2_input_valid && vif.ef2_input_ready) begin
          tr=thermo5_transaction_event::type_id::create("ef2_input_word");
          tr.kind=THERMO5_EVENT_EF2_WORD;
          tr.epoch=epoch;
          tr.event_cycle=cycle_count;
          tr.local_index=accepted_words++;
          tr.time_ns=$realtime;
          tr.ef2_i=vif.ef2_input_i_vec;
          tr.ef2_q=vif.ef2_input_q_vec;
          tr.ef2_pos_clamp_mask=vif.ef2_pos_clamp_event;
          tr.ef2_neg_clamp_mask=vif.ef2_neg_clamp_event;
          tr.ef2_state_rail_mask=vif.ef2_state_at_rail;
          for (int lane=0;lane<4;lane++) begin
            tr.ef2_err1_i[lane]=vif.ef2_err1_i[lane];
            tr.ef2_err2_i[lane]=vif.ef2_err2_i[lane];
            tr.ef2_err1_q[lane]=vif.ef2_err1_q[lane];
            tr.ef2_err2_q[lane]=vif.ef2_err2_q[lane];
          end
          ap.write(tr);
        end else if (vif.ef2_input_valid && !vif.ef2_input_ready && !stalled) begin
          tr=thermo5_transaction_event::type_id::create("ef2_input_stall");
          tr.kind=THERMO5_EVENT_EF2_STALL;
          tr.epoch=epoch;
          tr.event_cycle=cycle_count;
          tr.local_index=accepted_words;
          tr.time_ns=$realtime;
          tr.ef2_i=vif.ef2_input_i_vec;
          tr.ef2_q=vif.ef2_input_q_vec;
          ap.write(tr);
        end
        stalled=vif.ef2_input_valid && !vif.ef2_input_ready;
        if (stalled) begin
          held_i=vif.ef2_input_i_vec;
          held_q=vif.ef2_input_q_vec;
        end
      end
    end
  endtask
endclass
