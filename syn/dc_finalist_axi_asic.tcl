# Parameterized pre-layout DC synthesis for a full AXI finalist.
# The caller supplies the technology library and one finalist algorithm.

set ROOT [file normalize [file join [file dirname [info script]] ..]]
set RTL "$ROOT/rtl"
set PERIOD [expr {[info exists ::env(DSM_ASIC_PERIOD_NS)] ? $::env(DSM_ASIC_PERIOD_NS) : 10.0}]
set MAX_CORES [expr {[info exists ::env(DSM_ASIC_MAX_CORES)] ? $::env(DSM_ASIC_MAX_CORES) : 4}]
set DUC_MODE [expr {[info exists ::env(DSM_ASIC_DUC_MODE)] ? $::env(DSM_ASIC_DUC_MODE) : 0}]

foreach var {DSM_ASIC_STDCELL_DB DSM_ASIC_NODE DSM_ASIC_LABEL DSM_ASIC_ALGORITHM DSM_ASIC_RUN_DIR} {
  if {![info exists ::env($var)] || $::env($var) eq ""} {
    error "Required environment variable is missing: $var"
  }
}
if {![file exists $::env(DSM_ASIC_STDCELL_DB)]} {
  error "Standard-cell DB does not exist: $::env(DSM_ASIC_STDCELL_DB)"
}

set RUN_DIR $::env(DSM_ASIC_RUN_DIR)
file mkdir "$RUN_DIR/reports"
file mkdir "$RUN_DIR/netlist"
# Keep DC's HDL compiler intermediates out of the source-tree root.
cd $RUN_DIR
set_app_var search_path [list $RTL]
set_app_var target_library [list $::env(DSM_ASIC_STDCELL_DB)]
set_app_var link_library [list "*" $::env(DSM_ASIC_STDCELL_DB)]

# Reject macro-only or otherwise incomplete DB files before spending time in
# elaboration. A mappable standard-cell library must provide an inverter.
if {[sizeof_collection [get_lib_cells */*INV*]] == 0} {
  error "Standard-cell DB has no inverter cells: $::env(DSM_ASIC_STDCELL_DB)"
}

puts "DSM ASIC DC: node=$::env(DSM_ASIC_NODE) label=$::env(DSM_ASIC_LABEL) algorithm=$::env(DSM_ASIC_ALGORITHM) duc_mode=$DUC_MODE period_ns=$PERIOD"
puts "DSM ASIC DC: stdcell_db=$::env(DSM_ASIC_STDCELL_DB)"
set_host_options -max_cores $MAX_CORES

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

elaborate dsm_ip_axi_top -parameters "ALGORITHM=$::env(DSM_ASIC_ALGORITHM),INTERP_MODE=4,INTERP_IMPL=0,DUC_MODE=$DUC_MODE,DPD_POLY_ORDER=5,DPD_MP_MAX_TAPS=4,ENABLE_DPD_POLY=0,ENABLE_DPD_LUT=0,ENABLE_DPD_MEMORY=1"
# Elaborate makes the parameterized top current; its generated design name
# includes the parameter values and is not literally dsm_ip_axi_top.
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

if {[info exists ::env(DSM_ASIC_FAST)] && $::env(DSM_ASIC_FAST) eq "1"} {
  # This bounded exploratory mode is for environments that cannot sustain a
  # full compile_ultra job. It is explicitly reported as low-effort PPA.
  compile -map_effort low
} else {
  compile_ultra
  compile -incremental -only_hold_time
}

redirect -file "$RUN_DIR/reports/qor.rpt" { report_qor }
redirect -file "$RUN_DIR/reports/area.rpt" { report_area -hierarchy }
redirect -file "$RUN_DIR/reports/clocks.rpt" { report_clocks }
redirect -file "$RUN_DIR/reports/check_timing.rpt" { check_timing }
redirect -file "$RUN_DIR/reports/constraints.rpt" { report_constraint -all_violators }
redirect -file "$RUN_DIR/reports/timing.rpt" { report_timing -max_paths 20 }
redirect -file "$RUN_DIR/reports/hold_timing.rpt" { report_timing -delay min -max_paths 20 }
redirect -file "$RUN_DIR/reports/reference.rpt" { report_reference }
redirect -file "$RUN_DIR/reports/power.rpt" { report_power }
write -format ddc -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top.ddc"
write_file -format verilog -hierarchy -output "$RUN_DIR/netlist/dsm_ip_axi_top_syn.v"
puts "DSM ASIC DC completed: $RUN_DIR"
exit
