set here [file dirname [file normalize [info script]]]
set root [file normalize [file join $here .. ..]]
set project_dir [file join $here project]
set report_dir [file join $here reports]
file mkdir $project_dir
file mkdir $report_dir
create_project -force thermo5_lp_ooc [file join $project_dir thermo5_lp_ooc] -part xczu15eg-ffvb1156-2-i
set_property target_language Verilog [current_project]
foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] { add_files -norecurse $xpm_file }
foreach file [list \
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
  [file join $root rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv] \
  [file join $root syn rtl tid32_thermo_axis_frontend_ooc.sv]] { add_files -norecurse $file }
add_files -fileset constrs_1 -norecurse [file join $here constraints.xdc]
set_property top tid32_thermo5_axis_frontend_tx_lp_ooc [current_fileset]
update_compile_order -fileset sources_1
set_property -dict [list {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} {-mode out_of_context}] [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.DIRECTIVE AreaOptimized_high [get_runs synth_1]
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
launch_runs synth_1 -jobs 1
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" || ![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} { error "thermo5 LP synthesis failed: [get_property STATUS [get_runs synth_1]]" }
launch_runs impl_1 -to_step route_design -jobs 1
wait_on_run impl_1
set routed_dcp [file join $project_dir thermo5_lp_ooc thermo5_lp_ooc.runs impl_1 tid32_thermo5_axis_frontend_tx_lp_ooc_routed.dcp]
# The selected strategy contains a post-route phys-opt step.  Because this
# flow deliberately stops at route_design, use the routed checkpoint rather
# than the managed-run status as the implementation completion criterion.
if {![file exists $routed_dcp]} { error "thermo5 LP routed checkpoint missing; run status: [get_property STATUS [get_runs impl_1]]" }
open_checkpoint $routed_dcp
report_utilization -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_timing -max_paths 20 -file [file join $report_dir timing_max_paths.rpt]
report_power -file [file join $report_dir power_vectorless.rpt]
write_checkpoint -force [file join $report_dir thermo5_lp_routed.dcp]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
set status [expr {$wns >= 0.0 && $whs >= 0.0 ? "PASS" : "FAIL"}]
set f [open [file join $report_dir summary.csv] w]
puts $f "Part,Top,Core_MHz,Status,WNS_ns,WHS_ns"
puts $f "xczu15eg-ffvb1156-2-i,tid32_thermo5_axis_frontend_tx_lp_ooc,218.75,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_LP_OOC_STATUS=$status WNS=$wns WHS=$whs"
close_project
