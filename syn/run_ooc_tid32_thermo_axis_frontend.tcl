set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] < 4 || [llength $argv] > 9} { error "usage: <part> <core_mhz> <thermo3|thermo5> <out_dir> ?quick|full? ?saif? ?interp_taps? ?dpd_max_taps? ?dpd_active_taps?" }
set part [lindex $argv 0]
set core_mhz [expr {double([lindex $argv 1])}]
set flavour [lindex $argv 2]
set out_dir [file normalize [lindex $argv 3]]
set implementation [expr {[llength $argv] >= 5 ? [lindex $argv 4] : "quick"}]
set activity_file [expr {[llength $argv] >= 6 && [lindex $argv 5] ne "-" ? [file normalize [lindex $argv 5]] : ""}]
set interp_taps [expr {[llength $argv] >= 7 ? [lindex $argv 6] : 4}]
set dpd_max_taps [expr {[llength $argv] >= 8 ? [lindex $argv 7] : 4}]
set dpd_active_taps [expr {[llength $argv] >= 9 ? [lindex $argv 8] : 1}]
if {$flavour ni {thermo3 thermo5 thermo3_lp thermo5_lp}} { error "flavour must be thermo3, thermo5, thermo3_lp or thermo5_lp" }
if {$implementation ni {quick full}} { error "implementation must be quick or full" }
if {$interp_taps ni {2 3 4}} { error "interp_taps must be 2, 3, or 4" }
if {$dpd_max_taps ni {1 2 4}} { error "dpd_max_taps must be 1, 2, or 4" }
if {$dpd_active_taps < 1 || $dpd_active_taps > $dpd_max_taps} { error "dpd_active_taps must be in 1..dpd_max_taps" }
if {$flavour eq "thermo3"} { set top tid32_thermo3_axis_frontend_tx_ooc
} elseif {$flavour eq "thermo5"} { set top tid32_thermo5_axis_frontend_tx_ooc
} elseif {$flavour eq "thermo3_lp"} { set top tid32_thermo3_axis_frontend_tx_lp_ooc
} else { set top tid32_thermo5_axis_frontend_tx_lp_ooc }
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required for XPM FIFO synthesis" }
# Vivado 2024.1's realtime synthesis helper sources files from HRT_TCL_PATH.
# On this Windows installation the inherited value uses backslashes; Tcl then
# interprets sequences such as "\\r" and "\\t" while sourcing the generated
# helper script.  Pin the vendor-installed directory with forward slashes
# before synth_design so the helper receives a valid Tcl path.
# Vivado 2024.1's generated realtime helper expects the FPGA Tcl package
# directory itself, not its parent.  Point it at the vendor package and mark
# this as an external/in-process invocation so the helper does not enter the
# stale shared-memory cleanup path after synthesis.
set ::env(HRT_TCL_PATH) [string map {\\ /} [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]]
set ::env(XILINX_REALTIMEFPGA) 1
foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] {
  if {![file exists $xpm_file]} { error "XPM source not found: $xpm_file" }
  read_verilog -sv $xpm_file
}
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
  [file join $root rtl tx_bandpass_if tid32_thermo3_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo3_axis_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_fs4_multipa_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_frontend_tx.sv] \
  [file join $root rtl tx_bandpass_if tid32_thermo5_axis_frontend_tx.sv] \
  [file join $root syn rtl tid32_thermo_axis_frontend_ooc.sv]] { read_verilog -sv $file }
set_param general.maxThreads 1
set_param synth.maxThreads 1
catch {set_param synth.enableParallelSynthesis false}
catch {set_param synth.parallelSynthesis false}
# Do not set BUILTIN_SYNTH here.  Vivado's rtSynthParallelPrep.tcl checks only
# for the *presence* of that environment variable, so even a value of 0 enters
# the private realtime helper path and can fail with rt-undefined.  Leaving it
# unset selects the ordinary in-process synthesis path.
catch {unset ::env(BUILTIN_SYNTH)}
# DPD_ACTIVE_TAPS_RUNTIME=0 is essential for a structural PPA point: it
# makes the selected number of active memory taps a synthesis constant rather
# than a runtime port.  Defaults preserve the deployed runtime-programmable
# OOC configuration when no optional SKU arguments are supplied.
set sku_generics [list "INTERP_TAPS=$interp_taps" "DPD_MAX_TAPS=$dpd_max_taps"]
if {[llength $argv] >= 9} {
  lappend sku_generics "DPD_ACTIVE_TAPS=$dpd_active_taps"
  lappend sku_generics "DPD_ACTIVE_TAPS_RUNTIME=0"
}
synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high -generic $sku_generics
puts "TID32_THERMO_AXIS_OOC_STAGE=post_synth"
create_clock -name s_axis_aclk -period 8.000 [get_ports clk125]
create_clock -name core_clk -period [expr {1000.0/$core_mhz}] [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {rst125_n rst218_n run_request}]
# The quick flow is retained as a bounded diagnostic.  Timing closure must use
# the full timing-driven implementation sequence, which matches the earlier
# single-clock frontend methodology and allows physical optimization.
if {$implementation eq "full"} {
  opt_design
  place_design
  phys_opt_design
} else {
  place_design -directive Quick
}
puts "TID32_THERMO_AXIS_OOC_STAGE=place_done"
if {$implementation eq "full"} {
  route_design
} else {
  route_design -directive Quick
}
puts "TID32_THERMO_AXIS_OOC_STAGE=route_done"
report_utilization -file [file join $out_dir utilization.rpt]
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 20 -file [file join $out_dir timing_max_paths.rpt]
if {$activity_file ne ""} {
  if {![file exists $activity_file]} { error "SAIF activity file does not exist: $activity_file" }
  # The activity generator logs the testbench hierarchy above the common
  # g_thermo*/u_dut instance. Strip that simulation-only prefix so SAIF names
  # map onto the synthesized OOC top's u_dut hierarchy.
  set strip_path [expr {[string match "thermo5*" $flavour] ?
                        "tb_tid32_thermo_axis_lp_power/g_thermo5" :
                        "tb_tid32_thermo_axis_lp_power/g_thermo3"}]
  read_saif -strip_path $strip_path $activity_file
}
set power_name [expr {$activity_file eq "" ? "power_vectorless.rpt" : "power_saif.rpt"}]
report_power -file [file join $out_dir $power_name]
write_checkpoint -force [file join $out_dir routed.dcp]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} {set status FAIL_SETUP} elseif {$whs < 0.0} {set status FAIL_HOLD} else {set status PASS}
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Block,Source_MHz,Core_MHz,Interp_Taps,DPD_Max_Taps,DPD_Active_Taps,DPD_Implementation,Implementation,Status,WNS_ns,WHS_ns"
set dpd_mode [expr {[llength $argv] >= 9 ? "memory_poly_compile_time" : "memory_poly_identity_runtime"}]
puts $f "$part,$top,125.00,[format %.2f $core_mhz],$interp_taps,$dpd_max_taps,$dpd_active_taps,$dpd_mode,$implementation,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
set pf [open [file join $out_dir power_provenance.txt] w]
set activity_source vectorless
if {$activity_file ne ""} { set activity_source saif }
puts $pf "activity_source=$activity_source"
if {$activity_file ne ""} { puts $pf "activity_file=$activity_file" }
close $pf
puts "TID32_THERMO_AXIS_OOC_STATUS=$status"
