// Functional event coverage is kept separate from VCS code coverage.  A test
// must check its required event counts; a sampled bin alone is not a PASS.
class thermo5_sku_coverage extends uvm_component;
  `uvm_component_utils(thermo5_sku_coverage)
  virtual thermo5_sku_if vif;
  thermo5_sku_config cfg;
  int fifo_full_cycles, source_stall_cycles, frame_starts;
  int reset_reassertions, underflow_cycles, protocol_error_cycles;
  int underflow_before_last_source;
  int pa_stall_cycles, pa_words;
  int pa_partial_ready_stall_cycles;
  int accepted_tlast_markers, packet_beats_since_boundary;
  int signed_min_beats, signed_max_beats;
  bit seen_src_release, last_src_rst_n;

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

  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_cg=new(); core_cg=new(); plane_atomic_cg=new();
    stop_restart_cg=new();
  endfunction

  function void sample_stop_restart(bit [2:0] event_code);
    stop_restart_cg.sample(event_code);
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
        else if (vif.src_valid && vif.src_ready) begin
          packet_beats_since_boundary++;
          if (vif.src_last && packet_beats_since_boundary%32==0)
            packet_beats_since_boundary=0;
        end
        if (vif.src_rst_n) seen_src_release=1;
        last_src_rst_n=vif.src_rst_n;
        if (vif.src_rst_n) begin
          if (vif.fifo_full) fifo_full_cycles++;
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
        core_cg.sample(vif.underflow, vif.protocol_error,
                       vif.pa_valid==4'hf && vif.pa_ready!=4'hf,
                       vif.pa_valid==4'hf && vif.pa_ready==4'hf);
        if (vif.core_rst_n) begin
          if (vif.underflow) begin
            underflow_cycles++;
            if (vif.accepted_beats<cfg.source_beats) underflow_before_last_source++;
          end
          if (vif.protocol_error) protocol_error_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf) pa_stall_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready!=4'hf && vif.pa_ready!=4'h0)
            pa_partial_ready_stall_cycles++;
          if (vif.pa_valid==4'hf && vif.pa_ready==4'hf) pa_words++;
        end
      end
    join
  endtask

  function void report_phase(uvm_phase phase);
    `uvm_info("SKU_COVERAGE",$sformatf("full=%0d source_stall=%0d frame=%0d accepted_tlast=%0d reset=%0d underflow=%0d early_underflow=%0d illegal=%0d pa_stall=%0d pa_partial_ready_stall=%0d pa_words=%0d signed_min_beats=%0d signed_max_beats=%0d source_cg=%.1f core_cg=%.1f plane_atomic_cg=%.1f stop_restart_cg=%.1f",
      fifo_full_cycles,source_stall_cycles,frame_starts,accepted_tlast_markers,reset_reassertions,
      underflow_cycles,underflow_before_last_source,protocol_error_cycles,pa_stall_cycles,
      pa_partial_ready_stall_cycles,pa_words,
      signed_min_beats,signed_max_beats,
      source_cg.get_coverage(),core_cg.get_coverage(),plane_atomic_cg.get_coverage(),
      stop_restart_cg.get_coverage()),UVM_NONE)
  endfunction
endclass
