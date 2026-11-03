class thermo5_dsp_boundary_monitor extends uvm_monitor;
  `uvm_component_utils(thermo5_dsp_boundary_monitor)
  virtual thermo5_sku_if vif;
  uvm_analysis_port #(thermo5_transaction_event) ap;
  int unsigned epoch, cycle_count;
  bit reset_active;
  logic [15:0] previous_probe_state;
  int unsigned previous_samples[16];
  int unsigned previous_saturations[16];
  bit have_snapshot;

  function new(string name, uvm_component parent);
    super.new(name,parent);
    ap=new("ap",this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual thermo5_sku_if)::get(this,"","vif",vif))
      `uvm_fatal("DSP_MON_VIF","DSP observer needs the Thermo5 interface")
  endfunction

  task run_phase(uvm_phase phase);
    thermo5_transaction_event tr;
    logic [15:0] probe_state;
    bit changed;
    forever begin
      @(posedge vif.core_clk);
      if (!vif.core_rst_n) begin
        if (!reset_active) epoch++;
        reset_active=1;
        cycle_count=0;
        have_snapshot=0;
      end else begin
        reset_active=0;
        cycle_count++;
        probe_state={vif.interp1_empty_blocked,vif.interp2_empty_blocked,
          vif.dpd_empty_blocked,vif.interp1_stage1_empty_blocked,
          vif.interp1_stall_window,vif.interp1_stage1_held,
          vif.interp1_stage0_held,vif.interp2_stage1_held,
          vif.interp1_output_held,vif.interp2_output_held,
          vif.interp1_output_empty_blocked,vif.interp2_stage1_empty_blocked,
          vif.interp1_centered_pop_push,vif.interp2_centered_pop_push,
          vif.underflow,vif.dpd_config_boundary};
        changed=!have_snapshot || (probe_state!==previous_probe_state);
        for (int lane=0;lane<16;lane++) begin
          if (vif.dpd_sample_count[lane]!==previous_samples[lane] ||
              vif.dpd_saturation_count[lane]!==previous_saturations[lane])
            changed=1;
        end
        if (changed) begin
          tr=thermo5_transaction_event::type_id::create("dsp_boundary_snapshot");
          tr.kind=THERMO5_EVENT_DSP_OBSERVATION;
          tr.epoch=epoch;
          tr.event_cycle=cycle_count;
          tr.time_ns=$realtime;
          tr.dsp_probe_state=probe_state;
          tr.dpd_active_taps=vif.dpd_active_taps;
          tr.cfg_pending=vif.cfg_pending_valid;
          for (int lane=0;lane<16;lane++) begin
            tr.dpd_samples[lane]=vif.dpd_sample_count[lane];
            tr.dpd_saturations[lane]=vif.dpd_saturation_count[lane];
            previous_samples[lane]=vif.dpd_sample_count[lane];
            previous_saturations[lane]=vif.dpd_saturation_count[lane];
          end
          ap.write(tr);
        end
        previous_probe_state=probe_state;
        have_snapshot=1;
      end
    end
  endtask
endclass
