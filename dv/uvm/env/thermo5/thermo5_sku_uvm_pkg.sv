package thermo5_sku_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  localparam int SRC_BEATS = 32;
  localparam int CORE_WORDS = 56;
  localparam int SAMPLES = 448;

  `include "thermo5_sku_config.svh"
  `include "thermo5_source_item.svh"
  class thermo5_pa_word extends uvm_sequence_item;
    bit [63:0] plane[4];
    `uvm_object_utils(thermo5_pa_word)
    function new(string name = "thermo5_pa_word"); super.new(name); endfunction
  endclass

  `uvm_analysis_imp_decl(_src)
  `uvm_analysis_imp_decl(_pa)
  `include "thermo5_source_sequencer.svh"
  `include "thermo5_source_driver.svh"
  `include "thermo5_source_monitor.svh"
  `include "thermo5_source_agent.svh"
  `include "thermo5_source_sequence.svh"
  `include "thermo5_pa_monitor.svh"
  `include "thermo5_control_bfm.svh"
  `include "thermo5_pa_scoreboard.svh"
  `include "thermo5_sku_coverage.svh"
  `include "thermo5_sku_env.svh"
  `include "thermo5_sku_bittrue_test.svh"
  `include "thermo5_sku_corner_tests.svh"
endpackage
