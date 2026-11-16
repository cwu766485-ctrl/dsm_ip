package thermo5_arch_contract_pkg;
  typedef enum logic [1:0] {
    DSM_ARCH_EF1    = 2'd0,
    DSM_ARCH_EF2    = 2'd1,
    DSM_ARCH_MASH11 = 2'd2
  } dsm_arch_e;

  typedef enum logic [1:0] {
    PA_CONTRACT_FOUR_EQUAL = 2'd0,
    PA_CONTRACT_MASH_1_TO_2 = 2'd1
  } pa_contract_e;

  typedef struct packed {
    dsm_arch_e arch;
    pa_contract_e pa_contract;
    logic frame_start;
    logic frame_end;
    logic tail;
    logic [15:0] config_id;
    logic [15:0] epoch;
  } dsm_boundary_meta_t;
endpackage

