typedef enum bit [1:0] {
  DSM_ARCH_EF1    = 2'd0,
  DSM_ARCH_EF2    = 2'd1,
  DSM_ARCH_MASH11 = 2'd2
} thermo5_dsm_arch_e;

typedef enum bit [1:0] {
  PA_CONTRACT_FOUR_EQUAL = 2'd0,
  PA_CONTRACT_MASH_1_TO_2 = 2'd1
} thermo5_pa_contract_e;

class thermo5_mash_pa_word extends uvm_sequence_item;
  `uvm_object_utils(thermo5_mash_pa_word)
  bit [63:0] stage1;
  bit [63:0] stage2;
  int unsigned epoch, word_index;
  int unsigned config_id;
  bit frame_start, frame_end, tail;
  function new(string name = "thermo5_mash_pa_word"); super.new(name); endfunction
endclass

