if {[llength $argv] != 6} {
  error "usage: <repo_root> <part> <core_mhz> <thermo3|thermo5> <baseline|lp> <out_dir>"
}
set root [file normalize [lindex $argv 0]]
set part [lindex $argv 1]
set core_mhz [expr {double([lindex $argv 2])}]
set flavour [lindex $argv 3]
set mode [lindex $argv 4]
set out_dir [file normalize [lindex $argv 5]]
if {$flavour ni {thermo3 thermo5}} { error "invalid flavour: $flavour" }
if {$mode ni {baseline lp}} { error "invalid mode: $mode" }
if {abs($core_mhz - 218.75) > 0.001} {
  error "power-project XDC is qualified only for 218.75 MHz"
}
file mkdir $out_dir

set suffix [expr {$mode eq "lp" ? "_lp_ooc" : "_ooc"}]
set top "tid32_${flavour}_axis_frontend_tx${suffix}"
set project_name "${flavour}_${mode}_power_ooc"
set project_dir [file join $out_dir project]
create_project -force $project_name $project_dir -part $part
set_property target_language Verilog [current_project]

foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] {
  add_files -norecurse $xpm_file
}
foreach source [list \
  [file join $root rtl axis dsm_reset_sync.sv] \
  [file join $root rtl axis dsm_frame_power_ctrl.sv] \
  [file join $root rtl axis dsm_xpm_async_fifo.sv] \
  [file join $root rtl axis dsm_axis14_to_core8_cdc.sv] \
  [file join $root rtl frontend dsm_frame_gain_vector.sv] \
  [file join $root rtl gt gt_tx_user_bridge.sv] \
  [file join $root rtl gt gt_tx_raw64_boundary.sv] \
  [file join $root rtl dpd dpd_poly.v] \
  [file join $root rtl dpd dpd_memory_poly.v] \
  [file join $root rtl dpd dpd_vector16_memory_poly.sv] \
  [file join $root rtl dpd dpd_vector_elastic_buffer.sv] \
  [file join $root rtl interp dsm_interp_x2_polyphase_vector.sv] \
  [file join $root rtl tx_bandpass_if tid32_cartesian_fs4_gt_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_axis_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv] \
  [file join $root syn rtl tid32_thermo_axis_frontend_ooc.sv]] {
  add_files -norecurse $source
}
set xdc [file join $root fpga "${flavour}_lp" constraints.xdc]
add_files -fileset constrs_1 -norecurse $xdc
set_property top $top [current_fileset]
update_compile_order -fileset sources_1

set_property -dict [list {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} {-mode out_of_context}] [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

launch_runs synth_1 -jobs 1
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    ![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {
  error "$flavour/$mode synthesis failed: [get_property STATUS [get_runs synth_1]]"
}
launch_runs impl_1 -to_step route_design -jobs 1
wait_on_run impl_1
set run_dir [file join $project_dir "${project_name}.runs" impl_1]
set routed_dcp [file join $run_dir "${top}_routed.dcp"]
if {![file exists $routed_dcp]} {
  error "$flavour/$mode routed checkpoint missing: [get_property STATUS [get_runs impl_1]]"
}
open_checkpoint $routed_dcp
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0 || $whs < 0.0} { error "$flavour/$mode timing failed WNS=$wns WHS=$whs" }
puts "LP_POWER_BUILD_PASS flavour=$flavour mode=$mode WNS=$wns WHS=$whs"
close_design
close_project
exit
