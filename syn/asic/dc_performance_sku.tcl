# Pre-layout DC synthesis for the frozen Performance SKU. The caller must
# provide a permitted standard-cell DB through DSM_ASIC_STDCELL_DB.

set ROOT [file normalize [file join [file dirname [info script]] .. ..]]
set RTL "$ROOT/rtl"
foreach var {DSM_ASIC_STDCELL_DB DSM_ASIC_RUN_DIR DSM_ASIC_PERIOD_NS DSM_ASIC_TARGET_MHZ DSM_ASIC_NODE DSM_ASIC_LABEL} {
  if {![info exists ::env($var)] || $::env($var) eq ""} {
    error "Required environment variable is missing: $var"
  }
}
if {![file exists $::env(DSM_ASIC_STDCELL_DB)]} {
  error "Standard-cell DB does not exist: $::env(DSM_ASIC_STDCELL_DB)"
}

set RUN_DIR $::env(DSM_ASIC_RUN_DIR)
set REPORT_DIR "$RUN_DIR/reports"
set INTERP_MODE [expr {[info exists ::env(DSM_ASIC_INTERP_MODE)] ? $::env(DSM_ASIC_INTERP_MODE) : 4}]
set DPD_POLY_ORDER [expr {[info exists ::env(DSM_ASIC_DPD_POLY_ORDER)] ? $::env(DSM_ASIC_DPD_POLY_ORDER) : 5}]
set DPD_MP_MAX_TAPS [expr {[info exists ::env(DSM_ASIC_DPD_MP_MAX_TAPS)] ? $::env(DSM_ASIC_DPD_MP_MAX_TAPS) : 4}]
set ENABLE_DPD_MEMORY [expr {[info exists ::env(DSM_ASIC_ENABLE_DPD_MEMORY)] ? $::env(DSM_ASIC_ENABLE_DPD_MEMORY) : 1}]
set ENABLE_DPD_POLY [expr {[info exists ::env(DSM_ASIC_ENABLE_DPD_POLY)] ? $::env(DSM_ASIC_ENABLE_DPD_POLY) : 0}]
set ENABLE_DPD_LUT [expr {[info exists ::env(DSM_ASIC_ENABLE_DPD_LUT)] ? $::env(DSM_ASIC_ENABLE_DPD_LUT) : 0}]
file mkdir $REPORT_DIR
file mkdir "$RUN_DIR/netlist"
set_app_var search_path [list $RTL]
set stdcell_db [file normalize $::env(DSM_ASIC_STDCELL_DB)]

# Use the normal target/link-library setup used by the existing, known-good
# 28 nm DC flow.  Explicit read_db here caused duplicate library loading in
# some installations; target_library loads the same permitted DB on demand.
set_app_var target_library [list $stdcell_db]
set_app_var link_library [list "*" $stdcell_db]
# Check the library selected by the supplied .db rather than every library
# that DC may load internally (for example GTECH and standard.sldb).
set mapping_lib_name [file rootname [file tail $stdcell_db]]
set loaded_cells [get_lib_cells -quiet "${mapping_lib_name}/*"]
if {[sizeof_collection $loaded_cells] == 0} {
  puts stderr "ERROR: The supplied DB loaded no cells under library $mapping_lib_name"
  exit 2
}
set inverter_cells [get_lib_cells -quiet "${mapping_lib_name}/*INV*"]
if {[sizeof_collection $inverter_cells] == 0} {
  puts stderr "ERROR: Library $mapping_lib_name has no inverter cells and cannot map logic"
  exit 2
}
# Some DC installations issue CMD-013 for a generic `report_lib` redirect
# even after a valid target library has loaded.  The synthesis flow only
# needs auditable evidence of the selected mapping library, so write that
# deterministic record directly instead of invoking a report on all libs.
set library_report [open "$REPORT_DIR/library.rpt" w]
puts $library_report "mapping_library=$mapping_lib_name"
puts $library_report "loaded_cells=[sizeof_collection $loaded_cells]"
puts $library_report "inverter_cells=[sizeof_collection $inverter_cells]"
close $library_report
puts "ASIC DC: mapping_library=$mapping_lib_name loaded_cells=[sizeof_collection $loaded_cells] inverter_cells=[sizeof_collection $inverter_cells]"

analyze -format sverilog [list \
  $RTL/axis/axis_skid_buffer.sv \
  $RTL/dsm/singlebit/dsm_core.sv \
  $RTL/dsm/singlebit/dsm_core_dsm2.sv \
  $RTL/dsm/singlebit/dsm_core_ef1.sv \
  $RTL/dsm/singlebit/dsm_core_ef2.sv \
  $RTL/dsm/singlebit/dsm_core_mash11.sv \
  $RTL/dsm/singlebit/dsm_core_mash111.sv \
  $RTL/dsm/singlebit/dsm_core_mash22.sv \
  $RTL/dsm/multibit/dsm_core_multibit.sv \
  $RTL/dsm/multibit/dsm_core_multibit_lp1.sv \
  $RTL/dsm/multibit/dsm_core_multibit_lp2.sv \
  $RTL/dsm/multibit/dsm_core_multibit_ef1.sv \
  $RTL/dsm/multibit/dsm_core_multibit_ef2.sv \
  $RTL/dsm/multibit/dsm_core_multibit_mash11.sv \
  $RTL/dsm/multibit/dsm_core_multibit_mash111.sv \
  $RTL/dsm/multibit/dsm_core_multibit_mash22.sv \
  $RTL/interp/dsm_interp_fir_fixed.sv \
  $RTL/interp/dsm_interp_cic_direct.sv \
  $RTL/interp/dsm_interp_fir_polyphase.sv \
  $RTL/interp/dsm_interp_fir_i2_polyphase.sv \
  $RTL/interp/dsm_interp2_halfband.sv \
  $RTL/interp/dsm_interp_frontend.sv \
  $RTL/dpd/dpd_poly.v \
  $RTL/dpd/dpd_lut.v \
  $RTL/dpd/dpd_memory_poly.v \
  $RTL/dpd/dpd_observer.v \
  $RTL/dpd/dpd_seed_predictor.v \
  $RTL/dpd/dpd_frontend.v \
  $RTL/duc/duc_fs4_merge.sv \
  $RTL/duc/duc_fs4_merge_signed.sv \
  $RTL/duc/duc_nco_mix_signed.v \
  $RTL/tx_bandpass_if/bp_fs4_iq_mixer.sv \
  $RTL/tx_bandpass_if/dsm_core_bp_single.sv \
  $RTL/tx_bandpass_if/dsm_core_bp_ef2.sv \
  $RTL/tx_bandpass_if/tx_bp_if_top.sv \
  $RTL/ip/dsm_ip_core.sv \
  $RTL/ip/dsm_ip_top.v \
  $RTL/axi/dsm_ip_axi_read_mux.v \
  $RTL/axi/dsm_ip_axi_top.v \
]

elaborate dsm_ip_axi_top -parameters "ALGORITHM=3,INTERP_MODE=$INTERP_MODE,INTERP_IMPL=0,DUC_MODE=3,DPD_POLY_ORDER=$DPD_POLY_ORDER,DPD_MP_MAX_TAPS=$DPD_MP_MAX_TAPS,ENABLE_DPD_POLY=$ENABLE_DPD_POLY,ENABLE_DPD_LUT=$ENABLE_DPD_LUT,ENABLE_DPD_MEMORY=$ENABLE_DPD_MEMORY"
link
redirect -file "$REPORT_DIR/check_design.rpt" { check_design }

set PERIOD $::env(DSM_ASIC_PERIOD_NS)
create_clock -name aclk -period $PERIOD [get_ports aclk]
set_clock_uncertainty -setup 0.10 [get_clocks aclk]
set_clock_uncertainty -hold 0.02 [get_clocks aclk]
set reset_ports [get_ports aresetn]
set data_inputs [remove_from_collection [all_inputs] [add_to_collection [get_ports aclk] $reset_ports]]
set_input_delay 0.20 -clock aclk $data_inputs
set_output_delay 0.20 -clock aclk [all_outputs]
set_false_path -from $reset_ports
set_fix_multiple_port_nets -all -buffer_constants
set_fix_hold [get_clocks aclk]

set power_basis "vectorless_estimate"
if {[info exists ::env(DSM_ASIC_ACTIVITY_FILE)] && $::env(DSM_ASIC_ACTIVITY_FILE) ne ""} {
  if {![file exists $::env(DSM_ASIC_ACTIVITY_FILE)]} {
    error "DSM_ASIC_ACTIVITY_FILE does not exist: $::env(DSM_ASIC_ACTIVITY_FILE)"
  }
  read_saif -input $::env(DSM_ASIC_ACTIVITY_FILE) -instance_name dsm_ip_axi_top
  set power_basis "saif_annotated"
}

compile_ultra
compile -incremental -only_hold_time

redirect -file "$REPORT_DIR/qor.rpt" { report_qor }
redirect -file "$REPORT_DIR/area.rpt" { report_area -hierarchy }
redirect -file "$REPORT_DIR/timing.rpt" { report_timing -max_paths 20 }
redirect -file "$REPORT_DIR/hold_timing.rpt" { report_timing -delay min -max_paths 20 }
redirect -file "$REPORT_DIR/reference.rpt" { report_reference }
redirect -file "$REPORT_DIR/power.rpt" { report_power }
redirect -file "$REPORT_DIR/check_timing.rpt" { check_timing }
redirect -file "$REPORT_DIR/clocks.rpt" { report_clock }
redirect -file "$REPORT_DIR/constraints.rpt" { report_constraint -all_violators }
write -format ddc -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top.ddc"
write_file -format verilog -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top_syn.v"

set metadata [open "$RUN_DIR/metadata.txt" w]
puts $metadata "node=$::env(DSM_ASIC_NODE)"
puts $metadata "label=$::env(DSM_ASIC_LABEL)"
puts $metadata "target_mhz=$::env(DSM_ASIC_TARGET_MHZ)"
puts $metadata "period_ns=$PERIOD"
puts $metadata "power_basis=$power_basis"
puts $metadata "top=dsm_ip_axi_top"
puts $metadata "parameters=ALGORITHM=3,DUC_MODE=3,INTERP_MODE=$INTERP_MODE,INTERP_IMPL=0,DPD_POLY_ORDER=$DPD_POLY_ORDER,DPD_MP_MAX_TAPS=$DPD_MP_MAX_TAPS,ENABLE_DPD_MEMORY=$ENABLE_DPD_MEMORY,ENABLE_DPD_POLY=$ENABLE_DPD_POLY,ENABLE_DPD_LUT=$ENABLE_DPD_LUT"
close $metadata
puts "ASIC_PERFORMANCE_SKU_DC_COMPLETE run_dir=$RUN_DIR"
exit
