# Read-only audit of a routed research DCP; never modify source constraints.
if {[llength $argv] != 2} {error "usage: <routed-dcp> <new-output-dir>"}
set dcp [file normalize [lindex $argv 0]]
set out [file normalize [lindex $argv 1]]
if {![file exists $dcp] || [file exists $out]} {error "missing DCP or output already exists"}
file mkdir $out
cd $out
set_param general.maxThreads 1
open_checkpoint $dcp
report_cdc -details -file cdc_details.rpt
report_clock_interaction -delay_type min_max -file clock_interaction.rpt
report_exceptions -file exceptions.rpt
check_timing -verbose -file check_timing.rpt
report_timing_summary -delay_type min_max -report_unconstrained -file timing_summary.rpt
puts "CDC_AUDIT_COMPLETE"
