# DC lint-only elaboration for the complete BP EFDSM2 AXI SKU.
# Intentionally stops before compile_ultra: this is structural RTL checking,
# not implementation PPA.
set ROOT [file normalize [file join [file dirname [info script]] ..]]
set RTL "$ROOT/rtl"
set PERIOD [expr {[info exists ::env(DSM_LINT_PERIOD_NS)] ? $::env(DSM_LINT_PERIOD_NS) : 10.0}]
foreach var {DSM_LINT_STDCELL_DB DSM_LINT_RUN_DIR} {
  if {![info exists ::env($var)] || $::env($var) eq ""} { error "Required environment variable is missing: $var" }
}
if {![file exists $::env(DSM_LINT_STDCELL_DB)]} { error "Standard-cell DB does not exist: $::env(DSM_LINT_STDCELL_DB)" }
set RUN_DIR [file normalize $::env(DSM_LINT_RUN_DIR)]
file mkdir "$RUN_DIR/reports"
set_app_var search_path [list $RTL]
set_app_var target_library [list $::env(DSM_LINT_STDCELL_DB)]
set_app_var link_library [list "*" $::env(DSM_LINT_STDCELL_DB)]
if {[sizeof_collection [get_lib_cells */*INV*]] == 0} { error "Standard-cell DB has no inverter cells" }

set rtl_files [list \
  $RTL/axis/axis_skid_buffer.sv \
  $RTL/dsm/singlebit/dsm_core.sv $RTL/dsm/singlebit/dsm_core_dsm2.sv \
  $RTL/dsm/singlebit/dsm_core_ef1.sv $RTL/dsm/singlebit/dsm_core_ef2.sv \
  $RTL/dsm/singlebit/dsm_core_mash11.sv $RTL/dsm/singlebit/dsm_core_mash111.sv \
  $RTL/dsm/singlebit/dsm_core_mash22.sv \
  $RTL/dsm/multibit/dsm_core_multibit.sv $RTL/dsm/multibit/dsm_core_multibit_lp1.sv \
  $RTL/dsm/multibit/dsm_core_multibit_lp2.sv $RTL/dsm/multibit/dsm_core_multibit_ef1.sv \
  $RTL/dsm/multibit/dsm_core_multibit_ef2.sv $RTL/dsm/multibit/dsm_core_multibit_mash11.sv \
  $RTL/dsm/multibit/dsm_core_multibit_mash111.sv $RTL/dsm/multibit/dsm_core_multibit_mash22.sv \
  $RTL/interp/dsm_interp_fir_fixed.sv $RTL/interp/dsm_interp_cic_direct.sv \
  $RTL/interp/dsm_interp_fir_polyphase.sv $RTL/interp/dsm_interp_fir_i2_polyphase.sv \
  $RTL/interp/dsm_interp2_halfband.sv $RTL/interp/dsm_interp_frontend.sv \
  $RTL/dpd/dpd_poly.v $RTL/dpd/dpd_lut.v $RTL/dpd/dpd_memory_poly.v \
  $RTL/dpd/dpd_observer.v $RTL/dpd/dpd_seed_predictor.v $RTL/dpd/dpd_frontend.v \
  $RTL/duc/duc_fs4_merge.sv $RTL/duc/duc_fs4_merge_signed.sv $RTL/duc/duc_nco_mix_signed.v \
  $RTL/tx_bandpass_if/bp_fs4_iq_mixer.sv $RTL/tx_bandpass_if/dsm_core_bp_single.sv \
  $RTL/tx_bandpass_if/dsm_core_bp_ef2.sv $RTL/tx_bandpass_if/tx_bp_if_top.sv \
  $RTL/ip/dsm_ip_core.sv $RTL/ip/dsm_ip_top.v $RTL/axi/dsm_ip_axi_top.v]
foreach f $rtl_files { if {![file exists $f]} { error "RTL source is missing: $f" } }

puts "BP EFDSM2 AXI DC lint: analyze [llength $rtl_files] RTL files"
analyze -format sverilog $rtl_files
elaborate dsm_ip_axi_top -parameters "ALGORITHM=3,INTERP_MODE=4,INTERP_IMPL=0,DUC_MODE=3,DPD_POLY_ORDER=5,DPD_MP_MAX_TAPS=4,ENABLE_DPD_POLY=0,ENABLE_DPD_LUT=0,ENABLE_DPD_MEMORY=1"
link
redirect -file "$RUN_DIR/reports/check_design.rpt" { check_design }
redirect -file "$RUN_DIR/reports/reference.rpt" { report_reference }
create_clock -name aclk -period $PERIOD [get_ports aclk]
set_clock_uncertainty -setup 0.10 [get_clocks aclk]
set_clock_uncertainty -hold 0.02 [get_clocks aclk]
set reset_ports [get_ports aresetn]
set data_inputs [remove_from_collection [all_inputs] [add_to_collection [get_ports aclk] $reset_ports]]
set_input_delay 0.20 -clock aclk $data_inputs
set_output_delay 0.20 -clock aclk [all_outputs]
set_false_path -from $reset_ports
redirect -file "$RUN_DIR/reports/check_timing.rpt" { check_timing }
redirect -file "$RUN_DIR/reports/timing_paths.rpt" { report_timing -max_paths 10 }
redirect -file "$RUN_DIR/reports/ports.rpt" { report_port -verbose }
set fp [open "$RUN_DIR/LINT_PASS" w]
puts $fp "BP_EFDSM2_AXI lint passed: analyze/elaborate/link/check_design/check_timing"
puts $fp "Parameters: ALGORITHM=3 INTERP_MODE=4 INTERP_IMPL=0 DUC_MODE=3 MEMORY_DPD_ONLY"
close $fp
puts "BP EFDSM2 AXI DC lint completed: $RUN_DIR"
exit
