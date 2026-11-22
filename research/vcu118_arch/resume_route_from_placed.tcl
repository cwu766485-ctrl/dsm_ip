# Route a preserved placed checkpoint without modifying its source DCP.
# The checkpoint must already contain the complete timing constraints and
# physical placement. Use a new output directory for every attempt.
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
set_param place.maxThreads 1
set_param route.maxThreads 1
open_checkpoint $source_dcp

set required_clocks {core_clk s_axis_aclk s_axil_aclk}
foreach name $required_clocks {
  set c [get_clocks -quiet $name]
  if {[llength $c] != 1} {error "expected exactly one clock $name"}
}
set core_period [get_property PERIOD [get_clocks core_clk]]
if {abs($core_period - 4.571428571) > 0.001} {
  error "unexpected core period $core_period ns"
}
puts "ROUTE_RESUME_SOURCE $source_dcp"
puts "ROUTE_RESUME_CLOCKS core_clk=$core_period axis=[get_property PERIOD [get_clocks s_axis_aclk]] axil=[get_property PERIOD [get_clocks s_axil_aclk]]"

report_exceptions -file pre_route_exceptions.rpt
report_clock_interaction -delay_type min_max -file pre_route_clock_interaction.rpt
check_timing -verbose -file pre_route_check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file pre_route_timing_summary.rpt

if {[catch {route_design} message options]} {
  puts stderr "ROUTE_RESUME_FAILED message=$message"
  if {[dict exists $options -errorinfo]} {puts stderr [dict get $options -errorinfo]}
  error "route_design failed"
}

write_checkpoint routed.dcp
report_cdc -file routed_cdc.rpt
report_cdc -details -file routed_cdc_details.rpt
report_utilization -file routed_utilization.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 -file setup_worst20.rpt
report_timing -delay_type min -max_paths 20 -nworst 20 -file hold_worst20.rpt
report_timing -delay_type max -max_paths 20 -nworst 20 \
  -from [get_clocks core_clk] -to [get_clocks core_clk] -file core_setup_worst20.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction.rpt
report_exceptions -file routed_exceptions.rpt
report_bus_skew -file routed_bus_skew.rpt
report_power -file power_default_activity.rpt
puts "ROUTE_RESUME_PASS OUT=$out"
