class thermo5_sku_config extends uvm_object;
  `uvm_object_utils(thermo5_sku_config)
  int source_beats = 32;
  int core_words = 56;
  int frame_starts = 3;
  string vector_dir;
  bit random_pa_ready;
  bit manual_pa_ready;
  int unsigned pa_stall_percent = 25;
  bit illegal_frame;
  bit expect_pa = 1;
  function new(string name = "thermo5_sku_config"); super.new(name); endfunction
endclass
