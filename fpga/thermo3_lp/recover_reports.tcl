set here [file dirname [file normalize [info script]]]
set report_dir [file join $here reports]
set routed_dcp [file join $here project thermo3_lp_ooc thermo3_lp_ooc.runs impl_1 tid32_thermo3_axis_frontend_tx_lp_ooc_routed.dcp]

if {![file exists $routed_dcp]} {
  error "thermo3 LP routed checkpoint missing: $routed_dcp"
}

file mkdir $report_dir
open_checkpoint $routed_dcp
report_utilization -file [file join $report_dir utilization.rpt]
report_timing_summary -file [file join $report_dir timing_summary.rpt]
report_timing -max_paths 20 -file [file join $report_dir timing_max_paths.rpt]
report_power -file [file join $report_dir power_vectorless.rpt]
write_checkpoint -force [file join $report_dir thermo3_lp_routed.dcp]

set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} {
  error "thermo3 LP checkpoint has no constrained setup or hold path"
}
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
set status [expr {$wns >= 0.0 && $whs >= 0.0 ? "PASS" : "FAIL"}]
set f [open [file join $report_dir summary.csv] w]
puts $f "Part,Top,Core_MHz,Status,WNS_ns,WHS_ns"
puts $f "xczu15eg-ffvb1156-2-i,tid32_thermo3_axis_frontend_tx_lp_ooc,218.75,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO3_LP_OOC_STATUS=$status WNS=$wns WHS=$whs"
close_design
exit
