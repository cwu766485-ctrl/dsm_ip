# Generate final STA reports from a routed thermo5 full AXI-Stream checkpoint.
# Parent I/O budgets/HD.PARTPIN_LOCS are intentionally not fabricated here.
if {[llength $argv] != 1} { error "usage: <out_dir>" }
set out_dir [file normalize [lindex $argv 0]]
set checkpoint [file join $out_dir routed.dcp]
if {![file exists $checkpoint]} { error "routed checkpoint not found: $checkpoint" }
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
report_timing_summary -file [file join $out_dir timing_summary.rpt]
report_timing -max_paths 30 -file [file join $out_dir timing_max_paths.rpt]
report_clock_interaction -file [file join $out_dir clock_interaction.rpt]
check_timing -verbose -file [file join $out_dir check_timing.rpt]
report_utilization -file [file join $out_dir utilization.rpt]
set setup [get_timing_paths -max_paths 1 -quiet]
set hold [get_timing_paths -delay_type min -max_paths 1 -quiet]
if {[llength $setup] == 0 || [llength $hold] == 0} {
  error "No setup/hold path was available in the routed checkpoint"
}
set wns [get_property SLACK [lindex $setup 0]]
set whs [get_property SLACK [lindex $hold 0]]
if {$wns < 0.0} { set status FAIL_SETUP
} elseif {$whs < 0.0} { set status FAIL_HOLD
} else { set status PASS }
set f [open [file join $out_dir summary.csv] w]
puts $f "Part,Top,Source_MHz,Core_MHz,Interp_Taps,Dpd_Max_Taps,Fifo,Status,WNS_ns,WHS_ns"
puts $f "xczu15eg-ffvb1156-2-i,tid32_thermo5_axis_frontend_tx,125.00,218.75,2,1,XPM,$status,[format %.3f $wns],[format %.3f $whs]"
close $f
puts "THERMO5_AXIS_ROUTED_REPORT_STATUS=$status WNS=$wns WHS=$whs"
