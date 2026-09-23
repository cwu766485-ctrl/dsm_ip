set script_dir [file dirname [file normalize [info script]]]
set root [file normalize [file join $script_dir ".."]]
if {[llength $argv] ni {4 5}} { error "usage: <part> <core_mhz> <thermo3|thermo5> <out_dir> ?quick|full?" }
set part [lindex $argv 0]
set core_mhz [expr {double([lindex $argv 1])}]
set flavour [lindex $argv 2]
set out_dir [file normalize [lindex $argv 3]]
set implementation [expr {[llength $argv] == 5 ? [lindex $argv 4] : "quick"}]
if {$flavour ni {thermo3 thermo5}} { error "flavour must be thermo3 or thermo5" }
if {$implementation ni {quick full}} { error "implementation must be quick or full" }
if {$flavour eq "thermo3"} { set top tid32_thermo3_axis_frontend_tx_ooc } else { set top tid32_thermo5_axis_frontend_tx_ooc }
file mkdir $out_dir
cd $out_dir
create_project -in_memory -part $part
if {![info exists ::env(XILINX_VIVADO)]} { error "XILINX_VIVADO is required for XPM FIFO synthesis" }
# Vivado 2024.1's realtime synthesis helper sources files from HRT_TCL_PATH.
# On this Windows installation the inherited value uses backslashes; Tcl then
# interprets sequences such as "\\r" and "\\t" while sourcing the generated
# helper script.  Pin the vendor-installed directory with forward slashes
# before synth_design so the helper receives a valid Tcl path.
set ::env(HRT_TCL_PATH) [file normalize [file join $::env(XILINX_VIVADO) scripts rt fpga_tcl]]
foreach xpm_file [list \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_cdc hdl xpm_cdc.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_memory hdl xpm_memory.sv] \
  [file join $::env(XILINX_VIVADO) data ip xpm xpm_fifo hdl xpm_fifo.sv]] {
  if {![file exists $xpm_file]} { error "XPM source not found: $xpm_file" }
  read_verilog -sv $xpm_file
}
foreach file [list \
  [file join $root rtl axis dsm_reset_sync.sv] \
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
# Vivado 2024.1 occasionally crashes its optional realtime parallel-synthesis
# helper on this host while sourcing an existing vendor unimacro Tcl file.  The
# helper only pre-spawns worker processes; it is not part of synthesis results.
# The Vivado frontend hides the realtime database before user Tcl is sourced.
# Restore it only long enough to disable helper spawning explicitly.  Keep the
# catch because older installations do not expose the same realtime hooks.
if {[llength [info commands rt::_x_restore]] != 0} {
  catch {namespace eval rt {_x_restore}}
}
if {[catch {rt::set_parameter enableParallelHelperSpawn false} helper_disable_error]} {
  puts "TID32_THERMO_AXIS_OOC_HELPER_DISABLE_UNAVAILABLE=$helper_disable_error"
} else {
  puts "TID32_THERMO_AXIS_OOC_HELPER_DISABLED=1"
}
synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy none -directive AreaOptimized_high
puts "TID32_THERMO_AXIS_OOC_STAGE=post_synth"
create_clock -name s_axis_aclk -period 8.000 [get_ports clk125]
create_clock -name core_clk -period [expr {1000.0/$core_mhz}] [get_ports clk218]
set_clock_groups -asynchronous -group [get_clocks s_axis_aclk] -group [get_clocks core_clk]
set_false_path -from [get_ports {rst125_n rst218_n}]
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
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} { error "No timing path reported" }
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} {set status FAIL_SETUP} elseif {$whs < 0.0} {set status FAIL_HOLD} else {set status PASS}
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Block,Source_MHz,Core_MHz,DPD_Implementation,Implementation,Status,WNS_ns,WHS_ns"
puts $f "$part,$top,125.00,[format %.2f $core_mhz],memory_poly_identity_runtime,$implementation,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "TID32_THERMO_AXIS_OOC_STATUS=$status"
