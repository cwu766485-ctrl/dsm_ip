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
  int signed_min_beats, signed_max_beats;
  bit seen_src_release, last_src_rst_n;

  covergroup source_cg with function sample(bit full, bit stalled, bit start,
                                              bit reset_low, bit signed_min,
                                              bit signed_max);
    option.per_instance = 1;
    cp_full: coverpoint full { bins not_full={0}; bins full={1}; }
    cp_stalled: coverpoint stalled { bins flowing={0}; bins backpressured={1}; }
    cp_start: coverpoint start { bins ordinary={0}; bins frame={1}; }
    cp_reset: coverpoint reset_low { bins active={0}; bins reset={1}; }
    cp_signed_min: coverpoint signed_min { bins absent={0}; bins present={1}; }
    cp_signed_max: coverpoint signed_max { bins absent={0}; bins present={1}; }
  endgroup
  covergroup core_cg with function sample(bit underflow, bit illegal, bit pa_stall, bit pa_word);
    option.per_instance = 1;
    cp_underflow: coverpoint underflow { bins normal={0}; bins empty={1}; }
    cp_illegal: coverpoint illegal { bins legal={0}; bins bad_frame={1}; }
    cp_pa_stall: coverpoint pa_stall { bins ready={0}; bins stalled={1}; }
    cp_pa_word: coverpoint pa_word { bins no_word={0}; bins four_plane_word={1}; }
  endgroup
  function new(string name, uvm_component parent);
    super.new(name,parent);
    source_cg=new(); core_cg=new();
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
    fork
      forever begin
        @(posedge vif.src_clk);
        accepted_min=0;
        accepted_max=0;
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
                         !vif.src_rst_n, accepted_min, accepted_max);
        if (seen_src_release && last_src_rst_n && !vif.src_rst_n) reset_reassertions++;
        if (vif.src_rst_n) seen_src_release=1;
        last_src_rst_n=vif.src_rst_n;
        if (vif.src_rst_n) begin
          if (vif.fifo_full) fifo_full_cycles++;
          if (vif.src_valid && !vif.src_ready) source_stall_cycles++;
          if (vif.src_valid && vif.src_ready && vif.frame_start) frame_starts++;
          if (accepted_min) signed_min_beats++;
          if (accepted_max) signed_max_beats++;
        end
      end
      forever begin
        @(posedge vif.core_clk);
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
          if (vif.pa_valid==4'hf && vif.pa_ready==4'hf) pa_words++;
        end
      end
    join
  endtask
  function void report_phase(uvm_phase phase);
    `uvm_info("SKU_COVERAGE",$sformatf("full=%0d source_stall=%0d frame=%0d reset=%0d underflow=%0d early_underflow=%0d illegal=%0d pa_stall=%0d pa_words=%0d signed_min_beats=%0d signed_max_beats=%0d source_cg=%.1f core_cg=%.1f",
      fifo_full_cycles,source_stall_cycles,frame_starts,reset_reassertions,
      underflow_cycles,underflow_before_last_source,protocol_error_cycles,pa_stall_cycles,pa_words,
      signed_min_beats,signed_max_beats,
      source_cg.get_coverage(),core_cg.get_coverage()),UVM_NONE)
  endfunction
endclass
