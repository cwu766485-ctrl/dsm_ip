// Frozen verification SKU. Keep these values aligned with synthesis and IP
// packaging manifests before accepting a regression result.
localparam int unsigned DSM_SKU_ALGORITHM         = 3;
localparam int unsigned DSM_SKU_DUC_MODE          = 3;
localparam int unsigned DSM_SKU_INTERP_MODE       = 4;
localparam int unsigned DSM_SKU_INTERP_IMPL       = 0;
localparam bit          DSM_SKU_ENABLE_DPD_POLY   = 1'b0;
localparam bit          DSM_SKU_ENABLE_DPD_LUT    = 1'b0;
localparam bit          DSM_SKU_ENABLE_DPD_MEMORY = 1'b1;
localparam int unsigned DSM_SKU_DPD_MP_MAX_TAPS   = 4;
localparam int unsigned DSM_SKU_DPD_POLY_ORDER    = 5;
localparam int unsigned DSM_SKU_ACLK_HZ           = 100_000_000;
localparam int unsigned DSM_SKU_INTERP_RATIO      = 32;
localparam logic [31:0] DSM_SKU_CORE_VERSION      = 32'h0001_0005;

// DPD paths are explicitly aligned to the ten-stage memory-polynomial path.
// Interpolation is an elastic rate-changing pipeline, so end-to-end checking
// must use ready/valid transaction order rather than a fixed cycle offset.
localparam int unsigned DSM_DPD_LATENCY_CYCLES    = 10;
localparam int unsigned DSM_BP_MIXER_CYCLES       = 1;
localparam int unsigned DSM_BP_QUANTIZER_CYCLES   = 1;
localparam bit          DSM_E2E_FIXED_LATENCY     = 1'b0;

function automatic string dsm_vector_dir();
  string value;
  if (!$value$plusargs("DSM_VECTOR_DIR=%s", value)) begin
    void'($value$plusargs("DSM_VECTOR_DIR+%s", value));
  end
  if (value == "")
    value = "uvm_verif/refmodel/python/out";
  return value;
endfunction

class dsm_uvm_config extends uvm_object;
  int unsigned post_sequence_cycles = 1800;
  int unsigned drain_timeout_cycles = 4096;
  bit check_sku_readback = 1'b1;
  bit require_rf_toggle = 1'b1;
  bit require_rf_output = 1'b1;
  int unsigned expected_rf_count = 0;
  bit enable_fullchain_check = 1'b0;
  string fullchain_vector_set = "performance_sku";

  `uvm_object_utils_begin(dsm_uvm_config)
    `uvm_field_int(post_sequence_cycles, UVM_DEFAULT)
    `uvm_field_int(drain_timeout_cycles, UVM_DEFAULT)
    `uvm_field_int(check_sku_readback, UVM_DEFAULT)
    `uvm_field_int(require_rf_toggle, UVM_DEFAULT)
    `uvm_field_int(require_rf_output, UVM_DEFAULT)
    `uvm_field_int(expected_rf_count, UVM_DEFAULT)
    `uvm_field_int(enable_fullchain_check, UVM_DEFAULT)
    `uvm_field_string(fullchain_vector_set, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "dsm_uvm_config");
    super.new(name);
  endfunction
endclass
