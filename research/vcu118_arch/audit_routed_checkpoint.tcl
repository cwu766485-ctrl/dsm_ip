# Post-route constraint audit for a preserved compile-time product DCP.
# Usage: <routed.dcp> <new-output-dir>
if {[llength $argv] != 2} {
  error "usage: <routed.dcp> <new-output-dir>"
}
set source_dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file isfile $source_dcp]} {error "routed checkpoint not found: $source_dcp"}
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
puts "ROUTED_AUDIT_SOURCE_DCP $source_dcp"
report_timing_summary -delay_type min_max -report_unconstrained -file routed_timing_summary_audit.rpt
check_timing -verbose -file routed_check_timing.rpt
report_exceptions -file routed_exceptions_audit.rpt
report_clock_interaction -delay_type min_max -file routed_clock_interaction_audit.rpt
report_bus_skew -file routed_bus_skew_audit.rpt
puts "ROUTED_AUDIT_PASS source=$source_dcp out=$out"
