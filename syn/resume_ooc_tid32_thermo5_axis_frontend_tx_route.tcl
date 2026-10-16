# Resume routing from a saved thermo5 full AXI-Stream physopt checkpoint.
# The routed checkpoint is saved before optional report generation so the
# implementation result survives a later report-stage memory limit.
if {[llength $argv] != 2} {
  error "usage: <physopt_checkpoint> <out_dir>"
}
set checkpoint [file normalize [lindex $argv 0]]
set out_dir [file normalize [lindex $argv 1]]
if {![file exists $checkpoint]} { error "physopt checkpoint not found: $checkpoint" }
file mkdir $out_dir
cd $out_dir
open_checkpoint $checkpoint
foreach {name period} {s_axis_aclk 8.000 core_clk 4.571428571} {
  set clock [get_clocks -quiet $name]
  if {[llength $clock] != 1} { error "Expected constrained clock is missing: $name" }
  set actual [get_property PERIOD $clock]
  if {abs($actual - $period) > 0.002} {
    error "Unexpected period for $name: expected $period ns, got $actual ns"
  }
}
puts "THERMO5_AXIS_RESUME_ROUTE_CLOCKS=PASS"
route_design
report_route_status -file [file join $out_dir route_status.rpt]
write_checkpoint -force [file join $out_dir routed.dcp]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} {
  error "No setup/hold path was available after routing"
}
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} { set status FAIL_SETUP
} elseif {$whs < 0.0} { set status FAIL_HOLD
} else { set status PASS }
set f [open [file join $out_dir router_summary.csv] w]
puts $f "Part,Top,Source_MHz,Core_MHz,Interp_Taps,Dpd_Max_Taps,Fifo,Status,WNS_ns,WHS_ns"
puts $f "xczu15eg-ffvb1156-2-i,tid32_thermo5_axis_frontend_tx,125.00,218.75,2,1,XPM,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_AXIS_RESUME_ROUTE_STATUS=$status WNS=$wns WHS=$whs"
