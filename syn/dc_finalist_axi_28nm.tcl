# TSMC28 nominal-PVT, pre-layout DC synthesis for one full AXI finalist.
# Required environment: DSM28_STDCELL_DB, DSM28_LABEL, DSM28_ALGORITHM and
# DSM28_RUN_DIR.  This is a synthesis estimate only: it has no placement,
# clock-tree, extracted RC or multi-corner signoff analysis.

set ROOT [file normalize [file join [file dirname [info script]] ..]]
set RTL "$ROOT/rtl"
set PERIOD [expr {[info exists ::env(DSM28_PERIOD_NS)] ? $::env(DSM28_PERIOD_NS) : 10.0}]

foreach var {DSM28_STDCELL_DB DSM28_LABEL DSM28_ALGORITHM DSM28_RUN_DIR} {
  if {![info exists ::env($var)] || $::env($var) eq ""} {
    error "Required environment variable is missing: $var"
  }
}
if {![file exists $::env(DSM28_STDCELL_DB)]} {
  error "DSM28_STDCELL_DB does not exist: $::env(DSM28_STDCELL_DB)"
}

set RUN_DIR $::env(DSM28_RUN_DIR)
file mkdir "$RUN_DIR/reports"
file mkdir "$RUN_DIR/netlist"
set_app_var search_path [list $RTL]
set_app_var target_library [list $::env(DSM28_STDCELL_DB)]
set_app_var link_library [list "*" $::env(DSM28_STDCELL_DB)]

puts "DSM 28nm DC: label=$::env(DSM28_LABEL) algorithm=$::env(DSM28_ALGORITHM) period_ns=$PERIOD"
puts "DSM 28nm DC: stdcell_db=$::env(DSM28_STDCELL_DB)"

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
  $RTL/ip/dsm_ip_core.sv \
  $RTL/ip/dsm_ip_top.v \
  $RTL/axi/dsm_ip_axi_top.v \
]

elaborate dsm_ip_axi_top -parameters "ALGORITHM=$::env(DSM28_ALGORITHM),INTERP_MODE=4,INTERP_IMPL=0,DUC_MODE=0,ENABLE_DPD_MEMORY=1"
current_design dsm_ip_axi_top
link
redirect -file "$RUN_DIR/reports/check_design.rpt" { check_design }

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

compile_ultra
compile -incremental -only_hold_time

redirect -file "$RUN_DIR/reports/qor.rpt" { report_qor }
redirect -file "$RUN_DIR/reports/area.rpt" { report_area -hierarchy }
redirect -file "$RUN_DIR/reports/timing.rpt" { report_timing -max_paths 20 }
redirect -file "$RUN_DIR/reports/hold_timing.rpt" { report_timing -delay min -max_paths 20 }
redirect -file "$RUN_DIR/reports/reference.rpt" { report_reference }
redirect -file "$RUN_DIR/reports/power.rpt" { report_power }
write -format ddc -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top.ddc"
write_file -format verilog -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top_syn.v"
puts "DSM 28nm DC completed: $RUN_DIR"
exit
