class thermo5_sku_config extends uvm_object;
  `uvm_object_utils(thermo5_sku_config)
  int source_beats = 32;
  int core_words = 56;
  int frame_starts = 3;
  string vector_dir;
  bit random_pa_ready;
  bit random_partial_pa_ready;
  bit manual_pa_ready;
  int unsigned pa_stall_percent = 25;
  bit illegal_frame;
  bit expect_pa = 1;
  bit ef2_reference_enable;
  bit axil_control;
  thermo5_dsm_arch_e dsm_arch = DSM_ARCH_EF1;
  thermo5_pa_contract_e pa_contract = PA_CONTRACT_FOUR_EQUAL;
  int unsigned mash_fifo_depth = 0;
  int unsigned mash_core_latency = 0;
  bit mash_bounded_backpressure;
  uvm_active_passive_enum pa_sink_active = UVM_ACTIVE;
  function new(string name = "thermo5_sku_config"); super.new(name); endfunction
endclass
