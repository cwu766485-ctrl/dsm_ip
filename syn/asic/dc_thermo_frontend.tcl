# Reproducible pre-layout DC synthesis for the thermo3/thermo5 ASIC wrappers.
# Run with DSM_ASIC_FLAVOUR=thermo3 or thermo5 and a permitted TSMC28 DB.
set ROOT [file normalize [file join [file dirname [info script]] .. ..]]
foreach v {DSM_ASIC_STDCELL_DB DSM_ASIC_RUN_DIR DSM_ASIC_FLAVOUR} {
  if {![info exists ::env($v)] || $::env($v) eq ""} { error "missing $v" }
}
set db [file normalize $::env(DSM_ASIC_STDCELL_DB)]
if {![file exists $db]} { error "standard-cell DB does not exist: $db" }
set run [file normalize $::env(DSM_ASIC_RUN_DIR)]
set rep "$run/reports"
set compile_mode [expr {[info exists ::env(DSM_ASIC_COMPILE_MODE)] ? $::env(DSM_ASIC_COMPILE_MODE) : "bounded"}]
file mkdir $rep
file mkdir "$run/netlist"
set_app_var search_path [list "$ROOT/rtl" "$ROOT/syn/rtl"]
set_app_var target_library [list $db]
set_app_var link_library [list "*" $db]
set libname [file rootname [file tail $db]]
set cells [get_lib_cells -quiet "${libname}/*"]
if {[sizeof_collection $cells] == 0} { error "no cells loaded from $db" }
set invs [get_lib_cells -quiet "${libname}/*INV*"]
if {[sizeof_collection $invs] == 0} { error "mapping library has no inverter cells" }
set lf [open "$rep/library.rpt" w]
puts $lf "mapping_library=$libname"
puts $lf "loaded_cells=[sizeof_collection $cells]"
puts $lf "inverter_cells=[sizeof_collection $invs]"
close $lf

set src [list \
  "$ROOT/rtl/axis/dsm_reset_sync.sv" \
  "$ROOT/rtl/axis/dsm_async_fifo.sv" \
  "$ROOT/rtl/axis/dsm_axis14_to_core8_cdc.sv" \
  "$ROOT/rtl/frontend/dsm_frame_gain_vector.sv" \
  "$ROOT/rtl/dpd/dpd_poly.v" \
  "$ROOT/rtl/dpd/dpd_memory_poly.v" \
  "$ROOT/rtl/dpd/dpd_vector16_memory_poly.sv" \
  "$ROOT/rtl/dpd/dpd_vector_elastic_buffer.sv" \
  "$ROOT/rtl/interp/dsm_interp_x2_polyphase_vector.sv" \
  "$ROOT/rtl/gt/gt_tx_raw64_boundary.sv" \
  "$ROOT/rtl/gt/gt_tx_user_bridge.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo3_fs4_multipa_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo3_frontend_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo3_axis_frontend_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo5_fs4_multipa_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo5_frontend_tx.sv" \
  "$ROOT/rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv" \
  "$ROOT/syn/rtl/tid32_thermo_asic_frontend_dc.sv"]
analyze -format sverilog $src
if {$::env(DSM_ASIC_FLAVOUR) eq "thermo3"} {
  set top tid32_thermo3_axis_frontend_tx_asic_dc
} elseif {$::env(DSM_ASIC_FLAVOUR) eq "thermo5"} {
  set top tid32_thermo5_axis_frontend_tx_asic_dc
} else { error "DSM_ASIC_FLAVOUR must be thermo3 or thermo5" }
elaborate $top
current_design $top
link
redirect -file "$rep/check_design.rpt" {check_design}
redirect -file "$rep/check_timing_pre.rpt" {check_timing}
create_clock -name clk125 -period 8.000 [get_ports clk125]
create_clock -name clk218 -period 4.571428 [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks clk125] -group [get_clocks clk218]
set_false_path -from [get_ports {rst125_n rst218_n}]
set_input_delay 0.20 -clock clk125 [get_ports {s_valid s_frame_start s_i_vec s_q_vec s_frame_gain dpd_active_taps c1_re c1_im c3_re c3_im c5_re c5_im}]
set_output_delay 0.20 -clock clk218 [all_outputs]
set_fix_multiple_port_nets -all -buffer_constants
if {$compile_mode eq "bounded"} {
  # The complete frontend is very large when FPGA DSP/BRAM resources are
  # mapped into standard cells.  Start with the lower-memory classic mapper;
  # the resulting DDC is a checkpoint for a later incremental high-effort run.
  compile -map_effort medium -area_effort medium
} elseif {$compile_mode eq "ultra"} {
  compile_ultra
} elseif {$compile_mode eq "incremental"} {
  if {![info exists ::env(DSM_ASIC_INPUT_DDC)] || ![file exists $::env(DSM_ASIC_INPUT_DDC)]} {
    error "incremental mode requires DSM_ASIC_INPUT_DDC"
  }
  read_ddc $::env(DSM_ASIC_INPUT_DDC)
  current_design $top
  compile_ultra -incremental
} else {
  error "DSM_ASIC_COMPILE_MODE must be bounded, ultra, or incremental"
}
compile -incremental -only_hold_time
redirect -file "$rep/qor.rpt" {report_qor}
redirect -file "$rep/area.rpt" {report_area -hierarchy}
redirect -file "$rep/timing_setup.rpt" {report_timing -max_paths 20}
redirect -file "$rep/timing_hold.rpt" {report_timing -delay min -max_paths 20}
redirect -file "$rep/power.rpt" {report_power}
redirect -file "$rep/reference.rpt" {report_reference}
redirect -file "$rep/check_timing.rpt" {check_timing}
redirect -file "$rep/constraints.rpt" {report_constraint -all_violators}
write -format ddc -hierarchy -output "$run/netlist/${top}.ddc"
write_file -format verilog -hierarchy -output "$run/netlist/${top}_syn.v"
set mf [open "$run/metadata.txt" w]
puts $mf "top=$top"
puts $mf "flavour=$::env(DSM_ASIC_FLAVOUR)"
puts $mf "mapping_library=$libname"
puts $mf "power_basis=vectorless_estimate"
puts $mf "compile_mode=$compile_mode"
puts $mf "clk125_period_ns=8.000"
puts $mf "clk218_period_ns=4.571428"
close $mf
puts "THERMO_ASIC_DC_COMPLETE top=$top run=$run"
exit
