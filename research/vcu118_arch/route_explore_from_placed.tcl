# Alternate routing strategy from a preserved placed checkpoint.
# Usage: <placed.dcp> <new-output-dir>
if {[llength $argv] != 2} {
  error "usage: <placed.dcp> <new-output-dir>"
}
set source_dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file isfile $source_dcp]} {error "placed checkpoint not found: $source_dcp"}
if {[file exists $out]} {error "refusing to overwrite output directory: $out"}
file mkdir $out
cd $out
set_param general.maxThreads 1
open_checkpoint $source_dcp

foreach {name expected} {core_clk 4.571428571 s_axis_aclk 8.0 s_axil_aclk 10.0} {
  set c [get_clocks -quiet $name]
  if {[llength $c] != 1} {error "expected exactly one clock $name"}
  set period [get_property PERIOD $c]
  if {abs($period - $expected) > 0.001} {error "unexpected $name period $period ns"}
}
puts "ROUTE_EXPLORE_SOURCE_DCP $source_dcp"
report_exceptions -file pre_route_exceptions.rpt
check_timing -verbose -file pre_route_check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file pre_route_timing_summary.rpt
if {[catch {route_design -directive Explore} message options]} {
  puts stderr "ROUTE_EXPLORE_FAILED message=$message"
  if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
  error "route_design -directive Explore failed"
}
write_checkpoint routed.dcp
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_cdc -file routed_cdc.rpt
report_cdc -details -file routed_cdc_details.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_exceptions -file routed_exceptions.rpt
report_bus_skew -file routed_bus_skew.rpt
report_power -file power_default_activity.rpt
puts "ROUTE_EXPLORE_PASS source=$source_dcp out=$out"
