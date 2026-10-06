class thermo5_source_sequence extends uvm_sequence#(thermo5_source_item);
  `uvm_object_utils(thermo5_source_sequence)
  thermo5_sku_config cfg;
  int beat_count;
  bit illegal_frame;
  int gap_before_beat = -1;
  int unsigned gap_cycles = 0;
  logic [15:0] i_mem[], q_mem[], frame_mem[], gain_mem[];
  function new(string name = "thermo5_source_sequence"); super.new(name); endfunction
  task body();
    thermo5_source_item tr;
    int sample, core_word;
    if (cfg == null) `uvm_fatal("NOCFG","Source sequence configuration missing")
    if (beat_count < 1 || beat_count > cfg.source_beats)
      `uvm_fatal("BEATS","Source beat count is outside the SKU vector")
    i_mem=new[cfg.core_words*8]; q_mem=new[cfg.core_words*8];
    frame_mem=new[cfg.core_words]; gain_mem=new[cfg.core_words];
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_i.mem"},i_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_q.mem"},q_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_frame_start.mem"},frame_mem);
    $readmemh({cfg.vector_dir,"/tid32_thermo5_frontend_frame_gain.mem"},gain_mem);
    for (int beat=0;beat<beat_count;beat++) begin
      tr=thermo5_source_item::type_id::create($sformatf("beat_%0d",beat));
      sample=14*beat;
      core_word=sample/8;
      tr.beat_index=beat;
      tr.valid_gap_cycles=(beat==gap_before_beat) ? gap_cycles : 0;
      tr.frame_start=frame_mem[core_word][0] || (illegal_frame && beat==1);
      tr.frame_gain=gain_mem[core_word];
      for (int lane=0;lane<14;lane++) begin
        tr.i_vec[lane*16+:16]=i_mem[sample+lane];
        tr.q_vec[lane*16+:16]=q_mem[sample+lane];
      end
      start_item(tr);
      finish_item(tr);
    end
  endtask
endclass
