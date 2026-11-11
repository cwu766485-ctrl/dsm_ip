package thermo5_sku_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int SRC_BEATS = 32;
  localparam int CORE_WORDS = 56;
  localparam int SAMPLES = 448;

  `include "thermo5_sku_config.svh"
  `include "thermo5_source_item.svh"
  `include "thermo5_axil_item.svh"
  class thermo5_pa_word extends uvm_sequence_item;
    bit [63:0] plane[4];
    int unsigned epoch, word_index;
    `uvm_object_utils(thermo5_pa_word)
    function new(string name = "thermo5_pa_word"); super.new(name); endfunction
  endclass

  `uvm_analysis_imp_decl(_src)
  `uvm_analysis_imp_decl(_pa)
  `uvm_analysis_imp_decl(_axil_fire)
  `uvm_analysis_imp_decl(_axil_addr)
  `uvm_analysis_imp_decl(_axil_done)
  `uvm_analysis_imp_decl(_axil_cycle)
  `uvm_analysis_imp_decl(_trace_src)
  `uvm_analysis_imp_decl(_trace_pa)
  `uvm_analysis_imp_decl(_trace_axil_fire)
  `uvm_analysis_imp_decl(_trace_axil_addr)
  `uvm_analysis_imp_decl(_trace_axil_done)
  `uvm_analysis_imp_decl(_trace_axil_cycle)
  `uvm_analysis_imp_decl(_cdc_evt)
  `uvm_analysis_imp_decl(_dsp_evt)
  `uvm_analysis_imp_decl(_ef2_evt)
  `uvm_analysis_imp_decl(_event)
  `include "thermo5_transaction_event.svh"
  `include "thermo5_source_sequencer.svh"
  `include "thermo5_source_driver.svh"
  `include "thermo5_source_monitor.svh"
  `include "thermo5_source_agent.svh"
  `include "thermo5_source_sequence.svh"
  `include "thermo5_axil_sequencer.svh"
  `include "thermo5_axil_driver.svh"
  `include "thermo5_axil_monitor.svh"
  `include "thermo5_axil_agent.svh"
  `include "thermo5_pa_monitor.svh"
  `include "thermo5_cdc_core_monitor.svh"
  `include "thermo5_dsp_boundary_monitor.svh"
  `include "thermo5_ef2_input_monitor.svh"
  `include "thermo5_pa_sink_driver.svh"
  `include "thermo5_pa_sink_agent.svh"
  `include "thermo5_control_agent.svh"
  `include "thermo5_axil_register_predictor.svh"
  `include "thermo5_trace_recorder.svh"
  `include "thermo5_pa_scoreboard.svh"
  `include "thermo5_sku_coverage.svh"
  `include "thermo5_transaction_event_bus.svh"
  `include "thermo5_unified_scoreboard.svh"
  `include "thermo5_unified_scoreboard_mutation_test.svh"
  `include "thermo5_sku_virtual_sequencer.svh"
  `include "thermo5_sku_env.svh"
  `include "thermo5_sku_base_test.svh"
  `include "thermo5_sku_bittrue_test.svh"
  `include "thermo5_sku_corner_tests.svh"
  `include "thermo5_axil_access_sequence.svh"
  `include "thermo5_sku_virtual_sequence.svh"
  `include "thermo5_sku_axil_config_test.svh"
  `include "thermo5_sku_axil_virtual_sequence_smoke_test.svh"
  `include "thermo5_sku_axil_random_packet_test.svh"
  `include "thermo5_sku_axil_graceful_stop_test.svh"
  `include "thermo5_sku_axil_stop_restart_test.svh"
  `include "thermo5_sku_axil_register_access_test.svh"
  `include "thermo5_sku_axil_coeff_transport_test.svh"
  `include "thermo5_sku_axil_nonlinear_dpd_test.svh"
  `include "thermo5_sku_axil_nonlinear_bittrue_test.svh"
  `include "thermo5_sku_axil_random_dpd_bittrue_test.svh"
  `include "thermo5_sku_axil_dpd_saturation_bittrue_test.svh"
  `include "thermo5_sku_axil_nonlinear_tap4_bittrue_test.svh"
  `include "thermo5_sku_axil_ef2_corner_test.svh"
  `include "thermo5_sku_axil_tap4_identity_test.svh"
  `include "thermo5_sku_axil_boundary_phase_test.svh"
  `include "thermo5_sku_axil_mailbox_fault_test.svh"
  `include "thermo5_sku_axil_reset_pending_commit_test.svh"
  `include "thermo5_sku_axil_illegal_frame_test.svh"
  `include "thermo5_sku_axil_reset_sweep_test.svh"
  `include "thermo5_sku_axil_stalled_reset_test.svh"
  `include "thermo5_sku_axil_starvation_test.svh"
  `include "thermo5_sku_axil_frame_replacement_test.svh"
  `include "thermo5_sku_axil_outstanding_bounds_test.svh"
  `include "thermo5_sku_low_power_drain_test.svh"
  `include "thermo5_sku_axil_p0_overlap_test.svh"
  `include "thermo5_sku_axil_p0_reset_test.svh"
endpackage
